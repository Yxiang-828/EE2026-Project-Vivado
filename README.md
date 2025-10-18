# EE2026 FPGA Graphics Calculator

## Project Status: **Core Infrastructure Complete** ✅

### ✅ **Fully Implemented & Working**
- **Mode Switching System**: OFF → WELCOME → CALCULATOR/GRAPHER modes
- **OLED Keypad Interface**: 5-bit key code input with debouncing
- **Shared Equation Buffer**: 32-character ASCII buffer shared between modes
- **VGA Display System**: 640×480 resolution with stable mode transitions
- **Text Rendering Engine**: 8×8 font ROM with proper bounds checking
- **Welcome Screen**: Interactive navigation with button controls
- **Display Architecture**: Dual OLED (96×64) + VGA output multiplexing

### 🚧 **Implemented But Placeholder (No Real Calculations)**
- **Calculator Mode**: Displays equation text only (no arithmetic)
- **Grapher Mode**: Shows equation text only (no graph plotting)
- **ALU Modules**: Framework exists but no actual math operations
- **Equation Parser**: Key-to-ASCII conversion only (no evaluation)

### ❌ **To Be Implemented**
- **Arithmetic Logic Unit (ALU)**: Add, subtract, multiply, divide operations
- **Graph Plotting Engine**: Function evaluation and pixel rendering
- **Equation Evaluation**: Parse and compute mathematical expressions
- **Advanced Functions**: Trigonometry, square root, logarithms
- **Result Display**: Show calculation outputs

## SETUP
Need to add font.coe as a new IP

Under Project Manager -> IP Catalog -> Memories & Storage Elements -> RAMs & ROMs -> Block Memory Generator

### BASIC
Interface Type: Native
Memory Type: Single Port ROM

## Component Name
blk_mem_gen_font

### Port A Options
Port A Width: 8
Port A Depth: 2048

### Other Options
Check the Load Init File box
Coe File: font.coe

Press OK then Generate

## Current Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TOP MODULE (main.v)                       │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────────┐    │
│  │   OLED     │→→│ Shared Buffer │→→│ Calculator Mode  │    │
│  │  Keypad    │  │   (32 chars)  │  │   (Text Only)    │    │
│  │  (Input)   │  │              │  │                  │    │
│  └────────────┘  └──────────────┘  └──────────────────┘    │
│       ↓ 5-bit          ↓ ASCII           ↓ VGA Text        │
│       key_code         equation          display           │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         VGA Display Controller                      │    │
│  │  • 640×480 Resolution  • 12-bit Color              │    │
│  │  • Font ROM (8×8)      • Stable Mode Switching     │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Workload Split (Updated)

### Ryan (You)
- ✅ **Main Navigation Page**: BRAM-based welcome screen (LUT usage: 7% → 1%)
- ✅ **Shared Buffer System**: 32-character equation management
- ✅ **VGA Display Fixes**: Resolved all text rendering and mode switching issues
- 🚧 **Arithmetic Logic Unit**: Framework ready, calculations pending

### Person 2
- ✅ **Number Input**: OLED keypad interface implemented
- 🚧 **Data Parser**: Key-to-ASCII conversion done, evaluation pending

### Person 3
- 🚧 **Function Input**: Keypad supports operators, evaluation pending
- ❌ **Graph Plotting**: Framework exists, rendering not implemented

### Person 4
- ❌ **Advanced Graphing**: Axis rendering and function plotting pending
- ❌ **Result Display**: Calculation output visualization pending

## Key Achievements
- **VGA Display Issues Resolved**: Fixed inverted colors, symbol clones, lateral inversion, fuzzy mode switching, and positioning
- **Stable Architecture**: Clean mode transitions with no visual artifacts
- **Shared Buffer System**: Unified equation management across calculator and grapher modes
- **Professional Text Rendering**: Proper bounds checking and centering

## Next Steps
1. **Implement ALU Operations**: Add, subtract, multiply, divide
2. **Equation Parser**: Convert ASCII expressions to calculations
3. **Graph Rendering**: Plot mathematical functions on VGA
4. **Result Display**: Show computation outputs

---
*Last Updated: October 19, 2025* 
