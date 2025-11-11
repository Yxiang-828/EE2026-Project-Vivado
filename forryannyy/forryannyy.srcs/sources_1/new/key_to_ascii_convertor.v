`timescale 1ns / 1ps

module key_to_ascii_converter(
    input clk,
    input rst,
    
    // Keypad input
    input [4:0] key_code,
    input key_valid,
    
    // ASCII output (for single-char functions)
    output reg [7:0] ascii_char,
    output reg char_valid,
    
    // Multi-character function output
    output reg is_multichar,
    output reg [2:0] char_count,
    output reg [23:0] multichar_data 
);

    // Key code constants
    localparam KEY_0 = 5'd0, KEY_1 = 5'd1, KEY_2 = 5'd2, KEY_3 = 5'd3;
    localparam KEY_4 = 5'd4, KEY_5 = 5'd5, KEY_6 = 5'd6, KEY_7 = 5'd7;
    localparam KEY_8 = 5'd8, KEY_9 = 5'd9;
    localparam KEY_ADD = 5'd10, KEY_SUB = 5'd11, KEY_MUL = 5'd12, KEY_DIV = 5'd13;
    localparam KEY_POW = 5'd14;
    localparam KEY_SIN = 5'd15, KEY_COS = 5'd16, KEY_TAN = 5'd17, KEY_LN = 5'd18;
    localparam KEY_SQRT = 5'd19;
    localparam KEY_PI = 5'd20, KEY_E = 5'd21;
    localparam KEY_DOT = 5'd22, KEY_EQUAL = 5'd23, KEY_CLEAR = 5'd24;
    localparam KEY_LPAREN = 5'd25, KEY_RPAREN = 5'd26;
    localparam KEY_DELETE = 5'd27, KEY_FACTORIAL = 5'd28;
    localparam KEY_X = 5'd29;

    always @(posedge clk) begin
        if (rst) begin
            ascii_char <= 8'h00;
            char_valid <= 0;
            is_multichar <= 0;
            char_count <= 0;
            multichar_data <= 24'h000000;
        end else begin
            char_valid <= 0;
            is_multichar <= 0;
            char_count <= 0;
            
            if (key_valid) begin
                char_valid <= 1;
                
                case (key_code)
                    // Digits
                    KEY_0: begin ascii_char <= 8'h30; char_count <= 1; end
                    KEY_1: begin ascii_char <= 8'h31; char_count <= 1; end
                    KEY_2: begin ascii_char <= 8'h32; char_count <= 1; end
                    KEY_3: begin ascii_char <= 8'h33; char_count <= 1; end
                    KEY_4: begin ascii_char <= 8'h34; char_count <= 1; end
                    KEY_5: begin ascii_char <= 8'h35; char_count <= 1; end
                    KEY_6: begin ascii_char <= 8'h36; char_count <= 1; end
                    KEY_7: begin ascii_char <= 8'h37; char_count <= 1; end
                    KEY_8: begin ascii_char <= 8'h38; char_count <= 1; end
                    KEY_9: begin ascii_char <= 8'h39; char_count <= 1; end
                    
                    // Operators
                    KEY_ADD: begin ascii_char <= 8'h2B; char_count <= 1; end
                    KEY_SUB: begin ascii_char <= 8'h2D; char_count <= 1; end
                    KEY_MUL: begin ascii_char <= 8'h2A; char_count <= 1; end
                    KEY_DIV: begin ascii_char <= 8'h2F; char_count <= 1; end
                    KEY_POW: begin ascii_char <= 8'h5E; char_count <= 1; end
                    KEY_DOT: begin ascii_char <= 8'h2E; char_count <= 1; end
                    KEY_LPAREN: begin ascii_char <= 8'h28; char_count <= 1; end
                    KEY_RPAREN: begin ascii_char <= 8'h29; char_count <= 1; end
                    KEY_FACTORIAL: begin ascii_char <= 8'h21; char_count <= 1; end
                    
                    // Special chars
                    KEY_SQRT: begin ascii_char <= 8'hFB; char_count <= 1; end
                    KEY_PI: begin ascii_char <= 8'hE3; char_count <= 1; end
                    KEY_E: begin ascii_char <= 8'h65; char_count <= 1; end
                    KEY_X: begin ascii_char <= 8'h78; char_count <= 1; end
                    
                    // Control (no symbols)
                    KEY_EQUAL: begin ascii_char <= 8'h3D; char_count <= 0; end
                    KEY_CLEAR: begin ascii_char <= 8'h43; char_count <= 0; end
                    KEY_DELETE: begin ascii_char <= 8'h44; char_count <= 0; end
                    
                    // Multi-char functions
                    KEY_SIN: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h6E, 8'h69, 8'h73};  // 'n','i','s'
                        ascii_char <= 8'h73;
                    end
                    
                    KEY_COS: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h73, 8'h6F, 8'h63};  // 's','o','c'
                        ascii_char <= 8'h63;
                    end
                    
                    KEY_TAN: begin
                        is_multichar <= 1;
                        char_count <= 3;
                        multichar_data <= {8'h6E, 8'h61, 8'h74};  // 'n','a','t'
                        ascii_char <= 8'h74;
                    end
                    
                    KEY_LN: begin
                        is_multichar <= 1;
                        char_count <= 2;
                        multichar_data <= {8'h00, 8'h6E, 8'h6C};  // 0,'n','l'
                        ascii_char <= 8'h6C;
                    end
                    
                    default: begin
                        ascii_char <= 8'h3F;
                        char_count <= 0;
                    end
                endcase
            end
        end
    end

endmodule