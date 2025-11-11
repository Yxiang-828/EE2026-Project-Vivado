// ==================== sevenseg_driver.v ====================
`timescale 1ns/1ps
module sevenseg_driver(
    input  wire        clk,      // 100MHz on Basys3
    input  wire  [3:0] val3,     // leftmost
    input  wire  [3:0] val2,
    input  wire  [3:0] val1,
    input  wire  [3:0] val0,     // rightmost
    input  wire  [3:0] dot_on,   // 1=dot on for that digit
    output reg   [7:0] seg,      // active-low: [7]=dp, [6:0]=g..a
    output reg   [3:0] an        // active-low anodes
);

    // --- Clock Divider & Selector ---
    // This part is the same, but we'll use the proper rollover
    // for a 16-bit counter. This gives ~1.5kHz total refresh.
    reg [15:0] div = 16'd0;
    always @(posedge clk) div <= div + 16'd1;

    // 'sel' points to the digit we will PREPARE data for
    reg [1:0] sel = 2'd0;
    always @(posedge clk) begin
        if (div == 16'hFFFF) // Update on rollover
            sel <= sel + 2'd1;
    end
    
    // --- Pipeline Stage 1: Data Selection (Registered) ---
    // We register the data and dot corresponding to 'sel'
    reg [3:0] nib_reg;
    reg       dp_reg;
    
    always @(posedge clk) begin
        case (sel)
            2'd0: begin nib_reg <= val0; dp_reg <= dot_on[0]; end
            2'd1: begin nib_reg <= val1; dp_reg <= dot_on[1]; end
            2'd2: begin nib_reg <= val2; dp_reg <= dot_on[2]; end
            2'd3: begin nib_reg <= val3; dp_reg <= dot_on[3]; end
            default: begin nib_reg <= 4'hF; dp_reg <= 1'b0; end // Blank
        endcase
    end

    // 'sel_reg' holds the 'sel' value from the PREVIOUS cycle.
    // This is the selector that matches the data in 'nib_reg' and 'dp_reg'.
    reg [1:0] sel_reg;
    always @(posedge clk) begin
        sel_reg <= sel;
    end

    // --- 7-Segment Encoder Function (unchanged) ---
    function automatic [7:0] enc7seg(input [3:0] v, input dp_on);
        reg [7:0] s;
        begin
            case (v)
                4'h0: s = 8'b1100_0000;
                4'h1: s = 8'b1111_1001;
                4'h2: s = 8'b1010_0100;
                4'h3: s = 8'b1011_0000;
                4'h4: s = 8'b1001_1001;
                4'h5: s = 8'b1001_0010;
                4'h6: s = 8'b1000_0010;
                4'h7: s = 8'b1111_1000;
                4'h8: s = 8'b1000_0000;
                4'h9: s = 8'b1001_0000;
                4'hA: s = 8'b1000_1000; // A
                4'hB: s = 8'b1010_0011; // o (custom small 'o')
                4'hC: s = 8'b1100_0110; // C
                4'hD: s = 8'b1111_0111; // '-' (only g on)
                4'hE: s = 8'b1111_1111; // blank
                4'hF: s = 8'b1000_1110; // F
                default: s = 8'b1111_1111; // blank
            endcase
            s[7] = dp_on ? 1'b0 : 1'b1; // dp (active-low)
            enc7seg = s;
        end
    endfunction

    // --- Pipeline Stage 2: Output Drivers (Registered) ---
    // Both 'an' and 'seg' are updated on the SAME clock edge
    // using the perfectly synchronized data from Stage 1.
    
    always @(posedge clk) begin
        // 1. Decode the anode from the PREVIOUS 'sel'
        case (sel_reg)
            2'd0: an <= 4'b1110; // an[0] on
            2'd1: an <= 4'b1101; // an[1] on
            2'd2: an <= 4'b1011; // an[2] on
            2'd3: an <= 4'b0111; // an[3] on
            default: an <= 4'b1111; // all off
        endcase

        // 2. Decode the segment data from the PREVIOUS 'sel'
        seg <= enc7seg(nib_reg, dp_reg);
    end

endmodule

/*`timescale 1ns/1ps
module sevenseg_driver(
  input  wire        clk,         // 100MHz on Basys3
  input  wire  [3:0] val3,        // leftmost
  input  wire  [3:0] val2,
  input  wire  [3:0] val1,
  input  wire  [3:0] val0,        // rightmost
  input  wire  [3:0] dot_on,      // 1=dot on for that digit
  output reg   [7:0] seg,         // active-low: [7]=dp, [6:0]=g..a
  output reg   [3:0] an           // active-low anodes
);

  // ~1 kHz per digit refresh: 100e6 / (1k * 4) ? 25_000
  reg [15:0] div = 16'd0;
  always @(posedge clk) div <= div + 16'd1;

  reg [1:0] sel = 2'd0;           // which digit is active
  always @(posedge clk) if (div == 16'd0) sel <= sel + 2'd1;

  // mux current digit nibble + its decimal point request
  reg [3:0] nib;
  reg       dp;
  always @* begin
    case (sel)
      2'd0: begin nib = val0; dp = dot_on[0]; end
      2'd1: begin nib = val1; dp = dot_on[1]; end
      2'd2: begin nib = val2; dp = dot_on[2]; end
      2'd3: begin nib = val3; dp = dot_on[3]; end
    endcase
  end

  // enable only the selected anode (active-low)
  always @* begin
    an        = 4'b1111;
    an[sel]   = 1'b0;
  end

  // hex/char to segments (active-low, order: [dp g f e d c b a])
  function automatic [7:0] enc7seg(input [3:0] v, input dp_on);
    reg [7:0] s;
    begin
      case (v)
        4'h0: s = 8'b1100_0000;
        4'h1: s = 8'b1111_1001;
        4'h2: s = 8'b1010_0100;
        4'h3: s = 8'b1011_0000;
        4'h4: s = 8'b1001_1001;
        4'h5: s = 8'b1001_0010;
        4'h6: s = 8'b1000_0010;
        4'h7: s = 8'b1111_1000;
        4'h8: s = 8'b1000_0000;
        4'h9: s = 8'b1001_0000;
        4'hA: s = 8'b1000_1000; // A
        4'hB: s = 8'b1010_0011; // o (custom small 'o')
        4'hC: s = 8'b1100_0110; // C
        4'hD: s = 8'b1111_0111; // '-' (only g on)
        4'hE: s = 8'b1111_1111; // blank
        4'hF: s = 8'b1000_1110; // F
        default: s = 8'b1111_1111; // blank
      endcase
      // decimal point (active-low) lives in bit7
      s[7] = dp_on ? 1'b0 : 1'b1;
      enc7seg = s;
    end
  endfunction

  // drive segments for the currently active digit
  always @* begin
    seg = enc7seg(nib, dp);
  end

endmodule*/
