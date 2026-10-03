#!/usr/bin/env bash
#########################################################################
# File Name: adb_device.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Sep 2026 06:50:00 PM CST
#########################################################################

# usage:
#     d=$(dirname "$(readlink -f "$0")")
#     prj_root_dir=$(git -C "$d" rev-parse --show-toplevel)
#     source ${prj_root_dir}/0.general_tools/03.adb_tools/02.adb_device.sh
#     or after run init_tools.sh
#     source ${HOME}/bin/_adb_device.sh
#
# adb 设备操作通用封装: 适用于任何支持 adb 的设备 (Android / 带 adbd 的 Linux 等).
# 先 adev_select 选中设备, 之后所有操作走 adev_adb.
# 本库只做设备 I/O, 不依赖任何日志库, 日志由调用方负责.
#
# 全局:
#   adev_adb   当前 adb 命令 (由 adev_select 设置)
#   adev_ret   adev_run_capture 中远端命令的返回码
#
# 函数分组:
#   设备选择   adev_select
#   基本执行   adev_valid / adev_run / adev_shell / adev_push / adev_pull
#   查询辅助   adev_find_exe / adev_file_size / adev_free_kb
#   带日志执行 adev_run_capture
#   工具       adev_quote
#
# 接口:
#   adev_select [adbs args...]  选设备 (透传 adbs 参数, 如 --idx/--soc), 设置 adev_adb
#   adev_valid                  所选设备是否可用 (0=可用)
#   adev_run <args...>          adb 命令透传
#   adev_shell <cmd...>         在设备上执行 shell, 输出到 stdout
#   adev_push <local> <remote>  推送文件到设备 (adb push)
#   adev_pull <remote> <local>  从设备拉取文件 (adb pull)
#   adev_find_exe <name> [paths...]
#                                探测设备端可执行文件, 输出完整路径 (先试 name 与显式
#                                paths, 再试 /system/bin/<name> 与 /vendor/bin/<name>)
#   adev_file_size <path>       设备文件字节数
#   adev_free_kb <path>         设备路径所在分区可用空间 (KB)
#   adev_run_capture <cmd> <cmd_out> <logcat_out>
#                                cmd          设备端执行的命令
#                                cmd_out      本地文件, 保存 cmd 的 stdout+stderr
#                                logcat_out   本地文件, 保存设备端 logcat dump
#                                执行前先清 logcat; cmd 返回码存 adev_ret
#   adev_quote <s>              把字符串安全嵌入设备端命令 (单引号转义, 供 sh -c 使用)

adev_adb=""
adev_ret=""

# ---------- 内部辅助 ----------

# 未选设备时告警并返回非 0, 避免把参数当本地命令执行
function _adev_need()
{
    [ -n "${adev_adb}" ] || { echo "adev: no device selected" >&2; return 1; }
}

# 数值校验: 输出 $1 并返回 0; 非纯数字则不输出并返回 1
function _adev_num()
{
    local v="${1:-}"
    case "${v}" in
        ''|*[!0-9]*) return 1 ;;
    esac
    echo "${v}"
}

# ---------- 设备选择 ----------

# 选择设备; adbs 交互选择界面走 stderr, 故不与 stdout 合并
function adev_select()
{
    adev_adb=""
    command -v adbs >/dev/null 2>&1 || { echo "adev: adbs not found" >&2; return 1; }
    adev_adb=$(adbs "$@")
    [ -z "${adev_adb}" ] && { echo "adev: no device found" >&2; return 1; }
    return 0
}

# ---------- 基本执行 ----------

function adev_shell()
{
    _adev_need || return 1
    ${adev_adb} shell "$@" < /dev/null
}

# 所选设备是否可用 (直接向设备发一条命令, 比 adb devices 列表更准确:
# devices 子命令会忽略 -s, 列出所有设备, 无法反映所选设备是否在线)
function adev_valid()
{
    _adev_need || return 1
    adev_shell "true" >/dev/null 2>&1
}

# < /dev/null: 防止 adb 消费 while read 循环的 stdin
# 注意: ${adev_adb} 故意不加引号, 以便 "adb -s <serial>" 按空格分词
function adev_run()
{
    _adev_need || return 1
    ${adev_adb} "$@" < /dev/null
}

function adev_push()
{
    adev_run push "$@"
}

