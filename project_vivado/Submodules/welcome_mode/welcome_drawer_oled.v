`timescale 1ns / 1ps

module welcome_drawer_oled(
    input [12:0] pixel_index,  // Pixel index (0 to 6143 for 96x64 OLED)
    output reg [15:0] oled_data    // Output: 1 = white pixel, 0 = black pixel
);

    // Make the entire screen black (draw_pixel = 0 for all pixels)
    always @(*) begin
        oled_data = 1'b0;  // Black screen for all pixels
    end

endmodule
