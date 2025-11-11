`timescale 1ns / 1ps

module twos_complement_to_sign_magnitude(
    input  wire signed [24:0] in_num,      // Input in two's complement
    output reg  signed [24:0] out_num,     // Output in sign-magnitude
    output reg overflow                     // Overflow flag
);
    always @(*) begin
        if (in_num == 25'h1000000) begin  // Most negative number (-2^24), magnitude doesn't fit
            overflow = 1'b1;
            out_num = 25'h0;  // Or some default value
        end else if (in_num[24] == 1'b1) begin
            overflow = 1'b0;
            out_num = {1'b1, ((~in_num[23:0] + 1'b1) & 24'hFFFFFF)};
        end else begin
            overflow = 1'b0;
            out_num = in_num;
        end
    end
endmodule

module sign_magnitude_to_twos_complement(
    input  wire signed [24:0] in_num,      // Input in sign-magnitude
    output reg  signed [24:0] out_num       // Output in two's complement
);
    always @(*) begin
        if (in_num[24] == 1'b1 && in_num[23:0] == 24'h000000) begin  // -0, treat as 0
            out_num = 25'h0;
        end else if (in_num[24] == 1'b1) begin
            // Proper two's complement: negate the magnitude, do not set sign bit manually
            out_num = (~{1'b0, in_num[23:0]} + 1'b1);
        end else begin
            out_num = in_num;
        end
    end
endmodule
