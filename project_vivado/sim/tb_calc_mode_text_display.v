`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench: Calculator Mode Text Display Verification
//
// This testbench verifies the complete data flow:
// 1. Keypad input → Parser accumulation
// 2. Parser output → Display buffer
// 3. Display buffer → VGA text rendering
// 4. Font ROM → VGA pixel output
//
// Test Cases:
// - Type "1" → Check if '1' (ASCII 0x31) appears in buffer[0]
// - Type "123" → Check if buffer contains 0x31, 0x32, 0x33
// - Verify text_length increments correctly
// - Verify VGA rendering shows pixels at correct coordinates
//////////////////////////////////////////////////////////////////////////////////

module tb_calc_mode_text_display();

    // Clock generation
    reg clk;
    reg reset;

    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz clock (10ns period)

    // Keypad inputs
    reg [4:0] key_code;
    reg key_valid;

    // VGA coordinates (we'll manually set these to test text box area)
    reg [9:0] vga_x;
    reg [9:0] vga_y;

    // Outputs
    wire [11:0] vga_data;
    wire [5:0] debug_display_length;

    // Instantiate calc_mode_module
    calc_mode_module uut (
        .clk(clk),
        .reset(reset),
        .key_code(key_code),
        .key_valid(key_valid),
        .pixel_index(13'h0),  // Not used
        .oled_data(),         // Not used
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(vga_data),
        .debug_display_length(debug_display_length)
    );

    // Access internal signals for debugging
    wire [255:0] display_buffer = uut.display_buffer_flat;
    wire [5:0] text_length = uut.display_length;

    // Test stimulus
    integer test_case;
    integer x, y;
    integer pixel_count;
    integer black_pixels;

    initial begin
        $display("========================================");
        $display("Calculator Mode Text Display Testbench");
        $display("========================================");

        // Initialize
        reset = 1;
        key_code = 5'd0;
        key_valid = 0;
        vga_x = 10'd0;
        vga_y = 10'd0;
        test_case = 0;

        // Wait for reset
        #20;
        reset = 0;
        #20;

        $display("\n[TIME %0t] Reset released, starting tests...", $time);
        $display("Initial state:");
        $display("  text_length = %d", text_length);
        $display("  debug_display_length = %d", debug_display_length);
        $display("  display_buffer[7:0] = 0x%02h", display_buffer[7:0]);

        // =====================================================================
        // TEST 1: Press key '1' and verify parser accumulates
        // =====================================================================
        test_case = 1;
        $display("\n========================================");
        $display("TEST 1: Press key '1' (key_code = 5'd1)");
        $display("========================================");

        #20;
        key_code = 5'd1;  // Key '1'
        key_valid = 1;
        #10;  // Hold for 1 clock cycle
        key_valid = 0;
        #50;  // Wait for parser FSM to process

        $display("[TIME %0t] After pressing '1':", $time);
        $display("  text_length = %d (expected: 1)", text_length);
        $display("  debug_display_length = %d (expected: 1)", debug_display_length);
        $display("  display_buffer[7:0] = 0x%02h (expected: 0x31 = '1')", display_buffer[7:0]);

        if (text_length == 1 && display_buffer[7:0] == 8'h31) begin
            $display("  ✓ TEST 1 PASSED: Parser accumulated '1' correctly");
        end else begin
            $display("  ✗ TEST 1 FAILED: Parser did not accumulate '1'");
            if (text_length == 0) begin
                $display("    ERROR: text_length is still 0 - Parser FSM not transitioning!");
                $display("    POSSIBLE CAUSES:");
                $display("    1. Parser not receiving key_valid signal");
                $display("    2. Parser FSM stuck in IDLE state");
                $display("    3. Reset signal not properly released");
            end
            if (display_buffer[7:0] != 8'h31) begin
                $display("    ERROR: display_buffer[7:0] = 0x%02h (not 0x31)", display_buffer[7:0]);
                $display("    POSSIBLE CAUSES:");
                $display("    1. key_to_ascii function incorrect");
                $display("    2. Buffer write logic broken");
            end
        end

        // =====================================================================
        // TEST 2: Press key '2' and verify accumulation continues
        // =====================================================================
        test_case = 2;
        $display("\n========================================");
        $display("TEST 2: Press key '2' (key_code = 5'd2)");
        $display("========================================");

        #20;
        key_code = 5'd2;  // Key '2'
        key_valid = 1;
        #10;
        key_valid = 0;
        #50;

        $display("[TIME %0t] After pressing '2':", $time);
        $display("  text_length = %d (expected: 2)", text_length);
        $display("  display_buffer[7:0] = 0x%02h (expected: 0x31 = '1')", display_buffer[7:0]);
        $display("  display_buffer[15:8] = 0x%02h (expected: 0x32 = '2')", display_buffer[15:8]);

        if (text_length == 2 && display_buffer[7:0] == 8'h31 && display_buffer[15:8] == 8'h32) begin
            $display("  ✓ TEST 2 PASSED: Parser accumulated '2' correctly");
        end else begin
            $display("  ✗ TEST 2 FAILED: Parser did not accumulate '2' correctly");
        end

        // =====================================================================
        // TEST 3: Press key '3' and verify "123" in buffer
        // =====================================================================
        test_case = 3;
        $display("\n========================================");
        $display("TEST 3: Press key '3' (key_code = 5'd3)");
        $display("========================================");

        #20;
        key_code = 5'd3;  // Key '3'
        key_valid = 1;
        #10;
        key_valid = 0;
        #50;

        $display("[TIME %0t] After pressing '3':", $time);
        $display("  text_length = %d (expected: 3)", text_length);
        $display("  display_buffer[7:0]   = 0x%02h (expected: 0x31 = '1')", display_buffer[7:0]);
        $display("  display_buffer[15:8]  = 0x%02h (expected: 0x32 = '2')", display_buffer[15:8]);
        $display("  display_buffer[23:16] = 0x%02h (expected: 0x33 = '3')", display_buffer[23:16]);

        if (text_length == 3 &&
            display_buffer[7:0] == 8'h31 &&
            display_buffer[15:8] == 8'h32 &&
            display_buffer[23:16] == 8'h33) begin
            $display("  ✓ TEST 3 PASSED: Parser accumulated '123' correctly");
        end else begin
            $display("  ✗ TEST 3 FAILED: Parser did not accumulate '123' correctly");
        end

        // =====================================================================
        // TEST 4: VGA Text Rendering - Check character '1' at position (15, 15)
        // =====================================================================
        test_case = 4;
        $display("\n========================================");
        $display("TEST 4: VGA Text Rendering");
        $display("========================================");

        // Text box starts at (15, 15)
        // Character 0 is at x=15-22, y=15-22 (8x8 font)

        $display("\nScanning VGA coordinates for character '1' rendering...");

        // Set VGA coordinates to character 0, row 0, col 0
        #20;
        vga_x = 10'd15;
        vga_y = 10'd15;
        #30;  // Wait for BRAM pipeline (1 cycle latency + registered output)

        $display("[TIME %0t] VGA output at (15, 15):", $time);
        $display("  vga_data = 0x%03h", vga_data);
        $display("  Expected: Font pixel data (should not be 0x888 or 0xFFF uniformly)");

        // Scan multiple pixels to see if ANY rendering happens
        pixel_count = 0;
        black_pixels = 0;

        $display("\nScanning 8x8 region at (15,15) to (22,22)...");
        for (y = 15; y < 23; y = y + 1) begin
            for (x = 15; x < 23; x = x + 1) begin
                vga_x = x;
                vga_y = y;
                #30;  // Wait for pipeline
                pixel_count = pixel_count + 1;
                if (vga_data == 12'h000) begin
                    black_pixels = black_pixels + 1;
                end
                if (x == 15) begin  // Print first column for debugging
                    $display("  (x=%0d, y=%0d): vga_data = 0x%03h", x, y, vga_data);
                end
            end
        end

        $display("\nScan results:");
        $display("  Total pixels: %0d", pixel_count);
        $display("  Black pixels (0x000): %0d", black_pixels);

        if (black_pixels > 0 && black_pixels < 64) begin
            $display("  ✓ TEST 4 PASSED: Font rendering detected (%0d black pixels)", black_pixels);
        end else if (black_pixels == 0) begin
            $display("  ✗ TEST 4 FAILED: No black pixels found - Font not rendering!");
            $display("    POSSIBLE CAUSES:");
            $display("    1. Font ROM not initialized (all zeros)");
            $display("    2. BRAM pipeline timing incorrect");
            $display("    3. Bit-slicing extracting wrong character");
            $display("    4. current_char always returning 0x20 (space)");
        end else if (black_pixels == 64) begin
            $display("  ✗ TEST 4 FAILED: All pixels black - Border or logic error!");
        end

        // =====================================================================
        // TEST 5: Check border rendering (should be black at y=10)
        // =====================================================================
        test_case = 5;
        $display("\n========================================");
        $display("TEST 5: Border Rendering");
        $display("========================================");

        vga_x = 10'd15;
        vga_y = 10'd10;  // Top border
        #30;

        $display("[TIME %0t] Border pixel at (15, 10):", $time);
        $display("  vga_data = 0x%03h (expected: 0x000 = black)", vga_data);

        if (vga_data == 12'h000) begin
            $display("  ✓ TEST 5 PASSED: Border renders correctly");
        end else begin
            $display("  ✗ TEST 5 FAILED: Border not black");
        end

        // =====================================================================
        // TEST 6: Check background (should be white inside text box)
        // =====================================================================
        test_case = 6;
        $display("\n========================================");
        $display("TEST 6: Background Rendering");
        $display("========================================");

        vga_x = 10'd100;  // Far right inside text box (no text there)
        vga_y = 10'd20;
        #30;

        $display("[TIME %0t] Background pixel at (100, 20):", $time);
        $display("  vga_data = 0x%03h (expected: 0xFFF = white)", vga_data);

        if (vga_data == 12'hFFF) begin
            $display("  ✓ TEST 6 PASSED: Background renders correctly");
        end else begin
            $display("  ✗ TEST 6 FAILED: Background not white");
        end

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Final parser state:");
        $display("  text_length = %d", text_length);
        $display("  debug_display_length = %d", debug_display_length);
        $display("  Buffer contents (hex): %h", display_buffer[23:0]);
        $display("  Buffer contents (ASCII):");
        if (text_length > 0) $display("    Char 0: 0x%02h ('%c')", display_buffer[7:0], display_buffer[7:0]);
        if (text_length > 1) $display("    Char 1: 0x%02h ('%c')", display_buffer[15:8], display_buffer[15:8]);
        if (text_length > 2) $display("    Char 2: 0x%02h ('%c')", display_buffer[23:16], display_buffer[23:16]);

        $display("\n========================================");
        $display("Testbench Complete");
        $display("========================================");
        $finish;
    end

endmodule
