#!/usr/bin/env bash
#########################################################################
# File Name: specDebug.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 03 Jun 2026 10:51:30 AM CST
#########################################################################

# usage: specDebug.sh [-s spec]
#   -s: spec name (interactive select if omit)

cmd_sel_spec=""

sel_tag_spec="codec_spec_d: "

spec_lst=(
    "avc"
    "hevc"
    "vvc"
    "avs2"
    "davs2"
    "xavs2"
    "vp9"
    "av1"
    "jpg1"
    "jpg2"
    )

m_sel=""

spec_root="${HOME}/Projects/LearnVcodec"
debug_cmd_file="${spec_root}/spec_debug.gdb"

# spec => exe path (relative to spec work dir)
function spec_exe()
{
    local spec="$1"
    case ${spec} in
        avc)   echo "bin/ldecod.dbg.exe" ;;
        hevc)  echo "../bin/TAppDecoderStaticd" ;;
        vvc)   echo "../bin/DecoderAppStaticd" ;;
        avs2)  echo "../../source/bin/ldecod.exe" ;;
        davs2) echo "./davs2" ;;
        xavs2) echo "./xavs2" ;;
        vp9)   echo "vpxdec" ;;
        av1)   echo "./aomdec -o output.yuv ${HOME}/test/testStrms/Sintel_360_10s_1MB.ivf" ;;
        jpg1)  echo "wrjpgcom" ;;
        jpg2)  echo "wrjpgcom" ;;
        *)     echo ""; return 1 ;;
    esac
}

# spec => work dir
function spec_work_dir()
{
    local spec="$1"
    case ${spec} in
        avc)   echo "${spec_root}/02.1.h264/JM" ;;
        hevc)  echo "${spec_root}/02.2.h265/HM/Lbuild" ;;
        vvc)
            if [ "$(uname)" = "Darwin" ]; then
                echo "${spec_root}/02.3.h266/VVCSoftware_VTM/build"
            else
                echo "${spec_root}/02.3.h266/VVCSoftware_VTM/build"
            fi
            ;;
        avs2)  echo "${spec_root}/04.1.avs2/RD17.0/build/linux" ;;
        davs2) echo "${spec_root}/04.1.avs2/davs2/build/linux" ;;
        xavs2) echo "${spec_root}/04.1.avs2/xavs2/build/linux" ;;
        vp9)   echo "${spec_root}/03.1.vp9/libvpx/Lbuild" ;;
        av1)   echo "${spec_root}/03.2.av1/aom/Lbuild" ;;
        jpg1)  echo "${spec_root}/05.1.jpeg/ijg_jpeg-9f/Lbuild" ;;
        jpg2)  echo "${spec_root}/05.1.jpeg/libjpeg_jpeg-6b/Lbuild" ;;
        *)     echo ""; return 1 ;;
    esac
}

function gen_debug_cmd()
{
    local exe_path="$1"
    local work_dir="$2"

    if [ -e ${debug_cmd_file} ]; then
        echo "use exist debug cmd file: ${debug_cmd_file}"
        return
    fi

    cat > ${debug_cmd_file} <<EOF
# pwd: ${work_dir}
# exe: ${exe_path}

set pagination off
set print pretty on
b main
r
layout src
EOF

    echo "generate debug cmd file: ${debug_cmd_file}"
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
            -h|--help)
                echo "usage: $0 [-s spec]"
                echo "  -s: spec name (interactive select if omit)"
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

    local work_dir=$(spec_work_dir ${m_sel})
    local exe_path=$(spec_exe ${m_sel})

    [ -z "${work_dir}" ] && { echo "error: unsupported spec: ${m_sel}"; exit 1; }
    [ -z "${exe_path}" ]  && { echo "error: unsupported spec: ${m_sel}"; exit 1; }

    cd ${work_dir}
    local abs_exe=$(readlink -f ${exe_path})

    echo "======> debug ${m_sel} <======"
    echo "work dir : ${work_dir}"
    echo "exe path : ${abs_exe}"

    gen_debug_cmd "${abs_exe}" "${work_dir}"

    gdb --command=${debug_cmd_file} --args ${abs_exe}
}

main $@
