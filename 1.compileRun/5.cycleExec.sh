#!env bash
#########################################################################
# File Name: 5.delayExec.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年06月04日 星期日 22时15分59秒
#########################################################################


#======> loop sleep code
# 以下代码不需要考虑跨天的问题，指定功能会在下次到达设定时间时执行
# 可以参考定时代码编写年月日的等待代码
otime="00:22:20"                  # 定时时间 -- need modify
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
}

echo "The timing time is : ${otime}, the current time is : ${ctime}"
# otime is tomorrow
while true
do
    # sleep next day
    if [ "`expr $otime_h - $ctime_h`" -lt 0 ]; then
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1h"
        sleep 1h # sleep 1h
        updateTime
        continue
    elif [ "`expr $otime_h - $ctime_h`" -eq 0 ] \
       && [ "`expr $otime_m - $ctime_m`" -lt 0 ] ; then
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1h"
        sleep 1h # sleep 1h
        updateTime
        continue
    elif [ "`expr $otime_h - $ctime_h`" -eq 0 ] \
       && [ "`expr $otime_m - $ctime_m`" -eq 0 ] \
       && [ "`expr $otime_s - $ctime_s`" -lt 0 ] ; then
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1h"
        sleep 1h # sleep 1h
        updateTime
        continue
    fi
    break
done

# otime is today
while [ "${ctime_h}" -lt "${otime_h}" ] \
      || [ "${ctime_m}" -lt "${otime_m}" ] \
      || [ "${ctime_s}" -lt "${otime_s}" ]
do
    # sleep
    if [ "`expr $otime_h - $ctime_h`" -gt 1 ]; then
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1h"
        sleep 1h # sleep 1h
    elif [ "`expr $otime_m - $ctime_m`" -gt 1 ]; then
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1m"
        sleep 1m # sleep 1m
    else
        echo -e "current time is `date +"%H:%M:%S"` otime is ${otime} sleep 1s"
        sleep 1 # sleep 1s
    fi

    # update cur time
    updateTime
    # echo "ctime:${ctime} H:${ctime_h} M:${ctime_m} S:${ctime_s}"
    # echo "otime:${otime} H:${otime_h} M:${otime_m} S:${otime_s}"
done
echo "ctime:"${ctime} " eq otime:"${otime}
#======> loop sleep code end


# exec func
echo "begin exec"





# # 参考博客： https://blog.csdn.net/yipiantian/article/details/122179152
# # 以下代码可以不考虑跨天的问题，直接以时间字符串比较，但等待时间只能是固定时常，
# # 不然会有时间字符串卡不上的问题
# ## loop sleep code ##
# #otime="16:35:01"                  #定时时间
# otime="10:00:01"                  #定时时间
# ctime=`date +"%H:%M:%S"`          #当前时间
# step=5                            #消息间隔步长
# echo "The timing time is : "${otime}, "the current time is : "${ctime} " the step is "${step}
# while [[ "${ctime}" != "${otime}" ]]
# do
#     sleep 1
#     ctime=`date +"%H:%M:%S"`
#     mi=`date +"%M"`                  #分钟
#     sec=`date +"%S"`                 #秒
#     rs=`expr ${mi} % ${step}`        #分钟与间隔取余
# 
#     if [ ${rs} = 0 ] && [ ${sec} = "01" ]
#     then
#         echo -e "current time is "`date +"%H:%M:%S"` " wait a few minutes."
#         #else
#         #echo "sleep 1 second : "`date +"%H:%M:%S"` " -- M: ${mi} S: ${sec} not !"
#     fi
# done
# echo "ctime:"${ctime} " eq otime:"${otime}
# ## loop sleep code  ##
