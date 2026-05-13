#!/usr/bin/env bash
#########################################################################
# File Name: rk_shell_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 30 Oct 2024 04:56:07 PM CST
#########################################################################

# add to bashrc/zshrc:
# source ${HOME}/Projects/miniTools/1.compileRun/2.rk_tools/rk_shell_tools.sh


# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root; ${adbCmd} remount; ${adbCmd} shell'
# alias opdev='devSelNo=`adbs get-serialno` && scrcpy --serial=${devSelNo}'
#
# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root; eval ${adbCmd} remount; eval ${adbCmd} shell'
# alias opdev='devSelNo=`adbs get-serialno` && scrcpy --serial=${devSelNo}'


# zsh 在解析 ${prefix} para 形式的命令时，会只解析${prefix}，忽略后边的 para
# 因此需要用eval，eval会将后边的参数作为新的命令来执行，并且会将其展开

# 这个参数的说明，可以查看 adbSelCmd.sh
export ADB_LIBUSB=0

function clog()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "clog: View device logcat"
        echo ""
        echo "Usage:"
        echo "  clog                         Clear logcat buffer and view logs in real time"
        echo "  clog -c \"cmd\"                Clear logcat, run cmd on device, dump logs after execution"
        echo "  clog -o <file>               Output logcat to file (tee: both screen and file)"
        echo "  clog -d <num>                Specify device by index (pass-through to adbs --idx)"
        echo "  clog -r                      Root and remount device before operation"
        echo "  clog -c \"cmd\" -o <file>      Run cmd and save logs to file"
        echo "  clog -d <num> -o <file>      Specify device and output to file"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    local cmd_log_file=""
    local cmd_adb_idx=""
    local cmd_run_cmd=""
    local cmd_root=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o) cmd_log_file="$2"; shift 2; ;;
            -d) cmd_adb_idx="$2"; shift 2; ;;
            -c) shift; cmd_run_cmd="$1"; shift; ;;
            -r) cmd_root="1"; shift; ;;
            *)  shift; ;;
        esac
    done

    clear
    echo "clog: device=${cmd_adb_idx:-select}  cmd=${cmd_run_cmd:-none}  log=${cmd_log_file:-none}  root=${cmd_root:-no}"
    local adb_args=""
    [ -n "${cmd_adb_idx}" ] && adb_args="--idx ${cmd_adb_idx}"
    adbCmd=$(adbs ${adb_args})
    [ -z "${adbCmd}" ] && { echo "!!! no dev selected, use -d <id>"; return 1; }

    if [ -n "${cmd_root}" ]; then
        # adb root 后设备会断开再重连 adbd, 不能立即执行后续命令
        # 不使用 wait-for-device: 在部分 Rockchip 设备上可能长时间阻塞
        # 固定等待 3 秒: 实测足够覆盖大多数 Rockchip 设备的 adbd 重启周期
        eval ${adbCmd} root
        sleep 3
        # root 后设备重连, transport ID 会变化, 必须重新获取
        adbCmd=$(adbs ${adb_args})
        [ -z "${adbCmd}" ] && { echo "!!! device lost after root"; return 1; }
        eval ${adbCmd} remount
    fi

    # 打印最终设备信息, 确认操作对象正确
    local dev_serial=$(eval ${adbCmd} get-serialno 2>/dev/null)
    local dev_name=$(eval ${adbCmd} shell "cat /proc/device-tree/compatible" 2>/dev/null | tr -d '\0')
    echo "clog: serial=${dev_serial}  ${adbCmd}  ${dev_name}"
    [ -n "${cmd_log_file}" ] && echo "clog: serial=${dev_serial}  ${adbCmd}  ${dev_name}" > "${cmd_log_file}"

    if [ -n "${cmd_run_cmd}" ]; then
        # Clear logcat buffer before command
        eval ${adbCmd} logcat -c

        # Execute the command on device
        eval ${adbCmd} shell "${cmd_run_cmd}"

        # Dump logcat buffer after command
        if [ -n "${cmd_log_file}" ]; then
            eval ${adbCmd} logcat -d | tee -a "${cmd_log_file}"
        else
            eval ${adbCmd} logcat -d
        fi
    else
        eval ${adbCmd} logcat -c
        if [ -n "${cmd_log_file}" ]; then
            eval ${adbCmd} logcat | tee -a "${cmd_log_file}"
        else
            eval ${adbCmd} logcat
        fi
    fi
}

