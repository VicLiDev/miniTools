#!/usr/bin/env python
#########################################################################
# File Name: cmodel_reg_proc.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 19 Mar 2026 08:17:23 PM CST
#########################################################################

# usage: python <exe> <input_file>

import re
import argparse
import os

def read_file_to_list(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    lines = []
    with open(filename, 'r') as file:
        for line in file:
            lines.append(line.strip().split())
    return lines

def main():
    parser = argparse.ArgumentParser(description='处理 cmodel 寄存器配置文件')
    parser.add_argument('input_file', nargs='?', default='./reg_config.h',
                        help='输入文件路径 (默认: ./reg_config.h)')
    parser.add_argument('--base', '-b', type=lambda x: int(x, 0), default=0x100,
                        help='寄存器基地址偏移 (默认: 0x100)')
    args = parser.parse_args()

    if not os.path.exists(args.input_file):
        print(f"错误: 文件不存在: {args.input_file}\n")
        parser.print_help()
        return

    print(f"基地址偏移: 0x{args.base:x}")
    lst = read_file_to_list(args.input_file)
    results = []
    for line in lst:
        entry = re.split(r'[()+=]', line[0])
        reg_idx = int((int(entry[2]) - args.base) / 4)
        reg_off = reg_idx * 4
        # if reg_idx < 0:
        #     continue
        results.append((reg_idx, reg_off, entry[4]))

    for reg_idx, reg_off, value in sorted(results, key=lambda x: x[0]):
        print(f"reg[{reg_idx:03}]: 0x{reg_off:08x}: {value}")

if __name__ == "__main__":
    main()
