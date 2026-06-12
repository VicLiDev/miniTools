#!/usr/bin/env bash
#########################################################################
# File Name: 10.data_cut.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Tue 11 Jun 2024 09:50:04 AM CST
#########################################################################

# usage:
#   data_cut.sh -i <input_file> [-o <output_file>] [-s N] [-S N] [-c N] [-C N]
#
# options:
#   -s <N>   skip first N bytes (remove header bytes)
#   -S <N>   skip first N lines (remove header lines)
#   -c <N>   keep first N bytes (truncate to size)
#   -C <N>   keep first N lines (head)
#
# examples:
#   data_cut.sh -i data.bin -o out.bin -s 2          # remove first 2 bytes
#   data_cut.sh -i data.txt -o out.txt -S 2          # remove first 2 lines
#   data_cut.sh -i data.bin -o out.bin -c 1024       # keep first 1024 bytes
#   data_cut.sh -i data.bin -o out.bin -s 100 -c 200 # bytes 101~300

# 命令行输入变量，以 cmd_ 开头
cmd_in_file=""
cmd_out_file=""
cmd_skip_bytes=""
cmd_skip_lines=""
cmd_count_bytes=""
cmd_count_lines=""

# 终端颜色定义
RED='\033[0m\033[1;31m'
GREEN='\033[0m\033[1;32m'
YELLOW='\033[0m\033[1;33m'
NC='\033[0m'

# 判断字符串是否为无符号整数（纯数字，不允许负号、小数点等）
function is_uint()
{
    # =~ 正则匹配：^ 开头，[0-9]+ 至少1个数字，$ 结尾
    [[ "$1" =~ ^[0-9]+$ ]]
}

function usage()
{
    echo "usage: data_cut.sh -i <input_file> [-o <output_file>] [-s N] [-S N] [-c N] [-C N]"
    echo ""
    echo "options:"
    echo "  -s <N>   skip first N bytes (remove header bytes)"
    echo "  -S <N>   skip first N lines (remove header lines)"
    echo "  -c <N>   keep first N bytes (truncate to size)"
    echo "  -C <N>   keep first N lines (head)"
    echo ""
    echo "notes:"
    echo "  - -o is optional; if omitted, output writes to <input>.cropped"
    echo "  - -s and -c can be combined: skip S bytes then take C bytes"
    echo "  - -S and -C can be combined: skip S lines then take C lines"
    echo "  - byte options (-s/-c) and line options (-S/-C) cannot be mixed"
    echo ""
    echo "examples:"
    echo "  data_cut.sh -i data.bin -s 2"
    echo "  data_cut.sh -i data.txt -S 2"
    echo "  data_cut.sh -i data.bin -c 1024"
    echo "  data_cut.sh -i data.bin -s 100 -c 200"
}

# 解析命令行参数并校验合法性
function procParas()
{
    # getopts 解析选项：单个字符后跟冒号表示该选项需要参数
    # OPTARG 保存当前选项的参数值
    while getopts "i:o:s:S:c:C:" opt
    do
        case "${opt}" in
            i)  cmd_in_file=${OPTARG} ;;
            o)  cmd_out_file=${OPTARG} ;;
            s)  cmd_skip_bytes=${OPTARG} ;;
            S)  cmd_skip_lines=${OPTARG} ;;
            c)  cmd_count_bytes=${OPTARG} ;;
            C)  cmd_count_lines=${OPTARG} ;;
            *)  echo -e "${RED}unsupported option: -${opt}${NC}" >&2; usage; exit 1 ;;
        esac
    done

    # 输入文件是必须的
    [ -z "${cmd_in_file}" ] && { usage; exit 1; }

    if [ ! -e "${cmd_in_file}" ]; then
        echo -e "${RED}error: input file '${cmd_in_file}' not exist${NC}" >&2
        exit 1
    fi

    # 未指定输出文件时，默认在输入文件名后加 .cropped
    if [ -z "${cmd_out_file}" ]; then
        cmd_out_file="${cmd_in_file}.cropped"
    fi

    # 字节选项(-s/-c)和行选项(-S/-C)不能混用，因为底层实现是两条路径：
    #   字节操作用 dd，行操作用 tail/head，语义上无法同时生效
    if [[ (-n "${cmd_skip_bytes}" || -n "${cmd_count_bytes}") \
        && (-n "${cmd_skip_lines}" || -n "${cmd_count_lines}") ]]; then
        echo -e "${RED}error: byte options (-s/-c) and line options (-S/-C) cannot be mixed${NC}" >&2
        exit 1
    fi

    # 校验数值参数是否为无符号整数
    # ${!val_name} 是 bash 间接引用：val_name 的值是变量名字符串，取该变量的值
    # 例如 val_name="cmd_skip_bytes" → ${!val_name} 等价于 ${cmd_skip_bytes}
    for val_name in cmd_skip_bytes cmd_count_bytes cmd_skip_lines cmd_count_lines; do
        val="${!val_name}"
        if [[ -n "${val}" ]] && ! is_uint "${val}"; then
            echo -e "${RED}error: ${val_name} '${val}' is not a valid positive integer${NC}" >&2
            exit 1
        fi
    done

    echo -e "${GREEN}input : ${cmd_in_file}${NC}"
    echo -e "${GREEN}output: ${cmd_out_file}${NC}"
}

