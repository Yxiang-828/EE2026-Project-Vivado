`timescale 1ns/1ps
`default_nettype none
////////////////////////////////////////////////////////////////////////////////
// expr_execute_no_check.v  (pipelined high-performance)
////////////////////////////////////////////////////////////////////////////////
module expr_execute_no_check #(
  parameter integer MAXN = 32
)(
  input  wire               clk,
  input  wire               rst_n,
  input  wire               start_p,
  input  wire [8*MAXN-1:0]  buf_flat,
  input  wire [5:0]         len,
  input  wire               chk_done,
  input  wire               chk_err_any,
  output reg                done,
  output reg  signed [24:0] result_value,
  output reg                result_overflow
);

  // handshake wires
  wire                pe_alu_start;
  wire [3:0]          pe_alu_op;
  wire signed [24:0]  pe_alu_a, pe_alu_b;
  wire                alu_done;
  wire signed [24:0]  alu_result;
  wire                alu_ovf;

  // =========================================================
  // stage 1: precedence evaluator (parser)
  // =========================================================
  precedence_eval #(.MAXN(MAXN)) u_pe (
    .clk(clk),
    .rst_n(rst_n),
    .start_eval(start_p),
    .buf_flat(buf_flat),
    .len(len),
    .alu_start(pe_alu_start),
    .alu_op(pe_alu_op),
    .alu_a(pe_alu_a),
    .alu_b(pe_alu_b),
    .alu_done(alu_done),
    .alu_result(alu_result),
    .alu_overflow(alu_ovf),
    .done_eval(),                  // unused internal
    .result_value(),
    .result_overflow()
  );

  // =========================================================
  // stage 1.5: pipeline registers (reduce timing)
  // =========================================================
  reg                alu_start_r;
  reg [3:0]          alu_op_r;
  reg signed [24:0]  alu_a_r, alu_b_r;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      alu_start_r <= 0;
      alu_op_r    <= 0;
      alu_a_r     <= 0;
      alu_b_r     <= 0;
    end else begin
      alu_start_r <= pe_alu_start;
      alu_op_r    <= pe_alu_op;
      alu_a_r     <= pe_alu_a;
      alu_b_r     <= pe_alu_b;
    end
  end

  // =========================================================
  // stage 2: ALU bridge
  // =========================================================
  team_alu_bridge u_alu (
    .clk(clk),
    .rst_n(rst_n),
    .alu_start(alu_start_r),
    .alu_op(alu_op_r),
    .alu_a(alu_a_r),
    .alu_b(alu_b_r),
    .alu_done(alu_done),
    .alu_result(alu_result),
    .alu_overflow(alu_ovf)
  );

  // =========================================================
  // stage 3: result latch (short feedback path)
  // =========================================================
  reg [1:0] done_sync;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done_sync <= 0;
      done <= 0;
      result_value <= 0;
      result_overflow <= 0;
    end else begin
      done_sync <= {done_sync[0], alu_done};
      if (alu_done) begin
        done <= 1'b1;
        result_value <= alu_result;
        result_overflow <= alu_ovf;
      end else if (done_sync[1]) begin
        done <= 1'b0; // clear after one cycle
      end
    end
  end

endmodule
`default_nettype wire
