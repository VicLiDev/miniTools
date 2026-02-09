#!/usr/bin/env bash
#########################################################################
# File Name: 02.git_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 28 Jun 14:46:50 2024
#########################################################################

# add to bashrc:
# source ${HOME}/Projects/miniTools/1.compileRun/13.git_tools.sh
#
# zsh 在git仓库显示的距离最新节点的距离是用如下方法计算：
# git rev-list --count HEAD..origin/branch_name

# git one line
alias gonel="git log --graph --pretty=format:'%C(yellow)%h %C(blue)author: %<|(40)%an %C(cyan)%ci %C(auto) %s %d'"
# 只显示当前分支“真正走过的主线”，把所有被 merge 进来的子分支历史全部折叠掉
# 正常git log 会显示merge进来的其他分支的节点
# git one line current branch
alias golcurb="gonel --first-parent"
# 只看merge，不看其他
# git log --merges --oneline

# ====== commit forward/backword ======
get_commit_info()
{
    cmd_cnt=1
    cmd_opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cmd_cnt="$2"; if [ -z "$cmd_cnt" ]; then return 1; fi; shift; ;;
            -l) cmd_opt_loc="$2"; if [ -z "$cmd_opt_loc" ]; then return 1; fi; shift; ;;
            -h) echo "get_commit_info [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done
    echo "loc: $cmd_opt_loc"

    # rev-list 的用法：
    # git rev-list = “给机器用的提交遍历引擎”
    #
    # 它做三件事：
    # 1. 从一个或多个起点（commit / branch / tag）开始
    # 2. 按拓扑或时间顺序遍历历史
    # 3. 只输出 commit id（不带 message）
    #
    # 和 git log 的关系：
    # | 命令           | 给谁用     | 输出       |
    # | -------------- | ---------- | ---------- |
    # | `git log`      | 人         | 漂亮信息   |
    # | `git rev-list` | 脚本 / CI  | 纯 commit  |
    #
    # 最基础用法
    # 1. 从 HEAD 往回列出所有提交: git rev-list HEAD # 输出（从新到旧），HEAD 能到达的所有 commit
    # 2. 限制数量（最常用）: git rev-list -n 5 HEAD # 最近 5 个提交（不管是不是 merge）
    #
    # 指定范围
    # 1. 两点语法A..B:  git rev-list A..B   # B 有，但 A 没有的提交，这个 merge 带进来了什么？两个版本差了哪些提交？
    # 2. 三点语法A...B: git rev-list A...B  # A 和 B 的“对称差集”，A 独有 + B 独有，对比两个分支“各自多了啥”。
    #    A 和 B 是 commit 的名字，也就是说：
    #      可以是分支名
    #      可以是 tag
    #      可以是 commit hash
    #      甚至可以是 HEAD~3、origin/main 这种表达式
    #    Git 在看到 A..B / A...B 时，第一步永远是：把 A 和 B 解析成两个 commit。
    #
    # 控制“怎么走这条历史线”
    # 1. --first-parent（内核必备）: git rev-list --first-parent HEAD  # 只沿主线走，不钻进子分支
    # 2. 排除 merge commit: git rev-list --no-merges HEAD  # 只看“真正改代码的提交”。
    # 3. 只要 merge commit: git rev-list --merges HEAD    # 和 git log --merges 类似，但给脚本用。
    #
    # 路径限定
    # 1. git rev-list HEAD -- drivers/media # 只列出改动过 drivers/media 的提交，注意：-- 是必须的。
    #
    # 排序与顺序
    # 1. 默认顺序：拓扑顺序 + 时间，从新到旧
    # 2. 按时间排序： git rev-list --date-order HEAD
    # 3. 严格拓扑顺序（很少用）：git rev-list --topo-order HEAD
    #
    # rev-list 的“判断型用法”
    # 1. 判断某个 commit 是否在主线：git rev-list --first-parent HEAD | grep <commit>
    #    在：主线 commit    不在：子分支历史
    # 2. 找最近一个“满足条件”的提交
    #    git rev-list -n 1 --no-merges HEAD -- drivers/media
    #    最近一次改动 media 的 非 merge 提交。
    #
    # 和其他命令配合
    # 1. 和 git show: git show $(git rev-list -n 1 HEAD -- arch/arm64)
    # 2. 和 git describe: git describe --contains $(git rev-list -n 1 -- drivers/media)
    #    把"裸 commit"翻译成人能理解的 tag。
    #
    # --abbrev-commit
    # 缩写 commit hash
    #   默认完整：40 位
    #   加这个后：7～12 位（足够唯一）


    # cur
    # 同时显示所有分支和主线的结果
    echo "===== [all branches] ====="
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit HEAD -- ${cmd_opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    echo "cur commit:        ${cur_commit}"
    echo "cur com_id:        ${cur_com_id}"
    echo

    # 仅显示主线的结果
    echo "===== [first-parent only] ====="
    cur_com_id_fp=$(git rev-list --max-count=1 --abbrev-commit --first-parent HEAD -- ${cmd_opt_loc})
    cur_commit_fp=$(git log --oneline -n 1 ${cur_com_id_fp})
    echo "cur commit:        ${cur_commit_fp}"
    echo "cur com_id:        ${cur_com_id_fp}"
    echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config "branch.${cur_remote_br}.remote" || echo "")
    echo "remote repo:       ${remote_repo}"
    echo "cur remote branch: ${cur_remote_br}"
    echo

    # [all branches] forward
    echo "===== [all branches] ====="
    # forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
    #                --oneline ${cmd_opt_loc} | grep -B ${cmd_cnt} ${cur_com_id} | head -1)
    # forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    forward_com_id=$(git rev-list --abbrev-commit ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                     -- ${cmd_opt_loc} | grep -B ${cmd_cnt} ${cur_com_id} | head -1)
    # 检查 forward_com_id 是否为空，避免后续命令在无 forward commits 时报错
    if [ -z "$forward_com_id" ]; then
        echo "forward commit:    None (no newer commits on remote)"
        echo "forward com_id:    N/A"
    else
        forward_commit=$(git log --oneline -n 1 ${forward_com_id})
        echo "forward commit:    ${forward_commit}"
        echo "forward com_id:    ${forward_com_id}"
    fi
    echo

    # [first-parent only] forward
    echo "===== [first-parent only] ====="
    forward_com_id_fp=$(git rev-list --abbrev-commit --first-parent ${cur_com_id_fp}^..${remote_repo}/${cur_remote_br} \
                        -- ${cmd_opt_loc} | grep -B ${cmd_cnt} ${cur_com_id_fp} | head -1)
    if [ -z "$forward_com_id_fp" ]; then
        echo "forward commit:    None (no newer commits on remote)"
        echo "forward com_id:    N/A"
    else
        forward_commit_fp=$(git log --oneline -n 1 ${forward_com_id_fp})
        echo "forward commit:    ${forward_commit_fp}"
        echo "forward com_id:    ${forward_com_id_fp}"
    fi
    echo

    # backward
    # [all branches] backward
    echo "===== [all branches] ====="
    # 旧方式：使用 expr 进行算术运算，效率较低且已过时
    # backward_commit=$(git log --oneline -n `expr ${cmd_cnt} \* 2` ${cmd_opt_loc} \
    #                   | grep -A ${cmd_cnt} ${cur_com_id} | tail -1)
    # backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    # backward_com_id=$(git rev-list --max-count=`expr ${cmd_cnt} \* 2` \
    # 新方式：使用 $(( )) 进行算术运算，更高效且现代
    backward_com_id=$(git rev-list --max-count=$((${cmd_cnt} * 2)) \
                      --abbrev-commit HEAD -- ${cmd_opt_loc} \
                      | grep -A ${cmd_cnt} ${cur_com_id} | tail -1)
    backward_commit=$(git log --oneline -n 1 ${backward_com_id})
    echo "backward commit:   ${backward_commit}"
    echo "backward com_id:   ${backward_com_id}"
    echo

    # [first-parent only] backward
    echo "===== [first-parent only] ====="
    backward_com_id_fp=$(git rev-list --max-count=$((${cmd_cnt} * 2)) \
                          --abbrev-commit --first-parent HEAD -- ${cmd_opt_loc} \
                          | grep -A ${cmd_cnt} ${cur_com_id_fp} | tail -1)
    backward_commit_fp=$(git log --oneline -n 1 ${backward_com_id_fp})
    echo "backward commit:   ${backward_commit_fp}"
    echo "backward com_id:   ${backward_com_id_fp}"
}

