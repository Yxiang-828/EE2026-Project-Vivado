# 🔍 Text Input Box Ghosting - Visual Explanation

## The Problem: Subpixel Leakage

### What You Were Seeing

```
Correct character '7':          Ghost artifact:
┌────────┐ GAP                  ┌────────┐
│████  ██│ │                    │████  ██│█  ← Leaked pixels
│    ██  │ │                    │    ██  │█
│   ██   │ │                    │   ██   │█
│  ██    │ │                    │  ██    │█
│  ██    │ │                    │  ██    │█
│  ██    │ │                    │  ██    │█
│  ██    │ │                    │  ██    │█
└────────┘ │                    └────────┘█
  x=2..9   x=10                  Extra column at x=10

AND ghosting below:
┌────────┐
│  ██    │█ ← y=11 (should be empty)
└────────┘█
```

---

## Root Cause Analysis

### 🐛 Bug #1: Gap Pixel Entering Logic

**OLD CODE (Buggy):**
```verilog
if (oled_x >= 2 && oled_x < 11) begin  // ❌ Includes x=10 (gap pixel)
    input_char_idx = 0;
    input_font_col = oled_x - 2;  // When x=10: font_col = 8
    if (input_font_col < 8 && input_char_idx < expression_length) 
        in_input_area = 1;  // ❌ Fails check BUT input_char_idx is already set!
end
```

**What happens at x=10:**
1. ✅ Enters the if-block (10 < 11)
2. ✅ Sets `input_char_idx = 0` (character '7')
3. ✅ Calculates `input_font_col = 8`
4. ❌ **Validation fails** (`font_col < 8` is false)
5. ❌ `in_input_area` stays 0, **BUT** `input_char_idx = 0` is already in pipeline!
6. 💥 **Pipeline registers capture stale `input_char_idx=0`**, even though area is invalid
7. 💥 Font ROM fetches column 8 of character '7' (out of bounds, wraps to next row)
8. 💥 **Ghost pixels appear at x=10**

---

### 🐛 Bug #2: Y-Coordinate Overflow

**OLD CODE (Buggy):**
```verilog
if (oled_y >= INPUT_Y_START && oled_y <= INPUT_Y_END) begin
    input_font_row = oled_y - INPUT_Y_START;  // When y=11: font_row = 11
    
    // ❌ NO CHECK if font_row < 8!
    if (oled_x >= 2 && oled_x < 11) begin
        // ... renders character even when font_row = 11 ...
    end
end
```

**What happens at y=11:**
1. ✅ `INPUT_Y_END = 11`, so condition passes
2. ✅ `input_font_row = 11`
3. ❌ **No validation** that `font_row < 8`
4. 💥 Font ROM address becomes `{char_code, 11[2:0]}` = `{char_code, 3'b011}` (row 3)
5. 💥 **Renders row 3 of the font at y=11** (should be empty)
6. 💥 **Ghost pixels appear below the text box**

---

## ✅ The Fix

### Fix #1: Tighten X-Bounds (Exclude Gap Pixels)

**NEW CODE:**
```verilog
if (oled_x >= 2 && oled_x < 10) begin  // ✅ EXCLUDES x=10 (gap pixel)
    input_char_idx = 0;
    input_font_col = oled_x - 2;  // Max value: 7 (when x=9)
    if (input_font_col < 8 && input_char_idx < expression_length) 
        in_input_area = 1;
end
// When x=10: Falls through to else, ALL flags stay 0
```

**Character Slot Boundaries (ALL Fixed):**
```
Char 0: x=2..9   (8 pixels) | x=10  (gap) ← Now excluded from if-block
Char 1: x=11..18 (8 pixels) | x=19  (gap) ← Now excluded
Char 2: x=20..27 (8 pixels) | x=28  (gap) ← Now excluded
Char 3: x=29..36 (8 pixels) | x=37  (gap) ← Now excluded
Char 4: x=38..45 (8 pixels) | x=46  (gap) ← Now excluded
Char 5: x=47..54 (8 pixels) | x=55  (gap) ← Now excluded
Char 6: x=56..63 (8 pixels) | x=64  (gap) ← Now excluded
Char 7: x=65..72 (8 pixels) | x=73  (gap) ← Now excluded
Char 8: x=74..81 (8 pixels) | x=82  (gap) ← Now excluded
Char 9: x=83..90 (8 pixels) | x=91  (gap) ← Now excluded
```

