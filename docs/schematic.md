# Schematic

This document describes the hardware schematic and connections for the Basys3 FPGA project.

## Basys3 Board Overview
- **FPGA**: Xilinx Artix-7 XC7A35T-1CPG236C.
- **Clock**: 100MHz oscillator connected to W5 pin.
- **Power**: 3.3V and 1.8V supplies.

## Input Interfaces
- **Switches (sw[15:0])**: 16 slide switches connected to pins V17, V16, W16, W17, W15, V15, W14, W13, V2, T3, T2, R3, W2, U1, T1, R2.
- **Buttons (btn[4:0])**: 5 push buttons:
  - Centre: U18
  - Up: T18
  - Left: W19
  - Right: T17
  - Down: U17
- **PS2**: Keyboard interface on C17 (PS2Clk) and B17 (PS2Data), currently unused.

## Output Interfaces
- **OLED Display (JB[7:0])**: Connected to Pmod JB header:
  - JB[0]: A14 (MOSI)
  - JB[1]: A16 (SCK)
  - JB[2]: B15 (DC)
  - JB[3]: B16 (RES)
  - JB[4]: A15 (VBAT)
  - JB[5]: A17 (VDD)
  - JB[6]: C15 (CS)
  - JB[7]: C16 (Unused)
- **VGA**: Standard VGA connector:
  - Hsync: P19
  - Vsync: R19
  - Red[3:0]: G19, H19, J19, N19
  - Green[3:0]: N18, L18, K18, J18
  - Blue[3:0]: J17, H17, G17, D17

## Internal Block Diagram

```
Top_Student Module
├── Clock: clk (100MHz)
├── Reset: ~sw[15]
├── Buttons: btn[4:0] → button_debouncer_array → btn_debounced[4:0]
├── Switches: sw[15:0]
├── PS2: Tri-stated (not used)
├── Mode Control: current_main_mode[1:0]
│   ├── OFF: off_module
│   ├── WELCOME: welcome_mode_module
│   │   ├── welcome_drawer_oled
│   │   └── welcome_drawer_vga
│   ├── CALCULATOR: (placeholder)
│   └── GRAPHER: (placeholder)
├── Display Handler: display_handler
│   ├── OLED: pixel_index[12:0], oled_data[15:0] → JB[7:0]
│   └── VGA: vga_x[9:0], vga_y[9:0], vga_pixel_data[11:0] → VGA_Hsync, VGA_Vsync, VGA_RGB[11:0]
└── Debug: current_main_mode[1:0]
```

## Timing
- **Clock**: 100MHz system clock.
- **OLED**: SPI interface, ~10MHz clock derived from system clock.
- **VGA**: 640x480@60Hz, pixel clock ~25MHz derived from system clock.

## Power Considerations
- OLED requires 3.3V and controlled power sequencing.
- VGA signals are 3.3V CMOS.
- Total power consumption: <1A @3.3V for implemented features.

## Notes
- All I/O uses LVCMOS33 standard.
- PS2 pins have pull-ups enabled.
- Unused pins are left unconstrained or tri-stated.