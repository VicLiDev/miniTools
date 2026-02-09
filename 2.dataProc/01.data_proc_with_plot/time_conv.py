#!/usr/bin/env python
#########################################################################
# File Name: time_conv.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue  9 Sep 11:16:57 2025
#########################################################################

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os

def time_to_ms(time_str):
    """
    将时间字符串转换为毫秒
    支持格式: HH:MM:SS.ms 或 HH:MM:SS
    """
    try:
        time_str = time_str.strip()
        # 分割时间部分
        time_parts = time_str.split(':')

        if len(time_parts) != 3:
            return None, f"无效格式: 需要3个部分，得到{len(time_parts)}个"

        # 提取小时和分钟
        hours = int(time_parts[0])
        minutes = int(time_parts[1])

        # 处理秒和毫秒部分
        seconds_part = time_parts[2]
        if '.' in seconds_part:
            seconds, milliseconds = seconds_part.split('.')
            seconds = int(seconds)
            # 确保毫秒部分是3位数
            milliseconds = milliseconds.ljust(3, '0')[:3]
            milliseconds = int(milliseconds)
        else:
            seconds = int(seconds_part)
            milliseconds = 0

        # 验证时间范围
        if not (0 <= hours < 24):
            return None, f"小时超出范围: {hours}"
        if not (0 <= minutes < 60):
            return None, f"分钟超出范围: {minutes}"
        if not (0 <= seconds < 60):
            return None, f"秒超出范围: {seconds}"
        if not (0 <= milliseconds < 1000):
            return None, f"毫秒超出范围: {milliseconds}"

        # 计算总毫秒数
        total_ms = (hours * 3600 + minutes * 60 + seconds) * 1000 + milliseconds
        return total_ms, None

    except ValueError as e:
        return None, f"数值转换错误: {str(e)}"
    except Exception as e:
        return None, f"处理错误: {str(e)}"

def process_time_file(input_file, output_file=None, verbose=True):
    """
    处理包含时间列的文件

    Args:
        input_file: 输入文件路径
        output_file: 输出文件路径（可选）
        verbose: 是否显示详细信息
    """
    if not os.path.exists(input_file):
        print(f"错误: 输入文件 '{input_file}' 不存在")
        return False

    successful_count = 0
    error_count = 0
    results = []

    if verbose:
        print(f"正在处理文件: {input_file}")
        print("-" * 60)

    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                original_line = line.strip()
                if not original_line or original_line.startswith('#'):
                    # 跳过空行和注释行
                    results.append("")
                    continue

                ms, error = time_to_ms(original_line)

                if error:
                    error_msg = f"第{line_num}行: {original_line} -> 错误: {error}"
                    results.append(error_msg)
                    error_count += 1
                    if verbose:
                        print(error_msg)
                else:
                    result_line = f"{original_line} -> {ms} ms"
                    results.append(result_line)
                    successful_count += 1
                    if verbose:
                        print(result_line)

    except Exception as e:
        print(f"读取文件时发生错误: {str(e)}")
        return False

    # 保存结果到输出文件
    if output_file:
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                for result in results:
                    f.write(result + '\n')
            if verbose:
                print(f"\n结果已保存到: {output_file}")
        except Exception as e:
            print(f"保存输出文件时发生错误: {str(e)}")
            return False

    # 显示统计信息
    if verbose:
        print("-" * 60)
        print(f"处理完成!")
        print(f"成功转换: {successful_count} 行")
        print(f"错误行数: {error_count} 行")
        print(f"总行数: {successful_count + error_count} 行")

    return True

def main():
    if len(sys.argv) < 2:
        print("时间转毫秒批量转换工具")
        print("用法:")
        print(f"  {sys.argv[0]} <输入文件> [输出文件]")
        print("")
        print("参数说明:")
        print("  输入文件: 包含时间列的文件，每行一个时间")
        print("  输出文件: 可选，保存转换结果的文件")
        print("")
        print("时间格式: HH:MM:SS.ms 或 HH:MM:SS")
        print("示例: 19:10:13.952, 08:45:30, 12:00:00.123")
        print("")
        print("示例:")
        print(f"  {sys.argv[0]} times.txt")
        print(f"  {sys.argv[0]} times.txt result.txt")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    success = process_time_file(input_file, output_file)

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
