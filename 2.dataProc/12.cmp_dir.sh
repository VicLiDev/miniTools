#!/bin/bash
#########################################################################
# File Name: check_data.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri Oct 20 16:32:21 2023
#########################################################################

# compare all files in two dir
# ex: bash ./12.check_data.sh <dir1/file1> <dir2/file2>

if [ $# -lt 2 ]; then
    echo "too few parameters"
    help
    exit 1
fi
dataDir1=$1
dataDir2=$2

if [ `find ${dataDir1} | wc -l` -ne `find ${dataDir2} | wc -l` ]; then
    echo "dir1 file cnt: `find ${dataDir1} | wc -l`"
    echo "dir2 file cnt: `find ${dataDir2} | wc -l`"
    exit 1
fi

for file in `find ${dataDir1} | sort`
do
    file1=${dataDir1}${file##*${dataDir1}}
    file2=${dataDir2}${file##*${dataDir1}}

    if [ ! -e ${file1} ]; then echo "${file1} not exist"; exit 1; fi
    if [ ! -e ${file2} ]; then echo "${file2} not exist"; exit 1; fi
    if [ ! -f ${file1} ] && [ ! -f ${file2} ]; then continue; fi

    frmIdx="${file1##*Frame}"
    frmIdx="${frmIdx##*frame}"
    frmIdx="${frmIdx##*frm}"
    frmIdx="${frmIdx%%/*}"
    if [ "${frmIdx}" = "${file1}" ]; then frmIdx=""; fi
    if [ -n "${frmIdx}" ]; then frmIdx="Frame${frmIdx}"; fi
    fileNmae="${file1##*/}"

    md5Val1=`md5sum ${file1} | awk '{print $1}'`
    md5Val2=`md5sum ${file2} | awk '{print $1}'`
    if [ $md5Val1 != $md5Val2 ]; then
        echo "--> [res]: ${frmIdx} file: ${fileNmae} compare faile    vimdiff ${file1} ${file2}"
        exit 1
    else
        echo "--> [res]: ${frmIdx} file: ${fileNmae} compare pass"
    fi
    
done
