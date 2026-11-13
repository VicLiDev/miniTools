#!/usr/bin/env bash
#########################################################################
# File Name: rk_dec_perf.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Tue 10 Nov 2026 10:00:00 AM CST
#########################################################################

# ============================================================
# RK 解码性能测试
#
#   列表: <codec> <path>  (本机路径 push 到设备, 设备路径直接解码)
#   工作目录自动选剩余空间最大的分区, RK_DEC_PERF_WORKDIR 可覆盖
#   帧率: ins 每秒采样取 max/min; 汇总行 fps 为 avg; <1s 自动 -n 3000 补采样
#   码率: 优先容器元数据; 裸流按 文件大小*帧率/帧数 估算 (~ 前缀)
#   输出: <outdir>/perf_result.csv, rk_dec_perf_<ts>.log, <n>_<name>.perf.log[cat]
# ============================================================

source "${HOME}/bin/_log.sh"
source "${HOME}/bin/_csv.sh"
source "${HOME}/bin/_adb_dev_op.sh"
source "${HOME}/bin/_mpp.sh"

__probe_stream="${HOME}/bin/m_probe_stream.sh"
__bom=$'\xEF\xBB\xBF'

# ---- 配置 ----
cmd_list_file=""
cmd_out_dir="rk_dec_perf_out"
cmd_extra_args=""
cmd_frames=""      # 固定解码帧数 (-n); 空 = 解完整码流
cmd_hw_stat="0"    # 1 = 统计内核硬件解码时间 (mpp_dev_debug)
hw_rows=()         # 硬件统计: spec name cnt avg_us min_us max_us avg_fps max_fps min_fps
hw_dbg_old=""      # 原始 mpp_dev_debug 值, 退出时恢复
hw_csv=""
hw_cnt=0; hw_avg_us=0; hw_min_us=0; hw_max_us=0
hw_avg_fps="-"; hw_max_fps="-"; hw_min_fps="-"
cmd_reader_buf="1048576"
cmd_envs=""          # 额外环境变量 (K=V ...)  # reader_buf_size; 空 = mpi_dec_test 默认 4KB
cmd_timeout_sec="300"
cmd_verbose="0"
cmd_quiet="0"
cmd_keep_dev="0"
cmd_adb_sel_paras=""

dev_work_dir="/data/tmp/rk_perf"
dev_free_kb=""
dev_exe="mpi_dec_test"
dev_has_timeout="0"
g_dev_ready="0"
g_idx="0"
ts=""
result_csv=""

# ---- 逐片源输出 ----
res_rows=()     # 表格行
stat_lines=()   # "avg max min", 仅 PASS 片源
fail_rows=()    # "名字 (原因)"
est_seen="0"    # 出现过渡估算码率 (表格下方补说明)

# ---- 日志解析结果 ----
g_max=""; g_min=""; g_avg=""; g_frames="-"; g_time="-"
g_frames_est=""   # 估算码率用的帧数 (循环解码时取单遍帧数)
g_rsl="N/A"; g_br="N/A"

# ==================== 命令行 ====================

function usage()
{
    cat <<EOF
Usage: $0 -l <list> [options]

  -l <file>        stream list, each line: <codec> <stream path>
  --idx <n>        select device by index
  --soc <name>     select device by SoC name
  -o <dir>         output dir (default: ${cmd_out_dir})
  --extra <args>   extra mpi_dec_test args, e.g. "-o out.yuv"
  --frames <n>     decode fixed frame count (mpi_dec_test -n); short
  --hw               analyze hardware decode time (mpp_dev_debug=260, needs root)
  --reader-buf <n>  reader_buf_size for mpi_dec_test (default 1048576)
  --env "K=V ..."   extra env for the test binary (e.g. mpp_dec_debug=0x2)
                   streams loop to reach n, default 0 = whole stream
  --timeout <sec>  per-stream decode timeout (default: ${cmd_timeout_sec})
  -k               keep stream file on device
  -v / -q          verbose / quiet
  -h               show this help

Codec types: h264 h265 vp9 av1 avs2 avs mpeg2 mpeg4 vp8 mjpeg

Env: RK_DEC_PERF_WORKDIR  device work dir (default: auto detect)

Example: $0 -l streams.list --frames 3000
EOF
}

function need_val()
{
    [ -n "${2:-}" ] || {
        echo "Error: option $1 requires a value" >&2
        exit 1
    }
}

