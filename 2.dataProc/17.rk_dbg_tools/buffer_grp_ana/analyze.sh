#!/usr/bin/env bash
#########################################################################
# File Name: analyze.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri  8 Nov 10:39:34 2024
#########################################################################

# 放开打印：
# setprop mpp_sys_cfg_debug 0x10 && setprop vendor.mpp_sys_cfg_debug 0x10
# setprop mpp_sys_cfg_debug 0 && setprop vendor.mpp_sys_cfg_debug 0
# export mpp_sys_cfg_debug=0x10
# export mpp_sys_cfg_debug=0

[ -z "$1" ] && { echo "usage: <exe> <org_log_file>"; exit 1; }
[ ! -f "$1" ] && { echo "usage: <exe> <org_log_file>"; exit 1; }
logfile="${1}"

runOpt=""

grp=(`grep mpp_buffer ${logfile} \
    | sed 's/.*mpp_buffer: *//g' \
    | sed 's/group *//g' \
    | awk '{print $1}' \
    | sort -n | uniq`)

echo "======> group_list: ${grp[@]} <======"
for cur_grp in ${grp[@]}
do
    buf_idxs=(`grep mpp_buffer ${logfile} \
        | sed 's/.*mpp_buffer: *//g' \
        | grep "group * ${cur_grp} buffer" \
        | sed "s/.*group *${cur_grp} buffer *//g" \
        | awk '{print $1}' \
        | grep -E '^[0-9]+' \
        | sort -n | uniq`)

    if [ -z "${buf_idxs}" ]
    then
        echo "------> grp:${cur_grp} buf_idx is null <------"
        grep mpp_buffer ${logfile} \
            | sed 's/.*mpp_buffer: *//g' \
            | grep "group * ${cur_grp} "
        echo "------> grp:${cur_grp} buf_idx is null <------"

        if [ "${runOpt}" != "c" ]; then
            read -p "continue? [y/n/c] def[y]:" runOpt
            if [ "$runOpt" = "n" ];then exit 0; fi
        fi

        continue
    fi

    echo "======> group ${cur_grp} buf_idx_list: ${buf_idxs[@]} <======"
    for cur_buf_idx in ${buf_idxs[@]}
    do
        buf_fds=(`grep mpp_buffer ${logfile} \
            | sed 's/.*mpp_buffer: *//g' \
            | grep "group * ${cur_grp} buffer * ${cur_buf_idx} fd" \
            | sed "s/group * ${cur_grp} buffer * ${cur_buf_idx} fd *//g" \
            | awk '{print $1}' \
            | grep -E '^[0-9]' \
            | sort -n | uniq`)

        echo "======> group ${cur_grp} buf_idx ${cur_buf_idx} fd_list: ${buf_fds[@]} <======"
        for cur_fd in ${buf_fds}
        do
            echo "------> grp:${cur_grp}  buf_idx:${buf_idxs}  fd:${cur_fd} <------"
            grep mpp_buffer ${logfile} \
                | sed 's/.*mpp_buffer: *//g' \
                | grep "group * ${cur_grp} buffer * ${cur_buf_idx} fd * ${cur_fd}"
            echo "------> grp:${cur_grp}  buf_idx:${buf_idxs}  fd:${cur_fd} <------"

            if [ "${runOpt}" != "c" ]; then
                read -p "continue? [y/n/c] def[y]:" runOpt
                if [ "$runOpt" = "n" ];then exit 0; fi
            fi
        done
    done
done
