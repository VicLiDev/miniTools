#!/usr/bin/env bash
#########################################################################
# File Name: 18.vcut.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 28 Nov 2024 11:25:34 AM CST
#########################################################################

# init para, def val
cmd_input=""
cmd_time_beg=""
cmd_time_end=""


usage()
{
    echo "usage: `basename $0` -i <input_strm> -b <begin_time> -e <end_time>"
    echo "time format: s|ss|m:s|mm:ss|hh:mm:ss"
}


proc_paras()
{
    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h)
                usage
                exit 0
                ;;
            -i)
                cmd_input="$2"
                shift # move to next para
                ;;
            -b)
                cmd_time_beg="$2"
                shift # move to next para
                ;;
            -e)
                cmd_time_end="$2"
                shift # move to next para
                ;;
            *)
                # unknow para
                echo "unknow para: ${key}"
                usage
                exit 1
                ;;
        esac
        shift # move to next para
    done

    [ -z "${cmd_input}" ] && { usage; exit 0; }
    [ -z "${cmd_time_beg}" ] && { usage; exit 0; }
    [ -z "${cmd_time_end}" ] && { usage; exit 0; }

    echo "cmd_input    : ${cmd_input}"
    echo "cmd_time_beg : ${cmd_time_beg}"
    echo "cmd_time_end : ${cmd_time_end}"
}


format_time()
{
    # 按冒号分割输入
    # -r 选项会禁止反斜杠转义（防止 \ 被当作转义字符）
    # -a 选项告诉 read 将输入的每个分隔出的字段放入一个数组中
    IFS=':' read -r -a time_array <<< "$1"

    # 确保每个部分（小时、分钟、秒）都有两位数字
    for i in "${!time_array[@]}"; do
        # 对每个部分进行补零，确保它至少有两位
        time_array[$i]=$(printf "%02d" "${time_array[$i]}")
    done

    # 根据数组长度来决定如何补充缺失的部分
    case ${#time_array[@]} in
        1)  # 只有一个字段，补充小时和分钟，最后是秒
            time_array=("00" "00" "${time_array[0]}")
            ;;
        2)  # 有两个字段，补充分钟和秒
            time_array=("00" "${time_array[0]}" "${time_array[1]}")
            ;;
        3)  # 已经是完整的 hh:mm:ss 格式，不需要补充
            ;;
    esac

    # 输出格式化后的时间（hh:mm:ss）
    echo "${time_array[0]}:${time_array[1]}:${time_array[2]}"
}

# # 测试
# format_time "5"        # 输出 00:00:05
# format_time "5:3"      # 输出 00:05:03
# format_time "5:3:9"    # 输出 00:03:09

split_strm()
{
    in_file="$1"
    time_beg="$2"
    time_end="$3"
    out_file="vcut${time_beg//:/_}_to_${time_end//:/_}_${in_file}"

    echo "in_file  : ${in_file}"
    echo "time_beg : ${time_beg}"
    echo "time_end : ${time_end}"
    echo "out_file : ${out_file}"

    cmd="ffmpeg -i ${in_file} -vcodec copy -ss ${time_beg} -to ${time_end} ${out_file} -y"
    echo "cmd: ${cmd}"
    ${cmd}
}

proc_paras $@
cmd_time_beg=`format_time ${cmd_time_beg}`
cmd_time_end=`format_time ${cmd_time_end}`
split_strm ${cmd_input} "${cmd_time_beg}" "${cmd_time_end}"
