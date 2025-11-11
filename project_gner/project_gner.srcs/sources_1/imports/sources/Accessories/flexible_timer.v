`timescale 1ns / 1ps

module flexible_timer(
    input CLOCK,
    input [31:0] frequency, 
    output reg SLOW_CLOCK = 0
);
    
    localparam BASYS_CLOCK = 100_000_000;
    reg [31:0] MAX_COUNT;
    reg [31:0] COUNT = 0;

    always @(*) begin
        if (frequency > 0)
            MAX_COUNT = (BASYS_CLOCK / (2 * frequency)) - 1;
        else
            MAX_COUNT = 32'hFFFFFFFF; // avoid div by 0
    end

    always @(posedge CLOCK) begin
        if (COUNT == MAX_COUNT) begin
            COUNT <= 0;
            SLOW_CLOCK <= ~SLOW_CLOCK;
        end else begin
            COUNT <= COUNT + 1;
        end
    end
endmodule