#!env bash
#########################################################################
# File Name: compareInterBs.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 03 Jun 2023 04:48:52 PM CST
#########################################################################

logfile="inter_bs_batch_test_log.txt"
startFrm=0
endFrm=10

# %s/\/home3\/group_db\/mmip\/testdata\/video_data\/decoder\/allegro_hevc_stream/\/test_data\/allegro_hevc_stream/gc
# %s/\/home3\/group_db\/mmip\/testdata\/video_data\/decoder\/argon_streams_hevc_rockchip2/\/test_data\/argon_streams_hevc_rockchip2/gc
testCmd="./hm -b ${startFrm} -e ${endFrm} -g hevc_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF,mc=0xFFFFFFFFFFFFFFFF,inter=0xffffffffffffffff -d testOut"

rm ${logfile}
for file in `cat ../doc/allegro_hevc_stream_file_best`
do
    echo "--> file: ${file}" | tee -a $logfile
    echo "--> test cmd: ${testCmd} -i ${file}" | tee -a $logfile
    ${testCmd} -i ${file}

    ctuSize=`cat testOut/Frame0000/loopfilter_debug.txt | grep "CTU Size" | awk '{print $4}' | head -n 1`
    ctuSize=${ctuSize:5}
    echo "ctu size: ${ctuSize}" | tee -a $logfile
    ~/Projects/compareInterBs.py ${startFrm} ${endFrm} ${ctuSize} | tee -a $logfile
    echo
done
