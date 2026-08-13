#!/usr/bin/env bash
#########################################################################
# File Name: rk_dec_verify.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Tue 11 Aug 2026 04:31:12 PM CST
#########################################################################

# ============================================================
# RK 硬件解码验证脚本
#
# 功能:
#   1. 用户给定片源列表
#   2. 将每个片源推送到指定设备
#   3. 设备上用 mpi_dec_test 解码得到 yuv
#      (slt 验证模式附带生成 crc slt 数据)
#   4. adb pull 到 PC
#   5. 按用户选定的校验方式 (--verify-method) 验证解码 yuv 是否正确:
#      yuv - ffmpeg 软解 + 逐帧数据比对, 定位首个差异帧
#      md5 - ffmpeg 软解 + 整体 md5 比对
#      slt - 与 golden slt 数据比对, 无 golden 时生成
#   6. 删除设备上的片源和解码产物
#   7. 按校验方式分类汇总验证结果
#
# 片源列表格式 (每行): <编码类型> <片源路径>
#   编码类型必须准确指定:
#   h264/h265/vp9/av1/avs2/avs/mpeg2/mpeg4/vp8/mjpeg
#   编码类型不对或缺失时该片源直接判 FAIL
# ============================================================

# ==================== 全局配置 ====================

# 设备端工作目录 (shell 可写, 无需 root)
dev_work_dir="/data/tmp/rk_verify"

# 设备端 mpi_dec_test 名称 (detect_dec_exe 自动探测设备端路径并回填)
dev_exe="mpi_dec_test"

# 参数
cmd_list_file=""        # 片源列表文件
cmd_out_dir=""          # 本地输出目录
cmd_keep_dev="0"        # 保留设备文件
cmd_save_local="0"      # 保留本地软解 yuv
cmd_verbose="0"         # 详细输出
cmd_quiet="0"           # 仅输出汇总
cmd_extra_args=""       # 附加解码参数
cmd_soft_pixfmt=""      # 覆盖软解输出格式
cmd_no_cmp="0"          # 仅解码, 不做 md5 对比
cmd_verify_method="yuv" # 验证方法: yuv/md5/slt, 逗号分隔可组合, all=全部
cmd_slt_dir=""          # slt golden 数据目录 (默认片源同目录)
cmd_timeout_sec="300"   # 设备端解码超时 (秒)
cmd_adb_sel_paras=""    # 单设备快捷选择参数 (adbs --idx/--soc)

adb_cmd=""
log_file=""
result_csv=""
ts=""

# ==================== 编码类型映射 ====================

# 编码名(小写) -> mpi_dec_test -t 数值
codec_type_map="h264:7
avc:7
h265:16777220
hevc:16777220
vp9:10
av1:16777224
avs2:16777223
avs:6
mpeg2:2
mpeg2video:2
mpeg4:4
vp8:9
mjpeg:8
jpeg:8"

# ==================== 基础工具函数 ====================

function usage()
{
    echo "Usage: $0 [options]"
    echo ""
    echo "Select one device via adbs (or --idx/--soc shortcut), then"
    echo "verify all streams on the device."
    echo ""
    echo "Options:"
    echo "  -l <file>           stream list file (required), each line: <codec> <stream path>"
    echo "                       codec must be specified accurately (no auto-detect)"
    echo "  --idx <n>           select device by index, no interactive select"
    echo "  --soc <name>        select device by SoC name, no interactive select"
    echo "  -o <dir>            local output dir (default: rk_dec_verify_out)"
    echo "  -k                  keep stream and decoded yuv on device"
    echo "  --save              keep local soft-decoded yuv"
    echo "  -v                  verbose output"
    echo "  -q                  summary only"
    echo "  --extra <args>      extra decode args, e.g. \"-n 30\""
    echo "  --soft-pixfmt <f>   override soft-decode output pixel format, e.g. nv12/p010le"
    echo "  --verify-method <m> verify method: yuv/md5/slt, comma-separated, default yuv"
    echo "                       yuv: frame md5 compare with ffmpeg soft decode"
    echo "                       md5: whole-file md5 compare with ffmpeg soft decode"
    echo "                       slt: compare with golden slt data (mpi_dec_test -slt)"
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
    echo "  $0 -l streams.list -o ./out"
}

# 注意: 常规日志走 stderr, 避免被 $(...) 命令替换捕获 (如 get_soft_pixfmt 内部)
# quiet 模式下常规日志静默, log_summary 不受影响
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; NC="\033[0m"
function q_gate()      { [ "${cmd_quiet}" = "1" ] && return 1; return 0; }
function log_line()    { q_gate || return; echo -e "$*" | tee -a "${log_file}" >&2; }
function log()         { q_gate || return; echo "$*" | tee -a "${log_file}" >&2; }
function log_dbg()     { [ "${cmd_verbose}" = "1" ] && log "$*"; }
function log_pass()    { log_line "${GREEN}[PASS] $*${NC}"; }
function log_fail()    { log_line "${RED}[FAIL] $*${NC}"; }
function log_warn()    { log_line "${YELLOW}[WARN] $*${NC}"; }
function log_summary() { echo -e "$*" >>"${log_file}"; echo -e "$*"; }

