#!/usr/bin/env bash
#########################################################################
# File Name: analyze.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri  8 Nov 10:39:34 2024
#########################################################################

logfile="${HOME}/Downloads/log.txt"

grp=(`cat ${logfile} | grep mpp_buffer | sed 's/.*mpp_buffer: group//g' | sed 's/\r//g' | awk '{print $1}' | sort -n | uniq`)

echo ${grp[@]}

runOpt=""
for cur_grp in ${grp[@]}
do
    grp_idxs=(`cat ${logfile} | grep "group *${cur_grp}" | sed "s/.*group *${cur_grp} buffer//g" | awk '{print $1}' | sort -n | uniq`)
    for cur_idx in ${grp_idxs[@]}
    do
        cur_file="grp${cur_grp}_idx${cur_idx}.txt"
        echo ${cur_file}
        cat ${logfile} | grep "group *${cur_grp}" | grep "group *${cur_grp} buffer *${cur_idx}"


        if [ "${runOpt}" != "c" ]; then
            read -p "continue? [y/n/c] def[y]:" runOpt
            if [ "$runOpt" = "n" ];then exit 0; fi
        fi
    done
done
