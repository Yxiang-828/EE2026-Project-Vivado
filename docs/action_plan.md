# Action Plan for FPGA Graphical Calculator

This document outlines the phased implementation plan for completing the FPGA Graphical Calculator project, based on the Artix-6 Fixed-Point Calculator Architecture (Q16.8) and Grapher Architecture. The plan is divided into sections for modular development and testing.

## Phase 1: Core Infrastructure Setup
### 1.1 Integrate Calculator Module into Top-Level
- Add `calculator_module` instantiation in `main.v` under MODE_CALCULATOR
- Wire inputs: `btn_debounced`, `sw`, `pixel_index`, `vga_x`, `vga_y`
- Wire outputs: `oled_overlay`, `vga_pixel` to multiplexers
- Update mode selection logic to handle calculator mode transitions

### 1.2 Integrate Grapher Module into Top-Level
- Add `grapher_module` instantiation in `main.v` under MODE_GRAPHER
- Wire inputs: `btn_debounced`, `sw`, `pixel_index`, `vga_x`, `vga_y`
- Wire outputs: `oled_overlay`, `vga_pixel` to multiplexers
- Ensure mode switching works between calculator and grapher

### 1.3 Implement Keypad Input System
- Create OLED-based keypad interface for number input
- Replace mouse control with button-based cursor movement
- Map buttons to keypad navigation (up/down/left/right for cursor, center for select)
- Integrate keypad codes into calculator and grapher modules

## Phase 2: Calculator Mode Implementation
### 2.1 Data Path Implementation
- Implement Operand_Stack using BRAM (24-bit wide)
- Implement Operator_Stack using BRAM (4-bit wide)
- Add registers: R_TEMP (24-bit), R_RESULT (48-bit), Key_Value (5-bit), FP_Position (4-bit)
- Add constants: R_CONST_PI, R_CONST_E (24-bit read-only)
- Add flags: Is_Unary, Overflow_Flag, Decimal_Entered_Flag

### 2.2 Control Unit (FSM) Implementation
- Implement S_IDLE state with reset logic
- Implement S_CONST_LOAD for pi/e loading
- Implement S_INPUT_TEMP for number entry with overflow checking
- Implement S_PUSH_OPD for stack operations
- Implement S_OP_MANAGE with precedence checking
- Implement S_EXECUTE_OP, S_PUSH_RESULT, S_DISPLAY_R, S_ERROR states

### 2.3 Input Processing Logic
- Implement decimal to Q16.8 conversion in S_INPUT_TEMP
- Add number accumulation with overflow detection
- Implement negation using two's complement
- Add final scaling and alignment for stack push

### 2.4 ALU Module Integration
- Implement Adder/Subtractor (single-cycle)
- Implement Serial Multiplier (24-cycle, use_dsp="no")
- Implement Serial Divider (24-cycle) with division-by-zero check
- Implement CORDIC Circular for sin/cos (24-cycle)
- Implement CORDIC Hyperbolic for ln/exp (24-cycle)
- Implement Serial Square Root (24-cycle) with domain check

## Phase 3: Grapher Mode Implementation
### 3.1 Data Path Setup
- Implement RPN_Memory_1 and RPN_Memory_2 (28-bit/word BRAM)
- Add registers: R_X (24-bit), R_Y_MIN/MAX (24-bit), R_RPN_PTR
- Add display outputs: Display_Active_Value, Display_Expression_Bus

### 3.2 Grapher FSM Implementation
- Implement G_INPUT_EXPR_1 and G_INPUT_EXPR_2 states
- Implement setup states: G_SETUP_XMIN, G_SETUP_XMAX, G_SETUP_STEP
- Implement G_RANGE_FIND for Y-axis calculation
- Implement plotting loop: G_PLOT_LOOP, G_RPN_EXECUTE, G_OUTPUT_Y
- Add G_ERROR state with reset capability

### 3.3 RPN Execution Logic
- Implement token reading from RPN memory
- Add operand push/pop logic
- Integrate ALU modules for operator execution
- Handle variable 'x' loading from R_X
- Implement dual function evaluation (y1 and y2)

## Phase 4: Display and Interface Integration
### 4.1 OLED Keypad Implementation
- Create 4x4 keypad layout on OLED
- Implement cursor movement with buttons
- Add number/operator selection logic
- Integrate with calculator input processing

### 4.2 VGA Display Enhancement
- Implement grid and axis drawing for grapher
- Add function plotting with pixel mapping
- Enhance calculator display with expression history
- Add error indication and overflow warnings

### 4.3 User Interface Polish
- Implement expression display on top line
- Add result display on bottom line
- Add mode indicators and status feedback
- Implement clear (AC) and equals (=) functionality

## Phase 5: Testing and Validation
### 5.1 Unit Testing
- Test each ALU module individually
- Validate Q16.8 arithmetic operations
- Test stack operations and precedence handling
- Verify RPN compilation and execution

### 5.2 Integration Testing
- Test calculator mode with basic operations
- Test grapher mode with linear functions
- Validate mode switching and data persistence
- Test overflow and error conditions

### 5.3 Hardware Testing
- Synthesize and implement on Basys3
- Test OLED keypad interaction
- Verify VGA plotting accuracy
- Measure performance and resource usage

## Phase 6: Enhancements and Optimizations
### 6.1 Feature Additions
- Implement multi-digit number support
- Add parentheses handling in expressions
- Enhance graphing with multiple functions
- Add unit conversion utilities

### 6.2 Performance Optimizations
- Optimize ALU cycle counts where possible
- Implement pipelining for better throughput
- Reduce BRAM usage through compression
- Add caching for frequently used constants

### 6.3 Additional Number Systems
- Implement binary input/output
- Add hexadecimal support
- Include octal number handling
- Add number system conversion

## Phase 7: Documentation and Finalization
### 7.1 Update Documentation
- Complete user guide with all features
- Update architecture documentation
- Add troubleshooting guide
- Create developer notes

### 7.2 Final Testing
- Comprehensive system testing
- Performance benchmarking
- Resource utilization analysis
- User acceptance testing

### 7.3 Project Completion
- Code cleanup and commenting
- Final bitstream generation
- Demo preparation
- Project submission

## Resource Allocation
- **LUTs**: Monitor usage, target <50% of XC7A35T capacity
- **BRAM**: Used for stacks and RPN memory
- **DSP**: Avoid DSP blocks for multipliers (use_dsp="no")
- **Timing**: Ensure 100MHz operation with proper constraints

## Risk Mitigation
- Implement modular testing to catch issues early
- Use simulation for complex logic before hardware testing
- Maintain version control for rollback capability
- Document all changes and decisions

## Timeline Estimate
- Phase 1-2: 2-3 weeks (Core calculator)
- Phase 3: 2 weeks (Grapher implementation)
- Phase 4: 1 week (Interface integration)
- Phase 5-7: 1-2 weeks (Testing and completion)