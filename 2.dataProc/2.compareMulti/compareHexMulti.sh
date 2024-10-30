#########################################################################
# File Name: compareHexMulti.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 11 Jan 2022 12:58:16 AM CST
#########################################################################
#!/usr/bin/env bash

# 类c语言
# for ((i=1; i<=100; i++))
# do
#     echo $i
# done

# in使用
# for i in {1..100}
# do
# 	echo $i
# done

# 代码
# for i in `seq 1 100`
# do
# 	echo $i
# done

files=(
1.txt
2.txt
3.txt
)

fileCnt=${#files[*]}

for ((i=0; i<fileCnt; i++))
do
    file1=${files[0]}
    file2=${files[i]}
    cmp -s $file1 $file2
    if [ $? -eq 0 ]
    then
        echo $file1 "is eqal to" $file2
    else
        echo $file1 "is not eqal to" $file2
    fi
done
