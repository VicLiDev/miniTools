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
    loc_dir=${3}
    loc_pfx=${4}
    usr=${5}
    pw=${6}
    if [[ -z "${rmt_ip}" || -z "${rmt_dir}" || -z "${usr}" || -z "${pw}" ]]
    then
        echo "Usage: mount_smb <srv_ip> <srv_dir> <loc_dir> <loc_prefix> <usr> <pw>"
        return -1
    fi
    rmt_addr="//${rmt_ip}/${rmt_dir}"
    loc_mtp="${loc_dir}/${loc_pfx}_${rmt_dir}"
    [ ! -e ${loc_mtp} ] && mkdir -p ${loc_mtp}
    chmod 755 ${loc_mtp}
    cmd="sudo mount -t cifs ${rmt_addr} ${loc_mtp} -o username=${usr},password=${pw}"
    echo "cur cmd: ${cmd}"
    eval ${cmd}
}

