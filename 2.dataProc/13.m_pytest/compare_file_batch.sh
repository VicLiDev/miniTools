#!/bin/bash
#########################################################################
# File Name: compare_file_batch.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 28 Feb 2024 09:45:38 AM CST
#########################################################################

bgIdx=0
edIdx=10

dir1="path_to_dir1"
dir2="path_to_dir2"

file_name1="global_cfg.dat"
file_name2="global_cfg.dat"

for ((i = ${bgIdx}; i < ${edIdx}; i++))
do
    frm_no=`printf "%04d" $i`
    echo; echo "Frm:$frm_no"
    file1="${dir1}/Frame${frm_no}/${file_name1}"
    file2="${dir2}/Frame${frm_no}/${file_name2}"
    if [ ! -f ${file1} ]; then echo "file1 is not normal file: ${file1}"; exit 0; fi
    if [ ! -f ${file2} ]; then echo "file2 is not normal file: ${file2}"; exit 0; fi

    read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ]; then exit 0; fi

    # diff -Nur ${file1} ${file2}
    vimdiff ${file1} ${file2}
done