function ldev()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "ldev: Enter device shell (auto root + remount)"
        echo ""
        echo "Usage: ldev"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && return 0
    eval ${adbCmd} root
    eval ${adbCmd} remount
    eval ${adbCmd} shell
}

# 通过 scrcpy 打开设备屏幕镜像
#
# 问题: 部分设备 serial 相同(如 0000000000000000), scrcpy --serial 无法区分
# 解决: scrcpy 不支持 --transport-id, 但支持 ADB 环境变量指定 adb 路径。
#        创建临时 adb 包装脚本, 内部对所有命令注入 -t <transport_id>,
#        使 scrcpy 间接通过 transport ID 定位设备。
#
# 运行逻辑:
#   shell 将 ADB 环境变量设置为临时脚本路径, 然后启动 scrcpy 进程。
#   scrcpy 内部需要调用 adb 时, 会先检查 ADB 环境变量, 发现非空则调用包装脚本而非系统 adb。
#   scrcpy 本身不知道自己使用的是包装脚本, 它只是遵循 ADB 环境变量的约定。
#   wrapper 收到命令后, 用 transport ID 唯一定位目标设备, 绕过 serial 重复的问题。
#
# 包装脚本处理两类命令:
#   1. adb devices:
#      拦截 → 用 adb -t <tp_id> get-serialno 获取目标设备 serial
#           → 伪造单设备列表输出, 让 scrcpy 以为只有一个设备
#   2. 其他命令(如 shell push ...):
#      剥离 scrcpy 附加的 -s/--serial 参数(避免与 -t 冲突)
#      → 改用 adb -t <tp_id> <原始命令> 执行
function opdev()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "opdev: Open device screen mirror via scrcpy"
        echo ""
        echo "Usage: opdev"
        echo ""
        echo "Note: Uses transport ID to handle duplicate serial devices"
        echo "Requires: adbs, scrcpy"
        return 0
    fi

    # adbs 输出如 "adb -t 3", 提取末尾的 transport ID
    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && return 0
    tp_id="${adbCmd##* }"
    echo "transport ID: ${tp_id}"

    # 创建临时 adb 包装脚本
    # 用 sed 将 __TPID__ 占位符替换为实际 transport ID,
    # <<'EOF' 禁止 heredoc 内的变量展开, 避免 $1 $@ 等被提前解释
    local tmp_adb
    # mktemp:
    # 末尾 X 会被替换为随机字符(至少 3 个 X, 仅 X 为占位符，其他字符不行),
    # 生成唯一临时文件, 避免并发冲突
    tmp_adb=$(mktemp /tmp/adb_t_XXXXXX)
    sed "s/__TPID__/${tp_id}/" > "${tmp_adb}" <<'EOF'
#!/bin/bash
_tp="__TPID__"
if [ "$1" = "devices" ]; then
    # 拦截 devices 命令: 只返回目标设备, 让 scrcpy 以为只有一个设备
    _sn=$(adb -t "${_tp}" get-serialno 2>/dev/null)
    [ -z "$_sn" ] && exit 0
    printf 'List of devices attached\n%s\tdevice\n' "$_sn"
else
    # 其他命令: 剥离 -s/--serial 避免 adb 同时收到 -t 和 -s 冲突,
    # 统一通过 -t <transport_id> 定位设备
    # 初始化空数组, 用于收集过滤后的参数
    _a=()
    while [ $# -gt 0 ]; do
        case "$1" in
            # -s|--serial: 跳过标志和紧随的 serial 值(shift 2)
            -s|--serial) shift 2 ;;
            # --serial=xxx: 直接丢弃, 不 shift 等同跳过
            --serial=*) ;;
            # 其他参数: 保留到数组 _a
            *) _a+=("$1"); shift ;;
        esac
    done
    # 用 transport ID 执行过滤后的命令, 剥离的 -s 被替换为 -t
    exec adb -t "${_tp}" "${_a[@]}"
