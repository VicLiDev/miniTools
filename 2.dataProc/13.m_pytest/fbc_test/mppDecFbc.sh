#!env bash
#########################################################################
# File Name: mppDecMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 09 Apr 2024 04:20:46 PM CST
#########################################################################

mppCmd="mpi_dec_test -t 10 -i /sdcard/vcut00_01_video_decode_accuracy_and_capability-vp9_3840x2160_30fps.ivf -layout 1"
mppCmd="mpi_dec_test -t 10 -i /sdcard/video_decode_accuracy_and_capability-vp9_3840x2160_30fps.ivf -layout 1"

fbcDir="./fbcdata"
yuvDir="./yuvdata"
mergYuv="./yuvdata/output_conv_fbc.yuv"

create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1"; mkdir -p $1; fi
}

mpp_decfbc()
{
    beg=$1
    end=$2

    if [ -e $fbcDir ]; then rm -rf $fbcDir; fi
    create_dir ${fbcDir}

    for ((i = ${beg}; i < ${end}; i++))
    do
        adb shell setprop cur_dump $i
    
        outputFile="/sdcard/output_3576_${i}.yuv"
        adb shell $mppCmd -o $outputFile
        adb pull $outputFile $fbcDir
    done
}

conv_fbc2yuv()
{
    beg=$1
    end=$2
    size=$3

    if [ -e "${yuvDir}" ]; then rm -rf ${yuvDir}; fi
    create_dir ${yuvDir}

    for ((i = ${beg}; i < ${end}; i++))
    do
        inFile="${fbcDir}/output_3576_${i}.yuv"
        outFile="${yuvDir}/yuv_${i}.yuv"
        cmd="wine ./format_trans.exe -i $inFile -D ${size}_yuv4208b_0_${size}_yuv4208b_2_0_0 -o ${outFile} -n 1"
        echo cmd:$cmd
        $cmd
        if [ $? -ne 0 ]; then echo "convert error!!!"; exit 1; fi
    
        cat $outFile >> ${mergYuv}
    done
}

main()
{
    mpp_decfbc $1 $2
    conv_fbc2yuv $1 $2 3840x2160
}



main 0 120
