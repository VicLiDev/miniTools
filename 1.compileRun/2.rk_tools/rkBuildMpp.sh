#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

# set -e

sel_tag_mpp="rk_mpp_b: "
sel_tag_mpp_ko="rk_mpp_ko_b: "

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    "ko_develop2"
    "ko_kmpp_develop"
    "ko_kmpp"
    )

mSelectedArch=""

kdirList=(
    "${HOME}/Projects/kernel"
    "${HOME}/Projects/kernel2"
    "${HOME}/Projects/kernel3"
    )

mSelectedKdir=""

linux_toolchain_dir="${HOME}/Projects/prebuilts"

push_bins_to_device()
{
    adbCmd="$1"
    file_dir="$2"
    device_dir="$3"

    ${adbCmd} shell "ls -d ${device_dir} > /dev/null 2>&1"
    if [ "$?" -ne "0" ]; then echo "Error: device dir not exist: ${device_dir}"; return; fi

    if [ -d "${file_dir}" ]; then
        for cur_bin_file in `find ${file_dir} -maxdepth 1 -type f -executable`
        do
            if [ ! -e ${cur_bin_file} ]; then continue; fi

            echo "==> push <${cur_bin_file}> to device <${device_dir}>"
            ${adbCmd} push ${cur_bin_file} ${device_dir}
        done
    elif [ -f "${file_dir}" ]; then
        if [ ! -e ${file_dir} ]; then continue; fi

        echo "==> push <${file_dir}> to device <${device_dir}>"
        ${adbCmd} push ${file_dir} ${device_dir}
    else
        echo "Error: adbCmd:${adbCmd} file_dir:${file_dir} device_dir:${device_dir}"
    fi
}

build_android_32()
{
    echo "======> selected ${mSelectedArch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/arm \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)
        if [ -z "${adbCmd}" ]; then exit 0; fi

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
    fi
}

build_android_64()
{
    echo "======> selected ${mSelectedArch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/aarch64 \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)
        if [ -z "${adbCmd}" ]; then exit 0; fi

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
    fi
}

build_linux_32()
{
    echo "======> selected ${mSelectedArch} <======"
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
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)
        if [ -z "${adbCmd}" ]; then exit 0; fi

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
    fi
}

build_linux_64()
{
    echo "======> selected ${mSelectedArch} <======"
    linux_64_tc_dir="${linux_toolchain_dir}/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"
    linux_64_tc="${linux_64_tc_dir}/bin/aarch64-none-linux-gnu-"
    echo "toolchain: ${linux_64_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/aarch64 \
        && ./make-Makefiles.bash --toolchain "${linux_64_tc}" \
        && make -j
    echo "toolchain: ${linux_64_tc}"

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)
        if [ -z "${adbCmd}" ]; then exit 0; fi

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
    fi
}

build_linux_x86_64()
{
    echo "======> selected ${mSelectedArch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/x86_64 \
        && ./make-Makefiles.bash

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
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
    echo "======> selected ${mSelectedArch} <======"
    selectNode "${sel_tag_mpp_ko}" "kdirList" "mSelectedKdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${mSelectedKdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    cd `git rev-parse --show-toplevel` \
        && cd build/kmpp/aarch64 \
        && ./make-Kbuild.sh --kernel ${mSelectedKdir} \
            --toolchain ${toolchains} --ndk ${toolchains}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
    fi
}

build_ko_kmpp_develop()
{
    echo "======> selected ${mSelectedArch} <======"
    selectNode "${sel_tag_mpp_ko}" "kdirList" "mSelectedKdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${mSelectedKdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    cd `git rev-parse --show-toplevel` \
        && cd build/aarch64 \
        && ./make-Kbuild.sh --kernel ${mSelectedKdir} \
            --toolchain ${toolchains} --ndk ${toolchains}

    # install
    adbCmd=$(adbs)
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

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
    fi
}

# 5.10 1106_linux
build_ko_kmpp()
{
    echo "======> selected ${mSelectedArch} <======"
    selectNode "${sel_tag_mpp_ko}" "kdirList" "mSelectedKdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${mSelectedKdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    # build
    kmpp_build_cmd="${make_cmd} ARCH=arm -C ${mSelectedKdir} M=`pwd` modules"
    echo "kmpp_build_cmd: ${kmpp_build_cmd}"
    export PATH=${toolchains}:${PATH}
    cd `git rev-parse --show-toplevel` \
        && ${kmpp_build_cmd}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp error! <======"
    fi
}


cur_br=`git branch --show-current`
echo "cur branch: $cur_br"
prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.select_node.sh
selectNode "${sel_tag_mpp}" "pltList" "mSelectedArch" "platform"
build_${mSelectedArch}


# set +e