fi
EOF
    chmod +x "${tmp_adb}"

    # 通过 ADB 环境变量让 scrcpy 使用包装脚本
    # 括号 () 创建子 shell: ADB 变量无论加不加括号都不会泄露到当前 shell(inline 赋值仅对当前命令生效),
    # 加括号的真正区别是 scrcpy 在子 shell 中执行, 其内部的 cd/exit 等不会影响当前 shell
    ( ADB="${tmp_adb}" scrcpy )
    rm -f "${tmp_adb}"
}

function vimdiff_strm()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "vimdiff_strm: Compare stream files as hex text via vimdiff"
        echo ""
        echo "Usage: vimdiff_strm <file1> <file2>"
        echo ""
        echo "Requires: splitterHexTxt.py, vimdiff"
        return 0
    fi

    file1=${1}
    file2=${2}

    conv_exe="${HOME}/splitterHexTxt.py"
    ${conv_exe} ${file1} ${file1}_tmp -r
    ${conv_exe} ${file2} ${file2}_tmp -r

    vimdiff ${file1}_tmp ${file2}_tmp
}

function akill_media()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "akill_media: Kill media-related processes on device"
        echo ""
        echo "Usage: akill_media"
        echo ""
        echo "Processes killed:"
        echo "  mediaserver, cameraserver, media.codec"
        echo "  rockchip.hardware.rockit.hw@1.0-service"
        echo "  android.hardware.media.c2@1.1-service"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    adbCmd=$(adbs)
    eval ${adbCmd} shell pkill mediaserver
    eval ${adbCmd} shell pkill cameraserver
    eval ${adbCmd} shell killall media.codec

    eval ${adbCmd} shell killall rockchip.hardware.rockit.hw@1.0-service
    eval ${adbCmd} shell killall android.hardware.media.c2@1.1-service
}

function aen_fbc_l()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "aen_fbc_l: Enable/disable AFBC via GStreamer env variable (current shell only)"
        echo ""
        echo "Usage: aen_fbc_l <0|1>"
        echo "  0    Disable AFBC"
        echo "  1    Enable AFBC"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    en_fbc=$1
    [ -z "${en_fbc}" ] && { echo "usage: aen_fbc_l <0|1>    0=disable, 1=enable"; return 1; }

    adbCmd=$(adbs)
    if [ "${en_fbc}" = "1" ]; then
        eval "${adbCmd} shell \"export GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC=1\""
        [ "$?" = "0" ] && { echo "enable afbc success!"; } || { echo "enable afbc failed!"; return 1; }
    elif [ "${en_fbc}" = "0" ]; then
        eval "${adbCmd} shell \"export GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC=0\""
        [ "$?" = "0" ] && { echo "disable afbc success!"; } || { echo "disable afbc failed!"; return 1; }
    else
        echo "unknow opt of en_fbc: ${en_fbc}"
    fi
}

function aen_fbc_a()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "aen_fbc_a: Enable/disable AFBC via system property (global, requires setenforce 0)"
        echo ""
        echo "Usage: aen_fbc_a <0|1>"
        echo "  0    Disable AFBC"
        echo "  1    Enable AFBC"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    en_fbc=$1
    [ -z "${en_fbc}" ] && { echo "usage: aen_fbc_a <0|1>    0=disable, 1=enable"; return 1; }

    adbCmd=$(adbs)
    if [ "${en_fbc}" = "1" ]; then
        eval "${adbCmd} shell \"setenforce 0 && setprop rt_vdec_fbc_disable 0\""
        eval "${adbCmd} shell \"setenforce 0 && setprop codec2_fbc_disable 0\""
        # for android 9
        eval "${adbCmd} shell \"setenforce 0 && setprop sys.video.fbc.disable 0\""
        [ "$?" = "0" ] && { echo "enable afbc success!"; } || { echo "enable afbc failed!"; return 1; }
    elif [ "${en_fbc}" = "0" ]; then
        eval "${adbCmd} shell \"setenforce 0 && setprop rt_vdec_fbc_disable 1\""
        eval "${adbCmd} shell \"setenforce 0 && setprop codec2_fbc_disable 1\""
        # for android 9
        eval "${adbCmd} shell \"setenforce 0 && setprop sys.video.fbc.disable 1\""
        [ "$?" = "0" ] && { echo "disable afbc success!"; } || { echo "disable afbc failed!"; return 1; }
    else
        echo "unknow opt of en_fbc: ${en_fbc}"
    fi
}
