#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildKer.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

# when add new plt:
#   1. add plt name in pltList
#   2. add build methed

set -e

cmd_init_env="false"
cmd_wk_dir=""

sel_tag_ker="rk_kernel_b: "
sel_tag_mod="rk_kernel_b_m: "
sel_tag_android="rk_kernel_b_android: "

pltList=(
    "1109/1126_android"
    "3288_android"
    "3328_android"
    "3399_android"
    "3566_android"
    "3588_android"
    "3562_android"
    "3576_android"
    "3572_android"
    "3528_android"
    "3538_android"
    "1106_linux"
    "px30_linux"
    "3326_linux"
    "3399_linux"
    "3566_linux"
    "3588_linux"
    "3576_linux"
    "3576_fpga"
    "1126B_linux_fpga"
    "1126B_ipc_arm"
    "1126B_linux_aarch"
    "intel_linux_fpga"
    )

build_mode_list=(
    "build_kmod"
    "build_kernel"
    )

curPlt="3588_android"
cur_android_ver=""
cur_android_config=""

m_toolchains=""
m_arch=""
m_config=""
m_make=""
build_mod=""
config_cmd=""
build_cmd=""
build_mod_cmd=""
adbCmd=""

get_arch()
{
    if [ -n "${curPlt}" ]; then
        case ${curPlt} in
            '1109/1126_android'\
            |'3288_android'\
            |'1106_linux'\
            |'1126B_ipc_arm')
                m_arch="arm"
                ;;
            '3328_android'\
            |'3399_android'\
            |'3566_android'\
            |'3588_android'\
            |'3562_android'\
            |'3576_android'\
            |'3572_android'\
            |'3528_android'\
            |'3538_android'\
            |'px30_linux'\
            |'3326_linux'\
            |'3399_linux'\
            |'3566_linux'\
            |'3588_linux'\
            |'3576_linux'\
            |'3576_fpga'\
            |'1126B_linux_fpga'\
            |'1126B_linux_aarch'\
            |'intel_linux_fpga')
                m_arch="arm64"
                ;;
        esac
    fi
}

init_tools_env()
{
    tools_dir="${HOME}/Projects/prebuilts"

    if [ "${m_arch}" == "arm" ]; then  # arm
        # default
        m_toolchains="${tools_dir}/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin"
        m_make="make CROSS_COMPILE=arm-linux-gnueabihf-"

        # for diff platform
        if [ "${curPlt}" == "1126B_ipc_arm" ]; then
            m_toolchains="${tools_dir}/toolchains/arm/arm-rockchip1240-linux-gnueabihf/bin"
            m_make="make CROSS_COMPILE=arm-rockchip1240-linux-gnueabihf-"
        fi
    else # arm64
        # default
        if [ -n "`echo ${curPlt} | grep linux`" ]; then # linux
            m_toolchains="${tools_dir}/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin"
            m_make="make CROSS_COMPILE=aarch64-none-linux-gnu-"
        else # android
            if [ "${VERSION}" -lt "6" ]; then
                m_toolchains="${tools_dir}/toolchains/aarch64/clang-r416183b/bin"
            else
                m_toolchains="${tools_dir}/toolchains/linux-x86_rk/clang-r487747c/bin"
            fi
            m_make="make CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

            if [ -n "`echo ${curPlt} | grep fpga`" ]; then
                m_make="make CROSS_COMPILE=aarch64-linux-gnu- LT0=none LLVM=1 LLVM_IAS=1"
                echo '3576 kernel6.1 fpga maybe need this toolchain'
                echo '${tools_dir}/toolchains/aarch64/clang-r433403/bin'
            fi
        fi

        # for diff platform
        if [ "${curPlt}" == "1126B_linux_aarch" ]; then
            m_toolchains="${tools_dir}/toolchains/aarch64/aarch64-rockchip1240-linux-gnu/bin"
            m_make="make CROSS_COMPILE=aarch64-rockchip1240-linux-gnu-"
        fi
    fi

    export PATH=${m_toolchains}:$PATH
    echo "toolchains: ${m_toolchains}"
    echo "m_make: ${m_make}"
}

