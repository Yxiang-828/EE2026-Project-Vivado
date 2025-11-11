`timescale 1ns / 1ps

// MULTIPLY MODULE USING SHIFT AND ADD ALGORITHM
module multiply_module(
    input clk,
    input clr,
    input signed [24:0] number1,
    input signed [24:0] number2,
    output reg [24:0] number_out,
    output reg overflow,
    output reg done
);

    wire [24:0] sm_num1, sm_num2;
    wire overflow_num1, overflow_num2;

    twos_complement_to_sign_magnitude twos_complement_to_sign_magnitude_num1(
        .in_num(number1),
        .out_num(sm_num1),
        .overflow(overflow_num1)
    );

    twos_complement_to_sign_magnitude twos_complement_to_sign_magnitude_num2(
        .in_num(number2),
        .out_num(sm_num2),
        .overflow(overflow_num2)
    );

    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam WAIT_ACCUMULATE = 3'b011;
    localparam ACCUMULATE = 3'b100;
    localparam WAIT_DONE = 3'b101;
    localparam DONE = 3'b110;

    reg sign;
    reg [49:0] product, addend;
    reg [4:0] bit_index;
    reg [23:0] num1_val, num2_val;
    reg overflow_calc;
    wire [24:0] result;

    wire [49:0] adder_result;
    
    adder50 adder50_inst (
        .a(product),
        .b(addend),
        .cin(1'b0),
        .sum(adder_result),
        .cout()
    );

    sign_magnitude_to_twos_complement sign_magnitude_to_twos_complement_result(
        .in_num({sign, product[31:8]}),
        .out_num(result)
    ); 

    always @ (posedge clk or posedge clr) begin
        if (clr) begin
            number_out <= 25'b0;
            overflow <= 1'b0;
            done <= 1'b0;

            sign <= 1'b0;
            product <= 50'b0;
            addend <= 50'b0;    
            bit_index <= 5'b0;
            state <= IDLE;

        end else begin
            case (state)

                IDLE: 
                begin
                    if (~clr) begin
                        state <= SETUP;
                    end
                end
                
                SETUP:
                begin 
                    num1_val <= sm_num1[23:0];
                    num2_val <= sm_num2[23:0];
                    
                    if (overflow_num1 | overflow_num2 | sm_num1[23:0] == 24'b0 | sm_num2[23:0] == 24'b0) begin
                        sign <= 1'b0;
                        overflow_calc <= 0;
                        state <= DONE;
                    end else begin
                        sign <= sm_num1[24] ^ sm_num2[24];
                        overflow_calc <= 0;
                        state <= CALCULATE;
                    end
                end

              CALCULATE:
              begin
                  if (bit_index < 24) begin 
                      if (num2_val[bit_index]) begin
                          addend <= num1_val << bit_index;
                          state <= ACCUMULATE;
                      end else begin
                          addend <= 50'b0;
                          bit_index <= bit_index + 1;
                      end
                  end else begin
                      overflow_calc <= |product[48:32];
                      state <= WAIT_DONE;
                  end
              end

              ACCUMULATE:
              begin
                  product <= adder_result;
                  bit_index <= bit_index + 1;
                  state <= CALCULATE;
              end

              WAIT_DONE:
              begin
                  state <= DONE;
              end

              DONE:
              begin
                  number_out <= (overflow_calc | overflow_num1 | overflow_num2) ? 25'b0 : result;
                  overflow <= overflow_calc | overflow_num1 | overflow_num2;
                  done <= 1'b1;
              end
            endcase
        end  
    end
endmodule

// 50-bit adder module using full_adder
module adder50 (
    input [49:0] a,
    input [49:0] b,
    input cin,
    output [49:0] sum,
    output cout
);
    wire [50:0] carry;
    assign carry[0] = cin;
    genvar i;
    generate
        for (i = 0; i < 50; i = i + 1) begin : adder_bits
            full_adder fa (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    assign cout = carry[50];
endmodule
