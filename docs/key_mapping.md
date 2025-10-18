# Key Mapping Reference

This document details the complete key mapping system for the calculator, including key codes, ASCII conversions, and display outputs.

## Key Code Constants (5-bit values)

```
KEY_0 = 0, KEY_1 = 1, KEY_2 = 2, KEY_3 = 3, KEY_4 = 4, KEY_5 = 5, KEY_6 = 6, KEY_7 = 7
KEY_8 = 8, KEY_9 = 9, KEY_ADD = 10, KEY_SUB = 11, KEY_MUL = 12, KEY_DIV = 13
KEY_POW = 14, KEY_SIN = 15, KEY_COS = 16, KEY_TAN = 17, KEY_LN = 18
KEY_SQRT = 19, KEY_PI = 20, KEY_E = 21
KEY_DOT = 22, KEY_EQUAL = 23, KEY_CLEAR = 24, KEY_LPAREN = 25, KEY_RPAREN = 26
KEY_DELETE = 27, KEY_FACTORIAL = 28
```

## ASCII Converter Output (Backend Logic)

The `key_to_ascii_converter.v` module converts key codes to ASCII characters for backend processing:

| Key Code | ASCII Char | Hex | Description |
|----------|------------|-----|-------------|
| KEY_0-9 | '0'-'9' | 0x30-0x39 | Digits |
| KEY_ADD | '+' | 0x2B | Addition |
| KEY_SUB | '-' | 0x2D | Subtraction |
| KEY_MUL | '*' | 0x2A | Multiplication |
| KEY_DIV | '/' | 0x2F | Division |
| KEY_POW | '^' | 0x5E | Power/Exponentiation |
| KEY_DOT | '.' | 0x2E | Decimal point |
| KEY_EQUAL | '=' | 0x3D | Equals |
| KEY_LPAREN | '(' | 0x28 | Left parenthesis |
| KEY_RPAREN | ')' | 0x29 | Right parenthesis |
| **KEY_SIN** | **'s'** | **0x73** | Sin function identifier |
| **KEY_COS** | **'c'** | **0x63** | Cos function identifier |
| **KEY_TAN** | **'t'** | **0x74** | Tan function identifier |
| **KEY_LN** | **'l'** | **0x6C** | Natural log identifier |
| **KEY_SQRT** | **'√'** | **0xFB** | Square root symbol |
| **KEY_PI** | **'π'** | **0xE3** | Pi constant |
| **KEY_E** | **'e'** | **0x65** | Euler's number |
| **KEY_FACTORIAL** | **'!'** | **0x21** | Factorial symbol |
| KEY_CLEAR | 'C' | 0x43 | Clear |
| KEY_DELETE | 'D' | 0x44 | Delete |

## Display Output (VGA/OLED Rendering)

When function keys are pressed, the system inserts full function names into the display buffer for readability:

| Key Pressed | Display Shows | Character Count | ASCII Sequence |
|-------------|---------------|-----------------|----------------|
| Sin key | **"sin"** | 3 chars | 0x73, 0x69, 0x6E |
| Cos key | **"cos"** | 3 chars | 0x63, 0x6F, 0x73 |
| Tan key | **"tan"** | 3 chars | 0x74, 0x61, 0x6E |
| Ln key | **"ln"** | 2 chars | 0x6C, 0x6E |
| Sqrt key | **"√"** | 1 char | 0xFB |
| Pi key | **"π"** | 1 char | 0xE3 |
| E key | **"e"** | 1 char | 0x65 |
| Factorial key | **"!"** | 1 char | 0x21 |
| Numbers/Operators | Single chars | 1 char each | As ASCII table |

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