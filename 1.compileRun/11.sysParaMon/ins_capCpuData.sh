#!/usr/bin/env bash
#########################################################################
# File Name: ins_capCpuData.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Nov 2024 11:06:26 AM CST
#########################################################################


capfname=""
logfname="ins_cpudata.txt"
[ $# -lt 1 ] && echo "./exe <cap_file> [<logfile>]" && exit 0
[ -e "$1" ] && capfname="$1" || { echo "file: $1 not exist"; exit 0;}
[ -n "$2" ] && logfname="$2"
[ -e ${logfname} ] && rm ${logfname}
echo "log file name: ${logfname}"

loop=0

while true
do
    loop=`expr ${loop} + 1`
    echo "Capture ins CPU data loop idx: ${loop}" | tee -a ${logfname}
    echo "uptm `cat /proc/uptime`" >> ${logfname}
    echo "stat `cat ${capfname}`" >> ${logfname}
    sleep 1
done
