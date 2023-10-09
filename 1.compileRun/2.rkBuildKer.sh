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
    "3399_linux_5.10"
    "3568_linux_4.19"
    "3588_linux_5.10"
    )

display()
{
    loop=0
    for curPlt in ${pltList[@]}
    do
        echo "${loop}. ${curPlt}"
        loop=`expr $loop + 1`
    done
}

display

echo "cur dir: `pwd`"

while [ True ]
do
    read -p "Please select platform or quit(q):" pltIdx
    if [ "${pltIdx}" == "q" ]; then
        echo "======> quit <======"
        exit 0
    elif [[ -n $pltIdx && -z `echo $pltIdx | sed 's/[0-9]//g'` ]]; then
        curPlt=${pltList[${pltIdx}]}
        echo "--> selected plt:${curPlt}, index:${pltIdx}"
    else
        curPlt=""
        echo "--> please input num in scope 0-`expr ${#pltList[@]} - 1`"
        continue
    fi


    if [ -n ${curPlt} ]
    then
        case ${curPlt} in
            '1109/1126_android')
                echo "======> selected ${curPlt} <======"
                # make ARCH=arm rockchip_defconfig \
                make ARCH=arm rv1126_defconfig \
                    && make ARCH=arm rv1126-evb-ddr3-v13.img -j24
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3288_android')
                echo "======> selected ${curPlt} <======"
                make ARCH=arm rockchip_defconfig \
                    && make ARCH=arm rk3288-evb-android-rk808-edp.img -j16
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3328_android')
                echo "======> selected ${curPlt} <======"
                make ARCH=arm64 rockchip_defconfig \
                    && make rk3328-evb-android-avb.img ARCH=arm64 BOOT_IMG=./boot_rk3328EVB.img -j20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3399_android')
                echo "======> selected ${curPlt} <======"
                make ARCH=arm64 rockchip_defconfig android-11.config disable_incfs.config \
                    && make ARCH=arm64 BOOT_IMG=./boot_sample.img rk3399-evb-ind-lpddr4-android-avb.img -j20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3568_android')
                echo "======> selected ${curPlt} <======"
                make ARCH=arm64 rockchip_defconfig rk356x.config android-11.config \
                    && make ARCH=arm64 rk3566-evb1-ddr4-v10.img BOOT_IMG=boot1.img -j20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3588_android')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/linux-x86/clang-r416183b/bin:$PATH
                msk='make CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1'

                ${msk} ARCH=arm64 rockchip_defconfig android-11.config \
                    && ${msk} ARCH=arm64 BOOT_IMG=./boot_3588.img rk3588-evb1-lp4-v10.img -j20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3399_linux_5.10')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-

                make ARCH=arm64 rockchip_linux_defconfig \
                    && make ARCH=arm64 rk3399-evb-ind-lpddr4-linux.img -j 20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3568_linux_4.19')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-

                make ARCH=arm64 rockchip_linux_defconfig \
                    && make ARCH=arm64 rk3568-evb1-ddr4-v10-linux.img -j 20
                echo "======> selected ${curPlt} compile done <======"
                break
                ;;
            '3588_linux_5.10')
                echo "======> selected ${curPlt} <======"
                # 根据 build.sh 按照本地环境修改
                export PATH=/home/lhj/Projects/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin:$PATH
                export CROSS_COMPILE=aarch64-none-linux-gnu-

                make ARCH=arm64 rockchip_linux_defconfig \
                    && make ARCH=arm64 rk3588-evb1-lp4-v10.img -j 20
                echo "======> selected ${curPlt} compile done <======"
                break
                break
                ;;
        esac
    fi
done

echo "======> copy boot.img to ~/test <======"
echo "cur dir: `pwd`"
cp boot.img ~/test

echo "======> download boot.img <======"
rkUT.sh b

set +e