function parse_args()
{
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--list)    need_val "$@"; cmd_list_file="$2"; shift 2 ;;
            --idx)        need_val "$@"; cmd_adb_sel_paras="--idx $2"; shift 2 ;;
            --soc)        need_val "$@"; cmd_adb_sel_paras="--soc $2"; shift 2 ;;
            -o|--outdir)  need_val "$@"; cmd_out_dir="$2"; shift 2 ;;
            --extra)      need_val "$@"; cmd_extra_args="$2"; shift 2 ;;
            --frames)     need_val "$@"; cmd_frames="$2"; shift 2 ;;
            --hw)         cmd_hw_stat="1"; shift ;;
            --reader-buf) need_val "$@"; cmd_reader_buf="$2"; shift 2 ;;
            --env)        need_val "$@"; cmd_envs="$2"; shift 2 ;;
            --timeout)    need_val "$@"; cmd_timeout_sec="$2"; shift 2 ;;
            -k|--keep)    cmd_keep_dev="1"; shift ;;
            -v|--verbose) cmd_verbose="1"; shift ;;
            -q|--quiet)   cmd_quiet="1"; shift ;;
            -h|--help)    usage; exit 0 ;;
            *)            echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
        esac
    done

    [ -z "${cmd_list_file}" ] && { echo "Error: no list file (-l)" >&2; exit 1; }
    [ -f "${cmd_list_file}" ] || { echo "Error: list not found: ${cmd_list_file}" >&2; exit 1; }
    case "${cmd_timeout_sec}" in
        ''|*[!0-9]*) echo "Error: invalid timeout: ${cmd_timeout_sec}" >&2; exit 1 ;;
    esac
    case "${cmd_frames}" in
        '') ;;
        *[!0-9]*) echo "Error: invalid frames: ${cmd_frames}" >&2; exit 1 ;;
    esac
    case "${cmd_reader_buf}" in
        "") ;;
        *[!0-9]*) echo "Error: invalid reader buf: ${cmd_reader_buf}" >&2; exit 1 ;;
    esac
}

function check_env()
{
    local t
    for t in awk basename stat tr readlink; do
        command -v "${t}" >/dev/null 2>&1 || { echo "Error: missing tool: ${t}" >&2; exit 1; }
    done
    [ -x "${__probe_stream}" ] || {
        echo "Error: helper not executable: ${__probe_stream}" >&2
        exit 1
    }
}

# ==================== 流信息 ====================

# ffprobe key=value -> p_w p_h p_b p_d p_c p_f p_a (avg_frame_rate)
function _kv_read()
{
    p_w=""; p_h=""; p_b="N/A"; p_d="N/A"; p_c="N/A"; p_f="N/A"; p_a="N/A"
    while IFS='=' read -r k v; do
        case "${k}" in
            width)          p_w="${v}" ;;
            height)         p_h="${v}" ;;
            bit_rate)       [ -n "${v}" ] && p_b="${v}" ;;
            duration)       [ -n "${v}" ] && p_d="${v}" ;;
            codec_name)     [ -n "${v}" ] && p_c="${v}" ;;
            r_frame_rate)   [ -n "${v}" ] && p_f="${v}" ;;
            avg_frame_rate) [ -n "${v}" ] && p_a="${v}" ;;
        esac
    done
}

