#!/usr/bin/env bash
#########################################################################
# File Name: 01.log.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Sep 2026 05:30:00 PM CST
#########################################################################

# usage:
#     1. source "$(dirname "$(readlink -f "$0")")/../0.general_tools/00.lib/01.log.sh"
#        or
#        d=$(dirname "$(readlink -f "$0")")
#        prj_root_dir=$(git -C "$d" rev-parse --show-toplevel)
#        source ${prj_root_dir}/0.general_tools/00.lib/01.log.sh
#        or after run init_tools.sh
#        source ${HOME}/bin/_log.sh
#     2. log_setup "<log file>" [quiet] [verbose]
#     3. 记录日志:
#          log "<msg>"          信息 (别名 log_info)
#          log_dbg "<msg>"      调试, 仅 DEBUG 级别输出 (别名 log_debug)
#          log_pass "<msg>"     [PASS]
#          log_fail "<msg>"     [FAIL] (别名 log_error)
#          log_warn "<msg>"     [WARN]
#          log_summary "<msg>"  结果汇报: 写文件 + stdout, 不受 quiet/级别影响
#                               (行首同样带 ts/tag 前缀)
#     4. 路由:
#          log_out "<msg>"      走 stdout + 文件 (默认走 stderr + 文件)
#          log_fonly "<msg>"    仅写文件, 不上控制台
#          log_line "<msg>"     同 log (历史别名, 保留兼容)
#          log_color <out|err> <color>  取该去向可用的颜色(非终端时为空),
#                                        color: green|red|yellow|cyan|dim|nc
#                                        供调用方手工拼接带色字符串
#     5. 结构辅助 (默认 INFO 级, 走 stderr; 可用 log_set_struct 改):
#          log_sep [char] [len]          分隔线 (默认 "=" 40, 长度 1-1000)
#          log_title "<msg>"             标题 (上下各一条分隔线)
#          log_kv <key> <value> [width]  键值对 (width 可选 1-1000, 对齐 key)
#          log_step <n> <total> "<msg>"  [n/total] 前缀
#          (非法 len/width 会告警并回退: sep 用 40, kv 转为不对齐; step 的 n>total 会告警)
#          结构辅助目标为 file 但未配置日志文件时, 自动回退 stderr 以免静默丢弃
#     6. 配置:
#          log_set_level <debug|info|warn|error|0-3>
#          log_set_ts [fmt]              时间戳格式如 "%H:%M:%S" (可带前导 '+'), 空/off/OFF/0 关闭
#          log_set_tag <tag>             行首标签 (默认无)
#          log_set_color <auto|on|off>   颜色 (默认 auto)
#          log_set_struct <out|err|file> <debug..error|0-3>  结构辅助级别/去向 (默认 err INFO)
#          log_refresh                   刷新导出颜色变量 _log_green 等
#
# 环境变量: NO_COLOR (存在即关颜色, 含空值); LOG_LEVEL/LOG_TS/LOG_TAG/LOG_COLOR 由 log_setup 读取
#
# 说明:
#   - 常规日志走 stderr, 避免被 $(...) 命令替换捕获.
#   - 级别: DEBUG=0 < INFO=1 < WARN=2 < ERROR=3, 默认 INFO; verbose=1 即 DEBUG.
#   - 级别过滤只作用于控制台; 日志文件始终记录所有级别.
#   - quiet=1 时控制台仅保留 WARN/ERROR 与 log_summary.
#   - 颜色 auto: 设 NO_COLOR 或 stdout/stderr 均非 TTY 时自动无色,
#     每次输出时判定, 重定向变化后仍生效.
#   - 日志文件始终为无色纯文本, 不写入 ANSI 转义; 颜色只作用于控制台.
#   - 导出变量 _log_green/_log_red/... 为便捷用: auto 下只要 stdout 或 stderr
#     任一为终端就带色; 若把它拼给"单个被重定向的流"可能泄漏 ANSI,
#     此时请改用 log_color <out|err> <color> 按去向取色。

