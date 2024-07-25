#!env bash
#########################################################################
# File Name: 12.batch_test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Nov 21 15:06:58 2022
#########################################################################

# usage:
#    1. modify test cmd
#    2. run test script and specify the test video root directory

# ex: bash batch_test.c av1 /test_data/Allegro_AV1/Syntax_Main_10bits

clear

logfile="batch_test_log.txt"
# logfile=/dev/null

curPath=`pwd`
echo "curPath: $curPath"
curDir=${curPath#*c_model*/}
echo "curDir: $curDir"
rootPath=${curPath%/$curDir}
echo "rootPath: $rootPath"

proc=$1

function cdDir()
{
    workDir=""
    case $1 in
        "av1")
            workDir="${rootPath}/c_model_av1/build/"
            ;;
        "avs2")
            workDir="${rootPath}/c_model_avs2/RD19.5/"
            ;;
        "vp9")
            workDir="${rootPath}/c_model_vp9_10bit/libvpx-1.11.0/build/"
            ;;
        "avc")
            workDir="${rootPath}/c_model_h264_v2/jm18.6/"
            ;;
        "hevc")
            workDir="${rootPath}/c_model_hevc_v2/build/"
            ;;
        *)
            echo "unsupport proc: $1"
            ;;
    esac

    if [ ! -d "$workDir" ]; then
        echo "dir $workDir is not exist"
        exit 0
    else
        cd $workDir
    fi
}

# check result
function av1ResultCheck()
{
    echo "--> [res]: file check result is null" | tee -a $logfile
}
function hevcResultCheck()
{
    checkCnt=10
    for ((loop=0; loop<checkCnt; loop++))
    do
        # file1="testOut/Frame000${loop}/loopfilter_sao_out_check.txt"
        # file2="testOut/Frame000${loop}/loopfilter_sao_data.dat"
        file1="testOut/Frame000${loop}/loopfilter_data.dat"
        file2="testOut/Frame000${loop}/loopfilter_data_ver.dat"
        if [[ -e ${file1} ]] && [[ -e ${file2} ]]; then
            # echo "file1: ${file1}" | tee -a $logfile
            # echo "file2: ${file2}" | tee -a $logfile
            # diff ${file1} ${file2} > /dev/null
            md5Val1=`md5sum ${file1} | awk '{print $1}'`
            md5Val2=`md5sum ${file2} | awk '{print $1}'`
            if [ $md5Val1 = $md5Val2 ]; then
                echo "--> [res]: frame:${loop} file compare pass" | tee -a $logfile
            else
                echo "--> [res]: frame:${loop} file compare faile    vimdiff ${file1} ${file2}" | tee -a $logfile
            fi
        fi
    done
}
function avs2ResultCheck()
{
    echo "--> [res]: file check result is null" | tee -a $logfile
}
function vp9ResultCheck()
{
    echo "--> [res]: file check result is null" | tee -a $logfile
}
function avcResultCheck()
{
    echo "--> [res]: file check result is null" | tee -a $logfile
}

if [ -e $logfile ]; then
    echo "log file have already exit, old log file while be rm"
    rm $logfile
    echo
fi

echo "====================================" | tee -a $logfile
echo "========> batch test begin <========" | tee -a $logfile
echo "====================================" | tee -a $logfile
date | tee -a $logfile

rootDir=$2
# av1 hevc avs2 vp9 avc
testCmdAV1="./aomdec -o testOut/output.yuv -b 2 -e 5 -c av1_vdp_cfg -g av1_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF -d testOut"
testCmdHEVC="./hm -b 3 -e 5 -g hevc_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF -d testOut"
testCmdAVS2="./Lbuild/bin/ldecod -o output/rec.yuv -b 0 -e 5 -g source/bin/avs2_file_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF -d testOut"
testCmdVP9="./vpxdec -o testOut/rec.yuv -b 3 -e 5 -g vp9_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF -d testOut"
testCmdAVC="./build/jm -b 3 -e 5 -g build/h264_cmodel_cfg -f loopfilter=0xFFFFFFFFFFFFFFFF -d build"
testCmd=$testCmdAV1

cdDir $proc

case ${proc} in
    "av1")
        testCmd=$testCmdAV1
        ;;
    "hevc")
        testCmd=$testCmdHEVC
        ;;
    "avs2")
        testCmd=$testCmdAVS2
        ;;
    "vp9")
        testCmd=$testCmdVP9
        ;;
    "avc")
        testCmd=$testCmdAVC
        ;;
    *)
        echo "unsupport proc"
        ;;
esac

runCtl="null"
ignoreCnt=0
if [ -n "$3" ]; then
    ignoreCnt=$3
fi
ignoreIdx=0
echo "ignore cnt: `expr $ignoreCnt`" | tee -a $logfile

