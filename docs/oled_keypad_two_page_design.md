# OLED Keypad - Two-Page Design with Input Display

## Overview
Two-page keypad with input display box at top showing current expression and blinking cursor.

---

## Display Specifications

### OLED Layout
- **Total Size**: 96px × 64px
- **Input Display Area**: y=0-11 (12px height, full 96px width)
- **Keypad Area**: y=12-63 (52px height)
- **Grid**: **4 rows × 5 columns** = 20 buttons per page
- **Cell Size**: 19.2px width × 13px height

### Calculations
- **Text box height**: 12px (as requested)
- **Remaining height**: 64-12 = 52px for keypad
- **Row height**: 52px / 4 rows = 13px per row
- **Column width**: 96px / 5 columns = 19.2px per column
- **Character centering (8×8 font)**:
  - Horizontal offset: (19.2-8)/2 = 5.6px → 5px
  - Vertical offset: (13-8)/2 = 2.5px → 2px

### Multi-Character Rendering
- **"sin" width**: 3 × 8px = 24px
- **Cell width**: 19.2px
- **Issue**: 24px > 19.2px - text will overflow!
- **Solution**: Use condensed spacing (6px between chars): 8+6+8 = 22px (still slightly over)
- **Alternative**: Accept visual overflow or use abbreviations

---

## Input Display Box

### Layout
```
┌─────────────────────────────────────┐
│ 1 + 2 × sin ( 4 5 )                 │  ← Expression
│             ↑                       │  ← Blinking cursor
└─────────────────────────────────────┘
┌──────┬──────┬──────┬──────┬──────┐
│      │      │      │      │      │
├──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │      │
├──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │      │
├──────┼──────┼──────┼──────┼──────┤
│      │      │      │      │      │
└──────┴──────┴──────┴──────┴──────┘
```

### Features
- **Height**: 12px (full width)
- **Font**: 8×8 bitmap font
- **Content**: Current mathematical expression
- **Cursor**: Blinking vertical bar showing insert position
- **Scrolling**: If expression > 12 chars, scroll to show current position
- **Background**: Black with white text

---

## Page 1: Numbers & Operators

### Grid Layout (4×5)
```
┌─────────────────────────────────────┐
│ Expression: 1+2×sin(45)             │
└─────────────────────────────────────┘
┌──────┬──────┬──────┬──────┬──────┐
│  7   │  8   │  9   │  /   │  C   │
├──────┼──────┼──────┼──────┼──────┤
│  4   │  5   │  6   │  *   │  D   │
├──────┼──────┼──────┼──────┼──────┤
│  1   │  2   │  3   │  -   │  +   │
├──────┼──────┼──────┼──────┼──────┤
│  0   │  .   │  ^   │  √   │  =   │
└──────┴──────┴──────┴──────┴──────┘
```

### Character Mapping (ASCII codes)
```verilog
// Page 1 - Single ASCII character per button
Row 0: 0x37, 0x38, 0x39, 0x2F, 0x43  // '7', '8', '9', '/', 'C'
Row 1: 0x34, 0x35, 0x36, 0x2A, 0x44  // '4', '5', '6', '*', 'D' (Delete)
Row 2: 0x31, 0x32, 0x33, 0x2D, 0x2B  // '1', '2', '3', '-', '+'
Row 3: 0x30, 0x2E, 0x5E, 0xFB, 0x3D  // '0', '.', '^', '√', '='
```

### Legend
- **0-9**: Numbers
- **/, *, -, +**: Operators
- **.**: Decimal point
- **^**: Power operator
- **√**: Square root
- **=**: Calculate
- **C**: Clear all
- **DEL** (D): Delete last character

---

## Page 2: Functions Only

### Grid Layout (3×3 with wide cells)
```
┌─────────────────────────────────────┐
│ Expression: 1+2×sin(45)             │
└─────────────────────────────────────┘
┌─────────┬─────────┬─────────┐
│   sin   │   cos   │   tan   │
├─────────┼─────────┼─────────┤
│    (    │    )    │   x²    │
├─────────┼─────────┼─────────┤
│   √x    │    π    │    e    │
└─────────┴─────────┴─────────┘
```

### New Cell Size Calculation
- **Keypad area**: y=12-63 (52px height)
- **Rows**: 3 rows
- **Columns**: 3 columns
- **Cell height**: 52px / 3 rows = 17.33px ≈ 17px per row
- **Cell width**: 96px / 3 columns = 32px per column
- **Character centering**:
  - Horizontal: (32-8)/2 = 12px offset (perfect for single chars)
  - Horizontal: (32-24)/2 = 4px offset (perfect for "sin")

### Multi-Character Rendering
- **"sin" width**: 24px
- **Cell width**: 32px
- **Perfect fit**: 8px margin on each side

### Character Mapping
```verilog
// Page 2 - 3×3 grid
Row 0: "sin", "cos", "tan"
Row 1: '(',   ')',   "x²"
Row 2: "√x",  'π',   'e'
```

### Symbol Notes
- **sin/cos/tan**: Render with slight overflow (24px in 19.2px cell)
- **(, )**: Parentheses (ASCII 0x28, 0x29)
- **x²**: Power of 2 (use 'x' + '²' or '^' + '2')
- **√x**: Square root (use '√' + 'x' or 'v' + 'x')
- **π**: Pi symbol (use 'π' or 'p')
- **e**: Euler's number (ASCII 0x65)

