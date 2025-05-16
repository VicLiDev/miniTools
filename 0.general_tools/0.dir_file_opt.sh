#!/usr/bin/env bash
#########################################################################
# File Name: 0.dir_file_opt.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 29 Jul 2024 03:23:30 PM CST
#########################################################################

# usage:
# source $(dirname $(readlink -f $0))/../0.general_tools/0.dir_file_opt.sh
# or
# prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
# source ${prj_root_dir}/0.general_tools/0.dir_file_opt.sh

create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1" >&2; mkdir -p $1; fi
}

remove_dir()
{
    if [ -e $1 ]; then echo "remove dir $1" >&2; rm -rf $1; fi
}

update_file()
{
    src="$1"
    dst="$2"
    if [[ -z "$src" || ! -e $src ]]; then echo "error: src file $1 do not exist" >&2; exit 1; fi
    # dts maybe file or dir
    if [[ -z "$dst" || ! -e ${dst%/*} ]]; then echo "error: dst dir $2 do not exist" >&2; exit 1; fi
    echo "copy $src to $dst" >&2
    cp -r $src $dst
}

update_bins()
{
    # copy src dir/bin/soft_link to dst dir
    # usage: update_bins <src_dir/bin/soft_link> <dst_dir>
    src="$1"
    dst="$2"

    if [[ -z "$src" || ! -e $src ]]; then echo "error: src dir/bin/soft_link $1 do not exist" >&2; exit 1; fi
    # dts maybe file or dir
    if [[ -z "$dst" || ! -e ${dst%/*} ]]; then echo "error: dst dir $2 do not exist" >&2; exit 1; fi

    # -type l: 查找符号链接。
    # -type f -executable: 查找可执行文件。
    # -o: 表示“或”的逻辑条件。
    # \( 和 \): 用于分组条件。
    for cur_bin in `find ${src} -maxdepth 1 \( -type l -o -type f -executable \)`
    do
        echo "copy ${cur_bin} to ${dst}" >&2
        cp -r ${cur_bin} ${dst}
    done
}
check_exist()
{
    if [ -e "$1" ]; then
        echo -e "\033[0m\033[1;32m $1 exist \033[0m" >&2
    else
        echo -e "\033[0m\033[1;31m $1 not exist \033[0m" >&2
    fi
}
