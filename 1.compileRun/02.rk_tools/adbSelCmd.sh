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
cmd_root_remount="false"

devSerIDList=()
devTPIDList=()
devNameList=()
selectList=()
devUsbPathList=()

function help_info()
{
    echo "usage: adbs <adbsParas> [<orgAdbParas>]"
    echo "    -h|--help help info"
    echo "    -l List devices"
    echo "    -c Get device count"
    echo "    -s gen \"adb -s\" style cmd, default \"adb -t\" style"
    echo "    --idx <num>  Generates cmd with idx:num"
    echo "    -r           Root and remount devices with no info"
    echo
    echo "use session:                        "
    echo "    1. use adbs as adb command      "
    echo "       ex: adbs push <file> <dir>   "
    echo "           adbs -s push <file> <dir>"
    echo "    2. gen adb -t/-s prefix         "
    echo '       ex: adbCmd=$(adbs)           '
    echo '           adbCmd=$(adbs -s)        '
}

function root_remount_no_info_devs()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print $i}'))

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    local need_root_tpids=()
    local -A need_root_usb
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        # `adb shell id` returns uid=0(root) when rooted, uid=2000(shell) when not
        local uid=`adb -t ${devTPIDList[${i}]} shell id 2>/dev/null | grep -oP 'uid=\K\d+'`
        if [ "${uid}" != "0" ]; then
            need_root_tpids+=(${devTPIDList[${i}]})
            need_root_usb[${devUsbPathList[${i}]}]=1
        fi
    done
    [ ${#need_root_tpids[@]} -eq 0 ] && return;

    for tpid in "${need_root_tpids[@]}"; do
        echo "[${tpid}] not rooted, executing root..." >&2
        adb -t ${tpid} root
    done
    sleep 2
    # re-fetch: transport_id changes after root, usb path is stable
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print $i}'))
    # remount only devices that needed root (match by stable USB path)
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        if [[ -n "${need_root_usb[${devUsbPathList[${i}]}]}" ]]; then
            adb -t ${devTPIDList[${i}]} remount
        fi
    done
    sleep 1
}

function gen_dev_info_list()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print $i}'))
    devNameList=()
    selectList=()

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        nameTmp=`adb -t ${devTPIDList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        nameTmp=${nameTmp%rockchip*}
        nameTmp=${nameTmp#"rockchip,"}
        devNameList[${i}]=${nameTmp}
        selectList[${i}]="${devNameList[${i}]} ==> serID: ${devSerIDList[${i}]} ==> usb: ${devUsbPathList[${i}]} ==> TrsptID: ${devTPIDList[${i}]}"
    done
}

function gen_adb_cmd()
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

function proc_paras()
{
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--hlep) help_info; exit 0 ;;
            -l)        cmd_list_devs="true" ;;
            -c)        cmd_get_count="true" ;;
            -s)        cmd_gen_s_style="true" ;;
            -r)        cmd_root_remount="true" ;;
            --idx)     cmd_sel_idx="$2"; shift ;;
            *)         cmd_orgAdbOpt=$@; return ;;
        esac
        shift
    done
}

# ====== main ======
source ${HOME}/bin/_select_node.sh

function main()
{
    proc_paras $@
    [ "${cmd_root_remount}" == "true" ] && root_remount_no_info_devs
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
}

main $@
