#!/usr/bin/env bash
#########################################################################
# File Name: link.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Jul 25 14:39:36 2023
#########################################################################

repo_root=""

function get_repo_root()
{
    init_tool_dir=$(dirname $(readlink -f "$0"))
    repo_root=$(git -C ${init_tool_dir} rev-parse --show-toplevel)
    echo "git repo root: ${repo_root}"
}

function link_tool()
{
    src_tool="$1"
    dst_tool="$2"

    [ -e "${dst_tool}" ] && rm ${dst_tool}
    ln -s ${src_tool} ${dst_tool}
}

get_repo_root
fpga_tools_dir="${repo_root}/1.compileRun/13.rk_fpga_tools"

link_tool "${fpga_tools_dir}/host_boot_sys.sh"      dbg_host_boot_sys.sh
link_tool "${fpga_tools_dir}/host_update_sdcard.sh" dbg_host_update_sdcard.sh
link_tool "${fpga_tools_dir}/target_run_batch.sh"   dbg_target_run_batch.sh
link_tool "${fpga_tools_dir}/target_run_test.sh"    dbg_target_run_test.sh
