#!/usr/bin/env bash
#########################################################################
# File Name: 0.dir_file_opt.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 29 Jul 2024 03:23:30 PM CST
#########################################################################

# usage: source $(dirname $(readlink -f $0))/0.dir_file_opt.sh

create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1"; mkdir -p $1; fi
}

remove_dir()
{
    if [ -e $1 ]; then echo "remove dir $1"; rm -rf $1; fi
}

update_file()
{
    src="$1"
    dst="$2"
    if [[ -z "$src" || ! -e $src ]]; then echo "error: src file $1 do not exist"; exit 1; fi
    # dts maybe file or dir
    if [[ -z "$dst" || ! -e ${dst%/*} ]]; then echo "error: dst dir $2 do not exist"; exit 1; fi
    echo "copy $src to $dst"
    cp -r $src $dst
}
