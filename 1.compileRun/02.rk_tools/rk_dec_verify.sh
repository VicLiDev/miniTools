#!/usr/bin/env bash
#########################################################################
# File Name: rk_dec_verify.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Tue 11 Aug 2026 04:31:12 PM CST
#########################################################################

# ============================================================
# RK 硬件解码验证脚本 (三层结构)
#
# 分层:
#   第一层 通用与编排: 片源列表解析 / 日志 / CSV / 结果汇总
#   第二层 校验层:     与 yuv/slt 的生成方式无关
#                      只负责"给定产物如何校验":
#                        yuv/md5 - 软解参考 + 数据/md5 比对 (委托 cmp_yuv)
#                        slt     - 与 golden slt 数据比对
#   第三层 生产层:     与具体解码工具相关, 负责生成待校验的 yuv/slt
#                      默认后端 mpi_dec_test (push 到设备解码后 pull 回 PC)
#
#   两层通过固定接口解耦: 生产层"产出" yuv/slt, 校验层"消费" yuv/slt.
#   调整 / 新增 / 更换生成方式 = 增加一个 producer_<id>_* 后端
#   并通过 --producer <id> 选用, 校验层与编排层无需改动.
#
# 流程:
#   1. 读取片源列表 (每行: <编码类型> <片源路径>)
#   2. 生产层生成待校验 yuv (slt 校验时附带生成 slt)
#   3. 校验层按 --verify-method 对比
#   4. 分类汇总 (PASS/WARN/FAIL), 写 result.csv
#
# 片源列表格式 (每行): <编码类型> <片源路径>
#   编码类型必须准确指定:
#   h264/h265/vp9/av1/avs2/avs/mpeg2/mpeg4/vp8/mjpeg
#   编码类型不对或缺失时该片源直接判 FAIL
# ============================================================
#
# 代码结构索引:
#   入口      usage / parse_args / check_env
#   第一层    parse_stream_line / write_csv_header / clean_out_dir / cleanup
#   第二层    get_stream_info / get_soft_pixfmt / frame_size / soft_decode
#             soft_compare / slt_compare / method_enabled / verify_run
#   第三层    producer_dispatch / producer_* / log_env_info / detect_dec_exe
#             check_dev_space / retry_run / producer_decode_once
#             / producer_mpi_dec_test_*
#   编排      verify_one / main
# ============================================================

# ==================== 全局配置 ====================

# ---- 通用参数 ----
cmd_list_file=""        # 片源列表文件
cmd_out_dir=""          # 本地输出目录
cmd_verbose="0"         # 详细输出
cmd_quiet="0"           # 仅输出汇总

# ---- 生产层配置 ----
cmd_producer="mpi_dec_test"          # 生产层后端 id
dev_work_dir="/data/tmp/rk_verify"   # 设备端工作目录 (mpi_dec_test 后端)
dev_exe="mpi_dec_test"               # 设备端可执行名 (detect 后回填完整路径)
dev_has_timeout="0"                  # 设备端是否有 timeout 命令 (探测一次)
cmd_extra_args=""                    # 附加解码参数
cmd_timeout_sec="300"                # 设备端解码超时 (秒)
cmd_keep_dev="0"                     # 保留设备文件
cmd_adb_sel_paras=""                 # 单设备快捷选择参数 (adbs --idx/--soc)

# ---- 校验层配置 ----
cmd_verify_method="yuv" # 验证方法: yuv/md5/slt, 逗号分隔可组合, all=全部
cmd_slt_dir=""          # slt golden 数据目录 (默认片源同目录)
cmd_soft_pixfmt=""      # 覆盖软解输出格式
cmd_save_local="0"      # 保留本地软解 yuv
cmd_no_cmp="0"          # 仅解码, 不做对比

# ---- 运行时状态 ----
result_csv=""
ts=""
g_producer_ready="0"    # 生产层是否已初始化成功 (控制退出清理)
dn_opt=""               # check_env 探测: ffmpeg 是否支持 -dn
fps_mode_opt=""         # check_env 探测: 帧率透传选项 (-fps_mode/-vsync)
# 流信息缓存 (get_stream_info 输出, 供帧大小/软解/空间估算复用)
info_file=""
strm_w=""; strm_h=""; strm_pixfmt=""; strm_fps=""; strm_bpp=""; strm_dur=""
# 跨函数输出 (函数间传递结果; 集中声明便于查阅, 亦保证 set -u 安全)
codec_name=""; strm_path=""; parse_note=""
hw_frames=""; sw_frames=""; first_diff=""
prod_note=""
dec_ret=""; dev_size=""
sw_prepared=""          # yuv/md5 方法共享: 复用同一次软解
verify_fail_note=""; verify_method_results=""

# ============================================================
# 第一层: 通用与编排
# ============================================================

# ---- 依赖库 / 工具定位 ----
# 均通过 init_tools.sh 部署到 ~/bin (软链), 这里直接 source / 调用
__bom=$'\xEF\xBB\xBF'   # UTF-8 BOM, 解析片源列表时剥离

# 日志库 (log_setup/log/log_pass/...) / CSV 写出 / adb 设备操作
source "${HOME}/bin/_log.sh"
source "${HOME}/bin/_csv.sh"
source "${HOME}/bin/_adb_device.sh"

# 校验层比对工具 (独立 CLI): 软解 + yuv 比对
__cmp_yuv="${HOME}/bin/m_cmp_yuv.sh"

# 生产层流信息探测工具 (独立 CLI): ffprobe 探测宽高/像素格式/帧率/位深/时长
__probe_stream="${HOME}/bin/m_probe_stream.sh"

# 追加日志的目标: 有日志文件则写之, 否则丢弃 (软解/重试等命令输出重定向用)
function log_sink()
{
    printf '%s' "${_log_file:-/dev/null}"
}

# ---- 命令行 ----

