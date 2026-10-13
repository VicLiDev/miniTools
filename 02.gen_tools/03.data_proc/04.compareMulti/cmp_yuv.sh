#!/usr/bin/env bash
#########################################################################
# File Name: cmp_yuv.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed Sep 30 2026
#########################################################################

# 比对 yuv 原始数据: 两个 yuv 直接比 / yuv 与 ffmpeg 软解比对 / 仅软解。
# 先对公共帧整体 md5 快速预检, 不一致时二分定位首个差异帧(0-based)。
#
# output (stdout, key=value):
#   result=equal|diff|cannot_compare; yuv1_frames / yuv2_frames / cmp_frames
#   first_diff=<idx|-> (0-based, '-'=无差异/未定位); frame_count_match=0|1
#
# exit: 0 一致 / 1 不一致 / 2 无法比对 / 3 公共帧一致但总帧数不等
#
# 代码分类:
#   A. 参数解析与帮助
#   B. 输入与前置校验
#   C. 像素格式与帧大小
#   D. 软解参考
#   E. 比对与输出
#   F. 模式与主流程

# 通用日志库, 由 init_tools.sh 部署到 ~/bin/_log.sh
source "${HOME}/bin/_log.sh"

# ---------------- 全局参数 ----------------
yuv1=""
yuv2=""
stream=""
out_yuv=""
soft_fmt=""
size_str=""
bits=""
frame_size=""
max_frames=""
uv_interleave=""
ffmpeg_extra=""
locate="1"
bits_given="0"

p_w=""
p_h=""
p_pixfmt=""
ref_fmt=""
ps_ys=""
ps_us=""

tmp_files=()

# ============================================================================
# A. 参数解析与帮助
# ============================================================================

# 依次把位置参数填入 yuv1/yuv2, 超出报错
function set_positional()
{
    if [ -z "${yuv1}" ]; then
        yuv1="$1"
    elif [ -z "${yuv2}" ]; then
        yuv2="$1"
    else
        log_error "too many positional args: $1"; usage; exit 1
    fi
}

# 需要值的选项缺值时统一报错
function want_val()
{
    [ $# -ge 2 ] || { log_error "option $1 requires a value"; usage; exit 1; }
}

function parse_args()
{
    local end_opts="0"
    while [ $# -gt 0 ]; do
        if [ "${end_opts}" = "1" ]; then
            set_positional "$1"; shift; continue
        fi
        case "$1" in
            -i)              want_val "$@"; stream="$2"; shift 2 ;;
            -o)              want_val "$@"; out_yuv="$2"; shift 2 ;;
            -f)              want_val "$@"; soft_fmt="$2"; shift 2 ;;
            -s)              want_val "$@"; size_str="$2"; shift 2 ;;
            -b)              want_val "$@"; bits="$2"; bits_given="1"; shift 2 ;;
            -z)              want_val "$@"; frame_size="$2"; shift 2 ;;
            -n)              want_val "$@"; max_frames="$2"; shift 2 ;;
            --uv-interleave) want_val "$@"; uv_interleave="$2"; shift 2 ;;
            --ffmpeg-args)   want_val "$@"; ffmpeg_extra="$2"; shift 2 ;;
            --no-locate)     locate="0"; shift ;;
            --)              end_opts="1"; shift ;;
            -v|--verbose)    log_set_level debug; shift ;;
            -h|--help)       usage; exit 0 ;;
            -*)              log_error "unknown option: $1"; usage; exit 1 ;;
            *)               set_positional "$1"; shift ;;
        esac
    done
}

