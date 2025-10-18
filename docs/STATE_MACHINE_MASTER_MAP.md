# Complete System State Machine - User Interaction Flow Map

## Date: October 18, 2025
## Purpose: Master Reference for System Behavior & Verification

---

# 🗺️ STATE MACHINE OVERVIEW

```
┌─────────────┐
│   POWER-ON  │
│   (Reset)   │
└──────┬──────┘
       │
       ↓
┌─────────────┐
│  MODE_OFF   │ (sw[15] = 0)
│  (State 00) │
└──────┬──────┘
       │ sw[15] = 1
       ↓
┌─────────────┐     btn navigation      ┌──────────────┐
│MODE_WELCOME │────────────────────────→│MODE_CALCULATOR│
│ (State 01)  │                         │  (State 10)   │
└─────────────┘                         └───────┬───────┘
       │                                        │
       │ btn navigation                         │ btn navigation
       ↓                                        ↓
┌─────────────┐                         ┌──────────────┐
│MODE_GRAPHER │←────────────────────────│  (can switch  │
│ (State 11)  │    btn navigation       │   back)       │
└─────────────┘                         └──────────────┘
```

---

# 📋 STATE 0: MODE_OFF (00)

## **System Status:**
- **Power:** ON (FPGA powered)
- **Clock:** Running (100MHz)
- **Reset:** sw[15] = 0 (active reset)

## **What SHOULD Work:**
✅ Clock distribution
✅ Power LEDs on Basys3 board
✅ Nothing else (system held in reset)

## **What SHOULD NOT Work:**
❌ OLED display (blank/off)
❌ VGA output (should show black or sync-only)
❌ Button inputs (ignored)
❌ LEDs (should be off or show reset state)
❌ All modules held in reset state

## **Expected Outputs:**
| Output     | Expected Value   | Notes           |
| ---------- | ---------------- | --------------- |
| OLED       | 16'h0000 (black) | Display off     |
| VGA        | 12'h000 (black)  | No video signal |
| LED[13:12] | 00               | Mode = OFF      |
| LED[11:0]  | 0                | All zeros       |
| seg/an     | Off              | 7-segment off   |

## **User Actions:**
- **Action:** Flip sw[15] to 1
- **Result:** Transition to MODE_WELCOME
- **LED Change:** LED[13:12] changes from `00` → `01`

## **Integrity Checks:**
- [ ] VGA shows black screen (no flickering)
- [ ] OLED is completely blank
- [ ] LED[13:12] = `00`
- [ ] No response to button presses

---

# 📋 STATE 1: MODE_WELCOME (01)

## **System Status:**
- **Power:** ON
- **Clock:** Running (100MHz)
- **Reset:** Released (sw[15] = 1)
- **Active Module:** `welcome_mode_module`

## **What SHOULD Work:**
✅ VGA display showing welcome screen
✅ Welcome module button navigation
✅ Mode selection via buttons
✅ OLED shows welcome graphics (if implemented)
✅ LED[13:12] = `01` (mode indicator)

## **What SHOULD NOT Work:**
❌ **OLED keypad display** (should be BLANK - gated by mode)
❌ **Keypad button input processing** (key_valid gated OFF)
❌ **Data parser** (not accumulating, key_valid = 0)
❌ **Calculator VGA output** (not selected by mux)
❌ **Grapher VGA output** (not selected by mux)
❌ LED[11:6] should stay at `000000` (no text buffer active)

## **Expected Outputs:**
| Output     | Expected Value        | Notes                                   |
| ---------- | --------------------- | --------------------------------------- |
| OLED       | `welcome_screen_oled` | Welcome graphics (or blank if not impl) |
| VGA        | `welcome_screen_vga`  | Welcome screen with menu                |
| LED[13:12] | `01`                  | Mode = WELCOME                          |
| LED[11:6]  | `000000`              | No buffer length (gated)                |
| LED[5]     | `0`                   | key_valid gated OFF                     |
| LED[4:0]   | Any                   | Key code (but ignored)                  |

