#!/bin/bash

# when add new plt:
#   1. add plt name in pltList
#   2. add build methed

set -e

pltList=(
    "1109/1126_android"
    "3288_android"
    "3328_android"
    "3399_android"
    "3568_android"
    "3588_android"
    "3576_android"
    "px30_linux_4.4_4.19"
    "3326_linux_4.4_4.19"
    "3399_linux_5.10"
    "3568_linux_4.19"
    "3588_linux_5.10"
    "3576_linux_5.10_fpga"
    "3576_linux_6.1_fpga"
    "3576_linux_6.1"
    )

build_mode_list=(
    "build_kmod"
    "build_kernel"
    )

curPlt="3588_android"

m_arch=""
m_config=""
target=""
m_make=""
build_mod=""
adbCmd=""

display()
{
    local -n list_ref="$1"
    local tip="$2"
    echo "Please select ${tip}:"
    for ((i = 0; i < ${#list_ref[@]}; i++))
    do
        echo "  ${i}. ${list_ref[${i}]}"
    done
}

selectNode()
{
    defSelIdx="$1"
    local list_name="$2"
    local -n list_ref="$2"
    local -n sel_res="$3"
    sel_tip="$4"

    display $list_name $sel_tip
    echo "cur dir: `pwd`"
    while [ True ]
    do
        read -p "Please select ${sel_tip} or quit(q), def[${defSelIdx}]:" selIdx
        selIdx=${selIdx:-${defSelIdx}}

        if [ "${selIdx}" == "q" ]; then
            echo "======> quit <======"
            exit 0
        elif [[ -n ${selIdx} ]] \
            && [[ -z `echo ${selIdx} | sed 's/[0-9]//g'` ]] \
            && [[ "${selIdx}" -lt "${#list_ref[@]}" ]]; then
            sel_res=${list_ref[${selIdx}]}
            echo "--> selected index:${selIdx}, ${sel_tip}:${sel_res}"
            break
        else
            sel_res=""
            echo "--> please input num in scope 0-`expr ${#list_ref[@]} - 1`"
            continue
        fi
    done
}

gen_cmd()
{
    if [ -n "`cat drivers/video/rockchip/mpp/Makefile | grep obj-m | sed \"s/#.*//g\"`" ]; then
        # modify drivers/video/rockchip/mpp/Makefile need modify:
        # obj-$(CONFIG_ROCKCHIP_MPP_SERVICE) --> obj-m
        selectNode "0" "build_mode_list" "build_mod" "build method"
    else
        # default build kernel
        build_mod="build_kernel";
    fi
    if [ -n "${curPlt}" ]; then
        case ${curPlt} in
            '1109/1126_android')
                echo "======> selected ${curPlt} <======"
                export PATH=${HOME}/Projects/prebuilts/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin:$PATH
                m_arch="arm"
                m_config="rv1126_defconfig"
                m_target="rv1126-evb-ddr3-v13.img"
                m_make="make CROSS_COMPILE=arm-linux-gnueabihf-"
                ;;
            '3288_android')
                echo "======> selected ${curPlt} <======"
                m_arch="arm"
                m_config="rockchip_defconfig"
                m_target="rk3288-evb-android-rk808-edp.img"
                m_make="make"
                ;;
            '3328_android')
                echo "======> selected ${curPlt} <======"
                m_arch="arm64"
                m_config="rockchip_defconfig"
                m_target="rk3328-evb-android-avb.img BOOT_IMG=./boot_rk3328EVB.img"
                m_make="make"
                ;;
            '3399_android')
                echo "======> selected ${curPlt} <======"
                m_arch="arm64"
                m_config="rockchip_defconfig android-11.config disable_incfs.config"
                m_target="BOOT_IMG=./boot_sample.img rk3399-evb-ind-lpddr4-android-avb.img"
                m_make="make"
                ;;
            '3568_android')
                echo "======> selected ${curPlt} <======"
                m_arch="arm64"
                m_config="rockchip_defconfig rk356x.config android-11.config"
                m_target="rk3566-evb1-ddr4-v10.img BOOT_IMG=boot1.img"
                m_make="make"
                ;;
            '3588_android')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/clang-r416183b/bin:$PATH
                m_arch="arm64"
                m_config="rockchip_defconfig android-11.config"
                m_target="BOOT_IMG=./boot_3588.img rk3588-evb1-lp4-v10.img"
                m_make="make CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"
                ;;
            '3576_android')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/linux-x86_rk/clang-r487747c/bin:$PATH
                m_arch="arm64"
                m_config="rockchip_defconfig android-14.config rk3576.config"
                m_target="BOOT_IMG=./boot_3576.img rk3576-evb1-v10.img"
                m_make="make CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"
                ;;
            'px30_linux_4.4_4.19')
                echo "======> selected ${curPlt} <======"
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="px30_linux_defconfig"
                m_target="px30-evb-ddr3-v10-linux.img"
                m_make="make"
                ;;
            '3326_linux_4.4_4.19')
                echo "======> selected ${curPlt} <======"
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rk3326_linux_robot_defconfig"
                m_target="rk3326-evb-lp3-v10-linux.img"
                m_make="make"
                ;;
            '3399_linux_5.10')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_linux_defconfig"
                m_target="rk3399-evb-ind-lpddr4-linux.img"
                m_make="make"
                ;;
            '3568_linux_4.19')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_linux_defconfig"
                m_target="rk3568-evb1-ddr4-v10-linux.img"
                m_make="make"
                ;;
            '3588_linux_5.10')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_linux_defconfig"
                m_target="rk3588-evb1-lp4-v10.img"
                m_make="make"
                ;;
            '3576_linux_5.10_fpga')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/clang-r416183b/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_defconfig LT0=none LLVM=1 LLVM_IAS=1"
                m_target="rk3576-fpga.img LT0=none LLVM=1 LLVM_IAS=1"
                m_make="make"
                ;;
            '3576_linux_6.1_fpga')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/clang-r433403/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_defconfig LT0=none LLVM=1 LLVM_IAS=1"
                m_target="rk3576-fpga.img LT0=none LLVM=1 LLVM_IAS=1"
                m_make="make"
                ;;
            '3576_linux_6.1')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-
                m_arch="arm64"
                m_config="rockchip_linux_defconfig"
                m_target="rk3576-evb1-v10-linux.img"
                m_make="make"
                ;;
        esac
    fi
}