function usage()
{
    echo "usage:"
    echo "  $0 <yuv1> <yuv2> [options]           compare two raw yuv files"
    echo "  $0 <yuv1> -i <stream> [options]      compare yuv1 vs ffmpeg soft-decode"
    echo "  $0 -i <stream> -o <out> [options]    soft-decode only, no compare"
    echo ""
    echo "options:"
    echo "  -i <stream>          soft-decode stream as reference (replaces yuv2)"
    echo "  -o <out_yuv>         soft-decode output (default: temp, removed at exit)"
    echo "  -f <pix_fmt>         soft-decode format (default: inferred)"
    echo "  -s <WxH>             resolution for yuv-vs-yuv frame size (default 4:2:0)"
    echo "  -b <bit>             bit depth 8/10/12/14/16 (default 8), with -s"
    echo "  -z <frame_size>      frame size in bytes; priority over -s/-b"
    echo "  -n <max_frames>      compare at most first N frames (default: all)"
    echo "  --uv-interleave <f>  rearrange planar UV to interleaved (f = decode pix fmt)"
    echo "  --ffmpeg-args <a>    extra ffmpeg command arguments"
    echo "  --no-locate          skip binary-search of first differing frame"
    echo "  -v                   verbose output"
    echo "  -h                   show this help"
}

# ============================================================================
# B. 输入与前置校验
# ============================================================================

# 两个路径是否指向同一文件:
#   字符串相同, 或都已存在且 inode 相同(涵盖软/硬链接、./a vs a),
#   或尚未创建但解析后的绝对路径相同(如 ./x vs x、悬空软链与其目标)
function same_file()
{
    [ -n "$1" ] && [ -n "$2" ] || return 1
    [ "$1" = "$2" ] && return 0
    # 两者都存在时 inode 判定即可定论: 不同 inode 必为不同文件(如硬链接),
    # 同 inode 覆盖软链/. 与 .. ; 此处不再 fork readlink
    if [ -e "$1" ] && [ -e "$2" ]; then
        [ "$1" -ef "$2" ]
        return
    fi
    # 含不存在的路径(悬空软链等): 退化为规范化绝对路径比较
    local c1 c2
    c1=$(readlink -f -- "$1" 2>/dev/null) || return 1
    c2=$(readlink -f -- "$2" 2>/dev/null) || return 1
    [ -n "${c1}" ] && [ "${c1}" = "${c2}" ]
}

