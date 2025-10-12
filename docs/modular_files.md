# Modular Files Used

This document lists all the Verilog module files in the source directory (`project_vivado/`) and provides a brief description of each.

## Top-Level Module
- **main.v**: `Top_Student` module. The main entry point that instantiates all submodules. Handles mode switching between OFF, WELCOME, CALCULATOR, and GRAPHER modes. Manages multiplexing of OLED and VGA data from submodules. Includes button debouncing and display handler instantiation.

## Accessories Modules
- **debouncer.v**: `button_debouncer_array` module. Debounces the 5 push buttons to prevent multiple triggers from a single press.
- **display_handler.v**: `display_handler` module. Interfaces with the OLED display (via JB pins) and VGA output. Generates pixel indices for OLED and coordinates for VGA.
- **flexible_timer.v**: `flexible_timer` module. A configurable timer for delays or timing operations (not currently used in top module).
- **fourteen_segment_drawer_oled.v**: `fourteen_segment_drawer_oled` and `diagonal_drawer_oled` modules. Draws 14-segment alphanumeric characters and diagonal lines on the OLED display.
- **fourteen_segment_drawer_vga.v**: `fourteen_segment_drawer_vga` and `diagonal_drawer_vga` modules. Draws 14-segment alphanumeric characters and diagonal lines on the VGA display.
- **Oled_Display.v**: `Oled_Display` module. Low-level controller for the OLED panel, handling SPI communication.
- **vga_sync.v**: `vga_sync` module. Generates VGA sync signals (Hsync, Vsync) and pixel coordinates.

## Submodules
- **off_module.v**: `off_module` module. Provides blank (black) output for both OLED and VGA when in OFF mode.
- **welcome_mode/welcome_drawer_oled.v**: `welcome_drawer_oled` module. Renders the welcome screen text and graphics on the OLED.
- **welcome_mode/welcome_drawer_vga.v**: `welcome_drawer_vga` module. Renders the welcome screen with interactive elements on VGA, handles button inputs for mode selection.
- **welcome_mode/welcome_mode_module.v**: `welcome_mode_module` module. Combines OLED and VGA drawers for the welcome mode, manages handshake for mode transitions.

## Constraints
- **my_constraints.xdc**: Xilinx Design Constraints file. Defines pin mappings for Basys3 board (clock, switches, buttons, OLED JB, VGA, PS2). Includes timing constraints.

## Notes
- Calculator and Grapher modules are referenced in `main.v` but not yet instantiated or implemented in the source directory.
- All modules use 100MHz clock from Basys3.
- OLED uses 96x64 resolution, VGA uses 640x480.