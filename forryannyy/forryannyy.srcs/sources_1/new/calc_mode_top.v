`timescale 1ns / 1ps

module calc_mode_top(
    input clk,
    input reset,
    input [1:0] current_main_mode,
    
    // Shared input chain connections
    output calculator_keypad_request,
    input input_system_enable,
    
    // Shared buffer inputs (READ-ONLY)
    input [255:0] shared_equation_buffer,
    input [4:0] shared_equation_length,
    input shared_equation_complete,
    
    // ASCII input for processing
    input [7:0] ascii_char,
    input ascii_valid,
    
    // Display outputs
    input [12:0] jc_pixel_index,
    output [15:0] calculator_screen_oled_ja,
    output [11:0] calculator_screen_vga,
    
    // VGA position inputs
    input [9:0] vga_x,
    input [9:0] vga_y,
    
    // Debug outputs
    output [13:0] led,
    output [7:0] seg,
    output [3:0] an,
    
    // Switches
    input [15:0] sw
);

    localparam MODE_CALCULATOR = 2'b10;
    
    // Enable calculator when in calculator mode
    wire calc_enable = (current_main_mode == MODE_CALCULATOR);
    assign calculator_keypad_request = calc_enable;
    
    // ========================================
    // === ERROR CHECKING & EXECUTION CHAIN ===
    // ========================================
    
    // Expression error checker outputs
    wire        chk_done;
    wire        chk_err_any;
    wire [3:0]  chk_err_code;
    wire [5:0]  chk_err_pos;
    
    // Stream capture outputs
    wire [8*32-1:0] eh_buf;
    wire [5:0]      eh_len;
    wire            eh_start;
    wire clr_p = ascii_valid && (ascii_char == 8'h43);  // 'C'
    // Stream capture module
    eh_stream_capture #(.MAXN(32)) eh_cap (
        .clk(clk),
        .rst(reset || !calc_enable||clr_p),
        .ascii_char(ascii_char),
        .ascii_valid(ascii_valid && calc_enable),
        .buf_flat(eh_buf),
        .len(eh_len),
        .start_pulse(eh_start)
    );
    
    wire start_p = eh_start;
    
    // Error handling module
    error_handling #(.MAXN(32)) expr_check (
        .clk(clk),
        .rst_n(~(reset || !calc_enable||clr_p)),
        .start(start_p),
        .buf_flat(eh_buf),
        .len(eh_len),
        .done(chk_done),
        .err_any(chk_err_any),
        .err_code(chk_err_code),
        .err_pos(chk_err_pos)
    );
    
    // Generate ok_pulse when checker finishes without error
    reg chk_done_q;
    always @(posedge clk or posedge reset) begin
        if (reset || !calc_enable) 
            chk_done_q <= 1'b0;
        else 
            chk_done_q <= chk_done;
    end
    
    wire ok_pulse = (chk_done & ~chk_done_q) & ~chk_err_any;
    
    // Expression executor
    wire        exec_done;
    wire        exec_ovf;
    wire signed [24:0] exec_result;
    wire        exec_start = ok_pulse;
    
    expr_execute_no_check #(.MAXN(32)) u_exec (
        .clk(clk),
        .rst_n(~(reset || !calc_enable||clr_p)),
        .start_p(exec_start),
        .buf_flat(eh_buf),
        .len(eh_len),
        .chk_done(chk_done),
        .chk_err_any(chk_err_any),
        .done(exec_done),
        .result_value(exec_result),
        .result_overflow(exec_ovf)
    );
    
    // Error handler output latch
    reg        eh_valid;
    reg        eh_err_any_l;
    reg [3:0]  eh_err_code_l;
    reg [5:0]  eh_err_pos_l;
    
    always @(posedge clk or posedge reset) begin
        if (reset || !calc_enable) begin
            eh_valid      <= 1'b0;
            eh_err_any_l  <= 1'b0;
            eh_err_code_l <= 4'd0;
            eh_err_pos_l  <= 6'd0;
        end else begin
            if (chk_done) begin
                eh_valid      <= 1'b1;
                eh_err_any_l  <= chk_err_any;
                eh_err_code_l <= chk_err_code;
                eh_err_pos_l  <= chk_err_pos;
            end
            else if (start_p) begin
                eh_valid      <= 1'b0;
                eh_err_any_l  <= 1'b0;
                eh_err_code_l <= 4'd0;
                eh_err_pos_l  <= 6'd0;
            end
            else if (ascii_valid && (ascii_char == 8'h43)) begin // 'C'
                eh_valid      <= 1'b0;
                eh_err_any_l  <= 1'b0;
                eh_err_code_l <= 4'd0;
                eh_err_pos_l  <= 6'd0;
            end
        end
    end
       

    // ========================================
    // === 7-SEGMENT DISPLAY ===
    // ========================================
    
    wire [7:0] seg_drv;
    wire [3:0] an_drv;
    
    // Normal mode: turn off 7-seg
    reg [3:0] d3 = 4'hE;
    reg [3:0] d2 = 4'hE;
    reg [3:0] d1 = 4'hE;
    reg [3:0] d0 = 4'hE;
    reg [3:0] dot_mask = 4'b0000;
    
    sevenseg_driver u_seg (
      .clk(clk),
      .val3(d3), .val2(d2), .val1(d1), .val0(d0),
      .dot_on(dot_mask),
      .seg(seg_drv),
      .an(an_drv)
    );
    // =======================================================
    // 7-SEG ERROR/OVERFLOW OVERRIDE
    // =======================================================
    
    wire [3:0] err_code = eh_err_code_l[3:0];
    wire       has_err  = eh_valid && eh_err_any_l;
    wire       has_ovf  = 1'b0;
    
    // Decide which label to show (overflow wins over checker error)
    reg [7:0] c3, c2, c1, c0; // 4 characters to show (left?right)
    always @* begin
      if (has_ovf) begin
        // Overflow ? "EOVE"
        c3="E"; c2="O"; c1="V"; c0="E";
      end else if (has_err) begin
        // Map checker error codes to tags
        case (err_code)
          4'd1: begin c3="E"; c2="E"; c1="M"; c0="P"; end // E_EMPTY  -> EEMP
          4'd2: begin c3="E"; c2="O"; c1="P"; c0="E"; end // E_SEQ    -> EOPE
          4'd3: begin c3="E"; c2="P"; c1="A"; c0="R"; end // E_PAREN  -> EPAR
          4'd4: begin c3="E"; c2="F"; c1="M"; c0="T"; end // E_NUMFMT -> EFMT
          4'd5: begin c3="E"; c2="Z"; c1="E"; c0="R"; end // E_DIV0   -> EZER
          4'd6: begin c3="E"; c2="R"; c1="N"; c0="G"; end // E_RANGE_IN -> ERNG
          default: begin c3="E"; c2="-"; c1="-"; c0="-"; end
        endcase
      end else begin
        // no override ? these are ignored in mux below
        c3="b"; c2="b"; c1="b"; c0="b";
      end
    end
    
    // Encode one character to 7-seg
    function [7:0] seg_for_char;
      input [7:0] ch;
      begin
        case (ch)
          // digits
          "0": seg_for_char = 8'b11000000;
          "1": seg_for_char = 8'b11111001;
          "2": seg_for_char = 8'b10100100;
          "3": seg_for_char = 8'b10110000;
          "4": seg_for_char = 8'b10011001;
          "5": seg_for_char = 8'b10010010;
          "6": seg_for_char = 8'b10000010;
          "7": seg_for_char = 8'b11111000;
          "8": seg_for_char = 8'b10000000;
          "9": seg_for_char = 8'b10010000;
          // letters used in tags (7-seg approximations)
          "A": seg_for_char = 8'b10001000;
          "E": seg_for_char = 8'b10000110;
          "F": seg_for_char = 8'b10001110;
          "M": seg_for_char = 8'b10100011; 
          "N": seg_for_char = 8'b11001000; 
          "O": seg_for_char = 8'b11000000; 
          "P": seg_for_char = 8'b10001100;
          "R": seg_for_char = 8'b10001001; 
          "T": seg_for_char = 8'b10000111; 
          "V": seg_for_char = 8'b11000001; 
          "Z": seg_for_char = 8'b10100100; 
          "-": seg_for_char = 8'b10111111;
          "b": seg_for_char = 8'b11111111; 
          default: seg_for_char = 8'b11111111;
        endcase
      end
    endfunction
    
    // Simple time-multiplex scanner for the 4 chars
    reg [15:0] scan_cnt;
    always @(posedge clk or posedge reset) begin
      if (reset) scan_cnt <= 16'd0;
      else       scan_cnt <= scan_cnt + 16'd1;
    end
    wire [1:0] sel = scan_cnt[15:14];
    
    reg [3:0] an_err;  
    reg [7:0] seg_err; 
    always @* begin
      an_err  = 4'b1111;
      seg_err = 8'hFF;
      case (sel)
        2'd0: begin an_err = 4'b0111; seg_err = seg_for_char(c3); end // leftmost
        2'd1: begin an_err = 4'b1011; seg_err = seg_for_char(c2); end
        2'd2: begin an_err = 4'b1101; seg_err = seg_for_char(c1); end
        2'd3: begin an_err = 4'b1110; seg_err = seg_for_char(c0); end // rightmost
      endcase
    end
    
    // Final mux: override normal driver when error/overflow active
    wire use_override = has_ovf | has_err;
    assign seg = use_override ? seg_err : seg_drv;
    assign an  = use_override ? an_err  : an_drv;
    
    // ========================================
    // === DISPLAY OUTPUTS ===
    // ========================================
    
    // Combined display module for input equation and output result
    calculator_mode_output_drawer vga_drawer (
        .clk(clk),
        .reset(reset),
        .clr_p(clr_p),
        .current_main_mode(current_main_mode),
        
        // Input equation signals (top display)
        .shared_buffer(shared_equation_buffer),
        .shared_length(shared_equation_length),
        .shared_complete(shared_equation_complete),
        
        // Output result signal (bottom display)
        .number_input(exec_result),
        
        // Error and execution status
        .exec_done(exec_done),
        .has_error(eh_err_any_l),
        .exec_overflow(exec_ovf),
        
        // VGA signals
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_data(calculator_screen_vga)
    );
    
    // OLED JA is black for calculator mode
    assign calculator_screen_oled_ja = 16'h0000;
    
    // Error LEDs
    assign led[9] = eh_err_any_l;
    assign led[8] = eh_err_code_l[3];
    assign led[7] = eh_err_code_l[2];
    assign led[6] = eh_err_code_l[1];
    assign led[5] = eh_err_code_l[0];

endmodule