function parse_args()
{
    while [ $# -gt 0 ]; do
        case "$1" in
            -l|--list)       cmd_list_file="$2"; shift 2 ;;
            --idx)           cmd_adb_sel_paras="--idx $2"; shift 2 ;;
            --soc)           cmd_adb_sel_paras="--soc $2"; shift 2 ;;
            -o|--outdir)     cmd_out_dir="$2"; shift 2 ;;
            -k|--keep)       cmd_keep_dev="1"; shift ;;
            --save)          cmd_save_local="1"; shift ;;
            -v|--verbose)    cmd_verbose="1"; shift ;;
            -q|--quiet)      cmd_quiet="1"; shift ;;
            --extra)         cmd_extra_args="$2"; shift 2 ;;
            --soft-pixfmt)   cmd_soft_pixfmt="$2"; shift 2 ;;
            --verify-method) cmd_verify_method="$2"; shift 2 ;;
            --slt-dir)       cmd_slt_dir="$2"; shift 2 ;;
            --timeout)       cmd_timeout_sec="$2"; shift 2 ;;
            --no-cmp)        cmd_no_cmp="1"; shift ;;
            -h|--help)       usage; exit 0 ;;
            *)               echo "Unknown argument: $1"; usage; exit 1 ;;
        esac
    done

    [ -z "${cmd_list_file}" ] \
        && { echo "Error: no stream list file specified (-l)"; usage; exit 1; }
    [ -e "${cmd_list_file}" ] \
        || { echo "Error: list file not found: ${cmd_list_file}"; exit 1; }
    [ -z "${cmd_out_dir}" ] && cmd_out_dir="rk_dec_verify_out"

    # 校验验证方法: yuv/md5/slt 逗号组合, all = 全部
    if [ "${cmd_verify_method}" = "all" ]; then
        cmd_verify_method="yuv,md5,slt"
    fi
    [ -z "${cmd_verify_method}" ] && cmd_verify_method="yuv"
    for m in ${cmd_verify_method//,/ }; do
        case "${m}" in
            yuv|md5|slt) : ;;
            *) echo "Error: invalid verify method: ${m} (yuv/md5/slt/all)"; exit 1 ;;
        esac
    done
}

# ==================== 环境预检 ====================

function check_env()
{
    for tool in ffmpeg ffprobe adbs md5sum dd stat awk perl diff wc; do
        command -v "${tool}" >/dev/null 2>&1 || {
            echo "Error: missing PC tool: ${tool}"
            exit 1
        }
    done

    # 老版 ffmpeg 不支持 -dn (disable data streams), 检测后自动去掉
    dn_opt="-dn"
    if ffmpeg -hide_banner -dn -version 2>&1 | grep -qi "unrecognized option"; then
        dn_opt=""
    fi
}

# ==================== 设备相关 ====================

# 当前 adb_cmd 是否有可用设备
function check_dev_valid()
{
    ${adb_cmd} devices 2>/dev/null | grep -q "device$"
}

# 选择设备: --idx/--soc 快捷选择, 否则弹出 adbs 交互选择
# 返回: 0=设备可用, 1=用户取消(无输出)或设备不可用
function init_adb()
{
    # 注意: 不能加 2>&1, adbs 的交互选择界面走 stderr,
    #       吞掉后界面不显示且 adb_cmd 会被界面文本污染
    adb_cmd=$(adbs ${cmd_adb_sel_paras})
    [ -z "${adb_cmd}" ] && {
        echo "Error: no device found${cmd_adb_sel_paras:+ for ${cmd_adb_sel_paras}}"
        return 1
    }
    log_dbg "adb cmd: ${adb_cmd}"
    return 0
}

# < /dev/null: 防止 adb 消费 while read 循环的 stdin
function run_adb() { ${adb_cmd} "$@" < /dev/null; }

# 执行设备 shell 命令, 返回 stdout
function run_shell() { ${adb_cmd} shell "$@" < /dev/null; }

# 记录环境信息到日志
function log_env_info()
{
    soc=$(run_shell \
        "getprop ro.board.platform 2>/dev/null; \
        cat /proc/device-tree/compatible 2>/dev/null" 2>/dev/null \
        | tr '\0' '\n' | tr -d '\r' | head -2 | tr '\n' ' ')
    kernel=$(run_shell "uname -r" 2>/dev/null | tr -d '\r')
    abi=$(run_shell "uname -m" 2>/dev/null | tr -d '\r')
    mpp_ver=$(run_shell "strings /system/lib64/libmpp.so /system/lib/libmpp.so \
        /usr/lib/librockchip_mpp.so /usr/lib/aarch64-linux-gnu/librockchip_mpp.so \
        /usr/local/lib/librockchip_mpp.so 2>/dev/null \
        | grep -m1 version" 2>/dev/null | tr -d '\r')
    log "Device info: SoC=${soc:-unknown} kernel=${kernel:-unknown} abi=${abi:-unknown}"
    [ -n "${mpp_ver}" ] && log "mpp version: ${mpp_ver}"
}

