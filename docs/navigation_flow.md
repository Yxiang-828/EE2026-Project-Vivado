# Navigation Flow

This document describes the user interaction flow and mode transitions in the FPGA design.

## Mode Overview
The system has 4 modes, controlled by switches and buttons:
- **MODE_OFF (00)**: Blank screen, entered on reset.
- **MODE_WELCOME (01)**: Main menu screen, allows selection of calculator or grapher.
- **MODE_CALCULATOR (10)**: Calculator functionality (not yet implemented).
- **MODE_GRAPHER (11)**: Grapher functionality (not yet implemented).

## Startup Sequence
1. On power-up or when sw[15] is low (reset active), system enters MODE_OFF.
2. After reset deasserts, system automatically transitions to MODE_WELCOME.

## Welcome Mode Interaction
- **OLED**: Displays welcome text/graphics.
- **VGA**: Displays interactive menu with options for Calculator and Grapher.
- **Buttons**: Used to select mode:
  - Centre button: Select Calculator → transition to MODE_CALCULATOR.
  - Up/Left/Right/Down buttons: Navigate menu (implementation details in welcome_drawer_vga.v).
- **Mode Transition**: Handshake protocol ensures clean transition.

## Calculator Mode (Placeholder)
- Currently not implemented in main.v.
- Intended for arithmetic operations using OLED keypad and VGA display.

## Grapher Mode (Placeholder)
- Currently not implemented in main.v.
- Intended for graphing functions using OLED controls and VGA plot.

## Reset Behavior
- Setting sw[15] low resets the system to MODE_OFF, then back to MODE_WELCOME.
- All modes respect the reset signal.

## Notes
- Mode transitions use a handshake mechanism to prevent glitches.
- Current implementation only fully supports OFF and WELCOME modes.
- Calculator and Grapher modes are placeholders in the code.