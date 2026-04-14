#!/usr/bin/env python
#########################################################################
# File Name: cmodel_reg_proc.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 19 Mar 2026 08:17:23 PM CST
#########################################################################

# usage: python <exe> <input_file>
#
# 支持的寄存器配置格式:
#   1. word32(0x22140000+ 0x100 + 4*9)=0x01000000   (4*N 形式, idx 直接取 N)
#   2. word32(0x22140000+36)=0x01000000             (偏移值形式, idx = 偏移/4)

import re
import argparse
import os

def read_file_lines(filename):
    """逐行读取文件，返回原始行字符串列表"""
    lines = []
    with open(filename, 'r') as file:
        for line in file:
            lines.append(line.strip())
    return lines

def safe_eval_expr(expr):
    """安全地计算只含数字和 +-*/ 的算术表达式"""
    expr = expr.strip()
    if not re.fullmatch(r'[0-9a-fA-FxX+\-*/\s]+', expr):
        raise ValueError(f"不安全的表达式: {expr}")
    return int(eval(expr, {"__builtins__": {}}, {}))


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
    lines = read_file_lines(args.input_file)
    # 匹配寄存器配置行: word32(...) = 0x...
    #   group(1): 括号内的地址表达式 (如 0x22140000+ 0x100 + 4*9)
    #   group(2): 等号后的写入值 (如 0x01000000)
    pat = re.compile(r'word\d+\((.+?)\)=(0x[0-9a-fA-F]+)')
    results = []
    for line in lines:
        m = pat.search(line)
        if not m:
            continue
        addr_expr = m.group(1)
        value = m.group(2)
        # 优先提取 4*N 形式的寄存器索引
        #   匹配 "4*9" 或 "4*0xF", group(1) 为乘数 N, 即寄存器 idx
        m4 = re.search(r'4\*\s*(\d+|0x[0-9a-fA-F]+)', addr_expr)
        if m4:
            reg_idx = int(m4.group(1), 0)
        else:
            reg_idx = int((safe_eval_expr(addr_expr) - args.base) / 4)
        reg_off = reg_idx * 4
        # if reg_idx < 0:
        #     continue
        results.append((reg_idx, reg_off, value))

    for reg_idx, reg_off, value in sorted(results, key=lambda x: x[0]):
        print(f"reg[{reg_idx:03}]: 0x{reg_off:08x}: {value}")

if __name__ == "__main__":
    main()