function usage()
{
    echo "Usage: $0 [options]"
    echo ""
    echo "Select one device via adbs (or --idx/--soc shortcut), then"
    echo "verify all streams on the device."
    echo ""
    echo "Options:"
    echo "  -l <file>           stream list file (required)," \
         "each line: <codec> <stream path>"
    echo "                       codec must be specified accurately (no auto-detect)"
    echo "  --idx <n>           select device by index, no interactive select"
    echo "  --soc <name>        select device by SoC name, no interactive select"
    echo "  -o <dir>            local output dir (default: rk_dec_verify_out)"
    echo "  --producer <id>     decoder backend that produces yuv/slt," \
         "default mpi_dec_test"
    echo "  -k                  keep stream and decoded yuv on device"
    echo "  --save              keep local soft-decoded yuv"
    echo "  -v                  verbose output"
    echo "  -q                  summary only"
    echo "  --extra <args>      extra decode args, e.g. \"-n 30\""
    echo "  --soft-pixfmt <f>   override soft-decode output pixel format," \
         "e.g. nv12/p010le"
    echo "  --verify-method <m> verify method: yuv/md5/slt, comma-separated, default yuv"
    echo "                       yuv: frame md5 compare with ffmpeg soft decode"
    echo "                       md5: whole-file md5 compare with ffmpeg soft decode"
    echo "                       slt: compare with golden slt data" \
         "(producer must support)"
    echo "  --slt-dir <dir>     golden slt data dir (default: stream dir)"
    echo "  --timeout <sec>     device decode timeout in seconds, default 300"
    echo "  --no-cmp            decode only, skip all compare"
    echo "  -h                  show this help"
    echo ""
    echo "Codec types: h264/h265/vp9/av1/avs2/avs/mpeg2/mpeg4/vp8/mjpeg"
    echo ""
    echo "Examples:"
    echo "  $0 -l streams.list"
    echo "  $0 -l streams.list --idx 2"
    echo "  $0 -l streams.list -o ./out --verify-method yuv,md5"
}

# 取选项值: 缺失时报错并退出 (防止 shift 2 在参数不足时死循环)
function want_val()
{
    [ -n "${2:-}" ] || {
        echo "Error: option $1 requires a value" >&2
        usage >&2
        exit 1
    }
}

function parse_args()
{
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--list)       want_val "$@"; cmd_list_file="$2"; shift 2 ;;
            --idx)           want_val "$@"; cmd_adb_sel_paras="--idx $2"; shift 2 ;;
            --soc)           want_val "$@"; cmd_adb_sel_paras="--soc $2"; shift 2 ;;
            -o|--outdir)     want_val "$@"; cmd_out_dir="$2"; shift 2 ;;
            --producer)      want_val "$@"; cmd_producer="$2"; shift 2 ;;
            -k|--keep)       cmd_keep_dev="1"; shift ;;
            --save)          cmd_save_local="1"; shift ;;
            -v|--verbose)    cmd_verbose="1"; shift ;;
            -q|--quiet)      cmd_quiet="1"; shift ;;
            --extra)         want_val "$@"; cmd_extra_args="$2"; shift 2 ;;
            --soft-pixfmt)   want_val "$@"; cmd_soft_pixfmt="$2"; shift 2 ;;
            --verify-method) want_val "$@"; cmd_verify_method="$2"; shift 2 ;;
            --slt-dir)       want_val "$@"; cmd_slt_dir="$2"; shift 2 ;;
            --timeout)       want_val "$@"; cmd_timeout_sec="$2"; shift 2 ;;
            --no-cmp)        cmd_no_cmp="1"; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               echo "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done

    [ -z "${cmd_list_file}" ] \
        && { echo "Error: no stream list file specified (-l)"; usage; exit 1; }
    [ -f "${cmd_list_file}" ] \
        || { echo "Error: list file not found or not a regular file: ${cmd_list_file}"
             exit 1; }
    [ -z "${cmd_out_dir}" ] && cmd_out_dir="rk_dec_verify_out"

    # 校验验证方法: yuv/md5/slt 逗号组合, all = 全部; 重复方法只保留一次
    [ "${cmd_verify_method}" = "all" ] && cmd_verify_method="yuv,md5,slt"
    [ -z "${cmd_verify_method}" ] && cmd_verify_method="yuv"
    local m vmethod=""
    local -A mseen=()
    for m in ${cmd_verify_method//,/ }; do
        case "${m}" in
            yuv|md5|slt) : ;;
            *) echo "Error: invalid verify method: ${m} (yuv/md5/slt/all)"; exit 1 ;;
        esac
        [ -n "${mseen[${m}]:-}" ] && continue
        mseen["${m}"]=1
        vmethod+="${vmethod:+,}${m}"
    done
    cmd_verify_method="${vmethod}"

    # 超时必须为非负整数 (作为设备端 timeout 参数)
    case "${cmd_timeout_sec}" in
        ''|*[!0-9]*) echo "Error: invalid timeout: ${cmd_timeout_sec}"; exit 1 ;;
    esac
}

# ---- 环境预检 (校验层所需 PC 工具) ----
# 注意: adbs 与解码器属生产层, 由生产层后端自行校验
function check_env()
{
    local tool ff_help
    for tool in ffmpeg stat awk diff wc; do
        command -v "${tool}" >/dev/null 2>&1 || {
            echo "Error: missing PC tool: ${tool}"
            exit 1
        }
    done

    # 校验/生产层依赖的独立工具 (软解比对与流信息探测)
    for tool in "${__cmp_yuv}" "${__probe_stream}"; do
        [ -x "${tool}" ] || {
            echo "Error: helper tool missing or not executable: ${tool}"
            exit 1
        }
    done

    # 老版 ffmpeg 不支持 -dn (disable data streams), 检测后自动去掉
    dn_opt="-dn"
    if ffmpeg -hide_banner -dn -version 2>&1 | grep -qi "unrecognized option"; then
        dn_opt=""
    fi

    # 软解参考必须逐帧原样输出 (时间戳异常的片源会被默认帧率对齐丢弃)
    # 新版 ffmpeg 用 -fps_mode passthrough, 老版回退到等价的 -vsync 0
    # -h full 输出缓存一次, 供下面两条探测复用 (避免重复启动 ffmpeg)
    ff_help=$(ffmpeg -hide_banner -h full 2>/dev/null)
    fps_mode_opt=""
    if grep -q -- "-fps_mode" <<< "${ff_help}"; then
        fps_mode_opt="-fps_mode passthrough"
    elif grep -q -- "-vsync" <<< "${ff_help}"; then
        fps_mode_opt="-vsync 0"
    fi
}

# ---- 片源列表解析 (通用) ----
# 每行必须 <编码类型> <片源路径>, 编码类型合法性由生产层判定
# 说明: 空行/注释行已由调用方过滤, 此处只解析
# 输出(全局): codec_name / strm_path / parse_note

# 解析失败统一日志: $1=stream 显示值 $2=codec 显示值 $3=失败原因
function _stream_fail()
{
    log "========================================"
    log "stream: $1"
    log "codec: $2"
    log_fail "$3"
}

