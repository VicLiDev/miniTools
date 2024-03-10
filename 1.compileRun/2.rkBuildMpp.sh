#!/bin/bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

set -e

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    )

mSelectedArch=""

display()
{
    echo "Please select platform:"
    for ((i = 0; i < ${#pltList[@]}; i++))
    do
        echo "  ${i}. ${pltList[${i}]}"
    done
}

selectPlt()
{
    display
    echo "cur dir: `pwd`"

    defPltIdx=0
    while [ True ]
    do
        read -p "Please select platform or quit(q), def[${defPltIdx}]:" pltIdx
        pltIdx=${pltIdx:-${defPltIdx}}

        if [ "${pltIdx}" == "q" ]; then
            echo "======> quit <======"
            exit 0
        elif [[ -n "${pltIdx}" && -z `echo ${pltIdx} | sed 's/[0-9]//g'` ]]; then
            mSelectedArch=${pltList[${pltIdx}]}
            echo "--> selected index:${pltIdx}, plt:${mSelectedArch}"
            break
        else
            curPlt=""
            echo "--> please input num in scope 0-`expr ${#pltList[@]} - 1`"
            continue
        fi
    done
}

build_android_32()
{
    echo "======> selected ${mSelectedArch} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/arm \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        echo "======> push lib and demo to dev <======"
        adb push mpp/libmpp.so /vendor/lib
        adb push mpp/legacy/libvpu.so /vendor/lib
        adb push mpp/vproc/iep2/test/iep2_test /vendor/bin/
        adb push test/mpi_dec_test /vendor/bin/
        adb push test/mpi_enc_test /vendor/bin/
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
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
        adb push mpp/libmpp.so /vendor/lib64
        adb push mpp/legacy/libvpu.so /vendor/lib64
        adb push mpp/vproc/iep2/test/iep2_test /vendor/bin/
        adb push test/mpi_dec_test /vendor/bin/
        adb push test/mpi_enc_test /vendor/bin/
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
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
        adb push mpp/librockchip_mpp.so.0 /usr/lib
        adb push mpp/legacy/librockchip_vpu.so.0 /usr/lib
        adb push test/mpi_dec_test /usr/bin
        adb push test/mpi_enc_test /usr/bin
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
        adb push mpp/librockchip_mpp.so.0 /oem/usr/lib
        adb push mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        adb push test/mpi_dec_test /oem/usr/bin
        adb push test/mpi_enc_test /oem/usr/bin
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
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
        adb push mpp/librockchip_mpp.so.0 /usr/lib64
        adb push mpp/legacy/librockchip_vpu.so.0 /usr/lib64
        adb push test/mpi_dec_test /usr/bin
        adb push test/mpi_enc_test /usr/bin
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
        adb push mpp/librockchip_mpp.so.0 /oem/usr/lib
        adb push mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
        adb push test/mpi_dec_test /oem/usr/bin
        adb push test/mpi_enc_test /oem/usr/bin
        adb push test/mpi_dec_mt_test /vendor/bin/
        adb push test/mpi_dec_multi_test /vendor/bin/
        adb push test/mpi_enc_mt_test /vendor/bin/
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



selectPlt
build_${mSelectedArch}


set +e
