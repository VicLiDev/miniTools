#!/usr/bin/env bash
#########################################################################
# File Name: ffmpeg_cross_compile.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 30 May 2024 02:14:53 PM CST
#########################################################################

sel_tag_ffmpeg_b="ffmpeg_b:"

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86"
    )

m_sel_arch=""
run_opt=""


setup_env()
{
    # set env
    FFMPEG_ROOT="`pwd`"
    FFMPEG_EX_LIBS_DIR="${FFMPEG_ROOT}/ex_libs"
    FFMPEG_PREFIX="${FFMPEG_ROOT}/build_${m_sel_arch}"
    FFMPEG_BIN="${FFMPEG_PREFIX}/bin"
    # PKG_CONFIG_PATH 可以包含多个路径，pkg-config 会按顺序查找。
    # PKG_CONFIG_LIBDIR 一般只需指定交叉编译的全局目录（优先级最高），只能指定
    # 单个目录（不支持 : 分隔的多路径）
    # 虽然实测 PKG_CONFIG_LIBDIR 指定多个用: 分隔的路径也能正常工作，但并不是官方
    # 标准行为，在官方标准行为中：
    #   1. PKG_CONFIG_LIBDIR 应只包含单个绝对路径
    #   2. 它的设计初衷是 严格限定搜索范围，避免歧义，因此不支持多路径。
    #   3. 多路径应通过 PKG_CONFIG_PATH 实现（用 : 分隔）。
    pkg_config_paths=(
        # for ex lib and cross compile
        ${FFMPEG_PREFIX}/lib/pkgconfig
        ${FFMPEG_PREFIX}/usr/local/lib/pkgconfig
        # for linux x86 pc compile
        # 可以采用类似如下的方式，查找对应的pc文件路径
        # pkg-config --modversion freetype2 --debug
        # 例如：
        # Parsing package file '/usr/lib/x86_64-linux-gnu/pkgconfig/freetype2.pc'
        # 那么把 /usr/lib/x86_64-linux-gnu/pkgconfig 包含进来就可以了
        /usr/lib/x86_64-linux-gnu/pkgconfig
        )
    # 需要注意
    # @: 整个数组作为一个单一字符串，用 IFS 分隔每个元素。
    # *: 每个元素还是被当作独立的字符串，不会用 IFS 拼接，而是保留分隔
    FFMPEG_PKG_CFG_LIBDIR="${FFMPEG_PREFIX}/lib/pkgconfig"
    FFMPEG_PKG_CFG_PATH="$(IFS=:; echo "${pkg_config_paths[*]}")"
    FFMPEG_PATH="${FFMPEG_BIN}:$PATH"

    # create directory
    create_dir ${FFMPEG_EX_LIBS_DIR}
    create_dir ${FFMPEG_BIN}
    create_dir ${FFMPEG_PREFIX}

    if [ "${m_sel_arch}" == "android_32" ]; then
        export NDK="${HOME}/work/android/ndk/android-ndk-r25c"
        export TOOLCHAIN_ROOT="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"
        export SYSROOT=${TOOLCHAIN_ROOT}/sysroot
        # Set this to your minSdkVersion.
        export API_LEVEL=21

        # 新版本 NDK (r23+) 使用 LLVM 工具链，不再提供传统的 arm-linux-androideabi-* 工具
        # 可以使用使用如下方法创建独立工具链
        # 但建议直接使用NDK内置工具链
        # 直接使用NDK工具链通常是更简单可靠的方式
        # python3 ${NDK}/build/tools/make_standalone_toolchain.py \
        #     --api ${API_LEVEL} \
        #     --arch arm \
        #     --install-dir /tmp/android-toolchain-arm
        #
        # export PATH=/tmp/android-toolchain-arm/bin:${PATH}
        # export SYSROOT=/tmp/android-toolchain-arm/sysroot
        # export CC=arm-linux-androideabi-clang  # 注意这里改为clang

        # 直接使用内置ARM32工具链
        export CC=${TOOLCHAIN_ROOT}/bin/armv7a-linux-androideabi${API_LEVEL}-clang
        export CXX=${TOOLCHAIN_ROOT}/bin/armv7a-linux-androideabi${API_LEVEL}-clang++
        export NM=${TOOLCHAIN_ROOT}/bin/llvm-nm
        export AR=${TOOLCHAIN_ROOT}/bin/llvm-ar
        export LD=${TOOLCHAIN_ROOT}/bin/ld.lld
        export RANLIB=${TOOLCHAIN_ROOT}/bin/llvm-ranlib
        export STRIP=${TOOLCHAIN_ROOT}/bin/llvm-strip

        export ARCH=arm
        export TARGET=armv7a-linux-androideabi
        CPU_ARCH=armv7-a
        CROSS_PREFIX=${TOOLCHAIN_ROOT}/bin/${TARGET}${API_LEVEL}-

        echo "======> toolchains config plt:${m_sel_arch} <======"
        echo "NDK:             ${NDK}"
        echo "TOOLCHAIN_ROOT:  ${TOOLCHAIN_ROOT}"
        echo "SYSROOT          ${SYSROOT}"
        echo "API_LEVEL:       ${API_LEVEL}"
        echo "CC:              ${CC}"
        echo "CXX:             ${CXX}"
        echo "AR:              ${AR}"
        echo "LD:              ${LD}"
        echo "RANLIB:          ${RANLIB}"
        echo "STRIP:           ${STRIP}"
        echo "ARCH:            ${ARCH}"
        echo "TARGET:          ${TARGET}"
        echo "CPU_ARCH:        ${CPU_ARCH}"
        echo "CROSS_PREFIX:    ${CROSS_PREFIX}"
        echo

    elif [ "${m_sel_arch}" == "android_64" ]; then
        export NDK="${HOME}/work/android/ndk/android-ndk-r25c"
        export TOOLCHAIN_ROOT="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"
        export SYSROOT=${TOOLCHAIN_ROOT}/sysroot
        # Set this to your minSdkVersion.
        export API_LEVEL=21

        # 使用ARM64工具链
        export CC=${TOOLCHAIN_ROOT}/bin/aarch64-linux-android${API_LEVEL}-clang
        export CXX=${TOOLCHAIN_ROOT}/bin/aarch64-linux-android${API_LEVEL}-clang++
        export NM=${TOOLCHAIN_ROOT}/bin/llvm-nm
        export AR=${TOOLCHAIN_ROOT}/bin/llvm-ar
        export LD=${TOOLCHAIN_ROOT}/bin/ld.lld
        export RANLIB=${TOOLCHAIN_ROOT}/bin/llvm-ranlib
        export STRIP=${TOOLCHAIN_ROOT}/bin/llvm-strip

        export ARCH=aarch
        export TARGET=aarch64-linux-android
        CPU_ARCH=armv8
        CROSS_PREFIX=${TOOLCHAIN_ROOT}/bin/${TARGET}${API_LEVEL}-

        echo "======> toolchains config plt:${m_sel_arch} <======"
        echo "NDK:             ${NDK}"
        echo "TOOLCHAIN_ROOT:  ${TOOLCHAIN_ROOT}"
        echo "SYSROOT          ${SYSROOT}"
        echo "API_LEVEL:       ${API_LEVEL}"
        echo "CC:              ${CC}"
        echo "CXX:             ${CXX}"
        echo "AR:              ${AR}"
        echo "LD:              ${LD}"
        echo "RANLIB:          ${RANLIB}"
        echo "STRIP:           ${STRIP}"
        echo "ARCH:            ${ARCH}"
        echo "TARGET:          ${TARGET}"
        echo "CPU_ARCH:        ${CPU_ARCH}"
        echo "CROSS_PREFIX:    ${CROSS_PREFIX}"
        echo

    elif [ "${m_sel_arch}" == "linux_32" ]; then
        # 工具链配置
        export TOOLCHAIN_ROOT=${HOME}/Projects/prebuilts/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf
        export CROSS_PREFIX=${TOOLCHAIN_ROOT}/bin/arm-linux-gnueabihf-
        export SYSROOT=${TOOLCHAIN_ROOT}/arm-linux-gnueabihf/libc

        # 编译配置
        export ARCH=arm
        export CC=${CROSS_PREFIX}gcc
        export CXX=${CROSS_PREFIX}g++
        export AR=${CROSS_PREFIX}ar
        export LD=${CROSS_PREFIX}ld
        export RANLIB=${CROSS_PREFIX}ranlib
        export STRIP=${CROSS_PREFIX}strip

        CPU_ARCH=armv7-a

        echo "======> toolchains config plt:${m_sel_arch} <======"
        echo "TOOLCHAIN_ROOT: ${TOOLCHAIN_ROOT}"
        echo "CROSS_PREFIX:   ${CROSS_PREFIX}"
        echo "SYSROOT:        ${SYSROOT}"
        echo "ARCH:           ${ARCH}"
        echo "CC:             ${CC}"
        echo "CXX:            ${CXX}"
        echo "AR:             ${AR}"
        echo "LD:             ${LD}"
        echo "RANLIB:         ${RANLIB}"
        echo "STRIP:          ${STRIP}"
        echo "CPU_ARCH:       ${CPU_ARCH}"
        echo

    elif [ "${m_sel_arch}" == "linux_64" ]; then
        # 工具链配置
        export TOOLCHAIN_ROOT=${HOME}/Projects/prebuilts/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
        export CROSS_PREFIX=${TOOLCHAIN_ROOT}/bin/aarch64-none-linux-gnu-
        export SYSROOT=${TOOLCHAIN_ROOT}/aarch64-none-linux-gnu/libc

        # 编译配置
        export ARCH=aarch
        export CC=${CROSS_PREFIX}gcc
        export CXX=${CROSS_PREFIX}g++
        export AR=${CROSS_PREFIX}ar
        export LD=${CROSS_PREFIX}ld
        export RANLIB=${CROSS_PREFIX}ranlib
        export STRIP=${CROSS_PREFIX}strip

        CPU_ARCH=armv8

        echo "======> toolchains config plt:${m_sel_arch} <======"
        echo "TOOLCHAIN_ROOT: ${TOOLCHAIN_ROOT}"
        echo "CROSS_PREFIX:   ${CROSS_PREFIX}"
        echo "SYSROOT:        ${SYSROOT}"
        echo "ARCH:           ${ARCH}"
        echo "CC:             ${CC}"
        echo "CXX:            ${CXX}"
        echo "AR:             ${AR}"
        echo "LD:             ${LD}"
        echo "RANLIB:         ${RANLIB}"
        echo "STRIP:          ${STRIP}"
        echo "CPU_ARCH:       ${CPU_ARCH}"
        echo

    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        # 编译配置
        export CC=gcc
        export CXX=g++

        echo "======> toolchains config plt:${m_sel_arch} <======"
        echo "CC:             ${CC}"
        echo "CXX:            ${CXX}"
        echo

    else
        echo "err: platform select error"
        return
    fi
}

compile_nasm()
{
    #-- nasm
    prj_dir="${FFMPEG_EX_LIBS_DIR}/nasm-2.16.03"

    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        # git clone https://github.com/netwide-assembler/nasm.git
        # from https://www.linuxfromscratch.org/blfs/view/svn/general/nasm.html
        wget https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.xz
        tar -xvf nasm-2.16.03.tar.xz
        rm nasm-2.16.03.tar.xz
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/nasm-2.16.03"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        ./autogen.sh && \
            PATH=${FFMPEG_PATH} ./configure \
            --prefix=${FFMPEG_PREFIX} --bindir=${FFMPEG_BIN}
        make -j$(nproc) && make install
    else
        echo "err: platform select error"
        return
    fi

}

compile_x264()
{
    #-- 264
    prj_dir="${FFMPEG_EX_LIBS_DIR}/x264"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://code.videolan.org/videolan/x264.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/x264"
    create_dir ${wk_dir} && cd ${wk_dir}

    # 清理之前构建
    make distclean

    if [ "${m_sel_arch}" == "android_32" ]; then
        # 配置ARM32构建
        ./configure \
          --host=arm-linux-androideabi \
          --sysroot=${TOOLCHAIN_ROOT}/sysroot \
          --enable-static \
          --enable-pic \
          --disable-asm \  # 如果仍有问题可以暂时禁用
          --disable-cli \
          --cross-prefix=armv7a-linux-androideabi- \
          --prefix=${FFMPEG_PREFIX} \
          --bindir=${FFMPEG_PREFIX}/bin\
          --extra-cflags="-march=armv7-a -mfloat-abi=softfp -mfpu=neon" \
          --extra-ldflags="-march=armv7-a -Wl,--fix-cortex-a8"
    elif [ "${m_sel_arch}" == "android_64" ]; then
        # 配置ARM64构建
        ./configure \
          --host=aarch64-linux-android \
          --sysroot=${TOOLCHAIN_ROOT}/sysroot \
          --enable-static \
          --enable-pic \
          --disable-asm \  # 如需启用汇编优化可移除此参数
          --disable-cli \
          --cross-prefix=aarch64-linux-android- \
          --prefix=${FFMPEG_PREFIX} \
          --bindir=${FFMPEG_PREFIX}/bin \
          --extra-cflags="-O3" \  # ARM64不需要指定-march等参数
          --extra-ldflags=""
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        # linux 系统设置 --prefix 的话，安装地址会异常，因此这里不设置 --prefix
        # 而是直接由 make install 的 DESTDIR 处理
        ./configure \
            --host=arm-linux-gnueabihf \
            --sysroot=${SYSROOT} \
            --enable-static \
            --enable-pic \
            --cross-prefix=${CROSS_PREFIX} \
            --extra-cflags="-march=armv7-a -mfloat-abi=hard -mfpu=neon" \
            --extra-ldflags="-Wl,--fix-cortex-a8"
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        # linux 系统设置 --prefix 的话，安装地址会异常，因此这里不设置 --prefix
        # 而是直接由 make install 的 DESTDIR 处理
        ./configure \
            --host=aarch64-none-linux-gnu \
            --sysroot=${SYSROOT} \
            --enable-static \
            --enable-pic \
            --cross-prefix=${CROSS_PREFIX} \
            --extra-cflags="-O3" \
            --extra-ldflags=""
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        # 编译配置
        export CFLAGS="-O3 -march=x86-64 -mtune=generic"
        export LDFLAGS=""

        ./configure \
            --enable-static \
            --enable-pic \
            --disable-asm \  # 如需启用汇编优化可移除此行
            --prefix=${FFMPEG_PREFIX} \
            --bindir=${FFMPEG_BIN} \
            --extra-cflags="${CFLAGS}" \
            --extra-ldflags="${LDFLAGS}"
    else
        echo "err: platform select error"
        return
    fi

    # 构建安装
    PATH=${FFMPEG_PATH} make -j$(nproc) && make install DESTDIR=${FFMPEG_PREFIX}
}

