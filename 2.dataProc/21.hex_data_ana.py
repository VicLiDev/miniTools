#!/usr/bin/env python
#########################################################################
# File Name: 21.hex_data_ana.py
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Fri 10 Apr 2026 04:32:56 PM CST
#########################################################################

"""
Compare two files and report differing bits.
Extract bit field value from a hex value or a hex file.

Bit numbering: line1 rightmost = bit0, line1 leftmost = bit(N-1),
               line2 rightmost = bitN, line2 leftmost = bit(2N-1), etc.
"""

import sys
import argparse

BITS_PER_HEX = 4


# ---------------------------------------------------------------------------
# bit extraction
# ---------------------------------------------------------------------------

def extract_bits(hex_str, start_bit, num_bits):
    val = int(hex_str, 16)
    mask = (1 << num_bits) - 1
    extracted = (val >> start_bit) & mask
    return extracted, format(extracted, f'0{num_bits}b')


def extract_bits_from_file(file_path, start_bit, num_bits):
    with open(file_path) as f:
        lines = [l.strip() for l in f if l.strip()]

    chars_per_line = len(lines[0])
    bits_per_line = chars_per_line * BITS_PER_HEX

    merged = 0
    # range(start, stop, step)
    for i in range(len(lines) - 1, -1, -1):
        merged = (merged << bits_per_line) | int(lines[i], 16)

    mask = (1 << num_bits) - 1
    extracted = (merged >> start_bit) & mask
    bin_str = format(extracted, f'0{num_bits}b')

    line_start = start_bit // bits_per_line + 1
    line_end = (start_bit + num_bits - 1) // bits_per_line + 1
    loc = f"(line {line_start})" if line_start == line_end else f"(line {line_start}~{line_end})"

    print(f"file: {file_path}")
    print(f"bits_per_line: {bits_per_line} ({chars_per_line} hex chars), total lines: {len(lines)}")
    print(f"start_bit={start_bit}, num_bits={num_bits} {loc}")
    print(f"extracted bits: {bin_str}")
    print(f"value: {extracted} (0x{extracted:x})")
    return extracted, bin_str


def cmd_bits(hex_list, start_bit, num_bits):
    for hex_str in hex_list:
        extracted, bin_str = extract_bits(hex_str, start_bit, num_bits)
        print(f"hex={hex_str}, start_bit={start_bit}, num_bits={num_bits}")
        print(f"extracted bits: {bin_str}")
        print(f"value: {extracted} (0x{extracted:x})")


# ---------------------------------------------------------------------------
# diff
# ---------------------------------------------------------------------------

def get_bit(hex_line, bit_pos, chars_per_line):
    char_idx = chars_per_line - 1 - (bit_pos // BITS_PER_HEX)
    bit_in_char = bit_pos % BITS_PER_HEX
    return (int(hex_line[char_idx], 16) >> bit_in_char) & 1


CTX_LEFT = 4
CTX_RIGHT = 5
COL_WIDTH_VAL = 8


def cmd_diff(file1, file2):
    with open(file1) as f:
        lines1 = [l.strip() for l in f if l.strip()]
    with open(file2) as f:
        lines2 = [l.strip() for l in f if l.strip()]

    if len(lines1) != len(lines2):
        print(f"Error: line count mismatch ({len(lines1)} vs {len(lines2)})")
        sys.exit(1)

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
                diffs.append((line_idx, base_bit + bit_in_line, b1, b2))

    if not diffs:
        print("Files are identical.")
        return

    print(f"File1: {file1}")
    print(f"File2: {file2}")
    print(f"Found {len(diffs)} differing bit(s):")
    hdr = f"{'Idx':<5}{'Line':<6}{'Bit':<10}{'File1':<{COL_WIDTH_VAL}}{'File2':<{COL_WIDTH_VAL}}Context"
    print(hdr)
    ctx_max_len = (CTX_LEFT + CTX_RIGHT) * 2 + len(" vs ")
    print("-" * (len(hdr) + ctx_max_len))
    for idx, (line_idx, bit_num, b1, b2) in enumerate(diffs, 1):
        char_pos = chars_per_line - 1 - (bit_num % bits_per_line) // BITS_PER_HEX
        left = max(0, char_pos - CTX_LEFT)
        right = min(chars_per_line, char_pos + CTX_RIGHT)
        ctx1 = lines1[line_idx][left:right]
        ctx2 = lines2[line_idx][left:right]
        marker = " " * (char_pos - left) + "^"
        print(f"{idx:<5}{line_idx+1:<6}{bit_num:<10}{b1:<{COL_WIDTH_VAL}}{b2:<{COL_WIDTH_VAL}}{ctx1} vs {ctx2}")
        print(f"{'':<5}{'':<6}{'':<10}{'':<{COL_WIDTH_VAL}}{'':<{COL_WIDTH_VAL}}{marker}")

    affected = sorted(set(d[0] for d in diffs))
    print(f"\nSummary: {len(diffs)} bit(s) differ")
    print(f"Affected line(s): {', '.join(str(i+1) for i in affected)}")


# ---------------------------------------------------------------------------
# entry
# ---------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(
        description="Compare two files and report differing bits, "
                    "or extract a bit field from a hex value.",
        epilog="examples:\n"
               "  %(prog)s -d file1.hex file2.hex\n"
               "  %(prog)s -b 0x350 3 2\n"
               "  %(prog)s -b 0xABC 0xFF0 3 2\n"
               "  %(prog)s -b 3 2 -f data.txt\n"
               "\n"
               "-b without -f:  HEX [HEX ...] START_BIT NUM_BITS\n"
               "-b with    -f:  START_BIT NUM_BITS\n",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("-d", "--diff", nargs=2, metavar=("FILE1", "FILE2"),
                   help="compare two hex files and report differing bits")
    g.add_argument("-b", "--bits", nargs="+",
                   help="extract bit field, last two args are START_BIT NUM_BITS")
    parser.add_argument("-f", dest="file",
                   help="hex file for continuous bit stream (use with -b)")
    return parser


def main():
    args = build_parser().parse_args()

    if args.bits:
        start_bit, num_bits = int(args.bits[-2]), int(args.bits[-1])
        if args.file:
            extract_bits_from_file(args.file, start_bit, num_bits)
        else:
            cmd_bits(args.bits[:-2], start_bit, num_bits)
        return

    cmd_diff(*args.diff)


if __name__ == "__main__":
    main()
