#########################################################################
# File Name: 5.test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 16 Jan 2022 08:58:38 PM CST
#########################################################################
#!/bin/bash

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

    filter1="grep -E Input|Output|Stream|^frame|rtime"
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
        # videoCmd="$prefix ffmpeg -benchmark -threads 1 -i ${inputFile} -threads 1 -pix_fmt $rawFmt -an -f null -"
        videoCmd="$prefix ffmpeg -benchmark -i ${inputFile} -pix_fmt $rawFmt -an -f null -" #指定输出格式的话时间会稍长一点，不指定稍短一点，这里按照长的时间测试
    else
        echo "test type error"
    fi
    #-- exec
    # $videoCmd
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
    inColor=`echo ${inputlog} | awk 'match($0, /(yuv|nv)[0-9]./) {print substr($0, RSTART, RLENGTH)}'`
    inFps=`echo ${inputlog%fps,*} | awk '{print $NF}'`
    inSize=`echo ${inputlog} | awk 'match($0, /(yuv|nv)[0-9].*/) {print substr($0, RSTART, RLENGTH)}' | awk 'match($0,/[0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    outColor=`echo ${outputlog} | awk 'match($0, /(yuv|nv)[0-9]./) {print substr($0, RSTART, RLENGTH)}'`
    outFps=`echo ${outputlog%fps,*} | awk '{print $NF}'`
    outSize=`echo ${outputlog} | awk 'match($0, /(yuv|nv)[0-9].*/) {print substr($0, RSTART, RLENGTH)}' | awk 'match($0,/[0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    frames=`eval echo ${lastLine#*frame=} | awk '{print $1}'`
    rtime=`echo ${lastLine#*rtime=} | awk -F"s" '{print $1}'`
    bitrate=`eval echo ${lastLine#*bitrate=} | awk '{print $1}'`

    echo '==> in'
    echo "color:   "$inColor
    echo "fps:     "$inFps
    echo "size:    "$inSize

    echo '==> out'
    echo "color:   "$outColor
    echo "fps:     "$outFps
    echo "size:    "$outSize

    echo '==> gen'
    echo "bitrate: "$bitrate
    echo "frame:   "$frames
    echo "rtime:   "$rtime s
    echo "frame/s: "$frames/$rtime

    echo '==> result'
    printf "%-10s %-8s %-8s %-3s %-20s %-10s %-10s %-20s\n" "size" "framsCnt" "color" "fps" "source" "bitrate" "rtime" "frame/s"
    printf "%-10s %-8s %-8s %-3s %-20s %-10s %-10s %-20s\n" $inSize $frames $inColor $inFps ${inputFile} $bitrate $rtime $frames/$rtime
}


# ====================================== exec ======================================
# prefix="adb shell"

# ------------------ dec test ------------------
decInputFiles=(
test.webm
# encode: nv12 to jpeg2000
# decode: yuv420p to nv12
# /userdata/media/0.origin_mpeg1.mpeg
# /userdata/media/0.origin_mpeg2.mpeg
# /userdata/media/0.origin_mpeg2_1920x1080.mpg
# /userdata/media/0.origin_mpeg4.mpeg
)
decFileCnt=${#decInputFiles[*]}

testType="decode"
rawFmt="nv12"
for ((loop=0; loop<decFileCnt; loop++))
do
    videoCodec $testType ${decInputFiles[loop]} $rawFmt
done


# ------------------ enc test ------------------
encInputFiles=(
# /userdata/media/alisan420sp_nv12.yuv
# alisan420sp_nv12.yuv
# output420sp_NV12.yuv
)
encFileCnt=${#encInputFiles[*]}

testType="encode"
rawFmt="nv12"
# jpeg2000 jpegls mjpeg
encoder=jpeg2000
encodeSize=1920X1080
for ((loop=0; loop<encFileCnt; loop++))
do
    videoCodec $testType ${encInputFiles[loop]} $rawFmt $encoder $encodeSize
done
