#!/usr/bin/env bash
#########################################################################
# File Name: adbSelCmd.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 14 Mar 2024 05:12:51 PM CST
#########################################################################

# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root && eval ${adbCmd} remount && eval ${adbCmd} shell'

# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root && ${adbCmd} remount && ${adbCmd} shell'

# use platform-tools ≥ 30.x(Android 11) clould fix adb forward(transport) not work issue

# adb 36.x 引入了更激进的连接管理和特性（libusb、并发探测、IPv6、auth 机制变化等），
# 对某些 Linux 开发板的 USB Gadget / 内核驱动兼容性不好，导致反复断连，直到某个
# transport 被“侥幸”稳定下来。
#
# 强制 adb 不走 libusb 后端
# adb 连接 USB 设备有两套路径：
# 路径                  说明
# libusb                新 adb 默认，跨平台、并发能力强
# usbfs (/dev/bus/usb)  老 adb 用的，宽容但老
# ADB_LIBUSB=0 即 禁用新路径，退回老的 USB 实现
# 这是以为使用新的 libusb，会出现linux系统链接不稳定的问题
# 如果想长期生效，也可以写在shell启动脚本里：
# echo 'export ADB_LIBUSB=0' >> ~/.bashrc
# echo 'export ADB_TRACE=' >> ~/.bashrc

# ADB_TRACE 是 adb 的 调试日志开关
# ADB_TRACE=usb,transport
# 会打印巨量调试日志
# ADB_TRACE= 即明确关闭 adb 调试日志
# 用途只有一个：防止之前设置过 ADB_TRACE，结果 adb 巨慢 / 看起来不稳定
# ADB_TRACE=

sel_tag_adbs="adb_s:"

cmd_orgAdbOpt=""
cmd_list_devs="false"
cmd_get_count="false"
cmd_gen_s_style="false"
cmd_sel_idx=""

devSerIDList=()
devTPIDList=()
devNameList=()
selectList=()

help_info()
{
    echo "usage: adbs <adbsParas> [<orgAdbParas>]"
    echo "    -h|--help help info"
    echo "    -l List devices"
    echo "    -c Get device count"
    echo "    -s gen \"adb -s\" style cmd, default \"adb -t\" style"
    echo "    --idx <num>  Generates cmd with idx:num"
    echo
    echo "use session:                        "
    echo "    1. use adbs as adb command      "
    echo "       ex: adbs push <file> <dir>   "
    echo "           adbs -s push <file> <dir>"
    echo "    2. gen adb -t/-s prefix         "
    echo '       ex: adbCmd=$(adbs)           '
    echo '           adbCmd=$(adbs -s)        '
}

proc_paras()
{
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--hlep)
                help_info
                exit 0
                ;;
            -l)
                cmd_list_devs="true"
                ;;
            -c)
                cmd_get_count="true"
                ;;
            -s)
                cmd_gen_s_style="true"
                ;;
            --idx)
                cmd_sel_idx="$2"
                shift # move to next para
                ;;
            *)
                # next is adb paras
                cmd_orgAdbOpt=$@
                return
                ;;
        esac
        shift # move to next para
    done
}

gen_dev_info_list()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devNameList=()
    selectList=()

    if [ ${#devTPIDList[@]} -eq 0 ]; then echo "No device found!" >&2; exit 0; fi

    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        nameTmp=`adb -t ${devTPIDList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        nameTmp=${nameTmp%rockchip*}
        nameTmp=${nameTmp#"rockchip,"}
        devNameList[${i}]=${nameTmp}
        selectList[${i}]="${devNameList[${i}]} ==> serID: ${devSerIDList[${i}]} ==> TrsptID: ${devTPIDList[${i}]}"
    done
}

gen_adb_cmd()
{
    mSelectedDev=""

    if [ "${cmd_sel_idx}" == "" ]; then
        if [ ${#devTPIDList[@]} -gt 1 ]; then
            select_node "${sel_tag_adbs}" "selectList" "mSelectedDev" "device"
        else
            mSelectedDev=${selectList[0]}
        fi
    else
        mSelectedDev=${selectList[${cmd_sel_idx}]}
    fi

    if [ "${cmd_gen_s_style}" == "true" ]; then
        adbCmd="adb -s `echo ${mSelectedDev#*==>} | awk '{print $2}'`"
    else
        adbCmd="adb -t `echo ${mSelectedDev##*==>} | awk '{print $2}'`"
    fi

    echo ${adbCmd}
}

# ====== main ======
prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.select_node.sh
proc_paras $@
gen_dev_info_list
if [ ${cmd_get_count} == "true" ]; then
    echo "${#selectList[@]}"
elif [ "${cmd_list_devs}" == "true" ]; then
    for ((cur_idx = 0; cur_idx < ${#selectList[@]}; cur_idx++))
    do
        echo ${selectList[${cur_idx}]}
    done
else
    adbCmd=`gen_adb_cmd`
    [ -z "${adbCmd}" ] && exit 0
    [ -z "${cmd_orgAdbOpt}" ] && echo ${adbCmd} || ${adbCmd} ${cmd_orgAdbOpt}
fi
