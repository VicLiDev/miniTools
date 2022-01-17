#########################################################################
# File Name: 5.test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 16 Jan 2022 08:58:38 PM CST
#########################################################################
#!/bin/bash

# 字符串截取
#     http://c.biancheng.net/view/1120.html

inputFiles=(
0.origin.avi
test.webm
test2.avi
test3.mp4
)

fileCnt=${#inputFiles[*]}

function str_to_array()
{
    x=$1
    #默认的IFS值为换行符
    OLD_IFS="$IFS"
    IFS=","
    #以逗号进行分割了
    array=($x)
    #还原默认换行符
    IFS="$OLD_IFS"
    for each in ${array[*]}
    do
        echo $each
    done
}


for ((loop=0; loop<fileCnt; loop++))
do
    if [ ! -f ${inputFiles[loop]} ];then
        echo "file ${inputFiles[loop]} do not exist"
        continue
    fi

    echo
    echo "================ ${inputFiles[loop]}================"
    echo

    # ffmpeg -benchmark -i ${inputFiles[loop]} -f null - 2>&1 \
    #     | grep -E "Input|Output|Stream|frame|rtime" | grep -v -E "Stream mapping:|->"

    filter1="grep -E Input|Output|Stream|^frame|rtime"
    filter2="grep -v -E mapping:|->|Audio"
    videoCmd="ffmpeg -benchmark -i ${inputFiles[loop]} -an -f null -"
    $videoCmd 2>&1 | $filter1 | $filter2
    ffmpegLog=$($videoCmd 2>&1 | $filter1 | $filter2)
    # echo
    # echo $ffmpegLog

    # echo '-------- log separation --------'
    inputlog=${ffmpegLog%Output*}
    logTmp=Output:${ffmpegLog#*Output}
    # echo $inputlog
    outputlog=${logTmp%frame=*}
    # echo $outputlog
    lastLine="frame="${logTmp#*frame=}
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

    echo "-------- dump info --------"
    # echo size:${inputlog#*frame=} | awk '{gsub(/^\s+|\s+$/, "");print}' | awk '{print $1}'
    # echo ${testStr}|awk '{match($0,/([0-9]+(-)[0-9]+(-)[0-9]+( 00%3A00%3A00.0))/,a)} {print a[0]}'
    echo 

    # eval 指令配合 echo 去掉字符串前后的空格，但好像只能保留第一列数据
    echo '==> input'
    echo "color:   "`echo yuv${inputlog#*yuv} | awk -F"," '{print $1}' | awk -F"(" '{print $1}'`
    echo "fps:     "`echo ${inputlog%fps,*} | awk '{print $NF}'`
    echo "size:    "`echo ${inputlog#*yuv} | awk 'match($0,/[0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    echo
    echo '==> output'
    echo "color:   "`echo yuv${outputlog#*yuv} | awk -F"," '{print $1}'`
    echo "fps:     "`echo ${outputlog%fps,*} | awk '{print $NF}'`
    echo "size:    "`echo ${outputlog#*yuv} | awk 'match($0,/[0-9]+x[0-9]+/) {print substr($0, RSTART, RLENGTH)}'`

    echo
    echo '==> general'
    echo "frame:   "`eval echo ${lastLine#*frame=} | awk '{print $1}'`
    echo "bitrate: "`eval echo ${lastLine#*bitrate=} | awk '{print $1}'`
    echo "rtime:   "${lastLine#*rtime=}
    frames=`eval echo ${lastLine#*frame=} | awk '{print $1}'`
    rtime=`echo ${lastLine#*rtime=} | awk -F"s" '{print $1}'`
    echo "frame/s: "$frames/$rtime

done
