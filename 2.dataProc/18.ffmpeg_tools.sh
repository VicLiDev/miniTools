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
            -h) echo "<exe> -i <in_file/dir> [-o dir, def vstrms]"; return 0; ;;
            -i) cmd_in="$2"; shift; ;;
            -o) cmd_out="$2"; shift; ;;
            *)  echo "unknow para: ${key}"; echo "<exe> -i <in_file/dir> [-o dir, def vstrms]"; return 1; ;;
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

gseq()
{
    cmd_size="640x360"
    cmd_fmt="nv12"
    cmd_spec="h264"
    cmd_time="2"
    cmd_speed="fast"
    cmd_out_prefix=""

    ffmpeg_exe=""
    ffmpeg_spec=""
    quality=""
    out_suffix=""
    out_name=""

    ffmpeg_path="${HOME}/Projects/ffmpeg/build_linux_x86/bin/ffmpeg"
    [ -e "${ffmpeg_path}" ] && { ffmpeg_exe="${ffmpeg_path}";} || { ffmpeg_exe=`which ffmpeg`;}

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -s) cmd_size="$2"; shift; ;;
            -f) cmd_fmt="$2"; shift; ;;
            -sp) cmd_spec="$2"; shift; ;;
            -t) cmd_time="$2"; shift; ;;
            --speed) cmd_speed="$2"; shift; ;;
            --out_prefix) cmd_out_prefix="$2"; shift; ;;
            -h|*) echo "<exe> [-s size] [-f fmt] [-sp spec] [-t len] [-o out] [--out_prefix pfx]";
                echo "-s  size, 640x340,1920x1080,2560×1440,3840x2160,7680×4320"
                echo "-f  Supported Pixel Formats:"
                echo "    1. YUV400 (Gray):"
                echo "       - 8bit: gray, yuv400p"
                echo "       - 10bit: gray10le, yuv400p10le"
                echo "    2. YUV411:"
                echo "       - Planar (P): yuv411p"
                echo "       - Packed: yvu411p, uyvy411"
                echo "    3. YUV420:"
                echo "       - Planar (P): yuv420p, yuv420p10le"
                echo "       - Semi-Planar (SP): nv12, p010le"
                echo "    4. YUV422:"
                echo "       - Planar (P): yuv422p, yuv422p10le"
                echo "       - Semi-Planar (SP): nv16, nv20le"
                echo "       - Packed: yuyv422, uyvy422"
                echo "    5. YUV440:"
                echo "       - Planar (P): yuv440p, yuv440p10le"
                echo "       - Semi-Planar (SP): nv24 (8bit only)"
                echo "    6. YUV444:"
                echo "       - Planar (P): yuv444p, yuv444p10le"
                echo "       - Semi-Planar (SP): nv42 (8bit only)"
                echo "       - Packed: ayuv4444, xyuv4444"
                echo "    7. RGB:"
                echo "       - 8bit: rgb24, bgr24, rgba, bgra, argb, abgr"
                echo "       - 16bit: rgb48le, bgr48le, rgba64le, bgra64le"
                echo "       - Planar: gbrp, gbrap (8bit); gbrp10le, gbrap10le (10bit)"
                echo "       - Float: rgbaf, bgra (32-bit floating point)"
                echo "    Notes:"
                echo "       - All 10bit/16bit formats use little-endian by default (append 'be' for big-endian)"
                echo "       - Formats with 'a' include alpha channel"
                echo "       - Subsampling notation:"
                echo "         * 411: 4:1:1 (horizontal only)"
                echo "         * 420: 4:2:0 (horizontal and vertical)"
                echo "         * 422: 4:2:2 (horizontal only)"
                echo "         * 440: 4:4:0 (vertical only)"
                echo "         * 444: 4:4:4 (no subsampling)"
                echo "       - SP formats: NVxx series (NV12/NV16/NV24/NV42)echo "
                echo "-sp spec, def h264/h265/avs2/vp8/vp9/av1/mpg/m2v/m4v/jpg"
                echo "-t  len, def 2, 2s"
                echo "-o  output name, def gen by paras"
                echo "--speed  fast|medium|slow, def fast"
                echo "--out_prefix output prefix"
                return 0; ;;
        esac; shift
    done

    case ${cmd_spec} in
        h264) ffmpeg_spec="libx264"; out_suffix="h264"; ;;
        h265) ffmpeg_spec="libx265"; out_suffix="h265"; ;;
        avs2) ffmpeg_spec="libxavs2"; out_suffix="avs2"; ;;
        vp8) ffmpeg_spec="libvpx"; out_suffix="ivf"; ;;
        vp9) ffmpeg_spec="libvpx-vp9"; out_suffix="ivf"; ;;
        av1) ffmpeg_spec="libaom-av1"; out_suffix="ivf"; ;;
        mpg) ffmpeg_spec="mpeg1video"; out_suffix="mpg"; ;;
        m2v) ffmpeg_spec="mpeg2video"; out_suffix="m2v"; ;;
        m4v) ffmpeg_spec="mpeg4"; out_suffix="m4v"; ;;
        jpg) ffmpeg_spec="mjpeg"; out_suffix="jpg"; ;;
        *) echo "unsupport codec in gseq tool"; return 1; ;;
    esac

    # avs2 的 quality 设置看起来没有效果
    if [ "${cmd_speed}" = "fast" ]; then
        # 快速预览 / 实时，速度最快
        [ "${cmd_spec}" = "h264" ] && quality="-preset ultrafast -crf 28"
        [ "${cmd_spec}" = "h265" ] && quality="-preset ultrafast -crf 30"
        [ "${cmd_spec}" = "vp8"  ] && quality="-deadline realtime -cpu-used 5 -crf 32 -b:v 0"
        [ "${cmd_spec}" = "vp9"  ] && quality="-deadline realtime -cpu-used 5 -crf 40 -b:v 0"
        [ "${cmd_spec}" = "av1"  ] && quality="-cpu-used 8 -crf 40 -b:v 0"
        [ "${cmd_spec}" = "avs2" ] && quality="-preset ultrafast"  # 假设支持该预设
    elif [ "${cmd_speed}" = "medium" ]; then
        # 日常发布（速度与质量折中），速度适中
        [ "${cmd_spec}" = "h264" ] && quality="-preset medium -crf 23"
        [ "${cmd_spec}" = "h265" ] && quality="-preset medium -crf 28"
        [ "${cmd_spec}" = "vp8"  ] && quality="-deadline good -cpu-used 2 -crf 28 -b:v 0"
        [ "${cmd_spec}" = "vp9"  ] && quality="-deadline good -cpu-used 2 -crf 34 -b:v 0"
        [ "${cmd_spec}" = "av1"  ] && quality="-cpu-used 4 -crf 32 -b:v 0"
        [ "${cmd_spec}" = "avs2" ] && quality="-preset medium"
    elif [ "${cmd_speed}" = "slow" ]; then
        # 高质量压缩（尽可能高压缩效率），速度最慢
        [ "${cmd_spec}" = "h264" ] && quality="-preset veryslow -crf 18"
        [ "${cmd_spec}" = "h265" ] && quality="-preset veryslow -crf 20"
        [ "${cmd_spec}" = "vp8"  ] && quality="-deadline best -cpu-used 0 -crf 20 -b:v 0"
        [ "${cmd_spec}" = "vp9"  ] && quality="-deadline best -cpu-used 0 -crf 28 -b:v 0"
        [ "${cmd_spec}" = "av1"  ] && quality="-cpu-used 0 -crf 28 -b:v 0"
        [ "${cmd_spec}" = "avs2" ] && quality="-preset slow"
    fi

    if [ -z "${cmd_out_prefix}" ]; then
        out_name="test_${cmd_spec}_${cmd_size}_${cmd_fmt}.${out_suffix}"
    else
        out_name="test_${cmd_out_prefix}_${cmd_spec}_${cmd_size}_${cmd_fmt}.${out_suffix}"
    fi

    echo "======> paras <======"
    echo "cmd_size:    ${cmd_size}"
    echo "cmd_fmt:     ${cmd_fmt}"
    echo "cmd_spec:    ${cmd_spec}"
    echo "cmd_time:    ${cmd_time}"
    echo "cmd_speed:   ${cmd_speed}"
    echo "ffmpeg_spec: ${ffmpeg_spec}"
    echo "quality:     ${quality}"
    echo "out_suffix:  ${out_suffix}"
    echo "out_name:    ${out_name}"
    echo "ffmpeg_exe:  ${ffmpeg_exe}"
    echo "out_prefix:  ${cmd_out_prefix}"
    echo "====================="

    # -f lavfi -i testsrc=size=3840x2160:rate=30 - 生成一个测试视频源，4K分辨率(3840x2160)，30fps
    # -pix_fmt yuv420p - 指定YUV420像素格式
    # -c:v libx264 - 使用H.264编码器
    # -preset slow - 使用较慢的预设以获得更好的压缩率
    # -crf 18 - 设置CRF(恒定质量)值为18(质量较高，数值越小质量越高)
    # -t 10 - 限制输出时长为10秒
    # output.h264 - 输出文件名
    # -strict unofficial 放宽标准限制
    exe_cmd=()
    if [ "${out_suffix}" = "jpg" ]; then
        exe_cmd=(
            ${ffmpeg_exe}
            -v error
            -f lavfi
            -i "testsrc=size=${cmd_size}"
            -pix_fmt "${cmd_fmt}"
            -c:v "${ffmpeg_spec}"
            -strict unofficial
            -vframes 1
            -q:v 2
            "${out_name}"
            -y
        )
    else
        exe_cmd=(
            ${ffmpeg_exe}
            -v error
            -f lavfi
            -i "testsrc=size=${cmd_size}:rate=30"
            -pix_fmt "${cmd_fmt}"
            -c:v "${ffmpeg_spec}"
            ${quality}
            -crf 18
            -t "${cmd_time}"
            "${out_name}"
            -y
        )
    fi

    echo "ffmpeg cmd:  ${exe_cmd[@]}"
    eval ${exe_cmd[@]}
    echo
}

