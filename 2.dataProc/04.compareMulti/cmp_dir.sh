#!/usr/bin/env bash
#########################################################################
# File Name: cmp_dir.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri Oct 20 16:32:21 2023
#########################################################################

# compare all files in two dir
# ex: bash ./12.check_data.sh <dir1/file1> <dir2/file2> [q]

if [ $# -lt 2 ]; then
    echo "too few parameters"
    echo "ex: bash ./12.check_data.sh <dir1/file1> <dir2/file2> [q]"
    exit 1
fi
dataDir1=$1
dataDir2=$2
diffQuit="${3:-}"
cmpRet=0

# if [ ${dataDir1:0:1} != "/" ]; then echo "Please input abs path"; exit 1; fi
# if [ ${dataDir2:0:1} != "/" ]; then echo "Please input abs path"; exit 1; fi

[ ! -e "$dataDir1" ] && { echo "dir1 not exist: $dataDir1"; exit 1; }
[ ! -e "$dataDir2" ] && { echo "dir2 not exist: $dataDir2"; exit 1; }

if [ `find ${dataDir1} | wc -l` -ne `find ${dataDir2} | wc -l` ]; then
    echo "dir1 file cnt: `find ${dataDir1} | wc -l`"
    echo "dir2 file cnt: `find ${dataDir2} | wc -l`"
    if [ "$diffQuit" == "q" ];then exit 1; fi
fi

for file in `find ${dataDir1} | sort`
do
    file1="${dataDir1}${file##*${dataDir1}}"
    file2="${dataDir2}${file##*${dataDir1}}"

    if [ ! -f ${file1} ] && [ ! -f ${file2} ]; then continue; fi
    if [ ! -e ${file2} ]; then
        cmpRet=1
        echo "--> [res]: ${file2} not exist"
        if [ "$diffQuit" == "q" ];then exit 1; else continue; fi
    fi

    # 正则表达式用法可以参考 shell 文档
    frmIdx=""
    if [[ "$file1" =~ ([Ff]rame|frm)([0-9]+) ]]; then
        frmIdx="Frame${BASH_REMATCH[2]}"
    fi


    fileNmae="${file1##*/}"

    md5Val1=`md5sum ${file1} | awk '{print $1}'`
    md5Val2=`md5sum ${file2} | awk '{print $1}'`
    if [ $md5Val1 != $md5Val2 ]; then
        cmpRet=1
        echo -e "--> [res]: ${frmIdx} file: ${fileNmae} \033[0m\033[1;31m compare failed \033[0m    vimdiff ${file1} ${file2}"
        if [ "$diffQuit" == "q" ];then exit 1; fi
    else
        echo -e "--> [res]: ${frmIdx} file: ${fileNmae} \033[0m\033[1;32m compare pass  \033[0m"
    fi
done

exit $cmpRet
