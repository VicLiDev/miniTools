#!/usr/bin/env bash
#########################################################################
# File Name: init_tools.sh
# Author: Hongjin Li
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

    [ ! -d "${HOME}/bin" ] && mkdir -p ${HOME}/bin

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

    [ ! -d "${HOME}/bin" ] && mkdir -p ${HOME}/bin

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
#  libs
# =============================================================================

function init_libs()
{
    echo
    echo "==> Installing libs"

    libs_dir="${repo_root}/00.libs"

    create_link_to_bin ${libs_dir}/01.log.sh          _log.sh
    create_link_to_bin ${libs_dir}/02.dir_file_opt.sh _dir_file_opt.sh
    create_link_to_bin ${libs_dir}/03.select_node.sh  _select_node.sh
    create_link_to_bin ${libs_dir}/03.sel_node.py     _select_node.py
    create_link_to_bin ${libs_dir}/05.csv.sh          _csv.sh
}

# =============================================================================
#  shell env (source loaded)
# =============================================================================

function init_shell_env()
{
    echo
    echo "==> Installing shell env (source loaded)"
    echo "==> Generating ${source_file}"

    shell_env_dir="${repo_root}/01.shell_env"

    echo "source ${shell_env_dir}/01.gen_cmd_cfg.sh" > ${source_file}
    echo "source ${shell_env_dir}/02.git_tools.sh" >> ${source_file}
    echo "source ${repo_root}/02.gen_tools/03.data_proc/03.ffmpeg_tools/01.general.sh" >> ${source_file}
    echo "source ${repo_root}/04.spec_tools/01.rk_tools/01.rk_tools/rk_shell_tools.sh" >> ${source_file}
}

# =============================================================================
#  data proc tools
# =============================================================================

function init_data_proc_tools()
{
    echo
    echo "==> Installing data processing tools"

    tools_dir="${repo_root}/02.gen_tools/03.data_proc"

    create_link_to_bin ${tools_dir}/02.data_proc_with_plot/data_process_gen.py  m_plt.py
    create_link_to_bin ${tools_dir}/02.data_proc_with_plot/time_conv.py         m_time_conv.py
    create_link_to_bin ${tools_dir}/03.ffmpeg_tools/02.probe_stream.sh          m_probe_stream.sh
    create_link_to_bin ${tools_dir}/04.compareMulti/cmp_dir.sh                  m_cmp_dir.sh
    create_link_to_bin ${tools_dir}/04.compareMulti/cmp_yuv.sh                  m_cmp_yuv.sh
    create_link_to_bin ${tools_dir}/05.split_hex_str.py                         m_split_hex_str.py
    create_link_to_bin ${tools_dir}/06.split_hex_txt.py                         m_split_hex_txt.py
    create_link_to_bin ${tools_dir}/07.conv_bit2val.py                          m_convbit2val.py
    create_link_to_bin ${tools_dir}/08.conv_ascii.py                            m_conv_ascii.py
    create_link_to_bin ${tools_dir}/10.data_cut.sh                              m_data_cut.sh
    create_link_to_bin ${tools_dir}/11.pip_display.py                           m_pip_display.py
    create_link_to_bin ${tools_dir}/16.hex_data_ana.py                          m_hex_data_ana.py
    create_link_to_bin ${tools_dir}/17.split_bin2frms.py                        m_split_bin2frms.py
    create_link_to_bin ${tools_dir}/19.xml_fmt.py                               m_xml_fmt.py

    compile_tool_to_bin gcc ${tools_dir}/09.conv_str_bin.c       m_conv_str_bin
    compile_tool_to_bin gcc ${tools_dir}/12.map_raster_zorder.c  m_map_raster_zorder
}

# =============================================================================
#  general tools
# =============================================================================

function init_gen_tools()
{
    echo
    echo "==> Installing general tools"

    gen_tools_dir="${repo_root}/02.gen_tools"

    # dev tools
    create_link_to_bin ${gen_tools_dir}/01.dev_tools/01.adb_tools/01.adbSelCmd.sh  adbs
    create_link_to_bin ${gen_tools_dir}/01.dev_tools/01.adb_tools/03.adbDebug.sh   adbDebug.sh
    create_link_to_bin ${gen_tools_dir}/01.dev_tools/01.adb_tools/02.adb_device.sh _adb_device.sh

    create_link_to_bin ${gen_tools_dir}/01.dev_tools/03.sysParaMon.py      _sysParaMon.py
    create_link_to_bin ${gen_tools_dir}/01.dev_tools/04.usbinfo.sh         m_usbinfo.sh
    create_link_to_bin ${gen_tools_dir}/01.dev_tools/06.stress_test.py     m_stree_test.py

    # net tools
    create_link_to_bin ${gen_tools_dir}/02.net_tools/01.net_test.sh     m_net_test.sh
    create_link_to_bin ${gen_tools_dir}/02.net_tools/02.proxy_mihomo.sh m_proxy_mihomo

    # data proc tools
    init_data_proc_tools
}

# =============================================================================
#  build tools
# =============================================================================

function init_build()
{
    echo
    echo "==> Installing build tools"

    build_dir="${repo_root}/03.build"

    create_link_to_bin ${build_dir}/01.ffmpeg_build/ffmpeg_build_all.sh  m_ffmpeg_bd.sh
    create_link_to_bin ${build_dir}/01.ffmpeg_build/ffmpeg_build_smp.sh  m_ffmpeg_smp.sh

    create_link_to_bin ${build_dir}/02.codec_tools/01.sw_codec_eval/sw_codec.sh  m_sw_codec_eval.sh
    create_link_to_bin ${build_dir}/02.codec_tools/02.spec_build/specBuild.sh    m_spec_build.sh
    create_link_to_bin ${build_dir}/02.codec_tools/02.spec_build/specDebug.sh    m_spec_debug.sh

    echo "build tools: for prj usage"
    echo '  ln -s ${HOME}/bin/m_ffmpeg_smp.sh .prjBuild.sh'
    echo '  ln -s ${HOME}/bin/m_spec_build.sh .prjBuild.sh'
    echo '  ln -s ${HOME}/bin/m_spec_debug.sh .prjDebug.sh'
}

