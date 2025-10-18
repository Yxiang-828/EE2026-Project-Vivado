# FPGA Calculator Implementation Plan
**Status Assessment & Detailed Roadmap**

---

## 🔍 CURRENT STATE ANALYSIS

### ✅ What You HAVE (Complete)
1. **OLED Keypad Module** (`features/keypad/oled_keypad.v`)
   - ✅ 2-page navigation (numbers + functions)
   - ✅ 5-stage pipeline (no ghosting/fuzzing)
   - ✅ Expression buffer display
   - ✅ Cursor positioning and blinking
   - **Status:** WORKING, but outputs ASCII (needs interface change)

2. **Calculator Module Stub** (`features/calculator/calculator_module.v`)
   - ✅ Basic state machine structure
   - ✅ Q16.8 format awareness
   - ✅ Placeholder for operator handling
   - **Status:** STUB (needs complete rewrite per spec)

3. **Top Module** (`main.v`)
   - ✅ Mode switching (OFF/WELCOME/CALCULATOR/GRAPHER)
   - ✅ OLED keypad instantiated
   - **Status:** Partially wired (missing data flow)

### ❌ What You DON'T HAVE (Critical Missing)
1. **Data Parser Module** - DOES NOT EXIST
2. **Calculator Core FSM** - Current calc module is oversimplified
3. **ALU Modules** (6 types) - NONE EXIST
4. **ALU Controller** - DOES NOT EXIST
5. **Proper wiring** between modules

---

## 🚨 CRITICAL ISSUE: The Long Document's Approach Has Problems

### Why That Plan Won't Work Well For You:

1. **Too Complex Upfront**
   - Requires building 6 ALU modules before testing anything
   - Data parser FSM is over-engineered (3 states for number entry)
   - Shunting-Yard precedence before basic math works

2. **Testing Bottleneck**
   - Can't test OLED changes until full pipeline exists
   - No incremental validation
   - High risk of integration bugs

3. **Resource Waste**
   - You already have expression buffer in OLED module
   - Calculator stub has Q16.8 conversion started
   - Duplicates functionality across modules

---

## ✅ BETTER APPROACH: Incremental Integration

### Philosophy:
> **"Make it work, make it right, make it fast"**
> - Start with simplest possible data flow
> - Test each addition before moving on
> - Reuse existing code where possible

---

## 📋 REVISED IMPLEMENTATION PLAN

### PHASE 0: Setup & Baseline (1 hour)
**Goal:** Establish testing infrastructure

- [ ] **0.1** Create test document to track results
- [ ] **0.2** Verify current OLED keypad compiles and displays
- [ ] **0.3** Document current key mappings from `oled_keypad.v`
- [ ] **0.4** Create backup branch: `git checkout -b working-baseline`

**Output:** Known-good baseline to revert to

---

### PHASE 1: Minimal Interface Change (2-3 hours)
**Goal:** Get OLED sending 5-bit codes without breaking display

#### Task 1.1: Add Output Ports to OLED Keypad
**File:** `project_vivado/features/keypad/oled_keypad.v`

**Changes:**
```verilog
module oled_keypad (
    input clk,
    input reset,
    input [12:0] pixel_index,
    input [4:0] btn_debounced,
    output reg [15:0] oled_data,

    // NEW: Simple 5-bit output interface
    output reg [4:0] key_code,      // 5-bit code (0-28)
    output reg key_valid            // 1-cycle pulse when pressed
);
```

**Implementation:**
- Keep ALL existing logic (display, expression buffer, cursor)
- Add `key_code` and `key_valid` outputs ONLY
- Modify button press logic to SET these signals alongside existing ASCII insertion
- **DON'T remove ASCII logic yet** - we'll phase it out later

**Test:** LED[4:0] = key_code, LED[15] = key_valid

---

#### Task 1.2: Create Minimal Data Parser (Passthrough)
**File:** `project_vivado/features/parser/data_parser.v` (NEW)

