#!/usr/bin/env bash
#########################################################################
# File Name: tools_init.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 09 Feb 2026 06:30:07 PM CST
#########################################################################

repo_root=""
source_file="${HOME}/bin/source_cmd_tools.sh"

# =============================================================================
#  path tools
# =============================================================================

function get_repo_root()
{
    init_tool_dir=$(dirname $(readlink -f "$0"))
    cd ${init_tool_dir}
    repo_root=$(git rev-parse --show-toplevel)
    echo "git repo root: ${repo_root}"
}

function create_link_to_bin()
{
    src_tool="$1"
    target_bin="$2"
    target_t="${HOME}/bin/${target_bin}"

    [ ! -e "${HOME}/bin" ] && mkdir ${HOME}/bin

    [ ! -f "${src_tool}" ] && { echo "tool: ${src_tool} not exist!"; return 1; }
    [ -L ${target_t} ] && { rm ${target_t}; }
    ln -s ${src_tool} ${target_t}
}


# =============================================================================
#  source tools
# =============================================================================

function init_source_tools()
{
    echo "source ${repo_root}/1.compileRun/00.gen_cmd_cfg.sh" > ${source_file}
    echo "source ${repo_root}/1.compileRun/13.git_tools.sh" >> ${source_file}
    echo "source ${repo_root}/1.compileRun/02.rk_tools/rk_shell_tools.sh" >> ${source_file}
    echo "source ${repo_root}/2.dataProc/18.ffmpeg_tools.sh" >> ${source_file}
}

# =============================================================================
#  General tools
# =============================================================================

function init_general_tools()
{
    tools_dir="${repo_root}/0.general_tools"

    create_link_to_bin ${tools_dir}/0.dir_file_opt.sh _dir_file_opt.sh
    create_link_to_bin ${tools_dir}/0.select_node.sh  _select_node.sh
    create_link_to_bin ${tools_dir}/sel_node.py       _select_node.py
    create_link_to_bin ${tools_dir}/sysParaMon.py     _sysParaMon.py
}

# =============================================================================
#  data proc tools
# =============================================================================

function init_data_proc_tools()
{
    tools_dir="${repo_root}/2.dataProc"

    create_link_to_bin ${tools_dir}/01.data_proc_with_plot/data_process_gen.py plt.py
    create_link_to_bin ${tools_dir}/03.reg_opt/main.py reg_ut.py
}

# =============================================================================
#  rk tools
# =============================================================================

function init_rk_tools()
{
    rk_tools_dir="${repo_root}/1.compileRun/02.rk_tools"
    
    # mpp
    create_link_to_bin ${rk_tools_dir}/rkBuildMpp.sh rkBuildMpp.sh
    create_link_to_bin ${rk_tools_dir}/rkDebugMpp.sh rkDebugMpp.sh
    
    # kernel
    create_link_to_bin ${rk_tools_dir}/rkBuildKer.sh rkBuildKer.sh
    create_link_to_bin ${rk_tools_dir}/rkDebugKer.sh rkDebugKer.sh
    create_link_to_bin ${rk_tools_dir}/rkUT.sh       rkUT.sh
    
    # tools
    create_link_to_bin ${rk_tools_dir}/adbDebug.sh  adbDebug.sh
    create_link_to_bin ${rk_tools_dir}/adbSelCmd.sh adbs
    create_link_to_bin ${rk_tools_dir}/tarMpp.sh    tarMpp.sh
    
    # batch test tools
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTCore.sh         rkBtC
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTTolkit.sh       rkBt
    create_link_to_bin ${rk_tools_dir}/batch_test/veri_regression/main.py r_ver
    
    echo "==> rk tools: for prj"
    echo 'ln -s ${HOME}/bin/rkBuildMpp.sh .prjBuild.sh'
    echo 'ln -s ${HOME}/bin/rkDebugMpp.sh .prjDebug.sh'
    echo 'ln -s ${HOME}/bin/rkBuildKer.sh .prjBuild.sh'
    echo 'ln -s ${HOME}/bin/rkDebugKer.sh .prjDebug.sh'
}

function init_shell()
{
    # bashrc
    rc_file=${HOME}/.bashrc
    if [ -z "$(cat ${rc_file} | grep 'Personal configuration')" ];
    then
        echo "# ======================================================" >> ${rc_file}
        echo "# =========== Personal configuration ===================" >> ${rc_file}
        echo "# ======================================================" >> ${rc_file}
        echo "# ======> my tools and config"                            >> ${rc_file}
        echo "proxyIP=<your_proxy_ip>"                                  >> ${rc_file}
        echo "proxyPort=<your_proxy_port>"                              >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
        echo "${rc_file} has configed!"
    fi
    # zshrc
    rc_file=${HOME}/.zshrc
    if [ -z "$(cat ${rc_file} | grep 'Personal configuration')" ];
    then
        echo "# ======================================================" >> ${rc_file}
        echo "# =========== Personal configuration ===================" >> ${rc_file}
        echo "# ======================================================" >> ${rc_file}
        echo "# ======> my tools and config"                            >> ${rc_file}
        echo "proxyIP=<your_proxy_ip>"                                  >> ${rc_file}
        echo "proxyPort=<your_proxy_port>"                              >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
        echo "${rc_file} has configed!"
    fi
}

get_repo_root
init_source_tools
init_general_tools
init_data_proc_tools
init_rk_tools
init_shell