# 库自有变量, 用 _log_ 前缀避免污染调用方命名空间
_log_file=""
_log_quiet="0"
_log_verbose="0"
_log_level="1"            # 控制台阈值: 0=DEBUG 1=INFO 2=WARN 3=ERROR (文件始终全量)
_log_ts_fmt=""            # 空 = 关闭时间戳
_log_tag=""               # 行首标签
_log_color="auto"         # auto | 1 | 0
_log_pfx=""               # 行首前缀, 由 _log_prefix 生成
_log_plain=""             # _log_strip_ansi 的去色结果
_log_ansi=""              # _log_color_to_ansi 的解析结果(ANSI 序列)
_log_struct_level="1"     # 结构辅助(log_sep/title/kv/step)的级别
_log_struct_target="err"  # 结构辅助的输出目标: out|err|file

# 颜色常量(真实 ESC 字节), 供 _log_apply_color 取用
# ESC 全称 Escape, 即转义字符 0x1B(八进制 \033), 是终端 ANSI 颜色序列的起始字节。
# 用 $'...' 而非 "..." : 双引号不解析 \033, 存的是字面 "\033" 五字符;
# $'...' 让 shell 在赋值时就把 \033 变成真正的 ESC(0x1B)。
# 这样颜色就是真字节, 输出走 printf '%s' 即可, 无需 %b 解析转义,
# 从而避免正文反斜杠(如 C:\temp)被误解释, 日志文件也能安全地保持无色。
#
# 小例子(od 用于把看不见的字节显形):
#   a="\033[1;32m"; b=$'\033[1;32m'
#   printf '%s' "$a" | od -An -tx1   # 5c 30 33 33 5b 31 3b 33 32 6d
#   printf '%s' "$b" | od -An -tx1   # 1b 5b 31 3b 33 32 6d
#   a 首字节 5c 是反斜杠 '\', 说明双引号只存了字面字符;
#   b 首字节 1b 才是真 ESC, 说明 $'...' 已把 \033 解析成 ESC。
#
# od 命令说明: od(octal dump)按字节转储数据, 默认八进制, 这里看原始字节:
#   -An  即 -A n: 关掉每行开头的地址偏移(A=address, n=none, 不打印地址);
#   -tx1 即 -t x1: 输出类型 x=十六进制, 1=每单元 1 字节, 得到 5c/1b 这类字节;
#   合起来: 把 stdin 的字节按"每字节两位十六进制、无地址"打印, 便于对比。
_log_c_green=$'\033[1;32m'
_log_c_red=$'\033[1;31m'
_log_c_yellow=$'\033[1;33m'
_log_c_cyan=$'\033[1;36m'
_log_c_dim=$'\033[2m'
_log_c_nc=$'\033[0m'

# 对外颜色变量, auto/off 时可能被置空
_log_green="${_log_c_green}"
_log_red="${_log_c_red}"
_log_yellow="${_log_c_yellow}"
_log_cyan="${_log_c_cyan}"
_log_dim="${_log_c_dim}"
_log_nc="${_log_c_nc}"

# ---------------------------------------------------------------------------
#  配置
# ---------------------------------------------------------------------------

# 级别名/数字 -> 数字; 非法返回 1
function _log_level_num()
{
    case "${1:-}" in
        debug|DEBUG|0) echo 0 ;;
        info|INFO|1)   echo 1 ;;
        warn|WARN|2)   echo 2 ;;
        error|ERROR|3) echo 3 ;;
        *) return 1 ;;
    esac
}

function log_set_level()
{
    local _n
    [ $# -ge 1 ] || return 0
    if _n=$(_log_level_num "${1:-}"); then
        _log_level="${_n}"
    else
        echo "log: invalid level '${1:-}', use info" >&2
        _log_level="1"
    fi
}

function log_set_ts()
{
    case "${1:-}" in
        ""|off|OFF|0) _log_ts_fmt="" ;;
        *)            _log_ts_fmt="${1#+}" ;;   # 兼容 date 风格前导 '+'
    esac
}

