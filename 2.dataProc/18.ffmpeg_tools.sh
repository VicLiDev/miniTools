#!/usr/bin/env bash
#########################################################################
# File Name: 18.vcut.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 28 Nov 2024 11:25:34 AM CST
#########################################################################

# add to bashrc:
# source ${HOME}/Projects/miniTools/2.dataProc/18.ffmpeg_tools.sh

format_time()
{
    local str="$1"
    local h=0 m=0 s=0

    # 计算冒号数量
    local count=$(grep -o ":" <<< "$str" | wc -l)

    if [[ $count -eq 0 ]]; then
        # 只有秒
        s="$str"
    elif [[ $count -eq 1 ]]; then
        # 分钟:秒
        m="${str%:*}"  # 取冒号前部分
        s="${str#*:}"  # 取冒号后部分
    elif [[ $count -eq 2 ]]; then
        # 小时:分钟:秒
        h="${str%%:*}"         # 取第一个冒号前部分
        str="${str#*:}"        # 去掉第一个冒号及之前部分
        m="${str%:*}"          # 取第二个冒号前部分
        s="${str##*:}"         # 取第二个冒号后部分
    else
        echo "Invalid input"
        return 1
    fi

    # 格式化输出
    printf "%02d:%02d:%02d\n" "$h" "$m" "$s"
}

# # 测试
# format_time "5"        # 输出 00:00:05
# format_time "5:3"      # 输出 00:05:03
# format_time "5:3:9"    # 输出 00:03:09

vcut()
{
    # init para, def val
    cmd_input=""
    cmd_time_beg=""
    cmd_time_end=""
    out_file=""

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h) echo "usage: <exe> -i <input_strm> -b <begin_time> -e <end_time>"
                echo "time format: s|ss|m:s|mm:ss|hh:mm:ss"
                return 0; ;;
            -i) cmd_input="$2"; shift; ;;
            -b) cmd_time_beg="$2"; shift; ;;
            -e) cmd_time_end="$2"; shift; ;;
            *)  echo "unknow para: ${key}"
                echo "usage: <exe> -i <input_strm> -b <begin_time> -e <end_time>"
                echo "time format: s|ss|m:s|mm:ss|hh:mm:ss"
                return 1; ;;
        esac; shift
    done

    [ -z "${cmd_input}" ] && { vcut_usage; return 0; }
    [ -z "${cmd_time_beg}" ] && { vcut_usage; return 0; }
    [ -z "${cmd_time_end}" ] && { vcut_usage; return 0; }

    echo "cmd_input    : ${cmd_input}"
    echo "cmd_time_beg : ${cmd_time_beg}"
    echo "cmd_time_end : ${cmd_time_end}"

    cmd_time_beg=`format_time ${cmd_time_beg}`
    cmd_time_end=`format_time ${cmd_time_end}`

    # split_strm
    out_file="vcut${cmd_time_beg//:/_}_to_${cmd_time_end//:/_}_`basename ${cmd_input}`"

    echo "fmt_time_beg : ${cmd_time_beg}"
    echo "fmt_time_end : ${cmd_time_end}"
    echo "out_file : ${out_file}"
    echo

    cmd="ffmpeg -v error -i ${cmd_input} -vcodec copy -ss ${cmd_time_beg} -to ${cmd_time_end} ${out_file} -y"
    echo "cmd: ${cmd}"
    eval ${cmd}
}

extBstrms()
{
    # init para, def val
    cmd_in="./" # file/dir
    cmd_out="vstrms" # dir

    output_name=""
    codec=""
    suffix=""

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h) echo "<exe> -i <in_file/dir> [-o dir]"; return 0; ;;
            -i) cmd_in="$2"; shift; ;;
            -o) cmd_out="$2"; shift; ;;
            *)  echo "unknow para: ${key}"; echo "<exe> -i <in_file/dir> [-o dir]"; return 1; ;;
        esac; shift
    done

    echo "cmd_in:  ${cmd_in}"
    echo "cmd_out: ${cmd_out}"

    # create dir
    [ ! -d ${cmd_out} ] && echo "create dir $1"; mkdir -p ${cmd_out}

    for file in `find ${cmd_in} -type f`
    do
        echo "==> cur file: ${file}"
        # -v error 代表 日志级别只显示错误信息，忽略警告和信息日志，避免无关的日志输出。
        # -show_streams 让 ffprobe 显示文件中的所有流信息（视频流、音频流、字幕流等）。
        # 如果 file 是一个有效的媒体文件，它应该至少包含一个流。
        # 2>&1：stderr 重定向到 stdout，然后 stdout 被重定向到 /dev/null，丢弃所有输出。
        # 这样无论 ffprobe 输出什么，终端都不会看到。
        # 这条命令本身不会输出任何内容，但它的 返回值（$?） 可用于判断文件是否有效：
        ffprobe -v error -show_streams "${file}" > /dev/null 2>&1
        if [ $? -ne 0 ]; then echo "cur file is not video sequence"; continue; fi

        # -select_streams v:0  选择 视频流（v 表示视频）
        # v:0 选择 第一个视频流（如果文件有多个视频流，v:1 表示第二个视频流，依此类推）
        #
        # -show_entries 选择要输出的信息 stream=codec_name 只提取视频流的编码格式（h264/hevc/av1）
        #
        # -of 设定输出格式（output format）csv=p=0 让 ffprobe 只输出 纯文本格式的
        # 编码名称，不带任何额外信息。
        #     csv：以 逗号分隔格式（这里只返回一个值，所以不会有逗号）。
        #     p=0：不打印字段名称，只输出值。
        codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "${file}")
        case ${codec} in
            h264) suffix="h264"; ;;
            h265|hevc) suffix="h265"; ;;
            vp8|vp9|av1) suffix="ivf"; ;;
            mpeg2video|mpeg2video,) suffix="m2v"; ;;
            mpeg4) suffix="m4v"; ;;
            avs2) suffix="avs2"; ;;
            *) echo "unknow format: ${codec}"; continue; ;;
        esac

        output_name=`basename ${file}`
        output_name="${output_name%.*}.${suffix}"
        cmd="ffmpeg -v error -i ${file} -vcodec copy ${cmd_out}/${output_name}"
        echo "cmd: ${cmd}"
        eval ${cmd}
        [ $? -ne 0 ] && echo "error proc file: ${file}"
    done
}
