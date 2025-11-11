`timescale 1ns / 1ps

module debouncer (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_out
);

    localparam integer DEBOUNCE_COUNT = 5_000_000 - 1;

    reg btn_ff = 0;
    reg [24:0] count = 0;
    reg btn_sync = 0;

    // synchronize raw button input
    always @(posedge clk) begin
        btn_sync <= btn_in;
    end

    always @(posedge clk) begin
        btn_out <= 0;  // default to low
        
        // once btn_ff set to high for first button press, sets btn signal to 1,and 0 in next clk cycle
        // btn_out stays at 0 untill user releases button, once the release is stable for 200ms,
        // we clear btn_ff to get ready for next button press.
        if (!btn_ff && btn_sync) begin
            // rising edge detected, initial press
            btn_out <= 1;    // register inital press
            btn_ff <= 1;     // set flip-flop to block further pulses, untill released & stable for >200ms
            count <= 0;      // start counting debounce period
        end
        // flip flop is now high at 1, it will hold the output to 0 now
        else if (btn_ff) begin
            if (btn_sync) begin
                // button being held down, hold infinitely untill button released for >200ms
                count <= count;
            end 
            
            else begin
                // button released, count 200 ms before resetting flip-flop
                if (count < DEBOUNCE_COUNT)
                    count <= count + 1;
                else
                    btn_ff <= 0; // ready for next press
            end
        end
    end
endmodule

module button_debouncer_array (
    input wire clk,
    input wire [4:0] btn,
    output wire [4:0] btn_debounced 
);

    debouncer debouncer_inst_0 (
        .clk      (clk),
        .btn_in   (btn[0]),
        .btn_out  (btn_debounced[0])
    );
    
    debouncer debouncer_inst_1 (
        .clk      (clk),
        .btn_in   (btn[1]),
        .btn_out  (btn_debounced[1])
    );
    
    debouncer debouncer_inst_2 (
        .clk      (clk),
        .btn_in   (btn[2]),
        .btn_out  (btn_debounced[2])
    );
    
    debouncer debouncer_inst_3 (
        .clk      (clk),
        .btn_in   (btn[3]),
        .btn_out  (btn_debounced[3])
    );
    
    debouncer debouncer_inst_4 (
        .clk      (clk),
        .btn_in   (btn[4]),
        .btn_out  (btn_debounced[4])
    );

endmodule

