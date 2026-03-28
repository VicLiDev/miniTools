#!/usr/bin/env bash
#########################################################################
# File Name: init_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 09 Feb 2026 06:30:07 PM CST
#########################################################################

repo_root=""
source_file="${HOME}/bin/_source_cmd_tools.sh"

# =============================================================================
#  path tools
# =============================================================================

function get_repo_root()
{
    init_tool_dir=$(dirname $(readlink -f "$0"))
    repo_root=$(git -C ${init_tool_dir} rev-parse --show-toplevel)
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

function compile_tool_to_bin()
{
    cmp_tool="$1"
    src_tool="$2"
    target_bin="$3"
    target_t="${HOME}/bin/${target_bin}"

    [ ! -e "${HOME}/bin" ] && mkdir ${HOME}/bin

    [ ! -f "${src_tool}" ] && { echo "tool: ${src_tool} not exist!"; return 1; }
    [ -e ${target_t} ] && { rm ${target_t}; }
    ${cmp_tool} ${src_tool} -o ${target_t}
    if [ "$?" = "0" ]; then
        echo "tool: ${target_t} compile success"
    else
        echo "tool: ${target_t} compile faile"
    fi
}


# =============================================================================
#  source tools
# =============================================================================

function init_source_tools()
{
    echo "source ${repo_root}/0.general_tools/01.gen_cmd_cfg.sh" > ${source_file}
    echo "source ${repo_root}/0.general_tools/02.git_tools.sh" >> ${source_file}
    echo "source ${repo_root}/1.compileRun/02.rk_tools/rk_shell_tools.sh" >> ${source_file}
    echo "source ${repo_root}/2.dataProc/02.ffmpeg_tools.sh" >> ${source_file}
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
#  build/run tools
# =============================================================================

function init_build_run_tools()
{
    tools_dir="${repo_root}/1.compileRun"

    create_link_to_bin ${tools_dir}/01.ffmpeg_build/ffmpeg_build_all.sh  m_ffmpeg_bd.sh

    echo
    echo "==> build/run tools: for prj"
}

# =============================================================================
#  data proc tools
# =============================================================================

function init_data_proc_tools()
{
    tools_dir="${repo_root}/2.dataProc"

    create_link_to_bin ${tools_dir}/01.data_proc_with_plot/data_process_gen.py  m_plt.py
    create_link_to_bin ${tools_dir}/01.data_proc_with_plot/time_conv.py         m_time_conv.py
    create_link_to_bin ${tools_dir}/03.reg_opt/main.py                          m_reg_ut.py
    create_link_to_bin ${tools_dir}/04.compareMulti/cmp_dir.sh                  m_cmp_dir.sh
    create_link_to_bin ${tools_dir}/05.split_hex_str.py                         m_split_hex_str.py
    create_link_to_bin ${tools_dir}/06.split_hex_txt.py                         m_split_hex_txt.py
    create_link_to_bin ${tools_dir}/07.conv_bit2val.py                          m_convbit2val.py
    create_link_to_bin ${tools_dir}/08.conv_ascii.py                            m_conv_ascii.py
    create_link_to_bin ${tools_dir}/11.pip_display.py                           m_pip_display.py

    compile_tool_to_bin gcc ${tools_dir}/09.conv_str_bin.c       m_conv_str_bin
    compile_tool_to_bin gcc ${tools_dir}/12.map_raster_zorder.c  m_map_raster_zorder
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
    create_link_to_bin ${rk_tools_dir}/adbDebug.sh   adbDebug.sh
    create_link_to_bin ${rk_tools_dir}/adbSelCmd.sh  adbs
    create_link_to_bin ${rk_tools_dir}/rk_tar_mpp.sh rk_tar_mpp.sh
    
    # batch test tools
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTCore.sh         rkBtC
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTTolkit.sh       rkBt
    create_link_to_bin ${rk_tools_dir}/batch_test/veri_regression/main.py rk_r_ver

    # rga
    create_link_to_bin ${rk_tools_dir}/rkBuildRga.sh rkBuildRga.sh
    
    echo
    echo "==> rk tools: for prj"
    echo 'ln -s ${HOME}/bin/rkBuildMpp.sh .prjBuild.sh'
    echo 'ln -s ${HOME}/bin/rkDebugMpp.sh .prjDebug.sh'
    echo 'ln -s ${HOME}/bin/rkBuildKer.sh .prjBuild.sh'
    echo 'ln -s ${HOME}/bin/rkDebugKer.sh .prjDebug.sh'
    echo 'ln -s ${HOME}/bin/rkBuildRga.sh .prjBuild.sh'


    rk_tools_dir="${repo_root}/1.compileRun/04.cmodel_tools"

    # cmodel tools
    create_link_to_bin ${rk_tools_dir}/cmodel_reg_proc.py   rk_cmod_reg_proc.py


    rk_tools_dir="${repo_root}/1.compileRun/13.rk_fpga_tools"

    # fpga tools
    create_link_to_bin ${rk_tools_dir}/link.sh   rk_fpga_tools_init.sh

}

function init_shell()
{
    # bashrc
    rc_file=${HOME}/.bashrc
    if [ -z "$(cat ${rc_file} | grep 'Personal configuration')" ];
    then
        echo
        echo "# ======================================================" >> ${rc_file}
        echo "# =========== Personal configuration ===================" >> ${rc_file}
        echo "# ======================================================" >> ${rc_file}
        echo "# ======> my tools and config"                            >> ${rc_file}
        echo "proxyIP=<your_proxy_ip>"                                  >> ${rc_file}
        echo "proxyPort=<your_proxy_port>"                              >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
        echo
        echo "${rc_file} has configed!"
    fi
    # zshrc
    rc_file=${HOME}/.zshrc
    if [ -z "$(cat ${rc_file} | grep 'Personal configuration')" ];
    then
        echo
        echo "# ======================================================" >> ${rc_file}
        echo "# =========== Personal configuration ===================" >> ${rc_file}
        echo "# ======================================================" >> ${rc_file}
        echo "# ======> my tools and config"                            >> ${rc_file}
        echo "proxyIP=<your_proxy_ip>"                                  >> ${rc_file}
        echo "proxyPort=<your_proxy_port>"                              >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
        echo
        echo "${rc_file} has configed!"
    fi
}

get_repo_root
init_source_tools
init_general_tools
init_build_run_tools
init_data_proc_tools
init_rk_tools
init_shell

