#!/usr/bin/env bash
#########################################################################
# File Name: all_capCpuData.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 04:12:29 PM CST
#########################################################################

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
