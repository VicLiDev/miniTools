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

sel_tag_adbs="adb_s:"

gen_adb_cmd()
{
    devList=(`adb devices | grep device$ | awk '{print $1}'`)
    devNameList=()
    selectList=()
    mSelectedDev=""

    if [ ${#devList[@]} -eq 0 ]; then echo "No device found!" >&2; exit 0; fi

    for ((i = 0; i < ${#devList[@]}; i++))
    do
        nameTmp=`adb -s ${devList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        nameTmp=${nameTmp%,rk*}
        devNameList[${i}]=${nameTmp#"rockchip,"}
        selectList[${i}]="${devNameList[${i}]} ==> ${devList[${i}]}"
    done

    if [ ${#devList[@]} -gt 1 ]; then
        selectNode "${sel_tag_adbs}" "selectList" "mSelectedDev" "device"
        slcedDev=`echo ${mSelectedDev} | awk '{print $3}'`
    else
        slcedDev=${devList[0]}
    fi

    adbCmd="adb -s ${slcedDev}"

    echo ${adbCmd}
}

source $(dirname $(readlink -f $0))/0.select_node.sh
adbCmd=`gen_adb_cmd`
adbOpt=${@}

if [ -z "${adbOpt}" ]; then echo $adbCmd; else $adbCmd ${adbOpt}; fi
