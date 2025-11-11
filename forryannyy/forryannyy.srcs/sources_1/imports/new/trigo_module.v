`timescale 1ns / 1ps

module trigo_module(
    input clk,
    input clr,
    input [1:0] trig_select,  // 00: sin, 01: cos, 10: tan
    input signed [24:0] angle,  // Input angle in [sign].16.8 radians
    output reg signed [24:0] result,  // Result in [sign].16.8
    output reg done,
    output reg overflow  // High for tan if divide by zero
);

    // State machine states
    localparam IDLE = 2'b00;
    localparam COMPUTE_CORDIC = 2'b01;
    localparam COMPUTE_TAN = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state = IDLE;
    reg cordic_clr = 1;
    reg divider_clr = 1;
    wire cordic_done, divider_done, divider_overflow;
    wire signed [24:0] sin_temp, cos_temp, tan_temp;
    wire signed [24:0] sin_val, cos_val, tan_val;
    
    localparam signed [24:0] overflow_threshold = 25'sh0009600;

    wire [24:0] principal_angle; // sign.[4.20] format
    wire [1:0] quadrant;

    angle_preprocessor angle_prep_inst (
        .angle_in(angle),
        .principal_angle(principal_angle),
        .quadrant(quadrant)
    );
    
    // Instantiate CORDIC for sin/cos
    CORDIC_trigo_module CORDIC_trigo_inst (
        .clk(clk),
        .clr(cordic_clr),
        .angle(principal_angle),
        .quadrant(quadrant),
        .sin_out(sin_temp),
        .cos_out(cos_temp),
        .done(cordic_done)
    );
    
    // Instantiate divider for tan (sin / cos)
    divider_module divider_inst (
        .clk(clk),
        .clr(divider_clr),
        .a(sin_temp),  // sin for tan
        .b(cos_temp),   // cos for tan
        .val(tan_val),
        .done(divider_done), // was .busy(divider_done)
        .overflow(divider_overflow)
    );

    // State machine logic
    always @(posedge clk or posedge clr) begin
        if (clr) begin
            state <= IDLE;
            done <= 0;
            overflow <= 0;
            result <= 0;
            cordic_clr <= 1;
            divider_clr <= 1;
        end else begin
            case (state)

                IDLE: 
                begin
                    cordic_clr <= 0;
                    state <= COMPUTE_CORDIC;
                end

                COMPUTE_CORDIC: 
                begin
                    if (cordic_done) begin
                        if (trig_select == 2'b00) begin
                            if (sin_temp[24]) begin
                                result <= {13'h1FFF, sin_temp[23:12]};
                            end else begin  
                                result <= {13'b0, sin_temp[23:12]};
                            end
                            cordic_clr <= 1;
                            state <= DONE;
                        end else if (trig_select == 2'b01) begin
                            if (cos_temp[24]) begin
                                result <= {13'h1FFF, cos_temp[23:12]};
                            end else begin  
                                result <= {13'b0, cos_temp[23:12]};
                            end
                            cordic_clr <= 1;
                            state <= DONE;
                        end else if (trig_select == 2'b10) begin 
                            divider_clr <= 0;
                            state <= COMPUTE_TAN;
                        end
                    end else begin
                        state <= COMPUTE_CORDIC;
                    end
                end

                COMPUTE_TAN: 
                begin
                    if (divider_done) begin
                        result <= (tan_val > overflow_threshold || tan_val < -overflow_threshold || divider_overflow) ? 25'sh0 : tan_val;
                        overflow <= (tan_val > overflow_threshold || tan_val < -overflow_threshold || divider_overflow) ? 1 : 0;
                        cordic_clr <= 1;
                        divider_clr <= 1;
                        state <= DONE;
                    end else begin
                        state <= COMPUTE_TAN;
                    end
                end

                DONE: 
                begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule

module angle_preprocessor(
    input signed [24:0] angle_in, // [sign].16.8 radians
    output reg signed [24:0] principal_angle, // angle mapped to [0, pi/2] radians in [sign].4.20 format
    output reg [1:0] quadrant
);

    // Constants in [sign].16.8 format
    localparam signed [24:0] PI = 25'sh03243F7;
    localparam signed [24:0] PI_2 = 25'sh01921FB;
    localparam signed [24:0] TWO_PI = 25'sh06487ED;
    localparam signed [24:0] TWO_PI_16_8 = 25'sh0000648;

    reg signed [24:0] wrapped;
    reg signed [24:0] q;
    reg signed [24:0] scaled_angle;

    always @(*) begin
        q = angle_in / TWO_PI_16_8;
        wrapped = angle_in - q * TWO_PI_16_8;
        if (wrapped < 0)
            wrapped = wrapped + TWO_PI_16_8;
            
        scaled_angle = {wrapped[24], wrapped[11:0], 12'b0};

        if (scaled_angle < PI_2) begin
            quadrant   = 2'b00;
            principal_angle = scaled_angle;
        end else if (scaled_angle < PI) begin
            quadrant   = 2'b01;
            principal_angle = PI - scaled_angle;
        end else if (scaled_angle < PI + PI_2) begin
            quadrant   = 2'b10;
            principal_angle = scaled_angle - PI;
        end else begin
            quadrant   = 2'b11;
            principal_angle = TWO_PI - scaled_angle;
        end
    end
endmodule

module CORDIC_trigo_module(
    input clk,
    input clr,
    input [24:0] angle, // [sign].4.20 input
    input [1:0] quadrant, // quadrant from angle preprocessor
    output reg signed [24:0] sin_out, // [sign].4.20 output
    output reg signed [24:0] cos_out, // [sign].4.20 output
    output reg done
);

    // K-factor for 16 iterations, Q4.20 format ("K = 0.607252")
    localparam signed [24:0] K_FACTOR_4_20 = 25'sh009B74E; // Q4.20 multiplication

    localparam ITER = 16; // Max iterations
    reg signed [24:0] atan_table [0:15];
    initial begin
        atan_table[0]  = 25'sh00C90FE; // Q4.20 arctan(2^0)
        atan_table[1]  = 25'sh0076B1A; // Q4.20 arctan(2^-1)
        atan_table[2]  = 25'sh003EB6F; // Q4.20 arctan(2^-2)
        atan_table[3]  = 25'sh001FD5C; // Q4.20 arctan(2^-3)
        atan_table[4]  = 25'sh000FFAB; // Q4.20 arctan(2^-4)
        atan_table[5]  = 25'sh0007FF5; // Q4.20 arctan(2^-5)
        atan_table[6]  = 25'sh0003FFF; // Q4.20 arctan(2^-6)
        atan_table[7]  = 25'sh0002000; // Q4.20 arctan(2^-7)
        atan_table[8]  = 25'sh0001000; // Q4.20 arctan(2^-8)
        atan_table[9]  = 25'sh0000800; // Q4.20 arctan(2^-9)
        atan_table[10]  = 25'sh0000400; // Q4.20 arctan(2^-10)
        atan_table[11]  = 25'sh0000200; // Q4.20 arctan(2^-11)
        atan_table[12]  = 25'sh0000100; // Q4.20 arctan(2^-12)
        atan_table[13]  = 25'sh0000080; // Q4.20 arctan(2^-13)
        atan_table[14]  = 25'sh0000040; // Q4.20 arctan(2^-14)
        atan_table[15]  = 25'sh0000020; // Q4.20 arctan(2^-15)
    end

    reg [5:0] iter;
    reg signed [24:0] x, y, z;
    reg signed [24:0] x_next, y_next, z_next;

    reg [1:0] state;
    localparam SETUP = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam ADJUST = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [24:0] sin_temp, cos_temp;
    always @(posedge clk or posedge clr) begin
        if (clr) begin
            iter <= 0;
            done <= 0;
            state <= SETUP;
        end else begin
            case (state)

                SETUP: begin
                    iter <= 0;
                    done <= 0;
                    x <= K_FACTOR_4_20;
                    y <= 0;
                    z <= angle;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (iter < ITER) begin
                        if (z >= 0) begin
                            x_next = x - (y >>> iter);
                            y_next = y + (x >>> iter);
                            z_next = z - atan_table[iter];
                        end else begin
                            x_next = x + (y >>> iter);
                            y_next = y - (x >>> iter);
                            z_next = z + atan_table[iter];
                        end
                        x <= x_next;
                        y <= y_next;
                        z <= z_next;
                        iter <= iter + 1;
                    end else begin
                        state <= ADJUST;
                    end
                end

                ADJUST: begin
                    
                    case (quadrant)
                        2'b00: begin
                            sin_out = y;
                            cos_out = x;
                        end
                        2'b01: begin
                            sin_out = y;
                            cos_out = -x;
                        end
                        2'b10: begin
                            sin_out = -y;
                            cos_out = -x;
                        end
                        2'b11: begin
                            sin_out = -y;
                            cos_out = x;
                        end
                    endcase  
                    state <= DONE_STATE;
                end

                DONE_STATE: 
                begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule