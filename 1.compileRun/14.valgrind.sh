#!/usr/bin/env bash
#########################################################################
# File Name: compile.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 29 Jul 2024 11:34:24 AM CST
#########################################################################

# download:
# https://valgrind.org/
# https://valgrind.org/downloads/current.html

# reference:
# https://valgrind.org/docs/manual/dist.readme-android.html
# https://www.cnblogs.com/yucloud/p/armbuild_valgrind3.html

# 遇到的问题：
# 1. sysroot 会指定类似操作系统的环境，sysroot的路径下会有类似 /usr 的文件夹，
#    因此这里sysroot指定的是系统根目录的环境，例如 stdio.h 头文件等，
# 2. 遇到 c preprocessor arm-linux-androideabi-cpp fails sanity check 的问题，
#    这是因为没有正确指定CXX参数导致
# 3. 测试过ndk：android-ndk-r16b，由于它的 platforms/android 中均没有stdio.h
#    文件，因此改用android-ndk-r10d
# 3. 遇到找不到 stdio.h 的问题，这是因为sysroot中，有些android-<num>存在问题，
#    可以切换android-<num>试一下

# deploy in android:
# 看脚本最后的打印

bdPlt="arm"

if [ "$1" == "arm" ]; then bdPlt="arm"; fi
if [ "$1" == "arm64" ]; then bdPlt="arm64"; fi
if [ "$1" == "linux32" ]; then bdPlt="linux32"; fi
if [ "$1" == "linux64" ]; then bdPlt="linux64"; fi
if [ "$1" == "x86" ]; then bdPlt="x86"; fi

clear
source $(dirname $(readlink -f $0))/0.dir_file_opt.sh

# prepare env, create dir
echo "==> prepare env..."
VLDROOT="${HOME}/Projects/valgrind-3.23.0"
BuildDir="${VLDROOT}/build"
PrefixDir="${BuildDir}/vld_pre"
remove_dir ${BuildDir}
create_dir ${BuildDir}
create_dir ${PrefixDir}
echo "prj dir: ${VLDROOT}"
echo "build dir: ${BuildDir}"

# Set up toolchain paths.
#
# You may need to set the --with-tmpdir path to something
# different if /sdcard doesn't work on the device -- this is
# a known cause of difficulties.
if [ ${bdPlt} == "arm" ]; then
    # For ARM
    NDKROOT="${HOME}/work/android/ndk/android-ndk-r10d"
    ToolsDir="toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin"
    SYSROOT="platforms/android-19/arch-arm"
    export AR="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-ar"
    export LD="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-ld"
    export CC="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-gcc"
    export CXX="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-g++"
    # export CXX="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-c++"
    # export CPP="${NDKROOT}/${ToolsDir}/arm-linux-androideabi-cpp"
elif [ ${bdPlt} == "arm64" ]; then
    # For ARM64 (AArch64)
    NDKROOT="${HOME}/work/android/ndk/android-ndk-r10d"
    ToolsDir="toolchains/aarch64-linux-android-4.9/prebuilt/linux-x86_64/bin"
    SYSROOT="platforms/android-21/arch-arm64"
    export AR="${NDKROOT}/${ToolsDir}/aarch64-linux-android-ar"
    export LD="${NDKROOT}/${ToolsDir}/aarch64-linux-android-ld"
    export CC="${NDKROOT}/${ToolsDir}/aarch64-linux-android-gcc"
    export CXX="${NDKROOT}/${ToolsDir}/aarch64-linux-android-g++"
elif [ ${bdPlt} == "linux32" ]; then
    # For linux32
    TOOLSROOT="${HOME}/Projects/prebuilts/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf"
    SYSROOT="platforms/android-21/arch-arm64"
    export AR="${TOOLSROOT}/bin/arm-linux-gnueabihf-ar"
    export LD="${TOOLSROOT}/bin/arm-linux-gnueabihf-ld"
    export CC="${TOOLSROOT}/bin/arm-linux-gnueabihf-gcc"
    export CXX="${TOOLSROOT}/bin/arm-linux-gnueabihf-g++"
elif [ ${bdPlt} == "linux64" ]; then
    # For linux64
    TOOLSROOT="${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"
    SYSROOT="platforms/android-21/arch-arm64"
    export AR="${TOOLSROOT}/bin/aarch64-none-linux-gnu-ar"
    export LD="${TOOLSROOT}/bin/aarch64-none-linux-gnu-ld"
    export CC="${TOOLSROOT}/bin/aarch64-none-linux-gnu-gcc"
    export CXX="${TOOLSROOT}/bin/aarch64-none-linux-gnu-g++"
elif [ ${bdPlt} == "x86" ]; then
    # For x86
    export AR="ar"
    export LD="ld"
    export CC="gcc"
else
    echo "Please specify the compilation platform"
    exit 0
fi

echo "AR: ${AR}"
echo "LD: ${LD}"
echo "CC: ${CC}"
echo "sysroot: ${NDKROOT}/${SYSROOT}"


# 下面重新生成 configure、Makefiles、...
# 如果从发布 tarball 启动，则不需要此步骤。
echo "==> generate configure..."
cd ${VLDROOT}
echo "cur dir: `pwd`"
./autogen.sh

echo "==> config valgrind..."
cd ${BuildDir}
if [ ${bdPlt} == "arm" ]; then
    # for ARM
    CPPFLAGS="--sysroot=${NDKROOT}/${SYSROOT}" \
        CFLAGS="--sysroot=${NDKROOT}/${SYSROOT}" \
        ../configure --prefix=${PrefixDir} \
        --host=armv7-unknown-linux --target=armv7-unknown-linux \
        --with-tmpdir=/sdcard
elif [ ${bdPlt} == "arm64" ]; then
    # for ARM64 (AArch64)
    CPPFLAGS="--sysroot=${NDKROOT}/${SYSROOT}" \
        CFLAGS="--sysroot=${NDKROOT}/${SYSROOT}" \
        ../configure --prefix=${PrefixDir} \
        --host=aarch64-unknown-linux --target=aarch64-unknown-linux \
        --with-tmpdir=/sdcard
elif [ ${bdPlt} == "linux32" ]; then
    # for linux32
    ../configure --prefix=${PrefixDir} \
        --host=armv7-unknown-linux --target=armv7-unknown-linux \
        --with-tmpdir=/sdcard
elif [ ${bdPlt} == "linux64" ]; then
    # for linux64
    ../configure --prefix=${PrefixDir} \
        --host=aarch64-unknown-linux --target=aarch64-unknown-linux \
        --with-tmpdir=/sdcard
elif [ ${bdPlt} == "x86" ]; then
    # for x86
    ../configure --prefix=${PrefixDir}
else
    echo "Please specify the compilation platform"
    exit 0
fi


echo "==> build valgrind..."
make -j
make install



echo
echo -e "\033[0m\033[1;36m"
echo "==> deploy in android/linux: "
echo "Manual execution is recommended"
echo "It is recommended to use the buildroot system for Linux,"
echo "otherwise the relocation information may not be found"
echo "1. adb push ${PrefixDir} /vendor/"
echo "2. chmod -R 777 /vendor/vld_pre"
echo '3. export PATH=$PATH:/vendor/vld_pre/bin/'
echo "4. export VALGRIND_LIB=/vendor/vld_pre/libexec/valgrind/"
echo -e "\033[0m"