gen_cmd()
{
    # select android config
    if [ -n "`echo ${curPlt} | grep android`" ]; then
        android_ver_list=(`find ./ | grep "android-[0-9].*config" | sed "s/.*android-//g" \
                           | awk -F'[.-]' '{print $1}' | uniq | sort -r`)
        if [ "${#android_ver_list[@]}" -le "1" ]; then
            cur_android_ver=${android_ver_list[0]}
        else
            select_node "${sel_tag_android}" "android_ver_list" "cur_android_ver" "android version"
        fi
        if [ -n "${cur_android_ver}" ]; then
            cur_android_config="android-${cur_android_ver}.config"
        else
            cur_android_config=""
        fi
    fi

    if [ -n "`cat drivers/video/rockchip/mpp/Makefile | grep obj-m | sed \"s/#.*//g\"`" ]; then
        # modify drivers/video/rockchip/mpp/Makefile need modify:
        # obj-$(CONFIG_ROCKCHIP_MPP_SERVICE) --> obj-m
        select_node "${sel_tag_mod}" "build_mode_list" "build_mod" "build method"
    else
        # default build kernel
        build_mod="build_kernel";
    fi

    if [ -n "${curPlt}" ]; then
        case ${curPlt} in
            '1109/1126_android')
                m_config="rv1126_defconfig"
                m_target="rv1126-evb-ddr3-v13.img"
                ;;
            '3288_android')
                m_config="rockchip_defconfig"
                m_target="rk3288-evb-android-rk808-edp.img"
                ;;
            '3328_android')
                m_config="rockchip_defconfig"
                m_target="rk3328-evb-android-avb.img BOOT_IMG=../rk_kernel_boot/boot_rk3328EVB.img"
                ;;
            '3399_android')
                m_config="rockchip_defconfig ${cur_android_config} disable_incfs.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_sample.img rk3399-evb-ind-lpddr4-android-avb.img"
                ;;
            '3566_android')
                m_config="rockchip_defconfig rk356x.config ${cur_android_config}"
                m_target="rk3566-evb1-ddr4-v10.img BOOT_IMG=../rk_kernel_boot/boot1.img"
                ;;
            '3588_android')
                m_config="rockchip_defconfig ${cur_android_config}"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_3588.img rk3588-evb1-lp4-v10.img"
                ;;
            '3562_android')
                m_config="rockchip_defconfig ${cur_android_config} rk356x.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_3562.img rk3562-evb2-ddr4-v10.img"
                ;;
            '3576_android')
                m_config="rockchip_defconfig ${cur_android_config} rk3576.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_3576.img rk3576-evb1-v10.img"
                ;;
            '3572_android')
                m_config="rockchip_defconfig ${cur_android_config} rk3572.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_3572.img rk3572-evb1-v10.img"
                ;;
            '3528_android')
                m_config="rockchip_defconfig ${cur_android_config} rk3528_box.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_rk3528EVB.img rk3528-evb1-ddr4-v10.img"
                ;;
            '3538_android')
                m_config="rockchip_defconfig ${cur_android_config} rk3538.config"
                m_target="BOOT_IMG=../rk_kernel_boot/boot_rk3538EVB.img rk3538-evb1-ddr4-v10.img"
                ;;
            '1106_linux')
                m_config="rv1106_defconfig"
                m_target="rv1106g-evb1-v11.img"
                ;;
            'px30_linux')
                m_config="px30_linux_defconfig"
                m_target="px30-evb-ddr3-v10-linux.img"
                ;;
            '3326_linux')
                m_config="rk3326_linux_robot_defconfig"
                m_target="rk3326-evb-lp3-v10-linux.img"
                ;;
            '3399_linux')
                m_config="rockchip_linux_defconfig"
                m_target="rk3399-evb-ind-lpddr4-linux.img"
                ;;
            '3566_linux')
                m_config="rockchip_linux_defconfig"
                m_target="rk3566-evb1-ddr4-v10-linux.img"
                ;;
            '3588_linux')
                m_config="rockchip_linux_defconfig"
                m_target="rk3588-evb1-lp4-v10.img"
                ;;
            '3576_linux')
                m_config="rockchip_linux_defconfig"
                m_target="rk3576-evb1-v10-linux.img"
                ;;
            '3576_fpga')
                m_config="rockchip_defconfig"
                m_target="rk3576-fpga.img"
                ;;
            '1126B_linux_fpga')
                m_config="rv1126b_defconfig"
                m_target="rv1126b-fpga.img"
                ;;
            '1126B_ipc_arm')
                m_config="rv1126b_defconfig rv1126b-evb.config"
                m_target="rv1126b-evb1-v10.img BOOT_ITS=boot.its"
                ;;
            '1126B_linux_aarch')
                m_config="rv1126b_defconfig"
                m_target="rv1126b-evb1-v10.img BOOT_ITS=boot.its"
                ;;
            'intel_linux_fpga')
                m_config="socfpga_stratix10_defconfig"
                # 这里的modules是为了生成kernel根目录下的 Module.symvers
                # 1. Module.symvers 的作用
                #   这个文件是 内核构建系统生成的符号表，记录了所有
                #   EXPORT_SYMBOL() / EXPORT_SYMBOL_GPL() 导出的符号及其 CRC 校验值。
                #   modpost 阶段会用它来：
                #       确认外部模块用到的符号是否存在
                #       检查符号的 CRC，保证内核与模块 ABI 一致
                #   没有这个文件，modpost 就认为没有任何可用的导出符号，于是就出现
                #   undefined! 警告。
                # 2. 生成时机
                #   执行 make modules（编译内核所有模块）会生成一个完整的 Module.symvers。
                #   执行 make modules_prepare 也会生成一个空的 Module.symvers，
                #   并生成 scripts/module.lds 和 include/generated/*，以便外部模块能正常编译。
                #   如果内核源码树里既没执行过 make modules 也没执行过 make modules_prepare，
                #   那么根目录下就不会有 Module.symvers。
                m_target="Image altera/socfpga_stratix10_socdk.dtb modules"
                ;;
        esac
    fi
    echo "m_config: ${m_config}"
    echo "m_target: ${m_target}"
    if [ "${build_mod}" == "build_kernel" ]; then
        config_cmd="${m_make} ARCH=${m_arch} ${m_config}"
        build_cmd="${m_make} ARCH=${m_arch} ${m_target} -j$(nproc)"
        echo "config cmd: ${config_cmd}"
        echo "build  cmd: ${build_cmd}"
    fi
    if [ "${build_mod}" == "build_kmod" ]; then
        build_mod_cmd="${m_make} ARCH=${m_arch} -C `pwd` M=`pwd`/drivers/video/rockchip/mpp modules -j$(nproc)"
        echo "build mod cmd: ${build_mod_cmd}"
    fi
}