function parse_stream_line()
{
    local line="$1"

    parse_note=""
    # 一次 read 完成拆分: $1=编码名, 其余=片源路径 (内部空格保留, 对含空格路径更准)
    read -r codec_name strm_path <<< "${line}"

    if [ -z "${codec_name}" ]; then
        _stream_fail "${line}" "-" "missing codec type: ${line}"
        parse_note="missing codec type"
        strm_path="${line}"
        return 2
    fi

    if [ -z "${strm_path}" ]; then
        _stream_fail "${line}" "${codec_name}" "missing stream path: ${line}"
        parse_note="missing stream path"
        strm_path="${line}"
        return 2
    fi

    if [ ! -e "${strm_path}" ]; then
        _stream_fail "${strm_path}" "${codec_name}" "stream not found: ${strm_path}"
        parse_note="stream not found"
        return 2
    fi
    return 0
}

# ---- CSV / 输出目录清理 ----

function write_csv_header()
{
    csv_header "${result_csv}" stream codec status hw_frames sw_frames \
        first_diff note
}

# CSV 字段转义/写出: 实现抽离到通用库 0.general_tools/04.csv.sh (csv_field/csv_row/csv_append)

# 清理输出目录历史产物, 每次运行只保留本次结果
function clean_out_dir()
{
    rm -f "${cmd_out_dir}"/rk_dec_verify_*.log \
          "${cmd_out_dir}"/result.csv \
          "${cmd_out_dir}"/*.dec.log \
          "${cmd_out_dir}"/*.dec.logcat \
          "${cmd_out_dir}"/*.yuv \
          "${cmd_out_dir}"/*.slt 2>/dev/null
}

# 中断清理 (委托生产层释放设备侧资源)
function cleanup()
{
    log_warn "interrupt received, cleaning device files..."
    producer_cleanup_once
    exit 130
}

# ============================================================
# 第二层: 校验层 (与 yuv/slt 生成方式无关)
#
# yuv/md5 比对与软解委托给独立 CLI 工具 cmp_yuv (见 __cmp_yuv):
#   软解压缩流 -> yuv, 再与待校验 yuv 逐帧比对 (整段 md5 + 二分定位差异帧)
#
# 入口: verify_run <src> <hw_yuv> <sw_yuv> <cur_slt> <golden_slt>
#   src       - 压缩片源, 作为 ffmpeg 软解参考
#   hw_yuv    - 生产层生成的待校验 yuv
#   sw_yuv    - 校验层软解输出的临时 yuv (文件名由编排层给出)
#   cur_slt   - 生产层生成的 slt (可为空)
#   golden_slt- 期望的 golden slt
# 输出(全局): hw_frames/sw_frames/first_diff/
#             verify_fail_note/verify_method_results
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 3 帧数告警 / 4 生成 golden
# ============================================================

# 获取流信息: 输出到全局变量 strm_w/strm_h/strm_pixfmt/strm_fps/strm_bpp/strm_dur
# 同一文件探测结果缓存 (生产/校验多次调用只 probe 一次)
# 探测委托 probe_stream.sh (原始字段); fps 小数与位深在此按需换算/判定
function get_stream_info()
{
    local strm_file="$1"
    local info k v fps_r="" fps_a=""

    if [ "${info_file}" = "${strm_file}" ] && [ -n "${strm_w}" ]; then
        return 0
    fi
    # 新文件: 先清空旧值, 避免探测失败时残留上一片源的信息
    info_file=""
    strm_w=""; strm_h=""; strm_pixfmt=""; strm_fps=""; strm_bpp=""; strm_dur=""

    info=$("${__probe_stream}" "${strm_file}" 2>/dev/null) || return 1
    while IFS='=' read -r k v; do
        case "${k}" in
            width)          strm_w="${v}" ;;
            height)         strm_h="${v}" ;;
            pix_fmt)        strm_pixfmt="${v}" ;;
            r_frame_rate)   fps_r="${v}" ;;
            avg_frame_rate) fps_a="${v}" ;;
            duration)       strm_dur="${v}" ;;
        esac
    done <<< "${info}"

    if [ -z "${strm_w}" ] || [ -z "${strm_h}" ]; then
        return 1
    fi

    # 由真实帧率分数换算小数 (优先 r_frame_rate, 否则 avg_frame_rate; 无效留空)
    strm_fps=$(awk -v r="${fps_r}" -v a="${fps_a}" 'BEGIN{
        for (i = 1; i <= 2; i++) {
            cand = (i == 1) ? r : a
            if (cand == "" || cand ~ /^0\// || cand ~ /\/0$/) continue
            n = cand; sub(/\/.*/, "", n)
            d = cand; sub(/^[^/]*\//, "", d)
            if (d + 0 > 0) { printf "%.3f", n / d; exit }
        }
    }')

    # 位深由 pix_fmt 判定 (ffprobe 的 bits_per_raw_sample 常缺失)
    case "${strm_pixfmt}" in
        *10le|*10be) strm_bpp=10 ;;
        *12le|*12be) strm_bpp=12 ;;
        *14le|*14be) strm_bpp=14 ;;
        *16le|*16be) strm_bpp=16 ;;
        *)           strm_bpp=8 ;;
    esac

    info_file="${strm_file}"
    return 0
}

# 由流像素格式推断软解输出格式 (与 MPP 硬件输出对齐)
function get_soft_pixfmt()
{
    if [ -n "${cmd_soft_pixfmt}" ]; then
        echo "${cmd_soft_pixfmt}"
        return
    fi

    case "${strm_pixfmt}" in
        yuv420p|yuvj420p)
            echo "nv12" ;;                       # 8bit 420 -> NV12
        yuvj422p)
            echo "nv16" ;;                       # full-range 8bit 422 -> NV16
        yuvj444p)
            echo "nv24" ;;                       # full-range 8bit 444 -> NV24
        yuv420p10le)
            echo "yuv420p10le" ;;                # 10bit 右对齐平面, 后接重排
        yuv420p12le)
            log_warn "${strm_pixfmt} is 12-bit, compare with 12-bit right-aligned output"
            echo "yuv420p12le" ;;
        yuv422p)
            echo "nv16" ;;                       # 8bit 422 -> NV16
        yuv422p10le)
            echo "yuv422p10le" ;;                # 10bit 右对齐平面, 后接重排
        yuv422p12le)
            log_warn "${strm_pixfmt} is 12-bit, compare with 12-bit right-aligned output"
            echo "yuv422p12le" ;;
        yuv444p)
            echo "nv24" ;;                       # 8bit 444 -> NV24
        yuv444p10le)
            echo "yuv444p10le" ;;                # 10bit 右对齐平面, 后接重排
        yuv444p12le)
            log_warn "${strm_pixfmt} is 12-bit, compare with 12-bit right-aligned output"
            echo "yuv444p12le" ;;
        *)
            log_warn "unknown pixel format ${strm_pixfmt}, no format conversion, \
md5 compare may fail"
            echo "" ;;
    esac
}

