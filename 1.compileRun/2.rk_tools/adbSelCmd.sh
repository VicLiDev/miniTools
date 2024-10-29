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
source $(dirname $(readlink -f $0))/../../0.general_tools/0.select_node.sh
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
    if [ -z "${cmd_orgAdbOpt}" ]; then echo $adbCmd; else $adbCmd ${cmd_orgAdbOpt}; fi
fi
