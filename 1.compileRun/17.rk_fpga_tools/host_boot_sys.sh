#!/usr/bin/env bash
#########################################################################
# File Name: host_boot_sys.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 08 Jan 2025 09:27:23 AM CST
#########################################################################

# 1. 构建特定平台的目录结构，以3576为例
#    RK3576
#       mImage
#           bl31_0x40040000.bin   从上级目录复制过来
#           Image                 从kernel中编译得到
#           rk3576-fpga.dtb       从kernel中编译得到
#           rootfs.cpio           使用buildroot编译得到
#       bl31_0x40040000.bin       底层平台/fpga 相关人员提供
#       post_load_image.cfg       底层平台/fpga 相关人员提供
#       pre_load_image.cfg        底层平台/fpga 相关人员提供
# 2. 修改pre_load_image.cfg中相关的文件路径，例如kernel/rootfs等
# 3. 修改当前脚本中相关变量

sel_tag_fpga="rk_fpga_openocd: "

plt_list=(
    "RK3576"
    "RV1126B"
    )

# prj dirs
cur_plt=""
prj_dir=""
ker_dir=""
brt_dir=""

# imgs
bld=""    # bootloader
dtb=""
ker=""
rfs=""
target_dir=""

update_prj_dirs()
{
    prj_dir="${cur_plt}"
    ker_dir="${HOME}/Projects/kernel2"
    brt_dir="${HOME}/Projects/buildroot_git"

    echo "prj_dir: ${prj_dir}"
    echo "ker_dir: ${ker_dir}"
    echo "brt_dir: ${brt_dir}"
    echo
}

update_imgs_path()
{
    bld="${prj_dir}/bl31_0x40040000.bin"    # bootloader
    dtb="${ker_dir}/arch/arm64/boot/dts/rockchip/rv1126b-fpga.dtb"
    ker="${ker_dir}/arch/arm64/boot/Image"
    rfs="${brt_dir}/output/images/rootfs.cpio"
    target_dir="${prj_dir}/mImage"

    case ${cur_plt} in
        'RK3576')
            dtb="${ker_dir}/arch/arm64/boot/dts/rockchip/rk3576-fpga.dtb"
            ;;
        'RV1126B')
            dtb="${ker_dir}/arch/arm64/boot/dts/rockchip/rv1126b-fpga.dtb"
            ;;
    esac

    echo "bld: ${bld}"
    echo "dtb: ${dtb}"
    echo "ker: ${ker}"
    echo "rfs: ${rfs}"
    echo "target_dir: ${target_dir}"
    echo
}

collect_imgs()
{
    update_file ${bld} ${target_dir}
    update_file ${dtb} ${target_dir}
    update_file ${ker} ${target_dir}
    update_file ${rfs} ${target_dir}

    update_file ${brt_dir}/.config ${prj_dir}/buildroot_config
}

boot_sys()
{
    # 可以使用 ./openocd -r -h 查看需要使用的 -r 参数，-h并不是提供帮助信息，主要是
    # 提供一个错误的参数，以便打印错误信息，这里的rk3528 (4xcortex-a53)，是指4个a53核
    # -c "set CHIPCORES 2"是指只连接两个core，即只适用两个core

    openocd_cmd=""

    case ${cur_plt} in
        'RK3576')
            openocd_cmd="sudo ./src/openocd -r rk3528 \
                -c \"set CHIPCORES 2\" -c \"set CONNECT_ONLY 0\" -c \"gdb_port 8899\" \
                -i ${prj_dir}/pre_load_image.cfg -i ${prj_dir}/post_load_image.cfg"
            ;;
        'RV1126B')
            openocd_cmd="sudo ./src/openocd -r rv1126b \
                -c \"set CHIPCORES 1\" -c \"set CONNECT_ONLY 0\" -c \"gdb_port 8899\" \
                -i ${prj_dir}/pre_load_image.cfg -i ${prj_dir}/post_load_image.cfg"
            ;;
    esac

    echo "openocd cmd: ${openocd_cmd}"
    # 如果直接执行${openocd_cmd}，有些内容解析会有问题，因此需要用eval重新解析一下
    eval ${openocd_cmd}
}

# ====== main ======
prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prj_root_dir}/0.general_tools/0.select_node.sh
prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prj_root_dir}/0.general_tools/0.dir_file_opt.sh

while true; do
    cur_time="`date +"%Y_%m_%d %H:%M:%S"`"
    echo -e "\033[0m\033[1;33mcur time: ${cur_time}\033[0m"
    selectNode "${sel_tag_fpga}" "plt_list" "cur_plt" "platform"
    clear
    update_prj_dirs
    update_imgs_path
    create_dir ${prj_dir}
    create_dir ${target_dir}
    collect_imgs
    boot_sys

    # prepare
    # sudo cp ./99-openocd.rules ./60-openocd.rules /etc/udev/rules.d/ \
    # 	&& sudo udevadm control --reload-rules \
    # 	&& sudo udevadm control --reload
done