function log_set_tag()  { _log_tag="${1:-}"; }

function _log_apply_color()
{
    local _on="1"
    if [ "${_log_color}" = "auto" ]; then
        # ${NO_COLOR+x}: 只要 NO_COLOR 已定义(含空串)就展开为 x, 故 -n 为真 → 关色
        # (NO_COLOR 规范要求"存在即关色", 空值也算; 这里用存在性测试而非取它的值)
        [ -n "${NO_COLOR+x}" ] && _on="0"
        { [ ! -t 1 ] && [ ! -t 2 ]; } && _on="0"
    else
        _on="${_log_color}"
    fi

    if [ "${_on}" = "1" ]; then
        _log_green="${_log_c_green}"; _log_red="${_log_c_red}"
        _log_yellow="${_log_c_yellow}"; _log_cyan="${_log_c_cyan}"
        _log_dim="${_log_c_dim}"; _log_nc="${_log_c_nc}"
    else
        _log_green=""; _log_red=""; _log_yellow=""
        _log_cyan=""; _log_dim=""; _log_nc=""
    fi
}

# 刷新导出的颜色变量(_log_green 等), 使其反映当前 TTY/NO_COLOR 状态
function log_refresh()  { _log_apply_color; }

function log_set_color()
{
    case "${1:-}" in
        auto|"") _log_color="auto" ;;
        1|on|ON) _log_color="1" ;;
        0|off|OFF) _log_color="0" ;;
        *) echo "log: invalid color '${1:-}', use auto" >&2; _log_color="auto" ;;
    esac
    _log_apply_color
}

# 设置结构辅助(log_sep/log_title/log_kv/log_step)的默认级别与去向
function log_set_struct()
{
    case "${1:-err}" in
        out|OUT)    _log_struct_target="out" ;;
        err|ERR|"") _log_struct_target="err" ;;
        file|FILE)  _log_struct_target="file" ;;
        *) echo "log: invalid struct target '${1:-}', use err" >&2
           _log_struct_target="err" ;;
    esac
    local _lvl
    # level 仅在显式传入时修改; 只改 target 时保留原级别
    if [ -n "${2:-}" ]; then
        if _lvl=$(_log_level_num "${2}"); then
            _log_struct_level="${_lvl}"
        else
            echo "log: invalid struct level '${2}', use 1" >&2
            _log_struct_level="1"
        fi
    fi
}
function log_setup()
{
    local _dir
    _log_file="${1:-}"
    case "${2:-0}" in
        0|1) _log_quiet="${2:-0}" ;;
        *) echo "log: invalid quiet '${2:-0}', use 0" >&2; _log_quiet="0" ;;
    esac
    case "${3:-0}" in
        0|1) _log_verbose="${3:-0}" ;;
        *) echo "log: invalid verbose '${3:-0}', use 0" >&2; _log_verbose="0" ;;
    esac

    # 日志文件不可写则告警并禁用文件日志(避免后续每次写入都报错)
    if [ -n "${_log_file}" ]; then
        _dir=$(dirname "${_log_file}")
        if [ -e "${_log_file}" ]; then
            if [ ! -f "${_log_file}" ]; then
                echo "log: log file is not a regular file '${_log_file}'" >&2
                _log_file=""
            elif [ ! -w "${_log_file}" ]; then
                echo "log: log file not writable '${_log_file}'" >&2
                _log_file=""
            fi
        elif [ ! -d "${_dir}" ] || [ ! -w "${_dir}" ]; then
            echo "log: log dir not writable '${_dir}'" >&2
            _log_file=""
        fi
    fi

    _log_level="1"          # 重置为默认, 使二次调用结果确定
    _log_ts_fmt=""
    _log_tag=""
    _log_color="auto"
    _log_struct_level="1"
    _log_struct_target="err"

    [ -n "${LOG_TAG:-}" ]   && _log_tag="${LOG_TAG}"
    [ -n "${LOG_TS:-}" ]    && log_set_ts "${LOG_TS}"
    [ "${_log_verbose}" = "1" ] && _log_level="0"   # verbose 等价 DEBUG
    # 非法 LOG_LEVEL 时 log_set_level 返回 1; 不能让它成为 && 列表末条, 否则 set -e 会中止调用方
    if [ -n "${LOG_LEVEL:-}" ]; then log_set_level "${LOG_LEVEL}" || :; fi
    [ -n "${LOG_COLOR:-}" ] && log_set_color "${LOG_COLOR}"

    _log_apply_color
}

