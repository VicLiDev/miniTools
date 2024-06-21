#!/usr/bin/bash
#########################################################################
# File Name: 10.rkFlameGraph.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu Sep 21 09:11:08 2023
#########################################################################

# 使用方法：
# disable 其他 cpu core:
#   1. 修改 /sys/devices/system/cpu/cpu1/online
#   2. lscpu 或 lscpu 可以看cpu状态
#
# 将用来生成火焰图的码流放在 vstream 文件夹下，脚本会推到 /sdcard 中，这两个目录
# 可以在全局变量中修改
#
# ex: bash 10.rkFlameGraph.sh --plt 3576_old --prot h265 --ins 6

cmd_pltform=""
reportDir=""
cmd_instance=""
cmd_prot=""
mpp_prot_type=""

pltRoot="/sdcard"
logFile="log.txt"
ndkRoot="${HOME}/work/android/ndk/android-ndk-r25c"
strm_dir="vstream"
streams=(`find ${strm_dir} -type f -print | sed 's/vstream\///'`)


function proc_paras()
{
    # 双中括号提供了针对字符串比较的高级特性，使用双中括号 [[ ]] 进行字符串比较时，
    # 可以把右边的项看做一个模式，故而可以在 [[ ]] 中使用正则表达式：
    # if [[ hello == hell* ]]; then
    #
    # 位置参数可以用shift命令左移。比如shift 3表示原来的$4现在变成$1，原来的$5现在变成
    # $2等等，原来的$1、$2、$3丢弃，$0不移动。不带参数的shift命令相当于shift 1。

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            --plt)
                cmd_pltform=$2
                reportDir="report${cmd_pltform}"
                shift # move to next para
                ;;
            --ins)
                cmd_instance=$2
                shift # move to next para
                ;;
            --prot)
                cmd_prot=$2
                shift # move to next para
                ;;
            *)
                # unknow para
                echo "unknow para: ${key}"
                exit 1
                ;;
        esac
        shift # move to next para
    done

    # check paras
    if [[ -z "${reportDir}" || -z "${cmd_prot}" ]]
    then
        echo "usage:"
        echo "bash <curTool> --plt <platform> --ins <instance> --prot <prot>"
        echo "  --plt  Select hardware platform to create dir"
        echo "  --ins  Specify how many MPP instances to create, default=1"
        echo "  --prot Specify the current protocol"
        exit 1
    fi
    if [ -z "${cmd_instance}" ]
    then
        cmd_instance=1
    fi


    # proc dir
    if [ ! -d "${reportDir}" ]; then mkdir "${reportDir}"; fi

    if [ -e ${reportDir}/${logFile} ]; then
        rm ${reportDir}/${logFile}
    fi
    touch ${reportDir}/${logFile}


    # proc prot
    case ${cmd_prot} in
        "h264")
            mpp_prot_type=7
            ;;
        "h265")
            mpp_prot_type=16777220
            ;;
        "avs2")
            mpp_prot_type=16777223
            ;;
        "vp9")
            mpp_prot_type=10
            ;;
        "av1")
            mpp_prot_type=16777224
            ;;
        *)
            echo "unsupport prot: ${cmd_prot}" | tee -a ${reportDir}/${logFile}
            exit 1
            ;;
    esac


    # dump paras
    echo "======> cmd paras <======" | tee -a ${reportDir}/${logFile}
    echo "cmd_pltform:   ${cmd_pltform}" | tee -a ${reportDir}/${logFile}
    echo "cmd_instance:  ${cmd_instance}" | tee -a ${reportDir}/${logFile}
    echo "cmd_prot:      ${cmd_prot}" | tee -a ${reportDir}/${logFile}
    echo "mpp_prot_type: ${mpp_prot_type}" | tee -a ${reportDir}/${logFile}
    echo "reportDir:     ${reportDir}" | tee -a ${reportDir}/${logFile}
    echo "======> cmd paras <======" | tee -a ${reportDir}/${logFile}
    echo | tee -a ${reportDir}/${logFile}
}


