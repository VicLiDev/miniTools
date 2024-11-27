#!/usr/bin/env bash
#########################################################################
# File Name: rkBatchTTolkit.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 31 Oct 2024 11:51:26 AM CST
#########################################################################

dev_id_l=()
prot_l=()
dev_dir=""
quit_err="false"

dev_info_l=(`adbs -l | awk '{print $1}'`)
strm_list=()

strm_list_hevc=(
    ${HOME}/Projects/streams/m_h265/vstream
)
strm_list_avc=(
    ${HOME}/Projects/streams/m_h264/vstream
)
strm_list_avs2=(
    ${HOME}/Projects/streams/m_avs2/vstream
)
strm_list_vp9=(
    ${HOME}/Projects/streams/m_vp9/vstream
)
strm_list_av1=(
    ${HOME}/Projects/streams/m_av1/vstream
    ${HOME}/Projects/streams/m_AV1_90_ser/vstream
)

function usage()
{
    echo "usage: $0 [-h] [-t test_scope] [-p prot] [--ddir dev_dir] [-q]"
    echo "  -h|--help   help info"
    echo "  -d|--dev    device, def all"
    echo "  -p|--prot   protocol, hevc/h265/265/avc/h264/264/avs2/vp9/av1"
    echo "  --ddir      device work dir, def /sdcard"
    echo "  -q          quit when test failed"
}

function procParas()
{
    # 双中括号提供了针对字符串比较的高级特性，使用双中括号 [[ ]] 进行字符串比较时，
    # 可以把右边的项看做一个模式，故而可以在 [[ ]] 中使用正则表达式：
    # if [[ hello == hell* ]]; then
    #
    # 位置参数可以用shift命令左移。比如shift 3表示原来的$4现在变成$1，原来的$5现在变成
    # $2等等，原来的$1、$2、$3丢弃，$0不移动。不带参数的shift命令相当于shift 1。

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dev)
                dev_id_l=(${2})
                shift # move to next para
                ;;
            -p|--prot)
                case ${2} in
                    hevc|h265|265) prot_l=("hevc") ;;
                    avc|h264|264)  prot_l=("avc") ;;
                    avs2) prot_l=("avs2") ;;
                    vp9)  prot_l=("vp9")  ;;
                    av1)  prot_l=("av1")  ;;
                    *) echo "unsuport protocol" ;;
                esac
                shift # move to next para
                ;;
            --ddir)
                dev_dir="${2}"
                shift # move to next para
                ;;
            -q)
                quit_err="true"
                ;;
            *)
                # unknow para
                echo "unknow para: ${key}"
                exit 1
                ;;
        esac
        shift # move to next para
    done

    [ -z "${dev_dir}" ] && dev_dir="/sdcard"
}

function exec_batch_test()
{
    for dev_idx in ${dev_id_l[@]}
    do
        for cur_prot in ${prot_l[@]}
        do
            # cur_dirs=`eval echo '$'{strm_list_${cur_prot}[@]}`
            # echo "cur dirs: ${cur_dirs}"
            for cur_dir in `eval echo '$'{strm_list_${cur_prot}[@]}`
            do
                echo
                echo -e "\033[0m\033[1;36m <<<<<< [dev_idx]:  ${dev_idx} >>>>>>\033[0m"
                echo -e "\033[0m\033[1;36m <<<<<< [dev_info]: ${dev_info_l[${dev_idx}]} >>>>>>\033[0m"
                echo -e "\033[0m\033[1;36m <<<<<< [cur_prot]: ${cur_prot} >>>>>>\033[0m"
                echo -e "\033[0m\033[1;36m <<<<<< [cur_dir]:  ${cur_dir} >>>>>>\033[0m"
                cur_cmd="rkBtC -d ${dev_idx} -p ${cur_prot} -s ${cur_dir} --ddir ${dev_dir}"
                [ "${quit_err}" == "true" ] && cur_cmd="${cur_cmd} -q"
                echo "cur batch test cmd: ${cur_cmd}"
                ${cur_cmd}
                [ $? -ne 0 ] && [ ${quit_err} == "true" ] && exit -1
            done
        done
    done

}


function main()
{
    procParas $@
    if [ ${#dev_id_l[@]} == 0 ]; then dev_id_l=(`seq 0 $(($(adbs -c) - 1))`); fi
    if [ ${#prot_l[@]} == 0 ]; then prot_l=("hevc" "avc" "vp9" "avs2" "av1"); fi

    echo "======> $0 paras <======"
    echo "dev_id_l: ${dev_id_l[@]}"
    echo "prot_l:   ${prot_l[@]}"
    echo "dev_dir:  ${dev_dir}"
    echo "quit_err: ${quit_err}"

    exec_batch_test
}

main $@
