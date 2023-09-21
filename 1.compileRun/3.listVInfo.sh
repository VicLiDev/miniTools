#!/bin/bash
#########################################################################
# File Name: listVInfo.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Jan 19 16:48:04 2022
#########################################################################

# usage:
#     列出当前目录下视频文件的信息
#     ./app <scan_dir> > video_info.txt

# IFS='\n' //将字符\和字符n作为IFS的换行符。
# IFS='\n' //与上面一样。
# IFS=$'\n' //正真的使用换行符做为字段分隔符。
# $'string'形式的单词经过特殊处理。该单词扩展为“字符串”，并按ANSI C标准的规定替换反斜杠转义字符。
# \n是换行符的转义序列，因此IFS最终被设置为单个换行符。

scanDir=$1

IFS=$'\n'
# path=`cd $(dirname $0);pwd -P`
path=`pwd`
echo "====> scan dir is:${scanDir}"
# for file in `find ${scanDir}`
# for file in `find ${scanDir} | grep -E "ts$|mp4$|mkv$|avs2$|ivf$|mpg$|avi$|flv$|m2v$|wmv$|rmvb$|mov$|mpeg$|bin$|h264$|h265$|mgp$" | grep -E "480|720|1080|3840x2160"`
for file in `find ${scanDir} | grep -E "\.ts$|\.mp4$|\.mkv$|\.avs2$|\.ivf$|\.mpg$|\.avi$|\.flv$|\.m2v$|\.wmv$|\.rmvb$|\.mov$|\.mpeg$|\.bin$|\.h264$|\.h265$|\.mgp$"`
do
    if [ -d "${file}" ]; then
        continue
    fi

    videoInfo=`ffprobe $file 2>&1 | grep -E "Stream.*Video|bitrate"`
    if [ ! $? -eq 0 ]; then
        continue
    fi

    if [ -n "$videoInfo" ]
    then
        echo "file:$file"
        echo "     "`echo $videoInfo | awk 'match($0, /Duration.*Stream/) {print substr($0, RSTART, RLENGTH-6)}'`
        echo "     "`echo $videoInfo | awk 'match($0, /Video.*/) {print substr($0, RSTART, RLENGTH)}'`
    fi
done

filename=`basename $0`
echo "====> script file name is:$filename"
