#!/usr/bin/env bash
#########################################################################
# File Name: .prjBuild.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 16 Mar 2026 05:03:30 PM CST
#########################################################################

TARGET_NAME="android_ndk"

sel_tag_rga="rk_rga_b: "

plt_lst=(
    "lib_android32"
    "lib_android64"
    "lib_linux32"
    "lib_linux64"
    "lib_rt_thread"
    )

m_sel=""

function build_lib_android32()
{
    echo "======> selected ${m_sel} <======"

    # build

    # push

    if [ $? -eq 0 ]; then
        echo "======> build rga sucess! <======"
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function build_lib_android64()
{
    echo "======> selected ${m_sel} <======"

    # build

    # push

    if [ $? -eq 0 ]; then
        echo "======> build rga sucess! <======"
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function build_lib_linux32()
{
    echo "======> selected ${m_sel} <======"

    # build

    # push

    if [ $? -eq 0 ]; then
        echo "======> build rga sucess! <======"
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function build_lib_linux64()
{
    echo "======> selected ${m_sel} <======"

    # build

    # push

    if [ $? -eq 0 ]; then
        echo "======> build rga sucess! <======"
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function build_lib_rt_thread()
{
    echo "======> selected ${m_sel} <======"

    # build

    # push

    if [ $? -eq 0 ]; then
        echo "======> build rga sucess! <======"
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function main()
{
    cur_br=`git branch --show-current`
    echo "cur branch: $cur_br"
    source ${HOME}/bin/_select_node.sh

    select_node "${sel_tag_rga}" "plt_lst" "m_sel" "platform"

    build_${m_sel}
}

main $@