# 校验为十进制整数(限 15 位防溢出)并去前导零(防八进制), 失败报错返回 1
# $1 = 选项名(仅用于报错), $2 = 值; 成功时输出归一化后的十进制数
function norm_uint()
{
    # [ -n "$2" ]                   值非空
    # [[ "$2" =~ ^[0-9]{1,15}$ ]]   整串恰为 1-15 个数字:
    #                               =~ 是 bash [[ ]] 的"正则匹配"(右侧不要加引号);
    #                               ^ 行首, $ 行尾, [0-9] 一个数字, {1,15} 重复 1-15 次;
    #                               不满足(空/含非数字/超 15 位)则走右边报错分支
    [ -n "$2" ] && [[ "$2" =~ ^[0-9]{1,15}$ ]] || {
        log_error "invalid $1 '$2', expected integer"; return 1; }
    # $(( )) 是"算术展开": 把里面的整数表达式求值, 结果替换到该位置;
    # 表达式 10#$2 中的 "10#" 是进制前缀, 格式 base#number (base 2-64):
    #   10# 十进制, 8# 八进制, 16# 十六进制, 如 $((16#ff))=255, $((8#10))=8;
    #   不加前缀时前导 0 的数默认按八进制, 08/09 非法 -> value too great for base;
    # $(( )) 的结果始终按十进制输出, 与输入进制无关(要输出其它进制用 printf %x/%o)
    # 故用 10#$2 强制十进制并去掉前导零: "08"->8, "00005"->5
    echo $((10#$2))
}

# 校验数值/格式类选项, 并把数值归一为十进制(避免前导零被当作八进制)
function validate_args()
{
    # ${var,,} 是 bash 4+ 的"参数展开大小写转换": ",," = 全部转小写(非 POSIX)。
    # 此处统一小写, 因 ffmpeg 格式名与本工具的格式分类都按小写比对。
    # (值非空才赋值; 空值时左侧 [ -n ] 为假使该 && 列表退出码为 1, 但后面还有语句, 无碍)
    [ -n "${soft_fmt}" ] && soft_fmt="${soft_fmt,,}"
    [ -n "${uv_interleave}" ] && uv_interleave="${uv_interleave,,}"

    # -s 的格式校验, 正则 ^[1-9][0-9]{0,4}[xX][1-9][0-9]{0,4}$ 逐段看:
    #   [1-9]        首位 1-9 (排除前导零/0 开头的尺寸)
    #   [0-9]{0,4}   再跟 0-4 位数字, 合计 1-5 位
    #   [xX]         分隔符 x 或 X
    #   [1-9][0-9]{0,4}  高同理
    # 不匹配则报错。行尾的 \ 是"续行符": 把下一条命令接到同一逻辑行。
    if [ -n "${size_str}" ] && \
       ! [[ "${size_str}" =~ ^[1-9][0-9]{0,4}[xX][1-9][0-9]{0,4}$ ]]; then
        log_error "invalid -s '${size_str}', expected WxH"
        return 1
    fi

    # 数值选项归一: $(fn ...) 取函数 fn 的 stdout(归一化后的数)赋给变量;
    # 随后的 || 看的是 fn 的退出码, 失败即 return 1 (norm_uint 详见其定义)。
    if [ -n "${frame_size}" ]; then
        frame_size=$(norm_uint -z "${frame_size}") || return 1
    fi
    if [ -n "${max_frames}" ]; then
        max_frames=$(norm_uint -n "${max_frames}") || return 1
    fi

    # -b 先归一再枚举: case 用 | 并列多个模式, 仅接受 8/10/12/14/16,
    # 其余落到 *) 报错; "8|10|12|14|16)" 命中时执行空命令 ;; 直接结束该分支。
    if [ -n "${bits}" ]; then
        bits=$(norm_uint -b "${bits}") || return 1
        case "${bits}" in
            8|10|12|14|16) ;;
            *) log_error "invalid -b '${bits}', expected 8/10/12/14/16"
               return 1 ;;
        esac
    fi

    # 已是交错(半平面)格式就不能再 --uv-interleave, 否则会二次交错损坏数据。
    if [ -n "${uv_interleave}" ] && is_interleaved_fmt "${uv_interleave}"; then
        log_error "--uv-interleave '${uv_interleave}' is already interleaved"
        return 1
    fi
    return 0
}

# 检查所需命令是否存在 (按当前模式)
function check_deps()
{
    local d list="md5sum stat dd head awk cut mktemp" missing=""
    [ -n "${stream}" ] && list="${list} ffmpeg ffprobe"
    for d in ${list}; do
        command -v "${d}" >/dev/null 2>&1 || missing="${missing} ${d}"
    done
    [ -z "${missing}" ] && return 0
    log_error "missing required command(s):${missing}"
    return 1
}

# ============================================================================
# C. 像素格式与帧大小
# ============================================================================

# 由像素格式推断位深
function pixfmt_bits()
{
    case "$1" in
        *16le|*16be) echo 16 ;;
        *14le|*14be) echo 14 ;;
        *12le|*12be) echo 12 ;;
        *10le|*10be) echo 10 ;;
        *)           echo 8  ;;
    esac
}

# 由流像素格式推断软解输出格式 (对齐常见半平面布局)
function default_soft_fmt()
{
    case "$1" in
        yuv420p|yuvj420p) echo "nv12" ;;
        yuv420p10le)      echo "yuv420p10le" ;;
        yuv420p12le)      echo "yuv420p12le" ;;
        yuv422p)          echo "nv16" ;;
        yuv422p10le)      echo "yuv422p10le" ;;
        yuv422p12le)      echo "yuv422p12le" ;;
        *)                echo "" ;;
    esac
}

