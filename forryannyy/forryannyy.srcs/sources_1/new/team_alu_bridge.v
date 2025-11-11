`timescale 1ns/1ps
`default_nettype none

module team_alu_bridge (
  input  wire               clk,
  input  wire               rst_n,          // active-low
  input  wire               alu_start,
  input  wire        [3:0]  alu_op,         // 0:+ 1:- 2:* 3:/ 4:^ 5:log2 6:sin 7:cos 8:tan 9:ln
  input  wire signed [24:0] alu_a,          // Q16.8
  input  wire signed [24:0] alu_b,          // Q16.8
  output reg                alu_done,
  output reg  signed [24:0] alu_result,     // Q16.8
  output reg                alu_overflow
);
  // ---------- opcodes ----------
  localparam OP_ADD=0, OP_SUB=1, OP_MUL=2, OP_DIV=3, OP_POW=4, OP_LOG2=5, OP_SIN=6, OP_COS=7, OP_TAN=8, OP_LN=9;

  // ---------- constants ----------
  // ln(2) ? 0.693147 * 256 ? 177.44 -> 177 in Q16.8
  localparam signed [24:0] Q168_LN2 = 25'sd177;

  reg [3:0]          op_q;
  reg signed [24:0]  a_q, b_q;

  // add/sub comb (SUB = A + (-B))
  wire signed [24:0] b_neg = 25'sd0 - b_q;
  wire signed [24:0] add_out;
  wire               add_ovf;
  adder_module u_add (
    .clr(1'b0),
    .number1(a_q),
    .number2(op_q==OP_SUB ? b_neg : b_q),
    .number_out(add_out),
    .overflow_flag(add_ovf)
  );

  // engines (active-HIGH clr; drive 0 to run)
  reg mul_clr=1'b1, div_clr=1'b1, pow_clr=1'b1, log_clr=1'b1, tri_clr=1'b1;

  wire [24:0] mul_out; wire mul_done, mul_ovf;
  multiply_module u_mul (.clk(clk), .clr(mul_clr), .number1(a_q), .number2(b_q),
                         .number_out(mul_out), .overflow(mul_ovf), .done(mul_done));

  // *** ENABLE divider engine (no inline div) ***
  wire signed [24:0] div_out; wire div_done, div_ovf;
  divider_module u_div (.clk(clk), .clr(div_clr), .a(a_q), .b(b_q),
                        .val(div_out), .done(div_done), .overflow(div_ovf));

  wire signed [24:0] pow_out; wire pow_done, pow_ovf;
  power_module    u_pow (.clk(clk), .clr(pow_clr), .base(a_q), .exponent(b_q),
                         .result(pow_out), .done(pow_done), .overflow(pow_ovf));

  wire signed [24:0] log_out; wire log_done, log_ovf;
  log2_module      u_log (.clk(clk), .clr(log_clr), .a(b_q),
                          .val(log_out), .done(log_done), .overflow(log_ovf));

  // trig select: 00=sin, 01=cos, 10=tan
  reg [1:0] trig_sel;
  always @* begin
    case (op_q)
      OP_SIN: trig_sel = 2'b00;
      OP_COS: trig_sel = 2'b01;
      default: trig_sel = 2'b10;
    endcase
  end
  wire signed [24:0] tri_out; wire tri_done, tri_ovf;
  trigo_module u_trig (.clk(clk), .clr(tri_clr), .trig_select(trig_sel), .angle(b_q),
                       .result(tri_out), .done(tri_done), .overflow(tri_ovf));

  // mux for engine result (non-ADD/SUB, non-LN)
  wire sub_done =
       (op_q==OP_MUL  && mul_done)  ||
       (op_q==OP_DIV  && div_done)  ||   // <- include DIV
       (op_q==OP_POW  && pow_done)  ||
       (op_q==OP_LOG2 && log_done)  ||
       ((op_q==OP_SIN || op_q==OP_COS || op_q==OP_TAN) && tri_done);

  wire signed [24:0] sub_val =
       (op_q==OP_MUL ) ? mul_out  :
       (op_q==OP_DIV ) ? div_out  :  // <- include DIV
       (op_q==OP_POW ) ? pow_out  :
       (op_q==OP_LOG2) ? log_out  :
                         tri_out;

  wire sub_ovf =
       (op_q==OP_MUL ) ? mul_ovf  :
       (op_q==OP_DIV ) ? div_ovf  :  // <- include DIV
       (op_q==OP_POW ) ? pow_ovf  :
       (op_q==OP_LOG2) ? log_ovf  :
                         tri_ovf;

  // FSM
  localparam [1:0] S_IDLE=2'd0, S_RUN=2'd1, S_LATCH=2'd2, S_PULSE=2'd3;
  reg [1:0] st;
  reg  signed [24:0] res_q;
  reg                ovf_q;

  // LN two-step phase flag
  reg                ln_phase;   // 0: waiting log2, 1: waiting mul(log2*ln2)

  task stop_engines; begin
    mul_clr<=1'b1; div_clr<=1'b1; pow_clr<=1'b1; log_clr<=1'b1; tri_clr<=1'b1;
  end endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st<=S_IDLE; op_q<=4'd0; a_q<=25'sd0; b_q<=25'sd0;
      alu_done<=1'b0; alu_result<=25'sd0; alu_overflow<=1'b0;
      res_q<=25'sd0; ovf_q<=1'b0; stop_engines();
      ln_phase<=1'b0;
    end else begin
      alu_done<=1'b0;

      case (st)
        S_IDLE: begin
          stop_engines();
          if (alu_start) begin
            op_q<=alu_op; a_q<=alu_a; b_q<=alu_b;

            // exact-zero trig shortcut
            if ((alu_op==OP_SIN || alu_op==OP_COS || alu_op==OP_TAN) && (alu_b==25'sd0)) begin
              case (alu_op)
                OP_SIN: res_q <= 25'sd0;
                OP_COS: res_q <= (25'sd1 <<< 8);
                default: res_q <= 25'sd0;
              endcase
              ovf_q <= 1'b0; st <= S_PULSE;
            end
            // add/sub are combinational
            else if (alu_op==OP_ADD || alu_op==OP_SUB) begin
              st <= S_LATCH;
            end
            // all other ops via engines (DIV included)
            else begin
              case (alu_op)
                OP_MUL  : mul_clr <= 1'b0;
                OP_DIV  : div_clr <= 1'b0;               // <- start divider engine
                OP_POW  : pow_clr <= 1'b0;
                OP_LOG2 : log_clr <= 1'b0;
                OP_LN   : begin ln_phase <= 1'b0; log_clr <= 1'b0; end // start log2(b_q)
                default : tri_clr <= 1'b0; // sin/cos/tan
              endcase
              st <= S_RUN;
            end
          end
        end

        S_RUN: begin
          if (op_q==OP_LN) begin
            // Phase 0: wait for log2(b_q)
            if (!ln_phase) begin
              if (log_done) begin
                stop_engines();
                a_q      <= log_out;
                b_q      <= Q168_LN2;
                mul_clr  <= 1'b0;
                ln_phase <= 1'b1;
              end
            end else begin
              // Phase 1: wait for multiply
              if (mul_done) begin
                res_q <= mul_out;
                ovf_q <= (mul_ovf | log_ovf);
                stop_engines();
                ln_phase <= 1'b0;
                st <= S_LATCH;
              end
            end
          end else if (sub_done) begin
            res_q<=sub_val; ovf_q<=sub_ovf; stop_engines(); st<=S_LATCH;
          end
        end

        S_LATCH: begin
          if (op_q==OP_ADD || op_q==OP_SUB) begin res_q<=add_out; ovf_q<=add_ovf; end
          st<=S_PULSE;
        end

        S_PULSE: begin
          alu_result<=res_q; alu_overflow<=ovf_q; alu_done<=1'b1; st<=S_IDLE;
        end
      endcase
    end
  end
endmodule

`default_nettype wire
