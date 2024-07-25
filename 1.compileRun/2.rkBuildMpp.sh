#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

set -e

sel_tag_mpp="rk_mpp_b: "

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    )

mSelectedArch=""

build_android_32()
{
    echo "======> selected ${mSelectedArch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/arm \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adbCmd=$(adbs)
        ${adbCmd} push mpp/libmpp.so /vendor/lib
        ${adbCmd} push mpp/legacy/libvpu.so /vendor/lib
        ${adbCmd} push mpp/vproc/iep2/test/iep2_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_test /vendor/bin/
        ${adbCmd} push test/mpi_enc_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_mt_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_multi_test /vendor/bin/
        ${adbCmd} push test/mpi_enc_mt_test /vendor/bin/

        ${adbCmd} push mpp/libmpp.so /system/lib/
        ${adbCmd} push mpp/legacy/libvpu.so /system/lib/
        # ${adbCmd} push mpp/vproc/iep2/test/iep2_test /system/bin/
        # ${adbCmd} push test/mpi_dec_test /system/bin/
        # ${adbCmd} push test/mpi_enc_test /system/bin/
        # ${adbCmd} push test/mpi_dec_mt_test /system/bin/
        # ${adbCmd} push test/mpi_dec_multi_test /system/bin/
        # ${adbCmd} push test/mpi_enc_mt_test /system/bin/
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
        ${adbCmd} push mpp/libmpp.so /vendor/lib64
        ${adbCmd} push mpp/legacy/libvpu.so /vendor/lib64
        ${adbCmd} push mpp/vproc/iep2/test/iep2_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_test /vendor/bin/
        ${adbCmd} push test/mpi_enc_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_mt_test /vendor/bin/
        ${adbCmd} push test/mpi_dec_multi_test /vendor/bin/
        ${adbCmd} push test/mpi_enc_mt_test /vendor/bin/

        ${adbCmd} push mpp/libmpp.so /system/lib64
        ${adbCmd} push mpp/legacy/libvpu.so /system/lib64
        # ${adbCmd} push mpp/vproc/iep2/test/iep2_test /system/bin/
        # ${adbCmd} push test/mpi_dec_test /system/bin/
        # ${adbCmd} push test/mpi_enc_test /system/bin/
        # ${adbCmd} push test/mpi_dec_mt_test /system/bin/
        # ${adbCmd} push test/mpi_dec_multi_test /system/bin/
        # ${adbCmd} push test/mpi_enc_mt_test /system/bin/
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
        ${adbCmd} push mpp/librockchip_mpp.so.0 /usr/lib
        ${adbCmd} push mpp/legacy/librockchip_vpu.so.0 /usr/lib
        ${adbCmd} push test/mpi_dec_test /usr/bin
        ${adbCmd} push test/mpi_enc_test /usr/bin
        ${adbCmd} push test/mpi_dec_mt_test /usr/bin/
        ${adbCmd} push test/mpi_dec_multi_test /usr/bin/
        ${adbCmd} push test/mpi_enc_mt_test /usr/bin/
        ${adbCmd} push mpp/librockchip_mpp.so.0 /oem/usr/lib
        ${adbCmd} push mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        ${adbCmd} push test/mpi_dec_test /oem/usr/bin
        ${adbCmd} push test/mpi_enc_test /oem/usr/bin
        ${adbCmd} push test/mpi_dec_mt_test /oem/usr/bin/
        ${adbCmd} push test/mpi_dec_multi_test /oem/usr/bin/
        ${adbCmd} push test/mpi_enc_mt_test /oem/usr/bin/
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
        ${adbCmd} push mpp/librockchip_mpp.so.0 /usr/lib64
        ${adbCmd} push mpp/legacy/librockchip_vpu.so.0 /usr/lib64
        ${adbCmd} push test/mpi_dec_test /usr/bin
        ${adbCmd} push test/mpi_enc_test /usr/bin
        ${adbCmd} push test/mpi_dec_mt_test /usr/bin/
        ${adbCmd} push test/mpi_dec_multi_test /usr/bin/
        ${adbCmd} push test/mpi_enc_mt_test /usr/bin/
        ${adbCmd} push mpp/librockchip_mpp.so.0 /oem/usr/lib
        ${adbCmd} push mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        ${adbCmd} push test/mpi_dec_test /oem/usr/bin
        ${adbCmd} push test/mpi_enc_test /oem/usr/bin
        ${adbCmd} push test/mpi_dec_mt_test /oem/usr/bin/
        ${adbCmd} push test/mpi_dec_multi_test /oem/usr/bin/
        ${adbCmd} push test/mpi_enc_mt_test /oem/usr/bin/
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



source $(dirname $(readlink -f $0))/0.select_node.sh
selectNode "${sel_tag_mpp}" "pltList" "mSelectedArch" "platform"
build_${mSelectedArch}


set +e
