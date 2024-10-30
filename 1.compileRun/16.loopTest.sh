#!/usr/bin/env bash
#########################################################################
# File Name: loopTest.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2022年04月13日 星期三 11时16分00秒
#########################################################################

times=0
if [ -n "$1" ]; then times=$1; else echo "def times: 100"; times=100; fi
echo "test times: ${times}"


idx=0
runOpt=""

# adbCmd=`adbs`
while [ True ]
do
    if [ ${times} -ne "-1" ]; then if [ $idx -ge $times ]; then break; fi fi

    echo
    echo "========> lhj loop test ${idx} <========"

    if [ "${runOpt}" != "c" ]; then
        read -p "continue? [y/n/c] def[y]:" runOpt
        if [ "$runOpt" = "n" ];then exit 0; fi
    fi

    # exec cmd ====== begin
    # paras=""

    runCmd=""
    echo "run Cmd: ${runCmd}"
    ${runCmd}
    if [ $? -eq 0 ]; then
        # echo -e "test loop idx: ${idx} \033[0m\033[1;32m pass  \033[0m"
        printf "test loop idx: %s \033[0m\033[1;32m pass  \033[0m\n" "$idx"
    else
        # echo -e "test loop idx: ${idx} \033[0m\033[1;31m faile \033[0m"
        printf "test loop idx: %s \033[0m\033[1;31m faile \033[0m\n" "$idx"
    fi

    # exec cmd ====== end

    idx=`expr $idx + 1`
done
