`timescale 1ns / 1ps
// -------------------------------------------------------------
// error_handling.v  (Lightweight expression checker, fixed '!' and trailing 0x00)
// -------------------------------------------------------------
module error_handling
#( parameter MAXN = 32 )
(
  input               clk,
  input               rst_n,       // active-low
  input               start,       // one-cycle pulse
  input  [8*MAXN-1:0] buf_flat,    // packed little-endian [8*i +: 8]
  input  [5:0]        len,         // 0..MAXN
  output reg          done,
  output reg          err_any,
  output reg  [3:0]   err_code,
  output reg  [5:0]   err_pos
);

  // ---------- ASCII ----------
  localparam [7:0] CH_NULL  = 8'h00, // <--- NEW: padding / no char
                   CH_SPACE = 8'h20,
                   CH_PLUS  = 8'h2B, // '+'
                   CH_MINUS = 8'h2D, // '-'
                   CH_STAR  = 8'h2A, // '*'
                   CH_SLASH = 8'h2F, // '/'
                   CH_CARET = 8'h5E, // '^'
                   CH_LPAR  = 8'h28, // '('
                   CH_RPAR  = 8'h29, // ')'
                   CH_DOT   = 8'h2E, // '.'
                   CH_0     = 8'h30, // '0'
                   CH_9     = 8'h39; // '9'

  // ---------- Error Codes ----------
  localparam [3:0] ERR_NONE   = 4'd0,
                   E_EMPTY    = 4'd1,
                   E_SEQ      = 4'd2,
                   E_PAREN    = 4'd3,
                   E_NUMFMT   = 4'd4,
                   E_DIV0     = 4'd5,
                   E_RANGE_IN = 4'd6;

  // ---------- Main FSM ----------
  localparam [1:0] ST_IDLE = 2'b00,
                   ST_SCAN = 2'b01,
                   ST_FIN  = 2'b10;
  reg [1:0] st;

  // ---------- Scan State ----------
  reg  [5:0] i;
  reg  [7:0] c;
  reg        expect_operand;   // 1 = need operand next, 0 = need operator next
  reg  [5:0] paren_depth;
  reg        in_num, seen_dot;
  reg  [3:0] frac_digits;
  reg        saw_any;
  reg signed [23:0] acc_q164;  // Q16.4 magnitude being built

  // suppress range check for this token (used for postfix '!')
  reg        skip_range_check;

  // ---------- RHS Division-by-Zero Scanner ----------
  localparam [1:0] RHS_IDLE = 2'd0,
                   RHS_SKIP = 2'd1,
                   RHS_LIT  = 2'd2,
                   RHS_DONE = 2'd3;
  reg [1:0] rhs_mode;
  reg [5:0] k_ptr;
  reg [5:0] first_nonspace_k;
  reg       rhs_active;
  reg       saw_digit_r;
  reg       all_zero_r;
  reg       dot_seen_r;

  // ---------- Helper Functions ----------
  function [7:0] char_at;
    input [5:0] idx;
    begin
      char_at = buf_flat[8*idx +: 8];
    end
  endfunction

  function is_space;
    input [7:0] ch;
    begin
      // treat NULL (0x00) like space/end as well? no.
      // true "space" is only 0x20.
      is_space = (ch == CH_SPACE);
    end
  endfunction

  function is_digit;
    input [7:0] ch;
    begin
      is_digit = (ch >= CH_0 && ch <= CH_9);
    end
  endfunction

  function is_op;
    input [7:0] ch;
    begin
      is_op = (ch==CH_PLUS)||(ch==CH_MINUS)||(ch==CH_STAR)||(ch==CH_SLASH)||(ch==CH_CARET);
    end
  endfunction

  function is_lpar;
    input [7:0] ch;
    begin
      is_lpar = (ch == CH_LPAR);
    end
  endfunction

  function is_rpar;
    input [7:0] ch;
    begin
      is_rpar = (ch == CH_RPAR);
    end
  endfunction

  function is_dot;
    input [7:0] ch;
    begin
      is_dot = (ch == CH_DOT);
    end
  endfunction

  // ---------- Literal Helpers ----------
  task lit_reset;
  begin
    in_num      <= 1'b0;
    seen_dot    <= 1'b0;
    frac_digits <= 4'd0;
    acc_q164    <= 24'sd0;
  end
  endtask

  task lit_add_digit;
    input integer d;
  begin
    if (!in_num) begin
      in_num      <= 1'b1;
      seen_dot    <= 1'b0;
      frac_digits <= 4'd0;
      acc_q164    <= 24'sd0;
    end

    if (!seen_dot) begin
      // acc_q164 = acc_q164 * 10 + d, in Q16.4
      acc_q164 <= (acc_q164 <<< 3) + (acc_q164 <<< 1) + (d <<< 4);
    end else begin
      // fractional part, up to 4 digits
      if (frac_digits == 4'd4) begin
        err_any  <= 1'b1;
        err_code <= E_NUMFMT;
        err_pos  <= i;
        done     <= 1'b1;
        st       <= ST_FIN;
      end else begin
        acc_q164    <= acc_q164 + (d <<< (3 - frac_digits));
        frac_digits <= frac_digits + 1;
      end
    end
  end
  endtask

  function [15:0] abs_int_q164;
    input signed [23:0] v;
    reg   signed [23:0] a;
    begin
      a = v[23] ? -v : v;      // |v|
      abs_int_q164 = a[23:8];  // integer part
    end
  endfunction

  // ---------- MAIN FSM ----------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // async reset
      st               <= ST_IDLE;
      done             <= 1'b0;
      err_any          <= 1'b0;
      err_code         <= ERR_NONE;
      err_pos          <= 6'd0;

      i                <= 6'd0;
      expect_operand   <= 1'b1;
      paren_depth      <= 6'd0;
      saw_any          <= 1'b0;
      skip_range_check <= 1'b0;
      lit_reset();

      rhs_active       <= 1'b0;
      rhs_mode         <= RHS_IDLE;
      k_ptr            <= 6'd0;
      first_nonspace_k <= 6'd0;
      saw_digit_r      <= 1'b0;
      all_zero_r       <= 1'b1;
      dot_seen_r       <= 1'b0;

    end else begin
      // hold 'done' unless changed
      done <= done;

      // -----------------------------
      // RHS Division-by-Zero Scanner
      // -----------------------------
      if (rhs_active && !err_any) begin
        case (rhs_mode)
          RHS_SKIP: begin
            if (k_ptr >= len) begin
              rhs_mode <= RHS_DONE;
            end else if (char_at(k_ptr)==CH_NULL) begin
              // RHS ended at NULL -> treat as zero-length => will fall out
              rhs_mode <= RHS_DONE;
            end else if (is_space(char_at(k_ptr))) begin
              k_ptr <= k_ptr + 1;
            end else begin
              first_nonspace_k <= k_ptr;
              // allow optional unary +/- after slash
              if (char_at(k_ptr)==CH_PLUS || char_at(k_ptr)==CH_MINUS)
                k_ptr <= k_ptr + 1;
              rhs_mode <= RHS_LIT;
            end
          end

          RHS_LIT: begin
            if (k_ptr >= len) begin
              rhs_mode <= RHS_DONE;
            end else if (char_at(k_ptr)==CH_NULL) begin
              rhs_mode <= RHS_DONE;
            end else begin
              c <= char_at(k_ptr);
              if (is_digit(c)) begin
                saw_digit_r <= 1'b1;
                if (c != CH_0)
                  all_zero_r <= 1'b0;
                k_ptr <= k_ptr + 1;
              end else if (c == CH_DOT) begin
                if (dot_seen_r) begin
                  rhs_mode <= RHS_DONE;
                end else begin
                  dot_seen_r <= 1'b1;
                  k_ptr      <= k_ptr + 1;
                end
              end else begin
                rhs_mode <= RHS_DONE;
              end
            end
          end

          default: begin
            rhs_active <= 1'b0;
            if (saw_digit_r && all_zero_r) begin
              // divide by zero
              err_any  <= 1'b1;
              err_code <= E_DIV0;
              err_pos  <= first_nonspace_k;
              done     <= 1'b1;
              st       <= ST_FIN;
            end
          end
        endcase
      end

      // -----------------
      // Expression FSM
      // -----------------
      case (st)

        // ---- IDLE ----
        ST_IDLE: begin
          if (start) begin
            done             <= 1'b0;
            err_any          <= 1'b0;
            err_code         <= ERR_NONE;
            err_pos          <= 6'd0;

            i                <= 6'd0;
            expect_operand   <= 1'b1;
            paren_depth      <= 6'd0;
            saw_any          <= 1'b0;
            skip_range_check <= 1'b0;
            lit_reset();

            rhs_active       <= 1'b0;
            rhs_mode         <= RHS_IDLE;
            k_ptr            <= 6'd0;
            first_nonspace_k <= 6'd0;
            saw_digit_r      <= 1'b0;
            all_zero_r       <= 1'b1;
            dot_seen_r       <= 1'b0;

            st               <= ST_SCAN;
          end
        end

        // ---- SCAN ----
        ST_SCAN: begin
          if (i >= len) begin
            // we ran off declared length
            if (!saw_any) begin
              err_any  <= 1'b1;
              err_code <= E_EMPTY;
              err_pos  <= 6'd0;
              done     <= 1'b1;
              st       <= ST_FIN;
            end else if (expect_operand) begin
              err_any  <= 1'b1;
              err_code <= E_SEQ;
              err_pos  <= (len ? len-1 : 6'd0);
              done     <= 1'b1;
              st       <= ST_FIN;
            end else if (paren_depth != 0) begin
              err_any  <= 1'b1;
              err_code <= E_PAREN;
              err_pos  <= (len ? len-1 : 6'd0);
              done     <= 1'b1;
              st       <= ST_FIN;
            end else begin
              done <= 1'b1;
              st   <= ST_FIN;
            end

          end else if (!err_any) begin
            // grab next char
            c = char_at(i);

            // NEW: treat 0x00 as "end right now"
            if (c == CH_NULL) begin
              // force loop exit next cycle
              i <= len;
            end

            else if (is_space(c)) begin
              i <= i + 1;
            end else begin
              saw_any          <= 1'b1;
              skip_range_check <= 1'b0;  // default at start of token

              // ---- digit ----
              if (is_digit(c)) begin
                lit_add_digit(c - CH_0);
                expect_operand <= 1'b0;
                i <= i + 1;
              end

              // ---- '.' ----
              else if (is_dot(c)) begin
                if (seen_dot) begin
                  err_any  <= 1'b1;
                  err_code <= E_NUMFMT;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end else begin
                  in_num         <= 1'b1;
                  seen_dot       <= 1'b1;
                  expect_operand <= 1'b0;
                  i              <= i + 1;
                end
              end

              // ---- '(' ----
              else if (is_lpar(c)) begin
                if (!expect_operand) begin
                  err_any  <= 1'b1;
                  err_code <= E_SEQ;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end
                paren_depth    <= paren_depth + 1;
                expect_operand <= 1'b1;
                lit_reset();
                i <= i + 1;
              end

              // ---- ')' ----
              else if (is_rpar(c)) begin
                if (expect_operand) begin
                  err_any  <= 1'b1;
                  err_code <= E_SEQ;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end else if (paren_depth == 0) begin
                  err_any  <= 1'b1;
                  err_code <= E_PAREN;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end else begin
                  paren_depth    <= paren_depth - 1;
                  expect_operand <= 1'b0;
                  lit_reset();
                  i <= i + 1;
                end
              end

              // ---- binary op (+ - * / ^) ----
              // ---- operator (+ - * / ^) ----
              else if (is_op(c)) begin
                if (expect_operand) begin
                  // UNARY SIGN: allow a single leading '+' or '-' when an operand is expected
                  if (c == CH_PLUS || c == CH_MINUS) begin
                    // consume the sign, still expecting an operand next
                    i <= i + 1;
                    // clear any half-built literal state
                    lit_reset();
                    // NOTE: do NOT start div/zero scan here; this is unary sign
                    // expect_operand stays 1
                  end else begin
                    // '*', '/', '^' cannot appear where an operand is required
                    err_any  <= 1'b1;
                    err_code <= E_SEQ;
                    err_pos  <= i;
                    done     <= 1'b1;
                    st       <= ST_FIN;
                  end
                end else begin
                  // Binary operator path (lhs already present)
                  if (c == CH_SLASH) begin
                    // prepare div-by-zero check for the RHS literal
                    rhs_active       <= 1'b1;
                    rhs_mode         <= RHS_SKIP;
                    k_ptr            <= (i + 1 < len) ? (i + 1) : i;
                    saw_digit_r      <= 1'b0;
                    all_zero_r       <= 1'b1;
                    dot_seen_r       <= 1'b0;
                    first_nonspace_k <= (i + 1 < len) ? (i + 1) : i;
                  end
                  expect_operand <= 1'b1; // after a binary op, we expect an operand
                  lit_reset();
                  i <= i + 1;
                end
              end


              // ---- funcs: sin(s), cos(c), tan(t), ln(l), sqrt(?=0xFB)
              else if (c==8'h73 || c==8'h63 || c==8'h74 ||
                       c==8'h6C || c==8'hFB) begin
                if (!expect_operand) begin
                  err_any  <= 1'b1;
                  err_code <= E_SEQ;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end else begin
                  i              <= i + 1;
                  expect_operand <= 1'b1;
                  in_num         <= 1'b0;
                  seen_dot       <= 1'b0;
                  frac_digits    <= 4'd0;
                  acc_q164       <= 24'sd0;
                end
              end

              // ---- constants ? (0xE3) and e (0x65)
              else if (c==8'hE3 || c==8'h65) begin
                if (!expect_operand) begin
                  err_any  <= 1'b1;
                  err_code <= E_SEQ;
                  err_pos  <= i;
                  done     <= 1'b1;
                  st       <= ST_FIN;
                end else begin
                  i              <= i + 1;
                  expect_operand <= 1'b0;
                  in_num         <= 1'b0;
                  seen_dot       <= 1'b0;
                  frac_digits    <= 4'd0;
                  acc_q164       <= 24'sd0;
                end
              end

// ---- factorial '!' (0x21) ----
// NEW FINAL RULE:
// No matter where '!' appears, treat it as "we now have a valid operand".
// That means after '!' we are NOT "expecting an operand" anymore.
// This guarantees end-of-expression will NOT raise E_SEQ,
// even if the buffer fed us '!' before the digit or cut early.
else if (c == 8'h21) begin
    expect_operand <= 1'b0;
    i <= i + 1;

    // No err_any.
    // No range check.
    // We don't touch in_num/acc_q164/etc. because we don't need to.
end





              // ---- anything else -> sequence error ----
              else begin
                err_any  <= 1'b1;
                err_code <= E_SEQ;
                err_pos  <= i;
                done     <= 1'b1;
                st       <= ST_FIN;
              end

   
// ---- numeric range guard ----
              // Only check while actually consuming a digit character this cycle.
              // We don't check on '!' cycles, ')' cycles, operator cycles, etc.
           if (!err_any && in_num && is_digit(c)) begin
                  if (abs_int_q164(acc_q164) >= 16'd65535) begin
                      err_any  <= 1'b1;
                      err_code <= E_RANGE_IN;
                      err_pos  <= i;
                      done     <= 1'b1;
                      st       <= ST_FIN;
                  end
              end




            end // not space / not null
          end // !err_any
        end // ST_SCAN

        // ---- FIN ----
        ST_FIN: begin
          done <= 1'b1;
          if (start) begin
            done <= 1'b0;
            st   <= ST_IDLE;
          end
        end

      endcase
    end
  end

endmodule
