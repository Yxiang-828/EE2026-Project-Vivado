Artix-6 Fixed-Point Calculator Architecture (Q16.8) - Stack-Based
This document outlines the core hardware architecture for a graphical calculator on an Artix-6 FPGA. The design uses a Stack-Based Architecture (Shunting-Yard model) to handle operator precedence and complex multi-operand expressions, while focusing on manual ALU implementation with the Q16.8 (24-bit) fixed-point format.
1. The Data Path (Storage and Variables) - Stack Implementation
The simple R_A and R_B registers are replaced by dedicated stacks, which are typically implemented using Block RAM (BRAM) on the Artix-6 for deep storage, saving significant LUTs.
Register/Wire
Bit Width
Purpose
Operand_Stack
24 bits wide
Stores input numbers and intermediate results (e.g., 5, 4, 3...). Pushed/Popped from BRAM.
Operator_Stack
4 bits wide
Stores the pending operator codes (R_OP). Pushed/Popped from BRAM.
R_TEMP
24 bits (signed)
Temporary register for holding the current number being typed by the user (like the old R_A input).
R_RESULT
48 bits (signed)
Stores the result of operations before trimming (e.g.,  multiplication gives a 48-bit product).
Key_Value
5 bits
Input from the keypad/user interface.
FP_Position
4 bits
Tracks the position of the binary point during number entry.
R_CONST_PI
24 bits (signed)
Fixed-point value of  (Read-Only).
R_CONST_E
24 bits (signed)
Fixed-point value of  (Read-Only).
Is_Unary
1 bit
Flag: Set if the current operation is unary (sin, cos, ln, etc.).
Overflow_Flag
1 bit
Set if any input or result exceeds the Q16.8 range.
Decimal_Entered_Flag
1 bit
Set once the decimal point key is pressed.
Display_Expression
80 chars max
Logic output for the top line (expression history).

Key Codes (5-bit Key_Value)
Key Type
Keys
Code Range
Digits
0-9
5'b00000 - 5'b01001
Binary Ops
+, -, x, /, ^ (POW)
5'b01010 - 5'b01110
Unary Ops
SIN, COS, TAN, LN, EXP, SQRT, LN
5'b01111 - 5'b10100
Special Unary
NEG
5'b10101
Constants
PI, E
5'b10110 - 5'b10111
Utility
., =, AC
5'b11000 - 5'b11010
Parentheses
(, )
5'b11011 - 5'b11100

Operator Codes (4-bit R_OP) - Precedence Levels
Operation
Code
Type
Precedence
Implementation
ADD
4'b0001
Binary
1
Fast Carry Chain (+)
SUB
4'b0010
Binary
1
Fast Carry Chain (-)
MUL
4'b0011
Binary
2
Serial Shift-and-Add
DIV
4'b0100
Binary
2
Serial Non-Restoring Division
POW (x^y)
4'b0101
Binary
3
CORDIC + MUL (multi-function)
SIN (sin(A))
4'b0110
Unary
4
CORDIC (Circular)
COS (cos(A))
4'b0111
Unary
4
CORDIC (Circular)
TAN (tan(A))
4'b1000
Unary
4
CORDIC (sin/cos) + Division ALU
LN (ln(A))
4'b1001
Unary
4
CORDIC (Hyperbolic)
EXP (e^A)
4'b1010
Unary
4
CORDIC (Hyperbolic)
SQRT (sqrt(A))
4'b1011
Unary
4
Iterative Square Root
(
N/A
Control
0
Always Pushed

2. The Control Unit (Finite State Machine - FSM) - Stack Logic
The FSM is now driven by the arrival of a new operator and uses the Precedence Check to decide whether to push the new operator or execute the one currently on the stack.
State
Description
Next State on Input
S_IDLE
Calculator is reset. Bottom Display is clear.
Input: Digit key or ( key
Next State: S_INPUT_TEMP

Input: Constant key
Next State: S_CONST_LOAD
S_CONST_LOAD
Loads pi or e into R_TEMP.
Input: Done
Next State: S_PUSH_OPD
S_INPUT_TEMP
User is entering a number into R_TEMP. Bottom Display shows R_TEMP.
Input: If NEG key
Next State: Stay in S_INPUT_TEMP (Negate R_TEMP and stay)

Input: If Overflow_Flag set
Next State: S_ERROR

Input: Operator key or ) key or = key
Next State: S_PUSH_OPD
S_PUSH_OPD
Pushes the completed number from R_TEMP onto the Operand Stack.
Next State: S_OP_MANAGE
S_OP_MANAGE
PERFORMS PRECEDENCE CHECK. Compares R_OP (Incoming Op) vs. Operator Stack Top.
Input: If P_In > P_Top
Next State: S_OP_PUSH

Input: If P_In <= P_Top
Next State: S_EXECUTE_OP
S_OP_PUSH
Pushes the new incoming operator (R_OP) onto the Operator Stack. Updates Expression Display.
Input: Done
Next State: S_INPUT_TEMP (wait for next number)
S_EXECUTE_OP
Pops O_Top and one/two operands. Transitions to multi-cycle sub-state (ALU/CORDIC).
Input: If Overflow_Flag set
Next State: S_ERROR

Input: Done
Next State: S_PUSH_RESULT
S_PUSH_RESULT
Pushes the 48-bit result (after truncation/scaling) back onto the Operand Stack.
Input: If Overflow_Flag set
Next State: S_ERROR

Input: If more Operations on stack
Next State: S_OP_MANAGE

Input: If Stack Empty (after ‘=’)
Next State: S_DISPLAY_R
S_DISPLAY_R
Final result is ready and displayed. Bottom Display shows final result.
Input: Operator key
Next State: S_PUSH_OPD (for chaining)
S_ERROR
Error occurred (Overflow, Domain, or Division-by-Zero). Displays "E" on bottom line.
Input: AC key
Next State: S_IDLE

3. Input Processing Logic (Converting Decimal to Q16.8)
This logic runs primarily in S_INPUT_TEMP to handle keyboard input and convert base-10 digits into the fixed-point format (where the binary point is always 2^(-8)).
A. Number Accumulation and Input Overflow Check
The input register R_TEMP (24 bits) accumulates the magnitude.
// Inside S_INPUT_TEMP, on new digit input:
R_TEMP_NEXT = (R_TEMP * 10) + digit_value;

// Magnitude Overflow Check (before assignment):
// Check if the 16-bit integer portion (R_TEMP[23:8]) exceeds 32767.
if (R_TEMP_NEXT[23:8] > 16'h7FFF) begin
    Overflow_Flag <= 1'b1;
end else begin
    R_TEMP <= R_TEMP_NEXT;
end

// Negation
if (Key_Value == 5'b10101) begin // If NEG key (±) pressed
    // Negate R_TEMP using two's complement: R_TEMP = ~R_TEMP + 1
    // This reuses the fast carry chain adder hardware.
    R_TEMP <= (~R_TEMP) + 1;
end


B. Final Scaling and Alignment
When an operator key is pressed, the raw magnitude in R_TEMP must be scaled down by 10^(FP_Position) (decimal correction) and simultaneously scaled up by 2^8 (binary alignment) before being pushed to the stack. This is implemented via a Multi-Cycle Scaling Sub-routine to keep LUTs low.


