# Documentation Overview

This `docs/` folder contains comprehensive documentation for the FPGA Interactive Calculator/Grapher project.

## Files
- **modular_files.md**: List and description of all Verilog modules.
- **inputs_outputs.md**: Top-level module ports and interfaces.
- **navigation_flow.md**: User interaction and mode transitions.
- **current_progress.md**: Implementation status and next steps.
- **schematic.md**: Hardware connections and block diagram.
- **block_diagram.md**: Software architecture diagram.

## Project Summary
This is a Verilog project for the Basys3 FPGA board implementing an interactive calculator and grapher with OLED keypad and VGA display. Currently, the welcome screen and mode switching are implemented. Calculator and grapher features are developed but not yet integrated.

## Key Features
- 4 operating modes: OFF, WELCOME, CALCULATOR, GRAPHER
- OLED display (96x64) for keypad/interface
- VGA display (640x480) for graphics/output
- Button and switch inputs
- Debounced button handling
- Modular design for easy expansion

## Hardware
- Digilent Basys3 (XC7A35T)
- OLED display on Pmod JB
- VGA output
- 16 switches, 5 buttons

## Development
- Vivado 2023+ recommended
- Source files in `../project_vivado/`
- Constraints in `../project_vivado/Constraints/`

For questions or updates, refer to individual documentation files.