gmf()
{
    cmd_cnt=1
    cmd_opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cmd_cnt="$2"; if [ -z "$cmd_cnt" ]; then return 1; fi; shift; ;;
            -l) cmd_opt_loc="$2"; if [ -z "$cmd_opt_loc" ]; then return 1; fi; shift; ;;
            -h) echo "gmf [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${cmd_opt_loc} | grep $(git rev-parse --short HEAD))
    # cur_commit=$(git log --oneline -n 1 ${cmd_opt_loc})
    # cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit --first-parent HEAD -- ${cmd_opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # forward
    cur_remote_br=`git branch --show-current`
    remote_repo=$(git config "branch.${cur_remote_br}.remote" || echo "")
    # echo "remote repo:       ${remote_repo}"
    # echo "cur remote branch: ${cur_remote_br}"

    # forward_commit=$(git log ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
    #                --oneline ${cmd_opt_loc} | grep -B ${cmd_cnt} ${cur_com_id} | head -1)
    # forward_com_id=$(echo ${forward_commit} | awk '{print $1}')
    forward_com_id=$(git rev-list --abbrev-commit --first-parent \
                     ${cur_com_id}^..${remote_repo}/${cur_remote_br} \
                     -- ${cmd_opt_loc} | grep -B ${cmd_cnt} ${cur_com_id} | head -1)
    # 检查 forward_com_id 是否为空，避免 git reset 失败
    if [ -z "${forward_com_id}" ]; then
        echo "Error: No forward commits found or remote branch does not exist"
        return 1
    fi
    forward_commit=$(git log --oneline -n 1 ${forward_com_id})
    # echo "forward commit:    ${forward_commit}"
    # echo "forward com_id:    ${forward_com_id}"
    # echo

    git reset --hard ${forward_com_id}
}