# ---------------------------------------------------------------------------
#  内部输出
# ---------------------------------------------------------------------------

# 去掉字符串中的 ANSI SGR 序列, 结果写入全局 _log_plain。
# ANSI: 终端转义序列标准; SGR 全称 Select Graphic Rendition,
# 专指控制颜色/加粗/下划线等的序列, 形如 ESC [ <参数> m:
#   ESC = 0x1B(八进制 \033), 序列起始字节;
#   [   = 控制序列引导符; <参数> = 数字与分号, 如 1;32;
#   m   = 结尾, 表示"设置 SGR"。
# 例: ESC[1;32m 加粗绿色, ESC[0m 复位。这里说"真实 ESC"是强调匹配
# 0x1B 字节本身, 而非字面反斜杠 \033(见上方颜色常量说明)。
# 实现: 删除 CSI 序列 ESC [ <参数字节 0x30-0x3F> <中间字节 0x20-0x2F> <终止字节>;
# OSC 序列 ESC ] ... (BEL 或 ST); DCS/PM/APC/SOS 序列 ESC P|X|^|_ ... (BEL 或 ST);
# 以及单字符控制序列(如 ESC 7、ESC 8、ESC =、ESC >、ESC c)。
# 每类序列对 BEL / ST 两种终止各写一条规则(BRE 没有 | 交替语法)。
# 兜底: 再删除所有残留(孤立/不完整)ESC, 以及除 TAB/LF/CR 外的 C0 控制字符。
# 注: sed 前加 LC_ALL=C, 否则 [@-~] 等区间在非 C locale 下按字符序而非 ASCII 码匹配。
# 结果写入全局 _log_plain 而非 stdout: 避免命令替换把结尾换行吃掉。
# sed 失败(缺失/异常)时保留原串, 不让内容凭空消失。
function _log_strip_ansi()
{
    local _in="${1:-}" _s="${1:-}" _t
    # CSI: ESC [ 参数字节(0x30-0x3F) 中间字节(0x20-0x2F) 终止字节(0x40-0x7E)
    #      例 ESC[1;32m、ESC[?25l、ESC[>0c
    local _re=$'s/\033\\[[0-9;:<=>?]*[ -/]*[@-~]//g'
    # 单字符控制序列: ESC 紧跟 7 8 = > c (如保存/恢复光标、重置终端)
    _re+=$'\ns/\033[78=>c]//g'
    # OSC: ESC ] ... 以 BEL(0x07) 结尾
    _re+=$'\ns/\033][^\007\033]*\007//g'
    # OSC: ESC ] ... 以 ST(ESC \) 结尾
    _re+=$'\ns/\033][^\033]*\033\\\\//g'
    # DCS/PM/APC/SOS: ESC P|X|^|_ ... 以 BEL(0x07) 结尾
    _re+=$'\ns/\033[PX^_][^\007\033]*\007//g'
    # DCS/PM/APC/SOS: ESC P|X|^|_ ... 以 ST(ESC \) 结尾
    _re+=$'\ns/\033[PX^_][^\033]*\033\\\\//g'
    # 兜底: 删除所有残留 ESC(孤立或不完整的转义序列)
    _re+=$'\ns/\033//g'
    # 兜底: 删除除 TAB(\011) LF(\012) CR(\015) 外的 C0 控制字符及 DEL(\177)
    _re+=$'\ns/[\001-\010\013\014\016-\037\177]//g'
    # 不含任何控制字符时跳过 sed(省一次 fork)
    if [[ "${_in}" =~ [[:cntrl:]] ]]; then
        # 末尾加哨兵 x: 命令替换只剥结尾换行, 有 x 兜底则换行不丢
        if _t=$(printf '%s' "${_in}x" | LC_ALL=C sed "${_re}"); then
            _s="${_t%x}"
        fi
    fi
    _log_plain="${_s}"
}