function detect_dec_exe()
{
    # 自动探测: 先试默认值 (dev_exe), 再试常见路径
    for path in "${dev_exe}" "/system/bin/${dev_exe}" "/vendor/bin/${dev_exe}"; do
        [ -n "${path}" ] && run_shell "command -v '${path}'" >/dev/null 2>&1 && {
            dev_exe="${path}"
            log_dbg "device decoder: ${dev_exe}"
            return
        }
    done

    # 设备端缺失: 不做编译部署相关操作, 直接报错提示用户自行部署
    log_fail "${dev_exe} not found on device, please deploy it first"
    exit 1
}

# 设备空间预检: $1=本地片源路径, 返回 0 空间足够
function check_dev_space()
{
    strm_file="$1"
    strm_size=$(stat -c %s "${strm_file}" 2>/dev/null)
    [ -z "${strm_size}" ] && strm_size=0

    # 预估解码 yuv 大小 (用 ffprobe 宽高和时长, get_stream_info 已缓存)
    est_yuv=0
    if get_stream_info "${strm_file}" 2>/dev/null; then
        dur="${strm_dur}"
        if [ -n "${dur}" ] && [ "${dur}" != "N/A" ]; then
            frames=$(awk -v d="${dur}" 'BEGIN{printf "%d", d*30}')
            [ "${frames}" -lt 2 ] && frames=2
            est_yuv=$(( frames * strm_w * strm_h * 3 ))
        fi
    fi
    [ "${est_yuv}" -lt 1 ] && est_yuv=$(( strm_size * 20 ))

    need_kb=$(( (strm_size + est_yuv) / 1024 + 1024 ))
    avail_kb=$(run_shell "df -P /data 2>/dev/null | tail -1" 2>/dev/null \
        | awk '{print $4}' | tr -d '\r')
    if [ -z "${avail_kb}" ] || ! echo "${avail_kb}" | grep -qE '^[0-9]+$'; then
        log_warn "cannot get free space of device /data, skip space check"
        return 0
    fi
    if [ "${avail_kb}" -lt "${need_kb}" ]; then
        need_mb=$((need_kb / 1024))
        avail_mb=$((avail_kb / 1024))
        log_fail "insufficient space on device /data: need ~${need_mb} MB, have ${avail_mb} MB"
        return 1
    fi
    log_dbg "device space check passed: need ~$((need_kb/1024)) MB, have $((avail_kb/1024)) MB"
    return 0
}

# ==================== 编码类型解析 ====================

# 每行必须 <编码类型> <片源路径>, 编码类型由用户准确指定, 不做 ffprobe 探测
function parse_stream_line()
{
    line="$1"
    parse_note=""
    [ -z "${line}" ] && return 1
    case "${line}" in
        \#*|[[:space:]]*\#*|[[:space:]]*) return 1 ;;  # 空行/注释行
        *) : ;;
    esac

    strm_name="$(echo "${line}" | awk '{print $1}')"
    strm_path="$(echo "${line}" | awk '{$1=""; sub(/^ +/, ""); print}')"

    ctype=$(echo "${codec_type_map}" | awk -F: -v n="${strm_name}" \
            'tolower($1)==tolower(n){print $2; exit}')
    if [ -z "${ctype}" ]; then
        log "========================================"
        log "stream: ${line}"
        log "codec: -"
        log_fail "invalid codec type: ${strm_name}"
        log "expected: h264/h265/vp9/av1/avs2/avs/mpeg2/mpeg4/vp8/mjpeg"
        parse_note="invalid codec type"
        return 2
    fi

    [ -z "${strm_path}" ] && {
        log "========================================"
        log "stream: ${line}"
        log "codec: -"
        log_fail "missing stream path: ${line}"
        parse_note="missing stream path"
        return 2
    }

    [ -e "${strm_path}" ] || {
        log "========================================"
        log "stream: ${strm_path}"
        log "codec: -"
        log_fail "stream not found: ${strm_path}"
        parse_note="stream not found"
        return 2
    }
    return 0
}

# ==================== 软解对比 ====================

# 获取流信息: 输出到全局变量 strm_w/strm_h/strm_pixfmt/strm_bpp/strm_dur
# 同一文件探测结果缓存 (check_dev_space/verify_one 多次调用只 probe 一次)
function get_stream_info()
{
    strm_file="$1"
    if [ "${info_file}" = "${strm_file}" ] && [ -n "${strm_w}" ]; then
        return 0
    fi

    info=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,pix_fmt:format=duration \
        -of csv=p=0 "${strm_file}" 2>/dev/null)
    [ -z "${info}" ] && return 1

    strm_w=$(echo "${info}" | sed -n '1p' | cut -d, -f1)
    strm_h=$(echo "${info}" | sed -n '1p' | cut -d, -f2)
    strm_pixfmt=$(echo "${info}" | sed -n '1p' | cut -d, -f3)
    strm_dur=$(echo "${info}" | sed -n '2p')
    [ -z "${strm_w}" ] || [ -z "${strm_h}" ] && return 1

    # 位深: pix_fmt 后 4 字符为 10le/12le/14le/16le 则为对应位深
    strm_bpp=8
    case "${strm_pixfmt}" in
        *10le) strm_bpp=10 ;;
        *12le) strm_bpp=12 ;;
        *14le) strm_bpp=14 ;;
        *16le) strm_bpp=16 ;;
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
        *)
            log_warn "unknown pixel format ${strm_pixfmt}, no format conversion, \
md5 compare may fail"
            echo "" ;;
    esac
}