compile_x265()
{
    #-- 265
    prj_dir="${FFMPEG_EX_LIBS_DIR}/x265_git"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://bitbucket.org/multicoreware/x265_git.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/build_x265_${m_sel_arch}"
    [ -e ${wk_dir} ] && rm -rf ${wk_dir}
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        # 只需要 x265 的静态库用于 FFmpeg，不需要它的命令行工具，通过关闭
        # CLI 编译避免构建时出现 POSIX 依赖
        cmake -G "Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=${NDK}/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=armeabi-v7a \
            -DANDROID_PLATFORM=android-${API_LEVEL} \
            -DANDROID_ARM_NEON=ON \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_CLI=OFF \
            -DENABLE_SHARED=OFF \
            ../x265_git/source
    elif [ "${m_sel_arch}" == "android_64" ]; then
        cmake -G "Unix Makefiles" \
            -DCMAKE_TOOLCHAIN_FILE=${NDK}/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=arm64-v8a \
            -DANDROID_PLATFORM=android-${API_LEVEL} \
            -DANDROID_ARM_NEON=ON \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_CLI=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_ASSEMBLY=OFF \
            ../x265_git/source
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        cmake -G "Unix Makefiles" \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=arm \
            -DCMAKE_SYSROOT=${SYSROOT} \
            -DCMAKE_C_COMPILER=${CC} \
            -DCMAKE_CXX_COMPILER=${CXX} \
            -DCMAKE_FIND_ROOT_PATH=${SYSROOT} \
            -DCMAKE_C_FLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfpu=neon -mfloat-abi=hard" \
            -DCMAKE_CXX_FLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfpu=neon -mfloat-abi=hard" \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_SHARED=OFF \
            -DENABLE_CLI=OFF \
            -DENABLE_ASSEMBLY=OFF \
            ../x265_git/source
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        cmake -G "Unix Makefiles" \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
            -DCMAKE_C_COMPILER=${CC} \
            -DCMAKE_CXX_COMPILER=${CXX} \
            -DCMAKE_FIND_ROOT_PATH=${SYSROOT} \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DCMAKE_C_FLAGS="--sysroot=${SYSROOT} -march=armv8-a" \
            -DCMAKE_CXX_FLAGS="--sysroot=${SYSROOT} -march=armv8-a" \
            -DENABLE_SHARED=OFF \
            -DENABLE_CLI=OFF \
            -DENABLE_ASSEMBLY=OFF \
            ../x265_git/source
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        PATH=${FFMPEG_PATH} cmake -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_SHARED=off \
            ../x265_git/source
    else
        echo "err: platform select error"
        return
    fi

    PATH=${FFMPEG_PATH} make -j$(nproc) && make install
}

compile_vpx()
{
    #-- vpx
    prj_dir="${FFMPEG_EX_LIBS_DIR}/libvpx"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://chromium.googlesource.com/webm/libvpx.git
        # cd libvpx && git checkout v1.12.0
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/libvpx"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        # 配置目标架构
        # export HOST=arm-linux-androideabi

        # 使用 C 编译器来编译汇编（绕开 .asm.S 的误解析）
        export AS=${CC}
        export ASFLAGS=""

        # 编译参数
        export CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -D__ANDROID_API__=${API_LEVEL}"
        export CXXFLAGS="${CFLAGS}"
        export LDFLAGS=""

        # 配置脚本（重点：不生成可执行文件）
        ./configure \
            --target=armv7-android-gcc \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --enable-pic \
            --disable-examples \
            --disable-tools \
            --disable-unit-tests
        PATH=${FFMPEG_PATH} make -j$(nproc) && make install
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        # 配置目标架构
        # export HOST=aarch64-linux-android

        # 使用 C 编译器来编译汇编（绕开 .asm.S 的误解析）
        export AS=${CC}
        export ASFLAGS=""

        # 编译参数
        export CFLAGS="-march=armv8-a -D__ANDROID_API__=${API_LEVEL}"
        export CXXFLAGS="${CFLAGS}"
        export LDFLAGS=""

        # 配置脚本（重点：不生成可执行文件）
        ./configure \
            --target=arm64-android-gcc \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --enable-pic \
            --disable-examples \
            --disable-tools \
            --disable-unit-tests
        PATH=${FFMPEG_PATH} make -j$(nproc) && make install
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
        # 编译尚存在问题，需要解决
        # export CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard"
        # export ASFLAGS="-x assembler-with-cpp -march=armv7-a -mfpu=neon -mfloat-abi=hard"
        # 配置选项（修改根据项目需要）
        ./configure \
            --target=armv7-linux-gcc \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --enable-pic

        # 构建
        PATH=${FFMPEG_PATH} make -j$(nproc) && make install
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        # 配置选项（修改根据项目需要）
        ./configure \
            --target=arm64-linux-gcc \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --enable-pic

        # 构建
        PATH=${FFMPEG_PATH} make -j$(nproc) && make install
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        PATH=${FFMPEG_PATH} ./configure \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared
    else
        echo "err: platform select error"
        return
    fi

    PATH=${FFMPEG_PATH} make && make install
}

compile_fdkaac()
{
    #-- fdkaac
    prj_dir="${FFMPEG_EX_LIBS_DIR}/fdk-aac"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/mstorsjo/fdk-aac.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/fdk-aac"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        autoreconf -fiv && ./configure --prefix=$FFMPEG_PREFIX --disable-shared
        make -j$(nproc) && make install
    else
        echo "err: platform select error"
        return
    fi
}