# 计算 Y/U 平面字节数, 写入全局 ps_ys / ps_us
#   w/h   : 亮度(Y)平面宽高(入参)
#   cw/ch : 一个色度平面(U 或 V, 二者尺寸相同)的宽高, 由下采样格式决定
#   bytes : 每采样字节数, 8bit=1, >8bit(10/12/14/16)=2
#   整帧字节 = ps_ys + ps_us*2 (Y + U + V; 半平面时 *2 正好等于交错 UV 平面)
#   例: 64x48 8bit 4:2:0 -> ps_ys=3072, ps_us=32*24=768, 整帧 3072+768*2=4608
function plane_sizes()
{
    local w="$1" h="$2" fmt="$3" bytes=1 cw ch
    # 位深 >8 时每单元 2 字节 (复用 pixfmt_bits, 避免重复维护位深表)
    if [ "$(pixfmt_bits "${fmt}")" -gt 8 ]; then bytes=2; fi
    # 色度下采样(整数除法; 同时识别平面 yuv* 与半平面 nv*/p0xx 命名):
    #   4:0:0 *400*/gray/mono    cw=0     ch=0
    #   4:1:1 *411*              cw=w/4   ch=h
    #   4:4:4 *444*/nv24/p410*   cw=w     ch=h
    #   4:2:2 *422*/nv16/p210*   cw=w/2   ch=h
    #   4:2:0 (默认)             cw=w/2   ch=h/2
    case "${fmt}" in
        *400*|*gray*|*mono*)                cw=0;            ch=0 ;;
        *411*)                              cw=$(( w / 4 )); ch=${h} ;;
        *444*|nv24|nv42|p410*|p412*|p416*)  cw=${w};         ch=${h} ;;
        *422*|nv16|nv61|p210*|p212*|p216*)  cw=$(( w / 2 )); ch=${h} ;;
        *)                                  cw=$(( w / 2 )); ch=$(( h / 2 )) ;;
    esac
    ps_ys=$(( w * h * bytes ))
    ps_us=$(( cw * ch * bytes ))
}

# 单帧字节数: 给定分辨率与格式 (格式为空时按位深假定 420)
function frame_size_from()
{
    local w="$1" h="$2" fmt="$3"
    if [ -n "${fmt}" ]; then
        plane_sizes "${w}" "${h}" "${fmt}"
        echo $(( ps_ys + ps_us * 2 ))
    elif [ "${bits:-8}" -le 8 ]; then
        echo $(( w * h * 3 / 2 ))
    else
        echo $(( w * h * 3 ))
    fi
}

# 是否为已交错的半平面/交错像素格式 (不能再做平面->交错重排)
function is_interleaved_fmt()
{
    case "$1" in
        nv12|nv21|nv16|nv61|nv20*|nv24|nv42) return 0 ;;
        p010*|p210*|p012*|p212*|p016*|p216*) return 0 ;;
        *) return 1 ;;
    esac
}

# --uv-interleave 需要平面(planar)软解输出, 且必须与实际软解格式一致
function check_interleave_conflict()
{
    [ -n "${uv_interleave}" ] || return 0
    if [ -z "$1" ]; then
        log_error "--uv-interleave needs a known decode format; use -f"
        return 1
    fi
    if is_interleaved_fmt "$1"; then
        log_error "--uv-interleave conflicts with interleaved decode format '$1'"
        return 1
    fi
    if [ "$1" != "${uv_interleave}" ]; then
        log_error "--uv-interleave '${uv_interleave}' != decode format '$1'"
        return 1
    fi
    return 0
}

# ============================================================================
# D. 软解参考
# ============================================================================

# ffprobe 流信息 -> p_w/p_h/p_pixfmt
function probe_stream()
{
    local info tmo=()
    command -v timeout >/dev/null 2>&1 && tmo=(timeout 30)
    info=$("${tmo[@]}" ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,pix_fmt -of csv=p=0 -- "$1" 2>/dev/null)
    [ -n "${info}" ] || return 1
    IFS=, read -r p_w p_h p_pixfmt <<<"${info}"
    [ -n "${p_w}" ] && [ -n "${p_h}" ]
}

