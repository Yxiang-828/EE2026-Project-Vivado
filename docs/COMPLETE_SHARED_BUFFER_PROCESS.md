# COMPLETE SHARED BUFFER ARCHITECTURE - FULL PROCESS

## 📋 FULL DATA FLOW: KEYPAD → VGA DISPLAY

### PHASE 1: INPUT CAPTURE (Keypad)
```
User presses '1' on OLED keypad
    ↓
oled_keypad detects button press
    ↓
Outputs: key_code = 5'd1, key_valid = 1 (1-cycle pulse)
    ↓
main.v receives key_code + key_valid_raw
```

### PHASE 2: ASCII CONVERSION (Main Level)
```
key_to_ascii_converter receives key_code + key_valid
    ↓
Maps 5'd1 → 8'h31 ('1')
    ↓
Outputs: ascii_char = 8'h31, char_valid = 1 (1-cycle pulse)
    ↓
main.v receives ascii_char + char_valid
```

### PHASE 3: SHARED BUFFER MANAGEMENT (Main Level)
```
main.v equation logic processes ascii_char:
├── If ascii_char == 'C': shared_equation_length = 0, complete = 0
├── If ascii_char == 'D' && length > 0: shared_equation_length--
├── If ascii_char == '=': shared_equation_complete = 1
├── Else if length < 31: shared_equation_buffer[length++] = ascii_char
    ↓
SHARED STATE UPDATED:
- shared_equation_buffer[]: Current equation as ASCII array
- shared_equation_length: How many chars (0-31)
- shared_equation_complete: 1 when '=' pressed
    ↓
Both calc_mode and graph_mode receive read-only access to shared state
```

### PHASE 4: MODE-SPECIFIC DISPLAY (Calc/Graph Modules)

#### Calculator Mode Display:
```
calc_mode_module receives:
├── shared_equation_buffer[0:31] (read-only)
├── shared_equation_length
├── shared_equation_complete
    ↓
VGA rendering logic:
├── For each VGA pixel (x,y):
│   ├── Calculate which char position: char_index = x / 8
│   ├── If char_index < shared_equation_length:
│   │   ├── Get char = shared_equation_buffer[char_index]
│   │   ├── Get font pixel = font_rom[char][y%8][x%8]
│   │   └── Output: font_pixel ? BLACK : WHITE
│   └── Else: Output WHITE (background)
    ↓
├── If shared_equation_complete: Add blinking cursor at end
└── VGA shows: "12+34" with blinking cursor after '='
```

#### Graph Mode Display:
```
graph_mode_module receives: (same shared inputs)
    ↓
VGA rendering logic:
├── Top text box: Shows shared_equation_buffer (same as calc)
├── Bottom graph area: Light blue background (placeholder)
└── VGA shows: "sin(x)" in text box, empty graph below
```

## 🔄 COMPLETE STATE MACHINE

### Welcome Mode (current_main_mode = 00)
```
OLED: Shows keypad UI
VGA: Shows welcome screen
Keypad: DISABLED (enable=0)
Buffer: IGNORED
```

### Calculator Mode (current_main_mode = 10)
```
OLED: Shows keypad UI
VGA: Shows calculator interface with equation + cursor
Keypad: ENABLED (enable=1)
Buffer: ACTIVE - builds equation, displays on VGA
```

### Graph Mode (current_main_mode = 11)
```
OLED: Shows keypad UI
VGA: Shows graph interface with equation + empty graph
Keypad: ENABLED (enable=1)
Buffer: ACTIVE - builds equation, displays on VGA
```

## 🎮 USER WORKFLOW EXAMPLE

### Scenario: User types "12+34=" in Calculator Mode

```
| Time | User Action  | Key Code | ASCII | Buffer State  | VGA Display                | LED[11:6] |
| ---- | ------------ | -------- | ----- | ------------- | -------------------------- | --------- |
| T=0  | Power on     | -        | -     | "" (len=0)    | Welcome                    | 000000    |
| T=1  | Navigate     | -        | -     | "" (len=0)    | Welcome                    | 000000    |
| T=2  | Enter Calc   | -        | -     | "" (len=0)    | Calc screen                | 000000    |
| T=3  | Press '1'    | 5'd1     | '1'   | "1" (len=1)   | "1_"                       | 000001    |
| T=4  | Press '2'    | 5'd2     | '2'   | "12" (len=2)  | "12_"                      | 000010    |
| T=5  | Press '+'    | 5'd10    | '+'   | "12+" (len=3) | "12+_"                     | 000011    |
| T=6  | Press '3'    | 5'd3     | '3'   | "12+3"(len=4) | "12+3_"                    | 000100    |
| T=7  | Press '4'    | 5'd4     | '4'   | "12+34"(5)    | "12+34_"                   | 000101    |
| T=8  | Press '='    | 5'd23    | '='   | "12+34"(5)    | "12+34" █                  | 000101    |
| T=9  | Switch Graph | -        | -     | "12+34"(5)    | Graph:"12+34" + empty plot | 000101    |
```