**Ultra-Simple Version 1.0:**
```verilog
module data_parser (
    input clk,
    input reset,
    
    // Input from OLED Keypad
    input [4:0] key_code,
    input key_valid,
    
    // Output to Calculator (MINIMAL)
    output reg [3:0] digit_value,      // 0-9 (for digits)
    output reg digit_valid,            // Pulse: digit ready
    output reg [3:0] operator_code,    // R_OP from spec
    output reg operator_valid          // Pulse: operator ready
);

    // KEY CODE CONSTANTS (match your OLED keypad)
    localparam KEY_0 = 5'd0;
    localparam KEY_1 = 5'd1;
    // ... KEY_2 through KEY_9 = 5'd2 to 5'd9
    localparam KEY_ADD = 5'd10;
    localparam KEY_SUB = 5'd11;
    localparam KEY_MUL = 5'd12;
    localparam KEY_DIV = 5'd13;
    localparam KEY_EQUAL = 5'd14;
    
    // PASSTHROUGH LOGIC (NO FSM YET)
    always @(posedge clk) begin
        if (reset) begin
            digit_valid <= 0;
            operator_valid <= 0;
        end else begin
            // Default: clear pulses
            digit_valid <= 0;
            operator_valid <= 0;
            
            if (key_valid) begin
                // Check if digit (0-9)
                if (key_code >= KEY_0 && key_code <= 5'd9) begin
                    digit_value <= key_code[3:0];
                    digit_valid <= 1;
                end
                // Check if operator
                else if (key_code >= KEY_ADD && key_code <= KEY_DIV) begin
                    operator_code <= key_code[3:0] - 10;  // Map to 0-3
                    operator_valid <= 1;
                end
                else if (key_code == KEY_EQUAL) begin
                    operator_code <= 4'd15;  // Special code for '='
                    operator_valid <= 1;
                end
            end
        end
    end

endmodule
```

**Test:** Connect outputs to LEDs, verify digit/operator detection

---

#### Task 1.3: Wire Parser to Main Module
**File:** `project_vivado/main.v`

**Changes:**
```verilog
// Wire declarations (add after oled_keypad instantiation)
wire [4:0] keypad_key_code;
wire keypad_key_valid;

oled_keypad oled_keypad_inst(
    .clk(clk),
    .reset(reset),
    .pixel_index(pixel_index),
    .btn_debounced(btn_debounced),
    .oled_data(keypad_oled),
    // NEW OUTPUTS
    .key_code(keypad_key_code),
    .key_valid(keypad_key_valid)
);

// Data Parser instantiation (NEW)
wire [3:0] parser_digit_value;
wire parser_digit_valid;
wire [3:0] parser_operator_code;
wire parser_operator_valid;

data_parser parser_inst (
    .clk(clk),
    .reset(reset),
    .key_code(keypad_key_code),
    .key_valid(keypad_key_valid),
    .digit_value(parser_digit_value),
    .digit_valid(parser_digit_valid),
    .operator_code(parser_operator_code),
    .operator_valid(parser_operator_valid)
);
```

**Test:** Program FPGA, verify:
- OLED display still works
- LEDs show key codes when buttons pressed

---

### PHASE 2: Simple Calculator (Add Only) (3-4 hours)
**Goal:** Get "5 + 3 = 8" working end-to-end

#### Task 2.1: Build Number Accumulator in Parser
**File:** `project_vivado/features/parser/data_parser.v`

**Add FSM to build Q16.8 numbers:**
```verilog
// Add to module outputs:
output reg [23:0] parsed_number,   // Q16.8 format
output reg number_ready            // Pulse: full number accumulated

// Add internal registers:
reg [15:0] integer_accumulator;    // Max 65535
reg [2:0] digit_count;
localparam IDLE = 0, ACCUMULATING = 1;
reg state;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        integer_accumulator <= 0;
        digit_count <= 0;
        number_ready <= 0;
    end else begin
        number_ready <= 0;
        
        case (state)
            IDLE: begin
                if (digit_valid) begin
                    integer_accumulator <= {12'b0, digit_value};
                    digit_count <= 1;
                    state <= ACCUMULATING;
                end
            end
            
            ACCUMULATING: begin
                if (digit_valid) begin
                    // Multiply by 10 and add new digit
                    integer_accumulator <= (integer_accumulator * 10) + digit_value;
                    digit_count <= digit_count + 1;
                end
                else if (operator_valid) begin
                    // Convert to Q16.8: shift left 8 bits
                    parsed_number <= {8'b0, integer_accumulator} << 8;
                    number_ready <= 1;
                    integer_accumulator <= 0;
                    digit_count <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
end
```

