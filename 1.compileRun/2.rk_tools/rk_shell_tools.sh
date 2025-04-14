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
