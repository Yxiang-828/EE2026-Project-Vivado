# Inputs and Outputs

This document details the inputs and outputs of the top-level module `Top_Student` in `main.v`.

## Inputs
- **clk**: 100MHz system clock from Basys3 board.
- **btn[4:0]**: 5 push buttons (Centre, Up, Left, Right, Down).
- **sw[15:0]**: 16 slide switches.
- **PS2Clk**: PS2 keyboard clock (inout, currently tri-stated).
- **PS2Data**: PS2 keyboard data (inout, currently tri-stated).

## Outputs
- **JB[7:0]**: 8-bit output for OLED display (SPI interface).
- **VGA_Hsync**: VGA horizontal sync signal.
- **VGA_Vsync**: VGA vertical sync signal.
- **VGA_RGB[11:0]**: 12-bit VGA color output (4 bits per R/G/B).
- **current_main_mode[1:0]**: Debug output indicating current mode (00: OFF, 01: WELCOME, 10: CALCULATOR, 11: GRAPHER).

## Internal Signals
- **reset**: Active high reset, derived from ~sw[15].
- OLED and VGA data are multiplexed based on `current_main_mode`.

## Notes
- PS2 interface is not used in current implementation.
- All signals are synchronous to `clk`.
- OLED resolution: 96x64 pixels.
- VGA resolution: 640x480 pixels.