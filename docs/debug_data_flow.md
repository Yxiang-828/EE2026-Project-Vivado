# Data Flow Break Analysis

## THE PROBLEM: Button press detection broken when enable transitions

### STEP 1: OLED KEYPAD (oled_keypad.v)

**OLD CODE (BROKEN):**
```verilog
wire [4:0] btn_pressed = enable ? (~btn_debounced & btn_prev) : 5'b00000;
always @(posedge clk) begin
    if (enable) btn_prev <= btn_debounced;  // ❌ ONLY updates when enabled
end
```

**What happens:**

#### Scenario A: User in WELCOME mode, presses button '1', then switches to CALC mode

```
| Time | Mode    | enable | btn[0] | btn_debounced[0] | btn_prev[0] | btn_pressed[0] | key_valid |
| ---- | ------- | ------ | ------ | ---------------- | ----------- | -------------- | --------- |
| T=0  | WELCOME | 0      | UP     | 1                | 1           | 0              | 0         |
| T=1  | WELCOME | 0      | DOWN   | 1→0              | 1 (FROZEN)  | 0 (gated)      | 0 ❌       |
| T=2  | WELCOME | 0      | DOWN   | 0                | 1 (FROZEN)  | 0 (gated)      | 0 ❌       |
| T=3  | CALC    | 1      | DOWN   | 0                | 1 (STALE!)  | 1 (FALSE!)     | 1 ❌❌❌     |
| T=4  | CALC    | 1      | DOWN   | 0                | 0           | 0              | 0         |
| T=5  | CALC    | 1      | UP     | 0→1              | 0           | 0              | 0         |
| T=6  | CALC    | 1      | DOWN   | 1→0              | 1           | 1 ✅            | 1 ✅       |
```

**THE BUG AT T=3:**
- User switches to CALC mode while button still pressed
- `btn_prev=1` (stale from T=0, before button was pressed in WELCOME)
- `btn_debounced=0` (button currently pressed)
- `btn_pressed = ~0 & 1 = 1` ← **FALSE TRIGGER!**
- `key_valid=1` sent to parser
- Parser receives **GARBAGE key_code** (not actually selected key)

**RESULT:** Parser gets spurious input, corrupts display buffer!

---

### STEP 2: MAIN.V (Signal routing)

```verilog
wire keypad_enable = (current_main_mode == MODE_CALCULATOR | MODE_GRAPHER);
wire keypad_key_valid = keypad_key_valid_raw & keypad_enable;
```

This DOUBLE-GATES the signal:
- `keypad_key_valid_raw` already gated by enable in oled_keypad
- Then AND'ed with enable AGAIN in main.v

This is redundant but NOT the root cause.

---

### STEP 3: CALC_MODE_MODULE (Parser input)

```verilog
data_parser_accumulator parser_inst(
    .key_code(key_code),       // ← Receives from main.v
    .key_valid(key_valid),     // ← FALSE TRIGGER from T=3!
    // ... outputs to display_buffer_flat
);
```

Parser receives:
- `key_valid=1` (false trigger)
- `key_code=???` (whatever keypad thinks is selected)
- Parser adds CHARACTER to display buffer
- **But it's the WRONG character or at WRONG time!**

---

### STEP 4: PARSER (data_parser_accumulator.v)

```verilog
always @(posedge clk) begin
    if (key_valid) begin
        display_text[text_length*8 +: 8] <= ascii_char;  // ← CORRUPTED!
        text_length <= text_length + 1;
    end
end
```

Parser blindly trusts `key_valid` signal. If it's false trigger:
- Adds wrong character to buffer
- Increments text_length incorrectly
- **Display buffer now has garbage data!**

---

### STEP 5: VGA RENDER (calc_mode_module.v)

```verilog
wire [7:0] current_char = display_buffer_flat[char_index*8 +: 8];
// Renders characters from corrupted buffer to screen
```

VGA renderer displays whatever is in buffer:
- If buffer has garbage → VGA shows garbage
- If buffer empty because parser never triggered → VGA shows nothing

---

## ✅ NEW CODE (FIXED)

**STEP 1: OLED KEYPAD - Clean edge detection**

```verilog
wire [4:0] btn_pressed_raw = ~btn_debounced & btn_prev;  // Always accurate
wire [4:0] btn_pressed = enable ? btn_pressed_raw : 5'b00000;  // Gate output
always @(posedge clk) begin
    btn_prev <= btn_debounced;  // ✅ ALWAYS updates
end
```

**Timeline with FIX:**

```
| Time | Mode    | enable | btn[0] | btn_debounced[0] | btn_prev[0] | btn_pressed_raw[0] | btn_pressed[0] | key_valid |
| ---- | ------- | ------ | ------ | ---------------- | ----------- | ------------------ | -------------- | --------- |
| T=0  | WELCOME | 0      | UP     | 1                | 1           | 0                  | 0              | 0         |
| T=1  | WELCOME | 0      | DOWN   | 1→0              | 1           | 1 ✅                | 0 (gated) ✅    | 0 ✅       |
| T=2  | WELCOME | 0      | DOWN   | 0                | 0 ✅         | 0 (consumed)       | 0              | 0 ✅       |
| T=3  | CALC    | 1      | DOWN   | 0                | 0 ✅         | 0 ✅                | 0 ✅            | 0 ✅       |
| T=4  | CALC    | 1      | DOWN   | 0                | 0           | 0                  | 0              | 0         |
| T=5  | CALC    | 1      | UP     | 0→1              | 0           | 0                  | 0              | 0         |
| T=6  | CALC    | 1      | DOWN   | 1→0              | 1           | 1 ✅                | 1 ✅            | 1 ✅       |
```

**AT T=1-2:** Edge detected and consumed in WELCOME mode (but gated, so no output)
**AT T=3:** Switch to CALC with CLEAN STATE - no false trigger!
**AT T=6:** Real button press detected correctly

---

## THE CHAIN REACTION

**Old code:**
```
❌ False trigger at T=3
  ↓
❌ Parser receives spurious key_valid
  ↓
❌ Parser adds garbage to display_buffer
  ↓
❌ VGA renders garbage (or nothing if buffer empty)
```

**New code:**
```
✅ No false trigger - btn_prev always accurate
  ↓
✅ Parser only receives REAL key presses
  ↓
✅ display_buffer filled with CORRECT characters
  ↓
✅ VGA renders CORRECT text!
```

---

## SUMMARY

**Your observation:** "can't take in data from OLED or display in VGA"

**Root cause:** `btn_prev` frozen when `enable=0`, causing:
1. False triggers when transitioning to enabled mode
2. Spurious `key_valid` pulses
3. Parser receiving garbage inputs
4. Display buffer corrupted
5. VGA showing wrong/no text

**The fix:** Always update `btn_prev` to maintain edge detection accuracy, but gate the OUTPUT with enable.