# 帧大小 = w*h*1.5 (8bit) 或 w*h*3 (10bit+)
function frame_size()
{
    if [ "${strm_bpp}" -le 8 ]; then
        echo $(( strm_w * strm_h * 3 / 2 ))
    else
        echo $(( strm_w * strm_h * 3 ))
    fi
}

# 取第 n 帧 md5
function frame_md5()
{
    yuv_file="$1"
    fsize="$2"
    idx="$3"
    dd if="${yuv_file}" bs="${fsize}" count=1 skip="${idx}" 2>/dev/null | md5sum | awk '{print $1}'
}

# 逐帧对比 (抽样定位 + 区间精查), 输出首个差异帧号, 无差异输出 -1
function find_first_diff()
{
    hw_yuv="$1"
    sw_yuv="$2"
    fsize="$3"
    frames="$4"

    step=$(( frames / 100 ))
    [ "${step}" -lt 1 ] && step=1

    # 帧 0 单独检查
    if [ "$(frame_md5 "${hw_yuv}" "${fsize}" 0)" != "$(frame_md5 "${sw_yuv}" "${fsize}" 0)" ]; then
        echo 0
        return
    fi

    prev=0
    for (( i = step; i < frames; i += step )); do
        if [ "$(frame_md5 "${hw_yuv}" "${fsize}" "${i}")" != \
             "$(frame_md5 "${sw_yuv}" "${fsize}" "${i}")" ]; then
            # 区间 (prev, i] 内逐帧精查
            for (( j = prev + 1; j <= i; j++ )); do
                if [ "$(frame_md5 "${hw_yuv}" "${fsize}" "${j}")" != \
                     "$(frame_md5 "${sw_yuv}" "${fsize}" "${j}")" ]; then
                    echo "${j}"
                    return
                fi
            done
        fi
        prev="${i}"
    done
    # 兜底: 差异帧可能在采样点之间 (采样点均一致时), 全查所有非采样帧
    for (( j = 1; j < frames; j++ )); do
        [ $(( j % step )) -eq 0 ] && continue
        if [ "$(frame_md5 "${hw_yuv}" "${fsize}" "${j}")" != \
             "$(frame_md5 "${sw_yuv}" "${fsize}" "${j}")" ]; then
            echo "${j}"
            return
        fi
    done
    echo -1
}

# 平面 YUV 重排为交错布局 (UV 交错), 对齐 MPP 10bit 输出
# $1=输入平面 yuv $2=输出交错 yuv $3=Y 平面字节数 $4=U 平面字节数
function rearrange_uv()
{
    perl -e '
        my ($ys,$us)=@ARGV;
        while(read(STDIN,$in,$ys+$us*2)) {
            my $y=substr($in,0,$ys);
            my $u=substr($in,$ys,$us);
            my $v=substr($in,$ys+$us,$us);
            print $y;
            for(my $i=0;$i<$us;$i+=2){ print substr($u,$i,2).substr($v,$i,2); }
        }
    ' "$3" "$4" <"$1" >"$2"
}

# 本地软解到 yuv 文件, 供对比或参考帧数使用
function soft_decode()
{
    strm_file="$1"
    out_yuv="$2"

    if ! get_stream_info "${strm_file}"; then
        log_warn "ffprobe cannot get stream info"
        return 1
    fi

    fmt=$(get_soft_pixfmt)
    ffmpeg_cmd="ffmpeg -y -threads 1 -v error -nostdin -i '${strm_file}' \
        -an -sn ${dn_opt} -c:v rawvideo"
    [ -n "${fmt}" ] && ffmpeg_cmd="${ffmpeg_cmd} -pix_fmt ${fmt}"
    ffmpeg_cmd="${ffmpeg_cmd} -f rawvideo '${out_yuv}'"

    log_dbg "soft decode: ${ffmpeg_cmd}"
    if eval "${ffmpeg_cmd}" >>"${log_file}" 2>&1; then
        return 0
    fi
    return 1
}

