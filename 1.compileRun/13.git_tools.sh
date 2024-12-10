#!/usr/bin/env bash
#########################################################################
# File Name: 13.git_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 28 Jun 14:46:50 2024
#########################################################################

# add to bashrc:
# source ${HOME}/Projects/miniTools/1.compileRun/13.git_tools.sh
#
# zsh 在git仓库显示的距离最新节点的距离是用如下方法计算：
# git rev-list --count HEAD..origin/branch_name

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
            -h) echo "get_commit_info [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done
    echo "loc: $opt_loc"

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    # cur_commit=$(git log --oneline -n 1 ${opt_loc})
    # cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit HEAD -- ${opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    echo "cur commit:        ${cur_commit}"
    echo "cur com_id:        ${cur_com_id}"
    echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config --list | grep "branch.${cur_remote_br}.remote" | sed "s/.*=//g")
    echo "remote repo:       ${remote_repo}"
    echo "cur remote branch: ${cur_remote_br}"

    # forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
    #                --oneline ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    # forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    forward_com_id=$(git rev-list --abbrev-commit ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                     -- ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    forward_commit=$(git log --oneline -n 1 ${forward_com_id})
    echo "forward commit:    ${forward_commit}"
    echo "forward com_id:    ${forward_com_id}"
    echo

    # backward
    # backward_commit=$(git log --oneline -n `expr ${cnt} \* 2` ${opt_loc} \
    #                   | grep -A ${cnt} ${cur_com_id} | tail -1)
    # backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    backward_com_id=$(git rev-list --max-count=`expr ${cnt} \* 2` \
                      --abbrev-commit HEAD -- ${opt_loc} \
                      | grep -A ${cnt} ${cur_com_id} | tail -1)
    backward_commit=$(git log --oneline -n 1 ${backward_com_id})
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
            -h) echo "gmf [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    # cur_commit=$(git log --oneline -n 1 ${opt_loc})
    # cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit HEAD -- ${opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config --list | grep "branch.${cur_remote_br}.remote" | sed "s/.*=//g")
    # echo "remote repo:       ${remote_repo}"
    # echo "cur remote branch: ${cur_remote_br}"

    # forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
    #                --oneline ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    # forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    forward_com_id=$(git rev-list --abbrev-commit ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                     -- ${opt_loc} | grep -B ${cnt} ${cur_com_id} | head -1)
    forward_commit=$(git log --oneline -n 1 ${forward_com_id})
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
            -h) echo "gmb [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${opt_loc} | grep $(git rev-parse --short HEAD))
    # cur_commit=$(git log --oneline -n 1 ${opt_loc})
    # cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit HEAD -- ${opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # backward
    # backward_commit=$(git log --oneline -n `expr ${cnt} \* 2` ${opt_loc} \
    #                   | grep -A ${cnt} ${cur_com_id} | tail -1)
    # backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    backward_com_id=$(git rev-list --max-count=`expr ${cnt} \* 2` \
                      --abbrev-commit HEAD -- ${opt_loc} \
                      | grep -A ${cnt} ${cur_com_id} | tail -1)
    backward_commit=$(git log --oneline -n 1 ${backward_com_id})
    # echo "backward commit:   ${backward_commit}"
    # echo "backward com_id:   ${backward_com_id}"

    git reset --hard ${backward_com_id}
}

gfind_node()
{
    git_dir=""
    obj_dir=""
    step="1"
    runOpt=""
    git_root_dir=`git rev-parse --show-toplevel`
    cur_cmp_cnt=""
    last_cmp_cnt=""

    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -g) git_dir="$2"; if [ ! -e "$git_dir" ]; then return 1; fi; shift; ;;
            -o) obj_dir="$2"; if [ ! -e "$obj_dir" ]; then return 1; fi; shift; ;;
            -s) step="$2"; if [ -z "$step" ]; then return 1; fi; shift; ;;
            -h) echo "gfind_node -g <git_dir> -o <obj_dir> [-s <step>,def 1]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done
    [ -z "${git_dir}" ] && { echo "gfind_node -g <git_dir> -o <obj_dir> [-s <step>,def 1]"; return 0;}
    [ -z "${obj_dir}" ] && { echo "gfind_node -g <git_dir> -o <obj_dir> [-s <step>,def 1]"; return 0;}

    while true
    do
        git checkout . && gmb -n ${step} -l ${git_dir}
        rm -rf ${git_dir} && cp -r ${obj_dir} ${git_dir}
        cur_cmp_cnt=`git status --porcelain | grep -v '^??' | wc -l`
        last_cmp_cnt=${last_cmp_cnt:-${cur_cmp_cnt}}

        echo ""
        cur_ver=`gonel -n 1`
        echo "cur_ver: ${cur_ver}"
        echo "git_dir: <${git_dir}> obj_dir: <${obj_dir}> step: <${step}>"
        echo "cur_cmp_cnt: <${cur_cmp_cnt}>"
        echo "forward:  gmf -n ${step} -l ${git_dir}"
        echo "backward: gmb -n ${step} -l ${git_dir}"
        if [ ${cur_cmp_cnt} -gt ${last_cmp_cnt} ]; then
            return 0;
        fi
        if [ "${runOpt}" != "c" ]; then
            echo "continue? [y/n/c] def[y]:"
            read runOpt
            if [ "$runOpt" = "n" ];then return 0; fi
        fi
        last_cmp_cnt=${cur_cmp_cnt}
    done
}

gapply()
{
    patch_dir=$1
    beg_idx="1"
    apply_cnt=""
    skip_array=()

    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -p) patch_dir="$2"; if [ ! -e "$patch_dir" ]; then return 1; fi; shift; ;;
            -b) beg_idx="$2"; shift; ;;
            -c) apply_cnt="$2"; shift; ;;
            # Compatible with bash and zsh
            --skip) eval "skip_array=($2)"; shift; ;;
            -h) echo "gapply -p <patch_dir> [-b <begin_idx>,def 1] [-c <apply_count>,def ALL] [--skip \"<skip idx list>\"]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    cur_idx=${beg_idx}
    while true
    do
        cur_idx=`printf "%04d" ${cur_idx}`
        patch_file="${patch_dir}/`ls -al ${patch_dir} | grep ${cur_idx} | awk '{print $NF}'`"
        if [ ! -f ${patch_file} ]; then return 0; fi
        echo "==> cur_idx: ${cur_idx}"
        echo "patch_file:  ${patch_file}"

        need_skip=""
        for skip_idx in ${skip_array[@]}
        do
            if [ ${skip_idx} -eq "${cur_idx}" ]; then
                echo "skip cur patch"
                need_skip="true"
                break
            fi
        done
        if [ "${need_skip}" = "true" ]; then
            if [ -n "${apply_cnt}" ]; then
                if [ "`expr ${cur_idx} - ${beg_idx} + 1`" -ge "${apply_cnt}" ]; then return 0; fi
            fi
            cur_idx=`expr ${cur_idx} + 1`
            continue
        fi


        git apply ${patch_file}
        if [ $? -ne "0" ]; then return 1; fi
        if [ -n "${apply_cnt}" ]; then
            if [ "`expr ${cur_idx} - ${beg_idx} + 1`" -ge "${apply_cnt}" ]; then return 0; fi
        fi
        cur_idx=`expr ${cur_idx} + 1`
    done
}


alias gonel="git log --pretty=format:'%C(yellow)%h %C(blue)author: %<|(40)%an %C(cyan)%ci %C(auto) %s %d'"
