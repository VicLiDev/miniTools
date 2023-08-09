#!/bin/bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

set -e

display()
{
    echo "Please select arch:"
    echo "  1. android 32"
    echo "  2. android 64"
    echo "  3. linux 32"
    echo "  4. linux 64"
}


display
echo "cur dir: `pwd`"

while [ True ]
do
    read -p "Please select arch or quit(q):" arch

    if [ -n $arch ]; then
        case $arch in
            '1')
                archName="android 32"
                echo "======> selected $archName <======"
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
                else
                    echo "======> build mpp error! <======"
                fi
                break
                ;;
            '2')
                archName="android 64"
                echo "======> selected $archName <======"
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
                else
                    echo "======> build mpp error! <======"
                fi
                break
                ;;
            '3')
                archName="linux 32"
                echo "======> selected $archName <======"
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
                    adb push mpp/librockchip_mpp.so.0 /oem/usr/lib
                    adb push mpp/legacy/librockchip_vpu.so.0 /oem/usr/lib
                    adb push test/mpi_dec_test /oem/usr/bin
                    adb push test/mpi_enc_test /oem/usr/bin
                else
                    echo "======> build mpp error! <======"
                fi
                break
                ;;
            '4')
                archName="linux 64"
                echo "======> selected $archName <======"
                cd `git rev-parse --show-toplevel` \
                    && cd build/linux/aarch64 \
                    && ./make-Makefiles.bash \
                    && make -j

                if [ $? -eq 0 ]; then
                    echo "======> push lib and demo to dev <======"
                    adb push mpp/librockchip_mpp.so.0 /usr/lib64 \
                    adb push mpp/legacy/librockchip_vpu.so.0 /usr/lib64 \
                    adb push test/mpi_dec_test /usr/bin
                else
                    echo "======> build mpp error! <======"
                fi
                break
                ;;
            'q')
                echo "======> quit <======"
                exit 0
                ;;
        esac
    fi
done

set +e