# 帧大小: 按源像素格式的色度下采样计算 (每采样 >8bit 时 2 字节)
# 4:2:0/4:2:2/4:4:4/4:1:1 覆盖率不同, 不能一律按 4:2:0 的 w*h*1.5 估算
function frame_size()
{
    local w="${strm_w}" h="${strm_h}" bytes=1 us
    [ "${strm_bpp}" -gt 8 ] && bytes=2
    case "${strm_pixfmt}" in
        *444*|nv24|nv42|*p410*|*p412*|*p416*) us=$(( w * h )) ;;
        *422*|nv16|nv61|nv20*|*p210*|*p212*|*p216*) us=$(( (w / 2) * h )) ;;
        *411*)                                 us=$(( (w / 4) * h )) ;;
        *400*|*gray*|*mono*)                   us=0 ;;
        *)                                     us=$(( (w / 2) * (h / 2) )) ;;
    esac
    echo $(( (w * h + us * 2) * bytes ))
}

# 本地软解到 yuv 文件 (委托 cmp_yuv 工具), 供对比或参考帧数使用
function soft_decode()
{
    local strm_file="$1"
    local out_yuv="$2"
    local fmt il args=()

    if ! get_stream_info "${strm_file}"; then
        log_warn "ffprobe cannot get stream info"
        return 1
    fi

    # 软解输出格式; 10bit+ 平面输出需交错重排 (用户显式指定格式时不重排)
    fmt=$(get_soft_pixfmt)
    il=""
    if [ -z "${cmd_soft_pixfmt}" ] && [ "${strm_bpp}" -gt 8 ]; then
        il="${fmt}"
    fi

    args=(-i "${strm_file}" -o "${out_yuv}")
    [ -n "${fmt}" ] && args+=(-f "${fmt}")
    [ -n "${il}" ] && args+=(--uv-interleave "${il}")
    [ -n "${dn_opt}${fps_mode_opt}" ] && \
        args+=(--ffmpeg-args "${dn_opt} ${fps_mode_opt}")

    log_dbg "soft decode: ${__cmp_yuv} ${args[*]}"
    if "${__cmp_yuv}" "${args[@]}" >>"$(log_sink)" 2>&1; then
        return 0
    fi
    return 1
}

# 验证方法 yuv/md5: 软解 (委托 cmp_yuv) + 与 ffmpeg 软解对比
# $4=locate (1=yuv, 逐帧二分定位首个差异帧; 0=md5, 仅整体比对)
# $5=帧大小 (可选, 调用方已算出时复用, 省一次 frame_size)
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 3 帧数不等(公共帧一致)
# sw_prepared=1 时复用已有软解结果 (yuv+md5 方法同一次运行只软解一次)
function soft_compare()
{
    local strm_file="$1"
    local hw_yuv="$2"
    local sw_yuv="$3"
    local locate="$4"
    local fsize="$5" out args r k v

    if [ "${sw_prepared}" != "1" ]; then
        log_dbg "ffprobe: ${strm_w}x${strm_h} ${strm_pixfmt} (${strm_bpp}bit)"
        if ! soft_decode "${strm_file}" "${sw_yuv}"; then
            log_warn "soft decode failed, skip compare"
            return 2
        fi
        sw_prepared="1"
    fi

    [ -n "${fsize}" ] || fsize=$(frame_size)
    args=("${hw_yuv}" "${sw_yuv}" -z "${fsize}")
    [ "${locate}" != "1" ] && args+=(--no-locate)

    out=$("${__cmp_yuv}" "${args[@]}" 2>>"$(log_sink)")
    r=$?

    while IFS='=' read -r k v; do
        case "${k}" in
            yuv1_frames) hw_frames="${v}" ;;
            yuv2_frames) sw_frames="${v}" ;;
            first_diff)  first_diff="${v}" ;;
        esac
    done <<< "${out}"
    [ -n "${out}" ] && log_dbg "cmp_yuv: $(tr '\n' ' ' <<< "${out}")"

    case "${r}" in
        0) return 0 ;;
        1)
            if [ "${locate}" = "1" ] && [ -n "${first_diff}" ] && \
               [ "${first_diff}" != "-" ]; then
                log "first diff frame: ${first_diff} \
(frame $(( first_diff + 1 )), 1-based)"
            else
                log_fail "overall md5 mismatch"
            fi
            return 1 ;;
        3) return 3 ;;
        *) return 2 ;;
    esac
}

# 验证方法 slt: 生产层生成的 slt (每帧一行 crc) 与 golden slt 对比
# $1=本地 slt 文件 $2=golden slt 路径
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 4 新 golden 已生成
function slt_compare()
{
    local cur_slt="$1"
    local golden_slt="$2"
    local cur_cnt gol_cnt

    if [ ! -s "${cur_slt}" ]; then
        log_warn "no slt data generated by decoder"
        return 2
    fi

    if [ ! -f "${golden_slt}" ]; then
        mkdir -p "$(dirname "${golden_slt}")"
        cp -f "${cur_slt}" "${golden_slt}"
        log_warn "no golden slt data, generated new golden: ${golden_slt}"
        return 4
    fi

    cur_cnt=$(wc -l < "${cur_slt}")
    gol_cnt=$(wc -l < "${golden_slt}")
    log_dbg "slt lines: cur ${cur_cnt}, golden ${gol_cnt}"

    if diff -q "${cur_slt}" "${golden_slt}" >/dev/null 2>&1; then
        return 0
    fi
    log_fail "slt data differs from golden slt"
    return 1
}

