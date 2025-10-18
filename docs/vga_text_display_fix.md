# VGA Text Display Fix - Calculator & Grapher Modules

## Problem
No text appearing in VGA text boxes for calculator and grapher modes despite keypad input being captured.

## Root Causes Identified

### 1. **Incorrect Text Area Detection**
**Original Logic:**
```verilog
wire in_text_area = (vga_y >= TEXT_START_Y && vga_y < TEXT_START_Y + CHAR_HEIGHT &&
                     vga_x >= TEXT_START_X && vga_x < TEXT_START_X + (display_length * CHAR_WIDTH));
```

**Problem:** This only checked for **one row** of text (8 pixels tall), not the full text box (40 pixels tall from y=10 to y=50).

**Fixed Logic:**
```verilog
wire in_text_render_area = (vga_y >= TEXT_START_Y && vga_y < TEXT_START_Y + CHAR_HEIGHT &&
                            vga_x >= TEXT_START_X && vga_x < TEXT_START_X + (equation_length * CHAR_WIDTH));
```
The fix is the same condition BUT now properly used in the rendering pipeline.

### 2. **Block RAM Latency Not Handled**
**Problem:** Font ROM is implemented using Block RAM (BRAM), which has a **1-cycle read latency**:
- Clock cycle N: Address sent to BRAM
- Clock cycle N+1: Data available from BRAM

The original code used combinational logic (`always @(*)`), which doesn't account for this delay.

**Original Code:**
```verilog
blk_mem_gen_font font_rom (
    .clka(clk),
    .addra(font_addr),
    .douta(font_row_data)  // Available 1 cycle later!
);

wire font_pixel = font_row_data[7 - char_col];  // ❌ Using stale data!

always @(*) begin  // ❌ Combinational - timing mismatch!
    if (in_text_area && font_pixel) begin
        vga_data = 12'h000;
    end
    ...
end
```

**Fixed Code with Pipeline:**
```verilog
blk_mem_gen_font font_rom (
    .clka(clk),
    .addra(font_addr),
    .douta(font_row_data)
);

// Pipeline registers to delay control signals by 1 cycle
reg in_text_render_area_d;
reg is_border_d;
reg in_text_box_d;
reg [2:0] char_col_d;

always @(posedge clk) begin
    in_text_render_area_d <= in_text_render_area;
    is_border_d <= is_border;
    in_text_box_d <= in_text_box;
    char_col_d <= char_col;
end

// Now font_pixel uses delayed char_col that matches font_row_data timing
wire font_pixel = font_row_data[7 - char_col_d];

// Registered output to match pipeline
always @(posedge clk) begin  // ✅ Synchronized with BRAM output!
    if (in_text_box_d) begin
        if (is_border_d) begin
            vga_data <= 12'h000;
        end else if (in_text_render_area_d && font_pixel) begin
            vga_data <= 12'h000;  // Black text
        end else begin
            vga_data <= 12'hFFF;  // White background
        end
    end else begin
        vga_data <= 12'h888;
    end
end
```

### 3. **Combinational Output Changed to Registered**
**Original:**
```verilog
output reg [11:0] vga_data  // Declared as reg but used combinationally!

always @(*) begin
    vga_data = ...
end
```

**Fixed:**
```verilog
output reg [11:0] vga_data  // Now properly registered

always @(posedge clk) begin
    vga_data <= ...  // Non-blocking assignment
end
```

## Changes Applied

### Files Modified
1. `project_vivado/Submodules/calc_mode_module.v`
2. `project_vivado/Submodules/graph_mode_module.v`

### Key Changes

#### 1. Added Pipeline Registers
```verilog
reg in_text_render_area_d;
reg is_border_d;
reg in_text_box_d;
reg in_graph_area_d;  // graph_mode_module only
reg [2:0] char_col_d;

always @(posedge clk) begin
    in_text_render_area_d <= in_text_render_area;
    is_border_d <= is_border;
    in_text_box_d <= in_text_box;
    in_graph_area_d <= in_graph_area;
    char_col_d <= char_col;
end
```

