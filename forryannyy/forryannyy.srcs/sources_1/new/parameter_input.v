`timescale 1ns / 1ps

module parameter_input(
    input clk,
    input enable,  
    input signed [8:0] parsed_number,  
    input parsed_valid,                
    input [2:0] selected_graph_type,
    output reg [1:0] current_param_index,
    output reg signed [8:0] linear_slope,      
    output reg signed [8:0] linear_intercept,  
    output reg signed [8:0] quadratic_a,       
    output reg signed [8:0] quadratic_b,       
    output reg signed [8:0] quadratic_c,       
    output reg signed [8:0] cubic_a,           
    output reg signed [8:0] cubic_b,           
    output reg signed [8:0] cubic_c,           
    output reg signed [8:0] cubic_d,           
    output reg signed [8:0] exp_scale,
    output reg signed [8:0] ln_scale,          
    output reg signed [8:0] sin_amplitude,     
    output reg signed [8:0] cos_amplitude,     
    output reg signed [8:0] tan_amplitude      
);

    reg [1:0] param_index;
    reg [1:0] max_param_index;

    initial begin
        param_index = 0;
        current_param_index = 0;
        linear_slope = 9'd2;
        linear_intercept = 9'd0;
        quadratic_a = 9'd1;
        quadratic_b = 9'd0;
        quadratic_c = 9'd0;
        cubic_a = 9'd1;
        cubic_b = 9'd0;
        cubic_c = 9'd0;
        cubic_d = 9'd0;
        exp_scale = 9'd1;
        ln_scale = 9'd20;
        sin_amplitude = 9'd10;
        cos_amplitude = 9'd10;
        tan_amplitude = 9'd5;
    end

    always @(*) begin
        case (selected_graph_type)
            3'b000: max_param_index = 1;  // Linear: 2 params
            3'b001: max_param_index = 2;  // Quadratic: 3 params
            3'b010: max_param_index = 3;  // Cubic: 4 params
            3'b011: max_param_index = 0;  // Sin: 1 param
            3'b100: max_param_index = 0;  // Cos: 1 param
            3'b101: max_param_index = 0;  // Tan: 1 param
            3'b110: max_param_index = 0;  // Exp: 1 param (was 1, now 0)
            3'b111: max_param_index = 0;  // Ln: 1 param
            default: max_param_index = 0;
        endcase
    end

    always @(posedge clk) begin
        if (!enable) begin  
            linear_slope <= 9'd2;
            linear_intercept <= 9'd0;
            quadratic_a <= 9'd1;
            quadratic_b <= 9'd0;
            quadratic_c <= 9'd0;
            cubic_a <= 9'd1;
            cubic_b <= 9'd0;
            cubic_c <= 9'd0;
            cubic_d <= 9'd0;
            exp_scale <= 9'd1;
            ln_scale <= 9'd20;
            sin_amplitude <= 9'd10;
            cos_amplitude <= 9'd10;
            tan_amplitude <= 9'd5;
            param_index <= 0;
            current_param_index <= 0;
        end else if (parsed_valid) begin  
            case (selected_graph_type)
                3'b000: case(param_index)
                            0: linear_slope <= parsed_number;
                            1: linear_intercept <= parsed_number;
                        endcase
                3'b001: case(param_index)
                            0: quadratic_a <= parsed_number;
                            1: quadratic_b <= parsed_number;
                            2: quadratic_c <= parsed_number;
                        endcase
                3'b010: case(param_index)
                            0: cubic_a <= parsed_number;
                            1: cubic_b <= parsed_number;
                            2: cubic_c <= parsed_number;
                            3: cubic_d <= parsed_number;
                        endcase
                3'b011: sin_amplitude <= parsed_number;
                3'b100: cos_amplitude <= parsed_number;
                3'b101: tan_amplitude <= parsed_number;
                3'b110: exp_scale <= parsed_number;
                3'b111: ln_scale <= parsed_number;
                default: ;
            endcase
            
            if (param_index < max_param_index)
                param_index <= param_index + 1;
            else
                param_index <= 0;
            
            if (param_index < max_param_index)
                current_param_index <= param_index + 1;
            else
                current_param_index <= 0;
        end
    end
endmodule