# 验证方法是否启用: $1=方法名 (yuv/md5/slt)
function method_enabled()
{
    local m
    for m in ${cmd_verify_method//,/ }; do
        [ "${m}" = "$1" ] && return 0
    done
    return 1
}

# 校验层入口: 对生产层产物做校验, 见本层头部说明
function verify_run()
{
    local strm_path="$1"
    local hw_yuv="$2"
    local sw_yuv="$3"
    local cur_slt="$4"
    local golden_slt="$5"
    local cmp_fail cmp_warn cmp_skip slt_gen fsz
    local m r m_pass m_fail m_note

    verify_fail_note=""
    verify_method_results=""

    if ! get_stream_info "${strm_path}"; then
        log_warn "ffprobe cannot get stream info, skip compare"
        return 2
    fi

    # 帧数以 yuv 实际数据为准 (由文件大小 / 每帧字节数算出)
    fsz=$(frame_size)
    hw_frames=$(( $(stat -c %s "${hw_yuv}") / fsz ))

    # 按验证方法逐个执行对比, 任一方法失败则整体失败
    cmp_fail=0
    cmp_warn=0
    cmp_skip=0
    slt_gen=""
    sw_prepared=""   # 与 soft_compare 共享的全局: yuv+md5 复用同一次软解
    for m in ${cmd_verify_method//,/ }; do
        case "${m}" in
            yuv) m_pass="yuv compare: hw decoded yuv matches soft decode"
                 m_fail="yuv compare: hw decoded yuv differs from soft decode"
                 m_note="yuv md5 mismatch"
                 soft_compare "${strm_path}" "${hw_yuv}" "${sw_yuv}" 1 "${fsz}" ;;
            md5) m_pass="md5 compare: hw yuv md5 matches soft decode"
                 m_fail="md5 compare: hw yuv md5 differs from soft decode"
                 m_note="md5 mismatch"
                 soft_compare "${strm_path}" "${hw_yuv}" "${sw_yuv}" 0 "${fsz}" ;;
            slt) m_pass="slt compare: hw slt data matches golden slt"
                 m_fail="slt compare: hw slt data differs from golden slt"
                 m_note="slt mismatch"
                 slt_compare "${cur_slt}" "${golden_slt}" ;;
        esac
        r=$?
        case "${r}" in
            0) log_pass "${m_pass}"; verify_method_results+="${m}=pass," ;;
            1) log_fail "${m_fail}"; verify_fail_note="${m_note}"; cmp_fail=1
               verify_method_results+="${m}=fail," ;;
            3) log_warn "${m} compare: frame count differs \
(hw ${hw_frames} / sw ${sw_frames})"; cmp_warn=1
               verify_method_results+="${m}=warn," ;;
            4) log_warn "slt compare: no golden slt, generated new golden"
               slt_gen="1"; verify_method_results+="${m}=gen," ;;
            *) log_warn "${m} compare: not completed"; cmp_skip=1
               verify_method_results+="${m}=skip," ;;
        esac
    done

    # 清理本地软解 yuv
    if [ "${cmd_save_local}" = "0" ]; then
        rm -f "${sw_yuv}"
    fi

    if [ "${cmp_fail}" = "1" ]; then
        return 1
    fi
    [ "${cmp_warn}" = "1" ] && return 3
    [ "${cmp_skip}" = "1" ] && return 2
    [ "${slt_gen}" = "1" ] && return 4
    return 0
}

# ============================================================
# 第三层: 生产层 (decoder backend; 默认 mpi_dec_test)
#
# 后端接口 (由 producer_<id>_* 实现, 通过 producer_* 分派):
#   producer_<id>_init                一次初始化 (选设备/探测/建目录)
#   producer_<id>_codec_token <name>  编码名 -> 后端 token (非法返回空)
#   producer_<id>_supports_slt        是否支持生成 slt (0=支持)
#   producer_<id>_produce <src> <token> <out_yuv> <out_slt> <want_slt>
#         成功 0 / 失败 1 / 设备掉线 9
#         输出(全局): prod_note
#   producer_<id>_cleanup             释放设备侧资源
# ============================================================

# ---- 后端分派 ----

function producer_dispatch()
{
    local fn="producer_${cmd_producer}_$1"
    shift
    if ! declare -F "${fn}" >/dev/null 2>&1; then
        log_fail "producer backend '${cmd_producer}' missing function: ${fn}"
        return 1
    fi
    "${fn}" "$@"
}

function producer_init()
{
    producer_dispatch init "$@" || return 1
    g_producer_ready="1"
}

function producer_codec_token()   { producer_dispatch codec_token "$@"; }
function producer_supports_slt()  { producer_dispatch supports_slt "$@"; }
function producer_produce()       { producer_dispatch produce "$@"; }
function producer_cleanup()       { producer_dispatch cleanup "$@"; }

# 退出清理: 仅当生产层已初始化且尚未清理时执行一次 (幂等)
function producer_cleanup_once()
{
    [ "${g_producer_ready}" = "1" ] || return 0
    g_producer_ready="0"
    producer_cleanup
}

# ---- 设备与工具 (mpi_dec_test 后端共用) ----
# 设备 I/O 底层实现抽离到通用库 0.general_tools/03.adb_tools/02.adb_device.sh:
#   adev_select/adev_valid/adev_run/adev_shell/adev_push/adev_pull/
#   adev_find_exe/adev_file_size/adev_free_kb/adev_run_capture
#   (选中设备后走 adev_adb)

# 记录环境信息到日志
function log_env_info()
{
    local soc kernel abi mpp_ver
    soc=$(adev_shell \
        "getprop ro.board.platform 2>/dev/null; \
        cat /proc/device-tree/compatible 2>/dev/null" 2>/dev/null \
        | tr '\0' '\n' | tr -d '\r' | head -2 | tr '\n' ' ')
    kernel=$(adev_shell "uname -r" 2>/dev/null | tr -d '\r')
    abi=$(adev_shell "uname -m" 2>/dev/null | tr -d '\r')
    mpp_ver=$(adev_shell "strings /system/lib64/libmpp.so /system/lib/libmpp.so \
        /usr/lib/librockchip_mpp.so /usr/lib/aarch64-linux-gnu/librockchip_mpp.so \
        /usr/local/lib/librockchip_mpp.so 2>/dev/null \
        | grep -m1 version" 2>/dev/null | tr -d '\r')
    log "Device info: SoC=${soc:-unknown} kernel=${kernel:-unknown} abi=${abi:-unknown}"
    if [ -n "${mpp_ver}" ]; then
        log "mpp version: ${mpp_ver}"
    fi
}

function detect_dec_exe()
{
    # 自动探测: 先试默认值 (dev_exe), 再试常见路径
    local found
    found=$(adev_find_exe "${dev_exe}") || {
        # 设备端缺失: 不做编译部署相关操作, 直接报错提示用户自行部署
        log_fail "${dev_exe} not found on device, please deploy it first"
        exit 1
    }
    dev_exe="${found}"
    log_dbg "device decoder: ${dev_exe}"

    # timeout 命令探测 (只需一次), 用于设备端解码超时保护
    adev_shell "command -v timeout" >/dev/null 2>&1 && dev_has_timeout="1"
    return 0
}

