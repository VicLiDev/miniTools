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
    clear
    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && return 0
    eval ${adbCmd} logcat -c
    eval ${adbCmd} logcat
}

ldev()
{
    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && return 0
    eval ${adbCmd} root
    eval ${adbCmd} remount
    eval ${adbCmd} shell
}

opdev()
{
    devSelNo=`adbs get-serialno`
    [ -z "${devSelNo}" ] && return 0
    echo "dev No: ${devSelNo}"
    scrcpy --serial=${devSelNo}
}

vimdiff_strm()
{
    file1=${1}
    file2=${2}

    conv_exe="${HOME}/Projects/miniTools/2.dataProc/19.hex_txt_splitter.py"
    ${conv_exe} ${file1} ${file1}_tmp -r
    ${conv_exe} ${file2} ${file2}_tmp -r

    vimdiff ${file1}_tmp ${file2}_tmp
}

adb_kill_media()
{
    adbCmd=$(adbs)
    eval ${adbCmd} shell pkill mediaserver
    eval ${adbCmd} shell pkill cameraserver
    eval ${adbCmd} shell killall media.codec

    eval ${adbCmd} shell killall rockchip.hardware.rockit.hw@1.0-service
    eval ${adbCmd} shell killall android.hardware.media.c2@1.1-service
}