**Test:** Type "123", press "+", check parsed_number = 0x007B00 (123.0 in Q16.8)

---

#### Task 2.2: Build Simple 2-Number Calculator
**File:** `project_vivado/features/calculator/simple_calculator.v` (NEW)

**Ultra-Simple State Machine:**
```verilog
module simple_calculator (
    input clk,
    input reset,
    
    // From Parser
    input [23:0] parsed_number,
    input number_ready,
    input [3:0] operator_code,
    input operator_valid,
    
    // Output
    output reg [23:0] result,
    output reg result_valid
);

    localparam WAIT_FIRST = 0, WAIT_OP = 1, WAIT_SECOND = 2, COMPUTE = 3;
    reg [1:0] state;
    
    reg [23:0] first_operand;
    reg [23:0] second_operand;
    reg [3:0] saved_operator;
    
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT_FIRST;
            result_valid <= 0;
        end else begin
            result_valid <= 0;
            
            case (state)
                WAIT_FIRST: begin
                    if (number_ready) begin
                        first_operand <= parsed_number;
                        state <= WAIT_OP;
                    end
                end
                
                WAIT_OP: begin
                    if (operator_valid && operator_code != 4'd15) begin
                        saved_operator <= operator_code;
                        state <= WAIT_SECOND;
                    end
                end
                
                WAIT_SECOND: begin
                    if (number_ready) begin
                        second_operand <= parsed_number;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (operator_valid && operator_code == 4'd15) begin  // '='
                        case (saved_operator)
                            4'd0: result <= first_operand + second_operand;  // ADD
                            4'd1: result <= first_operand - second_operand;  // SUB
                            default: result <= 24'hFF_FFFF;  // Error
                        endcase
                        result_valid <= 1;
                        state <= WAIT_FIRST;
                    end
                end
            endcase
        end
    end

endmodule
```

**Test:** "5 + 3 =" should give result = 0x000800 (8.0)

---

#### Task 2.3: Display Result on OLED
**Option A (Quick):** Use existing expression buffer, convert result back to ASCII

**Option B (Better):** Add result display line below input box

**File:** `project_vivado/features/keypad/oled_keypad.v`

**Add input port:**
```verilog
input [23:0] calc_result,
input calc_result_valid
```

**In display logic, add result line at Y=9-11:**
```verilog
// Convert Q16.8 to decimal ASCII for display
reg [7:0] result_ascii [0:7];  // "12345.67"

// Conversion logic (simplified - integer part only):
always @(*) begin
    if (calc_result_valid) begin
        integer_part = calc_result >> 8;  // Extract integer
        // Convert to ASCII digits (use divider by 10)
    end
end
```

**Test:** See "8.0" appear on OLED after pressing "="

---

### PHASE 3: Add Multiplication (4-5 hours)
**Goal:** Implement serial multiplier for "3 * 4 = 12"

#### Task 3.1: Build Serial Multiplier ALU
**File:** `project_vivado/features/alu/alu_multiplier.v` (NEW)

**Implementation:** Use shift-and-add algorithm (24 cycles)

```verilog
module alu_multiplier (
    input clk,
    input reset,
    input [23:0] a,          // Q16.8
    input [23:0] b,          // Q16.8
    input start,
    output reg [47:0] product,   // Q32.16 (need to shift back)
    output reg done
);

    reg [4:0] cycle_counter;
    reg [47:0] partial_product;
    reg [23:0] multiplicand;
    reg [23:0] multiplier_reg;
    reg active;
    
    always @(posedge clk) begin
        if (reset) begin
            done <= 0;
            active <= 0;
        end else if (start && !active) begin
            multiplicand <= a;
            multiplier_reg <= b;
            partial_product <= 0;
            cycle_counter <= 0;
            active <= 1;
            done <= 0;
        end else if (active) begin
            if (multiplier_reg[0]) begin
                partial_product <= partial_product + ({24'b0, multiplicand} << cycle_counter);
            end
            multiplier_reg <= multiplier_reg >> 1;
            cycle_counter <= cycle_counter + 1;
            
            if (cycle_counter == 23) begin
                // Result is Q32.16, need to convert to Q16.8
                // Shift right by 8 to compensate for double scaling
                product <= partial_product >> 8;
                done <= 1;
                active <= 0;
            end
        end else begin
            done <= 0;
        end
    end

endmodule
```

