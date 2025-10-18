# Simulation Guide - Debug Parser & VGA Rendering

## Problem Analysis

You're right - we need to **simulate first** to find where the failure is:

**Possible Failure Points:**
1. ❌ Parser not receiving keys → `text_length` stays at 0
2. ❌ Parser not accumulating → `display_text` empty
3. ❌ VGA not reading buffer → No rendering even with valid data
4. ❌ Font ROM not loaded → All pixels white/gray
5. ❌ BRAM timing wrong → Garbled/shifted characters

---

## Test Strategy

We have **2 testbenches** to isolate the problem:

### **Test 1: Parser Only** (`tb_parser_only.v`)
- Tests ONLY the parser accumulator
- Simulates pressing keys '1', '2', '3'
- Checks if `text_length` increments
- Checks if `display_text` buffer contains 0x31, 0x32, 0x33

**If this fails:** Parser is broken (FSM not transitioning)
**If this passes:** Parser works, problem is in VGA rendering

### **Test 2: Full Calculator Mode** (`tb_calc_mode_text_display.v`)
- Tests complete data flow: Parser → Buffer → VGA rendering
- Scans VGA coordinates to check pixel output
- Verifies font ROM is working
- Checks border, background, and text rendering

**If this fails after Test 1 passes:** VGA rendering broken

---

## How to Run Simulations in Vivado

### **Option 1: Using Vivado GUI (Recommended)**

1. **Open Vivado Project:**
   ```
   Open project_shit/project_shit.xpr
   ```

2. **Add Testbench Files:**
   - Click "Add Sources" (Alt+A)
   - Select "Add or create simulation sources"
   - Click "Add Files"
   - Navigate to `project_vivado/sim/`
   - Add both:
     - `tb_parser_only.v`
     - `tb_calc_mode_text_display.v`
   - Click "Finish"

3. **Run Parser-Only Test First:**
   - In "Flow Navigator" → "Simulation" → "Run Simulation" → "Run Behavioral Simulation"
   - Right-click simulation set → "Set Top" → Select `tb_parser_only`
   - Click "Run Simulation"
   - Wait for simulation to complete
   - Check **TCL Console** for output messages

4. **Read Results:**
   ```
   Look for these messages in TCL Console:

   ✅ PASS: "✅ PARSER WORKS: Successfully accumulated '123'"
      → Parser is good, check VGA rendering next

   ❌ FAIL: "❌ CRITICAL FAILURE: text_length is still 0!"
      → Parser FSM broken, not receiving keys
   ```

5. **If Parser Passes, Run Full Test:**
   - Right-click simulation set → "Set Top" → Select `tb_calc_mode_text_display`
   - Run simulation again
   - Check for VGA rendering issues

---

### **Option 2: Using TCL Console (Faster)**

1. **Open TCL Console in Vivado**

2. **Run Parser Test:**
   ```tcl
   # Set working directory
   cd C:/Users/xiang/ee2026_Project/project_shit

   # Launch simulator with parser testbench
   launch_simulation -mode behavioral -simset sim_1 -top tb_parser_only

   # Run for 500ns (enough time for 3 key presses)
   run 500ns

   # Check waveform
   # Look at: text_length, display_text[23:0]
   ```

3. **Read Console Output:**
   - Simulation will print results directly to console
   - Look for "PARSER TEST SUMMARY"

4. **Run Full Test (if parser passes):**
   ```tcl
   # Close previous sim
   close_sim

   # Run full test
   launch_simulation -mode behavioral -simset sim_1 -top tb_calc_mode_text_display
   run 2us  # Longer because scanning VGA coordinates
   ```

---

### **Option 3: Standalone xvlog/xsim (Command Line)**

If you want to run without opening Vivado GUI:

```powershell
# Navigate to project directory
cd C:\Users\xiang\ee2026_Project\project_vivado

# Compile parser test
xvlog features\parser\data_parser_accumulator.v sim\tb_parser_only.v

# Elaborate
xelab -debug typical tb_parser_only -s tb_parser_sim

# Run simulation
xsim tb_parser_sim -runall

# Check output in console
```

---

## What to Look For

### **Test 1: Parser Only**