# 设备空间预检: $1=本地片源路径, 返回 0 空间足够
function check_dev_space()
{
    local strm_file="$1"
    local strm_size est_yuv dur frames fsz need_kb avail_kb need_mb avail_mb

    strm_size=$(stat -c %s "${strm_file}" 2>/dev/null)
    [ -z "${strm_size}" ] && strm_size=0

    # 预估解码 yuv 大小 (ffprobe 宽高/帧率/时长, get_stream_info 已缓存)
    est_yuv=0
    if get_stream_info "${strm_file}" 2>/dev/null; then
        dur="${strm_dur}"
        fsz=$(frame_size)
        # 仅在有时长且能拿到真实帧率时按帧率估算, 不用默认帧率兜底
        if [ -n "${dur}" ] && [ "${dur}" != "N/A" ] && [ -n "${strm_fps}" ]; then
            frames=$(awk -v d="${dur}" -v f="${strm_fps}" \
                'BEGIN{printf "%d", d*f}')
            [ "${frames}" -lt 2 ] && frames=2
            est_yuv=$(( frames * fsz ))
        fi
    fi
    [ "${est_yuv}" -lt 1 ] && est_yuv=$(( strm_size * 20 ))

    need_kb=$(( (strm_size + est_yuv) / 1024 + 1024 ))
    # adev_free_kb 已校验数字, 失败时返回非 0 且不输出
    if ! avail_kb=$(adev_free_kb "/data"); then
        log_warn "cannot get free space of device /data, skip space check"
        return 0
    fi
    if [ "${avail_kb}" -lt "${need_kb}" ]; then
        need_mb=$((need_kb / 1024))
        avail_mb=$((avail_kb / 1024))
        log_fail "insufficient space on device /data:" \
            "need ~${need_mb} MB, have ${avail_mb} MB"
        return 1
    fi
    log_dbg "device space check passed: need ~$((need_kb/1024)) MB," \
        "have $((avail_kb/1024)) MB"
    return 0
}

# ---- 解码执行与重试 ----

# 重试执行: $1=描述, 其余为命令; 成功返回 0
function retry_run()
{
    local desc="$1"
    shift
    local tries=3 attempt=1
    while [ "${attempt}" -le "${tries}" ]; do
        if "$@" >>"$(log_sink)" 2>&1; then
            return 0
        fi
        if [ "${attempt}" -lt "${tries}" ]; then
            log_warn "${desc} failed (attempt ${attempt}), retrying..."
            sleep 2
        fi
        attempt=$(( attempt + 1 ))
    done
    return 1
}

# 执行一次设备端解码 (含 logcat 采集)
# $1=shell 命令 $2=解码日志(cmd_out) $3=logcat 日志 $4=设备端 yuv 路径
# 输出(全局): dec_ret, dev_size
function producer_decode_once()
{
    local shell_cmd="$1" dec_log="$2" logcat_log="$3" dev_yuv="$4"
    adev_run_capture "${shell_cmd}" "${dec_log}" "${logcat_log}"
    dec_ret="${adev_ret}"
    dev_size=$(adev_file_size "${dev_yuv}")
}

# 失败收尾: 设备掉线则置 prod_note 并返回 9 (调用方据此终止整个运行),
# 否则置 $1 并返回 1; 供 produce 的各失败分支复用
function _fail_or_disconnect()
{
    if ! adev_valid; then
        prod_note="device disconnected"
        return 9
    fi
    prod_note="$1"
    return 1
}

# ---- mpi_dec_test 后端 ----

function producer_mpi_dec_test_init()
{
    adev_select ${cmd_adb_sel_paras} || return 1
    log "device selected: ${adev_adb}"
    log_env_info
    detect_dec_exe
    adev_shell "mkdir -p '${dev_work_dir}'" >/dev/null 2>&1
    return 0
}

# 编码名(小写) -> mpi_dec_test -t 数值 (后端私有)
function producer_mpi_dec_test_codec_token()
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
        *)                : ;;
    esac
}

function producer_mpi_dec_test_supports_slt()
{
    return 0
}

# 生成 yuv (want_slt=1 时附带生成 slt)
function producer_mpi_dec_test_produce()
{
    local src="$1"
    local ctype="$2"
    local out_yuv="$3"
    local out_slt="$4"
    local want_slt="$5"
    local name dev_name dev_strm dev_yuv dev_slt dec_log dec_logcat
    local dec_cmd shell_cmd pull_size

    prod_note=""
    name=$(basename "${src}")
    # 设备端文件名清洗, 避免空格/引号/斜杠破坏远端 shell 命令
    dev_name=$(printf '%s' "${name}" | tr -c 'A-Za-z0-9._-' '_')
    dev_strm="${dev_work_dir}/${dev_name}"
    dev_yuv="${dev_work_dir}/${dev_name}.yuv"
    dev_slt=""
    dec_log="${cmd_out_dir}/${name}.dec.log"
    dec_logcat="${cmd_out_dir}/${name}.dec.logcat"

    # 空间预检
    if ! check_dev_space "${src}"; then
        prod_note="insufficient device space"
        return 1
    fi

    # push 片源到设备 (带重试)
    log_dbg "push ${src} -> ${dev_strm}"
    if ! retry_run "push" adev_push "${src}" "${dev_strm}"; then
        log_fail "push failed: ${src}"
        _fail_or_disconnect "push failed"
        return $?
    fi

    # 构建设备端解码命令
    dec_cmd="cd ${dev_work_dir} && ${dev_exe} -i ${dev_name} -o ${dev_name}.yuv"
    [ -n "${ctype}" ] && dec_cmd="${dec_cmd} -t ${ctype}"
    [ -n "${cmd_extra_args}" ] && dec_cmd="${dec_cmd} ${cmd_extra_args}"
    if [ "${want_slt}" = "1" ]; then
        dev_slt="${dev_work_dir}/${dev_name}.slt"
        dec_cmd="${dec_cmd} -slt ${dev_name}.slt"
    fi
    log_dbg "device decode: ${dec_cmd}"
    if [ "${dev_has_timeout}" = "1" ]; then
        # 内层命令嵌入 sh -c '...' 前转义单引号, 避免 --extra 含引号时截断/注入
        shell_cmd="timeout ${cmd_timeout_sec} sh -c $(adev_quote "${dec_cmd}")"
    else
        shell_cmd="${dec_cmd}"
    fi

    # 解码 (失败重试一次, 可能为瞬时失败)
    producer_decode_once "${shell_cmd}" "${dec_log}" "${dec_logcat}" "${dev_yuv}"
    if [ "${dec_ret}" -ne 0 ] || [ -z "${dev_size}" ] || [ "${dev_size}" -le 0 ]; then
        log_warn "decode failed (ret=${dec_ret}), retrying once..."
        sleep 2
        adev_shell "rm -f '${dev_yuv}' '${dev_slt}'" >/dev/null 2>&1
        producer_decode_once "${shell_cmd}" "${dec_log}" "${dec_logcat}" "${dev_yuv}"
    fi
    if [ "${dec_ret}" -ne 0 ] || [ -z "${dev_size}" ] || [ "${dev_size}" -le 0 ]; then
        log_fail "decode failed (ret=${dec_ret})"
        log_dbg "tail of decode log:"
        log_dbg "$(tail -n 5 "${dec_log}")"
        _fail_or_disconnect "decode failed ret=${dec_ret}"
        return $?
    fi

    # 帧数一律以产出的 yuv 为准 (不再解析解码日志)
    log "decode done: ${dev_size} bytes"

    # pull yuv 到 PC (带重试)
    log_dbg "pull ${dev_yuv} -> ${out_yuv}"
    if ! retry_run "pull" adev_pull "${dev_yuv}" "${out_yuv}"; then
        log_fail "pull failed"
        _fail_or_disconnect "pull failed"
        return $?
    fi

    # pull 完整性校验
    pull_size=$(stat -c %s "${out_yuv}" 2>/dev/null)
    if [ "${pull_size}" != "${dev_size}" ]; then
        log_fail "pull integrity check failed: device ${dev_size}, local ${pull_size}"
        prod_note="pull integrity check failed"
        return 1
    fi

    # pull slt
    if [ "${want_slt}" = "1" ]; then
        log_dbg "pull ${dev_slt} -> ${out_slt}"
        if ! retry_run "pull slt" adev_pull "${dev_slt}" "${out_slt}"; then
            log_fail "pull slt failed"
            _fail_or_disconnect "pull slt failed"
            return $?
        fi
    fi

    # 删除设备上的片源和解码产物
    if [ "${cmd_keep_dev}" = "0" ]; then
        adev_shell "rm -f '${dev_strm}' '${dev_yuv}' '${dev_slt}'" >/dev/null 2>&1
    fi
    return 0
}

