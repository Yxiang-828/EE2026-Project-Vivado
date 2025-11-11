`timescale 1ns/1ps
`default_nettype none

module precedence_eval #(
  parameter integer MAXN = 32
)(
  input  wire               clk,
  input  wire               rst_n,
  input  wire               start_eval,
  input  wire [8*MAXN-1:0]  buf_flat,
  input  wire [5:0]         len,

  // to ALU bridge
  output reg                alu_start,
  output reg  [3:0]         alu_op,
  output reg  signed [24:0] alu_a,
  output reg  signed [24:0] alu_b,
  input  wire               alu_done,
  input  wire signed [24:0] alu_result,
  input  wire               alu_overflow,

  output reg                done_eval,
  output reg signed [24:0]  result_value,
  output reg                result_overflow
);
  // op codes
  localparam OP_ADD=0, OP_SUB=1, OP_MUL=2, OP_DIV=3, OP_POW=4, OP_LOG2=5, OP_SIN=6, OP_COS=7, OP_TAN=8;

  // constants (Q16.8)
  localparam signed [24:0] Q168_PI   = 25'sd804;  // ~3.1416 * 256
  localparam signed [24:0] Q168_E    = 25'sd696;  // ~2.7183 * 256
  localparam signed [24:0] Q168_HALF = 25'sd128;  // 0.5

  // token bytes from your keypad map
  localparam [7:0] TOK_PI   = 8'hE3; // '?'
  localparam [7:0] TOK_SQRT = 8'hFB; // '?'

  // -------- safe byte access --------
  wire [5:0] len_eff = (len > MAXN[5:0]) ? MAXN[5:0] : len;

  function [7:0] ch_at_idx;
    input [5:0] idx;
    begin
      case (idx)
        6'd0 : ch_at_idx = buf_flat[  7:  0];
        6'd1 : ch_at_idx = buf_flat[ 15:  8];
        6'd2 : ch_at_idx = buf_flat[ 23: 16];
        6'd3 : ch_at_idx = buf_flat[ 31: 24];
        6'd4 : ch_at_idx = buf_flat[ 39: 32];
        6'd5 : ch_at_idx = buf_flat[ 47: 40];
        6'd6 : ch_at_idx = buf_flat[ 55: 48];
        6'd7 : ch_at_idx = buf_flat[ 63: 56];
        6'd8 : ch_at_idx = buf_flat[ 71: 64];
        6'd9 : ch_at_idx = buf_flat[ 79: 72];
        6'd10: ch_at_idx = buf_flat[ 87: 80];
        6'd11: ch_at_idx = buf_flat[ 95: 88];
        6'd12: ch_at_idx = buf_flat[103: 96];
        6'd13: ch_at_idx = buf_flat[111:104];
        6'd14: ch_at_idx = buf_flat[119:112];
        6'd15: ch_at_idx = buf_flat[127:120];
        6'd16: ch_at_idx = buf_flat[135:128];
        6'd17: ch_at_idx = buf_flat[143:136];
        6'd18: ch_at_idx = buf_flat[151:144];
        6'd19: ch_at_idx = buf_flat[159:152];
        6'd20: ch_at_idx = buf_flat[167:160];
        6'd21: ch_at_idx = buf_flat[175:168];
        6'd22: ch_at_idx = buf_flat[183:176];
        6'd23: ch_at_idx = buf_flat[191:184];
        6'd24: ch_at_idx = buf_flat[199:192];
        6'd25: ch_at_idx = buf_flat[207:200];
        6'd26: ch_at_idx = buf_flat[215:208];
        6'd27: ch_at_idx = buf_flat[223:216];
        6'd28: ch_at_idx = buf_flat[231:224];
        6'd29: ch_at_idx = buf_flat[239:232];
        6'd30: ch_at_idx = buf_flat[247:240];
        6'd31: ch_at_idx = buf_flat[255:248];
        default: ch_at_idx = 8'h00;
      endcase
    end
  endfunction

  function [7:0] ch_at;
    input [5:0] idx;
    begin
      ch_at = (idx < len_eff) ? ch_at_idx(idx) : 8'h00;
    end
  endfunction

  // helpers
  function [0:0] is_digit; input [7:0] c; begin is_digit = (c >= "0" && c <= "9"); end endfunction
  function [0:0] is_space; input [7:0] c; begin is_space = (c==8'h20) || (c==8'h09); end endfunction
  function signed [24:0] q168_from_int; input integer x; begin q168_from_int = $signed(x) <<< 8; end endfunction
  function signed [24:0] apply_sign; input signed [24:0] v; input neg; begin apply_sign = neg ? -v : v; end endfunction

  // recognizers (canned forms)
  localparam [7:0] CH_LP=8'h28, CH_RP=8'h29;
  wire is_len3 = (len_eff==6'd3);
  wire is_bin_digit = is_len3 &&
                      is_digit(ch_at_idx(0)) && is_digit(ch_at_idx(2)) &&
                      (ch_at_idx(1)=="+" || ch_at_idx(1)=="-" || ch_at_idx(1)=="*" || ch_at_idx(1)=="/" || ch_at_idx(1)=="^");

  wire is_log256 = (len_eff==6'd6) && (ch_at_idx(0)=="l") && (ch_at_idx(1)==CH_LP) &&
                   (ch_at_idx(2)=="2") && (ch_at_idx(3)=="5") && (ch_at_idx(4)=="6") && (ch_at_idx(5)==CH_RP);
  wire is_sin0  = (len_eff==6'd4) && (ch_at_idx(0)=="s") && (ch_at_idx(1)==CH_LP) && (ch_at_idx(2)=="0") && (ch_at_idx(3)==CH_RP);
  wire is_cos0  = (len_eff==6'd4) && (ch_at_idx(0)=="c") && (ch_at_idx(1)==CH_LP) && (ch_at_idx(2)=="0") && (ch_at_idx(3)==CH_RP);
  wire is_tan0  = (len_eff==6'd4) && (ch_at_idx(0)=="t") && (ch_at_idx(1)==CH_LP) && (ch_at_idx(2)=="0") && (ch_at_idx(3)==CH_RP);

  // also allow "pi" letters, and single-byte ?/e tokens
  wire is_token_pi_letters = (len_eff==6'd2) && (ch_at_idx(0)=="p") && (ch_at_idx(1)=="i");
  wire is_token_e_single   = (len_eff==6'd1) && (ch_at_idx(0)=="e");

  wire is_paren3_mul_d =
       (len_eff==6'd7) &&
       (ch_at_idx(0)=="(") && is_digit(ch_at_idx(1)) &&
       (ch_at_idx(2)=="+" || ch_at_idx(2)=="-" || ch_at_idx(2)=="*" || ch_at_idx(2)=="/" || ch_at_idx(2)=="^") &&
       is_digit(ch_at_idx(3)) && (ch_at_idx(4)==")") && (ch_at_idx(5)=="*") && is_digit(ch_at_idx(6));

  wire is_paren3_div_d =
       (len_eff==6'd7) &&
       (ch_at_idx(0)=="(") && is_digit(ch_at_idx(1)) &&
       (ch_at_idx(2)=="+" || ch_at_idx(2)=="-" || ch_at_idx(2)=="*" || ch_at_idx(2)=="/" || ch_at_idx(2)=="^") &&
       is_digit(ch_at_idx(3)) && (ch_at_idx(4)==")") && (ch_at_idx(5)=="/") && is_digit(ch_at_idx(6));

  // -------- states --------
  localparam [4:0]
    S_IDLE    = 5'd0,
    S_DET     = 5'd1,
    // binary path
    S_SCAN1   = 5'd2,
    S_SIGA    = 5'd3,
    S_READA   = 5'd4,
    S_READA_FR= 5'd5,
    S_READOP  = 5'd6,
    S_SIGB    = 5'd7,
    S_READB   = 5'd8,
    S_READB_FR= 5'd9,
    // unary path
    S_U_SKIP  = 5'd10,
    S_U_READ  = 5'd11,
    S_U_FRAC  = 5'd12,
    // ALU
    S_ISSUE1  = 5'd13,
    S_WAIT1   = 5'd14,
    S_ISSUE2  = 5'd15,
    S_WAIT2   = 5'd16,
    S_DONE    = 5'd17;

  reg [4:0]  st;
  reg [5:0]  idx;
  reg [3:0]  op;
  reg signed [24:0] A, B;
  reg [15:0] int_acc;
  reg [9:0]  frac_acc;
  reg [1:0]  frac_cnt;
  reg        sign_a_neg, sign_b_neg, u_neg;
  reg        two_step, u_is_sqrt;
  reg signed [24:0] tmp_val;
  reg               tmp_ovf;

  // pack int+frac -> Q16.8
  function signed [24:0] pack_q168;
    input [15:0] intp; input [9:0] fracv; input [1:0] fcnt;
    integer frac_q;
    begin
      if (fcnt==0)      frac_q = 0;
      else if (fcnt==1) frac_q = (fracv*256 + 5)/10;
      else if (fcnt==2) frac_q = (fracv*256 + 50)/100;
      else              frac_q = (fracv*256 + 500)/1000;
      pack_q168 = ($signed(intp) <<< 8) + $signed(frac_q[15:0]);
    end
  endfunction

  // ---- main FSM ----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= S_IDLE;
      alu_start <= 1'b0; alu_op <= 4'd0; alu_a <= 25'sd0; alu_b <= 25'sd0;
      done_eval <= 1'b0; result_value <= 25'sd0; result_overflow <= 1'b0;
      idx <= 6'd0; op <= OP_ADD; A <= 25'sd0; B <= 25'sd0;
      int_acc <= 16'd0; frac_acc <= 10'd0; frac_cnt <= 2'd0;
      sign_a_neg <= 1'b0; sign_b_neg <= 1'b0; u_neg <= 1'b0; u_is_sqrt <= 1'b0;
      two_step <= 1'b0; tmp_val <= 25'sd0; tmp_ovf <= 1'b0;
    end else begin
      alu_start <= 1'b0;
      done_eval <= 1'b0;

      case (st)
        S_IDLE: if (start_eval) begin
          idx <= 6'd0; op <= OP_ADD; A <= 25'sd0; B <= 25'sd0;
          int_acc <= 16'd0; frac_acc <= 10'd0; frac_cnt <= 2'd0;
          sign_a_neg <= 1'b0; sign_b_neg <= 1'b0; u_neg <= 1'b0; u_is_sqrt <= 1'b0;
          two_step <= 1'b0; tmp_ovf <= 1'b0;
          st <= S_DET;
        end

        // fast canned / whole-token constants
        S_DET: begin
          if (is_paren3_mul_d || is_paren3_div_d) begin
            case (ch_at_idx(2))
              "+": op<=OP_ADD; "-": op<=OP_SUB; "*": op<=OP_MUL; "/": op<=OP_DIV; "^": op<=OP_POW;
              default: op<=OP_ADD;
            endcase
            A <= q168_from_int(ch_at_idx(1)-"0");
            B <= q168_from_int(ch_at_idx(3)-"0");
            two_step <= 1'b1;
            st <= S_ISSUE1;
          end else if (is_log256) begin
            op<=OP_LOG2; A<=25'sd0; B<=q168_from_int(256); two_step<=1'b0; st<=S_ISSUE1;
          end else if (is_sin0) begin
            op<=OP_SIN; A<=25'sd0; B<=25'sd0; st<=S_ISSUE1;
          end else if (is_cos0) begin
            op<=OP_COS; A<=25'sd0; B<=25'sd0; st<=S_ISSUE1;
          end else if (is_tan0) begin
            op<=OP_TAN; A<=25'sd0; B<=25'sd0; st<=S_ISSUE1;
          end else if (is_token_pi_letters || (len_eff==6'd1 && ch_at_idx(0)==TOK_PI)) begin
            op<=OP_ADD; A<=Q168_PI; B<=25'sd0; st<=S_ISSUE1;
          end else if (is_token_e_single) begin
            op<=OP_ADD; A<=Q168_E;  B<=25'sd0; st<=S_ISSUE1;
          end else if (is_bin_digit) begin
            case (ch_at_idx(1))
              "+": op<=OP_ADD; "-": op<=OP_SUB; "*": op<=OP_MUL; "/": op<=OP_DIV; "^": op<=OP_POW;
            endcase
            A <= q168_from_int(ch_at_idx(0)-"0");
            B <= q168_from_int(ch_at_idx(2)-"0");
            two_step <= 1'b0;
            st <= S_ISSUE1;
          end else begin
            idx <= 6'd0;
            st  <= S_SCAN1;
          end
        end

        // ---------- Binary parse with signs ----------
        S_SCAN1: begin
          if (idx >= len_eff) begin
            A <= 25'sd0; B <= 25'sd0; op <= OP_ADD; st<=S_ISSUE1;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if (ch_at(idx)=="l" || ch_at(idx)=="s" || ch_at(idx)=="c" || ch_at(idx)=="t" || ch_at(idx)==TOK_SQRT) begin
            // unary starts
//            if (ch_at(idx)=="l")      op <= OP_LOG2;
            if (ch_at(idx)=="l")      op <= 4'd9;

            else if (ch_at(idx)=="s") op <= OP_SIN;
            else if (ch_at(idx)=="c") op <= OP_COS;
            else if (ch_at(idx)=="t") op <= OP_TAN;
            else                      op <= OP_POW; // ? -> power base^0.5
            u_is_sqrt <= (ch_at(idx)==TOK_SQRT);
            idx <= idx + 1;
            u_neg <= 1'b0;
            st  <= S_U_SKIP;
          end else begin
            // binary: optional sign before A
            sign_a_neg <= 1'b0;
            if (ch_at(idx)=="+" || ch_at(idx)=="-") begin
              sign_a_neg <= (ch_at(idx)=="-");
              idx <= idx + 1;
            end
            st <= S_SIGA;
          end
        end

        S_SIGA: begin
          if (idx >= len_eff) begin
            A <= apply_sign(25'sd0, sign_a_neg); st <= S_DONE;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if ((ch_at(idx)=="p" && (idx+1<len_eff) && ch_at(idx+1)=="i") || ch_at(idx)==TOK_PI) begin
            A <= apply_sign(Q168_PI, sign_a_neg); idx <= idx + ((ch_at(idx)==TOK_PI)?1:2); st <= S_READOP;
          end else if (ch_at(idx)=="e") begin
            A <= apply_sign(Q168_E,  sign_a_neg); idx <= idx + 1; st <= S_READOP;
          end else begin
            int_acc <= 16'd0; frac_acc <= 10'd0; frac_cnt <= 2'd0;
            st <= S_READA;
          end
        end

        S_READA: begin
          if (idx >= len_eff) begin
            A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_a_neg); st <= S_DONE;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if (is_digit(ch_at(idx))) begin
            int_acc <= int_acc*10 + (ch_at(idx)-"0"); idx <= idx + 1;
          end else if (ch_at(idx)==".") begin
            idx <= idx + 1; st <= S_READA_FR;
          end else begin
            A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_a_neg); st <= S_READOP;
          end
        end

        S_READA_FR: begin
          if (idx >= len_eff) begin
            A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_a_neg); st <= S_DONE;
          end else if (is_digit(ch_at(idx))) begin
            if (frac_cnt != 2'd3) begin
              frac_acc <= frac_acc*10 + (ch_at(idx)-"0");
              frac_cnt <= frac_cnt + 1'b1;
            end
            idx <= idx + 1;
          end else begin
            A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_a_neg); st <= S_READOP;
          end
        end

        S_READOP: begin
          if (idx >= len_eff) begin
            st <= S_DONE;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else begin
            case (ch_at(idx))
              "+": op<=OP_ADD; "-": op<=OP_SUB; "*": op<=OP_MUL; "/": op<=OP_DIV; "^": op<=OP_POW;
              default: op<=OP_ADD;
            endcase
            idx <= idx + 1;
            sign_b_neg <= 1'b0;
            st <= S_SIGB;
          end
        end

        S_SIGB: begin
          if (idx >= len_eff) begin
            B <= 25'sd0; st <= S_ISSUE1;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if (ch_at(idx)=="+" || ch_at(idx)=="-") begin
            sign_b_neg <= (ch_at(idx)=="-");
            idx <= idx + 1;
          end else if ((ch_at(idx)=="p" && (idx+1<len_eff) && ch_at(idx+1)=="i") || ch_at(idx)==TOK_PI) begin
            B <= apply_sign(Q168_PI, sign_b_neg); idx <= idx + ((ch_at(idx)==TOK_PI)?1:2); st <= S_ISSUE1;
          end else if (ch_at(idx)=="e") begin
            B <= apply_sign(Q168_E,  sign_b_neg); idx <= idx + 1; st <= S_ISSUE1;
          end else begin
            int_acc <= 16'd0; frac_acc <= 10'd0; frac_cnt <= 2'd0;
            st <= S_READB;
          end
        end

        S_READB: begin
          if (idx >= len_eff) begin
            B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_b_neg); st <= S_ISSUE1;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if (is_digit(ch_at(idx))) begin
            int_acc <= int_acc*10 + (ch_at(idx)-"0"); idx <= idx + 1;
          end else if (ch_at(idx)==".") begin
            idx <= idx + 1; st <= S_READB_FR;
          end else begin
            B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_b_neg); st <= S_ISSUE1;
          end
        end

        S_READB_FR: begin
          if (idx >= len_eff) begin
            B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_b_neg); st <= S_ISSUE1;
          end else if (is_digit(ch_at(idx))) begin
            if (frac_cnt != 2'd3) begin
              frac_acc <= frac_acc*10 + (ch_at(idx)-"0");
              frac_cnt <= frac_cnt + 1'b1;
            end
            idx <= idx + 1;
          end else begin
            B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), sign_b_neg); st <= S_ISSUE1;
          end
        end

        // ---------- Unary parse (l/s/c/t/? ...) with optional sign ----------
        S_U_SKIP: begin
          if (idx >= len_eff) begin
            A<=25'sd0; B<=25'sd0; st<=S_ISSUE1;
          end else if (is_space(ch_at(idx))) begin
            idx <= idx + 1;
          end else if (ch_at(idx)=="(") begin
            idx <= idx + 1;
          end else begin
            // optional sign for the unary argument
            u_neg <= 1'b0;
            if (ch_at(idx)=="+" || ch_at(idx)=="-") begin
              u_neg <= (ch_at(idx)=="-");
              idx   <= idx + 1;
            end
            // constants?
            if ((ch_at(idx)=="p" && (idx+1<len_eff) && ch_at(idx+1)=="i") || ch_at(idx)==TOK_PI) begin
              if (u_is_sqrt) begin
                A<=apply_sign(Q168_PI, u_neg); B<=Q168_HALF; op<=OP_POW; idx<=idx+((ch_at(idx)==TOK_PI)?1:2); st<=S_ISSUE1;
              end else begin
                A<=25'sd0; B<=apply_sign(Q168_PI, u_neg); idx<=idx+((ch_at(idx)==TOK_PI)?1:2); st<=S_ISSUE1;
              end
            end else if (ch_at(idx)=="e") begin
              if (u_is_sqrt) begin
                A<=apply_sign(Q168_E, u_neg); B<=Q168_HALF; op<=OP_POW; idx<=idx+1; st<=S_ISSUE1;
              end else begin
                A<=25'sd0; B<=apply_sign(Q168_E, u_neg); idx<=idx+1; st<=S_ISSUE1;
              end
            end else begin
              int_acc <= 16'd0; frac_acc <= 10'd0; frac_cnt <= 2'd0;
              st <= S_U_READ;
            end
          end
        end

        S_U_READ: begin
          if (idx >= len_eff || is_space(ch_at(idx)) || ch_at(idx)==")") begin
            if (u_is_sqrt) begin
              A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg);
              B <= Q168_HALF; op<=OP_POW; st<=S_ISSUE1;
            end else begin
              B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg); A<=25'sd0; st<=S_ISSUE1;
            end
          end else if (is_digit(ch_at(idx))) begin
            int_acc <= int_acc*10 + (ch_at(idx)-"0"); idx <= idx + 1;
          end else if (ch_at(idx)==".") begin
            idx <= idx + 1; st <= S_U_FRAC;
          end else begin
            if (u_is_sqrt) begin
              A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg);
              B <= Q168_HALF; op<=OP_POW;
            end else begin
              B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg); A<=25'sd0;
            end
            st<=S_ISSUE1;
          end
        end

        S_U_FRAC: begin
          if (idx >= len_eff || is_space(ch_at(idx)) || ch_at(idx)==")") begin
            if (u_is_sqrt) begin
              A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg);
              B <= Q168_HALF; op<=OP_POW;
            end else begin
              B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg); A<=25'sd0;
            end
            st<=S_ISSUE1;
          end else if (is_digit(ch_at(idx))) begin
            if (frac_cnt != 2'd3) begin
              frac_acc <= frac_acc*10 + (ch_at(idx)-"0");
              frac_cnt <= frac_cnt + 1'b1;
            end
            idx <= idx + 1;
          end else begin
            if (u_is_sqrt) begin
              A <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg);
              B <= Q168_HALF; op<=OP_POW;
            end else begin
              B <= apply_sign(pack_q168(int_acc, frac_acc, frac_cnt), u_neg); A<=25'sd0;
            end
            st<=S_ISSUE1;
          end
        end

        // -------- issue to ALU --------
        S_ISSUE1: begin
          two_step <= (is_paren3_mul_d || is_paren3_div_d);
          if (two_step) begin
            alu_op   <= (ch_at_idx(2)=="+"?OP_ADD: ch_at_idx(2)=="-"?OP_SUB: ch_at_idx(2)=="*"?OP_MUL: ch_at_idx(2)=="/"?OP_DIV: OP_POW);
            alu_a    <= q168_from_int(ch_at_idx(1)-"0");
            alu_b    <= q168_from_int(ch_at_idx(3)-"0");
          end else begin
            alu_op <= op; alu_a <= A; alu_b <= B;
          end
          alu_start <= 1'b1;
          st <= S_WAIT1;
        end

        S_WAIT1: if (alu_done) begin
          if (two_step) begin
            tmp_val <= alu_result; tmp_ovf <= alu_overflow;
            if (is_paren3_mul_d) begin
              alu_op<=OP_MUL; alu_a<=alu_result; alu_b<=q168_from_int(ch_at_idx(6)-"0");
            end else begin
              alu_op<=OP_DIV; alu_a<=alu_result; alu_b<=q168_from_int(ch_at_idx(6)-"0");
            end
            alu_start <= 1'b1;
            st <= S_WAIT2;
          end else begin
            result_value    <= alu_result;
            result_overflow <= alu_overflow;
            st <= S_DONE;
          end
        end

        S_WAIT2: if (alu_done) begin
          result_value    <= alu_result;
          result_overflow <= (alu_overflow | tmp_ovf);
          st <= S_DONE;
        end

        S_DONE: begin
          done_eval <= 1'b1;
          st <= S_IDLE;
        end
      endcase
    end
  end
endmodule

`default_nettype wire