**Key Points:**
- **Buffer persists** across mode switches
- **Length updates** with each valid key
- **Complete flag** triggers cursor blink
- **Both modes** show identical equation
- **LED feedback** shows current length

## 🔧 IMPLEMENTATION DETAILS

### Main.v Shared Buffer Logic:
```verilog
// SHARED STATE (one copy for both modes)
reg [7:0] shared_equation_buffer [0:31];
reg [4:0] shared_equation_length = 0;
reg shared_equation_complete = 0;

// ASCII PROCESSING (centralized input handling)
always @(posedge clk) begin
    if (reset) begin
        shared_equation_length <= 0;
        shared_equation_complete <= 0;
    end else if (ascii_valid && !shared_equation_complete) begin
        case (ascii_char)
            8'h43: begin  // 'C' - Clear
                shared_equation_length <= 0;
                shared_equation_complete <= 0;
            end
            8'h44: begin  // 'D' - Delete
                if (shared_equation_length > 0)
                    shared_equation_length <= shared_equation_length - 1;
            end
            8'h3D: begin  // '=' - Complete
                shared_equation_complete <= 1;
            end
            default: begin  // Regular character
                if (shared_equation_length < 31) begin
                    shared_equation_buffer[shared_equation_length] <= ascii_char;
                    shared_equation_length <= shared_equation_length + 1;
                end
            end
        endcase
    end
end
```

### Mode Module Interface:
```verilog
module calc_mode_module(
    // SHARED BUFFER INPUTS (READ-ONLY)
    input [7:0] shared_buffer [0:31],  // Full buffer access
    input [4:0] shared_length,         // Current length
    input shared_complete,             // Equation finished?

    // VGA OUTPUTS
    input [9:0] vga_x, vga_y,
    output reg [11:0] vga_data,

    // ... other signals
);
```

### VGA Rendering in Mode:
```verilog
// Calculate character position
wire [5:0] char_index = vga_x[9:3];  // 0-79 chars across screen
wire [2:0] char_col = vga_x[2:0];    // 0-7 pixel within char
wire [2:0] char_row = vga_y[2:0];    // 0-7 row within char

// Get character from shared buffer
wire [7:0] current_char = (char_index < shared_length) ?
                          shared_buffer[char_index] : 8'h20;

// Font lookup
wire [10:0] font_addr = {current_char, char_row};
wire [7:0] font_row_data;
blk_mem_gen_font font_rom (.clka(clk), .addra(font_addr), .douta(font_row_data));

// Pixel output
wire in_text_area = (vga_y >= TEXT_START_Y && vga_y < TEXT_END_Y &&
                     vga_x >= TEXT_START_X && vga_x < TEXT_END_X);

always @(*) begin
    if (in_text_area && char_index < shared_length) begin
        vga_data = font_row_data[char_col] ? 12'h000 : 12'hFFF;  // Black on white
    end else if (cursor_visible && cursor_position_match) begin
        vga_data = 12'hF00;  // Red blinking cursor
    end else begin
        vga_data = 12'hFFF;  // White background
    end
end
```

## 🎯 ADVANTAGES OF THIS ARCHITECTURE

### Efficiency:
- **One buffer**: 256 bits vs 768 bits (67% memory reduction)
- **Central logic**: Input processing in one place
- **No duplication**: Modes just read shared state

### Reliability:
- **Atomic updates**: Buffer changes are instantaneous
- **Consistent state**: Both modes show identical data
- **Mode-safe**: Switching modes preserves equation

### Maintainability:
- **Single source**: One place to debug equation logic
- **Clear interfaces**: Read-only access prevents corruption
- **Extensible**: Easy to add new modes or features

### User Experience:
- **Persistent input**: Type in calc, switch to graph, equation remains
- **Visual feedback**: Real-time display as you type
- **Clear completion**: Blinking cursor shows equation is ready

## 🚀 READY TO IMPLEMENT?

This architecture gives you:
1. **Simple input flow**: Keypad → ASCII → Shared Buffer → Display
2. **Efficient resources**: Minimal BRAM usage
3. **Robust operation**: No sync issues between modes
4. **Future-ready**: Easy to add computation/graphing later

**Want me to implement this shared buffer architecture?** It will be much cleaner than the separate buffers approach. 🎯