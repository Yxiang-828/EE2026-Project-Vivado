# Key Mapping Reference

## Overview
This document details the key code mappings used in the FPGA calculator's OLED keypad system. Key codes are assigned based on keypad layout positions, not logical grouping. Each key press generates a 5-bit key code (0-28) that gets converted to ASCII characters by the `key_to_ascii_converter.v` module.

## Key Code to ASCII Mapping

| Key Code | ASCII Char | Hex | Key Label | Page | Position |
|----------|------------|-----|-----------|------|----------|
| 0 | '7' | 0x37 | 7 | 1 | Row 0, Col 0 |
| 1 | '8' | 0x38 | 8 | 1 | Row 0, Col 1 |
| 2 | '9' | 0x39 | 9 | 1 | Row 0, Col 2 |
| 3 | '/' | 0x2F | ÷ | 1 | Row 0, Col 3 |
| 4 | 'C' | 0x43 | C | 1 | Row 0, Col 4 |
| 5 | '4' | 0x34 | 4 | 1 | Row 1, Col 0 |
| 6 | '5' | 0x35 | 5 | 1 | Row 1, Col 1 |
| 7 | '6' | 0x36 | 6 | 1 | Row 1, Col 2 |
| 8 | '*' | 0x2A | × | 1 | Row 1, Col 3 |
| 9 | 'D' | 0x44 | D | 1 | Row 1, Col 4 |
| 10 | '1' | 0x31 | 1 | 1 | Row 2, Col 0 |
| 11 | '2' | 0x32 | 2 | 1 | Row 2, Col 1 |
| 12 | '3' | 0x33 | 3 | 1 | Row 2, Col 2 |
| 13 | '-' | 0x2D | - | 1 | Row 2, Col 3 |
| 14 | '+' | 0x2B | + | 1 | Row 2, Col 4 |
| 15 | '0' | 0x30 | 0 | 1 | Row 3, Col 0 |
| 16 | '.' | 0x2E | . | 1 | Row 3, Col 1 |
| 17 | '^' | 0x5E | ^ | 1 | Row 3, Col 2 |
| 18 | '√' | 0xFB | √ | 1 | Row 3, Col 3 |
| 19 | '=' | 0x3D | = | 1 | Row 3, Col 4 |
| 20 | 's' | 0x73 | sin | 2 | Row 0, Col 0 |
| 21 | 'c' | 0x63 | cos | 2 | Row 0, Col 1 |
| 22 | 't' | 0x74 | tan | 2 | Row 0, Col 2 |
| 23 | '(' | 0x28 | ( | 2 | Row 1, Col 0 |
| 24 | ')' | 0x29 | ) | 2 | Row 1, Col 1 |
| 25 | '^' | 0x5E | x² | 2 | Row 1, Col 2 |
| 26 | '√' | 0xFB | √x | 2 | Row 2, Col 0 |
| 27 | 'π' | 0xE3 | π | 2 | Row 2, Col 1 |
| 28 | 'e' | 0x65 | e | 2 | Row 2, Col 2 |

## Display Logic Override

**Important**: While the ASCII converter outputs single characters, the main.v shared buffer logic detects function key codes and inserts full function names:

| Key Code | ASCII Converter | Display Logic Inserts | Description |
|----------|-----------------|----------------------|-------------|
| 20 (sin) | 's' | "sin" (3 chars) | Sine function |
| 21 (cos) | 'c' | "cos" (3 chars) | Cosine function |
| 22 (tan) | 't' | "tan" (3 chars) | Tangent function |
| 25 (x²) | '^' | "^2" (2 chars) | Power of 2 |
| 26 (√x) | '√' | "√(" (2 chars) | Square root with parenthesis |

## Keypad Layout

### Page 1: Numbers and Basic Operators (4×5 grid)
```
┌──────┬──────┬──────┬──────┬──────┐
│  7   │  8   │  9   │  /   │  C   │  ← Row 0 (codes 0-4)
├──────┼──────┼──────┼──────┼──────┤
│  4   │  5   │  6   │  *   │  D   │  ← Row 1 (codes 5-9)
├──────┼──────┼──────┼──────┼──────┤
│  1   │  2   │  3   │  -   │  +   │  ← Row 2 (codes 10-14)
├──────┼──────┼──────┼──────┼──────┤
│  0   │  .   │  ^   │  √   │  =   │  ← Row 3 (codes 15-19)
└──────┴──────┴──────┴──────┴──────┘
```

### Page 2: Functions and Advanced Symbols (3×3 grid)
```
┌─────────┬─────────┬─────────┐
│   sin   │   cos   │   tan   │  ← Row 0 (codes 20-22)
├─────────┼─────────┼─────────┤
│    (    │    )    │   x²    │  ← Row 1 (codes 23-25)
├─────────┼─────────┼─────────┤
│   √x    │    π    │    e    │  ← Row 2 (codes 26-28)
└─────────┴─────────┴─────────┴
```

## Processing Flow
1. **Physical Key Press** → 5-bit key code (0-28) based on keypad position
2. **ASCII Converter** → Single ASCII character based on layout mapping
3. **Main.v Logic** → Detects function codes (20-22, 25-26) → Inserts multi-char names
4. **Display** → Shows full readable function names

## Special Characters
- **Square Root (√)**: 0xFB (CP437 extended ASCII)
- **Pi (π)**: 0xE3 (CP437 extended ASCII)
- **Standard ASCII**: 0x20-0x7E for basic characters

## Buffer Management
- **Maximum**: 64 characters (512 bits)
- **OLED Display**: Shows scrolling last 10 characters
- **VGA Display**: Shows all characters centered
- **Multi-char Functions**: Handled by main.v logic, not converter

| Function Key | Display Text | Chars | ASCII Sequence |
|--------------|--------------|-------|----------------|
| sin (code 20) | **"sin"** | 3 | 0x73, 0x69, 0x6E |
| cos (code 21) | **"cos"** | 3 | 0x63, 0x6F, 0x73 |
| tan (code 22) | **"tan"** | 3 | 0x74, 0x61, 0x6E |
| x² (code 25) | **"^2"** | 2 | 0x5E, 0x32 |
| √x (code 26) | **"√("** | 2 | 0xFB, 0x28 |
| π (code 27) | **"π"** | 1 | 0xE3 |
| e (code 28) | **"e"** | 1 | 0x65 |

## System Architecture

### Dual Input Paths
1. **OLED Keypad Path**: Direct character insertion into expression buffer
2. **External Keypad Path**: Key code → ASCII conversion → Shared buffer management

### Display Logic
- **VGA Display**: Reads from `shared_equation_buffer` (shows full function names)
- **OLED Display**: Shows local `expression_buffer` (also full function names)
- **Backend Logic**: Uses key codes for function identification
- **Buffer Capacity**: 64 characters maximum (512 bits)

### Key Processing Flow
1. Physical key press → 5-bit key code
2. `key_to_ascii_converter` → Single ASCII char (for compatibility)
3. `main.v` shared buffer logic → Detects function key codes → Inserts full names
4. VGA/OLED modules → Render full function names from buffer

## Notes
- Function keys display as full, readable names (e.g., "sin" not "s")
- Single-character ASCII mappings are maintained for backward compatibility
- Extended ASCII characters (√, π) are supported via Code Page 437 font
- System ensures consistent display across VGA and OLED outputs</content>
<parameter name="filePath">c:\Users\xiang\ee2026_Project\docs\key_mapping.md