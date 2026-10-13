#!/usr/bin/env bash
#########################################################################
# File Name: 02.probe_stream.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed Sep 30 2026
#########################################################################

# 用 ffprobe 探测压缩码流的视频信息, 以 key=value 输出原始字段。
# 固定探测视频流 v:0; 不做回退/推导: 字段按 ffprobe 原样输出 (缺失通常为 N/A),
# 仅 bits_per_raw_sample 的 0 归一为空。
#
# 用法:
#   <exe> <stream> [options]
#
# 选项:
#   --get <field>        只打印指定字段 (裸值)
#   -e, --extended       附加字段 (profile/level/color_*/field_order, ...)
#   --timeout <sec>      用 timeout 限制 ffprobe 运行时长 (需要 timeout 命令)
#   -v                   详细模式 (向 stderr 打印探测命令)
#   -h                   显示帮助
#
# 输出 (stdout, key=value):
#   video: width height pix_fmt codec_name r_frame_rate avg_frame_rate nb_frames
#          bits_per_raw_sample duration
#   -e 追加: profile/level/bit_rate/color_range/color_space/color_transfer/
#            color_primaries/field_order/start_time/rotation/
#            sample_aspect_ratio/display_aspect_ratio
#   --get 接受任意适用字段
#
# 退出码: 0 成功 / 1 探测失败 / 2 参数错误

source "${HOME}/bin/_log.sh"

stream=""
get_field=""
extended="0"
timeout_sec=""
verbose="0"
end_opts="0"

codec_type=""; width=""; height=""; pix_fmt=""; codec_name=""
profile=""; level=""; r_frame_rate=""; avg_frame_rate=""; nb_frames=""
bits_per_raw_sample=""
color_range=""; color_space=""; color_transfer=""; color_primaries=""
field_order=""; start_time=""; rotation=""
sample_aspect_ratio=""; display_aspect_ratio=""
bit_rate=""
duration=""
fields=""

_ff_out=""; _ff_rc="0"; _ff_err=""; _ff_errf=""
_fv=""   # field_value 的输出槽 (字段名对应的变量值)

# 字段表 (单一来源, 供 field_value/emit_result 共用)
known_fields="codec_type width height pix_fmt codec_name profile level r_frame_rate \
avg_frame_rate nb_frames bit_rate color_range color_space color_transfer \
color_primaries field_order start_time rotation sample_aspect_ratio \
display_aspect_ratio bits_per_raw_sample duration"

base_video="width height pix_fmt codec_name r_frame_rate avg_frame_rate \
nb_frames bits_per_raw_sample duration"
ext_video="width height pix_fmt codec_name profile level r_frame_rate avg_frame_rate \
nb_frames bits_per_raw_sample bit_rate color_range color_space color_transfer \
color_primaries field_order start_time rotation sample_aspect_ratio \
display_aspect_ratio duration"

function usage()
{
    echo "usage: $0 <stream> [options]"
    echo "  options: --get <field> -e --timeout <sec> -v -h [--]"
    echo "  <stream>             compressed stream file (probe video stream v:0)"
    echo "  --get <field>        print only the given field (bare value)"
    echo "  -e, --extended       print extra fields"
    echo "  --timeout <sec>      ffprobe timeout"
    echo "  -v                   verbose (print probe command to stderr)"
    echo "  -h                   show help"
    echo "  --                   treat the next argument as the stream"
}

function cleanup()
{
    [ -n "${_ff_errf}" ] && rm -f "${_ff_errf}"
    return 0
}
# 注册退出钩子: 进程结束时(正常结束 / exit / 出错)自动删除临时 stderr 文件。
# trap 无函数作用域, 放顶层紧跟 cleanup 定义, 确保创建临时文件之前就已生效。
trap cleanup EXIT

# 详细输出走日志库 DEBUG 级别 (由 -v 打开)
function log_v()
{
    log_dbg "==> $*"
    return 0
}

# 字段是否为已知字段 (逐词精确匹配, 避免 "height pix_fmt" 这类多词串被子串匹配误判)
function is_known_field()
{
    local _k
    for _k in ${known_fields}; do
        [ "${_k}" = "$1" ] && return 0
    done
    return 1
}

# 取字段值到全局 _fv; 未知字段返回 1
function field_value()
{
    is_known_field "$1" || return 1
    _fv="${!1}"
}

# ---------------- 参数解析 ----------------
function parse_args()
{
    while [ $# -gt 0 ]; do
        if [ "${end_opts}" = "1" ]; then
            [ -z "${stream}" ] || { log_error "unexpected argument: $1"; exit 2; }
            stream="$1"; shift
            continue
        fi
        case "$1" in
            --get)
                { [ $# -ge 2 ] && [ -n "$2" ]; } \
                    || { log_error "option --get needs a value"; exit 2; }
                get_field="$2"; shift 2 ;;
            -e|--extended) extended="1"; shift ;;
            --timeout)
                [ $# -ge 2 ] || { log_error "option --timeout needs a value"; exit 2; }
                timeout_sec="$2"; shift 2 ;;
            -v|--verbose) verbose="1"; log_set_level debug; shift ;;
            -h|--help)    usage; exit 0 ;;
            --)           end_opts="1"; shift ;;
            -*)           log_error "unknown option: $1"; usage >&2; exit 2 ;;
            *)
                [ -z "${stream}" ] || { log_error "unexpected argument: $1"; exit 2; }
                stream="$1"; shift ;;
        esac
    done
}

