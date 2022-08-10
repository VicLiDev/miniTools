#!/bin/bash

set -e

display()
{
    echo "Please select platform:"
    echo "  1. 1109/1126"
    echo "  2. 3399"
    echo "  3. 3568"
    echo "  4. 3588"
    echo "  5. 3328"
    echo "  6. 3288"
    echo "  7. 3399 linux 5.10"
}

display

echo "cur dir: `pwd`"

while [ True ]
do
    read -p "Please select platform or quit(q):" platform

    if [ -n $platform ]
    then
        case $platform in
            '1')
                platformNmae="1109/1126"
                echo "======> selected $platformNmae <======"
                make ARCH=arm rv1126_defconfig \
                    && make ARCH=arm rv1126-evb-ddr3-v13.img -j24
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '2')
                platformNmae="3399"
                echo "======> selected $platformNmae <======"
                make ARCH=arm64 rockchip_defconfig android-11.config disable_incfs.config \
                    && make ARCH=arm64 BOOT_IMG=./boot_sample.img rk3399-evb-ind-lpddr4-android-avb.img -j20
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '3')
                platformNmae="3568"
                echo "======> selected $platformNmae <======"
                make ARCH=arm64 rockchip_defconfig rk356x.config android-11.config \
                    && make ARCH=arm64 rk3566-evb1-ddr4-v10.img BOOT_IMG=boot1.img -j20
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '4')
                platformNmae="3588"
                echo "======> selected $platformNmae <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/linux-x86/clang-r416183b/bin:$PATH
                msk='make CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1'

                ${msk} ARCH=arm64 rockchip_defconfig android-11.config \
                    && ${msk} ARCH=arm64 BOOT_IMG=./boot_3588.img rk3588-evb1-lp4-v10.img -j20
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '5')
                platformNmae="3328"
                echo "======> selected $platformNmae <======"
                make ARCH=arm64 rockchip_defconfig \
                    && make rk3328-evb-android-avb.img ARCH=arm64 BOOT_IMG=./boot_rk3328EVB.img -j20
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '6')
                platformNmae="3288"
                echo "======> selected $platformNmae <======"
                make ARCH=arm rockchip_defconfig \
                    && make ARCH=arm rk3288-evb-android-rk808-edp.img -j16
                echo "======> selected $platformNmae compile done <======"
                break
                ;;
            '7')
                platformNmae="3399 linux 5.10"
                echo "======> selected $platformNmae <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-

                make ARCH=arm64 rockchip_linux_defconfig \
                    && make ARCH=arm64 rk3399-evb-ind-lpddr4-linux.img -j 20
                echo "======> selected $platformNmae compile done <======"
                break
                ;;

            'q')
                echo "======> quit <======"
                exit 0
                ;;
        esac
    fi
done

echo "======> copy boot.img to ~/test <======"
echo "cur dir: `pwd`"
cp boot.img ~/test

echo "======> download boot.img <======"
rkut.sh b

set +e