for file in `find ${rootDir}`
do
    # ======> ignore file <======
    # if [ -e ${file} ] \
    #     || [[ ${file} =~ pdf$ ]] \
    #     || [[ ${file} =~ pgp$ ]] \
    #     || [[ ${file} =~ html$ ]] \
    #     || [[ ${file} =~ txt$ ]] \
    #     || [[ ${file} =~ md5$ ]] \
    #     || [[ ${file} =~ md5sum$ ]] \
    #     || [[ ${file} =~ zip$ ]] \
    #     || [[ ${file} =~ cfg$ ]] \
    #     || [[ ${file} =~ [0-9][0-9][0-9][0-9]$ ]]; then
    #     echo "ignore file: ${file}"
    #     continue
    # fi

    # if [[ ${file} =~ AVC_MAIN_TEST_237_13 ]]; then
    #     echo "ianore file: ${file}"
    # fi

    if [ ! -e ${file} ]; then
        continue
    fi

    if ! [[ ${file} =~ \.av1$ ]] \
        && ! [[ ${file} =~ \.bit$ ]] \
        && ! [[ ${file} =~ \.265$ ]] \
        && ! [[ ${file} =~ \.h265$ ]] \
        && ! [[ ${file} =~ \.hevc$ ]] \
        && ! [[ ${file} =~ \.ivf$ ]] \
        && ! [[ ${file} =~ \.vp9$ ]] \
        && ! [[ ${file} =~ \.bin$ ]] \
        && ! [[ ${file} =~ \.avs$ ]] \
        && ! [[ ${file} =~ \.avs2$ ]] \
        && ! [[ ${file} =~ \.H264$ ]] \
        && ! [[ ${file} =~ \.h264$ ]] \
        && ! [[ ${file} =~ \.264$ ]] \
        && ! [[ ${file} =~ \.264l$ ]];then
        continue
    fi

    if [[ ${file} =~ AVC_MAIN_TEST_237_13.h264 ]] \
        || [[ ${file} =~ AVC_MAIN_TEST_228_14.h264 ]] \
        || [[ ${file} =~ AVC_MAIN_TEST_221_12.h264 ]] \
        || [[ ${file} =~ MHza.h264 ]] \
        || [[ ${file} =~ MHzb.h264 ]] \
        || [[ ${file} =~ MHzc.h264 ]] \
        || [[ ${file} =~ MHzd.h264 ]] \
        || [[ ${file} =~ Allegro_MVC_INTER_S13_L41_CAVLC_HD@30Hz_1_r1.8.264 ]] \
        || [[ ${file} =~ Allegro_HEVC_Main_HT50_BADSLICES_00_1920x1080@60Hz_2.7.bin ]] \
        || [[ ${file} =~ test6923_6667_6043.ivf ]] \
        || [[ ${file} =~ test7995_7897.ivf ]] \
        || [[ ${file} =~ test4719_5918_5247.ivf ]] \
        || [[ ${file} =~ test6315_5898.ivf ]] \
        || [[ ${file} =~ test6761_5757_4794.ivf ]] \
        || [[ ${file} =~ test6759.ivf ]] \
        || [[ ${file} =~ test386_692.ivf ]] \
        || [[ ${file} =~ test7069_6393.ivf ]] \
        || [[ ${file} =~ test6777_6400_7237.ivf ]] \
        || [[ ${file} =~ test6795_6603.ivf ]] \
        || [[ ${file} =~ test5530.ivf ]] \
        || [[ ${file} =~ test6079_5118_5836.ivf ]] \
        || [[ ${file} =~ test597.ivf ]] \
        || [[ ${file} =~ test6256.ivf ]] \
        || [[ ${file} =~ test1012.ivf ]] \
        || [[ ${file} =~ test6881_4821.ivf ]] \
        || [[ ${file} =~ test7588_5697_4912.ivf ]] \
        || [[ ${file} =~ AVC_MAIN_TEST_237_14.h264 ]]; then
        continue
    fi

    if [ $ignoreCnt -gt $ignoreIdx ]; then
        ignoreIdx=`expr $ignoreIdx + 1`
        continue
    fi

    # ======> run test <======
    echo
    echo "======> test begin" | tee -a $logfile
    echo "--> file: ${file}" | tee -a $logfile
    echo "--> test cmd: ${testCmd} -i ${file}" | tee -a $logfile

    echo "------ test log ------" | tee -a $logfile
    $testCmd -i ${file}
    if [ $? -eq 0 ]; then
        echo "--> [res]: running test ok" | tee -a $logfile
    else
        echo "--> [res]: running test faile" | tee -a $logfile
        # exit 1
        # break
    fi
    # ----- result check ------
    case ${proc} in
        "av1")
            av1ResultCheck
            ;;
        "hevc")
            hevcResultCheck
            ;;
        "avs2")
            avs2ResultCheck
            ;;
        "vp9")
            vp9ResultCheck
            ;;
        "avc")
            avcResultCheck
            ;;
        *)
            echo "unsupport proc"
            ;;
    esac

    echo "------ test log end ------" | tee -a $logfile

    echo "--> file ${file}" | tee -a $logfile
    echo "======> test finish" | tee -a $logfile
    echo


    # ======> run control <======
    if [ "${runCtl}" == "continueRun" ]; then
        continue
    else
        # read -p "continue/next/quit? [c/n/q] default[n]" runOpt
        runOpt="c"
        case $runOpt in
            'c')
                echo "continue test"
                runCtl="continueRun"
                ;;
            'n')
                echo "next test"
                ;;
            'q')
                echo "exit test"
                break
                ;;
            *)
                echo "next test"
                ;;
        esac
    fi

done

echo "====================================" | tee -a $logfile
echo "=========> batch test end <=========" | tee -a $logfile
echo "====================================" | tee -a $logfile