**Test:** Standalone testbench:
- a=0x000300 (3.0), b=0x000400 (4.0)
- Expected: product[23:0] = 0x000C00 (12.0)

---

#### Task 3.2: Integrate Multiplier into Calculator
**File:** `project_vivado/features/calculator/simple_calculator.v`

**Add multiplier interface:**
```verilog
// Multiplier signals
reg [23:0] mul_a, mul_b;
reg mul_start;
wire [47:0] mul_product;
wire mul_done;

alu_multiplier mul_inst (
    .clk(clk), .reset(reset),
    .a(mul_a), .b(mul_b), .start(mul_start),
    .product(mul_product), .done(mul_done)
);

// Modify COMPUTE state:
COMPUTE: begin
    if (operator_valid && operator_code == 4'd15) begin
        case (saved_operator)
            4'd0: begin  // ADD
                result <= first_operand + second_operand;
                result_valid <= 1;
                state <= WAIT_FIRST;
            end
            4'd1: begin  // SUB
                result <= first_operand - second_operand;
                result_valid <= 1;
                state <= WAIT_FIRST;
            end
            4'd2: begin  // MUL (multi-cycle)
                mul_a <= first_operand;
                mul_b <= second_operand;
                mul_start <= 1;
                state <= WAIT_MUL;
            end
        endcase
    end
end

// Add new state:
WAIT_MUL: begin
    mul_start <= 0;
    if (mul_done) begin
        result <= mul_product[23:0];  // Take lower 24 bits
        result_valid <= 1;
        state <= WAIT_FIRST;
    end
end
```

**Test:** "3 * 4 =" → result = 12.0

---

### PHASE 4: Add Division (3-4 hours)
**Goal:** Implement "12 / 4 = 3"

#### Task 4.1: Build Serial Divider
**File:** `project_vivado/features/alu/alu_divider.v` (NEW)

**Use non-restoring division** (24 cycles, similar structure to multiplier)

**Test:** 12.0 / 4.0 = 3.0

---

#### Task 4.2: Integrate into Calculator
**Add WAIT_DIV state, similar to WAIT_MUL**

**Test:** "12 / 4 =" → result = 3.0

---

### PHASE 5: Precedence (Shunting-Yard) (5-6 hours)
**Goal:** "2 + 3 * 4 = 14" (not 20!)

#### Task 5.1: Add Operator Stack to Calculator
**Implement simplified Shunting-Yard**

**Test:**
- "2 + 3 * 4 =" → 14
- "10 / 2 + 3 =" → 8
- "(2 + 3) * 4 =" → 20

---

### PHASE 6: Advanced Functions (6-8 hours)
**Goal:** Add sin, cos, sqrt, etc.

#### Task 6.1: Implement CORDIC modules
#### Task 6.2: Integrate into calculator FSM

---

## 🎯 MINIMAL VIABLE PRODUCT (MVP) Checklist

**Week 1 Goal:** Basic 4-function calculator
- [ ] OLED keypad sends 5-bit codes
- [ ] Parser converts digits to Q16.8
- [ ] Calculator handles +, -, *, /
- [ ] Result displays on OLED
- [ ] Test: "123 + 456 = 579" works

**Week 2 Goal:** Precedence + parentheses
- [ ] Shunting-Yard algorithm implemented
- [ ] Test: "2 + 3 * 4 = 14" works
- [ ] Test: "(2 + 3) * 4 = 20" works

**Week 3 Goal:** Advanced functions
- [ ] CORDIC circular (sin, cos, tan)
- [ ] CORDIC hyperbolic (ln, exp)
- [ ] Serial sqrt
- [ ] Test: "sin(1.57) ≈ 1.0" works

---

## 📊 TODO LIST (Prioritized)

### IMMEDIATE (Next 2 Days)
- [ ] **TODO 1.1:** Backup current code: `git commit -am "Baseline before parser integration"`
- [ ] **TODO 1.2:** Add key_code/key_valid outputs to oled_keypad.v
- [ ] **TODO 1.3:** Create data_parser.v (passthrough version)
- [ ] **TODO 1.4:** Wire parser to main.v
- [ ] **TODO 1.5:** Test on hardware: LED[4:0] shows key codes

