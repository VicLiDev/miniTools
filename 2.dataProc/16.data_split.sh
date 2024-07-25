#!env bash
#########################################################################
# File Name: 16.data_split.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 11 Jun 2024 09:50:04 AM CST
#########################################################################

in_file=""
fragment_cfg_file=""


function usage()
{
    echo "usage: data_split.sh -i <input_file> -c <config_file>"
    echo ""

    echo "config_file format:"
    echo "<frm_w>  <frm_h>  <multi(420/422...)>  <frm_cnt>"
    echo "ex:"
    echo "640 360 1.5  164"
    echo "854 480 3    190"
    echo "854 480 1.5  87 "
}


function procParas()
{
    # 单个字符选项：如果选项不需要参数，可以直接使用一个字符表示。
    # 带参数选项：如果选项需要一个参数，应在选项字符后接一个冒号“:”。选项参数可以
    #             紧跟在选项之后，也可以以空格隔开。选项参数的首地址会赋给optarg变量。
    # 可选参数选项：如果选项的参数是可选的，应在选项字符后接两个冒号“::”。当提供
    #              了参数时，它必须紧跟在选项之后，不能以空格隔开，否则getopt会
    #              认为该选项没有参数，并将optarg赋值为NULL。
    # 实测发现，如果带有冒号，即带参，两种写法都可以 -n10 -n 10)
    # 但是如果不带冒号，则不能跟参数
    while getopts "i:c:" opt
    do
        # OPTIND 的主要用途是跟踪下一个要处理的参数的位置。当使用 getopts 解析参数时，
        # 它会按照顺序检查位置参数，并使用 OPTIND 来记住下一个要检查的参数的位置。
        # echo "==> OPTIND:$OPTIND opt:${opt} para:${OPTARG}"
        case "${opt}" in
            i)
                in_file=${OPTARG}
                ;;
            c)
                fragment_cfg_file=${OPTARG}
                ;;
            *)
                echo "unsupport opt: ${opt}"
                ;;
        esac
    done
}


function yuv_split()
{

    if [ ! -e ${in_file} ]; then echo "${in_file} file not exist"; exit 0; fi
    if [ ! -e ${fragment_cfg_file} ]; then echo "${fragment_cfg_file} file not exist"; exit 0; fi

    cur_fragment_idx=0
    last_remain_file=${in_file}
    while read cur_w cur_h cur_multi frm_cnt
    do
        echo ""
        echo "==> cur fragment idx: ${cur_fragment_idx}"

        echo "cur w:${cur_w} h:${cur_h} multi:${cur_multi} frm_cnt:${frm_cnt}"

        frm_size=`echo "$cur_w * $cur_h * $cur_multi" | bc`
        frm_size=$(printf "%.0f\n" "$frm_size")
        echo "frm size: ${frm_size}"
        echo "frm cnt : ${frm_cnt}"

        echo "--> cur fragment"
        cur_cmd="dd if=${last_remain_file} bs=${frm_size} count=${frm_cnt} of=output_fragment_${cur_fragment_idx}.yuv"
        echo "cur_cmd: ${cur_cmd}"
        $cur_cmd
        echo "--> remain"
        cur_cmd="dd if=${last_remain_file} bs=${frm_size} skip=${frm_cnt} of=output_fragment_${cur_fragment_idx}_remain.yuv"
        echo "cur_cmd: ${cur_cmd}"
        $cur_cmd

        last_remain_file="output_fragment_${cur_fragment_idx}_remain.yuv"
        cur_fragment_idx=`expr ${cur_fragment_idx} + 1`

    done < ${fragment_cfg_file}

}


function main()
{
    procParas $@
    if [ -z ${in_file} ]
    then
        usage
        exit 0
    fi
    echo "cmd line paras:"
    echo "in_file           : ${in_file}"
    echo "fragment_cfg_file : ${fragment_cfg_file}"

    if [[ -n ${fragment_cfg_file} && -n ${in_file} ]]; then
        yuv_split
    fi
}


main $@
