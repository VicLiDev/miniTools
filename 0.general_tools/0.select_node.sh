#!/usr/bin/env bash
#########################################################################
# File Name: 0.select_node.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 15 Jul 2024 09:09:03 AM CST
#########################################################################

# usage:
#     1. exec cmd: source $(dirname $(readlink -f $0))/../0.general_tools/0.select_node.sh
#        or
#        prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
#        source ${prj_root_dir}/0.general_tools/0.select_node.sh
#        or
#        ln -s ${HOME}/Projects/miniTools/0.general_tools/0.select_node.sh ${HOME}/bin/select_node.sh
#        source ${HOME}/bin/select_node.sh
#        or after run init_tools.sh
#        source ${HOME}/bin/_select_node.sh
#     2. select_node "<cache tag>" "<select list>" "<select result>" "<select tip>"
#
# basename命令用于从文件名中剥离路径信息，只留下基本名称。
# basename NAME [SUFFIX]
# * NAME: 文件名或路径。
# * SUFFIX: 可选参数，如果提供，将会从基本名称中移除指定的后缀。
#
# dirname命令用于从路径中剥离最后一级目录或文件名，只留下路径部分。
# dirname NAME
#
# readlink命令用于打印符号链接（软链接）所指向的文件路径。
# readlink [-fnv] FILE
# * FILE: 符号链接文件。
# * -f: 如果指定，将会打印出符号链接的最终目标路径，而不是相对路径。
# * -n: 如果指定，将不会在输出末尾添加换行符。
# * -v: 如果指定，将会打印有关读取链接的详细信息。


# 使用 _sn_ 前缀避免变量名冲突，并用 readonly 保护常量
readonly _sn_cache_file="${HOME}/bin/select.cache"
readonly _sn_display_color=36
# stdout bakfd 1001
# stderr bakfd 1002

function _sn_display()
{
    local _list_name="$1"
    local _tip="$2"
    local -n _list_ref="${_list_name}"
    local _i
    echo "Please select ${_tip}:" >&2
    for ((_i = 0; _i < ${#_list_ref[@]}; _i++))
    do
        echo "  ${_i}. ${_list_ref[${_i}]}" >&2
    done
}

function _sn_rd_sel_cache()
{
    local _tag="$1"
    local _def="$2"
    local _cached

    [ -z "${_tag}" ] && return
    [ ! -e ${_sn_cache_file} ] && { echo "${_def}"; return; }

    _cached=$(grep "^${_tag}" "${_sn_cache_file}" 2>/dev/null)

    [ -z "${_cached}" ] && { echo "${_def}"; } || { echo "${_cached#${_tag}}"; }
}

function _sn_wr_sel_cache()
{
    local _tag="$1"
    local _def="$2"

    [ -z "${_tag}" ] && { return; }

    if [ ! -e ${_sn_cache_file} ]; then
        echo "${_tag}${_def}" > ${_sn_cache_file}
    elif [ -z "$(grep "^${_tag}" ${_sn_cache_file})" ]; then
        echo "${_tag}${_def}" >> ${_sn_cache_file}
    else
        sed -i.bak "s/${_tag}.*/${_tag}${_def}/" ${_sn_cache_file}
    fi
}

function select_node()
{
    local _tag="$1"
    local _lst_name="$2"
    local _res_name="$3"
    local _tip="$4"
    local -n _lst_ref="${_lst_name}"
    local -n _sel_res="${_res_name}"
    local _def_idx _sel_idx

    _def_idx=$(_sn_rd_sel_cache "${_tag}" 0)

    echo -e "\033[0m\033[1;${_sn_display_color}m" >&2
    _sn_display "${_lst_name}" "${_tip}"

    echo "cur dir: $(pwd)" >&2
    while true
    do
        read -p "Please select ${_tip} or quit(q), def[${_def_idx}]:" _sel_idx >&2
        _sel_idx=${_sel_idx:-${_def_idx}}

        if [ "${_sel_idx}" == "q" ]; then
            echo "======> quit <======" >&2
            exit 1
        elif [[ -n ${_sel_idx} ]] \
            && [[ -z "${_sel_idx//[0-9]/}" ]] \
            && [[ "${_sel_idx}" -lt "${#_lst_ref[@]}" ]]; then
            _sel_res=${_lst_ref[${_sel_idx}]}
            echo "--> selected index:${_sel_idx}, ${_tip}:${_sel_res}" >&2
            break
        else
            _sel_res=""
            echo "--> please input num in scope 0-$((${#_lst_ref[@]} - 1))" >&2
        fi
    done

    _sn_wr_sel_cache "${_tag}" "${_sel_idx}"
    echo -e "\033[0m" >&2
}
