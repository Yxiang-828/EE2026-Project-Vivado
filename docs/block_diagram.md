# Block Diagram

This document provides a high-level block diagram of the FPGA design.

## Top-Level Block Diagram

```
+-------------------+
|   Top_Student     |
|                   |
|  Inputs:          |
|  - clk            |
|  - btn[4:0]       |
|  - sw[15:0]       |
|  - PS2Clk/Data    |
|                   |
|  Outputs:         |
|  - JB[7:0] (OLED) |
|  - VGA signals    |
|  - current_mode   |
+-------------------+
          |
          | Mode Control
          | (FSM with handshake)
          v
+-------------------+
| Mode Multiplexer  |
|                   |
| OFF     WELCOME   |
| CALC    GRAPH     |
+-------------------+
    |       |       |       |
    v       v       v       v
+-----+ +-----------+ +-----+ +-----+
| OFF | | WELCOME   | |CALC | |GRAPH|
| MOD | | MODULE    | | MOD | | MOD |
+-----+ +-----------+ +-----+ +-----+
                |
                | Submodules
                v
+-------------------+
| Display Handler   |
|                   |
| OLED Controller   |
| VGA Controller    |
+-------------------+
          |
          | Physical Outputs
          v
+-------------------+
| Basys3 Board      |
|                   |
| OLED (JB)         |
| VGA Connector     |
+-------------------+
```

## Submodule Details

### Welcome Module
```
welcome_mode_module
├── welcome_drawer_oled
│   └── OLED Graphics
└── welcome_drawer_vga
    ├── VGA Graphics
    └── Button Input Handler
```

### Display Handler
```
display_handler
├── Oled_Display (SPI)
├── vga_sync (Timing)
└── Pixel Multiplexing
```

### Accessories
- button_debouncer_array: Debounces btn[4:0]
- fourteen_segment_drawer_*: Character rendering
- flexible_timer: Timing utilities (unused)

## Data Flow
1. Buttons/Switches → Debouncer → Mode FSM
2. Mode → Submodule Selection → OLED/VGA Data
3. Data → Display Handler → Physical Outputs

## Notes
- Dashed lines indicate placeholder modules (Calculator/Grapher).
- All modules synchronous to 100MHz clk.
- Reset signal (~sw[15]) resets all modules.