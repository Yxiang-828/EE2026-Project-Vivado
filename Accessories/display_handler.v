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
    output [9:0] vga_y
);
    
    // Clock for OLED
    wire clk6p25m;
    flexible_timer clk_6p25m(
        .CLOCK(clk),
        .frequency(32'd6250000), 
        .SLOW_CLOCK(clk6p25m)
    );
    
    // Oled display instance
    Oled_Display oled_display_inst(
        .clk(clk6p25m), 
        .pixel_index(pixel_index),
        .pixel_data(oled_data),
        .cs(JB[0]), 
        .sdin(JB[1]), 
        .sclk(JB[3]), 
        .d_cn(JB[4]), 
        .resn(JB[5]), 
        .vccen(JB[6]),
        .pmoden(JB[7])
    );

    wire video_on;

    // Instantiate vga_sync to get coordinates and timing
    vga_sync vga_sync_unit (
        .clk(clk),
        .reset(reset),
        .hsync(VGA_Hsync),
        .vsync(VGA_Vsync),
        .video_on(video_on),
        .p_tick(vga_p_tick),
        .x(vga_x),
        .y(vga_y)
    );

    // rgb buffer: latch external pixel data on pixel tick
    reg [11:0] rgb_reg;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            rgb_reg <= 12'd0;
        end else if (vga_p_tick) begin
            rgb_reg <= vga_pixel_data; // external pixel value
        end
    end

    assign VGA_RGB = (video_on) ? rgb_reg : 12'b0;

endmodule