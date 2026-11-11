#!/usr/bin/env bash
#########################################################################
# File Name: 06.mpp.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 11 Nov 2026
#########################################################################

# mpi_dec_test / mpi_enc_test 公共逻辑:
#   编码类型映射 / 命令拼装 / fps 日志解析
#
# 只做与 MPP 测试工具相关的事, 不碰 adb 设备管理 (见 _adb_dev_op.sh)

if ! declare -F adev_quote >/dev/null 2>&1; then
    source "${HOME}/bin/_adb_dev_op.sh"
fi

# 编码名 -> mpi_dec_test / mpi_enc_test -t 数值
function mpp_codec_token()
{
    case "${1,,}" in
        h264|avc)         echo 7 ;;
        h265|hevc)        echo 16777220 ;;
        vp9)              echo 10 ;;
        av1)              echo 16777224 ;;
        avs2)             echo 16777223 ;;
        avs)              echo 6 ;;
        mpeg2|mpeg2video) echo 2 ;;
        mpeg4)            echo 4 ;;
        vp8)              echo 9 ;;
        mjpeg|jpeg)       echo 8 ;;
    esac
}

# 拼装设备端测试命令: oom 保护 + cd + exe + args, 可选 timeout 包裹
#   _mpp_exec_cmd <exe> <workdir> <timeout> <args...>
#   oom_score_adj=1000: 大码流被 OOM 时杀测试进程而不是 adbd
function _mpp_exec_cmd()
{
    local exe="$1" workdir="$2" tmo="$3" envs="$4"
    local cmd

    shift 4
    cmd="echo 1000 > /proc/self/oom_score_adj 2>/dev/null;"
    cmd+="cd $(adev_quote "${workdir}") && "
    [ -n "${envs}" ] && cmd+="${envs} "
    cmd+="$(adev_quote "${exe}")"
    [ $# -gt 0 ] && cmd+=" $*"
    [ -n "${tmo}" ] && cmd="timeout ${tmo} sh -c $(adev_quote "${cmd}")"
    printf '%s' "${cmd}"
}

# 解码命令
#   mpp_dec_cmd <exe> <workdir> <input> <ctype> [frames] [extra] [timeout]
function mpp_dec_cmd()
{
    local exe="$1" workdir="$2" input="$3" ctype="$4"
    local frames="${5:-}" extra="${6:-}" tmo="${7:-}" envs="${8:-}"
    local args="-i $(adev_quote "${input}") -t ${ctype}"

    [ -n "${frames}" ] && args+=" -n ${frames}"
    [ -n "${extra}" ] && args+=" ${extra}"
    _mpp_exec_cmd "${exe}" "${workdir}" "${tmo}" \
        "${envs}" "${args}"
}

# 编码命令
#   mpp_enc_cmd <exe> <workdir> <input> <output> <w> <h> <ctype> [extra] [timeout]
function mpp_enc_cmd()
{
    local exe="$1" workdir="$2" input="$3" output="${4:-}" w="$5" h="$6" ctype="$7"
    local extra="${8:-}" tmo="${9:-}"
    local args="-i $(adev_quote "${input}")"

    # -o 可选: 不给输出文件时只跑编码不落盘 (mpi_enc_test 支持)
    [ -n "${output}" ] && args+=" -o $(adev_quote "${output}")"
    args+=" -w ${w} -h ${h} -t ${ctype}"

    [ -n "${extra}" ] && args+=" ${extra}"
    _mpp_exec_cmd "${exe}" "${workdir}" "${tmo}" "" "${args}"
}

# 解析 mpi_dec_test / mpi_enc_test 日志, 输出 "max min avg frames time"
#
# 输入: 多个日志文件 (stdout + logcat), awk 按顺序连续读取.
# 输出: mpp_max/mpp_min/mpp_avg/mpp_frames/mpp_time (缺失为 "-").
# LC_ALL=C: 固定 ASCII 空白/小数点/正则行为, 避免不同 locale 下解析不一致.
# 具体匹配规则见函数内注释.
function mpp_fps_parse()
{
    local out

    mpp_max=""; mpp_min=""; mpp_avg=""; mpp_frames="-"; mpp_time="-"
    out=$(LC_ALL=C awk '
        # BEGIN 在读取任何输入前执行一次: 汇总行的默认值
        BEGIN { frames = "-"; tms = "-" }

        # 规则1: 每秒采样行, 例如
        #   decoded 82 frame fps avg 79.98 ins 79.98
        # 同时匹配 "fps avg" 和 " ins ", 避开只有汇总 fps 的结束行
        /fps[ \t]+avg/ && /[ \t]ins[ \t]/ {
            for (i = 1; i <= NF; i++) {         # NF: 当前行字段数
                if ($i != "ins") continue       # 只找 ins 这个字段
                v = $(i + 1) + 0                # 下一个字段转成数字
                if (v <= 0) continue            # 0/空/非数字一律丢弃
                if (cnt == 0 || v > mx) mx = v  # 第一个样本直接初始化
                if (cnt == 0 || v < mn) mn = v  # 避免 min 被 0 污染
                cnt++                           # 有效样本计数
            }
        }

        # 规则2: 结束汇总行, 例如
        #   decode 4402 frames time 52705 ms delay 40 ms fps 83.52
        #   encode 300 frames time 2500 ms delay 0 ms fps 120.00
        /(decode|encode)[ \t]+[0-9]+[ \t]+frames[ \t]+time/ {
            line = $0
            # 去掉日志前缀 (如 "mpp[1558]: mpi_dec_test: ")
            # .* 贪婪匹配, 会保留最后一个 decode/encode 之后的内容
            sub(/.*(decode|encode)[ \t]+/, "", line)
            # 拆分: a[1]=帧数 a[2]=frames a[3]=time a[4]=耗时ms ...
            split(line, a, /[ \t]+/)
            if (a[1] ~ /^[0-9]+$/) frames = a[1]   # 纯数字才采用
            if (a[4] ~ /^[0-9]+$/) tms = a[4]
            # 在原始行里找 fps 字段, 下一个字段就是整段平均帧率
            for (i = 1; i <= NF; i++)
                if ($i == "fps") avg = $(i + 1) + 0
        }

        # END 在所有输入处理完后执行一次, 输出固定 5 个字段:
        #   max min avg frames time
        END {
            if (cnt > 0) printf "%.2f %.2f ", mx, mn   # 无样本则 "- - "
            else         printf "- - "
            if (avg > 0) printf "%.2f %s %s\n", avg, frames, tms
            else         printf "- - -\n"              # 无汇总行
        }
    ' "$@" 2>/dev/null)

    # 一行 5 个字段按空白切分, 写入全局变量
    read -r mpp_max mpp_min mpp_avg mpp_frames mpp_time <<< "${out}"
}
