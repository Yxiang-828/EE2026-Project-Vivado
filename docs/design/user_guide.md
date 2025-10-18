
FPGA Graphical Calculator User Guide
1.0 System Overview
Welcome to the FPGA Graphical Calculator. This guide describes the operation of the calculator implemented on the Basys3 board, which utilizes both an OLED and a VGA monitor for its display. The system is designed to provide core functionality for simple arithmetic and basic function graphing.
The calculator features four primary modes of operation:
OFF Mode: The system is powered down or in a standby state.
Welcome Mode: The startup screen where the user selects the primary mode of operation.
Calculator Mode: For performing basic arithmetic.
Grapher Mode: For plotting simple linear functions.
The number input will be primarily done through the OLED display using the mouse as a controller.

2.0 Getting Started and Mode Switching
2.1 Power On Sequence
To begin, ensure the Basys3 board is properly connected to a power source and a VGA monitor.
Set switch SW[15] to the ON position to power on the calculator.
Upon startup, the system will briefly be in OFF mode before automatically displaying the Welcome Screen.
2.2 Mode Selection from the Welcome Screen
The Welcome Screen allows you to choose your desired mode of operation.
Press BTN[1] (Up button) to highlight the Calculator option. An arrow on the VGA display will indicate your selection.
Press BTN[4] (Down button) to highlight the Grapher option.
Press BTN[0] (Center button) to confirm your choice and enter the selected mode.
2.3 Switching Between Active Modes
To switch from Calculator Mode to Grapher Mode (or vice versa), you must return to the Welcome Screen.
Set switch SW[15] to the OFF position.
Set switch SW[15] back to the ON position.
The Welcome Screen will reappear, allowing you to select a new mode.

3.0 Modes of Operation
3.1 Welcome Screen
This is the initial screen that provides access to the calculator's main functions. It displays the title "EE2026 CALCULATOR" and presents the user with selectable modes.
3.2 Calculator Mode
This is the primary mode for performing arithmetic calculations.
Features:
Supported Operations: Addition (+), Subtraction (-), Multiplication (x) and Division (/) of numbers in the range of −32,768.0 to +32,767.99609375 (16.8 Bit Size)
Input Method: Uses the OLED Screen to input the number
Display: The selection of numbers is done on the Monitor Display and the results of the operation are displayed there as well.
Instructions:
Use the mouse to control the cursor on the OLED Display to select the numbers.
Select the desired operation: SW[4] for Addition (+) or SW[5] for Subtraction (-).
Enter the second digit (0-9) using switches SW[0-3].
Press BTN[0] to execute the calculation. The result will be displayed.
Example: To calculate 8 + 5, set the switches for '8', press SW[4], set the switches for '5', and then press BTN[0]. The display will show "8+5=13".
3.3 Grapher Mode
This mode is used to plot simple linear functions on the VGA display.
Features:
Supported Functions: Basic linear equations (e.g., y = mx + b).
Display: A graph with an X-Y grid and the plotted function line is shown on the VGA monitor.
Instructions:
First, navigate to Calculator Mode.
Enter the desired linear function (e.g., 2*X + 1).
Return to the Welcome Screen by toggling SW[15] OFF and ON.
Select and enter Grapher Mode.
The function will be automatically plotted on the VGA display.

4.0 Controls Reference Guide
Control
Function\
SW[15]
System Power ON/OFF. Toggles back to Welcome Screen.
SW[0-3]
Digit input for Calculator Mode (0-9).
SW[4]
Selects the Addition (+) operation.
SW[5]
Selects the Subtraction (-) operation.
BTN[0]
Calculate in Calculator Mode. Confirm selection in Welcome Mode.
BTN[1]
Selects Calculator option on Welcome Screen.
BTN[4]
Selects Grapher option on Welcome Screen.


5.0 Planned Enhancements
The following features are planned for future versions of this project:
Support for multi-digit numbers
Multiplication and division operations
Graphing of more complex functions
An OLED-based keypad interface for input
Unit conversion utilities
Support for Binary, Hexadecimal, and Octal number systems
Additional add-on modules