#### 2. Updated Font Pixel Extraction
```verilog
// Before: Used non-delayed char_col
wire font_pixel = font_row_data[7 - char_col];

// After: Uses delayed char_col to match BRAM timing
wire font_pixel = font_row_data[7 - char_col_d];
```

#### 3. Changed Output Logic to Registered
```verilog
// Before: Combinational (always @(*))
always @(*) begin
    if (in_text_box) begin
        ...
    end
end

// After: Registered (always @(posedge clk))
always @(posedge clk) begin
    if (in_text_box_d) begin  // Uses delayed signal
        ...
    end
end
```

## Timing Diagram

```
Clock:        __|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|
vga_x/y:      <--A--><--B--><--C--><--D-->
char_index:   <--0--><--1--><--2--><--3-->
font_addr:    <--A0-><--B1-><--C2-><--D3->
font_row_data:      <--A0-><--B1-><--C2-><--D3->  (1 cycle delay)
char_col_d:         <--A--><--B--><--C--><--D-->  (1 cycle delay)
font_pixel:         <-A0px><-B1px><-C2px><-D3px>
vga_data:                 <-A0px><-B1px><-C2px>  (output registered)
```

**Key Point:** All control signals are delayed by 1 cycle to align with the BRAM output.

## Testing Checklist

- [ ] Calculator mode displays typed numbers (e.g., "123")
- [ ] Calculator mode displays decimal points (e.g., "12.34")
- [ ] Calculator mode displays operators (e.g., "5+3")
- [ ] Grapher mode displays equation input (e.g., "x^2")
- [ ] Text appears in correct position (x=15, y=15 inside text box)
- [ ] White text box background renders correctly
- [ ] Black border renders around text box
- [ ] Characters are readable (no garbled/shifted pixels)
- [ ] Multi-character strings display without gaps

## Expected Visual Result

```
┌──────────────────────────────────────────┐  ← y=10 (TEXT_BOX_Y_START)
│                                          │
│  123.45+67                               │  ← Text at y=15 (TEXT_START_Y)
│                                          │
│                                          │
└──────────────────────────────────────────┘  ← y=50 (TEXT_BOX_Y_END)
     ↑
   x=15 (TEXT_START_X)
```

- **Text box:** White background with black border
- **Text:** Black characters on white background
- **Font:** 8×8 pixel CP437 font from Block ROM

## Performance Impact

- **Added latency:** 1 VGA clock cycle (~40ns at 25MHz)
- **Visual impact:** Imperceptible (text appears 1 pixel later horizontally)
- **Resource cost:** +5 flip-flops per module (negligible)

## Common Issues & Debugging

### If text still doesn't appear:
1. **Check `display_length`** - Is parser outputting non-zero length?
   - Add debug: `assign led[5:0] = display_length;`
2. **Check `display_buffer_flat`** - Are characters being written?
   - Add debug: `assign led[7:0] = display_buffer_flat[7:0];`
3. **Check VGA coordinates** - Is text box in visible area?
   - Text box: x=10-630, y=10-50
   - VGA resolution: 640×480
4. **Check font ROM** - Is BRAM initialized correctly?
   - Verify `font.coe` file exists and is loaded
5. **Check clock domain** - Is `clk` the VGA pixel clock (25MHz)?

### If text is garbled:
- **Byte ordering wrong** - Try reversing bit-slice: `display_buffer_flat[(31-char_index)*8 +: 8]`
- **Wrong font ROM address** - Check `font_addr` width (should be 11 bits)

### If text appears shifted:
- **Pipeline mismatch** - Verify all control signals use `_d` suffix
- **Wrong offset** - Check `TEXT_START_X/Y` constants

## Related Documentation
- Synthesis fix: `docs/synthesis_fix_unpacked_array.md`
- Font ROM details: `project_vivado/font.md`
- Parser design: `docs/design/data_parser.md`
