#!/usr/bin/env python
#########################################################################
# File Name: 21.hex_diff_off.py
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Fri 10 Apr 2026 04:32:56 PM CST
#########################################################################

"""
Compare two files and report differing bits.

Each line is N bits (hex chars * 4).
Bit numbering: line1 rightmost = bit0, line1 leftmost = bit(N-1),
               line2 rightmost = bitN, line2 leftmost = bit(2N-1), etc.
"""

import sys

BITS_PER_HEX = 4        # each hex char represents 4 bits
CTX_LEFT = 4            # hex chars shown before the diff position
CTX_RIGHT = 5           # hex chars shown after the diff position
COL_WIDTH_VAL = 8       # column width for File1/File2 value display


def get_bit(hex_line, bit_pos, chars_per_line):
    """Get the value of a bit at a given position within a hex line.

    bit_pos: 0 = rightmost bit (LSB)
    """
    char_idx = chars_per_line - 1 - (bit_pos // BITS_PER_HEX)
    bit_in_char = bit_pos % BITS_PER_HEX
    val = int(hex_line[char_idx], 16)
    return (val >> bit_in_char) & 1


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <file1> <file2>")
        sys.exit(1)

    f1_path, f2_path = sys.argv[1], sys.argv[2]

    with open(f1_path) as f:
        lines1 = [l.strip() for l in f if l.strip()]
    with open(f2_path) as f:
        lines2 = [l.strip() for l in f if l.strip()]

    if len(lines1) != len(lines2):
        print(f"Error: line count mismatch ({len(lines1)} vs {len(lines2)})")
        sys.exit(1)

    # derive bits per line from actual line length
    chars_per_line = len(lines1[0])
    bits_per_line = chars_per_line * BITS_PER_HEX
    print(f"Bits per line: {bits_per_line} ({chars_per_line} hex chars)")

    diffs = []
    for line_idx, (l1, l2) in enumerate(zip(lines1, lines2)):
        base_bit = line_idx * bits_per_line
        for bit_in_line in range(bits_per_line):
            b1 = get_bit(l1, bit_in_line, chars_per_line)
            b2 = get_bit(l2, bit_in_line, chars_per_line)
            if b1 != b2:
                bit_num = base_bit + bit_in_line
                diffs.append((line_idx, bit_num, b1, b2))

    if not diffs:
        print("Files are identical.")
        return

    print(f"File1: {f1_path}")
    print(f"File2: {f2_path}")
    print(f"Found {len(diffs)} differing bit(s):")
    hdr = f"{'Line':<6}{'Bit':<10}{'File1':<{COL_WIDTH_VAL}}{'File2':<{COL_WIDTH_VAL}}Context"
    print(hdr)
    ctx_max_len = (CTX_LEFT + CTX_RIGHT) * 2 + len(" vs ")
    print("-" * (len(hdr) + ctx_max_len))
    for line_idx, bit_num, b1, b2 in diffs:
        l1 = lines1[line_idx]
        l2 = lines2[line_idx]
        char_pos = chars_per_line - 1 - (bit_num % bits_per_line) // BITS_PER_HEX
        left = max(0, char_pos - CTX_LEFT)
        right = min(chars_per_line, char_pos + CTX_RIGHT)
        ctx1 = l1[left:right]
        ctx2 = l2[left:right]
        marker = " " * (char_pos - left) + "^"
        print(f"{line_idx+1:<6}{bit_num:<10}{b1:<{COL_WIDTH_VAL}}{b2:<{COL_WIDTH_VAL}}{ctx1} vs {ctx2}")
        print(f"{'':<6}{'':<10}{'':<{COL_WIDTH_VAL}}{'':<{COL_WIDTH_VAL}}{marker}")

    print(f"\nSummary: {len(diffs)} bit(s) differ")
    # print affected lines summary
    affected_lines = sorted(set(d[0] for d in diffs))
    print(f"Affected line(s): {', '.join(str(i+1) for i in affected_lines)}")


if __name__ == "__main__":
    main()
