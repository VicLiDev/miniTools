#!/usr/bin/env bash
#########################################################################
# File Name: sw_codec.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 06 May 2025 05:27:16 PM CST
#########################################################################

adb_cmd=""
use_dev="true"
cpu_cnt=0
cpu_en=()
cpu_freq=()
dec_test_cnt=0
enc_test_cnt=0
test_grp_id=0

dev_wk_dir="/sdcard"

data_bakup_dir="eval_data_bakup"
in_eval_info="in_eval_info.txt"
out_eval_info="${data_bakup_dir}/out_eval_info_`date +%Y_%m%d_%H%M%S`.txt"
out_eval_data="out_eval_data.txt"

select_cpu_core()
{
    adb_shell=""
    [ "${use_dev}" == "true" ] && adb_shell="${adb_cmd} shell"

    echo
    echo "======> select cpu core <======"

    # cpu_cnt=`${adb_cmd} shell cat /proc/cpuinfo | grep "^processor" | wc -l`
    if [ ${use_dev} == "true" ]; then
        cpu_cnt=`${adb_cmd} shell "ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$' | wc -l"`
    else
        cpu_cnt=`ls /sys/devices/system/cpu/ | grep -E '^cpu[0-9]+$' | wc -l`
    fi

    [ ${use_dev} == "true" ] && echo "adb cmd: ${adb_cmd}"
    echo "cpu cnt: ${cpu_cnt}"

    def_core_en_val=$(printf '1%.0s' $(seq 1 ${cpu_cnt}))

    read -p "enable cpu core? [ex: 1010, def:${def_core_en_val}] or quit(q):" ret
    [ "${ret}" == "q" ] && exit 0;
    # 去掉空格
    ret="`echo ${ret} | tr -d ' '`"
    [ -z ${ret} ] && ret="${def_core_en_val}"
    [ "${#ret}" -ne "${cpu_cnt}" ] && { echo "err: input cnt ${#ret} != cpu core count"; return -1; }
    for i in $(seq 0 $((${cpu_cnt} - 1)))
    do
        # echo "val: ${ret:${i}:1}"
        [ "${ret:${i}:1}" != "1" ] && [ "${ret:${i}:1}" != "0" ] && { echo "err: Please input 0/1"; return -1; }
        cpu_en[${i}]=${ret:${i}:1}
    done

    echo "cpu core enable info: ${cpu_en[@]}"
    for i in $(seq 0 $((${#cpu_en[@]} - 1)))
    do
        if [ "${use_dev}" == "true" ]; then
            ${adb_cmd} shell "echo ${cpu_en[${i}]} > /sys/devices/system/cpu/cpu${i}/online"
        fi
        
    done

    echo "==> online setup result:"
    for i in $(seq 0 $((${#cpu_en[@]} - 1)))
    do
        if [ "${use_dev}" == "true" ]; then
            cur_cmd="${adb_cmd} shell \"cat /sys/devices/system/cpu/cpu${i}/online\""
        else
            cur_cmd="cat /sys/devices/system/cpu/cpu${i}/online"
        fi
        cur_online=`eval ${cur_cmd}`
        echo "cur core id ${i}, online: ${cur_online}"
    done

    echo
    if [ "${use_dev}" == "true" ]; then
        echo "======> select cpu freq <======"
        for i in $(seq 0 $((${cpu_cnt} - 1)))
        do
            # get support freq
            echo "--> cur core id ${i}:"
            echo "support core freq:"
            cur_cmd="${adb_shell} \"cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_available_frequencies\""
            eval ${cur_cmd}

            # get cur core freq
            cur_cmd="${adb_shell} \"cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq\""
            cur_freq=`eval ${cur_cmd}`
            echo "cur freq: ${cur_freq}"

            # get user set freq
            read -p "set cur freq, def[${cur_freq}]: " set_freq
            [ "${set_freq}" == "q" ] && exit 0;
            [ -z "${set_freq}" ] && set_freq=${cur_freq}
            echo "selected freq: ${set_freq}"

            # set core freq
            cur_cmd="${adb_shell} \"echo userspace > /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor\""
            cur_cpu_freq_mode=`eval ${cur_cmd}`
            # cur_cmd="${adb_shell} \"cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor\""
            # cur_cpu_freq_mode=`eval ${cur_cmd}`
            # echo "cur_core id ${i}, core freq mode: ${cur_cpu_freq_mode}"
            cur_cmd="${adb_shell} \"echo ${set_freq} > /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_setspeed\""
            eval ${cur_cmd}
        done
    fi
    echo "==> cpu core freq setup result:"
    for i in $(seq 0 $((${cpu_cnt} - 1)))
    do
        # get user set freq
        if [ "${use_dev}" == "true" ]; then
            cur_cmd="${adb_shell} \"cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq\""
        else
            cur_cmd="cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_cur_freq"
        fi
        cur_freq=`eval ${cur_cmd}`
        cpu_freq[${i}]=${cur_freq}
        echo "cur core id ${i}, freq: ${cur_freq}"
    done
}

analyze_info()
{
    ffmpeg_log="$1"
    codec_type="$2"
    in_file="$3"

    # 拆分成多个段落，分别保存到变量
    input_blk=$(echo "${ffmpeg_log}" | awk -v kw="Input" 'index($0, kw) == 1 {flag=1} $1 != kw && /^[^[:space:]]/ {flag=0} flag')
    map_blk=$(echo "${ffmpeg_log}" | awk -v kw="Stream" 'index($0, kw) == 1 {flag=1} $1 != kw && /^[^[:space:]]/ {flag=0} flag')
    output_blk=$(echo "${ffmpeg_log}" | awk -v kw="Output" 'index($0, kw) == 1 {flag=1} $1 != kw && /^[^[:space:]]/ {flag=0} flag')
    # frame= 会刷新，所以这里log会有点混乱，取最后一行即可
    frame_line=$(echo "${ffmpeg_log}" | grep "frame.*bitrate.*speed" | tail -n 1)
    bench_lines=$(echo "${ffmpeg_log}" | grep '^bench:')

    # 使用 grep -P 支持 Perl 正则
    # \K 丢弃前面匹配的部分
    # \S+ 匹配非空白字符，但它会匹配到逗号，改用 [^,\s]+ 明确排除逗号和空格
    # head -1 只取第一个匹配
    in_spec=$(grep -oP 'Video:\s*\K[^,\s]+' <<< "${input_blk}" | head -1)
    # -o 只输出匹配的部分
    # -E 使用扩展正则表达式
    in_color=$(grep -oEm1 '(yuv|yuvj|nv)[0-9]+[a-z]?' <<< "${input_blk}")
    in_fps=`echo ${input_blk%fps,*} | awk '{print $NF}'`
    # -m1表示只取第一个匹配
    in_size=$(grep -oEm1 '[1-9][0-9]*x[1-9][0-9]*' <<< "${input_blk}")

    out_spec=$(grep -oP 'Video:\s*\K[^,\s]+' <<< "${output_blk}" | head -1)
    out_color=$(grep -oEm1 '(yuv|yuvj|nv)[0-9]+[a-z]?' <<< "${output_blk}")
    # 先匹配 "数字 fps" 格式
    # 再提取纯数字部分
    out_fps=$(grep -oP '\d+(\.\d+)?\s*fps' <<< "${output_blk}" | grep -oE '[0-9.]+' | head -1)
    # head -1 确保只获取第一个匹配结果
    out_size=$(grep -oEm1 '[1-9][0-9]*x[1-9][0-9]*' <<< "${output_blk}" | head -1)

    frames=`eval echo ${frame_line} | grep -oP 'frame=\s*\K\d+' | tail -n 1`
    rtime=`echo ${bench_lines#*rtime=} | awk -F"s" '{print $1}'`
    [ "${codec_type}" == "enc" ] && bitrate=`eval echo ${frame_line#*bitrate=} | awk '{print $1}'`
    [ "${codec_type}" == "dec" ] && bitrate=`eval echo ${input_blk#*bitrate:} | awk '{print $1}'`

    # check
    if [[ "`echo ${codec_type} | wc -w`" != 1 ]] ||
        [[ "`echo ${in_spec} | wc -w`" != 1 ]] ||
        [[ "`echo ${in_color} | wc -w`" != 1 ]] ||
        [[ "`echo ${in_fps} | wc -w`" != 1 ]] ||
        [[ "`echo ${in_size} | wc -w`" != 1 ]] ||
        [[ "`echo ${out_spec} | wc -w`" != 1 ]] ||
        [[ "`echo ${out_color} | wc -w`" != 1 ]] ||
        [[ "`echo ${out_fps} | wc -w`" != 1 ]] ||
        [[ "`echo ${out_size} | wc -w`" != 1 ]] ||
        [[ "`echo ${frames} | wc -w`" != 1 ]] ||
        [[ "`echo ${bitrate} | wc -w`" != 1 ]] ||
        [[ "`echo ${rtime} | wc -w`" != 1 ]] ||
        [[ "`echo ${in_file} | wc -w`" != 1 ]]; then
        echo "-- ffmpeg log"; echo "${ffmpeg_log}"
        echo "-- intput";     echo ${input_blk}
        echo "-- map";        echo ${map_blk}
        echo "-- outtput";    echo ${output_blk}
        echo "-- frame";      echo ${frame_line}
        echo "-- bench";      echo ${bench_lines}
        echo "==> in   <in_spec>:${in_spec}   <color>:${in_color}  <fps>:${in_fps}  <size>:${in_size}"
        echo "==> out  <out_spec>:${out_spec}  <color>:${out_color}  <fps>:${out_fps}  <size>:${out_size}"
        echo "==> gen  <bitrate>:${bitrate}  <frame>:${frames}  <rtime>:${rtime}s  <frame/s>:${frames}/${rtime}"
    fi
    [ "`echo ${codec_type} | wc -w`" != 1 ] && { echo "val: $codec_type} --> set to None"; codec_type="None"; }
    [ "`echo ${in_spec} | wc -w`"    != 1 ] && { echo "val: $in_spec} --> set to None";    in_spec="None"   ; }
    [ "`echo ${in_color} | wc -w`"   != 1 ] && { echo "val: $in_color} --> set to None";   in_color="None"  ; }
    [ "`echo ${in_fps} | wc -w`"     != 1 ] && { echo "val: $in_fps} --> set to None";     in_fps="None"    ; }
    [ "`echo ${in_size} | wc -w`"    != 1 ] && { echo "val: $in_size} --> set to None";    in_size="None"   ; }
    [ "`echo ${out_spec} | wc -w`"   != 1 ] && { echo "val: $out_spec} --> set to None";   out_spec="None"  ; }
    [ "`echo ${out_color} | wc -w`"  != 1 ] && { echo "val: $out_color} --> set to None";  out_color="None" ; }
    [ "`echo ${out_fps} | wc -w`"    != 1 ] && { echo "val: $out_fps} --> set to None";    out_fps="None"   ; }
    [ "`echo ${out_size} | wc -w`"   != 1 ] && { echo "val: $out_size} --> set to None";   out_size="None"  ; }
    [ "`echo ${frames} | wc -w`"     != 1 ] && { echo "val: $frames} --> set to None";     frames="None"    ; }
    [ "`echo ${bitrate} | wc -w`"    != 1 ] && { echo "val: $bitrate} --> set to None";    bitrate="None"   ; }
    [ "`echo ${rtime} | wc -w`"      != 1 ] && { echo "val: $rtime} --> set to None";      rtime="None"     ; }
    [ "`echo ${in_file} | wc -w`"    != 1 ] && { echo "val: $in_file} --> set to None";    in_file="None"   ; }

    if [[ "${codec_type}" == "dec" ]] && [[ ${dec_test_cnt} -eq 0 ]] || \
        [[ "${codec_type}" == "enc" ]] && [[ ${enc_test_cnt} -eq 0 ]]; then
        echo '==> result'
        echo "grp ${test_grp_id}" | tee -a ${out_eval_info}
        for i in $(seq 0 $((${cpu_cnt} - 1)))
        do
            echo "core id:${i} en:${cpu_en[${i}]} freq:${cpu_freq[${i}]}" | tee -a ${out_eval_info}
        done
        printf "%-8s %-10s %-10s %-10s %-8s %-8s %-6s %-14s %-10s %-15s %-20s\n" \
            "testType" "in_spec" "out_spec" "size" "frameCnt" "color" "fps" "bitrate(kb/s)" "rtime" "frame/s" "source" | tee -a ${out_eval_info}
    fi
    printf "%-8s %-10s %-10s %-10s %-8s %-8s %-6s %-14s %-10s %-15s %-20s\n" \
        ${codec_type} ${in_spec} ${out_spec} ${in_size} ${frames} ${in_color} ${in_fps} ${bitrate} ${rtime} ${frames}/${rtime} ${in_file} | tee -a ${out_eval_info}

}

dec_test()
{
    test_info="$1"

    cur_cfg=(${test_info})

    test_type="${cur_cfg[0]}"
    strm_file="${cur_cfg[1]}"

    [ ${use_dev} == "true" ] && ${adb_cmd} push ${strm_file} ${dev_wk_dir}

    #指定输出格式的话时间会稍长一点，不指定稍短一点，这里按照长的时间测试
    if [ "${use_dev}" == "true" ]; then
        dec_cmd="${adb_cmd} shell ffmpeg -benchmark -i ${dev_wk_dir}/`basename ${strm_file}` \
            -threads 0 -an -f null -"
    else
        dec_cmd="ffmpeg -benchmark -i ${strm_file} -threads 0 -an -f null -"
    fi
    # echo "ffmpeg cmd:${dec_cmd}"
    # 去掉 Input 之前的内容，awk拆分的用法可以查看 LearnC 中的文档
    # 指定输入 < /dev/null 避免 ffmpeg 读取标准输入的数据，不然会干扰输入文件的读取
    ffmpegLog=$(${dec_cmd} < /dev/null 2>&1 | awk '/^Input/ {flag=1} flag')

    analyze_info "${ffmpegLog}" "${test_type}" "${strm_file}"

    [ ${use_dev} == "true" ] && ${adb_cmd} shell "rm ${dev_wk_dir}/`basename ${strm_file}`"

    dec_test_cnt=`expr ${dec_test_cnt} + 1`
}

enc_test()
{
    test_info="$1"

    cur_cfg=(${test_info})

    test_type="${cur_cfg[0]}"
    pix_fmt="${cur_cfg[1]}"
    yuv_size="${cur_cfg[2]}"
    ff_encoder="${cur_cfg[3]}"
    speed="${cur_cfg[4]}"
    yuv_file="${cur_cfg[5]}"

    # echo "fmt:${pix_fmt} size:${yuv_size} encoder:${ff_encoder} yuv_path:${yuv_file}"

    [ ${use_dev} == "true" ] && ${adb_cmd} push ${yuv_file} ${dev_wk_dir}


# 编码协议 × 应用场景 对照表（纵向协议）
#
# | 协议/场景 | 快速预览 / 实时                | 日常发布                   | 高质量压缩                 | 恒定质量控制      | 固定比特率     |
# | --------- | ------------------------------ | -------------------------- | -------------------------- | ----------------- | -------------- |
# | x264      | -preset ultrafast              | -preset medium             | -preset veryslow           | -crf 18~28        | -b:v 2M        |
# | x265      | -preset ultrafast              | -preset medium             | -preset veryslow           | -crf 20~28        | -b:v 2M        |
# | VP8       | -deadline realtime -cpu-used 5 | -deadline good -cpu-used 2 | -deadline best -cpu-used 0 | -crf 10~32 -b:v 0 | -b:v 2M        |
# | VP9       | -deadline realtime -cpu-used 5 | -deadline good -cpu-used 2 | -deadline best -cpu-used 0 | -crf 30~40 -b:v 0 | -b:v 2M        |
# | AV1       | -cpu-used 8                    | -cpu-used 4                | -cpu-used 0                | -crf 20~40 -b:v 0 | -b:v 2M        |
# | AVS2*     | 实时支持有限                   | -preset medium （如支持）  | -preset slow （如支持）    | -crf（如实现支持）| -b:v(有限支持) |

# 说明：
# * CRF（Constant Rate Factor）：
#   * 所有现代编码器几乎都支持，推荐使用。
#   * 越小画质越好，文件越大。
# * Preset（预设）：
#   * 控制压缩“速度 vs 效率”的权衡。`ultrafast` → `veryslow` 表示从快到慢。
# * Deadline / CPU-used：
#   * 仅适用于 VP8 / VP9 / AV1（部分），不是所有编码器通用。
# * AVS2：
#   * 是中国主导的编解码标准，开源实现较少（如 `openavs2`），支持有限，不一定有成熟的 `ffmpeg` 支持。

# 推荐配置示例：
# YouTube 上传（高压缩质量）
# ```bash
# ffmpeg -i input.mp4 -c:v libx265 -preset slow -crf 22 -c:a aac output.mp4
# ```
# 实时直播推流（低延迟）
# ```bash
# ffmpeg -i input.mp4 -c:v libvpx -deadline realtime -cpu-used 5 -b:v 2M -c:a libopus output.webm
# ```
#高清存档（尽可能小的文件高画质）
# ```bash
# ffmpeg -i input.mp4 -c:v libaom-av1 -crf 28 -cpu-used 0 -c:a libopus output.webm
# ```

    # avs2 的 quality 设置看起来没有效果
    if [ "${speed}" == "fast" ]; then
        # 快速预览 / 实时，速度最快
        [ "${ff_encoder}" == "libx264"    ] && quality="-preset ultrafast -crf 28"
        [ "${ff_encoder}" == "libx265"    ] && quality="-preset ultrafast -crf 30"
        [ "${ff_encoder}" == "libvpx"     ] && quality="-deadline realtime -cpu-used 5 -crf 32 -b:v 0"
        [ "${ff_encoder}" == "libvpx-vp9" ] && quality="-deadline realtime -cpu-used 5 -crf 40 -b:v 0"
        [ "${ff_encoder}" == "libaom-av1" ] && quality="-cpu-used 8 -crf 40 -b:v 0"
        [ "${ff_encoder}" == "libxavs2"   ] && quality="-preset ultrafast"  # 假设支持该预设
    elif [ "${speed}" == "medium" ]; then
        # 日常发布（速度与质量折中），速度适中
        [ "${ff_encoder}" == "libx264"    ] && quality="-preset medium -crf 23"
        [ "${ff_encoder}" == "libx265"    ] && quality="-preset medium -crf 28"
        [ "${ff_encoder}" == "libvpx"     ] && quality="-deadline good -cpu-used 2 -crf 28 -b:v 0"
        [ "${ff_encoder}" == "libvpx-vp9" ] && quality="-deadline good -cpu-used 2 -crf 34 -b:v 0"
        [ "${ff_encoder}" == "libaom-av1" ] && quality="-cpu-used 4 -crf 32 -b:v 0"
        [ "${ff_encoder}" == "libxavs2"   ] && quality="-preset medium"
    elif [ "${speed}" == "slow" ]; then
        # 高质量压缩（尽可能高压缩效率），速度最慢
        [ "${ff_encoder}" == "libx264"    ] && quality="-preset veryslow -crf 18"
        [ "${ff_encoder}" == "libx265"    ] && quality="-preset veryslow -crf 20"
        [ "${ff_encoder}" == "libvpx"     ] && quality="-deadline best -cpu-used 0 -crf 20 -b:v 0"
        [ "${ff_encoder}" == "libvpx-vp9" ] && quality="-deadline best -cpu-used 0 -crf 28 -b:v 0"
        [ "${ff_encoder}" == "libaom-av1" ] && quality="-cpu-used 0 -crf 28 -b:v 0"
        [ "${ff_encoder}" == "libxavs2"   ] && quality="-preset slow"
    fi


    if [ "${use_dev}" == "true" ]; then
        enc_cmd="${adb_cmd} shell ffmpeg -benchmark -f rawvideo -pix_fmt ${pix_fmt} \
            -s:v ${yuv_size} -r 25 -i ${dev_wk_dir}/`basename ${yuv_file}` \
            -c:v ${ff_encoder} -threads 0 ${quality} -f null -"
    else
        enc_cmd="ffmpeg -benchmark -f rawvideo -pix_fmt ${pix_fmt} \
            -s:v ${yuv_size} -r 25 -i ${yuv_file} -c:v ${ff_encoder} -threads 0 \
            ${quality} -f null -"
    fi
    # echo "ffmpeg cmd: ${enc_cmd}"
    # 去掉 Input 之前的内容，awk拆分的用法可以查看 LearnC 中的文档
    # 指定输入 < /dev/null 避免 ffmpeg 读取标准输入的数据，不然会干扰输入文件的读取
    ffmpegLog=$(${enc_cmd} < /dev/null 2>&1 | awk '/^Input/ {flag=1} flag')

    analyze_info "${ffmpegLog}" "${test_type}" "${yuv_file}"

    [ ${use_dev} == "true" ] && ${adb_cmd} shell "rm ${dev_wk_dir}/`basename ${yuv_file}`"

    enc_test_cnt=`expr ${enc_test_cnt} + 1`
}

enc_dec_test()
{
    echo

    lines=()
    idx=0

    # IFS= 防止行首/行尾空格被截断。
    # -r 禁止反斜杠转义（如 \n 不会被解释为换行）。
    while IFS= read -r line
    do
        [ -z "${line}" ] && continue
        [ "${line[0]:0:1}" == "#" ] && continue

        lines[${idx}]="${line}"
        idx=`expr ${idx} + 1`
    done < ${in_eval_info}

    for cur_line in "${lines[@]}"
    do
        # echo "cur dec cfg: ${cur_line}"
        cur_cfg=(${cur_line})

        if [ "${cur_cfg[0]}" == "enc" ]; then
            enc_test "${cur_line}"
        elif [ "${cur_cfg[0]}" == "dec" ]; then
            dec_test "${cur_line}"
        fi
    done
}

main()
{
    # use_dev="false"

    [ ${use_dev} == "true" ] && adb_cmd=`adbs`
    cur_exe_dir=`dirname $(readlink -f $0)`
    test_grp_id=0

    [ ! -d "${data_bakup_dir}" ] && mkdir ${data_bakup_dir}

    while true
    do
        dec_test_cnt=0
        enc_test_cnt=0

        select_cpu_core

        enc_dec_test

        test_grp_id=`expr ${test_grp_id} + 1`

        # update to data file, to gen excel doc
        cp ${out_eval_info} ${out_eval_data}
    done
}

main $@
