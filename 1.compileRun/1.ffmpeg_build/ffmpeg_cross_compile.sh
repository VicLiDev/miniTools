#!/usr/bin/env bash
#########################################################################
# File Name: ffmpeg_cross_compile.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 30 May 2024 02:14:53 PM CST
#########################################################################

RootDir=`pwd`

ffmpeg_cmpile_linux_aarch64()
{
    create_dir build_linux_aarch64
    cd build_linux_aarch64

    TOOLCHAIN_ROOT=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
    CROSS_PREFIX=$TOOLCHAIN_ROOT/bin/aarch64-none-linux-gnu-

    ../configure \
        --prefix="${PWD}/ffmpeg_out" \
        --arch=aarch64 \
        --cross-prefix=$CROSS_PREFIX \
        --enable-cross-compile \
        --target-os=linux
    # 诸多编译工具都可以单独设置：
    # --nm
    # --ar=AR
    # --as=AS
    # --strip=STRIP
    # --cc=CC
    # --cxx=CXX
    # --ld=LD

    make -j 20 && make install
}


ffmpeg_cmpile_android()
{
    NDK="${HOME}/work/android/ndk/android-ndk-r25c"
    TOOLCHAINS="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"

    cfg_arch_append=""

    cd ${RootDir}

    # Only choose one of these, depending on your device...
    if [ "$1" == "arm" ]; then
        create_dir build_android_arm && cd build_android_arm
        export TARGET=armv7a-linux-androideabi
        TARGET_ARCH=armv7-a
        cfg_arch_append=""
    elif [ "$1" == "aarch64" ]; then
        create_dir build_android_aarch64 && cd build_android_aarch64
        export TARGET=aarch64-linux-android
        TARGET_ARCH=armv8
        # 汇编的支持存在问题，需要disable掉
        cfg_arch_append="
            --disable-x86asm
            --disable-inline-asm
            --disable-asm
            "
    fi

    # Set this to your minSdkVersion.
    export API=21

    # 设置工具链和架构
    CROSS_PREFIX=${TOOLCHAINS}/bin/${TARGET}${API}-

    # 设置FFmpeg源代码路径和输出路径
    FFMPEG_OUTPUT="${PWD}/ffmpeg_out"

    # 清除之前的构建
    rm -rf ${FFMPEG_OUTPUT}
    mkdir -p ${FFMPEG_OUTPUT}

    config=(
        --prefix=${FFMPEG_OUTPUT}
        --target-os=android
        --arch=${TARGET_ARCH}
        --cpu=${TARGET_ARCH}
        --enable-cross-compile
        --disable-shared
        --enable-static
        --disable-doc
        --disable-ffplay
        --disable-ffprobe
        --disable-avdevice
        --disable-symver
        --enable-gpl
        --cross-prefix=${CROSS_PREFIX}
        --ar=${TOOLCHAINS}/bin/llvm-ar
        --nm=${TOOLCHAINS}/bin/llvm-nm
        --ranlib=${TOOLCHAINS}/bin/llvm-ranlib
        --strip=${TOOLCHAINS}/bin/llvm-strip
        # --enable-libass
        # --enable-libfreetype
        # --enable-libfontconfig
        # --enable-libfribidi
        # --enable-libharfbuzz
        # --enable-libmp3lame
        # --enable-libopus
        # --enable-libtheora
        # --enable-libvorbis
        # --enable-libvpx
        # --enable-libx264
        # --enable-libxvid
        # --sysroot=$SYSROOT
        # --extra-cflags="-I$SYSROOT/usr/include"
        # --extra-ldflags="-L$SYSROOT/usr/lib -pie"
        ${cfg_arch_append}
    )

    # echo "${config[@]}"
    # 配置FFmpeg，由于ar，nm等的前缀与clang不一样，所以需要单独指定一下
    ../configure ${config[@]}

    # 编译FFmpeg
    make -j20

    # 安装FFmpeg（如果需要）
    make install
}


prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.dir_file_opt.sh

ffmpeg_cmpile_linux_aarch64
ffmpeg_cmpile_android arm
ffmpeg_cmpile_android aarch64
