#!/usr/bin/env bash
#########################################################################
# File Name: gen_capCpuData.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Nov 2024 10:33:32 AM CST
#########################################################################

logfname="gen_cpudata.txt"
[ -n "$1" ] && logfname="$1"
[ -e ${logfname} ] && rm ${logfname}
echo "log file name: ${logfname}"

loop=0

while true
do
    loop=`expr ${loop} + 1`
    echo "Capture gen CPU data loop idx: ${loop}" | tee -a ${logfname}
    cat /proc/stat | grep cpu >> ${logfname}
    sleep 1
done
