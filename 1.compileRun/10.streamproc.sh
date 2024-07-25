#!env bash
#########################################################################
# File Name: sourceproc.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Sep 20 17:07:50 2023
#########################################################################

# IFS="\n"
# IFS=$"\n"
# IFS=$'\n'
# 这三个赋值看起来都比较像”将换行符赋值给IFS“，但实际上只有最后一种写法才是我想要的结果。
# IFS="\n" //将字符n作为IFS的换行符。
# IFS=$"\n" //这里\n确实通过$转化为了换行符，但仅当被解释时（或被执行时）才被转化为换行符;第一个和第二个是等价的
# IFS=$'\n' //这才是真正的换行符。

OLDIFS=$IFS
IFS=$'\n'

videoPath=(
    # ==> 480p
    "/Volumes/RKshare/Video_P4_480P/测试视频片源/mp4\ LIB/H.264\ AVC/480x270,458\ Kbps,29.970fps,AVC,AAC,44.6\ Kbps,Macworld.2008.Keynote.mp4"
    # ==> 720p
    "/Volumes/RKshare/Video_4K_1080P_720P/MKV/mkv_720P_2/sample/[幸运库克-sample.mkv"
    "/Volumes/RKshare/芯片级测试/videotest/vdec_0x7f64122320.ts"
    # ==> 1080p
    "/Volumes/RKshare/Video_4K_1080P_720P/24Bit音轨视频文件/1920x1080,,23.976fps,AVC,DTS,,大侦探福尔摩斯sample.mkv"
    "/Volumes/RKshare/Video_4K_1080P_720P/HDL-video/hi3519v101_test_stream/hevc/1080p/Aspen_1080p_4000kbps.h265"
    # ==> 3840x2160
    "/Volumes/RKshare/Video_4K_1080P_720P/HDL-video/rk1109_avc_test_stream/4k/American_3840x2160_16mbps.bin"
    "/Volumes/RKshare/Video_4K_1080P_720P/HDL-video/rk1109_hevc_test_stream/4k/Brazil_3840x2160_16mbps.h265"
    )

rawPath="rawstream"
stmPath="vstream"

if [ ! -d ${rawPath} ]; then mkdir ${rawPath}; fi
if [ ! -d ${stmPath} ]; then mkdir ${stmPath}; fi

videoCnt=${#videoPath[@]}
for ((loop=0; loop<videoCnt; loop++))
do
    locName="./${rawPath}/${videoPath[loop]##*/}"
    if [ ! -e ${locName}  ]; then cp ${videoPath[loop]} ${rawPath}; fi 
done

for file in `find ${rawPath}`
do
    if [ -d ${file} ]; then continue; fi

    # mediainfo --Inform="Video;%Width%,%Height%,%DisplayAspectRatio/String%,%BitRate%,%FrameRate%" <stream>
    stmName="./${stmPath}/`mediainfo --Inform="Video;%Width%x%Height%.%Format%" ${file}`"
    stmName=${stmName,,}
    stmName=${stmName/avc/h264}
    stmName=${stmName/hevc/h265}
    echo $file
    echo $stmName
    ffmpeg -i ${file}  -vcodec copy ${stmName} -y
done

# mpi_enc_test -w 480 -h 270 -t 16777220 -o 480x270.h265 -n 800

IFS=$OLDIFS