### SHORT TERM (Week 1)
- [ ] **TODO 2.1:** Add number accumulator FSM to parser
- [ ] **TODO 2.2:** Create simple_calculator.v (2-operand, add/sub only)
- [ ] **TODO 2.3:** Add result display to OLED
- [ ] **TODO 2.4:** Test: "5 + 3 = 8" works end-to-end
- [ ] **TODO 2.5:** Test: "100 - 25 = 75" works

### MEDIUM TERM (Week 2)
- [ ] **TODO 3.1:** Implement alu_multiplier.v
- [ ] **TODO 3.2:** Add MUL to calculator
- [ ] **TODO 3.3:** Test: "3 * 4 = 12"
- [ ] **TODO 4.1:** Implement alu_divider.v
- [ ] **TODO 4.2:** Add DIV to calculator
- [ ] **TODO 4.3:** Test: "12 / 4 = 3"
- [ ] **TODO 4.4:** Test: "5.5 * 2.0 = 11.0" (decimal handling)

### LONG TERM (Week 3+)
- [ ] **TODO 5.1:** Add operator stack to calculator
- [ ] **TODO 5.2:** Implement precedence checking
- [ ] **TODO 5.3:** Test precedence: "2 + 3 * 4 = 14"
- [ ] **TODO 6.1:** Implement CORDIC circular mode
- [ ] **TODO 6.2:** Add sin/cos/tan to calculator
- [ ] **TODO 7.1:** Implement CORDIC hyperbolic
- [ ] **TODO 7.2:** Add ln/exp to calculator
- [ ] **TODO 8.1:** Implement serial sqrt
- [ ] **TODO 8.2:** Test: "sqrt(16) = 4"

---

## 🧪 TESTING STRATEGY

### Level 1: Module Testing (Simulation)
**Tools:** Vivado Simulator or ModelSim

**Test each module standalone:**
```verilog
// Example testbench for parser
module tb_parser;
    reg clk = 0;
    always #5 clk = ~clk;
    
    reg [4:0] key_code;
    reg key_valid = 0;
    wire [23:0] parsed_number;
    wire number_ready;
    
    data_parser dut(...);
    
    initial begin
        // Simulate typing "123"
        #10 key_code = 5'd1; key_valid = 1;
        #10 key_valid = 0;
        #50;
        #10 key_code = 5'd2; key_valid = 1;
        #10 key_valid = 0;
        #50;
        #10 key_code = 5'd3; key_valid = 1;
        #10 key_valid = 0;
        #50;
        // Press '+'
        #10 key_code = 5'd10; key_valid = 1;
        #10 key_valid = 0;
        #50;
        
        // Check parsed_number = 0x007B00 (123 in Q16.8)
        if (parsed_number == 24'h007B00) $display("PASS");
        else $display("FAIL: got %h", parsed_number);
        
        $finish;
    end
endmodule
```

---

### Level 2: Integration Testing (Hardware)
**Tools:** Basys3 board + LEDs

**Debug signals to expose:**
```verilog
// Add to main.v for debugging
assign led[4:0] = keypad_key_code;        // Show key pressed
assign led[8:5] = parser_digit_value;     // Show parsed digit
assign led[9] = parser_digit_valid;       // Digit ready
assign led[10] = parser_number_ready;     // Number complete
assign led[11] = calc_result_valid;       // Result ready
assign led[15:12] = calc_state;           // Calculator FSM state
```

**Test procedure:**
1. Power on, verify LEDs all off
2. Press '5', check LED[4:0] = 5
3. Press '+', check LED[10] pulses (number ready)
4. Press '3', check LED[4:0] = 3
5. Press '=', check LED[11] pulses (result ready)
6. Check OLED shows "8" or "8.0"

---

### Level 3: System Testing (Full Expressions)
**Test cases (in order of complexity):**

