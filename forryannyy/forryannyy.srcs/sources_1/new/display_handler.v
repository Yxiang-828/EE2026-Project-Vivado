`timescale 1ns / 1ps

module display_handler(
    input clk,
    input reset,
    input [15:0] oled_data,
    input [11:0] vga_pixel_data,

    output [12:0] pixel_index,
    output [7:0] JB,
    output VGA_Hsync,
    output VGA_Vsync,
    output [11:0] VGA_RGB,
    output [9:0] vga_x,
    output [9:0] vga_y,
    output vga_p_tick
);
    
    // --- OLED Logic (unchanged) ---
    wire clk6p25m;
    flexible_timer clk_6p25m(.CLOCK(clk), .frequency(32'd6250000), .SLOW_CLOCK(clk6p25m));
    Oled_Display oled_display_inst(.clk(clk6p25m), .pixel_index(pixel_index), .pixel_data(oled_data),
        .cs(JB[0]), .sdin(JB[1]), .sclk(JB[3]), .d_cn(JB[4]), 
        .resn(JB[5]), .vccen(JB[6]), .pmoden(JB[7]));

    // --- VGA Logic ---
    wire video_on; // Original, undelayed signal

    vga_sync vga_sync_unit (
        .clk(clk), .reset(reset), .hsync(VGA_Hsync), .vsync(VGA_Vsync),
        .video_on(video_on), .p_tick(vga_p_tick), .x(vga_x), .y(vga_y)
    );

    // 7 cycles for graph_renderer + 1 cycle for rgb_reg
    reg video_on_p1, video_on_p2, video_on_p3, video_on_p4;
    reg video_on_p5, video_on_p6, video_on_p7, video_on_p8;
    
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            {video_on_p8, video_on_p7, video_on_p6, video_on_p5, 
             video_on_p4, video_on_p3, video_on_p2, video_on_p1} <= 8'b0;
        end else if (vga_p_tick) begin
            video_on_p1 <= video_on;
            video_on_p2 <= video_on_p1;
            video_on_p3 <= video_on_p2;
            video_on_p4 <= video_on_p3;
            video_on_p5 <= video_on_p4;
            video_on_p6 <= video_on_p5;
            video_on_p7 <= video_on_p6;
            video_on_p8 <= video_on_p7; // This is 8 p_ticks delayed
        end
    end
    
    // rgb buffer (This is the 8th stage for the pixel data)
    reg [11:0] rgb_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            rgb_reg <= 12'd0;
        end else if (vga_p_tick) begin
            rgb_reg <= vga_pixel_data; 
        end
    end

    assign VGA_RGB = (video_on_p8) ? rgb_reg : 12'b0;

endmodule