### Grid Arrays (JavaScript style for reference)
```javascript
const page_1_grid = [
  ['7', '8', '9', '/',   'C'],
  ['4', '5', '6', '*',   'D'],
  ['1', '2', '3', '-',   '+'],
  ['0', '.', '^', '√',   '=']
];

const page_2_grid = [
  ['sin', 'cos', 'tan'],
  ['(',   ')',   'x²'],
  ['√x',  'π',   'e']
];
```

---

## Navigation Logic

### Within-Page Navigation
```verilog
// Dynamic row limits based on current page
wire [1:0] max_row = (current_page == 0) ? 3 : 2;  // Page 1: 4 rows (0-3), Page 2: 3 rows (0-2)
wire [1:0] max_col = (current_page == 0) ? 4 : 2;  // Page 1: 5 cols (0-4), Page 2: 3 cols (0-2)

if (btn_up && cursor_row > 0)
    cursor_row <= cursor_row - 1;

if (btn_down && cursor_row < max_row)
    cursor_row <= cursor_row + 1;

if (btn_left && cursor_col > 0)
    cursor_col <= cursor_col - 1;

if (btn_right && cursor_col < max_col)
    cursor_col <= cursor_col + 1;
```

### Page Switching Logic
```verilog
// Switch to Page 2: Right button when at rightmost column
if (btn_right && cursor_col == max_col && current_page == 0) begin
    current_page <= 1;
    cursor_col <= 0;
end

// Switch to Page 1: Left button when at leftmost column
if (btn_left && cursor_col == 0 && current_page == 1) begin
    current_page <= 0;
    cursor_col <= max_col;
end
```

---

## Module Interface

```verilog
module oled_keypad (
    input clk,
    input [12:0] pixel_index,
    input [4:0] btn,              // [center, up, left, right, down]
    output reg [15:0] oled_data,
    output reg [4:0] key_code,
    output reg key_valid,
    // Expression display outputs
    output reg [7:0] expression [0:31],  // Current expression buffer
    output reg [5:0] expr_length,        // Length of expression
    output reg [5:0] cursor_pos          // Cursor position in expression
);
```

---

## Key Codes

```verilog
// Page 1
'0'-'9' → 0-9
'/'     → 10
'*'     → 11
'-'     → 12
'+'     → 13
'.'     → 14
'^'     → 15  // Power operator
'√'     → 16  // Square root
'='     → 17  // Calculate (moved to end)
'C'     → 18  // Clear
'D'     → 19  // Delete

// Page 2
"sin"   → 20
"cos"   → 21
"tan"   → 22
'('     → 23
')'     → 24
"x²"    → 25
"√x"    → 26
'π'     → 27
'e'     → 28
```

---

## Implementation Notes

1. **Display areas**:
   - Input box: y=0-11 (12px height, full 96px width)
   - Keypad: y=12-63 (52px height)

2. **Cell sizes**:
   - **Page 1**: 19.2px × 13px (4 rows × 5 columns)
   - **Page 2**: 32px × 17.33px (3 rows × 3 columns, wider cells)

3. **Character centering**:
   - Page 1: Place 8×8 char at (5px, 2px) offset within cell
   - Page 2: Place 8×8 char at (12px, 4.5px) offset, "sin" at (4px, 4.5px) offset

4. **Multi-char labels**: For "sin", "cos", "tan" - perfect fit in 32px cells
5. **Empty cells**: None on Page 2 (all 9 cells used)
6. **Expression buffer**: 32-character max, with cursor position tracking
7. **Cursor blinking**: 500ms on/off cycle for input display

### Expression Buffer Logic
```verilog
// Expression buffer management
reg [7:0] expression [0:31];  // 32-character buffer
reg [5:0] expr_length;       // Current length
reg [5:0] cursor_pos;        // Cursor position (0 to expr_length)

// Add character to expression
if (key_pressed && key_code < 16) begin  // Numbers/operators
    if (expr_length < 31) begin
        // Insert at cursor position
        for (i = 31; i > cursor_pos; i = i - 1)
            expression[i] <= expression[i-1];
        expression[cursor_pos] <= key_ascii;
        expr_length <= expr_length + 1;
        cursor_pos <= cursor_pos + 1;
    end
end

// Delete character
if (key_code == 19) begin  // DEL key
    if (cursor_pos > 0) begin
        // Remove character before cursor
        for (i = cursor_pos-1; i < expr_length-1; i = i + 1)
            expression[i] <= expression[i+1];
        expression[expr_length-1] <= 0;
        expr_length <= expr_length - 1;
        cursor_pos <= cursor_pos - 1;
    end
end

// Clear all
if (key_code == 18) begin  // C key
    expr_length <= 0;
    cursor_pos <= 0;
    // Clear expression array...
end
```

### Input Display Rendering
```verilog
// Render input box (y=0-11)
if (pixel_y < 12) begin
    // Draw expression text with cursor
    char_x = (pixel_x - 4) / 8;  // Character position
    if (char_x < expr_length) begin
        // Draw character from expression buffer
        ascii_char = expression[char_x];
        // ... font rendering logic
    end else if (char_x == cursor_pos && blink_on) begin
        // Draw blinking cursor (vertical bar)
        oled_data <= WHITE;
    end else begin
        oled_data <= BLACK;
    end
end
```

---

## Summary

✅ **Input display box**: 12px height with blinking cursor
✅ **Page 1**: 4×5 grid (numbers + operators + C + D)
✅ **Page 2**: 3×3 grid (9 functions with wide cells - perfect fit!)
✅ **No overflow**: All characters fit perfectly
✅ **Dynamic navigation**: Handles different grid sizes per page

Ready to code!
