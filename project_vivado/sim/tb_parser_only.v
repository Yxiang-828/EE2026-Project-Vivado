`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench: Data Parser Accumulator - Isolated Test
// 
// This testbench ONLY tests the parser to see if it's accumulating data.
// If this fails, we know the parser is broken.
// If this passes, we know the problem is in VGA rendering.
//////////////////////////////////////////////////////////////////////////////////

module tb_parser_only();

    reg clk;
    reg rst;
    reg [4:0] key_code;
    reg key_valid;
    
    wire [24:0] parsed_number;
    wire number_ready;
    wire [3:0] operator_code;
    wire operator_ready;
    wire [255:0] display_text;
    wire [5:0] text_length;
    
    // Instantiate parser
    data_parser_accumulator uut (
        .clk(clk),
        .rst(rst),
        .key_code(key_code),
        .key_valid(key_valid),
        .parsed_number(parsed_number),
        .number_ready(number_ready),
        .operator_code(operator_code),
        .operator_ready(operator_ready),
        .precedence(),
        .equals_pressed(),
        .clear_pressed(),
        .delete_pressed(),
        .left_paren_pressed(),
        .right_paren_pressed(),
        .display_text(display_text),
        .text_length(text_length),
        .overflow_error(),
        .invalid_input_error()
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        $display("========================================");
        $display("Parser Accumulation Test");
        $display("========================================");
        
        // Initialize
        rst = 1;
        key_code = 0;
        key_valid = 0;
        
        #20;
        rst = 0;
        #20;
        
        $display("\n[%0t] Initial state:", $time);
        $display("  text_length = %d", text_length);
        $display("  display_text[7:0] = 0x%02h", display_text[7:0]);
        
        // =====================================================================
        // TEST: Press '1'
        // =====================================================================
        $display("\n[%0t] Pressing key '1' (key_code=1)...", $time);
        key_code = 5'd1;
        key_valid = 1;
        #10;
        key_valid = 0;
        #50;
        
        $display("[%0t] After '1':", $time);
        $display("  text_length = %d (expected: 1)", text_length);
        $display("  display_text[7:0] = 0x%02h (expected: 0x31)", display_text[7:0]);
        
        if (text_length == 0) begin
            $display("\n  ❌ CRITICAL FAILURE: text_length is still 0!");
            $display("  ❌ Parser FSM is NOT transitioning from IDLE!");
            $display("  ❌ Check:");
            $display("     1. Is key_valid actually reaching the parser?");
            $display("     2. Is the FSM stuck in IDLE?");
            $display("     3. Is rst properly released?");
            $finish;
        end
        
        // =====================================================================
        // TEST: Press '2'
        // =====================================================================
        $display("\n[%0t] Pressing key '2' (key_code=2)...", $time);
        key_code = 5'd2;
        key_valid = 1;
        #10;
        key_valid = 0;
        #50;
        
        $display("[%0t] After '2':", $time);
        $display("  text_length = %d (expected: 2)", text_length);
        $display("  display_text[7:0] = 0x%02h", display_text[7:0]);
        $display("  display_text[15:8] = 0x%02h (expected: 0x32)", display_text[15:8]);
        
        // =====================================================================
        // TEST: Press '3'
        // =====================================================================
        $display("\n[%0t] Pressing key '3' (key_code=3)...", $time);
        key_code = 5'd3;
        key_valid = 1;
        #10;
        key_valid = 0;
        #50;
        
        $display("[%0t] After '3':", $time);
        $display("  text_length = %d (expected: 3)", text_length);
        $display("  display_text[7:0] = 0x%02h (char 0)", display_text[7:0]);
        $display("  display_text[15:8] = 0x%02h (char 1)", display_text[15:8]);
        $display("  display_text[23:16] = 0x%02h (char 2, expected: 0x33)", display_text[23:16]);
        
        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("\n========================================");
        $display("PARSER TEST SUMMARY");
        $display("========================================");
        
        if (text_length == 3 && 
            display_text[7:0] == 8'h31 && 
            display_text[15:8] == 8'h32 && 
            display_text[23:16] == 8'h33) begin
            $display("✅ PARSER WORKS: Successfully accumulated '123'");
            $display("   Problem is in VGA rendering, not parser!");
        end else begin
            $display("❌ PARSER BROKEN:");
            $display("   text_length = %d (expected: 3)", text_length);
            $display("   Char 0: 0x%02h (expected: 0x31)", display_text[7:0]);
            $display("   Char 1: 0x%02h (expected: 0x32)", display_text[15:8]);
            $display("   Char 2: 0x%02h (expected: 0x33)", display_text[23:16]);
        end
        
        $finish;
    end

endmodule