function adev_pull()
{
    adev_run pull "$@"
}

# ---------- 工具 ----------

# shell 单引号转义: 把参数包成单引号串并转义其中单引号, 安全嵌入设备端命令.
#
# 为什么需要: 这里有“两层 shell”. 本地 shell 负责拼接字符串; adb shell 会把
# 整串再交给设备端 sh 解析执行一次. 若把变量值直接拼入命令, 值里的空格/引号/
# ;|>$ 会被设备端 sh “二次解析”, 导致拆词、语法错误甚至命令注入.
# adev_quote 把值包装成设备端 sh 眼中的单个字面词.
#
# 核心一行 s="${s//\'/\'\\\'\'}" 拆解:
#   ${s//A/B}    参数替换, 把所有 A 换成 B.
#   A = \'       在 ${...} 内反斜杠转义下一字符, 故 \' 即字面单引号 ' ;
#                若写裸 ' 会被 bash 误判引号配对而报 unexpected EOF, 故须转义.
#   B = \'\\\'\' 逐段解析(每个 \x 去掉反斜杠): \'->' , \\->\ , \'->' , \'->'
#                合起来 = '\'' (4 字符: 收尾单引号 + 字面单引号 + 重开单引号).
#   所以 a b'c -> a b'\''c, 再经 printf "'%s'" 外层包裹 -> 'a b'\''c'
#
# 例: name="a b'c"
#   不转义: sh -c "rm -f ${name}"          -> 拆成 rm -f a b'c, 引号错乱报错
#   转义后: adev_quote 输出 'a b'\''c', 设备端 sh 还原成单个参数 a b'c
#
# 用法1 (普通参数, 如设备路径可能带空格):
#   adev_shell "rm -f $(adev_quote "${dev_path}")"
# 用法2 (整条命令交给 sh -c, 如配合 timeout):
#   adev_run_capture "timeout 300 sh -c $(adev_quote "${dec_cmd}")" \
#       dec.log dec.logcat
# 边界: adev_quote 只保护“这段文本”作为设备端 sh 的单个词/整条命令; 若文本
#       本身是 shell 命令(如 dec_cmd), 其内部引号仍需调用方自己写对.
function adev_quote()
{
    local s="${1:-}"
    s="${s//\'/\'\\\'\'}"
    printf "'%s'" "${s}"
}

# ---------- 查询辅助 ----------

function adev_find_exe()
{
    local name="${1:-}"; shift || :
    local path
    for path in "${name}" "$@" "/system/bin/${name}" "/vendor/bin/${name}"; do
        [ -n "${path}" ] || continue
        adev_shell "command -v $(adev_quote "${path}")" >/dev/null 2>&1 || continue
        echo "${path}"
        return 0
    done
    return 1
}

# 设备文件字节数; 非数字(不存在/是目录等)返回 1
function adev_file_size()
{
    local sz
    sz=$(adev_shell "wc -c < $(adev_quote "${1:-}")" 2>/dev/null | tr -d ' \r')
    _adev_num "${sz}"
}

# 设备路径所在分区可用空间 (KB); 非数字返回 1
function adev_free_kb()
{
    local kb
    kb=$(adev_shell "df -P $(adev_quote "${1:-}") 2>/dev/null | tail -1" 2>/dev/null \
        | awk '{print $4}' | tr -d '\r')
    _adev_num "${kb}"
}

# ---------- 带日志执行 ----------

function adev_run_capture()
{
    local cmd="${1:-}" cmd_out="${2:-}" logcat_out="${3:-}"

    if ! _adev_need; then
        adev_ret=1
        return 1
    fi
    # logcat -c: clear, 清空设备端日志缓冲区, 使后面 dump 到的仅为本次执行产生的日志.
    #            加 >/dev/null 2>&1 且 best-effort (无 logcat 权限时忽略失败).
    adev_shell "logcat -c" >/dev/null 2>&1
    adev_shell "${cmd}" >"${cmd_out}" 2>&1
    adev_ret=$?
    # logcat -d: dump and exit, 打印当前日志缓冲区内容后立即退出, 不像默认的
    #            `adb logcat` 那样阻塞等待新日志; 输出存到本地 logcat_out 文件.
    adev_shell "logcat -d" >"${logcat_out}" 2>&1
}

