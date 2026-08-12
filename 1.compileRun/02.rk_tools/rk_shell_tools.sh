#!/usr/bin/env bash
#########################################################################
# File Name: rk_shell_tools.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Oct 2024 04:56:07 PM CST
#########################################################################

# add to bashrc/zshrc:
# source ${HOME}/Projects/miniTools/1.compileRun/2.rk_tools/rk_shell_tools.sh


# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root; ${adbCmd} remount; ${adbCmd} shell'
#
# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root; eval ${adbCmd} remount; eval ${adbCmd} shell'


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
        echo "  clog --soc <info>            Select device by SoC name (pass-through to adbs --soc)"
        echo "  clog -r                      Root and remount device before operation"
        echo "  clog -c \"cmd\" -o <file>      Run cmd and save logs to file"
        echo "  clog -d <num> -o <file>      Specify device and output to file"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    local cmd_log_file=""
    local cmd_adb_idx=""
    local cmd_soc_info=""
    local cmd_run_cmd=""
    local cmd_root=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o)    cmd_log_file="$2"; shift 2; ;;
            -d)    cmd_adb_idx="$2"; shift 2; ;;
            --soc) cmd_soc_info="$2"; shift 2; ;;
            -c)    shift; cmd_run_cmd="$1"; shift; ;;
            -r)    cmd_root="1"; shift; ;;
            *)     shift; ;;
        esac
    done

    clear
    echo "clog: device=${cmd_adb_idx:-select}  soc=${cmd_soc_info:-auto}  cmd=${cmd_run_cmd:-none}  log=${cmd_log_file:-none}  root=${cmd_root:-no}"
    local adb_args=""
    [ -n "${cmd_soc_info}" ] && adb_args="--soc ${cmd_soc_info}"
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
# adbs --scrcpy 的薄封装: 设备选择/transport ID 定位/远程隧道等
# 复杂逻辑全部由 adbs 完成, 这里只做参数转发
function opdev()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "opdev: Open device screen mirror via scrcpy"
        echo ""
        echo "Usage: opdev [-- <scrcpy args>]"
        echo "  e.g. opdev -- -r out.mp4   record to file"
        echo ""
        echo "Note: Thin wrapper of 'adbs --scrcpy', args after '--' pass to scrcpy"
        echo "Requires: adbs, scrcpy"
        return 0
    fi

    adbs --scrcpy "$@"
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

function rk_en_fbc_l()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "rk_en_fbc_l: Enable/disable AFBC via GStreamer env variable (current shell only)"
        echo ""
        echo "Usage: rk_en_fbc_l <0|1>"
        echo "  0    Disable AFBC"
        echo "  1    Enable AFBC"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    en_fbc=$1
    [ -z "${en_fbc}" ] && { echo "usage: rk_en_fbc_l <0|1>    0=disable, 1=enable"; return 1; }

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

function rk_en_fbc_a()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "rn_en_fbc_a: Enable/disable AFBC via system property (global, requires setenforce 0)"
        echo ""
        echo "Usage: rk_en_fbc_a <0|1>"
        echo "  0    Disable AFBC"
        echo "  1    Enable AFBC"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    en_fbc=$1
    [ -z "${en_fbc}" ] && { echo "usage: rk_en_fbc_a <0|1>    0=disable, 1=enable"; return 1; }

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