build_kernel_mod()
{
    if [ "${build_mod}" == "build_kernel" ]; then
        echo "======> compild kernel begin <======"
        config_cmd="${m_make} ARCH=${m_arch} ${m_config}"
        build_cmd="${m_make} ARCH=${m_arch} ${m_target} -j20"
        echo "config cmd: ${config_cmd}"
        echo "build  cmd: ${build_cmd}"
        ${config_cmd}
        if [ $? -ne 0 ]; then echo "config faile, cmd: ${config_cmd}"; exit 1; fi
        if [[ ${curPlt} == "3576_linux_5.10_fpga" || ${curPlt} == "3576_linux_6.1_fpga" ]]; then
            echo "modify .config for ${curPlt}";
            sed -i "s/# CONFIG_ROCKCHIP_MPP_RKVDEC3 is not set/CONFIG_ROCKCHIP_MPP_RKVDEC3=y/g" .config;
            # sed -i "s/# CONFIG_EXFAT_FS is not set/CONFIG_EXFAT_FS=y/g" .config;
            # sed -i "s/# CONFIG_NTFS_FS is not set/CONFIG_NTFS_FS=y/g" .config;
            if [ $? -ne 0 ]; then echo "modify .config faile"; fi
        fi
        if [ ${curPlt} == "3576_android" ]; then
            echo "modify .config for ${curPlt}";
            sed -i "s/# CONFIG_DEVMEM is not set/CONFIG_DEVMEM=y/g" .config;
            if [ $? -ne 0 ]; then echo "modify .config faile"; fi
        fi
        ${build_cmd}
        if [ $? -ne 0 ]; then echo "build faile, cmd: ${config_cmd}"; exit 1; fi
        echo "config cmd: ${config_cmd}"
        echo "build  cmd: ${build_cmd}"
        echo "======> compild kernel done <======"
    fi

    if [ "${build_mod}" == "build_kmod" ]; then
        echo "======> compild rk_vcodec.ko begin <======"
        build_mod_cmd="${m_make} ARCH=${m_arch} -C `pwd` M=`pwd`/drivers/video/rockchip/mpp modules"
        echo "build mod cmd: ${build_mod_cmd}"
        ${build_mod_cmd}
        echo "======> compild rk_vcodec.ko done <======"
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
        rkUT.sh b
    fi

    if [ "${build_mod}" == "build_kmod" ]; then
        echo ""
        echo "======> reload rk_vcodec.ko <======"
        ${adbCmd} push drivers/video/rockchip/mpp/rk_vcodec.ko /sdcard
        if [ -n "`${adbCmd} shell lsmod | grep rk_vcodec`" ]; then
            echo "rmmod old rk_vcodec.ko"
            ${adbCmd} shell rmmod rk_vcodec.ko
        fi
        echo "insmod rk_vcodec.ko"
        ${adbCmd} shell insmod /sdcard/rk_vcodec.ko
    fi
}

adbCmd=$(adbs)
selectNode "6" "pltList" "curPlt" "platform"
gen_cmd
build_kernel_mod
download

set +e
