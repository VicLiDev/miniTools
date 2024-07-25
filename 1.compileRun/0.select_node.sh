#!/usr/bin/env bash
#########################################################################
# File Name: 0.select_node.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 15 Jul 2024 09:09:03 AM CST
#########################################################################

# usage:
#     1. exec cmd: source $(dirname $(readlink -f $0))/0.select_node.sh
#     2. selectNode "<cache tag>" "<select list>" "<select result>" "<select tip>"
#
# basename命令用于从文件名中剥离路径信息，只留下基本名称。
# basename NAME [SUFFIX]
# * NAME: 文件名或路径。
# * SUFFIX: 可选参数，如果提供，将会从基本名称中移除指定的后缀。
#
# dirname命令用于从路径中剥离最后一级目录或文件名，只留下路径部分。
# dirname NAME
#
# readlink命令用于打印符号链接（软链接）所指向的文件路径。
# readlink [-fnv] FILE
# * FILE: 符号链接文件。
# * -f: 如果指定，将会打印出符号链接的最终目标路径，而不是相对路径。
# * -n: 如果指定，将不会在输出末尾添加换行符。
# * -v: 如果指定，将会打印有关读取链接的详细信息。


cache_file=${HOME}/bin/select.cache
sel_tag=""

display()
{
    declare -n list_ref="$1"
    local tip="$2"
    echo "Please select ${tip}:"
    for ((i = 0; i < ${#list_ref[@]}; i++))
    do
        echo "  ${i}. ${list_ref[${i}]}"
    done
}

rd_sel_cache()
{
    sel_tag="$1"
    def=$2

    if [[ ! -e ${cache_file} ]] \
        || [[ -z `cat ${cache_file} | grep ${sel_tag}` ]]; then
        echo ${def}
    else
        def=`cat ${cache_file} | grep ${sel_tag} | sed "s/${sel_tag}//g"`
        echo ${def}
    fi
}

wr_sel_cache()
{
    sel_tag="$1"
    def=$2

    if [ ! -e ${cache_file} ]; then
        echo "${sel_tag}${def}" > ${cache_file}
    elif [ -z "`cat ${cache_file} | grep ${sel_tag}`" ]; then
        echo "${sel_tag}${def}" >> ${cache_file}
    else
        sed -i "s/${sel_tag}.*/${sel_tag}${def}/" ${cache_file}
    fi
}

selectNode()
{
    defSelIdx=0
    sel_tag="$1"
    defSelIdx=`rd_sel_cache ${sel_tag} ${defSelIdx}`
    local list_name="$2"
    declare -n list_ref="$2"
    declare -n sel_res="$3"
    sel_tip="$4"

    display $list_name $sel_tip
    echo "cur dir: `pwd`"
    while [ True ]
    do
        read -p "Please select ${sel_tip} or quit(q), def[${defSelIdx}]:" selIdx
        selIdx=${selIdx:-${defSelIdx}}

        if [ "${selIdx}" == "q" ]; then
            echo "======> quit <======"
            exit 0
        elif [[ -n ${selIdx} ]] \
            && [[ -z `echo ${selIdx} | sed 's/[0-9]//g'` ]] \
            && [[ "${selIdx}" -lt "${#list_ref[@]}" ]]; then
            sel_res=${list_ref[${selIdx}]}
            echo "--> selected index:${selIdx}, ${sel_tip}:${sel_res}"
            break
        else
            sel_res=""
            echo "--> please input num in scope 0-`expr ${#list_ref[@]} - 1`"
            continue
        fi
    done

    wr_sel_cache ${sel_tag} ${selIdx}
}

