# OLED Keypad Operator Output Specification

## Overview
This document extends the `oled_keypad_two_page_design.md` with operator output behavior for VGA integration.

---

## Operator Output Behavior

### Output Types

#### 1. **Intermediate Output** (Operators: `+`, `-`, `*`, `/`)
When pressed, these operators:
1. **Send expression to VGA**: Output current expression buffer content to VGA module
2. **Clear local display**: Clear expression buffer and reset cursor
3. **Display operator as first symbol**: Insert the operator character into now-empty expression buffer

**Example Flow:**
```
User types: "2+3"
User presses "+"
→ VGA receives: "2+3" (6 chars)
→ OLED textbox shows: "+"
→ User continues: "+5"
→ OLED textbox shows: "+5"
```

#### 2. **Final Output** (Operator: `=`)
When pressed, this operator:
1. **Send expression to VGA**: Output current expression buffer content to VGA module
2. **Send completion signal**: Assert `output_complete` flag for 1 clock cycle
3. **Clear local display**: Clear expression buffer and reset cursor

**Example Flow:**
```
User types: "2+3="
User presses "="
→ VGA receives: "2+3=" (7 chars)
→ VGA receives: output_complete = 1 (for 1 cycle)
→ OLED textbox clears to empty
```

---

## Module Interface Extension

### Additional Output Ports
```verilog
module oled_keypad (
    // ... existing ports ...
    
    // VGA Output Interface
    output reg [7:0] vga_expression [0:31],  // Expression buffer for VGA
    output reg [5:0] vga_expr_length,        // Length of expression sent to VGA
    output reg vga_output_valid,             // Pulse: expression data is valid
    output reg vga_output_complete           // Pulse: '=' pressed, calculation complete
);
```

### Signal Descriptions

| Signal | Type | Description |
|--------|------|-------------|
| `vga_expression[0:31]` | `output reg [7:0]` | 32-character buffer sent to VGA (snapshot of expression_buffer) |
| `vga_expr_length` | `output reg [5:0]` | Number of valid characters in vga_expression (0-31) |
| `vga_output_valid` | `output reg` | 1-cycle pulse when intermediate operator pressed (`+`, `-`, `*`, `/`) |
| `vga_output_complete` | `output reg` | 1-cycle pulse when `=` pressed (final output) |

---

## Operator Detection Logic

### Page 1 Operator Positions
```verilog
// Row 0, Col 3: '/' (0x2F)
// Row 1, Col 3: '*' (0x2A)
// Row 2, Col 3: '-' (0x2D)
// Row 2, Col 4: '+' (0x2B)
// Row 3, Col 4: '=' (0x3D)
```

### State Machine States
```verilog
localparam STATE_IDLE         = 2'b00;  // Normal input mode
localparam STATE_SEND_INTERMEDIATE = 2'b01;  // Operator +,-,*,/ pressed
localparam STATE_SEND_FINAL   = 2'b10;  // '=' pressed
```

---

## Implementation Logic

### Button Press Handler (Pseudo-code)
```verilog
always @(posedge clk) begin
    if (reset) begin
        vga_output_valid <= 0;
        vga_output_complete <= 0;
        vga_expr_length <= 0;
    end else begin
        // Default: clear pulses
        vga_output_valid <= 0;
        vga_output_complete <= 0;
        
        if (btn_pressed[0] && current_page == PAGE_NUMBERS) begin
            case ({selected_row[2:0], selected_col[2:0]})
                // Intermediate operators
                6'b000_011,  // '/'
                6'b001_011,  // '*'
                6'b010_011,  // '-'
                6'b010_100: begin  // '+'
                    // Copy expression to VGA buffer
                    for (i = 0; i < 32; i = i + 1) begin
                        vga_expression[i] <= expression_buffer[i];
                    end
                    vga_expr_length <= expression_length;
                    vga_output_valid <= 1;  // Pulse for 1 cycle
                    
                    // Clear local expression
                    expression_length <= 1;  // Start with operator
                    cursor_pos <= 1;
                    expression_buffer[0] <= selected_operator_char;  // Insert operator
                end
                
                // Final operator
                6'b011_100: begin  // '='
                    // Copy expression to VGA buffer
                    for (i = 0; i < 32; i = i + 1) begin
                        vga_expression[i] <= expression_buffer[i];
                    end
                    vga_expr_length <= expression_length;
                    vga_output_complete <= 1;  // Pulse for 1 cycle
                    
                    // Clear local expression completely
                    expression_length <= 0;
                    cursor_pos <= 0;
                end
            endcase
        end
    end
end
```

---

## VGA Module Reception Logic (Reference)

The receiving VGA module should:

1. **Monitor `vga_output_valid`**:
   - When asserted, latch `vga_expression[0:vga_expr_length-1]`
   - Append to ongoing calculation string
   - Continue waiting for more input

2. **Monitor `vga_output_complete`**:
   - When asserted, latch final `vga_expression[0:vga_expr_length-1]`
   - Trigger calculation/evaluation logic
   - Display result

---

## Timing Diagrams

### Intermediate Operator Sequence
```
Cycle    Event
  0      User presses "+"
  1      vga_output_valid = 1, vga_expression = "2+3", vga_expr_length = 3
  2      vga_output_valid = 0
         expression_buffer[0] = '+', expression_length = 1
```

### Final Operator Sequence
```
Cycle    Event
  0      User presses "="
  1      vga_output_complete = 1, vga_expression = "2+3=", vga_expr_length = 4
  2      vga_output_complete = 0
         expression_buffer cleared, expression_length = 0
```

---

## Edge Cases

1. **Empty Expression**:
   - If user presses operator with `expression_length == 0`, do nothing
   
2. **Buffer Overflow**:
   - Already handled by `expression_length < 31` check
   
3. **Multiple Operators**:
   - Each intermediate operator sends current state and replaces with itself
   - Example: "2+3+" → sends "2+3", displays "+", user continues "5" → displays "+5"

---

## Summary

✅ **Intermediate operators** (`+`, `-`, `*`, `/`): Send expression, clear, insert operator
✅ **Final operator** (`=`): Send expression with completion signal, clear completely
✅ **VGA interface**: 32-byte expression buffer + length + 2 control signals
✅ **1-cycle pulses**: `vga_output_valid` and `vga_output_complete` for handshake

This design allows the VGA module to build up complex expressions from multiple OLED keypad inputs while maintaining clean separation between input (OLED) and computation/display (VGA).
