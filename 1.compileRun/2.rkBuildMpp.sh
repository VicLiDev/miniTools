#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

set -e

sel_tag_mpp="rk_mpp_b: "
sel_tag_mpp_ko="rk_mpp_ko_b: "

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    )

mSelectedArch=""

kdirList=(
    "${HOME}/Projects/kernel"
    "${HOME}/Projects/kernel2"
    "${HOME}/Projects/kernel3"
    )

mSelectedKdir=""

push_bins_to_device()
{
    adbCmd="$1"
    file_dir="$2"
    device_dir="$3"

    ${adbCmd} shell "ls -d ${device_dir} > /dev/null 2>&1"
    if [ "$?" -ne "0" ]; then echo "Error: device dir not exist: ${device_dir}"; exit; fi

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
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/arm \
        && ./make-Makefiles.bash \
        && make -j

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /usr/lib
        push_bins_to_device "${adbCmd}" push mpp/legacy/librockchip_vpu.so.0 /usr/lib
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /usr/bin
        push_bins_to_device "${adbCmd}" test /usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /usr/bin

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /oem/usr/lib
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
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/aarch64 \
        && ./make-Makefiles.bash \
        && make -j

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /usr/lib64
        push_bins_to_device "${adbCmd}" push mpp/legacy/librockchip_vpu.so.0 /usr/lib64
        push_bins_to_device "${adbCmd}" mpp/vproc/iep2/test/iep2_test /usr/bin
        push_bins_to_device "${adbCmd}" test /usr/bin
        push_bins_to_device "${adbCmd}" mpp/base/test /usr/bin

        push_bins_to_device "${adbCmd}" mpp/librockchip_mpp.so.0 /oem/usr/lib
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



cur_br=`git branch --show-current`
echo "cur branch: $cur_br"
source $(dirname $(readlink -f $0))/../0.general_tools/0.select_node.sh
if [ "${cur_br}" == "develop" ]; then
    selectNode "${sel_tag_mpp}" "pltList" "mSelectedArch" "platform"
    build_${mSelectedArch}
elif [ "${cur_br}" == "develop2" ]; then
    selectNode "${sel_tag_mpp_ko}" "kdirList" "mSelectedKdir" "kernel dir"

    info_list=`echo -e "\n\n" | bash ~/bin/rkBuildKer.sh --dir ${mSelectedKdir} --env \
        | grep -E "toolchains|m_make"`
    toolchains="`echo -e ${info_list} | awk '{print $2}'`"
    make_cmd=${info_list#*m_make: }
    echo "toolchains: ${toolchains}"
    echo "make_cmd: ${make_cmd}"

    cd `git rev-parse --show-toplevel` \
        && cd build/kmpp/aarch64 \
        && ./make-Kbuild.sh --kernel ${mSelectedKdir} \
            --toolchain ${toolchains} --ndk ${toolchains}
fi


set +e