# 软解压缩流 -> yuv 原始文件
function soft_decode()
{
    local strm="$1" out="$2" fmt="$3" cmd
    cmd=(ffmpeg -y -threads 1 -v error -nostdin -i "${strm}" -an -sn)
    if [ -n "${ffmpeg_extra}" ]; then
        # 需要按空格分词, 但禁用 glob, 避免 * 等被当前目录文件名展开
        local _prev_f=0
        case $- in *f*) _prev_f=1 ;; esac
        set -f
        cmd+=(${ffmpeg_extra})
        [ "${_prev_f}" = 0 ] && set +f
    fi
    cmd+=(-c:v rawvideo)
    [ -n "${fmt}" ] && cmd+=(-pix_fmt "${fmt}")
    cmd+=(-f rawvideo "${out}")
    log_dbg "soft decode: ${cmd[*]}"
    "${cmd[@]}"
}

# 把平面(planar)色度重排为交错(interleaved)半平面 (yuv420p -> nv12 风格), 逐帧转换.
# 下面主要说明该 perl 命令的内容:
#   my ($ys,$us,$unit)=@ARGV;     # 取 3 个参数: Y 平面字节数、一个色度平面字节数、
#                                 # 每单元(样本)字节数(8bit=1, 10/12/16bit=2)
#   while(read(STDIN,$in,$ys+$us*2)) {
#       # 从 STDIN 读满一帧(ys+us*2 字节); read 返回实读数, 为 0(EOF) 时结束
#       my $y=substr($in,0,$ys);           # Y: 帧头 ys 字节
#       my $u=substr($in,$ys,$us);         # U: 从 ys 起 us 字节
#       my $v=substr($in,$ys+$us,$us);     # V: 再接 us 字节
#       print $y;                          # 原样输出 Y
#       for(my $i=0;$i<$us;$i+=$unit){     # 以 unit 字节为步长遍历色度平面
#           print substr($u,$i,$unit).substr($v,$i,$unit);  # 输出 U 单元再 V 单元
#       }                                  # 即 U0 V0 U1 V1 ..., 逐样本交替
#   }
#   "$ys" "$us" "$unit" <"$in" >"$out"   # 传 3 个参数; < 读输入, > 写输出
function rearrange_uv()
{
    local in="$1" out="$2" ys="$3" us="$4" unit="$5"
    perl -e '
        my ($ys,$us,$unit)=@ARGV;
        # 每次读满一帧 (Y + U + V)
        while(read(STDIN,$in,$ys+$us*2)) {
            my $y=substr($in,0,$ys);
            my $u=substr($in,$ys,$us);
            my $v=substr($in,$ys+$us,$us);
            print $y;                       # Y 平面原样输出
            # U/V 逐样本交替: 每组 unit 字节 U 后接 unit 字节 V
            for(my $i=0;$i<$us;$i+=$unit){
                print substr($u,$i,$unit).substr($v,$i,$unit);
            }
        }
    ' "$ys" "$us" "$unit" <"$in" >"$out"
}

# 软解 + (可选)UV 交错重排, 生成参考 yuv
function prepare_reference()
{
    local strm="$1" out="$2" fmt="$3" ys us unit il
    if ! soft_decode "${strm}" "${out}" "${fmt}"; then
        return 1
    fi
    if [ -n "${uv_interleave}" ]; then
        if ! command -v perl >/dev/null 2>&1; then
            log_error "perl not found (needed by --uv-interleave)"
            return 1
        fi
        plane_sizes "${p_w}" "${p_h}" "${uv_interleave}"
        ys=${ps_ys}; us=${ps_us}
        unit=1; [ "$(pixfmt_bits "${uv_interleave}")" -gt 8 ] && unit=2
        il="${out}.il"
        tmp_files+=("${il}")
        rearrange_uv "${out}" "${il}" "${ys}" "${us}" "${unit}"
        mv -f "${il}" "${out}"
    fi
    return 0
}