function push_stream_to_dev()
{
    echo "==> push ${strm_dir} begin" | tee -a ${reportDir}/${logFile}
    adb push ${strm_dir} ${pltRoot}
    if [ $? == "0" ]; then
        echo "==> exec finish" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    else
        echo "==> exec error $?" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    fi
}



function dumpdata()
{
    proc_tmp=$1
    file_name=$2

    echo "--> dumpinfo txt" | tee -a ${reportDir}/${logFile}

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
        echo "--> exec finish" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    else
        echo "--> exec error $?" | tee -a ${reportDir}/${logFile}
        echo | tee -a ${reportDir}/${logFile}
    fi
}

function modify_instance()
{
    strm=$1

    size=${strm[loop]##*/}
    size=${size%\.h264}
    size=${size%\.h265}
    case ${size%x*} in
        # "480x270")
        "480")
            cmd_instance=128
            ;;
        # "720x480" | "720x480")
        "720")
            cmd_instance=64
            ;;
        "1920")
            cmd_instance=32
            ;;
        "3840")
            if [ $cmd_pltform == "3588" ]; then
                cmd_instance=2
            elif [ $cmd_pltform == "3568" ]; then
                cmd_instance=1
            elif [ $cmd_pltform == "3566" ]; then
                cmd_instance=1
            else
                cmd_instance=1
                # echo "cmd_instance select error ${size} ${cmd_pltform}"
                # exit 0
            fi
            ;;
        *)
            echo "cmd_instance select error ${size} ${cmd_pltform}"
            exit 0
            ;;
    esac
}

function gen_flame_graph()
{
    for ((loop = 0; loop < ${#streams[@]}; loop++))
    do
        nameHtml="${reportDir}/${streams[${loop}]}.html"
        nameTxt="${reportDir}/${streams[${loop}]}.txt"

        # modify_instance ${streams[${loop}]}


        echo "======> ${streams[${loop}]} cmd_instance:${cmd_instance} <======" | tee -a ${reportDir}/${logFile}

        mppCmd="mpi_dec_test -i ${pltRoot}/${strm_dir}/${streams[${loop}]} -t ${mpp_prot_type} -s ${cmd_instance} -v qf"
        perfCmd="adb shell simpleperf record -g -o ${pltRoot}/perf.data ${mppCmd}"
        echo "perf data cmd: $perfCmd" | tee -a ${reportDir}/${logFile}
        $perfCmd 2>&1 | tee -a ${reportDir}/${logFile}
        # adb shell simpleperf record -g -o ${pltRoot}/perf.data ${mppCmd} 2>&1 | tee -a ${reportDir}/${logFile}
        adb pull ${pltRoot}/perf.data


        echo "--> report html" | tee -a ${reportDir}/${logFile}
        reportCmd="python3 ${ndkRoot}/simpleperf/report_html.py --no_browser -i perf.data -o ${nameHtml}"
        echo "report html cmd: ${reportCmd}" | tee -a ${reportDir}/${logFile}
        ${reportCmd} 2>&1 | tee -a ${reportDir}/${logFile}
        if [ $? == "0" ]; then
            echo "--> exec finish" | tee -a ${reportDir}/${logFile}
        else
            echo "--> exec error $?" | tee -a ${reportDir}/${logFile}
        fi


        echo "--> report txt" | tee -a ${reportDir}/${logFile}
        reportCmd="python3 ${ndkRoot}/simpleperf/report.py -g -i perf.data -o ${nameTxt}"
        echo "report txt cmd: ${reportCmd}" | tee -a ${reportDir}/${logFile}
        ${reportCmd} 2>&1 | tee -a ${reportDir}/${logFile}
        if [ $? == "0" ]; then
            echo "--> exec finish" | tee -a ${reportDir}/${logFile}
        else
            echo "--> exec error $?" | tee -a ${reportDir}/${logFile}
        fi


        dumpdata ${cmd_prot} ${nameTxt}

        echo | tee -a ${reportDir}/${logFile}
        rm perf.data
    done
}


function main()
{
    proc_paras $@
    push_stream_to_dev
    gen_flame_graph
}

main $@
