`timescale 1ns / 1ps

module log2_module(
    input clk,
    input clr,
    input signed [24:0] a,
    output reg signed [24:0] val,
    output reg done,
    output reg overflow
);
    // States
    localparam IDLE = 3'b000;
    localparam FIND_MSB = 3'b001;
    localparam SET_ROM_ADDR = 3'b010;
    localparam WAIT_ROM = 3'b011;
    localparam COMPUTE_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    reg [2:0] state;
    reg [24:0] a_reg;
    reg [4:0] msb_position; 
    reg [23:0] normalised;
    reg signed [15:0] integer_part;
    reg [11:0] rom_addr_reg;
    reg [3:0] wait_counter;  // Counter for ROM read delay
    
    // Function to find MSB position
    function [4:0] find_msb;
        input [23:0] number;
        reg [4:0] pos;
        begin
            pos = 23;
            while (pos > 0 && number[pos] == 0) begin
                pos = pos - 1;
            end
            find_msb = pos;
        end
    endfunction
    
    // Interface to ROM
    wire [7:0] rom_data;
    reg [11:0] rom_addr;
    
    // Instantiate the ROM
    blk_mem_gen_log2_12bit rom_inst (
        .clka(clk),          // input wire clka
        .ena(1'b1),
        .addra(rom_addr),
        .douta(rom_data)
    );

    always @(posedge clk or posedge clr) begin
        if (clr) begin
            val <= 25'b0;
            done <= 1'b0;
            overflow <= 1'b0;
            state <= IDLE;
            a_reg <= 25'b0;
            msb_position <= 5'b0;
            normalised <= 24'b0;
            rom_addr <= 8'b0;
            rom_addr_reg <= 8'b0;
            wait_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    a_reg <= a;
                    state <= FIND_MSB;
                end
                
                FIND_MSB: begin
                    if (a_reg == 25'b0 || a_reg[24] == 1'b1) begin
                        overflow <= 1'b1;
                        val <= 25'b0;
                        state <= DONE_STATE;
                    end else begin
                        msb_position <= find_msb(a_reg[23:0]);
                        normalised <= a_reg[23:0] << (23 - find_msb(a_reg[23:0]));
                        state <= SET_ROM_ADDR;
                    end
                end
                
                SET_ROM_ADDR: begin
                    integer_part <= (msb_position < 8) ? 
                                  -{16'd8 - {11'b0, msb_position}} :  // Negative result for x < 1
                                  {11'b0, msb_position} - 16'd8;      // Positive result for x >= 1
                    rom_addr <= normalised[22:11];
                    rom_addr_reg <= normalised[22:11];
                    wait_counter <= 0;
                    state <= WAIT_ROM;
                end

                WAIT_ROM: begin
                    wait_counter <= wait_counter + 1;
                    
                    if (wait_counter >= 4'd3) begin 
                        state <= COMPUTE_RESULT;
                    end
                end

                COMPUTE_RESULT: begin
                    val <= {integer_part[15], integer_part, rom_data};
                    overflow <= 1'b0;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
