#########################################################################
# File Name: listVInfo.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Jan 19 16:48:04 2022
#########################################################################
#!/bin/bash

# usage:
#     列出当前目录下视频文件的信息

# IFS='\n' //将字符\和字符n作为IFS的换行符。
# IFS='\n' //与上面一样。
# IFS=$'\n' //正真的使用换行符做为字段分隔符。
# $'string'形式的单词经过特殊处理。该单词扩展为“字符串”，并按ANSI C标准的规定替换反斜杠转义字符。
# \n是换行符的转义序列，因此IFS最终被设置为单个换行符。

IFS=$'\n'
path=`cd $(dirname $0);pwd -P`
echo "====> the current path is:$path"
for file in `find ./*`
do
    videoInfo=`ffprobe $file 2>&1 | grep -E "Stream.*Video|bitrate"`
    if [ -n "$videoInfo" ]
    then
        echo "file:$file"
        echo "     "`echo $videoInfo | awk 'match($0, /Duration.*Stream/) {print substr($0, RSTART, RLENGTH-6)}'`
        echo "     "`echo $videoInfo | awk 'match($0, /Video.*/) {print substr($0, RSTART, RLENGTH)}'`
    fi
done
filename=`basename $0`
echo "====> script file name is:$filename"
