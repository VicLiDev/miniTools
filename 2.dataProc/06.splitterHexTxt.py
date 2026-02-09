#!/usr/bin/env python
#########################################################################
# File Name: 06.splitterHexTxt.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 26 Sep 2025 03:29:07 PM CST
#########################################################################

# 将十六进制字符串按指定字节数分行输出，可选顺序或逆序。
# ex: ./<exe> <input> <output> -n 3 -r

import argparse

def split_hex_to_lines(hex_str: str, bytes_per_line: int, reverse: bool = False) -> list[str]:
    """
    将连续的 hex 字符串按指定字节数分行，可选择顺序或逆序。

    :param hex_str: 原始十六进制字符串（不含空格）
    :param bytes_per_line: 每行多少字节
    :param reverse: 是否逆序（True 表示从右到左）
    :return: 分行后的字符串列表
    """
    # 清理输入
    hex_str = hex_str.strip().replace(" ", "").lower()
    if len(hex_str) % 2 != 0:
        raise ValueError(f"Hex string length must be an even number：{hex_str}")

    # 按字节切分
    bytes_list = [hex_str[i:i+2] for i in range(0, len(hex_str), 2)]

    # 如果需要逆序
    if reverse:
        bytes_list.reverse()

    # 按指定行宽拼接
    lines = [
        ''.join(bytes_list[i:i+bytes_per_line])
        for i in range(0, len(bytes_list), bytes_per_line)
    ]
    return lines


def process_file(input_file: str, output_file: str, bytes_per_line: int, reverse: bool = False):
    """
    处理文件：读取每行 hex → 分行 → 输出到新文件
    """
    with open(input_file, 'r', encoding='utf-8') as fin:
        hex_lines = [line.strip() for line in fin if line.strip()]

    with open(output_file, 'w', encoding='utf-8') as fout:
        for hex_line in hex_lines:
            lines = split_hex_to_lines(hex_line, bytes_per_line, reverse=reverse)
            fout.write('\n'.join(lines) + '\n')

    print(f"Conversion complete! Results saved to {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Output the hexadecimal string in the specified number of lines, "
            "in either ascending or descending order.\n"
            "  ex: ./<exe> <input> <output> -n 3 -r"),
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument("input_file", help="Input file path")
    parser.add_argument("output_file", help="Output file path")
    parser.add_argument(
        "-n", "--bytes-per-line",
        type=int,
        default=1,
        help="Number of bytes per line (default 1 bytes)"
    )
    parser.add_argument(
        "-r", "--reverse",
        action="store_true",
        help="Whether to output bytes in reverse order (default order)"
    )

    args = parser.parse_args()

    process_file(
        args.input_file,
        args.output_file,
        bytes_per_line=args.bytes_per_line,
        reverse=args.reverse
    )


if __name__ == "__main__":
    main()

