#!/usr/bin/bash
#########################################################################
# File Name: 10.rkFlameGraph.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu Sep 21 09:11:08 2023
#########################################################################

# disable 其他 cpu core:
#   1. 修改 /sys/devices/system/cpu/cpu1/online
#   2. lscpu 或 lscpu 可以看cpu状态
#
# ex: bash 10.rkFlameGraph.sh 3588

pltRoot="/vendor"
pltRoot="/sdcard"
pltform=$1
reportDir="report${pltform}"
instance=0
execType=7
logFile="log.txt"
ndkRoot="${HOME}/work/android/ndk/android-ndk-r25c"

if [ -e ${reportDir}/${logFile} ]; then
    rm ${reportDir}/${logFile}
fi
touch ${reportDir}/${logFile}

echo "==> push vstreams begin" | tee -a ${reportDir}/${logFile}
adb push vstream ${pltRoot}
if [ $? == "0" ]; then
    echo "==> exec finish" | tee -a ${reportDir}/${logFile}
    echo | tee -a ${reportDir}/${logFile}
else
    echo "==> exec error $?" | tee -a ${reportDir}/${logFile}
    echo | tee -a ${reportDir}/${logFile}
fi

streams=(
    "${pltRoot}/vstream/480x270.h264"
    "${pltRoot}/vstream/480x270.h265"
    "${pltRoot}/vstream/720x480.h264"
    "${pltRoot}/vstream/720x576.h265"
    "${pltRoot}/vstream/1920x1080.h264"
    "${pltRoot}/vstream/1920x1080.h265"
    "${pltRoot}/vstream/3840x2160.h264"
    "${pltRoot}/vstream/3840x2160.h265"
    )


if [ ! -d "${reportDir}" ]; then mkdir "${reportDir}"; fi

function dumpdata()
{
    proc_tmp=$1
    file_name=$2

    echo "==> dumpinfo txt" | tee -a ${reportDir}/${logFile}

    if [ ${proc_tmp} == "h264" ]; then
        strs=(
            "mpp_parser_prepare"
            "mpp_parser_parse"
            "mpp_hal_reg_gen"
            "parse_prepare"
            "parser_one_nalu"
            "prepare_spspps"
            )

        strsCnt=${#strs[@]}
        for ((dump_loop=0; dump_loop<strsCnt; dump_loop++))
        do
            # info=`cat ${file_name} | grep ${strs[dump_loop]} | grep "\-\-"`
            info=`cat ${file_name} | grep ${strs[dump_loop]} | grep -v -E "\-\-|\|"`
            # info=${info//-/ }
            # info=${info//|/ }
            echo ${info} | tee -a ${reportDir}/${logFile}

        done

        # info=`cat ${file_name} | grep -E "parse_prepare|parser_one_nalu|prepare_spspps" | grep "\-\-"`
        # info=${info//-/ }
        # info=${info//|/ }
        # infoCnt=`echo $info | wc -w`
        # infoCnt=`expr $infoCnt / 2`
        # for ((dump_loop=0; dump_loop<infoCnt; dump_loop++))
        # do
        #     # 消除字符串前后的空格，并在开始位置加一个空格，便于截取
        #     info=" "`eval echo $info`
        #     func=${info##*\ }
        #     info=${info%\ *}
        #     # echo $info

        #     # 消除字符串前后的空格，并在开始位置加一个空格，便于截取
        #     info=" "`eval echo $info`
        #     per=${info##*\ }
        #     info=${info%\ *}
        #     # echo $info

        #     echo "func:$func per:$per"
        # done
    elif [ ${proc_tmp} == "h265" ]; then
        strs=(
            "mpp_parser_prepare"
            "mpp_parser_parse"
            "mpp_hal_reg_gen"
            "hevc_find_frame_end"
            "parser_nal_unit"
            "hal_h265d_v345_output_pps_packet"
            )

        strsCnt=${#strs[@]}
        for ((dump_loop=0; dump_loop<strsCnt; dump_loop++))
        do
            # info=`cat ${file_name} | grep ${strs[dump_loop]} | grep "\-\-"`
            info=`cat ${file_name} | grep ${strs[dump_loop]} | grep -v -E "\-\-|\|" | grep -v "parser_nal_units"`
            # info=${info//-/ }
            # info=${info//|/ }
            echo ${info} | tee -a ${reportDir}/${logFile}
        done
    fi
    if [ $? == "0" ]; then
        echo "==> exec finish" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    else
        echo "==> exec error $?" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    fi
}

streamCnt=${#streams[@]}
for ((loop=0; loop<streamCnt; loop++))
do
    proc=${streams[loop]##*\.}
    size=${streams[loop]##*/}
    size=${size%\.h264}
    size=${size%\.h265}
    nameHtml="${reportDir}/${size}_${proc}.html"
    nameTxt="${reportDir}/${size}_${proc}.txt"

    case ${size%x*} in
        # "480x270")
        "480")
            instance=128
            ;;
        # "720x480" | "720x480")
        "720")
            instance=64
            ;;
        "1920")
            instance=32
            ;;
        "3840")
            if [ $pltform == "3588" ]; then
                instance=2
            elif [ $pltform == "3568" ]; then
                instance=1
            elif [ $pltform == "3566" ]; then
                instance=1
            else
                instance=1
                # echo "instance select error ${size} ${pltform}"
                # exit 0
            fi
            ;;
        *)
            echo "instance select error ${size} ${pltform}"
            exit 0
            ;;
    esac

    case ${proc} in
        "h264")
            execType=7
            ;;
        "h265")
            execType=16777220
            ;;
        *)
            ;;
    esac

    echo "======> ${streams[loop]} instance:${instance} <======" | tee -a ${reportDir}/${logFile}

    mppCmd="mpi_dec_test -i ${streams[loop]} -t ${execType} -s ${instance} -v qf"
    perfCmd="adb shell simpleperf record -g -o ${pltRoot}/perf.data ${mppCmd} 2>&1"
    # continue
    echo "cmd: $perfCmd"
    $perfCmd | tee -a ${reportDir}/${logFile}
    # adb shell simpleperf record -g -o ${pltRoot}/perf.data ${mppCmd} 2>&1 | tee -a ${reportDir}/${logFile}
    adb pull ${pltRoot}/perf.data

    echo "==> report html" | tee -a ${reportDir}/${logFile}
    python3 ${ndkRoot}/simpleperf/report_html.py --no_browser -i perf.data -o ${nameHtml} 2>&1 | tee -a ${reportDir}/${logFile}
    if [ $? == "0" ]; then
        echo "==> exec finish" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    else
        echo "==> exec error $?" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    fi

    echo "==> report txt" | tee -a ${reportDir}/${logFile}
    python3 ${ndkRoot}/simpleperf/report.py -g -i perf.data -o ${nameTxt} 2>&1 | tee -a ${reportDir}/${logFile}
    if [ $? == "0" ]; then
        echo "==> exec finish" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    else
        echo "==> exec error $?" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    fi

    dumpdata ${proc} ${nameTxt}

    rm perf.data
done