# ---------------- 探测 ----------------

# 执行 ffprobe (可带 timeout); stdout 存 _ff_out, stderr 存 _ff_err, 返回码存 _ff_rc
function run_ffprobe()
{
    [ -n "${_ff_errf}" ] || _ff_errf=$(mktemp)
    local -a c=(ffprobe -v error "$@")
    [ -n "${timeout_sec}" ] && c=(timeout "${timeout_sec}" "${c[@]}")
    log_v "${c[*]}"
    _ff_out=$("${c[@]}" 2>"${_ff_errf}")
    _ff_rc=$?
    _ff_err=$(cat "${_ff_errf}")
    return 0
}

# 报告 ffprobe 失败 (区分超时/普通失败; -v 时附带原始 stderr)
function report_probe_fail()
{
    # timeout 命令在子命令超时被它终止时返回 124
    if [ "${_ff_rc}" = "124" ]; then
        log_error "ffprobe timed out after ${timeout_sec}s: ${stream}"
    else
        log_error "ffprobe failed (rc=${_ff_rc}): ${stream}"
    fi
    [ -n "${_ff_err}" ] && [ "${verbose}" = "1" ] && printf '%s\n' "${_ff_err}" >&2
}

# -of default=noprint_wrappers=1 输出稳定的 key=value 行, 不依赖行/列顺序
function do_probe()
{
    local s_entries
    s_entries="codec_type,codec_name,profile,level,width,height,pix_fmt,"
    s_entries+="r_frame_rate,avg_frame_rate,nb_frames,sample_aspect_ratio,"
    s_entries+="display_aspect_ratio,bits_per_raw_sample,bit_rate,color_range,"
    s_entries+="color_space,color_transfer,color_primaries,field_order,start_time"
    local entries="stream=${s_entries}:stream_tags=rotate"
    entries+=":stream_side_data=rotation:format=duration"

    run_ffprobe -select_streams v:0 \
        -show_entries "${entries}" \
        -of default=noprint_wrappers=1 -- "${stream}"
    local info="${_ff_out}"
    { [ -z "${info}" ] || [ "${_ff_rc}" != "0" ]; } \
        && { report_probe_fail; return 1; }

    local key val
    while IFS='=' read -r key val; do
        case "${key}" in
            codec_type)          codec_type="${val}" ;;
            width)               width="${val}" ;;
            height)              height="${val}" ;;
            pix_fmt)             pix_fmt="${val}" ;;
            codec_name)          codec_name="${val}" ;;
            profile)             profile="${val}" ;;
            level)               level="${val}" ;;
            r_frame_rate)        r_frame_rate="${val}" ;;
            avg_frame_rate)      avg_frame_rate="${val}" ;;
            nb_frames)           nb_frames="${val}" ;;
            sample_aspect_ratio) sample_aspect_ratio="${val}" ;;
            display_aspect_ratio) display_aspect_ratio="${val}" ;;
            bits_per_raw_sample) bits_per_raw_sample="${val}" ;;
            bit_rate)            bit_rate="${val}" ;;
            color_range)         color_range="${val}" ;;
            color_space)         color_space="${val}" ;;
            color_transfer)      color_transfer="${val}" ;;
            color_primaries)     color_primaries="${val}" ;;
            field_order)         field_order="${val}" ;;
            start_time)          start_time="${val}" ;;
            # mkv 的 tag 名为大写 (TAG:ROTATE), mp4 可能小写, 故大小写不敏感匹配
            TAG:[Rr][Oo][Tt][Aa][Tt][Ee]) rotation="${val}" ;;
            rotation)            rotation="${val}" ;;
            duration)            duration="${val}" ;;
        esac
    done <<< "${info}"

    # 0 表示未知, 归一为空
    case "${bits_per_raw_sample}" in 0) bits_per_raw_sample="" ;; esac
    return 0
}

# ---------------- 输出 ----------------
function emit_result()
{
    local f
    if [ -n "${get_field}" ]; then
        is_known_field "${get_field}" \
            || { log_error "unknown field: ${get_field}"; exit 2; }
        field_value "${get_field}"
        printf '%s\n' "${_fv}"
        return 0
    fi

    for f in ${fields}; do
        field_value "${f}"
        printf '%s=%s\n' "${f}" "${_fv}"
    done
}

# ---------------- 主流程 ----------------
function main()
{
    parse_args "$@"

    [ -z "${stream}" ] && { usage >&2; exit 2; }
    [ -f "${stream}" ] || { log_error "stream not found: ${stream}"; exit 1; }

    if [ -n "${timeout_sec}" ]; then
        [[ "${timeout_sec}" =~ ^[0-9]+$ ]] \
            || { log_error "invalid --timeout: ${timeout_sec}"; exit 2; }
        command -v timeout >/dev/null 2>&1 \
            || { log_error "timeout not found"; exit 1; }
    fi
    command -v ffprobe >/dev/null 2>&1 || { log_error "ffprobe not found"; exit 1; }

    do_probe || exit 1

    [ "${codec_type}" = "video" ] && [ -n "${width}" ] && [ -n "${height}" ] \
        || { log_error "no video stream: ${stream}"; exit 1; }

    [ "${extended}" = "1" ] && fields="${ext_video}" || fields="${base_video}"
    emit_result
    return 0
}

main "$@"