# 探测流 → 解析软解格式 → 校验 interleave → 软解到 out; 成功时把格式写入全局 ref_fmt
# (须直接调用, 不能放进 $(...): 否则 probe_stream 写的是子 shell 的 p_* 全局)
# 失败返回 2; 比对模式由调用方输出 cannot_compare 的完整 kv
function build_reference()
{
    local strm="$1" out="$2"
    ref_fmt=""
    if ! probe_stream "${strm}"; then
        log_error "ffprobe failed: ${strm}"; return 2
    fi
    # 软解格式: 显式 -f 优先, 否则按流像素格式推断; 无默认时用 ffmpeg 原生格式
    ref_fmt="${soft_fmt:-$(default_soft_fmt "${p_pixfmt}")}"
    [ -z "${ref_fmt}" ] && \
        log_warn "no soft-decode default for '${p_pixfmt}'; use ffmpeg default"
    if ! check_interleave_conflict "${ref_fmt:-${p_pixfmt}}"; then
        return 2
    fi
    if ! prepare_reference "${strm}" "${out}" "${ref_fmt}"; then
        log_error "soft decode failed"; return 2
    fi
    return 0
}

# ============================================================================
# E. 比对与输出
# ============================================================================

# 统一输出比对结果 6 字段 (供消费者按 key 稳定取值)
function emit_result()
{
    echo "yuv1_frames=${1:--}"
    echo "yuv2_frames=${2:--}"
    echo "cmp_frames=${3:--}"
    echo "first_diff=${4:--}"
    echo "frame_count_match=${5:-0}"
    echo "result=${6}"
}

# 无法比对时统一输出全部字段; 可选传入已算出的帧数
function emit_cannot_compare()
{
    emit_result "${1:--}" "${2:--}" "${3:--}" - 0 cannot_compare
}

# 值非空时打印“被忽略”告警: warn_ignored <值> <消息>
function warn_ignored()
{
    if [ -n "$1" ]; then
        log_warn "$2"
    fi
}

# 取区间 [start, start+cnt) 帧的 md5
function range_md5()
{
    dd if="$1" bs="$2" skip="$3" count="$4" 2>/dev/null | md5sum | awk '{print $1}'
}

# 二分定位首个差异帧 (前提: 整体已确认不一致), 输出 0-based 帧号
function find_first_diff()
{
    local f1="$1" f2="$2" fsize="$3" frames="$4"
    local lo=0 hi=${frames} mid
    while [ $(( hi - lo )) -gt 1 ]; do
        mid=$(( (lo + hi) / 2 ))
        if [ "$(range_md5 "${f1}" "${fsize}" 0 "${mid}")" = \
             "$(range_md5 "${f2}" "${fsize}" 0 "${mid}")" ]; then
            lo=${mid}
        else
            hi=${mid}
        fi
    done
    echo "${lo}"
}