build_kernel_mod()
{
    if [ "${build_mod}" == "build_kernel" ]; then
        echo "======> compile kernel begin <======"
        ${config_cmd}
        if [ $? -ne 0 ]; then echo "config failed, cmd: ${config_cmd}"; exit 1; fi
        if [ ${curPlt} == "3576_fpga" ]; then
            echo "modify .config for ${curPlt}";
            sed -i "s/# CONFIG_ROCKCHIP_MPP_RKVDEC3 is not set/CONFIG_ROCKCHIP_MPP_RKVDEC3=y/g" .config;
            # sed -i "s/# CONFIG_EXFAT_FS is not set/CONFIG_EXFAT_FS=y/g" .config;
            # sed -i "s/# CONFIG_NTFS_FS is not set/CONFIG_NTFS_FS=y/g" .config;
            if [ $? -ne 0 ]; then echo "modify .config failed"; fi
        fi
        if [ ${curPlt} == "3576_android" ]; then
            echo "modify .config for ${curPlt}";
            sed -i "s/# CONFIG_DEVMEM is not set/CONFIG_DEVMEM=y/g" .config;
            if [ $? -ne 0 ]; then echo "modify .config failed"; fi
        fi
        if [ ${curPlt} == "1126B_linux_fpga" ]; then
            echo "modify .config for ${curPlt}";
            # sdcard support
            sed -i "s/# CONFIG_EXFAT_FS is not set/CONFIG_EXFAT_FS=y/g" .config;
            sed -i "s/# CONFIG_MMC_SDHCI is not set/CONFIG_MMC_SDHCI=y/g" .config;
            sed -i "s/# CONFIG_CRC_ITU_T is not set/CONFIG_CRC_ITU_T=y/g" .config;
            sed -i "s/# CONFIG_CRC7 is not set/CONFIG_CRC7=y/g" .config;
            # sed -i "s/# CONFIG_NTFS_FS is not set/CONFIG_NTFS_FS=y/g" .config;

            # io
            # sed -i "s/# CONFIG_DEVMEM is not set/CONFIG_DEVMEM=y/g" .config;
            if [ $? -ne 0 ]; then echo "modify .config failed"; fi
        fi
        ${build_cmd}
        if [ $? -ne 0 ]; then echo "build failed, cmd: ${build_cmd}"; exit 1; fi
        echo "toolchains: ${m_toolchains}"
        echo "config cmd: ${config_cmd}"
        echo "build  cmd: ${build_cmd}"
        echo "======> compile kernel done <======"
    fi

    if [ "${build_mod}" == "build_kmod" ]; then
        echo "======> compile rk_vcodec.ko begin <======"
        ${build_mod_cmd}
        echo "======> compile rk_vcodec.ko done <======"
    fi
}