compile_opus()
{
    #-- opus
    prj_dir="${FFMPEG_EX_LIBS_DIR}/opus"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/xiph/opus.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/opus"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        ./autogen.sh && ./configure --prefix=${FFMPEG_PREFIX} --disable-shared
        make -j$(nproc) && make install
    else
        echo "err: platform select error"
        return
    fi
}

compile_aom()
{
    #-- aom
    prj_dir="${FFMPEG_EX_LIBS_DIR}/aom"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://aomedia.googlesource.com/aom
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/build_aom_${m_sel_arch}"
    [ -e ${wk_dir} ] && rm -rf ${wk_dir}
    create_dir ${wk_dir} && cd ${wk_dir}

    if [ "${m_sel_arch}" == "android_32" ]; then
        cmake ../aom/ \
            -DCMAKE_TOOLCHAIN_FILE=${NDK}/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI="armeabi-v7a" \
            -DANDROID_ARM_NEON=ON \
            -DANDROID_PLATFORM=android-${API_LEVEL} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DBUILD_SHARED_LIBS=ON \
            -DENABLE_DOCS=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_EXAMPLES=OFF
    elif [ "${m_sel_arch}" == "android_64" ]; then
        cmake ../aom/ \
            -DCMAKE_TOOLCHAIN_FILE=${NDK}/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI="arm64-v8a" \
            -DANDROID_PLATFORM=android-${API_LEVEL} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DBUILD_SHARED_LIBS=ON \
            -DENABLE_DOCS=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_EXAMPLES=OFF
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        cmake ../aom/ \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=${ARCH} \
            -DCMAKE_C_COMPILER=${CC} \
            -DCMAKE_CXX_COMPILER=${CXX} \
            -DCMAKE_AR=${AR} \
            -DCMAKE_STRIP=${STRIP} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DBUILD_SHARED_LIBS=ON \
            -DENABLE_DOCS=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_EXAMPLES=OFF \
            -DCMAKE_C_FLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard" \
            -DCMAKE_CXX_FLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard"
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        cmake ../aom/ \
            -DCMAKE_SYSTEM_NAME=Linux \
            -DCMAKE_SYSTEM_PROCESSOR=${ARCH} \
            -DCMAKE_C_COMPILER=${CC} \
            -DCMAKE_CXX_COMPILER=${CXX} \
            -DCMAKE_AR=${AR} \
            -DCMAKE_STRIP=${STRIP} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DBUILD_SHARED_LIBS=ON \
            -DENABLE_DOCS=OFF \
            -DENABLE_TESTS=OFF \
            -DENABLE_EXAMPLES=OFF \
            -DCMAKE_C_FLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a72" \
            -DCMAKE_CXX_FLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a72"
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        PATH="${FFMPEG_PATH}" cmake \
            -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_TESTS=OFF \
            -DENABLE_NASM=on \
            ../aom
    else
        echo "err: platform select error"
        return
    fi

    PATH=${FFMPEG_PATH} make -j$(nproc) && make install
}

compile_svt()
{
    #-- svt
    prj_dir="${FFMPEG_EX_LIBS_DIR}/SVT-AV1"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/build_SVT-AV1_${m_sel_arch}"
    [ -e ${wk_dir} ] && rm -rf ${wk_dir}
    create_dir ${wk_dir} && cd ${wk_dir}

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        PATH=${FFMPEG_PATH} cmake \
            -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_DEC=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_DISABLE_FIND_PACKAGE_cpuinfo=ON \
            ../SVT-AV1/
        PATH=${FFMPEG_PATH} make -j$(nproc) && make install
    else
        echo "err: platform select error"
        return
    fi
}