# 探测片源信息 -> g_rsl (WxH) / g_br (码率)
#   码率优先级: 容器 bit_rate > 文件大小/时长 > 文件大小/帧率/帧数 (估算, 带 ~)
function probe_stream()
{
    local file="$1" w h b d c rf a sz fps frames est=""

    g_rsl="N/A"; g_br="N/A"
    [ -f "${file}" ] || return 0

    _kv_read < <("${__probe_stream}" -e "${file}" 2>/dev/null)
    w="${p_w}"; h="${p_h}"; b="${p_b}"; d="${p_d}"; c="${p_c}"; rf="${p_f}"; a="${p_a}"

    # 裸流从中间切出时首个 SPS 可能在很后面, 默认探测读不到宽高, 加大范围重试
    if [ "${w:-0}" -le 0 ] 2>/dev/null || [ "${h:-0}" -le 0 ] 2>/dev/null; then
        _kv_read < <(ffprobe -v quiet -analyzeduration 100M -probesize 100M \
            -select_streams v:0 -show_entries stream=width,height,bit_rate,codec_name,r_frame_rate,avg_frame_rate \
            -of default=nw=1 -- "${file}" 2>/dev/null)
        w="${p_w}"; h="${p_h}"; b="${p_b}"; c="${p_c}"; rf="${p_f}"; a="${p_a}"; d="N/A"
    fi
    [ "${w:-0}" -gt 0 ] 2>/dev/null && [ "${h:-0}" -gt 0 ] 2>/dev/null && g_rsl="${w}x${h}"

    sz=$(stat -c %s "${file}" 2>/dev/null)
    case "${b}" in ''|N/A|0) b="" ;; esac
    frames="${g_frames_est:-${g_frames}}"
    if [ -z "${b}" ] && [ -n "${sz}" ] && [ "${d}" != "N/A" ]; then
        b=$(LC_ALL=C awk -v s="${sz}" -v d="${d}" 'BEGIN { printf "%.0f", s * 8 / d }')
    fi
    if [ -z "${b}" ] && [ -n "${sz}" ] && [ "${frames:-0}" -gt 0 ] 2>/dev/null; then
        fps=""
        # 文件名里的帧率提示 (60F/25FPS/29.97F) 比裸流 SPS 更可靠
        if [[ "${file##*/}" =~ ([0-9]+(\.[0-9]+)?)[Ff] ]]; then
            fps="${BASH_REMATCH[1]}"
            LC_ALL=C awk -v x="${fps}" 'BEGIN { exit !(x >= 5 && x <= 120) }' || fps=""
        elif [ "${rf}" != "N/A" ] || [ "${a}" != "N/A" ]; then
            # 裸流 SPS/VUI: H.264 常写场率(2 倍), >30 时折半
            # r_frame_rate 可能是垃圾值(如 900559984/892718819), 不合法时退到 avg_frame_rate
            fps=$(LC_ALL=C awk -v r="${rf}" -v a="${a}" -v c="${c}" 'BEGIN {
                n = split(r, R, "/"); m = split(a, A, "/")
                for (i = 1; i <= 2; i++) {
                    if (i == 1) { if (n != 2 || R[2] == 0) continue; v = R[1] / R[2] }
                    else        { if (m != 2 || A[2] == 0) continue; v = A[1] / A[2] }
                    if (c == "h264" && v > 30) v /= 2
                    if (v >= 5 && v <= 120) { printf "%.2f", v; exit }
                } }')
        fi
        if [ -n "${fps}" ]; then
            b=$(LC_ALL=C awk -v s="${sz}" -v f="${frames}" -v r="${fps}" \
                'BEGIN { printf "%.0f", s * 8 * r / f }')
            est="~"; est_seen="1"
        fi
    fi
    [ -n "${b}" ] || return 0

    g_br=$(LC_ALL=C awk -v b="${b}" -v e="${est}" 'BEGIN {
        if (b >= 1000000) printf "%s%.2f Mbps", e, b / 1000000
        else              printf "%s%.0f kbps", e, b / 1000
    }')
}

# ==================== 设备 ====================

# 探测设备端可写工作目录: 不同设备根目录挂载差异较大
#   Android: /data/local/tmp;  Buildroot: /userdata
#   只在该目录的父目录已存在时才创建, 避免在 rootfs 上凭空造出 /data
#   (buildroot 根分区往往只有百来 MB, 看似可写却放不下码流),
#   并在所有候选里按可用空间挑最大的分区
#   可用环境变量 RK_DEC_PERF_WORKDIR 强制指定
function pick_work_dir()
{
    local dir base kb best="" best_kb=-1 q

    if [ -n "${RK_DEC_PERF_WORKDIR:-}" ]; then
        q=$(adev_quote "${RK_DEC_PERF_WORKDIR}")
        if adev_shell "mkdir -p ${q} && test -w ${q}" >/dev/null 2>&1; then
            dev_work_dir="${RK_DEC_PERF_WORKDIR}"
            return 0
        fi
        log_warn "RK_DEC_PERF_WORKDIR not writable: ${RK_DEC_PERF_WORKDIR}"
        return 1
    fi

    for dir in /data/local/tmp/rk_perf /userdata/rk_perf /data/rk_perf \
               /tmp/rk_perf /cache/rk_perf /dev/shm/rk_perf; do
        base="${dir%/*}"; q=$(adev_quote "${dir}")
        # 父目录存在才创建, 避免在 rootfs 上凭空造出 /data
        adev_shell "test -d $(adev_quote "${base}") && mkdir -p ${q} && test -w ${q}" \
            >/dev/null 2>&1 || continue
        if kb=$(adev_free_kb "${dir}"); then
            [ "${kb}" -gt "${best_kb}" ] && { best="${dir}"; best_kb="${kb}"; }
        elif [ -z "${best}" ]; then
            best="${dir}"       # 拿不到 df 时, 先用第一个可写目录
        fi
    done

    [ -n "${best}" ] || return 1
    dev_work_dir="${best}"
    [ "${best_kb}" -ge 0 ] && dev_free_kb="${best_kb}"
    return 0
}