# 软解并准备对比数据: 输出全局变量 hw_size/sw_size/fsize/hw_frames/sw_frames/
# cmp_frames/hw_md5/sw_md5; 返回 0 成功 / 2 无法对比
# sw_prepared=1 时复用已有软解结果 (yuv+md5 方法同一次运行只软解一次)
function soft_prepare()
{
    strm_file="$1"
    hw_yuv="$2"
    sw_yuv="$3"

    if [ "${sw_prepared}" != "1" ]; then
        log_dbg "ffprobe: ${strm_w}x${strm_h} ${strm_pixfmt} (${strm_bpp}bit)"

        if ! soft_decode "${strm_file}" "${sw_yuv}"; then
            log_warn "soft decode failed, skip compare"
            return 2
        fi

        # 10bit+ 流软解输出为平面格式, 重排为与 MPP 一致的交错布局 (MPP 右对齐)
        # --soft-pixfmt 显式指定时不做重排 (用户自行负责格式)
        if [ -z "${cmd_soft_pixfmt}" ] && [ "${strm_bpp}" -gt 8 ]; then
            ys=$(( strm_w * strm_h * 2 ))
            case "${strm_pixfmt}" in
                yuv420p10le|yuv420p12le)
                    rearrange_uv "${sw_yuv}" "${sw_yuv}.nv12" "${ys}" $(( ys / 4 ))
                    mv -f "${sw_yuv}.nv12" "${sw_yuv}" ;;
                yuv422p10le|yuv422p12le)
                    rearrange_uv "${sw_yuv}" "${sw_yuv}.nv16" "${ys}" $(( ys / 2 ))
                    mv -f "${sw_yuv}.nv16" "${sw_yuv}" ;;
            esac
        fi
        sw_prepared="1"
    fi

    hw_size=$(stat -c %s "${hw_yuv}")
    sw_size=$(stat -c %s "${sw_yuv}")
    fsize=$(frame_size)
    hw_frames=$(( hw_size / fsize ))
    sw_frames=$(( sw_size / fsize ))
    log_dbg "yuv size: hw ${hw_size} (${hw_frames} frames), sw ${sw_size} (${sw_frames} frames)"

    if [ "${hw_frames}" -ne "${sw_frames}" ]; then
        log_warn "frame count mismatch: hw ${hw_frames} frames, sw ${sw_frames} frames"
    fi

    cmp_frames=${hw_frames}
    [ "${sw_frames}" -lt "${cmp_frames}" ] && cmp_frames=${sw_frames}
    [ "${cmp_frames}" -lt 1 ] && { log_warn "no frames to compare, skip"; return 2; }

    # 公共部分整段 md5 快速预检
    hw_md5=$(head -c $(( cmp_frames * fsize )) "${hw_yuv}" | md5sum | awk '{print $1}')
    sw_md5=$(head -c $(( cmp_frames * fsize )) "${sw_yuv}" | md5sum | awk '{print $1}')
    log_dbg "hw md5: ${hw_md5}"
    log_dbg "sw md5: ${sw_md5}"
    return 0
}

# 验证方法 yuv: 软解 + 逐帧 md5 对比
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 3 帧数不等(公共帧一致)
function soft_compare()
{
    strm_file="$1"
    hw_yuv="$2"
    sw_yuv="$3"

    if ! soft_prepare "${strm_file}" "${hw_yuv}" "${sw_yuv}"; then
        return 2
    fi

    if [ "${hw_md5}" = "${sw_md5}" ]; then
        # 公共部分一致, 仅可能帧数不等
        if [ "${hw_frames}" -ne "${sw_frames}" ]; then
            return 3
        fi
        return 0
    fi

    # 逐帧定位首个差异帧
    log "overall md5 mismatch, locating first diff frame..."
    first_diff=$(find_first_diff "${hw_yuv}" "${sw_yuv}" "${fsize}" "${cmp_frames}")
    log "first diff frame: ${first_diff} (frame $(( first_diff + 1 )), 1-based)"
    return 1
}

# 验证方法 md5: 软解 + 整文件 md5 对比 (轻量, 不逐帧定位)
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 3 帧数不等(公共帧一致)
function soft_md5_compare()
{
    strm_file="$1"
    hw_yuv="$2"
    sw_yuv="$3"

    if ! soft_prepare "${strm_file}" "${hw_yuv}" "${sw_yuv}"; then
        return 2
    fi

    if [ "${hw_md5}" = "${sw_md5}" ]; then
        if [ "${hw_frames}" -ne "${sw_frames}" ]; then
            return 3
        fi
        return 0
    fi
    log_fail "overall md5 mismatch: hw ${hw_md5} vs sw ${sw_md5}"
    return 1
}

