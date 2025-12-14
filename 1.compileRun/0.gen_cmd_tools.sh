#!/usr/bin/env bash
#########################################################################
# File Name: 0.gen_cmd_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 14 Dec 2025 10:18:23 AM CST
#########################################################################


# source ${HOME}/Projects/miniTools/1.compileRun/0.gen_cmd_tools.sh

function mount_smb()
{
    # install CIFS maybe necessary
    # sudo apt-get install cifs-utils

    rmt_ip=${1}
    rmt_dir=${2}
    usr=${3}
    pw=${4}
    loc_dir=${5}
    loc_pfx=${6}
    loc_uid=${7}
    loc_gid=${8}
    if [[ -z "${rmt_ip}" || -z "${rmt_dir}" || -z "${usr}" || -z "${pw}" ]]
    then
        echo "Usage: mount_smb <srv_ip> <srv_dir> <usr> <pw> <loc_dir> <loc_prefix> <loc_uid> <loc_gid>"
        return -1
    fi
    rmt_addr="//${rmt_ip}/${rmt_dir}"
    loc_mtp="${loc_dir}/${loc_pfx}_${rmt_dir}"
    [ ! -e ${loc_mtp} ] && mkdir -p ${loc_mtp}
    chmod 755 ${loc_mtp}
    # uid 和 gid 只是说文件挂载给谁，即挂在之后，ls可以查看当前文件所属用户
    # 如果想让其他人也访问的话，可以修改file_mode/dir_mode
    cmd="sudo mount -t cifs ${rmt_addr} ${loc_mtp} -o username=${usr},password=${pw},uid=${loc_uid},gid=${loc_gid},file_mode=0664,dir_mode=0775"
    echo "cur cmd: ${cmd}"
    eval ${cmd}
}