1. **Single digits:** "5 + 3 = 8"
2. **Multi-digit:** "123 + 456 = 579"
3. **Subtraction:** "100 - 25 = 75"
4. **Multiplication:** "3 * 4 = 12"
5. **Division:** "12 / 4 = 3"
6. **Decimals:** "5.5 + 2.25 = 7.75"
7. **Precedence:** "2 + 3 * 4 = 14"
8. **Parentheses:** "(2 + 3) * 4 = 20"
9. **Negative:** "5 - 10 = -5"
10. **Functions:** "sin(0) = 0"

---

## 🔥 CRITICAL DECISIONS

### Decision 1: Where to Store Expression History?
**Option A:** Keep in OLED keypad (current)
**Option B:** Move to calculator module
**Option C:** Move to separate display controller

**RECOMMENDATION: A (Keep in OLED)**
- Reason: OLED module already handles display
- Expression is UI concern, not logic concern
- Calculator only needs to return final result

---

### Decision 2: When to Convert to Q16.8?
**Option A:** In parser (as numbers accumulate)
**Option B:** In calculator (when operator pressed)
**Option C:** Hybrid (integers immediate, decimals on demand)

**RECOMMENDATION: A (In Parser)**
- Reason: Calculator shouldn't know about decimal strings
- Parser is data transformation layer
- Cleaner separation of concerns

---

### Decision 3: Stack Implementation?
**Option A:** Use Verilog arrays (in LUTs)
**Option B:** Use BRAM for deeper stacks
**Option C:** Fixed 2-operand (no stack)

**RECOMMENDATION: A for MVP, B for final**
- Reason: Arrays simpler for first implementation
- 16-deep stack fits in ~400 LUTs (acceptable)
- Can optimize to BRAM later if needed

---

## 🎓 LEARNING RESOURCES

### Verilog Fixed-Point Arithmetic
- Q notation: https://en.wikipedia.org/wiki/Q_(number_format)
- Multiplication: Result width doubles (Q16.8 * Q16.8 = Q32.16)
- Division: Need to pre-scale dividend by 2^8

### CORDIC Algorithm
- Tutorial: https://www.dsprelated.com/showarticle/107.php
- Verilog examples: https://github.com/topics/cordic-algorithm

### Shunting-Yard Algorithm
- Explanation: https://en.wikipedia.org/wiki/Shunting-yard_algorithm
- Pseudocode: Easy to translate to Verilog FSM

---

## 🚀 QUICK START COMMANDS

```bash
# 1. Backup current state
cd c:\Users\xiang\ee2026_Project
git add .
git commit -m "Baseline before parser integration"
git checkout -b feature/data-parser

# 2. Create directory structure
mkdir project_vivado\features\parser
mkdir project_vivado\features\alu

# 3. Start implementing (use VS Code to create files)
# - data_parser.v
# - simple_calculator.v
# - alu_multiplier.v (later)

# 4. Test compilation in Vivado
# Open project_shit/*.xpr
# Add new files to design sources
# Run synthesis to check for errors

# 5. Program FPGA and test
# Generate bitstream
# Program device
# Test with physical buttons
```

---

## 📝 FINAL NOTES

### Why This Plan is Better:
1. **Incremental Testing** - Every phase produces testable output
2. **Reuses Your Code** - Keeps OLED module mostly intact
3. **Lower Risk** - Can stop at any phase and have working calculator
4. **Faster Results** - See "5 + 3 = 8" working in 1 day

### What to Avoid:
- ❌ Implementing all 6 ALU modules before testing
- ❌ Removing ASCII display logic too early
- ❌ Building complex FSMs without simulation
- ❌ Trying to do precedence before basic math works

### When You Get Stuck:
1. **Syntax errors?** → Check module instantiation port names
2. **Logic errors?** → Add debug LEDs to expose internal signals
3. **Timing errors?** → Check Vivado timing report, may need clock constraints
4. **Display broken?** → Revert OLED changes, test parser standalone

---

## ✅ SUCCESS CRITERIA

**Phase 1 Success:** LEDs blink with key codes
**Phase 2 Success:** "5 + 3 = 8" displays on OLED
**Phase 3 Success:** "3 * 4 = 12" works with serial multiplier
**MVP Success:** All 4 operations (+, -, *, /) work reliably
**Final Success:** Full scientific calculator with precedence

---

**GOOD LUCK! Start with Phase 1 Task 1.1 and work sequentially.** 🎯
