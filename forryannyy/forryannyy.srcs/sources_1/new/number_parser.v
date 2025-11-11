`timescale 1ns / 1ps

module number_parser(
    input clk,
    input rst,
    
    // Inputs
    input [7:0] ascii_char,
    input ascii_valid,
    input grapher_submode,
    input sw3_signed_mode,           // sw[3]: 1=signed, 0=unsigned
    
    // Outputs
    output reg signed [8:0] parsed_number,  // 9-bit signed (-256 to 255)
    output reg parsed_valid,                // Pulse when number is ready
    output reg [1:0] error_code             // Error code
);

    // Error codes
    localparam ERR_NONE = 2'b00;
    localparam ERR_SYNTAX = 2'b01;
    localparam ERR_OVERFLOW = 2'b10;

    // Internal parsing state
    reg [1:0] temp_error;
    reg is_negative;
    reg [3:0] digit_count;
    reg clear_next_cycle;

    // Separate digit registers (no division needed)
    reg [3:0] digit_regs [0:2];
    reg digit_valid [0:2];

    // INPUT PIPELINE REGISTERS
    reg [7:0] ascii_char_reg;
    reg ascii_valid_reg;
    reg grapher_submode_reg;
    reg sw3_signed_mode_reg;

    always @(posedge clk) begin
        if (rst) begin
            ascii_char_reg <= 0;
            ascii_valid_reg <= 0;
            grapher_submode_reg <= 0;
            sw3_signed_mode_reg <= 0;
        end else begin
            ascii_char_reg <= ascii_char;
            ascii_valid_reg <= ascii_valid;
            grapher_submode_reg <= grapher_submode;
            sw3_signed_mode_reg <= sw3_signed_mode;
        end
    end

    // Character classification
    wire is_digit_reg = (ascii_char_reg >= 8'h30 && ascii_char_reg <= 8'h39);
    wire is_minus_reg = (ascii_char_reg == 8'h2D);
    wire is_equal_reg = (ascii_char_reg == 8'h3D);
    wire is_clear_reg = (ascii_char_reg == 8'h43);
    wire is_delete_reg = (ascii_char_reg == 8'h44);

    // Rebuild temp_number from digit registers (no division)
    wire signed [9:0] temp_number;
    wire temp_number_valid;
    assign temp_number = (digit_valid[2] ? digit_regs[2] * 100 : 0) +
                         (digit_valid[1] ? digit_regs[1] * 10 : 0) +
                         (digit_valid[0] ? digit_regs[0] : 0);
    assign temp_number_valid = digit_valid[0] || digit_valid[1] || digit_valid[2];

    // Main parsing logic
    always @(posedge clk) begin
        if (rst) begin
            parsed_number <= 0;
            parsed_valid <= 0;
            error_code <= ERR_NONE;
            temp_error <= ERR_NONE;
            is_negative <= 0;
            digit_count <= 0;
            clear_next_cycle <= 0;
            digit_regs[0] <= 0;
            digit_regs[1] <= 0;
            digit_regs[2] <= 0;
            digit_valid[0] <= 0;
            digit_valid[1] <= 0;
            digit_valid[2] <= 0;
        end else begin
            parsed_valid <= 0;

            if (clear_next_cycle) begin
                is_negative <= 0;
                digit_count <= 0;
                digit_regs[0] <= 0;
                digit_regs[1] <= 0;
                digit_regs[2] <= 0;
                digit_valid[0] <= 0;
                digit_valid[1] <= 0;
                digit_valid[2] <= 0;
                clear_next_cycle <= 0;
            end 
            else if (ascii_valid_reg && grapher_submode_reg) begin
                if (is_clear_reg) begin
                    // Clear all parsing state
                    is_negative <= 0;
                    digit_count <= 0;
                    digit_regs[0] <= 0;
                    digit_regs[1] <= 0;
                    digit_regs[2] <= 0;
                    digit_valid[0] <= 0;
                    digit_valid[1] <= 0;
                    digit_valid[2] <= 0;
                    error_code <= ERR_NONE;
                    temp_error <= ERR_NONE;
                end
                else if (is_delete_reg) begin
                    // Shift digits on delete
                    if (digit_count > 0) begin
                        digit_count <= digit_count - 1;
                        digit_regs[0] <= digit_regs[1];
                        digit_regs[1] <= digit_regs[2];
                        digit_regs[2] <= 0;
                        digit_valid[0] <= digit_valid[1];
                        digit_valid[1] <= digit_valid[2];
                        digit_valid[2] <= 0;
                    end else if (is_negative) begin
                        // If deleting the negative sign (no digits entered yet)
                        is_negative <= 0;
                    end
                end
                else if (is_equal_reg) begin
                    // Parse and output number
                    if (temp_number_valid) begin
                        // Check mode: signed (sw3=1) or unsigned (sw3=0)
                        if (sw3_signed_mode_reg) begin
                            // SIGNED MODE: Allow negative, range -255 to 255
                            if (is_negative) begin
                                if (temp_number > 255) begin
                                    parsed_number <= -9'd255;
                                    error_code <= ERR_OVERFLOW;
                                end else begin
                                    parsed_number <= -temp_number[8:0];
                                    error_code <= temp_error;
                                end
                            end else begin
                                if (temp_number > 255) begin
                                    parsed_number <= 9'd255;
                                    error_code <= ERR_OVERFLOW;
                                end else begin
                                    parsed_number <= temp_number[8:0];
                                    error_code <= temp_error;
                                end
                            end
                        end else begin
                            // UNSIGNED MODE: Ignore negative sign, range 0 to 255
                            if (is_negative) begin
                                // Error: minus sign not allowed in unsigned mode
                                error_code <= ERR_SYNTAX;
                                parsed_number <= 0;
                            end else begin
                                if (temp_number > 255) begin
                                    parsed_number <= 9'd255;
                                    error_code <= ERR_OVERFLOW;
                                end else begin
                                    parsed_number <= temp_number[8:0];
                                    error_code <= temp_error;
                                end
                            end
                        end
                        
                        parsed_valid <= 1;
                        clear_next_cycle <= 1;
                        temp_error <= ERR_NONE;
                    end else begin
                        error_code <= ERR_SYNTAX;
                    end
                end
                else if (is_digit_reg) begin
                    // Accumulate digits
                    if (digit_count < 3) begin
                        digit_regs[digit_count] <= ascii_char_reg - 8'h30;
                        digit_valid[digit_count] <= 1;
                        digit_count <= digit_count + 1;
                        temp_error <= ERR_NONE;
                    end else begin
                        temp_error <= ERR_OVERFLOW;
                    end
                end
                else if (is_minus_reg) begin
                    // Handle minus sign based on mode
                    if (sw3_signed_mode_reg) begin
                        // SIGNED MODE: Allow minus at start
                        if (digit_count == 0 && !is_negative && !temp_number_valid) begin
                            is_negative <= 1;
                            temp_error <= ERR_NONE;
                        end else begin
                            temp_error <= ERR_SYNTAX;
                            error_code <= ERR_SYNTAX;
                        end
                    end else begin
                        // UNSIGNED MODE: Minus not allowed
                        temp_error <= ERR_SYNTAX;
                        error_code <= ERR_SYNTAX;
                    end
                end
            end
        end
    end

endmodule