function producer_mpi_dec_test_cleanup()
{
    if [ -n "${adev_adb}" ] && [ "${cmd_keep_dev}" = "0" ]; then
        adev_shell "rm -rf '${dev_work_dir}'" >/dev/null 2>&1
    fi
}

# ============================================================
# 编排入口 (组合生产层与校验层)
# ============================================================

# 单个片源验证: $1=片源路径 $2=编码名
# 输出(全局, 供 main 汇总): hw_frames/sw_frames/first_diff/
#                           verify_fail_note/verify_method_results
function verify_one()
{
    local strm_path="$1"
    local codec_name="$2"
    local name hw_yuv sw_yuv slt_file golden_slt want_slt ctype pstat fsize

    name=$(basename "${strm_path}")
    hw_yuv="${cmd_out_dir}/${name}.yuv"
    sw_yuv="${cmd_out_dir}/${name}.sw.yuv"
    slt_file="${cmd_out_dir}/${name}.slt"

    verify_fail_note=""
    verify_method_results=""
    log "========================================"
    log "stream: ${strm_path}"
    log "codec: ${codec_name}"

    # 编码合法性由生产层判定
    ctype=$(producer_codec_token "${codec_name}")
    if [ -z "${ctype}" ]; then
        log_fail "invalid codec type: ${codec_name}"
        verify_fail_note="invalid codec type"
        return 1
    fi

    # 是否需要生成 slt 产物 (校验层启用 slt 且生产层支持)
    want_slt="0"
    if [ "${cmd_no_cmp}" = "0" ] && method_enabled slt; then
        if producer_supports_slt; then
            want_slt="1"
        else
            log_warn "producer ${cmd_producer} does not support slt, slt verify skipped"
        fi
    fi

    # ---- 生产层: 生成 yuv (及可选 slt) ----
    producer_produce "${strm_path}" "${ctype}" "${hw_yuv}" "${slt_file}" "${want_slt}"
    pstat=$?
    if [ "${pstat}" != "0" ]; then
        if [ "${pstat}" = "9" ]; then
            verify_fail_note="${prod_note:-device disconnected}"
            return 9
        fi
        # 生产失败: 可选软解提供参考帧数
        if soft_decode "${strm_path}" "${sw_yuv}"; then
            fsize=$(frame_size)
            sw_frames=$(( $(stat -c %s "${sw_yuv}") / fsize ))
            log "soft decode done: ${sw_frames} frames (reference)"
        fi
        [ "${cmd_save_local}" = "0" ] && rm -f "${sw_yuv}"
        verify_fail_note="${prod_note:-decode failed}"
        return 1
    fi

    # 仅解码不比对
    if [ "${cmd_no_cmp}" = "1" ]; then
        log_pass "decode done (no compare)"
        return 0
    fi

    # ---- 校验层: 对比产物 ----
    golden_slt="$(dirname "${strm_path}")/${name}.slt"
    [ -n "${cmd_slt_dir}" ] && golden_slt="${cmd_slt_dir}/${name}.slt"
    verify_run "${strm_path}" "${hw_yuv}" "${sw_yuv}" "${slt_file}" \
        "${golden_slt}"
    return $?
}

