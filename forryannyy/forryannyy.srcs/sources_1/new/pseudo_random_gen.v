`timescale 1ns / 1ps
// changed to 6 bit signed
module random_9bit_signed(
    input clk,
    input rst,
    input enable,  // Enable randomization and capture when high
    output reg signed [8:0] captured_output,  // Captured random value (output when captured)
    output reg captured_valid   // High when enable is high
);

    // LFSR for 6-bit pseudo-random number generation
    // Polynomial: x^6 + x^5 + 1 (maximal length for 6 bits)
    reg [5:0] lfsr = 6'h1;  // Initial seed (non-zero)

    wire feedback = lfsr[5] ^ lfsr[4];  // Feedback bit: lfsr[5] XOR lfsr[4]

    always @(posedge clk) begin
        if (rst) begin
            lfsr <= 6'h1;  // Reset to initial seed
            captured_output <= 0;
            captured_valid <= 0;
        end else begin
            // Always update LFSR for randomness
            lfsr <= {lfsr[4:0], feedback};
            
            // Capture and set valid when enable is high
            if (enable) begin
                // Generate 6-bit unsigned (0-63), convert to signed (-32 to 31), assign to 9-bit
                captured_output <= (lfsr - 6'd32);  // Range: -32 to 31
                captured_valid <= 1;      // Set valid high
            end else begin
                captured_valid <= 0;      // Clear valid when enable is low
            end
        end
    end

endmodule