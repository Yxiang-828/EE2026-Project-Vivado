Artix-6 Fixed-Point Grapher Architecture (Q16.8) - Dual Function RPN
This document outlines the core hardware architecture for plotting two functions, y_1 = f(x) and y_2 =g(x), simultaneously. The design maintains minimal LUT utilization by reusing the fixed-point ALU and using BRAM for dual expression storage.
1. The Data Path (Storage and Variables)
The data path is updated to include storage for two independent RPN expressions. All arithmetic registers and ALU units (from the calculator) are reused.


Register/Memory
Width
Purpose
RPN_Memory_1
28 bits/word
Stores the compiled RPN expression for the first function, y_1.
RPN_Memory_2
28 bits/word
Stores the compiled RPN expression for the second function, y_2.
R_X
24 bits (Q16.8)
Holds the current x value being evaluated in the plot loop.
R_Y_MIN / R_Y_MAX
24 bits (Q16.8)
Stores the GLOBAL Y boundaries calculated across both y_1 and y_2 results.
R_RPN_PTR
Log2(RPN size)
Pointer/Address counter for reading instructions from the currently active RPN Memory.
Display_Active_Value
24 bits
OUTPUT: Raw Q16.8 data for the Bottom Line (editable setup values).
Display_Expression_Bus
 80 chars
OUTPUT: ASCII data for the Top Line (function currently being entered/plotted).

RPN Memory Word Format (28 bits)
Bit Range
Width
Type
Usage
[27]
1 bit
Token Type
0: Operator/Code
1: Operand Value
[26:24]
3 bits
Code Subtype
Differentiates between constant (pi/e), variable (x), and number.
[23:0]
24 bits
Value/Code
If Operand: Stores the Q16.8 value.
If Operator: Stores the 4-bit R_OP code.

2. Grapher Control Unit (FSM)
The FSM now sequences through the input and plotting of two functions.
Phase
State
Description
Primary Action
I. Input
G_INPUT_EXPR_1
User enters the first function, y_1. Acts identically to calculator's input, but pushes RPN tokens to RPN_Memory_1.
Input: Button Press
Next State: G_INPUT_EXPR_2 (to toggle between the 2 functions)

Input: Done
Next State: G_SETUP_XMIN


G_INPUT_EXPR_2
User enters the second function, y_2. Acts identically to calculator's input, but pushes RPN tokens to RPN_Memory_2.
Input: Button Press
Next State: G_INPUT_EXPR_1 (to toggle between the 2 functions)

Input: Done
Next State: G_SETUP_XMIN
II. Setup
G_SETUP_XMIN
Waits for user input x_min.
Input: Done (Stores number in R_X_MIN)
Next State: G_SETUP_XMAX




G_SETUP_XMAX
Waits for user input x_max.
Input: Done (Stores number in R_X_MAX)
Next State: G_SETUP_STEP


G_SETUP_STEP
Calculates the step size for the plot (based on screen width).
R_X_STEP = (R_X_MAX - R_X_MIN)/(Screen Width)

Input: Done
Next State: G_RANGE_FIND


G_RANGE_FIND
GLOBAL Y-AXIS FINDING: Executes both RPNs to determine y_min/y_max across the combined output.
Iterates x, executes y_1, executes y_2. Updates R_Y_MIN/R_Y_MAX

Input: Done
Next State: G_PLOT_LOOP
III. Plotting
G_PLOT_LOOP
Main execution loop. Controls the iteration count (X-axis pixel column).
R_X = R_X + R_X_STEP
Resets RPN_PTR

Input: Done
Next State: G_RPN_EXECUTE


G_RPN_EXECUTE
High-speed calculation phase. Executes the stored RPN for the current R_X.
Executes RPN_1 (for y_1) then RPN_2 (for y_2) sequentially.

Input: Done
Next State: G_OUTPUT_Y


G_OUTPUT_Y
RPN execution complete. Final results are y_1 and y_2.
Uses R_Y_MIN/R_Y_MAX to map both y_1 and y_2 results to screen pixels.

Input: Done
Next State: G_PLOT_LOOP
Error
G_ERROR
Displays error code.
Input: AC Key
(Reset Functions???)
Next State: G_INPUT_EXPR_1

3. The RPN Execution Logic (G_RPN_EXECUTE)
This sub-routine is executed twice per X-pixel column: once for y_1 (reading from RPN_Memory_1) and once for y_2 (reading from RPN_Memory_2).
Read Token: Read one 28-bit word from the currently active RPN Memory (controlled by the FSM).
If Token is 'x: Load the value from R_X (the current column's X-coordinate).
If Token is Operand: Push the value to the small, shared Operand Stack.
If Token is Operator: Pop operands, initiate the corresponding multi-cycle ALU block (CORDIC, Multiplier, etc.), and push the result back to the Operand Stack.