compile_dav1d()
{
    #-- dav1d
    prj_dir="${FFMPEG_EX_LIBS_DIR}/dav1d"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://code.videolan.org/videolan/dav1d.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/build_dav1d_${m_sel_arch}"
    [ -e ${wk_dir} ] && rm -rf ${wk_dir}
    create_dir ${wk_dir} && cd ${wk_dir}

    meson_config=${FFMPEG_PREFIX}/bin/${m_sel_arch}.meson

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "# ${meson_config}"             > ${meson_config}
        echo "[project]"                     >> ${meson_config}
        echo "name = 'dav1d_android_armv7a'" >> ${meson_config}
        echo "version = '1.0'"               >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[binaries]"                    >> ${meson_config}
        echo "# 指定交叉编译工具链"          >> ${meson_config}
        echo "c = '${CC}'"                   >> ${meson_config}
        echo "cpp = '${CXX}'"                >> ${meson_config}
        echo "ar = '${AR}'"                  >> ${meson_config}
        echo "strip = '${STRIP}'"            >> ${meson_config}
        echo "ld = '${LD}'"                  >> ${meson_config}
        echo "ranlib = '${RANLIB}'"          >> ${meson_config}
        echo "nm = '${NM}'"                  >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[host_machine]"                >> ${meson_config}
        echo "system = 'linux'"              >> ${meson_config}
        echo "cpu_family = 'arm'"            >> ${meson_config}
        echo "cpu = 'armv7-a'"               >> ${meson_config}
        echo "endian = 'little'"             >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[built-in options]"            >> ${meson_config}
        echo "c_args = ['-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=vfpv3-d16']"  >> ${meson_config}
        echo "cpp_args = ['-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=vfpv3-d16']">> ${meson_config}
        meson setup ${wk_dir} ../dav1d \
            --cross-file ${meson_config} \
            -Denable_tools=false \
            -Denable_tests=false \
            --default-library=static \
            --prefix ${FFMPEG_PREFIX} \
            --libdir=${FFMPEG_PREFIX}/lib
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "# ${meson_config}"             >  ${meson_config}
        echo "[project]"                     >> ${meson_config}
        echo "name = 'dav1d_android_arm64'"  >> ${meson_config}
        echo "version = '1.0'"               >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[binaries]"                    >> ${meson_config}
        echo "# 指定交叉编译工具链"          >> ${meson_config}
        echo "c = '${CC}'"                   >> ${meson_config}
        echo "cpp = '${CXX}'"                >> ${meson_config}
        echo "ar = '${AR}'"                  >> ${meson_config}
        echo "strip = '${STRIP}'"            >> ${meson_config}
        echo "ld = '${LD}'"                  >> ${meson_config}
        echo "ranlib = '${RANLIB}'"          >> ${meson_config}
        echo "nm = '${NM}'"                  >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[host_machine]"                >> ${meson_config}
        echo "system = 'android'"            >> ${meson_config}
        echo "cpu_family = 'aarch64'"        >> ${meson_config}
        echo "cpu = 'aarch64'"               >> ${meson_config}
        echo "endian = 'little'"             >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[built-in options]"            >> ${meson_config}
        echo "c_args = ['-march=armv8-a']"   >> ${meson_config}
        echo "cpp_args = ['-march=armv8-a']" >> ${meson_config}
        meson setup ${wk_dir} ../dav1d \
            --cross-file ${meson_config} \
            -Denable_tools=false \
            -Denable_tests=false \
            --default-library=static \
            --prefix ${FFMPEG_PREFIX} \
            --libdir=${FFMPEG_PREFIX}/lib
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "# ${meson_config}"             >  ${meson_config}
        echo "[project]"                     >> ${meson_config}
        echo "name = 'dav1d_linux_armv7a'"   >> ${meson_config}
        echo "version = '1.0'"               >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[binaries]"                    >> ${meson_config}
        echo "# 指定交叉编译工具链"          >> ${meson_config}
        echo "c = '${CC}'"                   >> ${meson_config}
        echo "cpp = '${CXX}'"                >> ${meson_config}
        echo "ar = '${AR}'"                  >> ${meson_config}
        echo "strip = '${STRIP}'"            >> ${meson_config}
        echo "ld = '${LD}'"                  >> ${meson_config}
        echo "ranlib = '${RANLIB}'"          >> ${meson_config}
        echo "nm = '${NM}'"                  >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[host_machine]"                >> ${meson_config}
        echo "system = 'linux'"              >> ${meson_config}
        echo "cpu_family = 'arm'"            >> ${meson_config}
        echo "cpu = 'armv7-a'"               >> ${meson_config}
        echo "endian = 'little'"             >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[built-in options]"            >> ${meson_config}
        echo "c_args = ['-march=armv7-a']"   >> ${meson_config}
        echo "cpp_args = ['-march=armv7-a']" >> ${meson_config}
        meson setup ${wk_dir} ../dav1d \
            --cross-file ${meson_config} \
            -Denable_tools=false \
            -Denable_tests=false \
            --default-library=static \
            --prefix ${FFMPEG_PREFIX} \
            --libdir=${FFMPEG_PREFIX}/lib
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "# ${meson_config}"             >  ${meson_config}
        echo "[project]"                     >> ${meson_config}
        echo "name = 'dav1d_linux_arm64'"    >> ${meson_config}
        echo "version = '1.0'"               >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[binaries]"                    >> ${meson_config}
        echo "# 指定交叉编译工具链"          >> ${meson_config}
        echo "c = '${CC}'"                   >> ${meson_config}
        echo "cpp = '${CXX}'"                >> ${meson_config}
        echo "ar = '${AR}'"                  >> ${meson_config}
        echo "strip = '${STRIP}'"            >> ${meson_config}
        echo "ld = '${LD}'"                  >> ${meson_config}
        echo "ranlib = '${RANLIB}'"          >> ${meson_config}
        echo "nm = '${NM}'"                  >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[host_machine]"                >> ${meson_config}
        echo "system = 'linux'"              >> ${meson_config}
        echo "cpu_family = 'aarch64'"        >> ${meson_config}
        echo "cpu = 'aarch64'"               >> ${meson_config}
        echo "endian = 'little'"             >> ${meson_config}
        echo ""                              >> ${meson_config}
        echo "[built-in options]"            >> ${meson_config}
        echo "c_args = ['-march=armv8-a']"   >> ${meson_config}
        echo "cpp_args = ['-march=armv8-a']" >> ${meson_config}
        meson setup ${wk_dir} ../dav1d \
            --cross-file ${meson_config} \
            -Denable_tools=false \
            -Denable_tests=false \
            --default-library=static \
            --prefix ${FFMPEG_PREFIX} \
            --libdir=${FFMPEG_PREFIX}/lib
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        meson setup \
            -Denable_tools=false \
            -Denable_tests=false \
            --default-library=static \
            --prefix ${FFMPEG_PREFIX} \
            --libdir=${FFMPEG_PREFIX}/lib \
            ../dav1d
    else
        echo "err: platform select error"
        return
    fi

    ninja && ninja install
}

compile_vmaf()
{
    #-- vmaf
    prj_dir="${FFMPEG_EX_LIBS_DIR}/vmaf"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/Netflix/vmaf.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/vmaf/libvmaf/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo "unsupport, need finish"
        return
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        meson setup -Denable_tests=false \
            -Denable_docs=false \
            --buildtype=release \
            --default-library=static \
            .. \
            --prefix ${FFMPEG_PREFIX} \
            --bindir=${FFMPEG_PREFIX}/bin \
            --libdir=${FFMPEG_PREFIX}/lib
        ninja && ninja install
    else
        echo "err: platform select error"
        return
    fi
}

compile_davs2()
{
    #-- davs2
    prj_dir="${FFMPEG_EX_LIBS_DIR}/davs2"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/pkuvcl/davs2.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/davs2/build/linux"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        ./configure \
            --host=arm-linux-androideabi \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfloat-abi=softfp -mfpu=neon -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "android_64" ]; then
        ./configure \
            --host=aarch64-linux-android \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        ./configure \
            --host=arm-linux-gnueabihf \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfloat-abi=softfp -mfpu=neon -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        ./configure \
            --host=aarch64-none-linux-gnu \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        ./configure \
            --prefix=${FFMPEG_PREFIX} \
            --enable-pic
    else
        echo "err: platform select error"
        return
    fi

    make -j$(nproc) && make install
}

compile_xavs2()
{
    #-- xavs2
    prj_dir="${FFMPEG_EX_LIBS_DIR}/xavs2"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/pkuvcl/xavs2.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/xavs2/build/linux"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        ./configure \
            --host=arm-linux-androideabi \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfloat-abi=softfp -mfpu=neon -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "android_64" ]; then
        ./configure \
            --host=aarch64-linux-android \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        ./configure \
            --host=aarch64-linux-android \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv7-a -mfpu=neon -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        ./configure \
            --host=aarch64-linux-android \
            --prefix=${FFMPEG_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-asm \
            --disable-cli \
            CC="${CC}" \
            CFLAGS="--sysroot=${SYSROOT} -march=armv8-a -fPIC" \
            LDFLAGS="--sysroot=${SYSROOT}"
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        ./configure \
            --prefix=${FFMPEG_PREFIX} \
            --enable-pic
    else
        echo "err: platform select error"
        return
    fi

    make -j$(nproc) && make install
}

compile_libjpeg()
{
    #-- libjpeg
    prj_dir="${FFMPEG_EX_LIBS_DIR}/libjpeg-turbo"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_EX_LIBS_DIR}
        git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git
    fi

    wk_dir="${FFMPEG_EX_LIBS_DIR}/libjpeg-turbo/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    make clean

    if [ "${m_sel_arch}" == "android_32" ]; then
        echo
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        echo
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        echo
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        PATH=${FFMPEG_PATH} cmake -G "Unix Makefiles" \
            -DCMAKE_INSTALL_PREFIX=${FFMPEG_PREFIX} \
            -DENABLE_SHARED=off \
            ..
    else
        echo "err: platform select error"
        return
    fi

    make -j$(nproc) && make install
}