gseqs()
{
    cmd_size="false"
    cmd_fmt="false"
    cmd_10b="false"
    cmd_all="false"

    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h) echo "<exe> [-s/-f/-a]";
                echo "-s gen size strms"
                echo "-f gen fmt strms"
                echo "-10 gen 10bit strms"
                echo "-a gen all strms"
                return 0; ;;
            -s) cmd_size="true"; ;;
            -f) cmd_fmt="true"; ;;
            -10) cmd_10b="true"; ;;
            -a) cmd_all="true"; ;;
            *)  echo "unknow para: ${key}"
                echo "<exe> [-s/-f/-a]";
                echo "-s gen size strms"
                echo "-f gen fmt strms"
                echo "-10 gen 10bit strms"
                echo "-a gen all strms"
                return 1; ;;
        esac; shift
    done

    echo "cmd_size: ${cmd_size}"
    echo "cmd_fmt:  ${cmd_fmt}"
    echo "cmd_all:  ${cmd_all}"

    # ==> size
    if [[ ${cmd_size} = "true" || ${cmd_all} = "true" ]]; then
        size_list=(
            640x360
            1920x1080
            2560x1440
            3840x2160
            7680x4320
            8192x8192
        )
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp h264 --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp h265 --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp avs2 --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp vp8  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp vp9  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp av1  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp mpg  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp m2v  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp m4v  --out_prefix size; done
        for cur_size in ${size_list[@]}; do gseq -s ${cur_size} -f nv12 -sp jpg  --out_prefix size; done
    fi

    # ==> yuv
    # YUV 格式  -pix_fmt    存储顺序              典型用途
    # YUV400    gray        YYYY...               灰度图像
    # YUV420    yuv420p     YYYY...UU...VV...     H.264/HEVC 主流格式
    # YUV422    yuv422p     YYYY...UU...VV...     专业视频编辑
    # YUV440    yuv440p     YYYY...UU...VV...     特殊垂直降采样
    # YUV411    yuv411p     YYYY...U...V...       高压缩场景
    # YUV444    yuv444p     YYYY...UUUU...VVVV... 无损/高质量编码
    if [[ ${cmd_fmt} = "true" || ${cmd_all} = "true" ]]; then
        fmt_list=(
            gray
            nv12
            yuv411p
            yuv420p
            yuv422p
            yuv440p
            yuv444p
        )
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp h264 --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp h265 --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp avs2 --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp vp8  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp vp9  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp av1  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp mpg  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp m2v  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp m4v  --out_prefix fmt; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp jpg  --out_prefix fmt; done
    fi

    # ==> 10bit
    # YUV400  gray            gray10le
    # YUV420  yuv420p nv12    yuv420p10le p010le
    # YUV422  yuv422p yuyv422 yuv422p10le y210le
    # YUV444  yuv444p         yuv444p10le y410le
    if [[ ${cmd_10b} = "true" || ${cmd_all} = "true" ]]; then
        fmt_list=(
            gray10le
            yuv420p10le
            p010le
            yuv422p10le
            y210le
            yuv444p10le
        )
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp h264 --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp h265 --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp avs2 --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp vp8  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp vp9  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp av1  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp mpg  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp m2v  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp m4v  --out_prefix 10bit; done
        for cur_fmt in ${fmt_list[@]}; do gseq -s 640x360 -f ${cur_fmt} -sp jpg  --out_prefix 10bit; done
    fi
}
