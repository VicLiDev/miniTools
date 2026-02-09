#!/usr/bin/env bash
#########################################################################
# File Name: rname.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 07 May 2025 10:11:07 PM CST
#########################################################################

for file in *.mpg
do
    echo
    echo "==> $file"
    newname=$(echo "$file" | tr ' ' '_' | tr '(' '_' | tr ')' '_' | tr '[' "_" | tr ']' '_')
    echo "newname ${newname}"
    mv "$file" "$newname"
done
