import re
import sys

def load_font_coe(filename):
    """Load font data from .coe file"""
    with open(filename, 'r') as f:
        content = f.read()

    # Extract the vector part
    vector_match = re.search(r'memory_initialization_vector=\s*(.*?);', content, re.DOTALL)
    if not vector_match:
        raise ValueError("Could not find memory_initialization_vector")

    # Split by commas and clean up
    hex_values = [x.strip() for x in vector_match.group(1).split(',') if x.strip()]

    # Convert to integers
    font_bytes = []
    for hex_val in hex_values:
        if hex_val:  # Skip empty strings
            font_bytes.append(int(hex_val, 16))

    # Organize into 256 characters, each with 8 bytes
    if len(font_bytes) < 256 * 8:
        raise ValueError(f"Not enough data: got {len(font_bytes)}, need {256*8}")

    font = []
    for char_idx in range(259):
        char_data = font_bytes[char_idx * 8 : (char_idx + 1) * 8]
        font.append(char_data)

    return font

def get_character_name(char_index):
    """Get the name/description of a character by its index (CP437)"""
    cp437_names = {
        # Control characters (0-31)
        0: "NUL (Null)",
        1: "SOH (Start of Heading) - White Smiley ☺",
        2: "STX (Start of Text) - Black Smiley ☻",
        3: "ETX (End of Text) - Heart ♥",
        4: "EOT (End of Transmission) - Diamond ♦",
        5: "ENQ (Enquiry) - Club ♣",
        6: "ACK (Acknowledge) - Spade ♠",
        7: "BEL (Bell) - Bullet •",
        8: "BS (Backspace) - Inverse Bullet ◘",
        9: "HT (Horizontal Tab) - Hollow Circle ○",
        10: "LF (Line Feed) - Inverse Circle ◙",
        11: "VT (Vertical Tab) - Male Symbol ♂",
        12: "FF (Form Feed) - Female Symbol ♀",
        13: "CR (Carriage Return) - Music Note ♪",
        14: "SO (Shift Out) - Double Music Note ♫",
        15: "SI (Shift In) - Sun ☼",
        16: "DLE (Data Link Escape) - Right Arrow ►",
        17: "DC1 (Device Control 1) - Left Arrow ◄",
        18: "DC2 (Device Control 2) - Up/Down Arrow ↕",
        19: "DC3 (Device Control 3) - Double Exclamation ‼",
        20: "DC4 (Device Control 4) - Pilcrow ¶",
        21: "NAK (Negative Acknowledge) - Section §",
        22: "SYN (Synchronous Idle) - Solid Rectangle ▬",
        23: "ETB (End of Transmission Block) - Up/Down Arrow ↨",
        24: "CAN (Cancel) - Up Arrow ↑",
        25: "EM (End of Medium) - Down Arrow ↓",
        26: "SUB (Substitute) - Right Arrow →",
        27: "ESC (Escape) - Left Arrow ←",
        28: "FS (File Separator) - Right Angle ∟",
        29: "GS (Group Separator) - Left/Right Arrow ↔",
        30: "RS (Record Separator) - Up Triangle ▲",
        31: "US (Unit Separator) - Down Triangle ▼",
        32: "' ' (Space)",
        33: "'!' (Exclamation Mark)",
        34: "'\"' (Double Quote)",
        35: "'#' (Hash)",
        36: "'$' (Dollar Sign)",
        37: "'%' (Percent)",
        38: "'&' (Ampersand)",
        39: "''' (Apostrophe)",
        40: "'(' (Open Parenthesis)",
        41: "')' (Close Parenthesis)",
        42: "'*' (Asterisk)",
        43: "'+' (Plus Sign)",
        44: "',' (Comma)",
        45: "'-' (Hyphen)",
        46: "'.' (Period)",
        47: "'/' (Slash)",
        48: "'0' (Digit Zero)",
        49: "'1' (Digit One)",
        50: "'2' (Digit Two)",
        51: "'3' (Digit Three)",
        52: "'4' (Digit Four)",
        53: "'5' (Digit Five)",
        54: "'6' (Digit Six)",
        55: "'7' (Digit Seven)",
        56: "'8' (Digit Eight)",
        57: "'9' (Digit Nine)",
        58: "':' (Colon)",
        59: "';' (Semicolon)",
        60: "'<' (Less-than)",
        61: "'=' (Equals)",
        62: "'>' (Greater-than)",
        63: "'?' (Question Mark)",
        64: "'@' (At Sign)",
        65: "'A' (Uppercase A)",
        66: "'B' (Uppercase B)",
        67: "'C' (Uppercase C)",
        68: "'D' (Uppercase D)",
        69: "'E' (Uppercase E)",
        70: "'F' (Uppercase F)",
        71: "'G' (Uppercase G)",
        72: "'H' (Uppercase H)",
        73: "'I' (Uppercase I)",
        74: "'J' (Uppercase J)",
        75: "'K' (Uppercase K)",
        76: "'L' (Uppercase L)",
        77: "'M' (Uppercase M)",
        78: "'N' (Uppercase N)",
        79: "'O' (Uppercase O)",
        80: "'P' (Uppercase P)",
        81: "'Q' (Uppercase Q)",
        82: "'R' (Uppercase R)",
        83: "'S' (Uppercase S)",
        84: "'T' (Uppercase T)",
        85: "'U' (Uppercase U)",
        86: "'V' (Uppercase V)",
        87: "'W' (Uppercase W)",
        88: "'X' (Uppercase X)",
        89: "'Y' (Uppercase Y)",
        90: "'Z' (Uppercase Z)",
        91: "'[' (Open Bracket)",
        92: "'\\' (Backslash)",
        93: "']' (Close Bracket)",
        94: "'^' (Caret)",
        95: "'_' (Underscore)",
        96: "'`' (Grave Accent)",
        97: "'a' (Lowercase a)",
        98: "'b' (Lowercase b)",
        99: "'c' (Lowercase c)",
        100: "'d' (Lowercase d)",
        101: "'e' (Lowercase e)",
        102: "'f' (Lowercase f)",
        103: "'g' (Lowercase g)",
        104: "'h' (Lowercase h)",
        105: "'i' (Lowercase i)",
        106: "'j' (Lowercase j)",
        107: "'k' (Lowercase k)",
        108: "'l' (Lowercase l)",
        109: "'m' (Lowercase m)",
        110: "'n' (Lowercase n)",
        111: "'o' (Lowercase o)",
        112: "'p' (Lowercase p)",
        113: "'q' (Lowercase q)",
        114: "'r' (Lowercase r)",
        115: "'s' (Lowercase s)",
        116: "'t' (Lowercase t)",
        117: "'u' (Lowercase u)",
        118: "'v' (Lowercase v)",
        119: "'w' (Lowercase w)",
        120: "'x' (Lowercase x)",
        121: "'y' (Lowercase y)",
        122: "'z' (Lowercase z)",
        123: "'{' (Open Curly Brace)",
        124: "'|' (Vertical Bar)",
        125: "'}' (Close Curly Brace)",
        126: "'~' (Tilde)",
        # Extended ASCII / CP437 characters (127-255) would go here
        # For brevity, I'll add a few key ones
        127: "DEL (Delete)",
        128: "Ç (Latin Capital C with Cedilla)",
        129: "ü (Latin Small U with Diaeresis)",
        130: "é (Latin Small E with Acute)",
        131: "â (Latin Small A with Circumflex)",
        132: "ä (Latin Small A with Diaeresis)",
        133: "à (Latin Small A with Grave)",
        134: "å (Latin Small A with Ring)",
        135: "ç (Latin Small C with Cedilla)",
        136: "ê (Latin Small E with Circumflex)",
        137: "ë (Latin Small E with Diaeresis)",
        138: "è (Latin Small E with Grave)",
        139: "ï (Latin Small I with Diaeresis)",
        140: "î (Latin Small I with Circumflex)",
        141: "ì (Latin Small I with Grave)",
        142: "Ä (Latin Capital A with Diaeresis)",
        143: "Å (Latin Capital A with Ring)",
        144: "É (Latin Capital E with Acute)",
        145: "æ (Latin Small Ae)",
        146: "Æ (Latin Capital Ae)",
        147: "ô (Latin Small O with Circumflex)",
        148: "ö (Latin Small O with Diaeresis)",
        149: "ò (Latin Small O with Grave)",
        150: "û (Latin Small U with Circumflex)",
        151: "ù (Latin Small U with Grave)",
        152: "ÿ (Latin Small Y with Diaeresis)",
        153: "Ö (Latin Capital O with Diaeresis)",
        154: "Ü (Latin Capital U with Diaeresis)",
        155: "¢ (Cent Sign)",
        156: "£ (Pound Sign)",
        157: "¥ (Yen Sign)",
        158: "₧ (Peseta Sign)",
        159: "ƒ (Latin Small F with Hook)",
        160: "á (Latin Small A with Acute)",
        161: "í (Latin Small I with Acute)",
        162: "ó (Latin Small O with Acute)",
        163: "ú (Latin Small U with Acute)",
        164: "ñ (Latin Small N with Tilde)",
        165: "Ñ (Latin Capital N with Tilde)",
        166: "ª (Feminine Ordinal Indicator)",
        167: "º (Masculine Ordinal Indicator)",
        168: "¿ (Inverted Question Mark)",
        169: "⌐ (Negation)",
        170: "¬ (Not Sign)",
        171: "½ (Vulgar Fraction One Half)",
        172: "¼ (Vulgar Fraction One Quarter)",
        173: "¡ (Inverted Exclamation Mark)",
        174: "« (Left-Pointing Double Angle Quotation Mark)",
        175: "» (Right-Pointing Double Angle Quotation Mark)",
        176: "░ (Light Shade)",
        177: "▒ (Medium Shade)",
        178: "▓ (Dark Shade)",
        179: "│ (Box Drawings Light Vertical)",
        180: "┤ (Box Drawings Light Vertical and Left)",
        181: "╡ (Box Drawings Vertical Single and Left Double)",
        182: "╢ (Box Drawings Vertical Double and Left Single)",
        183: "╖ (Box Drawings Down Double and Left Single)",
        184: "╕ (Box Drawings Down Single and Left Double)",
        185: "╣ (Box Drawings Vertical Double and Left Single)",
        186: "║ (Box Drawings Double Vertical)",
        187: "╗ (Box Drawings Double Down and Left)",
        188: "╝ (Box Drawings Double Up and Left)",
        189: "╜ (Box Drawings Up Double and Left Single)",
        190: "╛ (Box Drawings Up Single and Left Double)",
        191: "┐ (Box Drawings Light Down and Left)",
        192: "└ (Box Drawings Light Up and Right)",
        193: "┴ (Box Drawings Light Up and Horizontal)",
        194: "┬ (Box Drawings Light Down and Horizontal)",
        195: "├ (Box Drawings Light Vertical and Right)",
        196: "─ (Box Drawings Light Horizontal)",
        197: "┼ (Box Drawings Light Vertical and Horizontal)",
        198: "╞ (Box Drawings Vertical Single and Right Double)",
        199: "╟ (Box Drawings Vertical Double and Right Single)",
        200: "╚ (Box Drawings Double Up and Right)",
        201: "╔ (Box Drawings Double Down and Right)",
        202: "╩ (Box Drawings Double Up and Horizontal)",
        203: "╦ (Box Drawings Double Down and Horizontal)",
        204: "╠ (Box Drawings Double Vertical and Right)",
        205: "═ (Box Drawings Double Horizontal)",
        206: "╬ (Box Drawings Double Vertical and Horizontal)",
        207: "╧ (Box Drawings Up Single and Horizontal Double)",
        208: "╨ (Box Drawings Up Double and Horizontal Single)",
        209: "╤ (Box Drawings Down Single and Horizontal Double)",
        210: "╥ (Box Drawings Down Double and Horizontal Single)",
        211: "╙ (Box Drawings Up Double and Right Single)",
        212: "╘ (Box Drawings Up Single and Right Double)",
        213: "╒ (Box Drawings Down Single and Right Double)",
        214: "╓ (Box Drawings Down Double and Right Single)",
        215: "╫ (Box Drawings Vertical Double and Horizontal Single)",
        216: "╪ (Box Drawings Vertical Single and Horizontal Double)",
        217: "┘ (Box Drawings Light Up and Left)",
        218: "┌ (Box Drawings Light Down and Right)",
        219: "█ (Full Block)",
        220: "▄ (Lower Half Block)",
        221: "▌ (Left Half Block)",
        222: "▐ (Right Half Block)",
        223: "▀ (Upper Half Block)",
        224: "α (Greek Small Alpha)",
        225: "ß (Latin Small Sharp S)",
        226: "Γ (Greek Capital Gamma)",
        227: "π (Greek Small Pi)",
        228: "Σ (Greek Capital Sigma)",
        229: "σ (Greek Small Sigma)",
        230: "µ (Micro Sign)",
        231: "τ (Greek Small Tau)",
        232: "Φ (Greek Capital Phi)",
        233: "Θ (Greek Capital Theta)",
        234: "Ω (Greek Capital Omega)",
        235: "δ (Greek Small Delta)",
        236: "∞ (Infinity)",
        237: "φ (Greek Small Phi)",
        238: "ε (Greek Small Epsilon)",
        239: "∩ (Intersection)",
        240: "≡ (Identical To)",
        241: "± (Plus-Minus Sign)",
        242: "≥ (Greater-Than or Equal To)",
        243: "≤ (Less-Than or Equal To)",
        244: "⌠ (Top Half Integral)",
        245: "⌡ (Bottom Half Integral)",
        246: "÷ (Division Sign)",
        247: "≈ (Almost Equal To)",
        248: "° (Degree Sign)",
        249: "· (Middle Dot)",
        250: "· (Middle Dot)",
        251: "√ (Square Root)",
        252: "ⁿ (Superscript Latin Small N)",
        253: "² (Superscript Two)",
        254: "■ (Black Square)",
        255: "nbsp (Non-breaking Space)"
    }

    return cp437_names.get(char_index, f"Character {char_index}")