# 核心比对: $1=yuv1 $2=yuv2 $3=帧字节数(可空或 0=仅整文件 md5)
# 统一在末尾一次性输出全部字段, 避免多条分支各自拼装 kv
function do_compare()
{
    local f1="$1" f2="$2" fsize="$3"
    local s1 s2 n1="-" n2="-" cmp="-" first="-" match=0 result rc=0 h1 h2

    if [ ! -f "${f1}" ]; then log_error "yuv not exist: ${f1}"
        emit_cannot_compare; return 2; fi
    if [ ! -f "${f2}" ]; then log_error "yuv not exist: ${f2}"
        emit_cannot_compare; return 2; fi

    s1=$(stat -c %s -- "${f1}")
    s2=$(stat -c %s -- "${f2}")

    if [ -n "${fsize}" ] && [ "${fsize}" -gt 0 ]; then
        n1=$(( s1 / fsize ))
        n2=$(( s2 / fsize ))
        # 大小非帧整数倍时, 末尾不足一帧的字节不参与比对, 提示以免误判
        if [ $(( s1 % fsize )) -ne 0 ] || [ $(( s2 % fsize )) -ne 0 ]; then
            log_warn "file size not a multiple of frame size; trailing bytes ignored"
        fi
        cmp=${n1}
        [ "${n2}" -lt "${cmp}" ] && cmp=${n2}
        if [ -n "${max_frames}" ] && [ "${max_frames}" -gt 0 ] && \
           [ "${cmp}" -gt "${max_frames}" ]; then
            cmp=${max_frames}
        fi
        if [ "${cmp}" -lt 1 ]; then
            log_error "no frames to compare"
            emit_cannot_compare "${n1}" "${n2}" 0
            return 2
        fi
        h1=$(head -c $(( cmp * fsize )) -- "${f1}" | md5sum | awk '{print $1}')
        h2=$(head -c $(( cmp * fsize )) -- "${f2}" | md5sum | awk '{print $1}')
        [ "${n1}" = "${n2}" ] && match=1
    else
        log_dbg "no frame size, whole-file md5 only"
        h1=$(md5sum <"${f1}" | awk '{print $1}')
        h2=$(md5sum <"${f2}" | awk '{print $1}')
        [ "${s1}" = "${s2}" ] && match=1
    fi
    log_dbg "yuv1 md5: ${h1}"
    log_dbg "yuv2 md5: ${h2}"

    if [ "${h1}" != "${h2}" ]; then
        result="diff"; rc=1
        # 仅分帧比对时才能定位差异帧
        if [ "${locate}" = "1" ] && [ "${cmp}" != "-" ]; then
            first=$(find_first_diff "${f1}" "${f2}" "${fsize}" "${cmp}")
            log_dbg "first diff frame: ${first} (0-based)"
        fi
    elif [ "${cmp}" != "-" ] && [ "${n1}" != "${n2}" ]; then
        result="equal"; rc=3
    else
        result="equal"; rc=0
    fi

    emit_result "${n1}" "${n2}" "${cmp}" "${first}" "${match}" "${result}"
    return ${rc}
}

# ============================================================================
# F. 模式与主流程
# ============================================================================

# 删除全部临时文件
function cleanup()
{
    local f
    for f in "${tmp_files[@]}"; do
        [ -n "${f}" ] && rm -f "${f}"
    done
}

# 模式一: 仅软解, 不比对
function run_decode_only()
{
    warn_ignored "${size_str}"   "-s ignored in decode-only mode"
    warn_ignored "${bits}"       "-b ignored in decode-only mode"
    warn_ignored "${frame_size}" "-z ignored in decode-only mode"
    warn_ignored "${max_frames}" "-n ignored in decode-only mode"
    [ "${locate}" = "0" ] && log_warn "--no-locate ignored in decode-only mode"
    if [ -z "${out_yuv}" ]; then
        log_error "decode-only needs -o <out_yuv>"; exit 1
    fi
    if same_file "${out_yuv}" "${stream}"; then
        log_error "-o must differ from input stream"; exit 2
    fi
    build_reference "${stream}" "${out_yuv}" || exit 2
    log_dbg "decoded: ${out_yuv}"
    exit 0
}

