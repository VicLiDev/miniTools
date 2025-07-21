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
    "lib_android_32"
    "lib_android_64"
    "lib_linux_32"
    "lib_linux_64"
    "lib_linux_x86_64"
    "ko_kmpp_develop_mkf_arm32_one_ko"
    "ko_kmpp_develop_mkf_arm32_multi_ko"
    "ko_kmpp_develop_mkf_arm64_one_ko"
    "ko_kmpp_develop_mkf_arm64_multi_ko"
    "ko_kmpp_develop_cmk_arm32_one_ko"
    "ko_kmpp_develop_cmk_arm32_multi_ko"
    "ko_kmpp_develop_cmk_arm64_one_ko"
    "ko_kmpp_develop_cmk_arm64_multi_ko"
    "ko_kmpp"
    "ko_develop2"
    )

m_sel=""

kdir_lst=(
    "${HOME}/Projects/kernel"
    "${HOME}/Projects/kernel2"
    "${HOME}/Projects/kernel3"
    )

m_sel_kdir=""

linux_toolchain_dir="${HOME}/Projects/prebuilts"

function push_bins_to_device()
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

function build_lib_android_32()
{
    echo "======> selected ${m_sel} <======"
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

function build_lib_android_64()
{
    echo "======> selected ${m_sel} <======"
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

function build_lib_linux_32()
{
    echo "======> selected ${m_sel} <======"
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

function build_lib_linux_64()
{
    echo "======> selected ${m_sel} <======"
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

function build_lib_linux_x86_64()
{
    echo "======> selected ${m_sel} <======"
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

function rmmod_ko()
{
    ko_mod_name="$1"
    if [ -n "`${adbCmd} shell lsmod | grep ${ko_mod_name}`" ]; then
        echo "rmmod old ${ko_mod_name}.ko"
        ${adbCmd} shell rmmod ${ko_mod_name}.ko
    fi
}

function insmod_ko()
{
    ko_mod_name="$1"
    ko_mod_dir="$2"
    echo "insmod ${ko_mod_name}.ko"
    ${adbCmd} shell insmod ${ko_mod_dir}/${ko_mod_name}.ko
}

function push_ko_to_device()
{
    build_sys="$1"
    build_type="$2"
    arch="$3"

    adbCmd=""
    [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
    [ -z "${adbCmd}" ] && exit 0

    f_result=$(${adbCmd} shell 'if [ -f /oem/usr/ko/insmod_ko.sh ]; then echo exists; else echo missing; fi')
    if [[ "${f_result}" == *exists* ]]; then
        echo "mv /oem/usr/ko/insmod_ko.sh /oem/usr/ko/insmod_ko.sh.bak and reboot maybe necessary"
        return
    fi

    if [ "${build_sys}" = "mkf" ]; then
        # test
        ${adbCmd} push ./kmpp_test.ko           /data
        ${adbCmd} push ./kmpi_vsp_test.ko       /data
        ${adbCmd} push ./kmpi_enc_chan_test.ko  /data
        ${adbCmd} push ./kmpi_enc_test.ko       /data
        ${adbCmd} push ./osal_test.ko           /data
        ${adbCmd} push ./kmpp_enc_test.ko       /data
        ${adbCmd} push ./stub_test.ko           /data
        # ko
        if [ "${build_type}" = "multi" ]; then
            ${adbCmd} push ./kmpp_osal.ko /data
            ${adbCmd} push ./kmpp_sys.ko  /data
            ${adbCmd} push ./rk_vcodec.ko /data
        fi
        ${adbCmd} push ./kmpp.ko /data
    elif [ "${build_sys}" = "cmk" ]; then
        # test
        ${adbCmd} push ./test/kmpp_test/build/kmpp_test.ko                   /data
        ${adbCmd} push ./test/kmpi_vsp_test/build/kmpi_vsp_test.ko           /data
        ${adbCmd} push ./test/kmpi_enc_chan_test/build/kmpi_enc_chan_test.ko /data
        ${adbCmd} push ./test/kmpi_enc_test/build/kmpi_enc_test.ko           /data
        ${adbCmd} push ./test/osal_test/build/osal_test.ko                   /data
        ${adbCmd} push ./test/kmpp_enc_test/build/kmpp_enc_test.ko           /data
        ${adbCmd} push ./test/sym_test/sym_test/build/sym_test.ko            /data
        ${adbCmd} push ./test/sym_test/sym1/build/sym1.ko                    /data
        ${adbCmd} push ./test/sym_test/sym2/build/sym2.ko                    /data
        ${adbCmd} push ./test/sym_test/sym3/build/sym3.ko                    /data
        ${adbCmd} push ./test/sym_test/sym4/build/sym4.ko                    /data
        # ko
        if [ "${build_type}" = "multi" ]; then
            ${adbCmd} push ./osal/build/osal.ko             /data
            ${adbCmd} push ./sys/build/sys.ko               /data
            ${adbCmd} push ./mpp_service/build/rk_vcodec.ko /data
        fi
        ${adbCmd} push ./build/kmpp.ko /data
    else
        echo "build sys have not set"
        return
    fi

    # rmmod
    # test
    rmmod_ko stub_test
    rmmod_ko sym_test
    rmmod_ko sym1
    rmmod_ko sym2
    rmmod_ko sym3
    rmmod_ko sym4
    rmmod_ko kmpp_test
    rmmod_ko kmpi_vsp_test
    rmmod_ko kmpi_enc_chan_test
    rmmod_ko kmpi_enc_test
    rmmod_ko osal_test
    rmmod_ko kmpp_enc_test
    # mod
    rmmod_ko kmpp
    rmmod_ko rk_vcodec
    rmmod_ko kmpp_sys
    rmmod_ko kmpp_osal
    rmmod_ko sys
    rmmod_ko osal

    # insmod
    # mod
    if [ "${build_type}" = "multi" ]; then
        if [ "${build_sys}" = "mkf" ]; then
            insmod_ko kmpp_osal /data
            insmod_ko kmpp_sys  /data
            insmod_ko rk_vcodec /data
        elif [ "${build_sys}" = "cmk" ]; then
            insmod_ko osal      /data
            insmod_ko sys       /data
            insmod_ko rk_vcodec /data
        fi
    fi
    insmod_ko kmpp /data
    # test
    # insmod_ko kmpp_test          /data
    # insmod_ko kmpi_vsp_test      /data
    # insmod_ko kmpi_enc_chan_test /data
    # insmod_ko kmpi_enc_test      /data
    # insmod_ko osal_test          /data
    # insmod_ko kmpp_enc_test      /data
    # if [ "${build_sys}" = "mkf" ]; then
    #     insmod_ko stub_test  /data
    # elif [ "${build_sys}" = "cmk" ]; then
    #     insmod_ko sym_test /data
    #     insmod_ko sym1     /data
    #     insmod_ko sym2     /data
    #     insmod_ko sym3     /data
    #     insmod_ko sym4     /data
    # fi
}

function build_ko_kmpp_develop_mkf()
{
    echo "======> selected ${m_sel} <======"
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    cross_cmp="${toolchains}/$(ls -1 ${toolchains} | grep gcc$ | sed 's/gcc//g')"
    m_arch="$1"
    mod_build_type="$2"
    enable_one_ko="y"

    [ ${mod_build_type} = "one" ] && enable_one_ko="y"
    [ ${mod_build_type} = "multi" ] && enable_one_ko="n"

    echo "toolchains:  ${toolchains}"
    echo "make_cmd:    ${make_cmd}"
    echo "kernel dir:  ${m_sel_kdir}"
    echo "cross cmp:   ${cross_cmp}"
    echo "arch:        ${m_arch}"
    echo "module type: ${mod_build_type}"

    # build
    cd `git rev-parse --show-toplevel`
    export BUILD_ONE_KO=${enable_one_ko}
    export KERNEL_DIR=${m_sel_kdir}
    export CROSS_COMPILE=${cross_cmp}
    export ARCH=${m_arch}
    make all

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        # install
        push_ko_to_device "mkf" "${mod_build_type}" "${m_arch}"
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

function build_ko_kmpp_develop_mkf_arm32_one_ko()
{
    build_ko_kmpp_develop_mkf "arm" "one"
}

function build_ko_kmpp_develop_mkf_arm32_multi_ko()
{
    build_ko_kmpp_develop_mkf "arm" "multi"
}

function build_ko_kmpp_develop_mkf_arm64_one_ko()
{
    build_ko_kmpp_develop_mkf "arm64" "one"
}

function build_ko_kmpp_develop_mkf_arm64_multi_ko()
{
    build_ko_kmpp_develop_mkf "arm64" "multi"
}

function build_ko_kmpp_develop_cmk()
{
    echo "======> selected ${m_sel} <======"
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    m_arch="$1"
    mod_build_type="$2"
    build_wk_dir=""

    echo "toolchains:  ${toolchains}"
    echo "make_cmd:    ${make_cmd}"
    echo "kernel dir:  ${m_sel_kdir}"
    echo "arch:        ${m_arch}"
    echo "module type: ${mod_build_type}"

    # build
    [ ${m_arch} = "arm" ]   && build_wk_dir="build/arm"
    [ ${m_arch} = "arm64" ] && build_wk_dir="build/aarch64"
    export MODULE_TYPE=${mod_build_type}
    cd `git rev-parse --show-toplevel` \
        && cd ${build_wk_dir} \
        && ./make-Kbuild.sh --kernel ${m_sel_kdir} \
            --toolchain ${toolchains}

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        # install
        push_ko_to_device "cmk" "${mod_build_type}" "${m_arch}"
    else
        echo "======> build mpp error! <======"
        return 1
    fi
}

function build_ko_kmpp_develop_cmk_arm32_one_ko()
{
    build_ko_kmpp_develop_cmk "arm" "one"
}

function build_ko_kmpp_develop_cmk_arm32_multi_ko()
{
    build_ko_kmpp_develop_cmk "arm" "multi"
}

function build_ko_kmpp_develop_cmk_arm64_one_ko()
{
    build_ko_kmpp_develop_cmk "arm64" "one"
}

function build_ko_kmpp_develop_cmk_arm64_multi_ko()
{
    build_ko_kmpp_develop_cmk "arm64" "multi"
}

# 5.10 1106_linux
function build_ko_kmpp()
{
    echo "======> selected ${m_sel} <======"
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

function build_ko_develop2()
{
    echo "======> selected ${m_sel} <======"
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
    select_node "${sel_tag_mpp}" "plt_lst" "m_sel" "platform"
else
    m_sel="${plt_lst[${cmd_sel_plt}]}"
fi
build_${m_sel}


# set +e
