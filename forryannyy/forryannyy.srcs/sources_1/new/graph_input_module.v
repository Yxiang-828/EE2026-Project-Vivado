`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 16:28:10
// Design Name: 
// Module Name: graph_input_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module menu_selector(
    input clk,
    input [4:0] btn,
    input enable,                    // Enable this menu
    input [3:0] max_options,         // Maximum number of options (0-based)
    output reg [3:0] selected_option,
    output reg selection_confirmed
);

    // Button edge detection
    reg [4:0] btn_prev;
    wire [4:0] btn_rising_edge;
    assign btn_rising_edge = btn & ~btn_prev;

    always @(posedge clk) begin
        btn_prev <= btn;
        
        if (!enable) begin
            selected_option <= 0;
            selection_confirmed <= 0;
        end else begin
            // Navigate up with btn[1]
            if (btn_rising_edge[1]) begin
                if (selected_option == 0)
                    selected_option <= max_options;
                else
                    selected_option <= selected_option - 1;
            end
            
            // Navigate down with btn[4]
            if (btn_rising_edge[4]) begin
                if (selected_option == max_options)
                    selected_option <= 0;
                else
                    selected_option <= selected_option + 1;
            end
            
            // Confirm selection with btn[0]
            if (btn_rising_edge[0]) begin
                selection_confirmed <= 1;
            end else if (!btn[0]) begin
                selection_confirmed <= 0;
            end
        end
    end

endmodule