gmb()
{
    cmd_cnt=1
    cmd_opt_loc=""
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -n) cmd_cnt="$2"; if [ -z "$cmd_cnt" ]; then return 1; fi; shift; ;;
            -l) cmd_opt_loc="$2"; if [ -z "$cmd_opt_loc" ]; then return 1; fi; shift; ;;
            -h) echo "gmb [-n <node_cnt>,def 1] [-l <base file/dir>,def NULL]"; return 0; ;;
            *) echo "unknow para: ${key}"; return 1; ;;
        esac; shift
    done

    # cur
    # cur_commit=$(git log --oneline ${cmd_opt_loc} | grep $(git rev-parse --short HEAD))
    # cur_commit=$(git log --oneline -n 1 ${cmd_opt_loc})
    # cur_com_id=$(echo ${cur_commit} | awk '{print $1}')
    cur_com_id=$(git rev-list --max-count=1 --abbrev-commit --first-parent HEAD -- ${cmd_opt_loc})
    cur_commit=$(git log --oneline -n 1 ${cur_com_id})
    # echo "cur commit:        ${cur_commit}"
    # echo "cur com_id:        ${cur_com_id}"
    # echo

    # backward
    # 旧方式：使用 expr 进行算术运算，效率较低且已过时
    # backward_commit=$(git log --oneline -n `expr ${cmd_cnt} \* 2` ${cmd_opt_loc} \
    #                   | grep -A ${cmd_cnt} ${cur_com_id} | tail -1)
    # backward_com_id=$(echo ${backward_commit} | awk '{print $1}')
    # backward_com_id=$(git rev-list --max-count=`expr ${cmd_cnt} \* 2` \
    # 新方式：使用 $(( )) 进行算术运算，更高效且现代
    backward_com_id=$(git rev-list --max-count=$((${cmd_cnt} * 2)) \
                      --abbrev-commit --first-parent HEAD -- ${cmd_opt_loc} \
                      | grep -A ${cmd_cnt} ${cur_com_id} | tail -1)
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

gcroot()
{
    cd `git rev-parse --show-toplevel`
}