# =============================================================================
#  rk tools
# =============================================================================

function init_rk_tools()
{
    echo
    echo "==> Installing RK tools"

    rk_tools_dir="${repo_root}/04.spec_tools/01.rk_tools/01.rk_tools"

    # mpp
    create_link_to_bin ${rk_tools_dir}/rkBuildMpp.sh rkBuildMpp.sh
    create_link_to_bin ${rk_tools_dir}/rkDebugMpp.sh rkDebugMpp.sh

    # kernel
    create_link_to_bin ${rk_tools_dir}/rkBuildKer.sh rkBuildKer.sh
    create_link_to_bin ${rk_tools_dir}/rkDebugKer.sh rkDebugKer.sh
    create_link_to_bin ${rk_tools_dir}/rkut.sh       rkut.sh

    # tools
    create_link_to_bin ${rk_tools_dir}/rk_tar_mpp.sh rk_tar_mpp.sh
    create_link_to_bin ${rk_tools_dir}/rk_tar_ker.sh rk_tar_ker.sh

    # batch test tools
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTCore.sh         rkBtC
    create_link_to_bin ${rk_tools_dir}/batch_test/rkBatchTTolkit.sh       rkBt
    create_link_to_bin ${rk_tools_dir}/batch_test/veri_regression/main.py rk_r_ver
    create_link_to_bin ${rk_tools_dir}/rk_dec_verify.sh                   rkDecVerify.sh

    # rga
    create_link_to_bin ${rk_tools_dir}/rkBuildRga.sh rkBuildRga.sh

    echo "rk tools: for prj usage"
    echo '  ln -s ${HOME}/bin/rkBuildMpp.sh .prjBuild.sh'
    echo '  ln -s ${HOME}/bin/rkDebugMpp.sh .prjDebug.sh'
    echo '  ln -s ${HOME}/bin/rkBuildKer.sh .prjBuild.sh'
    echo '  ln -s ${HOME}/bin/rkDebugKer.sh .prjDebug.sh'
    echo '  ln -s ${HOME}/bin/rkBuildRga.sh .prjBuild.sh'
    echo


    rk_tools_dir="${repo_root}/04.spec_tools/01.rk_tools/02.cmodel_tools"

    # cmodel tools
    create_link_to_bin ${rk_tools_dir}/cmodel_reg_proc.py   rk_cmod_reg_proc.py


    rk_tools_dir="${repo_root}/04.spec_tools/01.rk_tools/07.reg_opt"

    # reg opt tools
    create_link_to_bin ${rk_tools_dir}/main.py   m_reg_ut.py


    rk_tools_dir="${repo_root}/04.spec_tools/01.rk_tools/04.rk_fpga_tools"

    # fpga tools
    create_link_to_bin ${rk_tools_dir}/link.sh   rk_fpga_tools_init.sh

}

function init_shell()
{
    echo
    echo "==> init shell config"

    # bashrc
    rc_file=${HOME}/.bashrc
    if [ -z "$(cat ${rc_file} | grep 'Personal configuration')" ];
    then
        echo
        echo "# ======================================================" >> ${rc_file}
        echo "# =========== Personal configuration ===================" >> ${rc_file}
        echo "# ======================================================" >> ${rc_file}
        echo "# ======> my tools and config"                            >> ${rc_file}
        echo "# export GIT_SSH_PORT=443"                                >> ${rc_file}
        echo "# proxyIP=<your_proxy_ip>"                                >> ${rc_file}
        echo "# proxyPort=<your_proxy_port>"                            >> ${rc_file}
        echo "# export proxyMihomoAddr=127.0.0.1:9090"                  >> ${rc_file}
        echo "# export proxyMihomoCfgDir=\${HOME}/.config/mihomo"       >> ${rc_file}
        echo "# export proxyMihomoBin=\${HOME}/.local/bin/mihomo"       >> ${rc_file}
        echo "# export ANDROID_ADB_SERVER_PORT=<adb_port>"              >> ${rc_file}
        echo "#-- export ADB_SERVER_SOCKET=tcp:127.0.0.1:<port>"        >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
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
        echo "# export GIT_SSH_PORT=443"                                >> ${rc_file}
        echo "# proxyIP=<your_proxy_ip>"                                >> ${rc_file}
        echo "# proxyPort=<your_proxy_port>"                            >> ${rc_file}
        echo "# export proxyMihomoAddr=127.0.0.1:9090"                  >> ${rc_file}
        echo "# export proxyMihomoCfgDir=\${HOME}/.config/mihomo"       >> ${rc_file}
        echo "# export proxyMihomoBin=\${HOME}/.local/bin/mihomo"       >> ${rc_file}
        echo "# export ANDROID_ADB_SERVER_PORT=<adb_port>"              >> ${rc_file}
        echo "#-- export ADB_SERVER_SOCKET=tcp:127.0.0.1:<port>"        >> ${rc_file}
        echo "source ${source_file}"                                    >> ${rc_file}
        echo "${rc_file} init finished!"
    else
        echo "${rc_file} has configed!"
    fi
}

function main()
{
    get_repo_root
    init_libs
    init_shell_env
    init_gen_tools
    init_build
    init_rk_tools
    init_shell
}

main $@