# 验证方法 slt: 设备端生成的 slt (每帧一行 crc) 与 golden slt 对比
# $1=本地 slt 文件 $2=golden slt 路径
# 返回 0 一致 / 1 不一致 / 2 无法对比 / 4 新 golden 已生成
function slt_compare()
{
    cur_slt="$1"
    golden_slt="$2"

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
    for m in ${cmd_verify_method//,/ }; do
        [ "${m}" = "$1" ] && return 0
    done
    return 1
}

# ==================== 单个片源验证 ====================

# 重试执行: $1=描述, 其余为命令; 成功返回 0
function retry_run()
{
    desc="$1"
    shift
    local tries=3 attempt=1
    while [ "${attempt}" -le "${tries}" ]; do
        if "$@" >>"${log_file}" 2>&1; then
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

# 执行一次设备端解码 (含 logcat 采集), 输出全局 dec_ret/dev_size
function run_decode_once()
{
    # 清空 logcat, 保证 dump 的日志仅为本次解码期间产生 (best-effort)
    run_shell "logcat -c" >/dev/null 2>&1
    run_shell "${shell_cmd}" >"${dec_log}" 2>&1
    dec_ret=$?
    # dump 解码期间设备日志到本地文件
    run_shell "logcat -d" >"${dec_logcat}" 2>&1
    dev_size=$(run_shell "wc -c < '${dev_yuv}'" 2>/dev/null | tr -d ' \r')
}

function verify_one()
{
    strm_path="$1"
    strm_type="$2"
    name=$(basename "${strm_path}")
    verify_fail_note=""
    dev_slt=""
    verify_method_results=""
    log "========================================"
    log "stream: ${strm_path}"
    log "codec: ${strm_type}"

    dev_strm="${dev_work_dir}/${name}"
    dev_yuv="${dev_work_dir}/${name}.yuv"
    hw_yuv="${cmd_out_dir}/${name}.yuv"
    sw_yuv="${cmd_out_dir}/${name}.sw.yuv"
    dec_log="${cmd_out_dir}/${name}.dec.log"
    dec_logcat="${cmd_out_dir}/${name}.dec.logcat"

    # slt 验证方法是否启用 (解码时生成 slt + pull + 对比)
    slt_enabled="0"
    [ "${cmd_no_cmp}" = "0" ] && method_enabled slt && slt_enabled="1"

    # 空间预检
    if ! check_dev_space "${strm_path}"; then
        verify_fail_note="insufficient device space"
        return 1
    fi

    # 2. push 片源到设备 (带重试)
    log_dbg "push ${strm_path} -> ${dev_strm}"
    if ! retry_run "push" run_adb push "${strm_path}" "${dev_strm}"; then
        log_fail "push failed: ${strm_path}"
        if ! check_dev_valid; then
            # 设备掉线: 后续片源必然全部失败, 快速终止整个运行
            verify_fail_note="device disconnected"
            return 9
        fi
        verify_fail_note="push failed"
        return 1
    fi

    # 3. mpi_dec_test 解码 (带超时/重试)
    dec_cmd="cd ${dev_work_dir} && ${dev_exe} -i ${name} -o ${name}.yuv"
    [ -n "${strm_type}" ] && dec_cmd="${dec_cmd} -t ${strm_type}"
    [ -n "${cmd_extra_args}" ] && dec_cmd="${dec_cmd} ${cmd_extra_args}"
    # slt 验证方法: 解码时同时生成 slt 数据 (每帧一行 crc)
    if [ "${slt_enabled}" = "1" ]; then
        dev_slt="${dev_work_dir}/${name}.slt"
        dec_cmd="${dec_cmd} -slt ${name}.slt"
    fi
    log_dbg "device decode: ${dec_cmd}"
    if run_shell "command -v timeout" >/dev/null 2>&1; then
        shell_cmd="timeout ${cmd_timeout_sec} sh -c '${dec_cmd}'"
    else
        shell_cmd="${dec_cmd}"
    fi

    run_decode_once
    if [ "${dec_ret}" -ne 0 ] || [ -z "${dev_size}" ] || [ "${dev_size}" -le 0 ]; then
        # 解码失败重试一次 (可能为瞬时失败)
        log_warn "decode failed (ret=${dec_ret}), retrying once..."
        sleep 2
        run_shell "rm -f '${dev_yuv}' '${dev_slt}'" >/dev/null 2>&1
        run_decode_once
    fi
    if [ "${dec_ret}" -ne 0 ] || [ -z "${dev_size}" ] || [ "${dev_size}" -le 0 ]; then
        log_fail "decode failed (ret=${dec_ret})"
        log_dbg "tail of decode log:"
        log_dbg "$(tail -n 5 "${dec_log}")"
        # 设备解码失败, 仍本地软解获取参考帧数
        if soft_decode "${strm_path}" "${sw_yuv}"; then
            fsize=$(frame_size)
            sw_frames=$(( $(stat -c %s "${sw_yuv}") / fsize ))
            log "soft decode done: ${sw_frames} frames (reference)"
        else
            log_warn "soft decode also failed, no frame info"
        fi
        if [ "${cmd_save_local}" = "0" ]; then
            rm -f "${sw_yuv}"
        fi
        verify_fail_note="decode failed ret=${dec_ret}"
        return 1
    fi
    dec_frames=$(grep -oE "decoded +[0-9]+ +frame" "${dec_log}" | tail -1 | grep -oE "[0-9]+")
    # Android 平台 mpp 日志走 logcat, 从已保存的 logcat 文件中提取帧数
    if [ -z "${dec_frames}" ]; then
        dec_exe_name=$(basename "${dev_exe}")
        dec_frames=$(grep -E "${dec_exe_name}.*decode" "${dec_logcat}" | \
            tail -1 | grep -oE "decode [0-9]+" | awk '{print $2}')
    fi
    [ -z "${dec_frames}" ] && dec_frames="-"
    log "decode done: ${dev_size} bytes, decode log frames ${dec_frames}"

    # 4. pull 到 PC (带重试)
    log_dbg "pull ${dev_yuv} -> ${hw_yuv}"
    if ! retry_run "pull" run_adb pull "${dev_yuv}" "${hw_yuv}"; then
        log_fail "pull failed"
        verify_fail_note="pull failed"
        return 1
    fi

    # pull 完整性校验
    pull_size=$(stat -c %s "${hw_yuv}" 2>/dev/null)
    if [ "${pull_size}" != "${dev_size}" ]; then
        log_fail "pull integrity check failed: device ${dev_size}, local ${pull_size}"
        verify_fail_note="pull integrity check failed"
        return 1
    fi

    # slt 验证方法: pull 设备端生成的 slt 数据
    if [ "${slt_enabled}" = "1" ]; then
        slt_new="${cmd_out_dir}/${name}.slt"
        log_dbg "pull ${dev_slt} -> ${slt_new}"
        if ! retry_run "pull slt" run_adb pull "${dev_slt}" "${slt_new}"; then
            log_fail "pull slt failed"
            verify_fail_note="pull slt failed"
            return 1
        fi
    fi

    # 6. 删除设备上的片源和解码 yuv
    if [ "${cmd_keep_dev}" = "0" ]; then
        run_shell "rm -f '${dev_strm}' '${dev_yuv}' '${dev_slt}'" >/dev/null 2>&1
    fi

    # 5. 分析解码 yuv 是否正确
    if [ "${cmd_no_cmp}" = "1" ]; then
        log_pass "decode done (no compare)"
        return 0
    fi

    if ! get_stream_info "${strm_path}"; then
        log_warn "ffprobe cannot get stream info, skip md5 compare"
        return 2
    fi

    # 帧数交叉核对: yuv 实际帧数 vs 解码日志帧数
    fsize=$(frame_size)
    hw_frames=$(( pull_size / fsize ))
    if [ "${dec_frames}" != "-" ] && [ "${hw_frames}" != "${dec_frames}" ]; then
        log_warn "frame count mismatch: yuv actual ${hw_frames} frames, \
decode log ${dec_frames} frames"
    fi

    # 5. 按验证方法逐个执行对比, 任一方法失败则整体失败
    cmp_fail=0
    cmp_warn=0
    cmp_skip=0
    slt_gen=""
    sw_prepared=""
    verify_method_results=""
    golden_slt="$(dirname "${strm_path}")/${name}.slt"
    [ -n "${cmd_slt_dir}" ] && golden_slt="${cmd_slt_dir}/${name}.slt"
    for m in ${cmd_verify_method//,/ }; do
        case "${m}" in
            yuv) soft_compare "${strm_path}" "${hw_yuv}" "${sw_yuv}" ;;
            md5) soft_md5_compare "${strm_path}" "${hw_yuv}" "${sw_yuv}" ;;
            slt) slt_compare "${slt_new}" "${golden_slt}" ;;
        esac
        r=$?
        case "${m}" in
            yuv) m_pass="yuv compare: hw decoded yuv matches soft decode"
                 m_fail="yuv compare: hw decoded yuv differs from soft decode"
                 m_note="yuv md5 mismatch" ;;
            md5) m_pass="md5 compare: hw yuv md5 matches soft decode"
                 m_fail="md5 compare: hw yuv md5 differs from soft decode"
                 m_note="md5 mismatch" ;;
            slt) m_pass="slt compare: hw slt data matches golden slt"
                 m_fail="slt compare: hw slt data differs from golden slt"
                 m_note="slt mismatch" ;;
        esac
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