## **Critical Gating Checks:**
```verilog
// In main.v:
wire keypad_key_valid = keypad_key_valid_raw &
    (current_main_mode == MODE_CALCULATOR | current_main_mode == MODE_GRAPHER);
```
✅ **MUST BE FALSE in welcome mode** → Parser doesn't accumulate

```verilog
wire [15:0] keypad_oled = (current_main_mode == MODE_CALCULATOR ||
                           current_main_mode == MODE_GRAPHER) ?
                           keypad_oled_raw : 16'h0000;
```
✅ **MUST OUTPUT 16'h0000 in welcome mode** → OLED keypad blank

## **User Actions:**

### **Action 1: Press buttons to navigate welcome menu**
- **SHOULD:** VGA shows menu selection highlighting
- **SHOULD:** Welcome module processes button input
- **SHOULD NOT:** OLED show keypad
- **SHOULD NOT:** LED[11:6] increment
- **LED[5]:** Should stay `0` (key_valid gated)

### **Action 2: Select "Calculator Mode"**
- **Result:** `welcome_mode_req` asserted, `welcome_mode_target = MODE_CALCULATOR`
- **Transition:** MODE_WELCOME → MODE_CALCULATOR
- **LED Change:** LED[13:12] changes from `01` → `10`
- **OLED Change:** Blank → Keypad interface appears
- **VGA Change:** Welcome screen → Calculator text box + background

### **Action 3: Select "Grapher Mode"**
- **Result:** Similar to Action 2, but target = MODE_GRAPHER
- **LED Change:** LED[13:12] changes from `01` → `11`

## **Integrity Checks:**
- [ ] VGA shows welcome screen (not flickering black)
- [ ] OLED is **completely blank** (keypad NOT visible)
- [ ] LED[13:12] = `01`
- [ ] LED[11:6] = `000000` (stays zero even if pressing OLED buttons)
- [ ] LED[5] = `0` (key_valid always low)
- [ ] Button presses on OLED buttons do NOT increment LED[11:6]

**🚨 CRITICAL TEST:** Press center button on OLED panel multiple times:
- **Expected:** LED[11:6] stays at `000000`
- **Expected:** LED[5] stays at `0`
- **If LED[11:6] increments:** Key gating NOT working → FIX REQUIRED

---

# 📋 STATE 2: MODE_CALCULATOR (10)

## **System Status:**
- **Power:** ON
- **Clock:** Running (100MHz)
- **Reset:** Released
- **Active Module:** `calc_mode_module`
- **Active Parser:** `data_parser_accumulator` inside calc_mode_module

## **What SHOULD Work:**
✅ **OLED keypad display** (visible and interactive)
✅ **Keypad button processing** (key_valid gated ON)
✅ **Data parser accumulation** (building number strings)
✅ **VGA text box display** (showing typed characters)
✅ **LED[11:6] incrementing** as you type
✅ **LED[5] blinking** on key presses
✅ Font ROM rendering characters to VGA
✅ Calculator logic (future: not yet implemented)

## **What SHOULD NOT Work:**
❌ Welcome screen (not selected by VGA mux)
❌ Grapher screen (not selected by VGA mux)
❌ Grapher parser accumulation (its parser instance exists but gets different key stream)

## **Expected Outputs:**
| Output     | Expected Value          | Notes                    |
| ---------- | ----------------------- | ------------------------ |
| OLED       | `keypad_oled_raw`       | Keypad interface visible |
| VGA        | `calculator_screen_vga` | Text box + calc UI       |
| LED[13:12] | `10`                    | Mode = CALCULATOR        |
| LED[11:6]  | `000000` to `100000`    | Buffer length (0-32)     |
| LED[5]     | Blinks on press         | key_valid indicator      |
| LED[4:0]   | Key code                | Shows pressed key        |

