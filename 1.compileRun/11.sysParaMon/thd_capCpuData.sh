#!/usr/bin/env bash
#########################################################################
# File Name: thd_capCpuData.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 02:49:44 PM CST
#########################################################################

cap_proc_fname=""
logfname="thd_cpudata.txt"
[ $# -lt 1 ] && echo "./exe <cap_file> [<logfile>]" && exit 0
[ -e "$1" ] && cap_proc_fname="$1" || { echo "file: $1 not exist"; exit 0;}
[ -n "$2" ] && logfname="$2"
[ -e ${logfname} ] && rm ${logfname}
echo "log file name: ${logfname}"

loop=0

while true
do
    loop=`expr ${loop} + 1`
    echo "Capture thd CPU data loop idx: ${loop}" | tee -a ${logfname}
    echo "uptm `cat /proc/uptime`" >> ${logfname}
    process_thd_dir="/proc/`pidof ${cap_proc_fname}`/task"
    for thd_id in `ls -1 ${process_thd_dir}`
    do
        echo "stat `cat ${process_thd_dir}/${thd_id}/stat`" >> ${logfname}
    done
    sleep 1
done
