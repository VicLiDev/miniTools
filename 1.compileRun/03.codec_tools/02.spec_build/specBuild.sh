#!/usr/bin/env bash
#########################################################################
# File Name: specBuild.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 03 Jun 2026 10:51:22 AM CST
#########################################################################

# usage: specBuild.sh [-s spec] [-c clean]
#   -s: spec name (interactive select if omit)
#   -c: clean build dir before build

cmd_sel_spec=""
cmd_clean="false"

sel_tag_spec="codec_spec_b: "

spec_lst=(
    "avc"
    "hevc"
    "vvc"
    "avs2"
    "davs2"
    "xavs2"
    "vp9"
    "av1"
    "av2"
    "jpg1"
    "jpg2"
    )

m_sel=""

spec_root="${HOME}/Projects/LearnVcodec"

# spec => build work dir (relative to spec_root)
function spec_work_dir()
{
    local spec="$1"
    case ${spec} in
        avc)   echo "${spec_root}/02.1.h264/JM" ;;
        hevc)  echo "${spec_root}/02.2.h265/HM/Lbuild" ;;
        vvc)   echo "${spec_root}/02.3.h266/VVCSoftware_VTM/build" ;;
        vp9)   echo "${spec_root}/03.1.vp9/libvpx/Lbuild" ;;
        av1)   echo "${spec_root}/03.2.av1/aom/Lbuild" ;;
        av2)   echo "${spec_root}/03.3.av2/aom/Lbuild" ;;
        avs2)  echo "${spec_root}/04.1.avs2/RD17.0/build/linux" ;;
        davs2) echo "${spec_root}/04.1.avs2/davs2/build/linux" ;;
        xavs2) echo "${spec_root}/04.1.avs2/xavs2/build/linux" ;;
        jpg1)  echo "${spec_root}/05.1.jpeg/ijg_jpeg-9f/Lbuild" ;;
        jpg2)  echo "${spec_root}/05.1.jpeg/libjpeg_jpeg-6b/Lbuild" ;;
        *)     echo ""; return 1 ;;
    esac
}

function build_avc()
{
    echo "======> build avc (JM) <======"
    cd "${spec_root}/02.1.h264/JM"
    make clean
    make CFLAGS="-fcommon -g" -j
}

function build_hevc()
{
    echo "======> build hevc (HM) <======"
    local work_dir=$(spec_work_dir hevc)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    cmake -DCMAKE_BUILD_TYPE=Debug ..
    make -j$(nproc)
}

function build_vvc()
{
    echo "======> build vvc (VTM) <======"
    local work_dir=$(spec_work_dir vvc)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*

    if [ "$(uname)" = "Linux" ]; then
        cmake .. -DCMAKE_BUILD_TYPE=Debug
        make -j$(nproc)
    elif [ "$(uname)" = "Darwin" ]; then
        cmake .. -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
        make -j$(nproc)
    else
        echo "unsupported system"
    fi
}

function build_avs2()
{
    echo "======> build avs2 (RD17.0) <======"
    local work_dir=$(spec_work_dir avs2)
    create_dir ${work_dir} && cd ${work_dir}
    bash ./clean.sh
    make CFLAGS="-fcommon -g" CC=gcc-9 CXX=g++-9 -j 10 -C ldecod
    make CFLAGS="-fcommon -g" CC=gcc-9 CXX=g++-9 -j 10 -C lencod
}

function build_davs2()
{
    echo "======> build davs2 <======"
    local work_dir=$(spec_work_dir davs2)
    create_dir ${work_dir} && cd ${work_dir}
    ./configure --enable-pic --enable-debug && make -j$(nproc)
}

function build_xavs2()
{
    echo "======> build xavs2 <======"
    local work_dir=$(spec_work_dir xavs2)
    create_dir ${work_dir} && cd ${work_dir}
    ./configure --enable-pic --enable-debug && make -j$(nproc)
}

function build_vp9()
{
    echo "======> build vp9 (libvpx) <======"
    local work_dir=$(spec_work_dir vp9)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    ../configure --enable-debug --disable-optimizations
    make -j$(nproc)
}

function build_av1()
{
    echo "======> build av1 (aom) <======"
    local work_dir=$(spec_work_dir av1)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    cmake -DCMAKE_BUILD_TYPE=Debug ..
    make -j$(nproc)
}

function build_av2()
{
    echo "======> build av2 (aom) <======"
    local work_dir=$(spec_work_dir av2)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    cmake -DCMAKE_BUILD_TYPE=Debug ..
    make -j$(nproc)
}

function build_jpg1()
{
    echo "======> build jpg1 (ijg jpeg-9f) <======"
    local work_dir=$(spec_work_dir jpg1)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    ../configure --enable-debug
    make -j$(nproc)
}

function build_jpg2()
{
    echo "======> build jpg2 (libjpeg-6b) <======"
    local work_dir=$(spec_work_dir jpg2)
    create_dir ${work_dir} && cd ${work_dir}
    [ "${cmd_clean}" == "true" ] && rm -rf ./*
    dos2unix ../configure
    ../configure --enable-debug
    make -j$(nproc)
}

function proc_paras()
{
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -s|--spec)
                cmd_sel_spec="$2"
                shift
                ;;
            -c|--clean)
                cmd_clean="true"
                ;;
            -h|--help)
                echo "usage: $0 [-s spec] [-c clean]"
                echo "  -s: spec name (interactive select if omit)"
                echo "  -c: clean build dir before build"
                exit 0
                ;;
            *)
                echo "unknown para: ${key}"
                exit 1
                ;;
        esac
        shift
    done

    echo "======> cmd paras <======"
    echo "cmd_sel_spec : ${cmd_sel_spec}"
    echo "cmd_clean    : ${cmd_clean}"
    echo
}

function main()
{
    source ${HOME}/bin/_dir_file_opt.sh
    source ${HOME}/bin/_select_node.sh

    proc_paras $@

    if [ -z "${cmd_sel_spec}" ]; then
        select_node "${sel_tag_spec}" "spec_lst" "m_sel" "spec"
    else
        m_sel="${cmd_sel_spec}"
    fi

    echo "======> build ${m_sel} <======"
    build_${m_sel}

    if [ $? -eq 0 ]; then
        echo "======> build ${m_sel} done <======"
    else
        echo "======> build ${m_sel} failed! <======"
    fi
}

main $@