## **Parser State:**
```verilog
// Inside calc_mode_module:
data_parser_accumulator parser_inst(
    .clk(clk),
    .rst(reset),  // Global reset only
    .key_code(keypad_key_code),
    .key_valid(keypad_key_valid),  // NOW GATED ON
    .display_text(display_buffer_flat),  // 256-bit packed
    .text_length(display_length)  // Exposed to LED[11:6]
);
```

## **VGA Rendering Pipeline:**
```
Clock N:   vga_x, vga_y → char_index → current_char → font_addr
Clock N+1: BRAM outputs font_row_data
Clock N+2: font_pixel extracted → vga_data output (registered)
```

## **User Actions:**

### **Action 1: Press number key '1'**
1. **Button pressed on OLED**
2. **Keypad module:** Detects button, outputs `key_code = 5'b00001`, `key_valid_raw = 1`
3. **Main.v gating:** `keypad_key_valid = 1` (mode check passes)
4. **Parser:** Receives key_code, accumulates '1' (ASCII 8'h31)
5. **Buffer update:** `display_buffer_flat[7:0] <= 8'h31`
6. **Length update:** `display_length <= 1`
7. **LED update:** `LED[11:6] = 000001`
8. **VGA update:** Text box shows '1' at position (15, 15)

**Timeline:**
```
Cycle 0: Button pressed
Cycle 1: key_valid_raw = 1, key_code = 1
Cycle 2: Parser FSM processes, display_length = 0 → 1
Cycle 3: display_buffer_flat[7:0] = 8'h31 ('1')
Cycle 4: LED[11:6] updates to 000001
Cycle N: VGA scans text box area
Cycle N+1: BRAM reads character '1' font data
Cycle N+2: Font pixels rendered to VGA
```

**Expected Results:**
- ✅ LED[11:6] changes: `000000` → `000001`
- ✅ LED[5] blinks high for 1 cycle
- ✅ LED[4:0] = `00001` (key code for '1')
- ✅ VGA shows '1' in text box
- ✅ OLED highlights selected cell, then returns to normal

### **Action 2: Press number key '2'**
- **Similar to Action 1**
- **Buffer:** `display_buffer_flat[15:8] <= 8'h32` ('2')
- **Length:** `display_length <= 2`
- **LED:** `LED[11:6] = 000010`
- **VGA:** Shows "12" in text box

### **Action 3: Press operator key '+'**
- **Keypad:** `key_code = 5'b01010`, `key_valid_raw = 1`
- **Parser:** Detects operator, sets `operator_ready = 1`
- **Buffer:** Operator may or may not appear in display (depends on parser design)
- **Expected:** Parser finalizes current number, prepares for next

### **Action 4: Press clear 'C'**
- **Keypad:** `key_code = 5'b11010`
- **Parser:** Sets `clear_pressed = 1`
- **Buffer:** Clears all, `display_length = 0`
- **LED:** `LED[11:6] = 000000`
- **VGA:** Text box clears (shows empty white box)

### **Action 5: Type "123.45"**
**Step-by-step LED changes:**
```
Initial:      LED[11:6] = 000000
Press '1':    LED[11:6] = 000001  (VGA: "1")
Press '2':    LED[11:6] = 000010  (VGA: "12")
Press '3':    LED[11:6] = 000011  (VGA: "123")
Press '.':    LED[11:6] = 000100  (VGA: "123.")
Press '4':    LED[11:6] = 000101  (VGA: "123.4")
Press '5':    LED[11:6] = 000110  (VGA: "123.45")
```

**VGA Output:**
```
┌──────────────────────────────────────────┐ ← y=10
│                                          │
│  123.45                                  │ ← y=15 (text)
│                                          │
│                                          │
└──────────────────────────────────────────┘ ← y=50
   ↑
 x=15
```

### **Action 6: Fill buffer (32 chars)**
- **Type 32 characters**
- **LED:** `LED[11:6] = 100000` (binary 32)
- **VGA:** Text box shows full line of text
- **Next press:** Parser should either ignore or trigger overflow error

## **Integrity Checks:**

### **Startup Checks:**
- [ ] LED[13:12] = `10` (mode indicator)
- [ ] LED[11:6] = `000000` (empty buffer)
- [ ] OLED shows keypad interface
- [ ] VGA shows white text box with black border at (10,10) to (630,50)
- [ ] No flickering patterns

### **Keypress Checks:**
- [ ] LED[5] blinks high when button pressed
- [ ] LED[4:0] shows correct key code
- [ ] LED[11:6] increments by 1 for each character key
- [ ] LED[11:6] resets to 0 when 'C' pressed

### **VGA Rendering Checks:**
- [ ] Characters appear at correct position (15, 15)
- [ ] Font is readable (8x8 pixels per character)
- [ ] No character ghosting or bleeding
- [ ] Text box background is white
- [ ] Border is black and solid
- [ ] Outside text box is gray (12'h888)

### **Parser Checks:**
- [ ] Single digit keys accumulate: '1','2','3' → "123"
- [ ] Decimal point works: '1','.','5' → "1.5"
- [ ] Clear works: type "123", press 'C' → LED[11:6] = 0
- [ ] Delete works: type "123", press 'D' → "12" (LED[11:6] = 2)

### **BRAM Pipeline Checks:**
```
Verification test: Type '8'
Cycle N:   char_index = 0, font_addr = {8'h38, char_row}
Cycle N+1: font_row_data = <8-bit pattern for '8'>
Cycle N+2: font_pixel extracted, vga_data rendered
```
- [ ] No 1-cycle offset in character position
- [ ] Character appears solid (not shifted/garbled)

---

# 📋 STATE 3: MODE_GRAPHER (11)

## **System Status:**
- **Power:** ON
- **Clock:** Running (100MHz)
- **Active Module:** `graph_mode_module`
- **Active Parser:** `data_parser_accumulator` inside graph_mode_module

## **What SHOULD Work:**
✅ Everything same as MODE_CALCULATOR, but:
✅ VGA shows graph area below text box (y=60 to y=470)
✅ LED[13:12] = `11`
✅ LED[11:6] shows equation_length instead of display_length
✅ Graph plotting area visible (black area for now)

## **What SHOULD NOT Work:**
❌ Calculator VGA output
❌ Calculator parser (different instance)
❌ Graph plotting (not yet implemented - shows black)

## **Expected Outputs:**
| Output     | Expected Value       | Notes                 |
| ---------- | -------------------- | --------------------- |
| OLED       | `keypad_oled_raw`    | Keypad interface      |
| VGA        | `grapher_screen_vga` | Text box + graph area |
| LED[13:12] | `11`                 | Mode = GRAPHER        |
| LED[11:6]  | `000000` to `100000` | Equation length       |
| LED[5]     | Blinks on press      | key_valid indicator   |

## **User Actions:**
- **Same as Calculator mode**
- **Type equation like "x^2+3"**
- **LED[11:6] increments with each character**
- **VGA shows equation in text box**

## **Integrity Checks:**
- Same as Calculator mode, plus:
- [ ] Graph area visible below text box (black for now)
- [ ] Graph area coordinates: y=60 to y=470

---

# 🔄 MODE TRANSITIONS

## **WELCOME → CALCULATOR**
```
Trigger: welcome_mode_req = 1, welcome_mode_target = MODE_CALCULATOR
Result:  current_main_mode changes 01 → 10

Before:
- OLED: Blank
- VGA: Welcome screen
- LED[13:12]: 01
- LED[11:6]: 000000
- key_valid: 0 (gated)

After (1 clock cycle):
- OLED: Keypad appears
- VGA: Calculator text box
- LED[13:12]: 10
- LED[11:6]: 000000 (starts empty)
- key_valid: 1 when pressed (gated ON)
```

**Integrity Check:**
- [ ] Transition happens in 1 clock cycle
- [ ] No glitches on VGA
- [ ] Parser starts fresh (display_length = 0)
- [ ] OLED keypad appears immediately

## **WELCOME → GRAPHER**
- Similar to above, LED[13:12] = `11`

## **CALCULATOR ↔ GRAPHER**
```
Question: Can user switch between calc and graph directly?
Answer: Depends on implementation - check welcome_mode module logic
```

**If allowed:**
- [ ] Buffer contents should clear on mode switch
- [ ] LED[11:6] resets to 0
- [ ] No data persistence between modes

---

# 🧪 COMPREHENSIVE TEST PROCEDURE

## **Test Suite 1: Power-On Sequence**
1. sw[15] = 0 (reset active)
   - Check: LED[13:12] = `00`
   - Check: OLED blank
   - Check: VGA black
2. sw[15] = 1 (release reset)
   - Check: LED[13:12] → `01` (welcome)
   - Check: VGA shows welcome screen
   - Check: OLED still blank

## **Test Suite 2: Welcome Mode Isolation**
1. In welcome mode
2. Press all OLED keypad buttons randomly
   - Check: LED[11:6] stays `000000` (CRITICAL)
   - Check: LED[5] stays `0` (CRITICAL)
   - Check: OLED remains blank (CRITICAL)
3. If any of above fail → **KEY GATING BROKEN**

## **Test Suite 3: Calculator Mode Entry**
1. Navigate to calculator mode
   - Check: LED[13:12] = `10`
   - Check: OLED shows keypad
   - Check: VGA shows text box
2. Press '1'
   - Check: LED[5] blinks
   - Check: LED[11:6] = `000001`
   - Check: VGA shows '1'
3. If LED[11:6] = 0 → **PARSER NOT WORKING**
4. If LED[11:6] increments but no VGA → **BRAM/RENDERING ISSUE**

## **Test Suite 4: Buffer Accumulation**
1. Type "0123456789"
   - Check: LED[11:6] = `001010` (binary 10)
   - Check: VGA shows all 10 characters
2. Press 'C' (clear)
   - Check: LED[11:6] = `000000`
   - Check: VGA text box clears
3. Type "ABC" (if available)
   - Check: Each key increments LED[11:6]

## **Test Suite 5: Mode Switching**
1. In calculator, type "123"
   - LED[11:6] = `000011`
2. Switch to grapher mode
   - Check: LED[13:12] = `11`
   - Check: LED[11:6] resets to `000000` (SHOULD CLEAR)
3. Type "456" in grapher
   - Check: LED[11:6] = `000011`
4. Switch back to calculator
   - Check: Buffer state (persistent or cleared?)

---

# ✅ MASTER INTEGRITY CHECKLIST

## **Hardware Gating Verification:**
- [ ] `keypad_key_valid` gating logic correct in main.v
- [ ] `keypad_oled` blanking logic correct in main.v
- [ ] Mode comparisons use correct constants (MODE_CALCULATOR = 2'b10)

## **Signal Routing Verification:**
- [ ] `keypad_key_code` connects keypad → calc/graph modules
- [ ] `keypad_key_valid` (gated) connects to parsers
- [ ] `calc_display_length` connects to LED mux
- [ ] `graph_equation_length` connects to LED mux
- [ ] `current_main_mode` available for comparisons

## **Parser State Verification:**
- [ ] Parser receives gated key_valid
- [ ] Parser `display_text` is 256-bit packed
- [ ] Parser `text_length` exposed to debug port

## **VGA Rendering Verification:**
- [ ] `display_buffer_flat` uses correct bit-slicing
- [ ] BRAM pipeline has 1-cycle delay compensation
- [ ] Font ROM address = {char_code[7:0], char_row[2:0]}
- [ ] Output is registered (`always @(posedge clk)`)

## **Mode Multiplexer Verification:**
- [ ] OLED mux selects correct source per mode
- [ ] VGA mux selects correct source per mode
- [ ] LED mux shows correct mode in [13:12]
- [ ] LED mux shows correct length in [11:6]

---

# 🚨 COMMON FAILURE MODES & DIAGNOSIS

## **Symptom: LED[11:6] stays 0 in calc mode**
**Diagnosis Steps:**
1. Check LED[5] - does it blink?
   - NO → key_valid not reaching parser → Check gating logic
   - YES → key_valid works, parser issue → Check parser FSM
2. Check LED[4:0] - does it change when pressing keys?
   - NO → Keypad not outputting key_code → Check keypad module
   - YES → Keypad works, issue downstream

**Root Causes:**
- Mode gating logic inverted
- Parser not instantiated correctly
- Parser in permanent reset

## **Symptom: LED[11:6] increments but no VGA text**
**Diagnosis:** Parser works, rendering broken
1. Check if text box visible (white background)
   - NO → VGA mux selecting wrong source
   - YES → Font rendering issue
2. Simulate to check BRAM outputs
   - If BRAM outputs 0x00 → Font ROM not loaded
   - If BRAM outputs valid → Pipeline timing issue

**Root Causes:**
- BRAM not initialized with `font.coe`
- Bit-slicing wrong (`[char_index*8 +: 8]` vs `[(31-char_index)*8 +: 8]`)
- Pipeline registers not delaying control signals

## **Symptom: OLED keypad visible in welcome mode**
**Diagnosis:** OLED blanking not working
1. Check `keypad_oled` assignment in main.v
2. Verify mode comparison logic
3. Check if `current_main_mode` updating correctly

**Root Cause:**
- Blanking logic missing or incorrect
- Mode constants wrong

## **Symptom: Flickering VGA patterns**
**Diagnosis:** Uninitialized or wrong BRAM data
1. Check if `display_length = 0`
2. Check if `current_char = 0x00` (NULL)
3. Verify BRAM address range

**Root Cause:**
- Font ROM addresses for NULL/space contain garbage
- Need to initialize BRAM properly or skip rendering when length=0

---

# 📊 EXPECTED LED PATTERNS (Quick Reference)

```
MODE_OFF:       LED[13:0] = 00_000000_0_00000
MODE_WELCOME:   LED[13:0] = 01_000000_0_xxxxx (keys ignored)
MODE_CALC (empty):         10_000000_0_00000
MODE_CALC (typed "1"):     10_000001_0_00001 (then LED[5]=0)
MODE_CALC (typed "123"):   10_000011_0_xxxxx
MODE_CALC (full 32 chars): 10_100000_0_xxxxx
MODE_GRAPH (empty):        11_000000_0_00000
```

---

# 🎯 SUMMARY: WHAT MUST WORK AT EACH STATE

| State      | OLED Keypad | VGA Output   | LED[11:6]  | Key Processing  | Notes            |
| ---------- | ----------- | ------------ | ---------- | --------------- | ---------------- |
| OFF        | ❌ Blank     | ❌ Black      | 000000     | ❌ None          | System reset     |
| WELCOME    | ❌ **BLANK** | ✅ Welcome    | 000000     | ❌ **GATED OFF** | **CRITICAL**     |
| CALCULATOR | ✅ Visible   | ✅ Text box   | Increments | ✅ Active        | Normal operation |
| GRAPHER    | ✅ Visible   | ✅ Text+Graph | Increments | ✅ Active        | Normal operation |

**KEY INTEGRITY RULE:**
**If OLED keypad visible in WELCOME mode OR LED[11:6] increments in WELCOME mode → SYSTEM BROKEN**

---

**This document is the MASTER REFERENCE. Always verify against this before claiming a fix works.**
