#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

# set -e

cmd_sel_plt=""
cmd_install="true"
cmd_ins_dev=""

sel_tag_mpp="rk_mpp_b: "
sel_tag_mpp_ko="rk_mpp_ko_b: "

plt_lst=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    "ko_develop2"
    "ko_kmpp_develop"
    "ko_kmpp"
    )

m_sel_arch=""

kdir_lst=(
    "${HOME}/Projects/kernel"
    "${HOME}/Projects/kernel2"
    "${HOME}/Projects/kernel3"
    )

m_sel_kdir=""

linux_toolchain_dir="${HOME}/Projects/prebuilts"

push_bins_to_device()
{
    adbCmd="$1"
    file_dir="$2"
    device_dir="$3"

    ${adbCmd} shell "ls -d ${device_dir} > /dev/null 2>&1"
    [ "$?" -ne "0" ] && { echo "Error: device dir not exist: ${device_dir}"; return; }

    if [ -d "${file_dir}" ]; then
        for cur_bin_file in `find ${file_dir} -maxdepth 1 -type f -executable`
        do
            [ ! -e ${cur_bin_file} ] && continue

            echo "==> push <${cur_bin_file}> to device <${device_dir}>"
            ${adbCmd} push ${cur_bin_file} ${device_dir}
        done
    elif [ -f "${file_dir}" ]; then
        [ ! -e ${file_dir} ] && continue

        echo "==> push <${file_dir}> to device <${device_dir}>"
        ${adbCmd} push ${file_dir} ${device_dir}
    else
        echo "Error: adbCmd:${adbCmd} file_dir:${file_dir} device_dir:${device_dir}"
    fi
}

