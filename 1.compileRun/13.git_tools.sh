#!/usr/bin/env bash
#########################################################################
# File Name: 13.git_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 28 Jun 14:46:50 2024
#########################################################################

# add to bashrc:
# source ${HOME}/Projects/miniTools/1.compileRun/13.git_tools.sh

# ====== commit forward/backword ======
get_commit_info()
{
    cnt=1
    opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cnt="$2"; if [ -z "$cnt" ]; then return 1; fi; shift; ;;
            -l) opt_loc="$2"; if [ -z "$opt_loc" ]; then return 1; fi; shift; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done
    echo "loc: $opt_loc"

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    cur_commit=$(git log --oneline -n 1 ${opt_loc})
    cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    echo "cur commit:        ${cur_commit}"
    echo "cur com_id:        ${cur_com_id}"
    echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config --list | grep "branch.${cur_remote_br}.remote" | sed "s/.*=//g")
    echo "remote repo:       ${remote_repo}"
    echo "cur remote branch: ${cur_remote_br}"

    forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                   --oneline ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    echo "forward commit:    ${forward_commit}"
    echo "forward com_id:    ${forward_com_id}"
    echo

    # backward
    backward_commit=$(git log --oneline -n `expr ${cnt} \* 2` ${opt_loc} | grep -A ${cnt} ${cur_com_id} | tail -1)
    backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    echo "backward commit:   ${backward_commit}"
    echo "backward com_id:   ${backward_com_id}"
}

gmf()
{
    cnt=1
    opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cnt="$2"; if [ -z "$cnt" ]; then return 1; fi; shift; ;;
            -l) opt_loc="$2"; if [ -z "$opt_loc" ]; then return 1; fi; shift; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    cur_commit=$(git log --oneline -n 1 ${opt_loc})
    cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config --list | grep "branch.${cur_remote_br}.remote" | sed "s/.*=//g")
    # echo "remote repo:       ${remote_repo}"
    # echo "cur remote branch: ${cur_remote_br}"

    forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                   --oneline ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    # echo "forward commit:    ${forward_commit}"
    # echo "forward com_id:    ${forward_com_id}"
    # echo

    git reset --hard ${forward_com_id}
}

gmb()
{
    cnt=1
    opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cnt="$2"; if [ -z "$cnt" ]; then return 1; fi; shift; ;;
            -l) opt_loc="$2"; if [ -z "$opt_loc" ]; then return 1; fi; shift; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    cur_commit=$(git log --oneline -n 1 ${opt_loc})
    cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # backward
    backward_commit=$(git log --oneline -n `expr ${cnt} \* 2` ${opt_loc} | grep -A ${cnt} ${cur_com_id} | tail -1)
    backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    # echo "backward commit:   ${backward_commit}"
    # echo "backward com_id:   ${backward_com_id}"

    git reset --hard ${backward_com_id}
}


alias gonel="git log --pretty=format:'%C(yellow)%h %C(blue)author: %<|(40)%an %C(cyan)%ci %C(auto) %s %d'"
