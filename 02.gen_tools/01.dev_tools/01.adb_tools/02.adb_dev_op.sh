#!/usr/bin/env bash
#########################################################################
# File Name: adb_dev_op.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Sep 2026 06:50:00 PM CST
#########################################################################

# usage:
#     d=$(dirname "$(readlink -f "$0")")
#     prj_root_dir=$(git -C "$d" rev-parse --show-toplevel)
#     source ${prj_root_dir}/02.gen_tools/01.dev_tools/01.adb_tools/02.adb_dev_op.sh
#     or after run init_tools.sh
#     source ${HOME}/bin/_adb_dev_op.sh
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

# 注意 < /dev/null: adb shell 会把本地 stdin 转发给设备端 (未加 -T 时还会
# 分配 pty), 在 "while read ...; do adb ...; done < list" 这类循环里会抢走
# 循环的输入, 导致只处理第一行. 接 /dev/null 让 adb 的 stdin 恒为空.
# 需要向设备喂数据时 (如 echo x | adb shell 'cat > f') 不要用本封装.
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

# < /dev/null: 同 adev_shell, 防止 adb 消费调用者的 stdin (push/pull 也走这里)
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

# adev_quote: 把任意字符串包成设备端 sh 的单个字面量 (安全传参)
#
# 两层 shell: 本地 bash 拼串, adb shell 再交给设备端 sh 解析一次.
# 直接拼变量会被设备端二次解释, 例如:
#   path="/data/my dir/a.h264"
#   adev_shell "rm -f ${path}"     # 设备端拆成 rm -f /data/my dir/a.h264
# 用单引号包住即可 (引号内不展开、不拆词):
#   adev_quote "${path}"  ->  '/data/my dir/a.h264'
#
# 值里有单引号时用 '\'' 表示 (收尾 + 转义的单引号 + 重新开始):
#   a b'c  ->  'a b'\''c'
#
# 实现: s="${s//\'/\'\\\'\'}"
#   \' 是字面单引号 (${...} 里不能直接写 ')
#   \\ 是字面反斜杠
#   所以替换串 \'\\\'\' 解析后是 ' \ ' ' , 即 '\''
#   最后 printf "'%s'" 再补外层单引号
#
# 用法:
#   adev_shell "rm -f $(adev_quote "${path}")"
#   adev_run_capture "timeout 300 sh -c $(adev_quote "${cmd}")" out.log out.logcat
# 注意: 只保证一个值是一个词; 值是整条命令时, 其内部引号仍需自己写对.
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

# 带命名输出的执行: 日志写到 <outdir>/<name>.log 与 <outdir>/<name>.logcat
#   adev_run_capture_named <cmd> <outdir> <name>
function adev_run_capture_named()
{
    local cmd="${1:-}" dir="${2:-}" name="${3:-}"

    [ -d "${dir}" ] || mkdir -p "${dir}" || return 1
    adev_run_capture "${cmd}" "${dir}/${name}.log" "${dir}/${name}.logcat"
}

# 在指定设备上执行命令, 输出保存为带时间戳的日志
#
#   adev_run_cmd <soc|id> <cmd> <log_dir>
#
#     soc|id   设备: soc 名 (如 rk3588, 按设备树 compatible 子串匹配)
#              或设备列表中的 idx (纯数字, 即 adbs -l 第一列)
#     cmd      设备端命令 (整串交给设备 sh 执行)
#     log_dir  日志目录, 不存在会自动创建
#
# 日志: <log_dir>/<YYYYmmdd_HHMMSS>.log
#   文件头记录: 设备 (adb 选择串), 命令, 开始时间
#   正文: 命令的 stdout+stderr; 设备有 logcat 时末尾追加 logcat -d
#   路径同时写入全局 adev_log, 返回码写入 adev_ret
#
# 例:
#   adev_run_cmd rk3588 'cat /proc/meminfo' /tmp/devlog
#   adev_run_cmd 0 'dmesg | tail -50' /tmp/devlog
function adev_run_cmd()
{
    local dev="${1:-}" cmd="${2:-}" dir="${3:-}"
    local sel=() ts log dev_name lcf

    if [ -z "${dev}" ] || [ -z "${cmd}" ] || [ -z "${dir}" ]; then
        echo "usage: adev_run_cmd <soc|id> <cmd> <log_dir>" >&2
        return 2
    fi

    case "${dev}" in
        *[!0-9]*) sel=(--soc "${dev}") ;;
        *)        sel=(--idx "${dev}") ;;
    esac
    if ! adev_select "${sel[@]}"; then
        return 1
    fi

    if ! mkdir -p "${dir}"; then
        return 1
    fi

    ts=$(date +%Y%m%d_%H%M%S)
    log="${dir}/${ts}.log"
    [ -e "${log}" ] && log="${dir}/${ts}_$$.log"
    adev_log="${log}"

    dev_name=$(adev_shell "cat /proc/device-tree/compatible 2>/dev/null" 2>/dev/null \
        | tr '\0' ' ' | tr -s ' ')

    {
        echo "# device: ${adev_adb}"
        [ -n "${dev_name}" ] && echo "# model : ${dev_name}"
        echo "# cmd   : ${cmd}"
        echo "# start : $(date '+%F %T')"
        echo "========================================"
    } > "${log}"

    adev_shell "logcat -c" >/dev/null 2>&1
    adev_shell "${cmd}" >> "${log}" 2>&1
    adev_ret=$?

    lcf="${log}.logcat.tmp"
    if adev_shell "command -v logcat" >/dev/null 2>&1 &&
       adev_shell "logcat -d" >"${lcf}" 2>/dev/null && [ -s "${lcf}" ]; then
        {
            echo "========================================"
            echo "# logcat"
            echo "========================================"
            cat "${lcf}"
        } >> "${log}"
    fi
    rm -f "${lcf}"

    echo "${log}"
    return "${adev_ret}"
}

