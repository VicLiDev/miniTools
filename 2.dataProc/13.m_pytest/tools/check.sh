#!env bash
#########################################################################
# File Name: check.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Oct 30 13:55:43 2023
#########################################################################
rootDir1="dir1"
rootDir2="dir2"

if [ -e pp.txt ]; then rm pp.txt; fi
if [ -e nn.txt ]; then rm nn.txt; fi

for file in `cat file.txt`
do
    file1="${rootDir1}/${file}"
    file2="${rootDir2}/${file}"
    # echo "${file}:"
    diff -Nur ${file1} ${file2} | grep -E "^\+index|^\-index" | sed "s/index.*val://g" | sort | grep "^\+" | sed "s/\+//g" >> pp.txt
    diff -Nur ${file1} ${file2} | grep -E "^\+index|^\-index" | sed "s/index.*val://g" | sort | grep "^\-" | sed "s/\-//g" >> nn.txt
done

diff pp.txt nn.txt > /dev/null
if [ $? -ne 0 ]; then
    echo "error"
else
    echo "ok"
fi
rm file.txt
rm pp.txt
rm nn.txt