# 解析 dmesg 中 rkvdec 每任务硬件耗时 (us), 计算硬件帧率
function hw_parse_dmesg()
{
    local out

    hw_cnt=0; hw_avg_us=0; hw_min_us=0; hw_max_us=0
    hw_avg_fps="-"; hw_max_fps="-"; hw_min_fps="-"
    out=$(LC_ALL=C awk '
        /rkvdec/ && /time:/ {
            for (i = 1; i <= NF; i++) {
                if ($i != "hw") continue
                v = $(i + 1) + 0
                if (v <= 0) continue
                if (c == 0 || v < mn) mn = v
                if (v > mx) mx = v
                s += v
                c++
            }
        }
        END {
            if (c > 0) printf "%d %.0f %d %d\n", c, s / c, mn, mx
            else       print "0 0 0 0"
        }
    ' "$1" 2>/dev/null)
    read -r hw_cnt hw_avg_us hw_min_us hw_max_us <<< "${out}"
    [ "${hw_cnt}" -gt 0 ] 2>/dev/null || return 0
    hw_avg_fps=$(LC_ALL=C awk -v u="${hw_avg_us}" 'BEGIN { printf "%.2f", 1000000 / u }')
    hw_max_fps=$(LC_ALL=C awk -v u="${hw_min_us}" 'BEGIN { printf "%.2f", 1000000 / u }')
    hw_min_fps=$(LC_ALL=C awk -v u="${hw_max_us}" 'BEGIN { printf "%.2f", 1000000 / u }')
}

# 恢复 mpp_dev_debug 原始值
function hw_restore()
{
    [ -n "${hw_dbg_old}" ] || return 0
    adev_shell "echo ${hw_dbg_old} > /sys/module/rk_vcodec/parameters/mpp_dev_debug" >/dev/null 2>&1
    hw_dbg_old=""
}

function device_init()
{
    local free=""
    adev_select ${cmd_adb_sel_paras} || return 1
    log "device selected: ${adev_adb}"

    dev_exe=$(adev_find_exe "${dev_exe}") || {
        log_fail "${dev_exe} not found on device, please deploy it first"
        return 1
    }
    log_dbg "device decoder: ${dev_exe}"

    if ! pick_work_dir; then
        log_fail "no writable dir on device (tried /data /userdata /tmp ...)"
        return 1
    fi
    free=""
    [ -n "${dev_free_kb}" ] && free=" (free $((dev_free_kb / 1024)) MB)"
    log "device work dir: ${dev_work_dir}${free}"

    adev_shell "command -v timeout" >/dev/null 2>&1 && dev_has_timeout="1"

    if [ "${cmd_hw_stat}" = "1" ]; then
        if ! adev_shell "test -e /sys/module/rk_vcodec/parameters/mpp_dev_debug" >/dev/null 2>&1; then
            log_warn "mpp_dev_debug not found, --hw disabled"
            cmd_hw_stat="0"
        else
            hw_dbg_old=$(adev_shell "cat /sys/module/rk_vcodec/parameters/mpp_dev_debug" 2>/dev/null | tr -d ' \r')
            if ! adev_shell "echo 260 > /sys/module/rk_vcodec/parameters/mpp_dev_debug" >/dev/null 2>&1; then
                log_warn "failed to enable mpp_dev_debug, --hw disabled"
                cmd_hw_stat="0"
            fi
        fi
    fi

    return 0
}

function cleanup()
{
    log_warn "interrupt received, cleaning device files..."
    hw_restore
    if [ "${g_dev_ready}" = "1" ] && [ "${cmd_keep_dev}" = "0" ]; then
        adev_shell "rm -rf $(adev_quote "${dev_work_dir}")" >/dev/null 2>&1
    fi
    exit 130
}

# ==================== 结果记录 ====================

# $1=spec $2=stream $3=status(PASS/FAIL) $4=note
# PASS 取 g_* ; FAIL 一律占位
function _record()
{
    local spec="$1" src="$2" status="$3" note="$4"
    local name mm avg rsl br frames tms

    name=$(basename "${src}")
    if [ "${status}" = "PASS" ]; then
        mm="${g_max}/${g_min}"; avg="${g_avg}"
        rsl="${g_rsl}"; br="${g_br}"
        frames="${g_frames}"; tms="${g_time}"
        stat_lines+=("${avg} ${g_max} ${g_min}")
    else
        mm="-/-"; avg="-"
        rsl="${g_rsl:--}"; br="${g_br:-N/A}"
        frames="-"; tms="-"
        fail_rows+=("${name} (${note})")
    fi

    # 存字段而不是成型的行, 打印时按内容宽度对齐
    res_rows+=("${spec}"$'\t'"${mm}"$'\t'"${avg}"$'\t'"${rsl}"$'\t'"${br}"$'\t'"${name}")

    csv_append "${result_csv}" "${spec}" "${mm}" "${avg}" "${rsl}" "${br}" \
        "${name}" "${frames}" "${tms}" "${status}" "${note}"
}

# 失败快捷记录: $1=spec $2=stream $3=原因 (始终返回 1)
function fail_stream()
{
    log_fail "$3"
    # 解码失败也尽量填分辨率/码率: 本地文件可直接探测
    [ -f "$2" ] && probe_stream "$2"
    _record "$1" "$2" "FAIL" "$3"
    return 1
}

# ==================== 单片源测试 ====================

function perf_one()
{
    local spec="$1" src="$2"
    local name ctype ret dev_in dec_log dec_logcat shell_cmd is_local=1
    local sz avail msg mem_avail note dec_envs

    g_idx=$(( g_idx + 1 ))
    name=$(basename "${src}")
    dec_log="${cmd_out_dir}/${g_idx}_${name}.perf.log"
    dec_logcat="${cmd_out_dir}/${g_idx}_${name}.perf.logcat"

    # 每个片源重置, 失败时也可能探测出分辨率/码率
    g_rsl="-"; g_br="N/A"

    ctype=$(mpp_codec_token "${spec}")
    [ -n "${ctype}" ] || { fail_stream "${spec}" "${src}" "invalid codec type"; return 1; }

    # 本机文件: push 到设备; 否则视为设备上已有文件
    if [ -f "${src}" ]; then
        dev_in="${dev_work_dir}/$(printf '%s' "${g_idx}_${name}" | tr -c 'A-Za-z0-9._-' '_')"

        # 推之前先看剩余空间, 大码流很容易把分区塞满
        sz=$(stat -c %s "${src}" 2>/dev/null); sz=${sz:-0}
        if avail=$(adev_free_kb "${dev_work_dir}" 2>/dev/null) \
                && [ "${avail}" -lt $(( sz / 1024 + 10240 )) ]; then
            fail_stream "${spec}" "${src}" \
                "no space on device: need $((sz / 1048576)) MB, have $((avail / 1024)) MB"
            return 1
        fi

        log_dbg "push ${src} -> ${dev_in}"
        if ! msg=$(adev_push "${src}" "${dev_in}" 2>&1 >/dev/null); then
            msg=$(printf '%s' "${msg}" | tr '\r' '\n' | tail -n 1)
            adev_shell "rm -f $(adev_quote "${dev_in}")" >/dev/null 2>&1
            fail_stream "${spec}" "${src}" "push failed: ${msg:-unknown error}"
            return 1
        fi

        # mpi_dec_test 的 reader 会把整个码流缓存进内存, 大文件在小内存板子上会 OOM
        if [ "${sz}" -gt $(( 300 * 1048576 )) ]; then
            mem_avail=$(adev_shell "grep MemAvailable /proc/meminfo" 2>/dev/null \
                | awk '{print int($2 / 1024)}' | tr -d ' \r')
            case "${mem_avail}" in
                ''|*[!0-9]*) mem_avail="" ;;
            esac
            if [ -n "${mem_avail}" ] \
                    && [ $(( sz / 1048576 + 300 )) -gt "${mem_avail}" ]; then
                log_warn "stream $((sz / 1048576)) MB, device MemAvailable" \
                    "${mem_avail} MB: mpi_dec_test caches the whole file" \
                    "in RAM, OOM risk"
            fi
        fi
    else
        is_local="0"
        adev_valid || { fail_stream "${spec}" "${src}" "device disconnected"; return 9; }
        adev_shell "test -f $(adev_quote "${src}")" >/dev/null 2>&1 \
            || { fail_stream "${spec}" "${src}" "stream not found on device"; return 1; }
        dev_in="${src}"
    fi

    # 不写 yuv, 避免磁盘 I/O 干扰性能; 需要落盘用 --extra "-o ..."
    # -v qf 由本脚本传入: q 静音逐帧日志, f 打开每秒 fps 打印 (新版默认不输出 ins 行)
    local run_frames="${cmd_frames}" pass_frames="" looped="0"
    g_frames_est=""

    while :; do
        dec_envs=""
        [ -n "${cmd_reader_buf}" ] && dec_envs="reader_buf_size=${cmd_reader_buf}"
        [ -n "${cmd_envs}" ] && dec_envs+="${dec_envs:+ }${cmd_envs}"
        shell_cmd=$(mpp_dec_cmd "${dev_exe}" "${dev_work_dir}" "${dev_in}" "${ctype}" \
            "${run_frames}" "-v qf${cmd_extra_args:+ ${cmd_extra_args}}" \
            "${dev_has_timeout:+${cmd_timeout_sec}}" "${dec_envs}")

        [ "${cmd_hw_stat}" = "1" ] && adev_shell "dmesg -c >/dev/null 2>&1" >/dev/null 2>&1

        log_dbg "device decode: ${shell_cmd}"
        adev_run_capture_named "${shell_cmd}" "${cmd_out_dir}" "${g_idx}_${name}.perf"
        ret=$adev_ret

        if [ "${cmd_hw_stat}" = "1" ]; then
            adev_shell "dmesg" > "${cmd_out_dir}/${g_idx}_${name}.dmesg" 2>/dev/null
            hw_parse_dmesg "${cmd_out_dir}/${g_idx}_${name}.dmesg"
        fi

        # stdout 与 logcat 都看, 兼容 Linux/Android 两套日志去向
        mpp_fps_parse "${dec_log}" "${dec_logcat}"
        g_max=$mpp_max; g_min=$mpp_min; g_avg=$mpp_avg
        g_frames=$mpp_frames; g_time=$mpp_time

        # 片源太短 (<1s) 时没有每秒采样, 用 -n 3000 循环解码一次补齐 max/min
        case " ${cmd_extra_args} " in *" -n "*) break ;; esac
        [ "${ret}" = "0" ] && [ -z "${run_frames}" ] || break
        [ "${g_max}" = "-" ] && [ "${g_time:-x}" -lt 1000 ] 2>/dev/null || break
        pass_frames="${g_frames}"
        run_frames="3000"
        looped="1"
        log_warn "stream too short (${g_time} ms), re-run with -n 3000 (loop)"
    done

    if [ "${is_local}" = "1" ] && [ "${cmd_keep_dev}" = "0" ]; then
        adev_shell "rm -f $(adev_quote "${dev_in}")" >/dev/null 2>&1
    fi

    if [ "${ret}" != "0" ]; then
        # 设备掉线 (解码器崩溃/OOM/重启) 与普通解码失败区分开
        if ! adev_valid; then
            fail_stream "${spec}" "${src}" "decode failed ret=${ret}, device lost"
            return 9
        fi
        msg=$(grep -avE 'fps avg|test start|^$' "${dec_log}" 2>/dev/null \
              | tail -n 1 | tr -d '\r')
        [ -n "${msg}" ] && msg=": ${msg}"
        if [ "${ret}" = "137" ]; then
            fail_stream "${spec}" "${src}" "decode killed (OOM?) ret=137${msg}"
        else
            fail_stream "${spec}" "${src}" "decode failed ret=${ret}${msg}"
        fi
        return 1
    fi
    if [ -z "${g_avg}" ] || [ "${g_avg}" = "-" ]; then
        fail_stream "${spec}" "${src}" "no fps data in log"
        return 1
    fi
    if [ "${g_max}" = "-" ]; then
        if [ "${g_time}" -lt 1000 ] 2>/dev/null; then
            log_warn "decode ${g_time} ms (<1s), no per-second fps sample," \
                "max/min unavailable"
        else
            log_warn "no 'ins' sample in log, max/min unavailable" \
                "(check -v f support)"
        fi
    fi

    [ "${looped}" = "1" ] && g_frames_est="${pass_frames}"
    probe_stream "${src}"
    note=""
    [ "${looped}" = "1" ] && note="looped -n ${run_frames}"
    _record "${spec}" "${src}" "PASS" "${note}"

    if [ "${cmd_hw_stat}" = "1" ] && [ "${hw_cnt}" -gt 0 ] 2>/dev/null; then
        hw_rows+=("${spec}"$'\t'"${name}"$'\t'"${hw_cnt}"$'\t'"${hw_avg_us}"$'\t'"${hw_min_us}"$'\t'"${hw_max_us}"$'\t'"${hw_avg_fps}"$'\t'"${hw_max_fps}"$'\t'"${hw_min_fps}")
        csv_append "${hw_csv}" "${spec}" "${name}" "${hw_cnt}" "${hw_avg_us}" \
            "${hw_min_us}" "${hw_max_us}" "${hw_avg_fps}" "${hw_max_fps}" "${hw_min_fps}"
        log "hw: avg ${hw_avg_fps} fps (max ${hw_max_fps}, min ${hw_min_fps})"
    fi
    log "result: avg ${g_avg} fps, max ${g_max}, min ${g_min}" \
        "(frames ${g_frames}, time ${g_time} ms)"
    return 0
}

