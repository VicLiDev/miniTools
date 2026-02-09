#!/usr/bin/env bash
#########################################################################
# File Name: delayExec.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年06月04日 星期日 22时15分59秒
#########################################################################


#======> loop sleep code
# 以下代码不需要考虑跨天的问题，指定功能会在下次到达设定时间时执行
# 可以参考定时代码编写年月日的等待代码
otime="15:46:20"                  # 定时时间 -- need modify
otime_h="${otime:0:2}"            # 定时时间 hour
otime_m="${otime:3:2}"            # 定时时间 min
otime_s="${otime:6:2}"            # 定时时间 sec
ctime=`date +"%H:%M:%S"`          # 当前时间
ctime_h=`date +"%H"`              # 当前时间 hour
ctime_m=`date +"%M"`              # 当前时间 min
ctime_s=`date +"%S"`              # 当前时间 sec

function updateTime()
{
    ctime=`date +"%H:%M:%S"`
    ctime_h=`date +"%H"`
    ctime_m=`date +"%M"`
    ctime_s=`date +"%S"`

    diff_h=`expr $otime_h - $ctime_h`
    diff_m=`expr $otime_m - $ctime_m`
    diff_s=`expr $otime_s - $ctime_s`
}

function waitObjTime()
{
    # usae: waitObjtime h/m/s/-
    # when time equal h/m/s cur func exit
    # without para, wait for ctime
    care_int="$1"

    while true
    do
        updateTime
        echo "The timing time is : ${otime}, the current time is : ${ctime} care interval: ${care_int}"
        if [ ${care_int} == "h" ]; then
            if [ ${diff_h} -ne "0" ]; then echo "sleep 1s"; sleep 1; continue; else break; fi
        elif [ ${care_int} == "m" ]; then
            if [ ${diff_m} -ne "0" ]; then echo "sleep 1s"; sleep 1; continue; else break; fi
        elif [ ${care_int} == "s" ]; then
            if [ ${diff_s} -ne "0" ]; then echo "sleep 1s"; sleep 1; continue; else break; fi
        else
            if [ ${diff_h} -ne "0" ] || [ ${diff_m} -ne "0" ] || [ ${diff_s} -ne "0" ]; then
                echo "sleep 1s"
                sleep 1
                continue
            else
                break
            fi
        fi
    done
}

waitObjTime h

echo "exec cmd"