build_android_32()
{
    echo "======> selected ${m_sel_arch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/arm \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_to_device "${adbCmd}" mpp/libmpp.so /vendor/lib
        push_bins_to_device "${adbCmd}" mpp/legacy/libvpu.so /vendor/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /vendor/bin
        push_bins_to_device "${adbCmd}" test /vendor/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /vendor/bin

        push_bins_to_device "${adbCmd}" mpp/libmpp.so /system/lib/
        push_bins_to_device "${adbCmd}" mpp/legacy/libvpu.so /system/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /system/bin
        push_bins_to_device "${adbCmd}" test /system/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /system/bin
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

build_android_64()
{
    echo "======> selected ${m_sel_arch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/aarch64 \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_to_device "${adbCmd}" mpp/libmpp.so /vendor/lib64
        push_bins_to_device "${adbCmd}" mpp/legacy/libvpu.so /vendor/lib64
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /vendor/bin
        push_bins_to_device "${adbCmd}" test /vendor/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /vendor/bin

        push_bins_to_device "${adbCmd}" mpp/libmpp.so /system/lib64
        push_bins_to_device "${adbCmd}" mpp/legacy/libvpu.so /system/lib64
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /system/bin
        push_bins_to_device "${adbCmd}" test /system/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /system/bin
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

build_linux_32()
{
    echo "======> selected ${m_sel_arch} <======"
    linux_32_tc_dir="${linux_toolchain_dir}/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf"
    linux_32_tc="${linux_32_tc_dir}/bin/arm-linux-gnueabihf-"
    echo "toolchain: ${linux_32_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/arm \
        && sed -i "s/#SET(CMAKE_SYSTEM_PROCESSOR \"armv7-a_hardfp\")/SET(CMAKE_SYSTEM_PROCESSOR \"armv7-a_hardfp\")/g" arm.linux.cross.cmake \
        && ./make-Makefiles.bash --toolchain "${linux_32_tc}" \
        && make -j
    echo "toolchain: ${linux_32_tc}"

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so   /usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.1 /usr/lib
        push_bins_to_device "${adbCmd}" mpp/legacy/librockchip_vpu.so.0 /usr/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /usr/bin
        push_bins_to_device "${adbCmd}" test /usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /usr/bin

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so   /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.1 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /oem/usr/bin
        push_bins_to_device "${adbCmd}" test /oem/usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /oem/usr/bin
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

build_linux_64()
{
    echo "======> selected ${m_sel_arch} <======"
    linux_64_tc_dir="${linux_toolchain_dir}/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"
    linux_64_tc="${linux_64_tc_dir}/bin/aarch64-none-linux-gnu-"
    echo "toolchain: ${linux_64_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/aarch64 \
        && ./make-Makefiles.bash --toolchain "${linux_64_tc}" \
        && make -j
    echo "toolchain: ${linux_64_tc}"

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /usr/lib64
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so   /usr/lib64
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.1 /usr/lib64
        push_bins_to_device "${adbCmd}" mpp/legacy/librockchip_vpu.so.0 /usr/lib64
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /usr/bin
        push_bins_to_device "${adbCmd}" test /usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /usr/bin

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so   /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.1 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /oem/usr/bin
        push_bins_to_device "${adbCmd}" test /oem/usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /oem/usr/bin
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

build_linux_x86_64()
{
    echo "======> selected ${m_sel_arch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/x86_64 \
        && ./make-Makefiles.bash

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

rmmod_ko()
{
    ko_mod_name="$1"
    if [ -n "`${adbCmd} shell lsmod | grep ${ko_mod_name}`" ]; then
        echo "rmmod old ${ko_mod_name}.ko"
        ${adbCmd} shell rmmod ${ko_mod_name}.ko
    fi
}

insmod_ko()
{
    ko_mod_name="$1"
    ko_mod_dir="$2"
    echo "insmod ${ko_mod_name}.ko"
    ${adbCmd} shell insmod ${ko_mod_dir}/${ko_mod_name}.ko
}

build_ko_develop2()
{
    echo "======> selected ${m_sel_arch} <======"
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    cd `git rev-parse --show-toplevel` \
        && cd build/kmpp/aarch64 \
        && ./make-Kbuild.sh --kernel ${m_sel_kdir} \
            --toolchain ${toolchains} --ndk ${toolchains}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

build_ko_kmpp_develop()
{
    echo "======> selected ${m_sel_arch} <======"
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    cd `git rev-parse --show-toplevel` \
        && cd build/aarch64 \
        && ./make-Kbuild.sh --kernel ${m_sel_kdir} \
            --toolchain ${toolchains} --ndk ${toolchains}

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        # install
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        ${adbCmd} push sys/build/sys.ko                            /data
        ${adbCmd} push osal/build/osal.ko                          /data
        ${adbCmd} push mpp_service/build/kmpp.ko                   /data
        ${adbCmd} push test/sym_test/sym4/build/sym4.ko            /data
        ${adbCmd} push test/sym_test/sym1/build/sym1.ko            /data
        ${adbCmd} push test/sym_test/sym3/build/sym3.ko            /data
        ${adbCmd} push test/sym_test/sym2/build/sym2.ko            /data
        ${adbCmd} push test/osal_test/build/osal_test.ko           /data
        ${adbCmd} push test/kmpi_enc_test/build/kmpi_enc_test.ko   /data
        ${adbCmd} push test/kmpp_enc_test/build/kmpp_enc_test.ko   /data
        ${adbCmd} push test/kmpp_test/build/kmpp_test.ko           /data
        ${adbCmd} push test/sym_test/sym_test/build/sym_test.ko    /data

        # rmmod_ko kmpi_enc_test
        # rmmod_ko kmpp_enc_test
        # rmmod_ko kmpp_test
        # rmmod_ko sym_test
        # rmmod_ko osal_test
        rmmod_ko sym1
        rmmod_ko sym3
        rmmod_ko sym2
        rmmod_ko sym4
        rmmod_ko kmpp
        rmmod_ko sys
        rmmod_ko osal

        insmod_ko osal           /data
        insmod_ko sys            /data
        insmod_ko kmpp           /data
        insmod_ko sym4           /data
        insmod_ko sym3           /data
        insmod_ko sym2           /data
        insmod_ko sym1           /data
        # insmod_ko osal_test      /data
        # insmod_ko sym_test       /data
        # insmod_ko kmpp_test      /data
        # insmod_ko kmpp_enc_test  /data
        # insmod_ko kmpi_enc_test  /data
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

# 5.10 1106_linux
build_ko_kmpp()
{
    echo "======> selected ${m_sel_arch} <======"
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    kmpp_build_cmd="${make_cmd} ARCH=arm -C ${m_sel_kdir} M=`pwd` modules"
    echo "kmpp_build_cmd: ${kmpp_build_cmd}"
    export PATH=${toolchains}:${PATH}
    cd `git rev-parse --show-toplevel` \
        && ${kmpp_build_cmd}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

function usage()
{
    echo "usage: $0 [-p|--plt 0...n] [-i|--install \"true\"|\"false\"] [-d|--dev install_dev_idx]"
}

function proc_paras()
{
    # 双中括号提供了针对字符串比较的高级特性，使用双中括号 [[ ]] 进行字符串比较时，
    # 可以把右边的项看做一个模式，故而可以在 [[ ]] 中使用正则表达式：
    # if [[ hello == hell* ]]; then
    #
    # 位置参数可以用shift命令左移。比如shift 3表示原来的$4现在变成$1，原来的$5现在变成
    # $2等等，原来的$1、$2、$3丢弃，$0不移动。不带参数的shift命令相当于shift 1。

    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--help)
                usage
                exit 0
                ;;
            -p|--plt)
                cmd_sel_plt="$2"
                shift # move to next para
                ;;
            -i|--install)
                cmd_install="$2"
                shift # move to next para
                ;;
            -d|--dev)
                cmd_ins_dev="$2"
                shift # move to next para
                ;;
            *)
                # unknow para
                echo "unknow para: ${key}"
                usage
                exit 1
                ;;
        esac
        shift # move to next para
    done

    # print result
    echo "======> cmd paras <======"
    echo "cmd_sel_plt : ${cmd_sel_plt}"
    echo "cmd_install : ${cmd_install}"
    echo "cmd_ins_dev : ${cmd_ins_dev}"
    echo
}



cur_br=`git branch --show-current`
echo "cur branch: $cur_br"
prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.select_node.sh

proc_paras $@

if [ -z "${cmd_sel_plt}" ]; then
    select_node "${sel_tag_mpp}" "plt_lst" "m_sel_arch" "platform"
else
    m_sel_arch="${plt_lst[${cmd_sel_plt}]}"
fi
build_${m_sel_arch}


# set +e