# ==================== 汇总 ====================

# 只统计 PASS 片源: "avg max min count ins_max ins_min"
function overall_stats()
{
    [ "${#stat_lines[@]}" -gt 0 ] || { echo "- - - 0 - -"; return 0; }

    printf '%s\n' "${stat_lines[@]}" | LC_ALL=C awk '
        {
            n++; sum += $1
            if (n == 1 || $1 > amax) amax = $1
            if (n == 1 || $1 < amin) amin = $1
            if ($2 != "-") {
                m++
                if (m == 1 || $2 > imax) imax = $2
                if (m == 1 || $3 < imin) imin = $3
            }
        }
        END {
            if (m == 0) printf "%.2f %.2f %.2f %d - -\n", sum / n, amax, amin, n
            else        printf "%.2f %.2f %.2f %d %.2f %.2f\n", sum / n, amax, amin, n, imax, imin
        }'
}

# 按显示宽度补空格 (bash ${#s} 在 UTF-8 下按字符数, 可直接处理中文表头)
# 显示宽度: 中文/全角字符按 2 列计 (UTF-8 3 字节字符)
function _dwidth()
{
    local s="${1}" n b

    n=${#s}
    local LC_ALL=C
    b=${#s}
    printf '%s' $(( n + (b - n) / 2 ))
}

function _pad()
{
    local s="${1}" n="$2" d

    d=$(_dwidth "${s}")
    printf '%s%*s' "${s}" $(( n > d ? n - d : 0 )) ''
}

# 结果表: 宽度按实际内容计算, 避免帧率位数变多后串列
function print_table()
{
    local -a hdr=(spec "max/min fps" "avg fps" "分辨率" "码率")
    local -a w=(4 11 7 6 4)
    local -a cells
    local r f0 f1 f2 f3 f4 f5 i line sep v d

    for r in "${res_rows[@]}"; do
        IFS=$'\t' read -r f0 f1 f2 f3 f4 f5 <<< "${r}"
        cells=("${f0}" "${f1}" "${f2}" "${f3}" "${f4}")
        for i in 0 1 2 3 4; do
            v="${cells[i]}"
            d=$(_dwidth "${v}")
            [ "${d}" -gt "${w[i]}" ] && w[i]=${d}
        done
    done

    line=""; sep=""
    for i in 0 1 2 3 4; do
        line+="$(_pad "${hdr[i]}" "${w[i]}")  "
        sep+="$(printf '%*s' "${w[i]}" '' | tr ' ' '-')  "
    done
    log_summary "${line}片源名字"
    log_summary "${sep}--------"

    for r in "${res_rows[@]}"; do
        IFS=$'\t' read -r f0 f1 f2 f3 f4 f5 <<< "${r}"
        cells=("${f0}" "${f1}" "${f2}" "${f3}" "${f4}")
        line=""
        for i in 0 1 2 3 4; do
            line+="$(_pad "${cells[i]}" "${w[i]}")  "
        done
        log_summary "${line}${f5}"
    done
    log_summary "${sep}--------"
}

# ==================== 主流程 ====================

function main()
{
    local line trimmed codec_name strm_path key ret
    local -A seen=()
    local aavg amax amin acnt imax imin r n_pass n_fail

    parse_args "$@"
    check_env
    mkdir -p "${cmd_out_dir}"

    # 实例锁: 防止多个实例并行写同一输出目录
    if command -v flock >/dev/null 2>&1; then
        exec 9>"${cmd_out_dir}/.rk_dec_perf.lock"
        flock -n 9 || { echo "Error: another rk_dec_perf instance is running" >&2; exit 1; }
    fi

    # 清理历史产物, 只保留本次结果
    rm -f "${cmd_out_dir}"/rk_dec_perf_*.log "${cmd_out_dir}"/perf_result.csv \
          "${cmd_out_dir}"/hw_result.csv "${cmd_out_dir}"/*.perf.log \
          "${cmd_out_dir}"/*.perf.logcat "${cmd_out_dir}"/*.dmesg 2>/dev/null

    ts=$(date +%Y%m%d_%H%M%S)
    log_setup "${cmd_out_dir}/rk_dec_perf_${ts}.log" "${cmd_quiet}" "${cmd_verbose}"
    [ -n "${_log_file:-}" ] && : >"${_log_file}"
    result_csv="${cmd_out_dir}/perf_result.csv"
    csv_header "${result_csv}" spec "max/min fps" "avg fps" resolution \
        bitrate stream frames time_ms status note

    if [ "${cmd_hw_stat}" = "1" ]; then
        hw_csv="${cmd_out_dir}/hw_result.csv"
        csv_header "${hw_csv}" spec stream tasks avg_hw_us min_hw_us max_hw_us \
            avg_fps max_fps min_fps
    fi

    log_summary "==== RK decode performance started: $(date) ===="
    log_summary "list file: ${cmd_list_file}"

    device_init || { log_fail "device init failed"; exit 1; }
    g_dev_ready="1"
    trap cleanup INT TERM

    while IFS= read -r line <&3 || [ -n "${line}" ]; do
        # 容忍 Windows(CRLF) 换行与文件开头 BOM
        line="${line%$'\r'}"
        line="${line#"${__bom}"}"
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "${trimmed}" in ''|\#*) continue ;; esac

        read -r codec_name strm_path <<< "${line}"

        # 列表去重: 同一片源只处理一次 (本机路径按绝对路径归一)
        if [ -n "${strm_path}" ]; then
            key="${strm_path}"
            [ -e "${strm_path}" ] && key=$(readlink -f "${strm_path}")
            if [ -n "${seen[${key}]:-}" ]; then
                log_warn "duplicate stream in list, skip: ${strm_path}"
                continue
            fi
            seen["${key}"]=1
        fi

        if [ -z "${codec_name}" ] || [ -z "${strm_path}" ]; then
            _record "${codec_name:--}" "${strm_path:-${line}}" "FAIL" "invalid list line"
            continue
        fi

        log "========================================"
        log "stream: ${strm_path}"
        log "spec: ${codec_name}"

        perf_one "${codec_name}" "${strm_path}"
        ret=$?
        # 设备掉线: 剩余片源无法继续
        if [ "${ret}" = "9" ]; then
            log_fail "device disconnected, abort remaining streams"
            break
        fi
    done 3<"${cmd_list_file}"

    if [ "${cmd_keep_dev}" = "0" ]; then
        adev_shell "rm -rf $(adev_quote "${dev_work_dir}")" >/dev/null 2>&1
    fi
    g_dev_ready="0"
    hw_restore

    n_pass=${#stat_lines[@]}
    n_fail=${#fail_rows[@]}

    # ---- 汇总输出 ----
    log_summary ""
    log_summary "==== decode performance ($((n_pass + n_fail)) streams, PASS ${n_pass}, FAIL ${n_fail}) ===="
    print_table

    if [ "${#hw_rows[@]}" -gt 0 ]; then
        log_summary ""
        log_summary "==== hardware decode stats (kernel mpp_dev_debug) ===="
        log_summary "spec  hw max/min fps  hw avg fps  name"
        for r in "${hw_rows[@]}"; do
            IFS=$'\t' read -r f0 f1 f2 f3 f4 f5 f6 f7 f8 <<< "${r}"
            log_summary "$(printf '%-5s %-14s %-9s %s' \
                "${f0}" "${f7}/${f8}" "${f6}" "${f1}")"
        done
    fi
    [ "${est_seen}" = "1" ] && log_summary \
        "注: ~ 为估算码率 (裸流无码率元数据, 按 文件大小*帧率/帧数 计算)"

    read -r aavg amax amin acnt imax imin <<< "$(overall_stats)"
    log_summary ""
    if [ "${acnt}" = "0" ]; then
        log_summary "overall: no PASS stream, no fps statistics"
    else
        log_summary "overall: ${acnt} stream(s), avg fps ${aavg}" \
            "(stream avg: max ${amax}, min ${amin})"
        [ "${imax}" != "-" ] && log_summary "overall ins: max ${imax}, min ${imin}"
    fi

    if [ "${n_fail}" -gt 0 ]; then
        log_summary ""
        log_summary "==== failed streams ===="
        for r in "${fail_rows[@]}"; do
            log_summary "  [FAIL] ${r}"
        done
    fi

    log_summary ""
    log_summary "result CSV: ${result_csv}"
    log_summary "detail log: ${_log_file:-<disabled>}"

    [ "${n_fail}" -gt 0 ] && exit 1
    exit 0
}

main "$@"