**Expected Output (PASS):**
```
========================================
Parser Accumulation Test
========================================

[0] Initial state:
  text_length = 0
  display_text[7:0] = 0x00

[30] Pressing key '1' (key_code=1)...
[90] After '1':
  text_length = 1 (expected: 1)  ✅
  display_text[7:0] = 0x31 (expected: 0x31)  ✅

[110] Pressing key '2' (key_code=2)...
[170] After '2':
  text_length = 2 (expected: 2)  ✅
  display_text[15:8] = 0x32 (expected: 0x32)  ✅

[190] Pressing key '3' (key_code=3)...
[250] After '3':
  text_length = 3 (expected: 3)  ✅
  display_text[23:16] = 0x33 (char 2, expected: 0x33)  ✅

========================================
PARSER TEST SUMMARY
========================================
✅ PARSER WORKS: Successfully accumulated '123'
   Problem is in VGA rendering, not parser!
```

**Expected Output (FAIL - Parser Broken):**
```
[90] After '1':
  text_length = 0 (expected: 1)  ❌
  display_text[7:0] = 0x00 (expected: 0x31)  ❌

  ❌ CRITICAL FAILURE: text_length is still 0!
  ❌ Parser FSM is NOT transitioning from IDLE!
  ❌ Check:
     1. Is key_valid actually reaching the parser?
     2. Is the FSM stuck in IDLE?
     3. Is rst properly released?
```

---

### **Test 2: Full Calculator Mode**

**Expected Output (VGA Working):**
```
TEST 4: VGA Text Rendering
========================================

Scanning 8x8 region at (15,15) to (22,22)...
  (x=15, y=15): vga_data = 0x000  ← Black pixel (font)
  (x=15, y=16): vga_data = 0xFFF  ← White background
  ...

Scan results:
  Total pixels: 64
  Black pixels (0x000): 12  ← Font pixels detected!
  ✓ TEST 4 PASSED: Font rendering detected (12 black pixels)
```

**Expected Output (VGA Broken):**
```
Scan results:
  Total pixels: 64
  Black pixels (0x000): 0  ← NO FONT RENDERING!
  ✗ TEST 4 FAILED: No black pixels found - Font not rendering!
    POSSIBLE CAUSES:
    1. Font ROM not initialized (all zeros)
    2. BRAM pipeline timing incorrect
    3. Bit-slicing extracting wrong character
    4. current_char always returning 0x20 (space)
```

---

## Debugging Based on Results

### **Scenario 1: Parser Test Fails (text_length = 0)**

**Problem:** Parser FSM not transitioning from IDLE

**Fix Locations to Check:**
1. `data_parser_accumulator.v` line ~180-200 (IDLE state)
2. Check if `key_valid` condition is correct
3. Check if `key_code <= KEY_9` comparison works

**Common Causes:**
- FSM never leaves IDLE because condition never true
- `key_valid` not being sampled correctly
- Reset logic keeping FSM stuck

---

### **Scenario 2: Parser Passes, VGA Test Shows No Pixels**

**Problem:** Font ROM not rendering

**Fix Locations to Check:**
1. `calc_mode_module.v` line ~100 (current_char extraction)
2. Check if `display_buffer_flat[char_index*8 +: 8]` is extracting correctly
3. Check if font ROM is initialized with `font.coe`
4. Check BRAM timing (pipeline registers)

**Test in Waveform:**
- Look at `current_char` signal → Should be 0x31 when rendering '1'
- Look at `font_addr` → Should be {0x31, char_row}
- Look at `font_row_data` → Should be non-zero font pixels

---

### **Scenario 3: Parser Passes, VGA Shows Wrong Characters**

**Problem:** Bit-slicing or indexing wrong

**Check:**
- Is character 0 at bits [7:0] or [255:248]?
- Is `char_index` calculation correct?
- Is text box position correct (starts at x=15)?

---

## Quick Simulation Commands

**Just run the parser test quickly:**
```tcl
# In Vivado TCL console
launch_simulation -mode behavioral -top tb_parser_only
run 500ns
```

**View waveforms:**
```tcl
# Add signals to waveform
add_wave /tb_parser_only/text_length
add_wave /tb_parser_only/display_text
add_wave /tb_parser_only/key_valid
add_wave /tb_parser_only/key_code
restart
run 500ns
```

---

## Expected Timeline

- ⏱️ Compile time: ~30 seconds
- ⏱️ Parser test runtime: ~0.5μs simulation time (instant)
- ⏱️ Full VGA test runtime: ~2μs simulation time (~1 minute real time)

---

## Next Steps After Simulation

1. **Run `tb_parser_only` first** → Confirm parser works
2. **If parser fails** → Fix parser FSM before touching VGA code
3. **If parser passes** → Run full test to check VGA rendering
4. **Report results** → Post console output so we can debug together

**DO NOT synthesize again until simulations pass!**
