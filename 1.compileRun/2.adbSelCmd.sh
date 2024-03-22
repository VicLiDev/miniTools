#!/bin/bash
#########################################################################
# File Name: adbSelCmd.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 14 Mar 2024 05:12:51 PM CST
#########################################################################

gen_adb_cmd()
{
    devList=(`adb devices | grep device$ | awk '{print $1}'`)
    devName=()
    defDev=0
    m_devIdx=0
    m_DevName=""

    if [ ${#devList[@]} -eq 0 ]; then echo "No device found!" >&2; exit 0; fi

    for ((i = 0; i < ${#devList[@]}; i++))
    do
        nameTmp=`adb -s ${devList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        # nameTmp=${nameTmp%,rk*}
        devName[${i}]=${nameTmp#"rockchip,"}
    done

    if [ ${#devList[@]} -gt 1 ]; then
        echo "Please select device:" >&2
        for ((i = 0; i < ${#devList[@]}; i++))
        do
            echo "  ${i}. ${devName[${i}]} ==> ${devList[${i}]}" >&2
        done
        while [ True ]
        do
            read -p "Please select device or quit(q), def[${defDev}]:" m_devIdx
            m_devIdx=${m_devIdx:-${defDev}}

            if [ "${m_devIdx}" == "q" ]; then
                echo "======> quit <======" >&2
                exit 0
            elif [[ -n "${m_devIdx}" && -z `echo ${m_devIdx} | sed 's/[0-9]//g'` ]]; then
                slcedDev=${devList[${m_devIdx}]}
                echo "--> selected index:${m_devIdx}, dev:${devName[${i}]} ==> ${slcedDev}" >&2
                break
            else
                curPlt=""
                echo "--> please input num in scope 0-`expr ${#devList[@]} - 1`" >&2
                continue
            fi
        done
    else
        slcedDev=${devList[0]}
    fi
    adbCmd="adb -s ${slcedDev}"

    echo ${adbCmd}
}

adbCmd=`gen_adb_cmd`
adbOpt=${@}

if [ -z "${adbOpt}" ]; then echo $adbCmd; else $adbCmd ${adbOpt}; fi

# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root && eval ${adbCmd} remount && eval ${adbCmd} shell'

# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root && ${adbCmd} remount && ${adbCmd} shell'