download()
{
    if [ "${build_mod}" == "build_kernel" ]; then
        echo ""
        echo "======> copy boot.img to ~/test <======"
        echo "cur dir: `pwd`"
        cp boot.img ~/test

        echo ""
        echo "======> download boot.img <======"
        # download boot.img
        rkUT.sh -di -b
        # reset device
        rkUT.sh -rd
    fi

    if [ "${build_mod}" == "build_kmod" ]; then
        echo ""
        echo "======> reload rk_vcodec.ko <======"
        adbCmd=$(adbs)
        if [ -z "${adbCmd}" ]; then exit 0; fi
        ${adbCmd} push drivers/video/rockchip/mpp/rk_vcodec.ko /data
        if [ -n "`${adbCmd} shell lsmod | grep rk_vcodec`" ]; then
            echo "rmmod old rk_vcodec.ko"
            ${adbCmd} shell rmmod rk_vcodec.ko
        fi
        echo "insmod rk_vcodec.ko"
        ${adbCmd} shell insmod /data/rk_vcodec.ko
    fi
}

# ====== main ======

while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        --env) cmd_init_env="true"; ;;
        --dir) cmd_wk_dir="$2"; shift; ;;
        -h|--help) echo "rkBuildKer.sh [--env] [--dir <kernel_path>]"; exit 0; ;;
        *) echo "unknow para: ${key}"; exit 1; ;;
    esac
    shift # move to next para
done


source ${HOME}/bin/_select_node.sh

if [ -n "${cmd_wk_dir}" ]; then
    cd ${cmd_wk_dir}
fi

KERNEL_VER=`make kernelversion`
VERSION=`head -n 10 Makefile | grep "^VERSION" | awk '{print $3}'`
PATCHLEVEL=`head -n 10 Makefile | grep "^PATCHLEVEL" | awk '{print $3}'`
SUBLEVEL=`head -n 10 Makefile | grep "^SUBLEVEL" | awk '{print $3}'`

echo "KERNEL_VER = ${KERNEL_VER}"
echo "VERSION    = ${VERSION}"
echo "PATCHLEVEL = ${PATCHLEVEL}"
echo "SUBLEVEL   = ${SUBLEVEL}"

select_node "${sel_tag_ker}" "pltList" "curPlt" "platform"
get_arch
init_tools_env
gen_cmd
if [ "${cmd_init_env}" == "true" ]; then exit 0; fi
build_kernel_mod
download

set +e
