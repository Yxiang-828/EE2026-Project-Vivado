`timescale 1ns / 1ps

module welcome_mode_module (

    // Mode Input
    input  [2:0]  current_main_mode,  // Expanded to 3 bits for MODE_POLY

    // Physical Input
    input  [4:0]  btn,
    input         clk,
    input  [15:0] sw,

    // New Mode Handshake
    output        mode_req,
    output [2:0]  mode_target,  // Expanded to 3 bits for MODE_POLY
    input         mode_ack,

    // OLED Interface
    input  [12:0] pixel_index,
    output [15:0] oled_data,

    // VGA Interface
    input  [9:0]  vga_x,
    input  [9:0]  vga_y,
    output [11:0] vga_data
);
    
    localparam MODE_WELCOME = 3'b001;

    welcome_drawer_oled welcome_drawer_oled_inst (
        .pixel_index(pixel_index),
        .oled_data(oled_data)
    );

    welcome_drawer_vga welcome_drawer_vga_inst (
        .clk(clk),
        .current_main_mode(current_main_mode),
        .btn(btn),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(vga_data),
        .mode_req(mode_req),
        .mode_target(mode_target),
        .mode_ack(mode_ack)
    );
    
endmodule
