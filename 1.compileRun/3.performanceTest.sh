#########################################################################
# File Name: 5.test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 16 Jan 2022 08:58:38 PM CST
#########################################################################
#!/usr/bin/env bash

# 字符串截取
#     http://c.biancheng.net/view/1120.html
#     https://cloud.tencent.com/developer/article/1530111
# awk:
#     https://cloud.tencent.com/developer/article/1159061

# usage:
#     1. 按照需要使能/去使能cpu核心
#     2. 根据需要修改videoCmd 指令修改线程数量
#     3. testType: 选择编码测试或解码测试
#     4. rawFmt：设置raw的格式，在编码测试时表示输入，在解码测试时表示输出
#     5. encoder：指定编码时需要的编码器
#     6. 修改编解码测试需要的文件
#     7. 除了最后的result需要查看，其他echo信息均可以屏蔽掉
#     8. 需要使用adb测试时放开 prefix 变量
#注意：文件名中间不能有空格，要注意处理


function videoCodec()
{
    testType=$1
    inputFile=$2
    rawFmt=$3
    encoder=$4
    encodeSize=$5
    # if [ ! -f ${inputFile} ];then
    #     echo "file ${inputFile} do not exist"
    #     continue
    # fi

    echo
    echo "================ ${inputFile} ================"
    echo

    filter1="grep -E Input|Output|Stream|Duration|^frame|rtime"
    filter2="grep -v -E mapping:|->|Audio"

    if [ $testType == "encode" ]
    then
        echo "encode test"
        #-- encode
        videoCmd="$prefix ffmpeg -benchmark -f rawvideo -pix_fmt $rawFmt -s:v $encodeSize -r 25 -i ${inputFile} -c:v $encoder -f null -"
    elif [ $testType == "decode" ]
    then
        echo "decode test"
        #-- decode
        # videoCmd="$prefix ffmpeg -benchmark -threads 1 -i ${inputFile} -threads 1 -an -f null -"
        videoCmd="$prefix ffmpeg -benchmark -i ${inputFile} -an -f null -" #指定输出格式的话时间会稍长一点，不指定稍短一点，这里按照长的时间测试
    else
        echo "test type error"
        return 0
    fi
    #-- exec
    # $videoCmd
    # if [ $? -ne 0 ]
    # then
    #     echo "exec ffmpeg cmd error!"
    #     echo $ffmpegLog
    #     return
    # fi
    ffmpegLog=$($videoCmd 2>&1 | $filter1 | $filter2 | sed -e 's/\r//g') # 使用sed去掉换行符
    # echo "-- ffmpegLog"
    # echo $ffmpegLog

    # echo '-------- log separation --------'
    inputlog=${ffmpegLog%Output*}
    logTmp=Output${ffmpegLog#*Output}
    # echo "-- intput" 
    # echo $inputlog
    outputlog=${logTmp%frame=*}
    # echo "-- outtput"
    # echo $outputlog
    lastLine="frame="${logTmp##*frame=}
    # echo "-- lastline"
    # echo $lastLine

    # echo "-------- data dump --------"
    # #默认的IFS值为换行符
    # OLD_IFS="$IFS"
    # IFS=","
    # #以逗号进行分割了
    # array=($ffmpegLog)
    # #还原默认换行符
    # IFS="$OLD_IFS"
    # for each in ${array[*]}
    # do
    #     echo $each | grep -E "Input|Output|[0-9]x[0-9]|yuv|fps|bitrate|rtime"
    # done

    # echo "-------- dump info --------"
    # eval 指令配合 echo 去掉字符串前后的空格，但好像只能保留第一列数据
    inProc=`echo ${inputlog} | awk 'match($0, /Video:.*/) {print substr($0, RSTART+6, RLENGTH)}' | awk -F"," '{print $1}' | awk '{print $1}'`
    inColor=`echo ${inputlog} | awk 'match($0, /(yuv|yuvj|nv)[0-9]+[a-z]?+/) {print substr($0, RSTART, RLENGTH)}'`
    inFps=`echo ${inputlog%fps,*} | awk '{print $NF}'`
    inSize=`echo ${inputlog} | awk 'match($0, /(yuv|yuvj|nv)[0-9]+[a-z]?+.*/) {print substr($0, RSTART, RLENGTH)}' \
        | awk 'match($0,/[0-9][0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    outProc=`echo ${outputlog} | awk 'match($0, /Video:.*/) {print substr($0, RSTART+6, RLENGTH)}' | awk -F"," '{print $1}' | awk '{print $1}'`
    outColor=`echo ${outputlog} | awk 'match($0, /(yuv|yuvj|nv)[0-9]+[a-z]?+/) {print substr($0, RSTART, RLENGTH)}'`
    outFps=`echo ${outputlog%fps,*} | awk '{print $NF}'`
    outSize=`echo ${outputlog} | awk 'match($0, /(yuv|yuvj|nv)[0-9]+[a-z]?+.*/) {print substr($0, RSTART, RLENGTH)}' \
        | awk 'match($0,/[0-9][0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    frames=`eval echo ${lastLine#*frame=} | awk '{print $1}'`
    rtime=`echo ${lastLine#*rtime=} | awk -F"s" '{print $1}'`
    if [ $testType == "encode" ]
    then
        bitrate=`eval echo ${lastLine#*bitrate=} | awk '{print $1}'`
    elif [ $testType == "decode" ]
    then
        bitrate=`eval echo ${inputlog#*bitrate:} | awk '{print $1}'`
    else
        echo "test type error"
        return 0
    fi

    echo '==> in'
    echo "inProc:  "$inProc
    echo "color:   "$inColor
    echo "fps:     "$inFps
    echo "size:    "$inSize

    echo '==> out'
    echo "outProc: "$outProc
    echo "color:   "$outColor
    echo "fps:     "$outFps
    echo "size:    "$outSize

    echo '==> gen'
    echo "bitrate: "$bitrate
    echo "frame:   "$frames
    echo "rtime:   "$rtime s
    echo "frame/s: "$frames/$rtime

    echo '==> result'
    printf "%-10s %-8s %-10s %-8s %-8s %-6s %-14s %-10s %-15s %-20s\n" "inProc" "testType" "size" "frameCnt" "color" "fps" "bitrate(kb/s)" "rtime" "frame/s" "source"  
    printf "%-10s %-8s %-10s %-8s %-8s %-6s %-14s %-10s %-15s %-20s\n" $inProc $testType $inSize $frames $inColor $inFps $bitrate $rtime $frames/$rtime ${inputFile} 
}


# ====================================== exec ======================================
prefix="adb shell"

# ------------------ dec test ------------------
decInputFiles=(
# test.webm
# 0.origin.avi
# encode: nv12 to jpeg2000
# decode: yuv420p to nv12
# /userdata/media/0.origin_mpeg1.mpeg
# /userdata/media/0.origin_mpeg2.mpeg
# /userdata/media/0.origin_mpeg2_1920x1080.mpg
# /userdata/media/0.origin_mpeg4.mpeg
#================> mpeg1
"他还是不懂.DAT"
"Qual3_Original_QVGA_mpeg1_30fps.mpeg"
#================> mpeg2
"3d电视演示短片www.233d.com左右格式1920x1080393M.mkv"
"00125.m2ts"
"50110.m2ts"
"1080p-60F.avi"
#================> mpeg4
"1080p-60F.avi"
"720P_diyunan.h26500_01_36-00_01_39.mp4"
"OnlineNews.mp4"
#================> WMV
"1920x1080,8000Kbps,23.976fps,WMV3,WMA3,192Kbps,高清试机短片系列.Good.Night.and.Good.Luck.wmv"
"test.wmv"
"CH1心理學可以告訴你什麼？.wmv"
#================> H.263
"3G2_1.3g2"
"3gp_1.3gp"
"3GP_2.3gp"
"3G2_1.3g2"
#================> vp6
"VP6视频0.flv"
"VP6视频0.flv"
#================> vp8
"变形金刚2卷土重来sample.webmvp8.webm"
"27-IFF_ILBM-VORBIS"
#================> rmvb
#================> H.264
"1920x1080,27.0Mbps,23.976fps,AVC,DTSAC3AC3,1536Kbps,变形金刚2：卷土重来sample.mkv"
"akiyo_1280x720_3mbps.bin"
"BQMall_1280x720_8mbps.bin"
"1920x1080,12.4Mbpss,AVC,23.976fps,DTS1536Kbps,,Arahan.2004.BluRay.1080p.DTS.x264-CHD.sample.mkv"
#================> jpeg
"BDLive_HSceneBG_generic.jpg"
"A13_BDJ_Jacket_LRG.jpg"
"01600_doodledoorjurassicicondorset_1920x1200.jpg"
)
decFileCnt=${#decInputFiles[*]}

fileRootDir="/userdata/media/testVideo/"
testType="decode"
for ((loop=0; loop<decFileCnt; loop++))
do
    videoCodec $testType "$fileRootDir${decInputFiles[loop]}"
done


# ------------------ enc test ------------------
encInputFiles=(
alisan420sp_nv12.yuv
# alisan420sp_nv12.yuv
# output420sp_NV12.yuv
)
encFileCnt=${#encInputFiles[*]}

fileRootDir=""
fileRootDir="/userdata/media/"
testType="encode"
rawFmt="nv12"
# jpeg2000 jpegls mjpeg
encoder=jpeg2000
encodeSize=1920X1080
for ((loop=0; loop<encFileCnt; loop++))
do
    videoCodec $testType "$fileRootDir${encInputFiles[loop]}" $rawFmt $encoder $encodeSize
done

encoder=jpegls
for ((loop=0; loop<encFileCnt; loop++))
do
    videoCodec $testType "$fileRootDir${encInputFiles[loop]}" $rawFmt $encoder $encodeSize
done

encoder=mjpeg
for ((loop=0; loop<encFileCnt; loop++))
do
    videoCodec $testType "$fileRootDir${encInputFiles[loop]}" $rawFmt $encoder $encodeSize
done