# ==================== 主流程 ====================

# 中断清理
function cleanup()
{
    echo ""
    echo "interrupt received, cleaning device files..."
    if [ -n "${adb_cmd}" ] && [ "${cmd_keep_dev}" = "0" ]; then
        run_shell "rm -rf '${dev_work_dir}'" >/dev/null 2>&1
    fi
    exit 130
}

function write_csv_header()
{
    echo "stream,codec,status,hw_frames,sw_frames,first_diff,note" >"${result_csv}"
}

# CSV 字段转义: 含逗号/引号/换行时双引号包裹, 引号翻倍
function csv_field()
{
    case "$1" in
        *,*|*\"*|*$'\n'*)
            echo "\"$(echo "$1" | sed 's/"/""/g')\"" ;;
        *)
            echo "$1" ;;
    esac
}

function append_csv_line()
{
    echo "$(csv_field "$1"),$(csv_field "$2"),$(csv_field "$3"),$(csv_field "$4"),\
$(csv_field "$5"),$(csv_field "$6"),$(csv_field "$7")" >>"${result_csv}"
}

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

function main()
{
    parse_args "$@"
    check_env
    trap cleanup INT TERM

    # 实例锁: 防止多个实例并行写同一输出目录 (结果会互相污染)
    mkdir -p "${cmd_out_dir}"
    exec 9>"${cmd_out_dir}/.rk_verify.lock"
    if ! flock -n 9; then
        echo "Error: another rk_dec_verify instance is running"
        echo "       (lock file: ${cmd_out_dir}/.rk_verify.lock)"
        exit 1
    fi
    # 清理历史结果 (含上次多设备模式的 dev_N 子目录)
    clean_out_dir
    rm -rf "${cmd_out_dir}"/dev_* 2>/dev/null

    # ===== 选择单台设备并本进程验证 =====
    init_adb || exit 1
    echo "device selected: ${adb_cmd}"

    # ===== 单设备验证全流程 =====
    mkdir -p "${cmd_out_dir}" || { echo "Error: cannot create output dir ${cmd_out_dir}"; exit 1; }
    # 清理上次运行产物, 避免旧结果/旧文件污染本次验证
    clean_out_dir
    ts=$(date +%Y%m%d_%H%M%S)
    log_file="${cmd_out_dir}/rk_dec_verify_${ts}.log"
    result_csv="${cmd_out_dir}/result.csv"
    : >"${log_file}"
    write_csv_header

    log_summary "==== RK decode verify started: $(date) ===="
    log_summary "list file: ${cmd_list_file}"
    log_env_info
    detect_dec_exe
    run_shell "mkdir -p '${dev_work_dir}'" >/dev/null 2>&1

    total=0
    abort_run="0"
    pass=0
    warn=0
    fail=0
    result_stream=()
    result_codec=()
    result_status=()
    result_hw_frames=()
    result_sw_frames=()
    result_diff=()
    result_note=()
    result_methods=()
    declare -a done_paths=()

    while IFS= read -r line <&3 || [ -n "${line}" ]; do
        # 空行/纯空白行/注释行跳过 (容忍行首空白)
        case "${line}" in
            \#*|[[:space:]]*\#*|[[:space:]]*) continue ;;
            *) : ;;
        esac

        parse_stream_line "${line}"
        ret=$?
        [ "${ret}" = "1" ] && continue    # 空行/注释

        strm_path="${strm_path:-${line}}"

        # 列表去重: 同一片源只处理一次
        dup=0
        for p in "${done_paths[@]}"; do
            [ "${p}" = "${strm_path}" ] && { dup=1; break; }
        done
        if [ "${dup}" = "1" ]; then
            log_warn "duplicate stream in list, skip: ${strm_path}"
            continue
        fi
        done_paths+=("${strm_path}")

        total=$(( total + 1 ))
        if [ "${ret}" = "2" ]; then
            fail=$(( fail + 1 ))
            result_stream+=("${strm_path}")
            result_codec+=("-")
            result_status+=("FAIL")
            result_hw_frames+=("-")
            result_sw_frames+=("-")
            result_diff+=("-")
            result_note+=("${parse_note:-invalid stream/codec}")
            result_methods+=("-")
            append_csv_line "${strm_path}" "-" "FAIL" "-" "-" "-" \
                "${parse_note:-invalid stream/codec}"
            continue
        fi

        # 复位对比结果变量, 防止上次残留
        hw_frames=""
        sw_frames=""
        first_diff=""
        dec_frames=""

        verify_one "${strm_path}" "${ctype}"
        vret=$?

        result_stream+=("${strm_path}")
        result_codec+=("${strm_name}")
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
            *) fail=$(( fail + 1 )); st="FAIL"; diff_v="${first_diff:-?}"
               note_v="${verify_fail_note:-md5 mismatch}" ;;
        esac
        result_status+=("${st}")
        result_diff+=("${diff_v}")
        result_note+=("${note_v}")
        result_methods+=("${verify_method_results}")
        result_hw_frames+=("${hw_frames:-${dec_frames:--}}")
        result_sw_frames+=("${sw_frames:--}")
        append_csv_line "${strm_path}" "${strm_name}" "${st}" \
            "${hw_frames:-${dec_frames:--}}" "${sw_frames:--}" \
            "${diff_v}" "${note_v}"
        # 设备掉线: 剩余片源全部跳过, 直接结束循环
        [ "${abort_run}" = "1" ] && {
            log_warn "device disconnected, skip remaining streams"
            break
        }
    done 3<"${cmd_list_file}"

    # 汇报验证结果
    log_summary ""
    log_summary "========================================"
    log_summary "verify summary (${total} streams, PASS ${pass}, WARN ${warn}, FAIL ${fail})"
    log_summary "========================================"
    for (( i = 0; i < total; i++ )); do
        st="${result_status[$i]}"
        if [ "${st}" = "PASS" ]; then
            log_summary "  ${GREEN}[PASS] ${result_stream[$i]}${NC}"
        elif [ "${st}" = "WARN" ] || [ "${st}" = "SKIP" ]; then
            log_summary "  ${YELLOW}[${st}] ${result_stream[$i]} (${result_note[$i]})${NC}"
        else
            log_summary "  ${RED}[FAIL] ${result_stream[$i]} (${result_note[$i]})${NC}"
        fi
    done

    # 按校验方式分类汇总
    if [ "${cmd_no_cmp}" = "0" ] && [ "${total}" -gt 0 ]; then
        log_summary ""
        log_summary "==== per-method summary ===="
        for m in ${cmd_verify_method//,/ }; do
            m_pass=0; m_warn=0; m_fail=0; m_gen=0; m_skip=0
            m_fail_list=""; m_warn_list=""
            for (( i = 0; i < total; i++ )); do
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
                log_summary "    FAIL:${m_fail_list}"
            [ "${m_warn}" -gt 0 ] && \
                log_summary "    WARN:${m_warn_list}"
        done
    fi

    log_summary "result CSV: ${result_csv}"
    log_summary "detail log: ${log_file}"

    [ "${fail}" -gt 0 ] && exit 1
    exit 0
}

main "$@"