function main()
{
    procParas "$@"

    # 获取输入文件大小（字节）
    # Linux 用 stat -c%s，macOS/BSD 用 stat -f%z
    # 2>/dev/null 丢弃不支持该参数时的报错
    # || 依次尝试，都失败则输出 "unknown"
    in_size=$(stat -c%s "${cmd_in_file}" 2>/dev/null || stat -f%z "${cmd_in_file}" 2>/dev/null || echo "unknown")

    # ---- 字节操作（用 dd） ----
    if [[ -n "${cmd_skip_bytes}" || -n "${cmd_count_bytes}" ]]; then
        # 构造 dd 命令参数
        if [[ -n "${cmd_skip_bytes}" && -n "${cmd_count_bytes}" ]]; then
            # 同时指定 skip 和 count：跳过 skip 字节，取 count 字节
            dd_args="if=${cmd_in_file} of=${cmd_out_file} bs=1 skip=${cmd_skip_bytes} count=${cmd_count_bytes} status=none"
        elif [[ -n "${cmd_skip_bytes}" ]]; then
            # 仅 skip：尝试用较大的 bs 优化速度
            # 找到能整除 skip 值的最大 2 的幂次方作为 bs
            skip_val=${cmd_skip_bytes}
            bs=1
            for pow in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576; do
                (( skip_val % pow == 0 )) && bs=$pow || break
            done
            skip_count=$((skip_val / bs))
            if (( bs > 1 )); then
                # bs > 1 时：skip_count = skip_val / bs，效果等价于 bs=1 skip=skip_val
                dd_args="if=${cmd_in_file} of=${cmd_out_file} bs=${bs} skip=${skip_count} status=none"
                echo -e "${YELLOW}optimized: bs=${bs} skip=${skip_count} (equiv. bs=1 skip=${cmd_skip_bytes})${NC}"
            else
                dd_args="if=${cmd_in_file} of=${cmd_out_file} bs=1 skip=${cmd_skip_bytes} status=none"
            fi
        else
            # 仅 count：保留前 count 字节
            dd_args="if=${cmd_in_file} of=${cmd_out_file} bs=1 count=${cmd_count_bytes} status=none"
        fi

        echo -e "${YELLOW}cmd: dd ${dd_args}${NC}"
        eval dd ${dd_args}
        if [ $? -eq 0 ]; then
            # 获取输出文件大小，打印处理前后的字节数对比
            out_size=$(stat -c%s "${cmd_out_file}" 2>/dev/null || stat -f%z "${cmd_out_file}" 2>/dev/null || echo "?")
            echo -e "${GREEN}done: ${in_size} -> ${out_size} bytes${NC}"
        else
            echo -e "${RED}dd command failed${NC}" >&2
            exit 1
        fi

        return 0
    fi

    # ---- 行操作（用 tail / head） ----
    if [[ -n "${cmd_skip_lines}" || -n "${cmd_count_lines}" ]]; then
        if [[ -n "${cmd_skip_lines}" && -n "${cmd_count_lines}" ]]; then
            # 跳过前 N 行，再取 M 行
            # tail -n +K 表示从第 K 行开始输出（含第 K 行）
            cmd="tail -n +$((cmd_skip_lines + 1)) \"${cmd_in_file}\" | head -n ${cmd_count_lines} > \"${cmd_out_file}\""
        elif [[ -n "${cmd_skip_lines}" ]]; then
            # 仅跳过前 N 行
            cmd="tail -n +$((cmd_skip_lines + 1)) \"${cmd_in_file}\" > \"${cmd_out_file}\""
        else
            # 仅保留前 N 行
            cmd="head -n ${cmd_count_lines} \"${cmd_in_file}\" > \"${cmd_out_file}\""
        fi

        echo -e "${YELLOW}cmd: ${cmd}${NC}"
        eval "${cmd}"
        if [ $? -eq 0 ]; then
            # 打印处理前后的行数对比
            in_lines=$(wc -l < "${cmd_in_file}")
            out_lines=$(wc -l < "${cmd_out_file}")
            echo -e "${GREEN}done: ${in_lines} -> ${out_lines} lines${NC}"
        else
            echo -e "${RED}command failed${NC}" >&2
            exit 1
        fi

        return 0
    fi

    # 未指定任何裁剪操作
    echo -e "${RED}error: no operation specified, use -s/-S/-c/-C${NC}" >&2
    usage
    exit 1
}

main "$@"
