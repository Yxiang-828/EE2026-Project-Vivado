// -------------------------------------------------------------
// eh_stream_capture.v  (unchanged; already light)
// -------------------------------------------------------------
module eh_stream_capture #(
  parameter MAXN = 32
)(
  input        clk,
  input        rst,              // active-high
  input  [7:0] ascii_char,
  input        ascii_valid,
  output reg [8*MAXN-1:0] buf_flat,   // packed little-endian: [8*i +: 8]
  output reg [5:0]        len,        // 0..MAXN
  output                  start_pulse // one cycle when '=' seen
);

  wire is_eq  = ascii_valid && (ascii_char == 8'h3D);
  wire is_clr = ascii_valid && (ascii_char == 8'h43); // 'C'
  wire is_del = ascii_valid && (ascii_char == 8'h44); // 'D'

  assign start_pulse = is_eq;

  integer i;
  always @(posedge clk) begin
    if (rst) begin
      len <= 6'd0;
      for (i=0; i<MAXN; i=i+1) buf_flat[8*i +: 8] <= 8'h20;
    end else begin
      if (is_clr) begin
        len <= 6'd0;
        for (i=0; i<MAXN; i=i+1) buf_flat[8*i +: 8] <= 8'h20;
      end else if (is_del) begin
        if (len != 0) begin
          len <= len - 1'b1;
          buf_flat[8*(len-1) +: 8] <= 8'h20;
        end
      end else if (ascii_valid && !is_eq) begin
        if (len < MAXN) begin
          buf_flat[8*len +: 8] <= ascii_char;
          len <= len + 1'b1;
        end
      end
    end
  end
endmodule