function main()
{
    local line ret i m st diff_v note_v vret kv v key trimmed
    local m_pass m_warn m_fail m_gen m_skip m_fail_list m_warn_list
    local total=0 abort_run="0" pass=0 warn=0 fail=0 has_method="0"
    local -A seen=()
    local -a result_stream=() result_status=() result_note=() result_methods=()

    parse_args "$@"
    check_env
    trap producer_cleanup_once EXIT
    trap cleanup INT TERM

    # 实例锁: 防止多个实例并行写同一输出目录 (结果会互相污染)
    # flock 缺失时降级: 告警并继续, 不加锁
    mkdir -p "${cmd_out_dir}"
    if command -v flock >/dev/null 2>&1; then
        exec 9>"${cmd_out_dir}/.rk_verify.lock"
        if ! flock -n 9; then
            echo "Error: another rk_dec_verify instance is running"
            echo "       (lock file: ${cmd_out_dir}/.rk_verify.lock)"
            exit 1
        fi
    else
        echo "Warning: flock not found, skip instance lock" >&2
    fi
    # 清理历史结果
    clean_out_dir

    ts=$(date +%Y%m%d_%H%M%S)
    log_setup "${cmd_out_dir}/rk_dec_verify_${ts}.log" "${cmd_quiet}" "${cmd_verbose}"
    result_csv="${cmd_out_dir}/result.csv"
    : >"$(log_sink)"
    write_csv_header

    log_summary "==== RK decode verify started: $(date) ===="
    log_summary "list file: ${cmd_list_file}"
    log_summary "producer: ${cmd_producer}"

    # 生产层初始化 (选设备 / 探测工具 / 建工作目录)
    producer_init || exit 1

    while IFS= read -r line <&3 || [ -n "${line}" ]; do
        # 容忍 Windows(CRLF) 换行与文件开头 BOM
        line="${line%$'\r'}"
        line="${line#"${__bom}"}"
        # 去掉行首空白后再判断: 仅空白行/注释行跳过 (容忍行首空白)
        trimmed="${line#"${line%%[![:space:]]*}"}"
        case "${trimmed}" in
            ''|\#*) continue ;;
        esac

        parse_stream_line "${line}"
        ret=$?

        # 列表去重: 同一片源只处理一次 (关联数组 O(1))
        # 键按绝对路径归一, 使 ./a 与 a 视为同一片源
        if [ -n "${strm_path}" ]; then
            key="${strm_path}"
            [ -e "${strm_path}" ] && key=$(readlink -f "${strm_path}")
            if [[ -n "${seen[${key}]:-}" ]]; then
                log_warn "duplicate stream in list, skip: ${strm_path}"
                continue
            fi
            seen["${key}"]=1
        fi

        total=$(( total + 1 ))
        if [ "${ret}" = "2" ]; then
            fail=$(( fail + 1 ))
            note_v="${parse_note:-invalid stream/codec}"
            result_stream+=("${strm_path}")
            result_status+=("FAIL")
            result_note+=("${note_v}")
            result_methods+=("-")
            csv_append "${result_csv}" "${strm_path}" "${codec_name:--}" "FAIL" \
                "-" "-" "-" "${note_v}"
            continue
        fi

        # 复位对比结果变量, 防止上次残留
        hw_frames=""
        sw_frames=""
        first_diff=""

        verify_one "${strm_path}" "${codec_name}"
        vret=$?

        result_stream+=("${strm_path}")
        case "${vret}" in
            0) pass=$(( pass + 1 )); st="PASS"; diff_v="-"; note_v="" ;;
            4) pass=$(( pass + 1 )); st="PASS"; diff_v="-"
               note_v="slt golden generated" ;;
            3) warn=$(( warn + 1 )); st="WARN"; diff_v="-"
               note_v="frame count mismatch hw=${hw_frames} sw=${sw_frames}" ;;
            2) warn=$(( warn + 1 )); st="SKIP"; diff_v="-"
               note_v="compare unavailable" ;;
            9) fail=$(( fail + 1 )); st="FAIL"; diff_v="-"
               note_v="device disconnected, abort remaining streams"
               abort_run="1" ;;
            *) fail=$(( fail + 1 )); st="FAIL"; diff_v="${first_diff:--}"
               note_v="${verify_fail_note:-md5 mismatch}" ;;
        esac
        result_status+=("${st}")
        result_note+=("${note_v}")
        result_methods+=("${verify_method_results}")
        [ -n "${verify_method_results}" ] && has_method="1"
        csv_append "${result_csv}" "${strm_path}" "${codec_name}" "${st}" \
            "${hw_frames:--}" "${sw_frames:--}" \
            "${diff_v}" "${note_v}"
        # 设备掉线: 剩余片源全部跳过, 直接结束循环 (note 已记录在 result)
        if [ "${abort_run}" = "1" ]; then
            break
        fi
    done 3<"${cmd_list_file}"

    # 汇报验证结果
    log_summary ""
    log_summary "========================================"
    log_summary "verify summary (${total} streams, PASS ${pass}," \
        "WARN ${warn}, FAIL ${fail})"
    log_summary "========================================"
    # 刷新导出颜色变量, 使其匹配当前 TTY 状态(log_summary 会为文件/非终端自动去色)
    log_refresh
    for (( i = 0; i < total; i++ )); do
        st="${result_status[$i]}"
        if [ "${st}" = "PASS" ]; then
            log_summary "  ${_log_green}[PASS] ${result_stream[$i]}${_log_nc}"
        elif [ "${st}" = "WARN" ] || [ "${st}" = "SKIP" ]; then
            log_summary "  ${_log_yellow}[${st}] ${result_stream[$i]}" \
                "(${result_note[$i]})${_log_nc}"
        else
            log_summary "  ${_log_red}[FAIL] ${result_stream[$i]}" \
                "(${result_note[$i]})${_log_nc}"
        fi
    done

    # 按校验方式分类汇总 (无任何片源进入校验时跳过)
    if [ "${cmd_no_cmp}" = "0" ] && [ "${total}" -gt 0 ] && \
       [ "${has_method}" = "1" ]; then
        log_summary ""
        log_summary "==== per-method summary ===="
        for m in ${cmd_verify_method//,/ }; do
            m_pass=0; m_warn=0; m_fail=0; m_gen=0; m_skip=0
            m_fail_list=""; m_warn_list=""
            for (( i = 0; i < total; i++ )); do
                # 未进入校验的片源 (parse 失败 / 非法 codec / 掉线) 不参与 per-method 统计
                case "${result_methods[$i]}" in
                    ''|-) continue ;;
                esac
                v=""
                for kv in ${result_methods[$i]//,/ }; do
                    case "${kv}" in
                        "${m}="*) v="${kv#*=}" ;;
                    esac
                done
                case "${v}" in
                    pass) m_pass=$(( m_pass + 1 )) ;;
                    fail) m_fail=$(( m_fail + 1 ))
                          m_fail_list="${m_fail_list} ${result_stream[$i]}," ;;
                    warn) m_warn=$(( m_warn + 1 ))
                          m_warn_list="${m_warn_list} ${result_stream[$i]}," ;;
                    gen)  m_gen=$(( m_gen + 1 )) ;;
                    *)    m_skip=$(( m_skip + 1 )) ;;
                esac
            done
            log_summary "  [${m}] PASS ${m_pass}, WARN ${m_warn}, FAIL ${m_fail}, \
GEN ${m_gen}, SKIP ${m_skip}"
            [ "${m_fail}" -gt 0 ] && \
                log_summary "    FAIL:${m_fail_list%,}"
            [ "${m_warn}" -gt 0 ] && \
                log_summary "    WARN:${m_warn_list%,}"
        done
    fi

    log_summary "result CSV: ${result_csv}"
    log_summary "detail log: ${_log_file:-<disabled>}"

    # 设备侧资源由 EXIT trap (producer_cleanup_once) 释放
    [ "${fail}" -gt 0 ] && exit 1
    exit 0
}

main "$@"
