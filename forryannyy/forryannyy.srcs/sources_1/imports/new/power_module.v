`timescale 1ns / 1ps

module power_module(
    input clk,
    input clr,
    input signed [24:0] base,
    input signed [24:0] exponent,
    output reg signed [24:0] result,
    output reg done,
    output reg overflow
);
    
    // States
    localparam IDLE = 3'b000;
    localparam COMPUTE_LOG = 3'b001;
    localparam WAIT_LOG = 3'b010;
    localparam MULTIPLY = 3'b011;
    localparam WAIT_MULTIPLY = 3'b100;
    localparam COMPUTE_POW2 = 3'b101;
    localparam WAIT_POW2 = 3'b110;
    localparam DONE_STATE = 3'b111;

    reg [2:0] state;
    
    // Intermediate results
    reg log2_clr = 1'b1;
    reg signed [24:0] log2_input;  // Added input register for log2
    wire signed [24:0] log2_result;
    wire log2_done, log2_overflow;
    
    reg mult_clr = 1'b1;
    wire signed [24:0] mult_result;
    wire mult_done, mult_overflow;
    
    reg pow2_clr = 1'b1;
    wire signed [24:0] pow2_result;
    wire pow2_done, pow2_overflow;
    
    // Instantiate log2 module
    log2_module log2_inst (
        .clk(clk),
        .clr(log2_clr),
        .a(log2_input),
        .val(log2_result),
        .done(log2_done),
        .overflow(log2_overflow)
    );
    
    // Instantiate multiply module
    multiply_module mult_inst (
        .clk(clk),
        .clr(mult_clr),
        .number1(log2_result),
        .number2(exponent),
        .number_out(mult_result),
        .done(mult_done),
        .overflow(mult_overflow)
    );
    
    // Instantiate pow2 module
    pow2_module pow2_inst (
        .clk(clk),
        .clr(pow2_clr),
        .x(mult_result),
        .val(pow2_result),
        .done(pow2_done),
        .overflow(pow2_overflow)
    );
    
    // Control logic
    always @(posedge clk or posedge clr) begin
        if (clr) begin
            log2_clr <= 1'b1;
            mult_clr <= 1'b1;
            pow2_clr <= 1'b1;
            result <= 25'b0;
            done <= 1'b0;
            overflow <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    // Check special cases first
                    if (base == 25'b0) begin
                        // 0^y = 0 for y > 0
                        // 0^y = undefined for y <= 0
                        if (exponent[24] == 1'b1 || exponent == 25'b0) begin
                            result <= 25'b0;
                            overflow <= 1'b1;
                        end else begin
                            result <= 25'b0;
                            overflow <= 1'b0;
                        end
                        state <= DONE_STATE;
                    end else if (exponent == 25'b0) begin
                        // x^0 = 1
                        result <= {1'b0, 16'h0001, 8'h00}; // 1.0 in fixed point
                        overflow <= 1'b0;
                        state <= DONE_STATE;
                    end else if (base[24] == 1'b1) begin
                        // Negative base case
                        if (exponent[7:0] != 8'b0) begin
                            // Non-integer exponent -> would give complex number
                            result <= 25'b0;
                            overflow <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Integer exponent -> calculate abs(base)^exponent then fix sign
                            done <= 1'b0;
                            overflow <= 1'b0;
                            state <= COMPUTE_LOG;
                            // Use absolute value of base for log2
                            log2_input <= -base;
                            log2_clr <= 1'b0;
                        end
                    end else begin
                        // Positive base - normal computation
                        done <= 1'b0;
                        overflow <= 1'b0;
                        state <= COMPUTE_LOG;
                        log2_input <= base;  // Use base directly for positive numbers
                        log2_clr <= 1'b0;
                    end
                end
                
                COMPUTE_LOG: begin
                    if (log2_done) begin
                        if (log2_overflow) begin
                            result <= 25'b0;
                            overflow <= 1'b1;
                            state <= DONE_STATE;
                            $display("LOG2 Stage: OVERFLOW");
                        end else begin
                            state <= MULTIPLY;
                            mult_clr <= 1'b0;
                        end
                    end
                end
                
                MULTIPLY: begin
                    if (mult_done) begin
                        if (mult_overflow) begin
                            result <= 25'b0;
                            overflow <= 1'b1;
                            state <= DONE_STATE;
                            $display("MULTIPLY Stage: OVERFLOW");
                        end else begin
                            state <= COMPUTE_POW2;
                            pow2_clr <= 1'b0;
                        end
                    end
                end
                
                COMPUTE_POW2: begin
                    if (pow2_done) begin
                        if (pow2_overflow) begin
                            result <= 25'b0;
                            overflow <= 1'b1;
                            state <= DONE_STATE;
                            $display("POW2 Stage: OVERFLOW");
                        end else begin
                            // For negative base, check if exponent is odd to determine sign
                            if (base[24] == 1'b1 && exponent[8] == 1'b1) begin
                                // Negative base with odd exponent -> result should be negative
                                result <= -pow2_result;
                            end else begin
                                // Positive base or negative base with even exponent -> result is positive
                                result <= pow2_result;
                            end
                            overflow <= 1'b0;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule


module pow2_module(
    input clk,
    input clr,
    input signed [24:0] x,
    output reg signed [24:0] val,
    output reg done,
    output reg overflow
);
    // States
    localparam IDLE = 3'b000;
    localparam CONVERT = 3'b001;
    localparam SPLIT_PARTS = 3'b010;
    localparam SET_ROM_ADDR = 3'b011;
    localparam WAIT_ROM = 3'b100;
    localparam COMPUTE_RESULT = 3'b101;
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    reg [15:0] integer_part;  // Integer part of x
    reg [7:0] frac_part;            // Fractional part of x
    reg [7:0] rom_addr;             // Address for ROM lookup
    reg [2:0] wait_counter;         // Counter for ROM read delay

    // ROM interface
    wire [7:0] rom_data;

    // Instantiate the ROM containing 2^frac values
    blk_mem_gen_pow2 pow2_rom (
        .clka(clk),
        .ena(1'b1),
        .addra(rom_addr),
        .douta(rom_data)
    );

    wire [24:0] x_converted;
    wire overflow_converter;

    twos_complement_to_sign_magnitude converter (
        .in_num(x),
        .out_num(x_converted),
        .overflow(overflow_converter)
    );

    reg [24:0] base_val;
    reg [24:0] shifted_val;

    always @ (posedge clk or posedge clr) begin
        if (clr) begin
            val <= 25'b0;
            done <= 1'b0;
            overflow <= 1'b0;
            state <= IDLE;
            integer_part <= 16'b0;
            frac_part <= 8'b0;
            rom_addr <= 8'b0;
            wait_counter <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    state <= CONVERT;
                end

                CONVERT: begin
                    if (overflow_converter) begin
                        overflow <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        state <= SPLIT_PARTS;
                    end
                end

                SPLIT_PARTS: begin
                    if (x_converted[24]) begin
                        // Negative input
                        integer_part <= x_converted[7:0] == 8'b0 ? x_converted[23:8] : (x_converted[23:8] + 1);
                        frac_part <= 9'h100 - x_converted[7:0];
                    end else begin
                        // Positive input
                        integer_part <= x_converted[23:8];
                        frac_part <= x_converted[7:0];
                    end
                    state <= SET_ROM_ADDR;
                end

                SET_ROM_ADDR: begin
                    rom_addr <= frac_part;
                    wait_counter <= 3'b0;
                    state <= WAIT_ROM;
                end

                WAIT_ROM: begin
                    if (wait_counter == 3'b100) begin
                        state <= COMPUTE_RESULT;
                    end else begin
                        wait_counter <= wait_counter + 1'b1;
                    end
                end

                COMPUTE_RESULT: begin
                    // Compute 2^x using integer and fractional parts
                    if (~x_converted[24] && integer_part > 16) begin
                        // Overflow for integer part > 16
                        overflow <= 1'b1;
                        val <= 25'b0;
                    end else if (x_converted[24] && integer_part > 8) begin
                        // Underflow for negative integer part < -8
                        val <= 25'b0;
                        overflow <= 1'b0;
                    end else begin
                        base_val = {1'b0, 16'h0001, rom_data};  // [sign].16.8 format
                        if (x[24]) begin  // For negative input
                            shifted_val = base_val >> integer_part;
                            val <= shifted_val;
                            overflow <= 1'b0;
                        end else begin  // For positive input
                            shifted_val = base_val << integer_part;
                            val <= shifted_val;
                            overflow <= 1'b0;
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
