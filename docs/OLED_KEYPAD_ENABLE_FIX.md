# OLED Keypad Enable Signal Fix

## Date: October 18, 2025
## Issue: Keypad Processing Inputs Continuously

---

## 🐛 **The Problem You Identified:**

The OLED keypad module was running **all the time**, even in welcome mode, because:
- Clock signal always active
- Button detection always running
- State changes happening even when keypad should be inactive

**Result:**
- Keypad FSM constantly processing button presses
- Accumulating state changes in welcome mode
- Wasting power and potentially causing glitches

---

## ✅ **The Fix: Enable Signal**

### **What Changed:**

1. **Added `enable` input to oled_keypad module**
2. **Gated button press detection with enable**
3. **Only update FSM state when enabled**
4. **Connected enable from main.v based on mode**

---

## 📝 **Implementation Details:**

### **File 1: `oled_keypad.v`**

**Added enable input:**
```verilog
module oled_keypad (
    input clk,
    input reset,
    input enable,              // NEW: Enable signal - only process inputs when high
    input [12:0] pixel_index,
    input [4:0] btn_debounced,
    ...
);
```

**Gated button detection:**
```verilog
// BEFORE: Always detected button presses
wire [4:0] btn_pressed = ~btn_debounced & btn_prev;

// AFTER: Only detect when enabled
wire [4:0] btn_pressed = enable ? (~btn_debounced & btn_prev) : 5'b00000;
```

**Gated state updates:**
```verilog
always @(posedge clk) begin
    if (reset) begin
        // Reset logic
    end else begin
        // Only update button state when enabled
        if (enable) begin
            btn_prev <= btn_debounced;
        end

        // Only process button presses when enabled
        if (enable && btn_pressed[1]) begin  // Up
            // Handle up button
        end else if (enable && btn_pressed[4]) begin  // Down
            // Handle down button
        end else if (enable && btn_pressed[2]) begin  // Left
            // Handle left button
        end else if (enable && btn_pressed[3]) begin  // Right
            // Handle right button
        end else if (enable && btn_pressed[0]) begin  // Centre
            // Handle center button
        end
    end
end
```

---

### **File 2: `main.v`**

**Generate enable signal:**
```verilog
// Enable keypad only in calculator or grapher mode
wire keypad_enable = (current_main_mode == MODE_CALCULATOR | current_main_mode == MODE_GRAPHER);
```

**Connect enable to keypad:**
```verilog
oled_keypad oled_keypad_inst(
    .clk(clk),
    .reset(reset),
    .enable(keypad_enable),       // NEW: Only process inputs in calc/graph modes
    .pixel_index(pixel_index),
    .btn_debounced(btn_debounced),
    .oled_data(keypad_oled_raw),
    .key_code(keypad_key_code),
    .key_valid(keypad_key_valid_raw)
);
```

---

## 🎯 **How It Works Now:**

### **Mode: OFF (00)**
```
keypad_enable = 0
→ btn_pressed = 5'b00000 (no buttons detected)
→ btn_prev not updated (frozen state)
→ No FSM transitions
→ No key_valid pulses
```

### **Mode: WELCOME (01)**
```
keypad_enable = 0
→ btn_pressed = 5'b00000 (no buttons detected)
→ Keypad FSM frozen
→ Button presses ignored
→ No spurious inputs to parser
```

### **Mode: CALCULATOR (10)**
```
keypad_enable = 1
→ btn_pressed = ~btn_debounced & btn_prev (normal detection)
→ btn_prev updates normally
→ FSM processes button presses
→ key_valid pulses generated
→ Parser receives inputs
```

### **Mode: GRAPHER (11)**
```
keypad_enable = 1
→ Same as calculator mode
→ Full keypad functionality
```

---

## 📊 **Benefits:**

### **1. Correct Behavior**
- ✅ Keypad only active when needed
- ✅ No spurious inputs in welcome mode
- ✅ FSM state preserved when disabled

### **2. Power Savings**
- ✅ Reduced logic switching in welcome mode
- ✅ No unnecessary FSM state changes
- ✅ Button detection circuitry gated

### **3. Cleaner Design**
- ✅ Explicit enable/disable control
- ✅ Prevents unintended side effects
- ✅ Easier to debug

---

## 🔍 **Comparison:**

### **OLD Design (Enable Not Used):**
```
Welcome Mode:
  Clock: Running ✅
  Buttons: Detected ❌ (should be ignored)
  FSM: Updating ❌ (should be frozen)
  key_valid: Pulsing ❌ (should be 0)
  Result: Keypad active when it shouldn't be ❌
```

### **NEW Design (Enable Signal Added):**
```
Welcome Mode:
  Clock: Running ✅
  Enable: 0 ✅
  Buttons: Ignored ✅
  FSM: Frozen ✅
  key_valid: Always 0 ✅
  Result: Keypad properly disabled ✅
```

---

## 🧪 **Testing:**

### **Test 1: Welcome Mode**
1. Power on → Welcome mode (LED[13:12] = 01)
2. Press OLED buttons randomly
3. **Expected:** No FSM state changes, key_valid stays 0
4. **Expected:** LED[11:6] stays 000000 (no accumulation)

### **Test 2: Calculator Mode**
1. Navigate to calculator mode (LED[13:12] = 10)
2. Press OLED button
3. **Expected:** FSM responds, key_valid pulses
4. **Expected:** LED[11:6] increments

### **Test 3: Mode Switching**
1. In calculator, press buttons (LED[11:6] increments)
2. Switch back to welcome
3. Press buttons
4. **Expected:** LED[11:6] stays at same value (no more increments)

---

## 🚀 **Resource Impact:**

### **Logic Added:**
- 1 wire for `keypad_enable`
- 5-bit mux for `btn_pressed` gating
- Enable checks in button press handlers

### **Estimated LUT Cost:**
- `keypad_enable` wire: 0 LUTs (just routing)
- `btn_pressed` mux: ~5 LUTs (5-bit 2:1 mux)
- Enable ANDs: ~5 LUTs (5 button enable gates)
- **Total: ~10 LUTs** (0.05% of 20,800 available)

---

## ✅ **Summary:**

| Aspect               | Before      | After     |
| -------------------- | ----------- | --------- |
| Welcome mode buttons | Processed ❌ | Ignored ✅ |
| Welcome mode FSM     | Updating ❌  | Frozen ✅  |
| Calculator mode      | Works ✅     | Works ✅   |
| Power efficiency     | Poor ❌      | Good ✅    |
| Code clarity         | Unclear ❌   | Clear ✅   |

---

**This fix ensures the keypad only responds when it should, preventing spurious inputs and improving system integrity.**