compile_distributor()
{
    components=$1
    cd ${FFMPEG_ROOT}

    echo "======> compile ${components} <======"
    build_func="compile_${components}"
    echo "Build components: ${components}"
    echo "Build components func: ${build_func}"

    if [ "${run_opt}" != "c" ]; then
        read -p "continue? [y/n/s/c] def[y]:" run_opt
        [ "$run_opt" = "n" ] && exit 0
        [ "$run_opt" = "s" ] && return 0
    fi

    ${build_func}
    res=$?
    echo "======> compile ${components} finish res:${res} <======"
    echo ""
}


compile_ffmpeg()
{
    #-- ffmpeg
    prj_dir="${FFMPEG_ROOT}/ffmpeg"
    if [ ! -d "${prj_dir}" ]; then
        cd ${FFMPEG_ROOT}
        git clone https://git.ffmpeg.org/ffmpeg.git
    fi

    wk_dir="${prj_dir}/build_ffmpeg_${m_sel_arch}"
    [ -e ${wk_dir} ] && rm -rf ${wk_dir}
    create_dir ${wk_dir} && cd ${wk_dir}

    pkg_config_exe=${FFMPEG_PREFIX}/bin/${m_sel_arch}-pkg-config

    # 出现问题：ERROR: aom >= 2.0.0 not found using pkg-config
    # 查看 aom 的版本信息
    # cat ${HOME}/Projects/ffmpeg/build_android_32/lib/pkgconfig/aom.pc
    # echo "pkg test cmd: PKG_CONFIG_PATH=${FFMPEG_PKG_CFG_PATH} pkg-config --debug --modversion aom"
    # 以下命令输出的版本，应该与pc文件中的版本一致，从debug信息，也可以看到找的文件是否正确
    # echo "pkg test cmd: ${pkg_config_exe} --debug --modversion x265"
    # 加上 --debug 参数可以看到是从哪个文件中解析到的数据，例如：Parsing package file...
    #
    # 如下设置PKG变量，仍旧找不到 aom，这是因为
    #   1. FFmpeg 的 configure 脚本可能在其内部 通过子 Shell 或子进程调用
    #      pkg-config，而导出的环境变量可能因作用域问题未被继承。
    #   2. 某些系统或脚本会 重置或覆盖 PKG_CONFIG_PATH（例如某些自动化工具链脚本）。
    #   3. PKG_CONFIG_LIBDIR 的优先级高于 PKG_CONFIG_PATH，但若未正确传递，
    #      pkg-config 可能回退到系统默认路径。
    # 但在链接 x264 的时候 使用config文件的方式又不能奏效，所以这种处理方式
    # 也需要保留
    # x86不设置 PKG_CONFIG_SYSROOT_DIR，不然会有问题
    # PKG_CONFIG_SYSROOT_DIR 只指向 目标 sysroot，不要把“自己编译的库路径”塞进 sysroot
    # 自己编译的库用 PKG_CONFIG_PATH 管
    if [ "${m_sel_arch}" != "linux_x86" ]; then
        export PKG_CONFIG_SYSROOT_DIR=${FFMPEG_PREFIX}
    fi
    export PKG_CONFIG_LIBDIR=${FFMPEG_PKG_CFG_LIBDIR}
    export PKG_CONFIG_PATH=${FFMPEG_PKG_CFG_PATH}
    #
    #
    # 有效的方法如下：创建一个 arm-pkg-config
    # 使用如下方法时，如果没有加最后一行：exec pkg-config "$@" 也会存在问题
    #
    # exec 的意义：
    # exec 会用 pkg-config 进程 替换当前 Shell 进程，确保环境变量（PKG_CONFIG_*）
    # 原封不动地传递给 pkg-config。
    # 如果没有 exec，脚本可能会以子 Shell 方式运行 pkg-config，导致环境变量传递
    # 不完整（某些 Shell 实现会优化掉未使用的变量）。
    #
    # "$@" 的意义：
    # 它将脚本接收的所有参数原样传递给 pkg-config，确保命令行参数
    # （如 --modversion aom）不被篡改。
    #
    # 为什么必须显式通过 --pkg-config 指定脚本
    # FFmpeg 的 configure 脚本默认直接调用系统 pkg-config，不会自动继承父进程
    # 的所有环境变量（尤其是跨 Shell 调用时）。
    # 通过 --pkg-config=自定义脚本，你强制 FFmpeg 使用你的脚本调用 pkg-config，
    # 从而 确保环境变量（如 PKG_CONFIG_LIBDIR）被正确传递。
    # 也就是告诉 FFmpeg：，“以后所有库检测，请用我指定的这个 pkg-config 程序”
    # 也就是说，FFmpeg 默认用的 /usr/bin/pkg-config 被你替换掉了。
    #
    #
    # 找不到 x265 库的问题：
    # 直接执行 ${pkg_config_exe} --debug --modversion x265 发现无法正常找到编译
    # 得到的 x265 库，需要加上export才可以，加上export，命令行可以直接执行
    # ${pkg_config_exe} --debug --modversion x265 这样的命令，便于调试
    #
    # 在 ${pkg_config_exe} 中添加调试相关打印，可以看到ffmpeg的相关行为，如果
    # 出现找不到 x265 的问题，可以直接执行 ${pkg_config_exe} <args> 进行测试
    #
    # 执行 ${pkg_config_exe} --libs --static x265 发现存在路径重复的问题
    # 调试发现，这主要是因为设置了PKG_CONFIG_SYSROOT_DIR，因此PKG_CONFIG_SYSROOT_DIR
    # 和 pc 里的路径叠加导致，但其他库，例如 vpx，存在相同的现象，却没有找不到库
    # 的问题
    #
    # 查看 ffbuild/config.log 发现：
    # ld: error: unable to find library -l-l:libunwind.a
    # ld: error: unable to find library -l-l:libunwind.a
    # clang-14: error: linker command failed with exit code 1 (use -v to see invocation)
    # ERROR: x265 not found using pkg-config
    # 因此找不到x265库，主要是因为 -l-l:libunwind.a 的问题导致，修改 x265.pc文件
    # 中的
    # Libs.private: -lc++ -lm -l-l:libunwind.a -ldl -l-l:libunwind.a -ldl -ldl
    # 为
    # Libs.private: -lc++ -lm -ldl
    # 就可以正常找到 x265 库进行编译了
    # 这个问题应该与 x265 的编译脚本有关
    #
    # 这个问题最终采用手动修改pc文件的方式解决：
    x265_pc="${FFMPEG_PREFIX}/lib/pkgconfig/x265.pc"
    [ -e "${x265_pc}" ] && sed -i -E -e 's/-l-l:/-l:/g' ${x265_pc}

    echo "#!/bin/bash" > ${pkg_config_exe}
    # echo "{" >> ${pkg_config_exe}
    # echo "    echo \"pkg cmd: ${pkg_config_exe} \$@\"" >> ${pkg_config_exe}
    # echo "} >&2" >> ${pkg_config_exe}

    if [ "${m_sel_arch}" != "linux_x86" ]; then
        echo "export PKG_CONFIG_SYSROOT_DIR=${FFMPEG_PREFIX}" >> ${pkg_config_exe}
    fi
    echo "export PKG_CONFIG_LIBDIR=${FFMPEG_PKG_CFG_LIBDIR}" >> ${pkg_config_exe}
    echo "export PKG_CONFIG_PATH=${FFMPEG_PKG_CFG_PATH}" >> ${pkg_config_exe}
    echo "exec pkg-config \"\$@\"" >> ${pkg_config_exe}
    chmod +x ${pkg_config_exe}

    # 遇到问题： ERROR: gnutls not found using pkg-config
    # 执行：pkg-config --modversion gnutls --debug
    # 出现：Unknown keyword 'Libs.private' in '/usr/lib/x86_64-linux-gnu/pkgconfig/gnutls.pc'
    # 原因：pkg-config 版本太老，不认识 Libs.private 这个字段
    # 解决方法：pkg-config --version 如果 < 0.29（尤其 0.26 / 0.27）就该升级了
    #           Ubuntu / Debian：sudo apt install -y pkg-config
    #           或：
    #           sudo apt install -y pkgconf
    #           sudo ln -sf /usr/bin/pkgconf /usr/bin/pkg-config
    #           然后验证：pkg-config --modversion gnutls --debug
    #           但是这只能解决 Libs.private 的问题，不能解决 gnutls的问题
    # 发现与 --pkg-config-flags="--static" 有关，注释掉就可以消除掉 gnutls 的问题
    # 这条参数含义：告诉 pkg-config：我要“静态链接”视角下的依赖信息
    # 不加的情况：只返回「直接依赖」
    # 加上的情况：返回「直接依赖 + 私有依赖（Libs.private / Requires.private）」
    # 最终通过安装如下内容解决：
    # sudo apt install libgnutls28-dev nettle-dev libtasn1-dev libidn2-dev \
    #                  libunistring-dev libp11-kit-dev libgmp-dev

    # 遇到问题：x264 not found using pkg-config
    # 查看：./ffmpeg/build_ffmpeg_linux_x86/ffbuild/config.log
    # 有异常信息：
    # /tmp/ffconf.O1MBi3ud/test.c:2:10: fatal error: x264.h: No such file or directory
    #     2 | #include <x264.h>
    #       |          ^~~~~~~~
    # compilation terminated.
    # ERROR: x264 not found using pkg-config
    # 异常原因是找不到 x264.h 头文件，因此需要在ffmpeg的include和lib路径中，
    # 加一下x264的路径，即：
    # --extra-cflags="-I ${FFMPEG_PREFIX}/include -I ${FFMPEG_PREFIX}/usr/local/include"
    # --extra-ldflags="-L ${FFMPEG_PREFIX}/lib -L ${FFMPEG_PREFIX}/usr/local/lib"

    # 如果希望静态编译，需要将aom 的动态库删掉
    [ -e "${FFMPEG_PREFIX}/lib/libaom.so" ] && rm ${FFMPEG_PREFIX}/lib/libaom.so

    if [ "${m_sel_arch}" == "android_32" ]; then
        ffmpeg_config=(
            --prefix=${FFMPEG_PREFIX}
            --target-os=android
            --arch=${ARCH}
            --cpu=${CPU_ARCH}
            --enable-cross-compile
            --cross-prefix=${CROSS_PREFIX}
            --ar=${AR}
            --nm=${NM}
            --ranlib=${RANLIB}
            --strip=${STRIP}
            --pkg-config=${pkg_config_exe}
            --pkg-config-flags="--static"
            --extra-cflags="-I ${FFMPEG_PREFIX}/include"
            --extra-ldflags="-L ${FFMPEG_PREFIX}/lib"
            --disable-shared
            --enable-static
            --enable-pthreads
            --disable-avdevice
            --disable-symver
            --enable-gpl
            # 外部依赖库
            --enable-libx264
            --enable-libx265
            --enable-libvpx
            --enable-libaom
            --enable-libdav1d
            --enable-libdavs2
            --enable-libxavs2
        )

        # 为了避免参数被错误解析，${ffmpeg_config[@]} 需要加引号
        PATH="${FFMPEG_PATH}" PKG_CONFIG_PATH="${FFMPEG_PKG_CFG_PATH}" ../configure "${ffmpeg_config[@]}"
    elif [ "${m_sel_arch}" == "android_64" ]; then
        ffmpeg_config=(
            --prefix=${FFMPEG_PREFIX}
            --target-os=android
            --arch=${ARCH}
            --cpu=${CPU_ARCH}
            --enable-cross-compile
            --cross-prefix=${CROSS_PREFIX}
            --ar=${AR}
            --nm=${NM}
            --ranlib=${RANLIB}
            --strip=${STRIP}
            --pkg-config=${pkg_config_exe}
            --pkg-config-flags="--static"
            --extra-cflags="-I ${FFMPEG_PREFIX}/include"
            --extra-ldflags="-L ${FFMPEG_PREFIX}/lib"
            --disable-shared
            --enable-static
            --enable-pthreads
            --disable-avdevice
            --disable-symver
            --enable-gpl
            # 外部依赖库
            --enable-libx264
            --enable-libx265
            --enable-libvpx
            --enable-libaom
            --enable-libdav1d
            --enable-libdavs2
            --enable-libxavs2
        )

        # 为了避免参数被错误解析，${ffmpeg_config[@]} 需要加引号
        PATH="${FFMPEG_PATH}" PKG_CONFIG_PATH="${FFMPEG_PKG_CFG_PATH}" ../configure "${ffmpeg_config[@]}"
    elif [ "${m_sel_arch}" == "linux_32" ]; then
        ffmpeg_config=(
            --prefix=${FFMPEG_PREFIX}
            --target-os=linux
            --arch=${ARCH}
            --cpu=${CPU_ARCH}
            --enable-cross-compile
            --cross-prefix=${CROSS_PREFIX}
            --ar=${AR}
            --nm=${NM}
            --ranlib=${RANLIB}
            --strip=${STRIP}
            --pkg-config=${pkg_config_exe}
            --pkg-config-flags="--static"
            --extra-cflags="-I ${FFMPEG_PREFIX}/include"
            --extra-ldflags="-L ${FFMPEG_PREFIX}/lib"
            --extra-libs="-lpthread -lm"
            --disable-shared
            --enable-static
            --enable-pthreads
            --disable-avdevice
            --disable-symver
            --enable-gpl
            # 外部依赖库
            --enable-libx264
            --enable-libx265
            # --enable-libvpx
            --enable-libaom
            --enable-libdav1d
            --enable-libdavs2
            --enable-libxavs2
        )

        # 为了避免参数被错误解析，${ffmpeg_config[@]} 需要加引号
        PATH="${FFMPEG_PATH}" PKG_CONFIG_PATH="${FFMPEG_PKG_CFG_PATH}" ../configure "${ffmpeg_config[@]}"
    elif [ "${m_sel_arch}" == "linux_64" ]; then
        ffmpeg_config=(
            --prefix=${FFMPEG_PREFIX}
            --target-os=linux
            --arch=${ARCH}
            --cpu=${CPU_ARCH}
            --enable-cross-compile
            --cross-prefix=${CROSS_PREFIX}
            --ar=${AR}
            --nm=${NM}
            --ranlib=${RANLIB}
            --strip=${STRIP}
            --pkg-config=${pkg_config_exe}
            --pkg-config-flags="--static"
            --extra-cflags="-I ${FFMPEG_PREFIX}/include"
            --extra-ldflags="-L ${FFMPEG_PREFIX}/lib"
            --extra-libs="-lpthread -lm"
            --disable-shared
            --enable-static
            --enable-pthreads
            --disable-avdevice
            --disable-symver
            --enable-gpl
            # 外部依赖库
            --enable-libx264
            --enable-libx265
            --enable-libvpx
            --enable-libaom
            --enable-libdav1d
            --enable-libdavs2
            --enable-libxavs2
        )

        # 为了避免参数被错误解析，${ffmpeg_config[@]} 需要加引号
        PATH="${FFMPEG_PATH}" PKG_CONFIG_PATH="${FFMPEG_PKG_CFG_PATH}" ../configure "${ffmpeg_config[@]}"
    elif [ "${m_sel_arch}" == "linux_x86" ]; then
        ffmpeg_config=(
            --prefix=${FFMPEG_PREFIX}
            # 这个参数主要是在交叉编译的时候，指定相应系统的sysroot
            # sysroot 中应当包含与指定平台等价的环境
            # --sysroot=${FFMPEG_PREFIX}
            --pkg-config=${pkg_config_exe}
            --pkg-config-flags="--static"
            --extra-cflags="-I ${FFMPEG_PREFIX}/include -I ${FFMPEG_PREFIX}/usr/local/include"
            --extra-ldflags="-L ${FFMPEG_PREFIX}/lib -L ${FFMPEG_PREFIX}/usr/local/lib"
            --extra-libs="-lpthread -lm"
            --ld="g++"
            --enable-libvorbis
            --enable-gnutls
            --enable-libass
            --enable-libfreetype
            --enable-libfontconfig
            --enable-libfribidi
            --enable-libharfbuzz
            --enable-libmp3lame
            --enable-sdl
            --enable-pthreads
            --enable-gpl
            --enable-nonfree
            # 外部依赖库
            --enable-libx264
            --enable-libx265
            --enable-libvpx
            --enable-libfdk-aac
            --enable-libopus
            --enable-libaom
            --enable-libsvtav1
            --enable-libdav1d
            --enable-libdavs2
            --enable-libxavs2
            # --enable-libjpeg       # 启用 libjpeg 支持
            # --enable-libjpeg-turbo
            --enable-encoder=mjpeg # 启用 MJPEG 编码器（基于 libjpeg）
            --enable-decoder=mjpeg # 启用 MJPEG 解码器
        )
        # 为了避免参数被错误解析，${ffmpeg_config[@]} 需要加引号
        PATH="${FFMPEG_PATH}" PKG_CONFIG_PATH="${FFMPEG_PKG_CFG_PATH}" ../configure "${ffmpeg_config[@]}"
    else
        echo "err: platform select error"
        return
    fi

    PATH="${FFMPEG_PATH}" make -j$(nproc) && make install

    echo "push libc++_shared.so to device maybe necessary by x265"
    if [ "${m_sel_arch}" == "android_32" ]; then
        echo "cmd: adbs push ${SYSROOT}/usr/lib/arm-linux-androideabi/libc++_shared.so /vendor/lib"
    elif [ "${m_sel_arch}" == "android_64" ]; then
        echo "cmd: adbs push ${SYSROOT}/usr/lib/aarch64-linux-android/libc++_shared.so /vendor/lib64"
    # elif [ "${m_sel_arch}" == "linux_32" ]; then
    #     echo "cmd: adbs push "
    # elif [ "${m_sel_arch}" == "linux_64" ]; then
    #     echo "cmd: adbs push "
    fi
}