# _log_fmt <prefix> <line>: 拼接 前缀+内容+换行, 按字面输出(printf %s)。
# 内容原样输出、不解析反斜杠, 正文里的 \t、\n 不会被误当成转义;
# 颜色常量已是真实 ESC 字节, 直接原样打印即可在终端显示颜色(见上方说明)。
function _log_fmt()
{
    printf '%s%s\n' "${1:-}" "${2:-}"
}

# 构造行首前缀, 结果写入全局 _log_pfx: 可选 [时间戳] + [标签]
# 时间戳优先用 bash 内建 printf '%(...)T' (无子进程); 格式异常时回退 date
function _log_prefix()
{
    _log_pfx=""
    if [ -n "${_log_ts_fmt}" ]; then
        local _ts
        # printf -v _ts: 与 printf 同, 但把格式化结果存入变量 _ts, 不打印到 stdout。
        # %(...)T: bash 4.2+ 的时间转换符, 括号内是 strftime 格式串(此处为
        #   _log_ts_fmt, 如 "%Y-%m-%d"); %T 表示"时间"。
        # -1: 传给 %T 的时间参数, -1 = 当前时间(-2 = shell 启动时间)。
        # 2>/dev/null: 格式非法时 printf 会报错并返回非零, 这里吞掉错误,
        #   于是走 else 分支回退到 date。整体用内建取时间戳, 免开 date 子进程。
        # printf %()T 对不支持的转换符(如 %N)会返回 0 却原样输出,
        # 故结果里若还残留 '%' 也视作失败, 一并回退到 date
        if printf -v _ts "%(${_log_ts_fmt})T" -1 2>/dev/null \
           && [[ "${_ts}" != *%* ]]; then
            _log_pfx="[${_ts}] "
        else
            _log_pfx="[$(date +"${_log_ts_fmt}")] "
        fi
    fi
    if [ -n "${_log_tag}" ]; then _log_pfx+="[${_log_tag}] "; fi
}

# 每次输出的公共前置: auto 时刷新颜色, 并构造行首前缀 _log_pfx
function _log_begin()
{
    [ "${_log_color}" = "auto" ] && _log_apply_color
    _log_prefix
}

# _log_color_to_ansi <color>: 颜色名 -> 当前可用的 ANSI 序列, 写入全局 _log_ansi。
#   color: green|red|yellow|cyan|dim|nc; 空 -> 空; 其他值按 ANSI 序列原样返回
function _log_color_to_ansi()
{
    case "${1:-}" in
        green)  _log_ansi="${_log_green}" ;;
        red)    _log_ansi="${_log_red}" ;;
        yellow) _log_ansi="${_log_yellow}" ;;
        cyan)   _log_ansi="${_log_cyan}" ;;
        dim)    _log_ansi="${_log_dim}" ;;
        nc)     _log_ansi="${_log_nc}" ;;
        "")     _log_ansi="" ;;
        *)      # 仅接受显式 ANSI 序列(以 ESC 开头), 其它按未知颜色名忽略
                if [[ "${1}" == $'\033'* ]]; then
                    _log_ansi="${1}"
                else
                    echo "log: unknown color '${1}', ignored" >&2
                    _log_ansi=""
                fi ;;
    esac
}

# 该去向是否连终端(auto 颜色据此判定): out 用 fd1, 其它用 fd2
function _log_tty() { if [ "${1:-err}" = "out" ]; then [ -t 1 ]; else [ -t 2 ]; fi; }