def draw_character_md(font, char_index):
    """Draw a character using Markdown code blocks"""
    if char_index < 0 or char_index >= len(font):
        return f"Invalid character index: {char_index}\n"

    char_data = font[char_index]
    char_name = get_character_name(char_index)
    result = f"### Character {char_index} (0x{char_index:02X}) - {char_name}\n\n"
    result += "```\n"

    for row in range(8):
        byte = char_data[row]
        line = ""
        for col in range(8):
            # MSB first (bit 7 is leftmost)
            bit = (byte >> (7 - col)) & 1
            line += '.' if bit else ' '
        result += line + "\n"
    result += "```\n\n"
    return result

def draw_ascii_range_md(font, start=0, end=255):
    """Draw ASCII characters in Markdown format"""
    result = "# 8x8 Font Character Map (Code Page 437)\n\n"
    result += f"Displaying characters {start} to {end} (0x{start:02X} to 0x{end:02X})\n\n"

    for idx in range(start, min(end + 1, len(font))):
        result += draw_character_md(font, idx)

    return result

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python font_viewer.py <font.coe file>")
        sys.exit(1)

    # Load the font
    font = load_font_coe(sys.argv[1])

    # Generate Markdown content
    print("Font loaded successfully!")
    print(f"Total characters: {len(font)}")
    print("Generating Markdown file...")

    # Generate Markdown content
    md_content = draw_ascii_range_md(font)

    # Write to file (use input filename with .md extension)
    input_filename = sys.argv[1]
    if input_filename.endswith('.coe'):
        output_file = input_filename[:-4] + '.md'
    else:
        output_file = input_filename + '.md'

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md_content)

    print(f"Markdown file '{output_file}' generated successfully!")
    print("You can open it in any Markdown viewer or text editor.")