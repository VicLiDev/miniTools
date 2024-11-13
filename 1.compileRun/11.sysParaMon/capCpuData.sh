#!/usr/bin/env bash
#########################################################################
# File Name: capCpuData.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 04:12:29 PM CST
#########################################################################

[ $# -lt 1 ] && { echo "./exe <app_name>"; echo "ex: ./capCpuData.sh cpu_mult_thd_simulation"; exit 0;}
pid=`pidof $1`
echo ${pid}
[ -z "${pid}" ] &&  { echo "process: $1 not exist"; exit 0;}

gen_logfname="cpudata_gen.txt"
ins_logfname="cpudata_ins.txt"
thd_logfname="cpudata_thd.txt"
[ -e ${gen_logfname} ] && rm ${gen_logfname}
[ -e ${ins_logfname} ] && rm ${ins_logfname}
[ -e ${thd_logfname} ] && rm ${thd_logfname}
echo "gen log file name: ${gen_logfname}"
echo "ins log file name: ${ins_logfname}"
echo "thd log file name: ${thd_logfname}"

# 获取当前时间戳（毫秒级）
current_time()
{
    date +%s%3N
}

loop=0

while true
do
    loop=`expr ${loop} + 1`
    echo "Capture ins CPU data loop idx: ${loop}"

    # 记录开始时间
    start_time=$(current_time)

    # gne
    echo "Capture gen CPU data loop idx: ${loop}" >> ${gen_logfname}
    cat /proc/stat | grep cpu >> ${gen_logfname}

    # ins
    echo "Capture ins CPU data loop idx: ${loop}" >> ${ins_logfname}
    echo "uptm `cat /proc/uptime`" >> ${ins_logfname}
    echo "stat `cat /proc/${pid}/stat`" >> ${ins_logfname}

    # thd
    echo "Capture thd CPU data loop idx: ${loop}" >> ${thd_logfname}
    echo "uptm `cat /proc/uptime`" >> ${thd_logfname}
    process_thd_dir="/proc/${pid}/task"
    for thd_id in `ls -1 ${process_thd_dir}`
    do
        echo "stat `cat ${process_thd_dir}/${thd_id}/stat`" >> ${thd_logfname}
    done

    # 记录结束时间
    end_time=$(current_time)
    # 计算命令执行时间
    elapsed_time=$((end_time - start_time))
    # 计算下一次执行前的休眠时间
    sleep_time=$((1000 - elapsed_time))
    # 如果命令执行时间超过 1 秒，直接继续下一次执行
    if [ ${sleep_time} -gt 0 ]; then
        # BEGIN 是 awk 中的一个特殊块，它在处理任何输入数据之前执行一次。
        # 在这个命令中，它用于在没有输入文件的情况下执行一个简单的计算。
        # echo "sleep $(awk "BEGIN {print ${sleep_time}/1000}")s"
        sleep $(awk "BEGIN {print ${sleep_time}/1000}")
    fi
done





# old capt log method

exit 0

[ $# -lt 1 ] && { echo "./exe <app_name>"; exit 0;}
ins=$1

# 启动三个脚本并放到后台
bash ./gen_capCpuData.sh &
pid1=$!
bash ./ins_capCpuData.sh /proc/`pidof ${ins}`/stat &
pid2=$!
bash ./thd_capCpuData.sh ${ins} &
pid3=$!

# 输出后台运行的脚本 PID
echo "Script1 PID: $pid1"
echo "Script2 PID: $pid2"
echo "Script3 PID: $pid3"



# # 等待用户按下任意键停止所有后台进程
# read -p "Press any key to stop the scripts..."
#
# # 停止后台进程
# kill $pid1
# kill $pid2
# kill $pid3
#
# echo "All scripts have been stopped."



# 定义捕获信号的处理函数
cleanup() {
    echo "Stopping scripts..."
    kill $pid1 $pid2 $pid3
    exit 0
}

# 捕获 SIGINT (Ctrl+C) 信号
trap cleanup SIGINT

# 保持脚本运行
while true; do
    sleep 1
done