# 去色后追加写入日志文件(文件始终无色); 未配置日志文件则无事发生
function _log_write_file()
{
    [ -n "${_log_file}" ] || return 0
    _log_strip_ansi "${1:-}"; printf '%s\n' "${_log_plain}" >> "${_log_file}"
}

# _log_emit <level> <target> <line> [color]
#   target: err|out|file
#   color:  颜色名 green|red|yellow|cyan|dim|nc (也可直接给 ANSI 序列);
#           颜色名在刷新颜色后解析, 避免库加载时非 TTY 导致取到空色;
#           颜色仅用于控制台, 日志文件始终写无色纯文本
function _log_emit()
{
    local _lvl="${1:-}" _target="${2:-}" _line="${3:-}" _color="${4:-}"
    local _pfx _out _seq

    # 刷新 auto 颜色并构造前缀, 重定向变化后仍正确
    _log_begin
    _pfx="${_log_pfx}"

    # 颜色名 -> 当前可用的 ANSI 序列
    _log_color_to_ansi "${_color}"
    _seq="${_log_ansi}"

    # 日志文件: 记录所有级别, 不受 quiet 影响; 前缀+消息整体去色保证无色
    _log_write_file "${_pfx}${_line}"

    [ "${_target}" = "file" ] && return 0

    # 控制台: 级别阈值 + quiet 分级 (quiet 仅保留 WARN/ERROR)
    [ "${_lvl}" -lt "${_log_level}" ] && return 0
    [ "${_log_quiet}" = "1" ] && [ "${_lvl}" -lt 2 ] && return 0

    _out="${_line}"
    if [ -n "${_seq}" ]; then
        local _use="${_seq}"
        # auto 时按实际输出去向判定 TTY, 避免 ANSI 写入被重定向的文件
        if [ "${_log_color}" = "auto" ]; then
            _log_tty "${_target}" || _use=""
        fi
        [ -n "${_use}" ] && _out="${_use}${_line}${_log_nc}"
    fi
    if [ "${_target}" = "out" ]; then
        _log_fmt "${_pfx}" "${_out}"
    else
        _log_fmt "${_pfx}" "${_out}" >&2
    fi
}

# ---------------------------------------------------------------------------
#  对外接口
# ---------------------------------------------------------------------------

function log_dbg()   { _log_emit 0 err "$*"; }
function log_debug() { log_dbg "$@"; }
function log_info()  { _log_emit 1 err "$*"; }
function log()       { _log_emit 1 err "$*"; }
function log_line()  { log "$@"; }
function log_out()   { _log_emit 1 out "$*"; }
function log_fonly() { _log_emit 1 file "$*"; }

# log_color <target> <color>: 按输出去向返回可用颜色(空串表示不上色)。
# 供调用方手工拼接带色字符串时使用, 避免颜色进入被重定向的流。
#   target: out(stdout) | err(stderr)
#   color:  green|red|yellow|cyan|dim|nc (也可直接传 ANSI 序列)
#   例: gc=$(log_color err green); nc=$(log_color err nc)
#       echo "${gc}text${nc}" >&2
#   注: 在 $(...) 中调用时命令替换的 fd1 是管道, 故 target=out 的终端判定
#       会看到管道返回空; 需为 stdout 上色时请改用 log_summary(它自行按去向处理)
function log_color()
{
    local _target="${1:-err}" _color="${2:-}" _seq
    case "${_target}" in
        out|err) ;;
        *) echo "log: invalid color target '${_target}', use out|err" >&2; return 0 ;;
    esac
    [ -n "${_color}" ] || return 0
    # auto 时先刷新, 避免库加载时非 TTY 导致 _log_* 为空取不到色
    [ "${_log_color}" = "auto" ] && _log_apply_color
    _log_color_to_ansi "${_color}"
    _seq="${_log_ansi}"
    [ -n "${_seq}" ] || return 0
    if [ "${_log_color}" = "auto" ]; then
        _log_tty "${_target}" || return 0
    fi
    printf '%s' "${_seq}"
}

