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

clog()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "clog: View device logcat"
        echo ""
        echo "Usage:"
        echo "  clog               Clear logcat buffer and view logs in real time"
        echo "  clog -c \"cmd\"    Clear logcat, run cmd on device, capture logs during execution"
        echo ""
        echo "Requires: adbs"
        return 0
    fi

    clear
    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && return 0

    if [ "$1" = "-c" ] && [ -n "$2" ]; then
        local cmd="$2"

        # Clear logcat buffer before command
        eval ${adbCmd} logcat -c

        # Execute the command on device
        eval ${adbCmd} shell "${cmd}"

        # Dump logcat buffer after command
        eval ${adbCmd} logcat -d
    else
        eval ${adbCmd} logcat -c
        eval ${adbCmd} logcat
    fi
}

ldev()
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

opdev()
{
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "opdev: Open device screen mirror via scrcpy"
        echo ""
        echo "Usage: opdev"
        echo ""
        echo "Requires: adbs, scrcpy"
        return 0
    fi

    devSelNo=`adbs get-serialno`
    [ -z "${devSelNo}" ] && return 0
    echo "dev No: ${devSelNo}"
    scrcpy --serial=${devSelNo}
}

vimdiff_strm()
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

akill_media()
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

aen_fbc_l()
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

aen_fbc_a()
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
