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

cmd_orgAdbOpt=""
cmd_get_count="false"
cmd_gen_s_style="false"
cmd_sel_idx=""

devSerIDList=()
devTPIDList=()
devNameList=()
selectList=()

help_info()
{
    echo "usage: adbs <adbsParas> [<orgAdbParas>]" >&2
    echo "    -h|--help help info" >&2
    echo "    -c Get device count" >&2
    echo "    -s gen \"adb -s\" style cmd, default \"adb -t\" style" >&2
    echo "    --idx <num>  Generates cmd with idx:num" >&2
    echo >&2
    echo "use session:                        " >&2
    echo "    1. use adbs as adb command      " >&2
    echo "       ex: adbs push <file> <dir>   " >&2
    echo "           adbs -s push <file> <dir>" >&2
    echo "    2. gen adb -t/-s prefix         " >&2
    echo '       ex: adbCmd=$(adbs)           ' >&2
    echo '           adbCmd=$(adbs -s)        ' >&2
}

proc_paras()
{
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -s)
                cmd_gen_s_style="true"
                ;;
            -c)
                cmd_get_count="true"
                ;;
            --idx)
                cmd_sel_idx="$2"
                shift # move to next para
                ;;
            -h|--hlep)
                help_info
                exit 0
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
        nameTmp=${nameTmp%,rk*}
        devNameList[${i}]=${nameTmp#"rockchip,"}
        selectList[${i}]="${devNameList[${i}]} ==> serID: ${devSerIDList[${i}]} ==> TransportID: ${devTPIDList[${i}]}"
    done
}

gen_adb_cmd()
{
    mSelectedDev=""

    if [ "${cmd_sel_idx}" == "" ]; then
        if [ ${#devTPIDList[@]} -gt 1 ]; then
            selectNode "${sel_tag_adbs}" "selectList" "mSelectedDev" "device"
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
source $(dirname $(readlink -f $0))/../0.general_tools/0.select_node.sh
proc_paras $@
gen_dev_info_list
if [ ${cmd_get_count} == "true" ]; then
    echo "${#selectList[@]}"
else
    adbCmd=`gen_adb_cmd`
    if [ -z "${cmd_orgAdbOpt}" ]; then echo $adbCmd; else $adbCmd ${cmd_orgAdbOpt}; fi
fi
