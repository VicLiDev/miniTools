#!/usr/bin/env bash
#########################################################################
# File Name: host_update_sdcard.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 08 Jan 2025 09:34:16 AM CST
#########################################################################

sel_tag_fpga="rk_fpga_update: "
update_list=(
    "-sd"
    "-rfs"
    "-all"
    )
cur_update=""

opt_only_sd="False"
opt_only_rfs="False"

mpp_dir="${HOME}/Projects/mpp"
ker_dir="${HOME}/Projects/kernel2"

sd_dev="/dev/sdb1"
sd_mnt_pnt="${HOME}/sdcard"
sd_exe_dir="${HOME}/sdcard/exec"

rtfs_dir="${HOME}/Projects/buildroot_git"
rtfs_sys_dir="${rtfs_dir}/output/target"
rtfs_exe_dir="${rtfs_sys_dir}/root/bin"
rtfs_lib_dir="${rtfs_sys_dir}/usr/lib64"
rtfs_spt_dir="${rtfs_sys_dir}/root"

h265_test_streams="${HOME}/Projects/streams/m_h265"
h264_test_streams="${HOME}/Projects/streams/m_h264"
avs2_test_streams="${HOME}/Projects/streams/m_avs2"
vp9_test_streams="${HOME}/Projects/streams/m_vp9"
av1_test_streams="${HOME}/Projects/streams/m_av1"
sd_video_dir="${HOME}/sdcard/test_stream/"
rfs_video_dir="${HOME}/sdcard/test_stream/"

ker_ko="${ker_dir}/drivers/video/rockchip/mpp/rk_vcodec.ko"
mpp_lib="${mpp_dir}/build/linux/aarch64/mpp/librockchip_mpp.so.0"
mpp_dec_exe="${mpp_dir}/build/linux/aarch64/test/mpi_dec_test"
fpga_tools_dir="${HOME}/Projects/miniTools/1.compileRun/17.rk_fpga_tools"
test_script="${fpga_tools_dir}/target_run_test.sh"
test_script2="${fpga_tools_dir}/target_run_batch.sh"


function create_dir()
{
    [ ! -d $1 ] && { echo "create dir $1"; mkdir -p $1; }
}

function update_file()
{
    [ ! -e $1 ] && echo "src file $1 do not exist"
    [ ! -e $2 ] && echo "dst dir $2 do not exist"
    echo "--copy--  $1"
    echo "== to ==> $2"
    cp -r $1 $2
}

function usage()
{
    echo "<exe> -<opt>"
    echo "  sd:  only update sd"
    echo "  rfs: only update rootfs"
    echo "  all: update sd and rootfs"
}

function procParas()
{
    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--help)
                usage
                exit 0
                ;;
            -sd)
                opt_only_sd="True"
                ;;
            -rfs)
                opt_only_rfs="True"
                ;;
            -all)
                opt_only_sd="True"
                opt_only_rfs="True"
                ;;
            *)
                usage
                exit 0
                ;;
        esac
        shift # move to next para
    done

    echo "opt_only_sd:   ${opt_only_sd}"
    echo "opt_only_rfs:  ${opt_only_rfs}"
}

function main()
{
    procParas $@

    if [[ ${opt_only_sd} == "True" && -e ${sd_dev} ]]; then
        # rm -rf ${sd_mnt_pnt}
        create_dir ${sd_mnt_pnt}
        sudo mount -o uid=1000 ${sd_dev} ${sd_mnt_pnt}
        # update mpp/ko to sd
        create_dir  ${sd_exe_dir}
        update_file ${ker_ko}       ${sd_exe_dir}
        update_file ${mpp_lib}      ${sd_exe_dir}
        update_file ${mpp_dec_exe}  ${sd_exe_dir}
        update_file ${test_script}  ${sd_exe_dir}
        update_file ${test_script2} ${sd_exe_dir}

        # # update video
        # create_dir ${sd_video_dir}
        # create_dir ${sd_video_dir}/m_h265
        # create_dir ${sd_video_dir}/m_h264
        # create_dir ${sd_video_dir}/m_avs2
        # create_dir ${sd_video_dir}/m_vp9
        # create_dir ${sd_video_dir}/m_av1
        # update_file ${h265_test_streams}/vstream ${sd_video_dir}/m_h265
        # update_file ${h264_test_streams}/vstream ${sd_video_dir}/m_h264
        # update_file ${avs2_test_streams}/vstream ${sd_video_dir}/m_avs2
        # update_file ${vp9_test_streams}/vstream ${sd_video_dir}/m_vp9
        # update_file ${av1_test_streams}/vstream ${sd_video_dir}/m_av1

        sudo umount ${sd_mnt_pnt}
    fi

    if [ ${opt_only_rfs} == "True" ]; then
        # update mpp to buildroot
        create_dir  ${rtfs_exe_dir}
        create_dir  ${rtfs_lib_dir}
        create_dir  ${rtfs_spt_dir}
        update_file ${ker_ko}       "${rtfs_exe_dir}"
        update_file ${mpp_lib}      "${rtfs_lib_dir}"
        update_file ${mpp_dec_exe}  "${rtfs_exe_dir}"
        update_file ${test_script}  "${rtfs_exe_dir}"
        update_file ${test_script2} "${rtfs_spt_dir}"
        link_name="${rtfs_sys_dir}/usr/lib64/librockchip_mpp.so.1"
        # lib_name="${rtfs_sys_dir}/usr/lib64/librockchip_mpp.so.0"
        lib_name="librockchip_mpp.so.0"
        [ ! -e ${link_name} ] && ln -s ${lib_name} ${link_name}
        make -j 10 -C ${rtfs_dir}

        # # update video
        # create_dir ${rfs_video_dir}
        # update_file ${h265_test_streams} ${rfs_video_dir}
        # update_file ${h264_test_streams} ${rfs_video_dir}
        # update_file ${avs2_test_streams} ${rfs_video_dir}
        # update_file ${vp9_test_streams} ${rfs_video_dir}
        # update_file ${av1_test_streams} ${rfs_video_dir}
    fi
}


# ====== main ======
source ${HOME}/bin/_select_node.sh

if [ $# -eq 0 ]; then
    while true; do
        opt_only_sd="False"
        opt_only_rfs="False"
        cur_time="`date +"%Y_%m_%d %H:%M:%S"`"
        echo -e "\033[0m\033[1;33mcur time: ${cur_time}\033[0m"
        select_node "${sel_tag_fpga}" "update_list" "cur_update" "update node"
        clear
        main ${cur_update}
    done
else
    main $@
fi