function log_pass()  { _log_emit 1 err "[PASS] $*" green; }
function log_fail()  { _log_emit 3 err "[FAIL] $*" red; }
function log_error() { log_fail "$@"; }
function log_warn()  { _log_emit 2 err "[WARN] $*" yellow; }

function log_summary()
{
    local _out
    # 刷新 auto 颜色并构造前缀, 重定向变化后仍正确
    _log_begin
    # 文件为无色纯文本, 前缀+消息整体去色, 保证始终无 ANSI
    _log_write_file "${_log_pfx}$*"
    # stdout 非终端且 auto 时同样去色, 避免颜色写入被重定向的输出
    _out="${_log_pfx}$*"
    if [ "${_log_color}" = "auto" ] && [ ! -t 1 ]; then
        _log_strip_ansi "${_out}"
        _out="${_log_plain}"
    fi
    printf '%s\n' "${_out}"
}

# 结构辅助
# 结构辅助输出: target 为 file 但未配置日志文件时回退 stderr, 避免静默丢弃
function _log_struct()
{
    local _t="${_log_struct_target}"
    if [ "${_t}" = "file" ] && [ -z "${_log_file}" ]; then
        _t="err"
    fi
    _log_emit "${_log_struct_level}" "${_t}" "$1"
}

# 校验 1-1000 的长度/宽度: 合法则打印归一化值, 否则返回 1
function _log_size()
{
    local _v="${1:-}"
    [[ "${_v}" =~ ^0*[0-9]{1,4}$ ]] && [ $((10#${_v})) -ge 1 ] \
       && [ $((10#${_v})) -le 1000 ] || return 1
    printf '%s' $((10#${_v}))
}

function log_sep()
{
    local _ch="=" _len="${2:-40}" _line _v
    [ $# -ge 1 ] && _ch="$1"
    if _v=$(_log_size "${_len}"); then
        _len="${_v}"
    else
        echo "log: invalid length '${_len}', use 40" >&2
        _len=40
    fi
    printf -v _line '%*s' "${_len}" ""
    _line="${_line// /${_ch}}"
    _log_struct "${_line}"
}

function log_title()
{
    log_sep
    _log_struct "$*"
    log_sep
}

function log_kv()
{
    local _key="${1:-}" _val="${2:-}" _w="${3:-}" _line _v
    if [ -n "${_w}" ]; then
        # 宽度须为 1-1000; 其余(如 0/超大/非数字)告警并按不对齐输出
        if _v=$(_log_size "${_w}"); then
            _w="${_v}"
            printf -v _line "%-*s : %s" "${_w}" "${_key}" "${_val}"
            _log_struct "${_line}"
            return 0
        fi
        echo "log: invalid width '${_w}', ignored" >&2
    fi
    _line="${_key} : ${_val}"
    _log_struct "${_line}"
}

function log_step()
{
    local _n="${1:-}" _total="${2:-}"
    if ! [[ "${_total}" =~ ^[0-9]+$ ]]; then
        echo "log: invalid total '${_total}', use '?'" >&2
        _total="?"
    fi
    if ! [[ "${_n}" =~ ^[0-9]+$ ]]; then
        echo "log: invalid step '${_n}', use '?'" >&2
        _n="?"
    fi
    # n > total 时提示; 仅对 64 位范围内的数字比较, 防止超大数字溢出
    if [[ "${_n}" =~ ^0*[0-9]{1,9}$ ]] && [[ "${_total}" =~ ^0*[0-9]{1,9}$ ]] \
       && [ "$((10#${_n}))" -gt "$((10#${_total}))" ]; then
        echo "log: step ${_n} exceeds total ${_total}" >&2
    fi
    _log_struct "[${_n}/${_total}] ${*:3}"
}

# 库加载时应用一次颜色策略, 使 auto 在 log_setup 之前也生效
_log_apply_color