# 模式二: yuv1 与压缩流的软解结果比对
function run_vs_stream()
{
    local sw eff_fmt bits_used=0
    if [ -z "${yuv1}" ]; then
        log_error "need yuv1 with -i"; usage; exit 1
    fi
    warn_ignored "${size_str}" "-s ignored with -i (frame size from stream)"

    if [ -n "${out_yuv}" ]; then
        sw="${out_yuv}"
    else
        sw=$(mktemp /tmp/cmp_yuv.XXXXXX)
        tmp_files+=("${sw}")
    fi

    # -o 指向被验证文件时, 软解会先覆盖它, 再自比 → 恒等(假通过), 必须拦截
    if same_file "${out_yuv}" "${yuv1}"; then
        log_error "-o must differ from yuv1 (would clobber the file under test)"
        emit_cannot_compare; exit 2
    fi
    if same_file "${out_yuv}" "${stream}"; then
        log_error "-o must differ from input stream"
        emit_cannot_compare; exit 2
    fi

    build_reference "${stream}" "${sw}" || { emit_cannot_compare; exit 2; }

    # 帧格式优先级: 交错目标 > 软解格式 > 流原生格式(软解默认即原生)
    eff_fmt="${uv_interleave:-${ref_fmt:-${p_pixfmt}}}"
    if [ -z "${frame_size}" ]; then
        if [ -n "${eff_fmt}" ]; then
            frame_size=$(frame_size_from "${p_w}" "${p_h}" "${eff_fmt}")
        else
            bits=$(pixfmt_bits "${p_pixfmt}")   # 无格式信息时才用 -b
            frame_size=$(frame_size_from "${p_w}" "${p_h}" "")
            bits_used=1
        fi
    fi
    # -b 仅在无格式分支用到, 其余(含 -z 指定帧大小)在流模式下被忽略
    [ "${bits_given}" = "1" ] && [ "${bits_used}" = "0" ] && \
        log_warn "-b ignored in stream mode"

    do_compare "${yuv1}" "${sw}" "${frame_size}"
    exit $?
}

# 模式三: 两个 yuv 文件比对
function run_vs_yuv()
{
    local fs_from="" sz w h
    if [ -z "${yuv2}" ]; then
        log_error "need yuv2 or -i <stream>"; usage; exit 1
    fi
    warn_ignored "${out_yuv}"       "-o ignored without -i"
    warn_ignored "${uv_interleave}" "--uv-interleave ignored without -i"
    warn_ignored "${ffmpeg_extra}"  "--ffmpeg-args ignored without -i"
    # 已给 -z 时, -s/-f 仅用于推算帧大小, 均被忽略
    if [ -n "${frame_size}" ]; then
        warn_ignored "${size_str}" "-s ignored (frame size from -z)"
        warn_ignored "${soft_fmt}" "-f ignored (frame size from -z)"
    fi
    # 无压缩流: 帧大小来自 -z, 或 -s(可配 -f 指定 yuv 像素格式)
    if [ -z "${frame_size}" ] && [ -n "${size_str}" ]; then
        sz="${size_str//X/x}"; w="${sz%x*}"; h="${sz#*x}"
        [ -z "${bits}" ] && bits=8
        frame_size=$(frame_size_from "${w}" "${h}" "${soft_fmt}")
        fs_from="-s"
        [ -z "${soft_fmt}" ] && \
            log_warn "-s without -f assumes 4:2:0; use -f or -z otherwise"
    elif [ -n "${soft_fmt}" ] && [ -z "${frame_size}" ]; then
        log_warn "-f needs -s (or -z) to compute frame size"
    fi
    # -b 仅在 -s 且未指定 -f(按位深补 4:2:0)时生效, 其余忽略
    if [ "${bits_given}" = "1" ]; then
        if [ "${fs_from}" != "-s" ]; then
            log_warn "-b ignored without -s"
        elif [ -n "${soft_fmt}" ]; then
            log_warn "-b ignored with -f"
        fi
    fi
    do_compare "${yuv1}" "${yuv2}" "${frame_size}"
    exit $?
}

# ---------------- 主流程 ----------------
function main()
{
    parse_args "$@"
    check_deps || exit 2
    validate_args || exit 2

    if [ -n "${stream}" ]; then
        if [ ! -f "${stream}" ]; then
            log_error "stream not exist: ${stream}"
            [ -n "${yuv1}" ] && emit_cannot_compare    # 比对模式输出完整 kv
            exit 2
        fi
        if [ -z "${yuv1}" ]; then
            run_decode_only
        else
            run_vs_stream
        fi
    else
        run_vs_yuv
    fi
}

# 注册退出钩子: 进程结束时(正常结束 / exit / 出错)自动删除全部临时文件。
# trap 无函数作用域; 此处 cleanup 已定义, 且临时文件均在 main 内创建, 故先于创建生效。
trap cleanup EXIT

main "$@"
