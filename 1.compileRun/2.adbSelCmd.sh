#!/usr/bin/env bash
#########################################################################
# File Name: adbSelCmd.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 14 Mar 2024 05:12:51 PM CST
#########################################################################

# usage:
#   1. use adbs as adb command
#      ex: adbs push <file> <dir>
#          adbs -s push <file> <dir>
#   2. gen adb -t/-s prefix
#      ex: adbCmd=$(adbs)
#          adbCmd=$(adbs -s)
#   note: default use -t, if need -s, exec "adbs -s"

# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root && eval ${adbCmd} remount && eval ${adbCmd} shell'

# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root && ${adbCmd} remount && ${adbCmd} shell'

sel_tag_adbs="adb_s:"
use_ser_id="false"

gen_adb_cmd()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devNameList=()
    selectList=()
    mSelectedDev=""

    if [ ${#devTPIDList[@]} -eq 0 ]; then echo "No device found!" >&2; exit 0; fi

    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        nameTmp=`adb -t ${devTPIDList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        nameTmp=${nameTmp%,rk*}
        devNameList[${i}]=${nameTmp#"rockchip,"}
        selectList[${i}]="${devNameList[${i}]} ==> serID: ${devSerIDList[${i}]} ==> TransportID: ${devTPIDList[${i}]}"
    done

    if [ ${#devTPIDList[@]} -gt 1 ]; then
        selectNode "${sel_tag_adbs}" "selectList" "mSelectedDev" "device"
    else
        mSelectedDev=${selectList[0]}
    fi

    if [ "${use_ser_id}" == "true" ]; then
        adbCmd="adb -s `echo ${mSelectedDev#*==>} | awk '{print $2}'`"
    else
        adbCmd="adb -t `echo ${mSelectedDev##*==>} | awk '{print $2}'`"
    fi

    echo ${adbCmd}
}

source $(dirname $(readlink -f $0))/../0.general_tools/0.select_node.sh
if [ "$1" == "-s" ]; then use_ser_id="true"; shift; fi
adbCmd=`gen_adb_cmd`
adbOpt=${@}

if [ -z "${adbOpt}" ]; then echo $adbCmd; else $adbCmd ${adbOpt}; fi
