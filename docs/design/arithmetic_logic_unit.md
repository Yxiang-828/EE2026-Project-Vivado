Artix-6 Fixed-Point ALU Modules (Q16.8)
This document details the six primary arithmetic and computational modules used within the S_EXECUTE_OP FSM state. All modules are designed to handle 24-bit (Q16.8) fixed-point data and are architected for minimal LUT utilisation by employing multi-cycle, iterative algorithms and leveraging the Artix-6's dedicated hardware resources.
1. Adder/Subtractor Module (The Fast ALU)
Feature
Details
LUT Strategy
Operations
Addition (+), Subtraction (-), Negation.
Minimal LUTs. Uses native Verilog operators (+, -) to force the synthesis tool to utilize the dedicated Fast Carry Chain hardware in the Artix-6 slice.
Cycles
1 Clock Cycle (Single-cycle operation).
This is the fastest arithmetic block in the system.
Subtraction
Implemented as addition using two's complement for the subtrahend (i.e., A - B = A + (~B +1)).



2. Serial Multiplier Module
Feature
Details
LUT Strategy
Operation
Multiplication (x).
Low-LUT via Iteration. Multiplier is forced to be implemented in LUT fabric using the (* use_dsp = "no" *) attribute. Uses a Serial Shift-and-Add algorithm.
Cycles
24+ Clock Cycles. Requires one control cycle and 24 data cycles for the  multiplication.
Trades high speed for minimal hardware area.
Output
Produces a 48-bit product (Q32.16) stored in R_RESULT before being truncated back to Q16.8 for the stack.



3. Serial Divider Module
Feature
Details
LUT Strategy
Operation
Division (/).
Low-LUT via Iteration. Implemented using the multi-cycle Non-Restoring Division algorithm.
Cycles
24+ Clock Cycles. Requires 24 cycles to compute the 24-bit quotient.
Logic relies on the reuse of the simple Adder/Subtractor unit.
Domain Check
Includes logic to detect Division-by-Zero before starting, setting the Overflow_Flag and halting execution if detected.



4. CORDIC Module (Circular Mode)
Feature
Details
LUT Strategy
Operations
Sine (sin), Cosine (cos), Tangent (tan).
Extreme LUT Efficiency. Uses the CORDIC algorithm (COordinate Rotation DIgital Computer), which performs rotation via only additions/subtractions and fixed shifts, minimising combinatorial logic.
Cycles
24+ Clock Cycles (One cycle per iteration for 24 bits of precision).
The tan(A) operation requires the output of this module (sin/cos) to be fed into the Serial Divider Module.

5. CORDIC Module (Hyperbolic Mode)
Feature
Details
LUT Strategy
Operations
Natural Logarithm (ln(A)), Exponential (e^A), and Power (x^y).
Maximum Resource Reuse. This block reuses the same core adder/shifter logic as the Circular CORDIC, requiring only different constants and control signals.
POW (x^y) Flow
Requires sequencing through three modules:  CORDIC -> MUL by y (Serial Multiplier) -> e^Result (CORDIC).



6. Serial Square Root Module
Feature
Details
LUT Strategy
Operation
Square Root (sqrt(A)).
Low-LUT via Iteration. Implemented using the multi-cycle Non-Restoring Square Root algorithm.
Cycles
24+ Clock Cycles. Requires 24 cycles to compute the 24-bit result.
Relies heavily on the simple Adder/Subtractor logic, making it LUT-efficient.
Domain Check
Includes logic to detect a negative input (Domain Error), setting the Overflow_Flag and halting execution.