**Impact:**
- Gap pixels now **never enter** the character rendering logic
- Pipeline sees `in_input_area = 0` for gap pixels
- Stage 3 gating forces `font_data_reg = 8'h00` (black)
- **No more right-side ghosting**

---

### Fix #2: Add Y-Bounds Wrapper

**NEW CODE:**
```verilog
if (oled_y >= INPUT_Y_START && oled_y <= INPUT_Y_END) begin
    input_font_row = oled_y - INPUT_Y_START;
    
    // ✅ CRITICAL: Only process if font_row < 8
    if (input_font_row < 8) begin
        // ... character rendering logic ...
    end
    // When y=11: font_row=11, inner block skipped, flags stay 0
end
```

**Impact:**
- Y=11 now skips the inner block completely
- `in_input_area` stays 0
- **No more bottom ghosting**

---

### Fix #3: Explicit Flag Zeroing

**NEW CODE:**
```verilog
always @(*) begin
    // **CRITICAL: Default ALL flags to OFF**
    in_input_area = 0;  // ✅ EXPLICIT OFF
    in_cursor_pos = 0;  // ✅ EXPLICIT OFF
    // ... rest of combinational logic
```

**Impact:**
- Unless explicitly set to 1 within a valid region, flags stay OFF
- Prevents any stale values from previous clock cycles
- Pipeline sees clean 0s for invalid regions

---

## Before vs. After

### BEFORE (Buggy):
```
Text Input Box (Y=0..11, X=2..92):
┌────────────────────────────────────┐
│ 7 8 9                              │ ← Y=0..7 (correct)
│ ██                                 │ ← Y=8..10 (correct)
│█│█                                 │ ← Y=11 (GHOST - should be empty)
├─│─┴───────────────────────────────┤
  └─ X=10 (GHOST - gap pixel leaked)

Keypad Area (Y=12..63):
│ [7] [8] [9] [/] [C]                │
```

### AFTER (Fixed):
```
Text Input Box (Y=0..11, X=2..92):
┌────────────────────────────────────┐
│ 7 8 9                              │ ← Y=0..7 (correct)
│ ██                                 │ ← Y=8..10 (correct)
│                                    │ ← Y=11 (CLEAN - no ghost)
├────────────────────────────────────┤
  ^ X=10,19,28... (CLEAN - gaps are black)

Keypad Area (Y=12..63):
│ [7] [8] [9] [/] [C]                │
```

---

## 🎯 Key Takeaways

### The 3-Layer Defense Against Ghosting:

1. **Combinational Logic Layer**
   - Tightened X-bounds to exclude gap pixels
   - Added Y-bounds wrapper (`if (input_font_row < 8)`)
   - Explicit flag defaults (`in_input_area = 0`)

2. **Pipeline Register Layer**
   - Stage 1: Capture coordinate mapping results
   - Stage 2: Capture character selection + **explicit space for invalid regions**
   - Stage 3: **Gate font data** - only pass through if valid area

3. **Output Logic Layer**
   - Default to BLACK for invalid regions
   - Only render white pixels when `in_input_reg` is HIGH

### Why This Works:

- **Gap pixels** now fall through to else case → flags stay 0 → pipeline zeroed → BLACK output
- **Out-of-bounds Y** now skips inner block → flags stay 0 → pipeline zeroed → BLACK output
- **Font ROM latency** is absorbed by pipeline stages with explicit gating

---

## 🧪 Testing Checklist

After this fix, you should see:

- [ ] **No ghosting to the right** of any character in text input box
- [ ] **No ghosting below** the text input box (Y=11 should be empty)
- [ ] **Clean 1-pixel gaps** between characters (x=10, 19, 28, etc.)
- [ ] **No artifacts** when typing/deleting characters
- [ ] **VGA not affected** by OLED rendering (separate pipelines)

---

## 📊 Code Changes Summary

| File | Lines Changed | Critical Sections |
|------|---------------|-------------------|
| `oled_keypad.v` | 20 lines | X-bounds tightened (10 character slots) |
| | | Y-bounds wrapper added |
| | | Explicit flag defaults |

**Total Impact:** 3 independent fixes working together to eliminate all ghosting artifacts.

✅ **Status:** Ready for synthesis and hardware testing.
