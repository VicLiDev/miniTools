#!/bin/bash
#########################################################################
# File Name: .prjBuild.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 30 May 2024 02:14:53 PM CST
#########################################################################


create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1"; mkdir -p $1; fi
}



ffmpeg_cmpile_linux_aarch64()
{
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


ffmpeg_cmpile_android_arm()
{
    NDK_ROOT=${HOME}/work/android/ndk/android-ndk-r25c
    API=21 # 设置为目标Android API级别

    # 设置工具链和架构
    TOOLCHAIN_PREFIX=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64
    TARGET_ARCH=armv7-a
    # SYSROOT=$NDK_ROOT/platforms/android-$API_LEVEL/arch-$TARGET_ARCH
    CROSS_PREFIX=$TOOLCHAIN_PREFIX/bin/armv7a-linux-androideabi21-

    # 设置FFmpeg源代码路径和输出路径
    FFMPEG_OUTPUT="${PWD}/ffmpeg_out"

    # 清除之前的构建
    rm -rf $FFMPEG_OUTPUT
    mkdir -p $FFMPEG_OUTPUT

    # 配置FFmpeg，由于ar，nm等的前缀与clang不一样，所以需要单独指定一下
    ../configure \
        --prefix=$FFMPEG_OUTPUT \
        --target-os=android \
        --arch=$TARGET_ARCH \
        --cpu=armv7-a \
        --enable-cross-compile \
        --disable-shared \
        --enable-static \
        --disable-doc \
        --disable-ffplay \
        --disable-ffprobe \
        --disable-avdevice \
        --disable-symver \
        --enable-gpl \
        --cross-prefix=$CROSS_PREFIX \
        --ar=$TOOLCHAIN_PREFIX/bin/llvm-ar \
        --nm=$TOOLCHAIN_PREFIX/bin/llvm-nm \
        --ranlib=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
        --strip=$TOOLCHAIN_PREFIX/bin/llvm-strip
        # --enable-libass \
        # --enable-libfreetype \
        # --enable-libmp3lame \
        # --enable-libopus \
        # --enable-libtheora \
        # --enable-libvorbis \
        # --enable-libvpx \
        # --enable-libx264 \
        # --enable-libxvid \
        # --sysroot=$SYSROOT \
        # --extra-cflags="-I$SYSROOT/usr/include" \
        # --extra-ldflags="-L$SYSROOT/usr/lib -pie" 

    # 编译FFmpeg
    make -j4

    # 安装FFmpeg（如果需要）
    make install
}


# 这个用不了
ffmpeg_cmpile_android_aarch64()
{
    # 设置 NDK 路径
    export NDK=${HOME}/work/android/ndk/android-ndk-r25c
    export PLATFORM=$NDK/platforms/android-21/arch-arm64/
    export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
    export PREFIX=$(pwd)/android/arm64-v8a
    export AR=$TOOLCHAIN/bin/arm64-v8a-linux-android-ar
    export AS=$TOOLCHAIN/bin/arm64-v8a-linux-android-as
    export CC=$TOOLCHAIN/bin/arm64-v8a-linux-android21-clang
    export CXX=$TOOLCHAIN/bin/arm64-v8a-linux-android21-clang++
    export LD=$TOOLCHAIN/bin/arm64-v8a-linux-android-ld
    export RANLIB=$TOOLCHAIN/bin/arm64-v8a-linux-android-ranlib
    export STRIP=$TOOLCHAIN/bin/arm64-v8a-linux-android-strip


    # 配置 FFmpeg
    ../configure --prefix=$PREFIX \
        --target-os=android \
        --arch=arm64 \
        --enable-shared \
        --disable-static \
        --enable-gpl \
        --enable-nonfree \
        --enable-small \
        --disable-doc \
        --disable-ffplay \
        --disable-ffmpeg \
        --disable-ffprobe \
        --disable-avdevice \
        --disable-symver \
        --disable-pthreads \
        --disable-w32threads \
        --disable-os2threads \
        --disable-debug \
        --disable-stripping \
        --cross-prefix=$TOOLCHAIN/bin/arm64-v8a-linux-android- \
        --enable-cross-compile \
        --sysroot=$PLATFORM \
        --extra-cflags="-I$PLATFORM/usr/include" \
        --extra-ldflags="-L$PLATFORM/usr/lib64"
        # --enable-encoder=libx264 \
        # --enable-libx264 \
        # --enable-decoder=h264 \


    # 编译FFmpeg
    make -j4

    # 安装FFmpeg（如果需要）
    make install
}


create_dir build
cd build

# ffmpeg_cmpile_linux_aarch64
ffmpeg_cmpile_android_arm
# ffmpeg_cmpile_android_aarch64