# ====== main ======

prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.dir_file_opt.sh
prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.select_node.sh

main()
{
    select_node "${sel_tag_ffmpeg_b}" "pltList" "m_sel_arch" "platform"
    
    setup_env

    read -p "build ex libs? [y/n] def[n]:" build_ex_libs
    if [ "${build_ex_libs}" == "y" ]; then
        if [ "${m_sel_arch}" == "android_32" ]; then
            compile_distributor "x264"
            compile_distributor "x265"
            compile_distributor "vpx"
            compile_distributor "aom"
            compile_distributor "dav1d"
            compile_distributor "davs2"
            compile_distributor "xavs2"
        elif [ "${m_sel_arch}" == "android_64" ]; then
            compile_distributor "x264"
            compile_distributor "x265"
            compile_distributor "vpx"
            compile_distributor "aom"
            compile_distributor "dav1d"
            compile_distributor "davs2"
            compile_distributor "xavs2"
        elif [ "${m_sel_arch}" == "linux_32" ]; then
            compile_distributor "x264"
            compile_distributor "x265"
            compile_distributor "vpx"
            compile_distributor "aom"
            compile_distributor "dav1d"
            compile_distributor "davs2"
            compile_distributor "xavs2"
        elif [ "${m_sel_arch}" == "linux_64" ]; then
            compile_distributor "x264"
            compile_distributor "x265"
            compile_distributor "vpx"
            compile_distributor "aom"
            compile_distributor "dav1d"
            compile_distributor "davs2"
            compile_distributor "xavs2"
        elif [ "${m_sel_arch}" == "linux_x86" ]; then
            compile_distributor "nasm"
            compile_distributor "x264"
            compile_distributor "x265"
            compile_distributor "vpx"
            compile_distributor "fdkaac"
            compile_distributor "opus"
            compile_distributor "aom"
            compile_distributor "svt"
            compile_distributor "dav1d"
            compile_distributor "vmaf"
            compile_distributor "davs2"
            compile_distributor "xavs2"
            compile_distributor "libjpeg"
        else
            echo "err: platform select error"
            return
        fi
    fi

    compile_distributor "ffmpeg"
}

main $@
