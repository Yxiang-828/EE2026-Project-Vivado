`timescale 1ns / 1ps

module off_module(
    output [15:0] off_screen_oled,
    output [11:0] off_screen_vga
);

    assign off_screen_oled = 16'h0000;
    assign off_screen_vga  = 12'h000;

endmodule