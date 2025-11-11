`timescale 1ns / 1ps

module sw_debouncer_posedge (
    input  wire clk,
    input  wire reset,
    input  wire sw_in,         // Raw switch input
    output reg  sw_posedge     // One-cycle pulse on posedge ONLY
);

    localparam integer DEBOUNCE_COUNT = 500_000;  // ~5ms at 100MHz

    reg [18:0] count = 0;
    reg sw_stable = 0;     // Debounced stable level
    reg sw_prev = 0;       // Previous cycle value (for edge detection)

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            sw_stable <= 0;
            sw_prev <= 0;
            sw_posedge <= 0;
        end else begin
            // Debounce logic
            if (sw_in != sw_stable) begin
                if (count < DEBOUNCE_COUNT - 1) begin
                    count <= count + 1;
                end else begin
                    sw_stable <= sw_in;  // Accept new switch state
                    count <= 0;
                end
            end else begin
                count <= 0;  // Reset counter when stable
            end

            // Edge detection (posedge only)
            sw_prev <= sw_stable;
            sw_posedge <= sw_stable && !sw_prev;  // One-cycle pulse
        end
    end
endmodule