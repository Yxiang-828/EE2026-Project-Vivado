`timescale 1ns / 1ps

// ADDER USING BITWISE ADDITION AND FULL ADDERS
module adder_module(
    input clr,
    input signed [24:0] number1,
    input signed [24:0] number2,
    output signed [24:0] number_out,
    output overflow_flag    
);

    wire signed [25:0] carry; // carry[0] = 0, carry[25] is final carry out
    wire signed [24:0] sum;
    
    assign carry[0] = 1'b0; // initial carry in
    
    genvar i;
    generate
        for (i = 0; i < 25; i = i + 1) begin : adder_bits
            full_adder fa (
                .a(number1[i]),
                .b(number2[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    
    assign overflow_flag = ~clr ? (carry[24] ^ carry[25]) : 1'b0;
    assign number_out = ~clr ? (overflow_flag ? 25'b0 : sum) : 25'b0;

endmodule

// Full Adder module
module full_adder(
    input a,
    input b,
    input cin,
    output sum,
    output cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule