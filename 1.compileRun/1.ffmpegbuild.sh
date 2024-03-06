#########################################################################
# File Name: ffmpegbuild.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2022年05月27日 星期五 14时49分55秒
#########################################################################
#!/bin/bash

set -e

create_dir()
{
    cur_dir=$1
    if [ ! -d "${cur_dir}" ]; then
        echo "create dir ${cur_dir}"
        mkdir -p ${cur_dir}
    fi
}

setup_env()
{
    # set env
    FFMPEGROOT="$HOME/Projects/ffmpeg_source"
    FFMPEGPREFIX="${FFMPEGROOT}/ffmpeg_build"
    FFMPEGBIN="${FFMPEGPREFIX}/bin"
    FFMPEGPKGCONFIG="${FFMPEGPREFIX}/lib/pkgconfig"
    FFMPEGPATH="${FFMPEGBIN}:$PATH"

    # create directory
    create_dir ${FFMPEGROOT}
    create_dir ${FFMPEGBIN}
    create_dir ${FFMPEGPREFIX}
}

compile_nasm()
{
    #-- nasm
    wk_dir="nasm-2.15.05"
    create_dir ${wk_dir} && cd ${wk_dir}

    ./autogen.sh && PATH=$FFMPEGPATH ./configure \
        --prefix=$HOME/ffmpeg_build --bindir=$FFMPEGBIN
    make -j20 && make install
}

compile_x264()
{
    #-- 264
    wk_dir="x264"
    create_dir ${wk_dir} && cd ${wk_dir}

    # PATH=$FFMPEGPATH PKG_CONFIG_PATH=$FFMPEGPKGCONFIG ./configure \
    PATH=$FFMPEGPATH ./configure \
        --prefix=$FFMPEGPREFIX --bindir=$FFMPEGBIN \
        --enable-static --enable-pic
    PATH=$FFMPEGPATH make -j 20 && make install
}

compile_x265()
{
    #-- 265
    wk_dir="multicoreware-x265_git-e3713124dccd/build/linux"
    create_dir ${wk_dir} && cd ${wk_dir}

    PATH=$FFMPEGPATH cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX -DENABLE_SHARED=off ../../source
    PATH=$FFMPEGPATH make -j20 && make install
}

compile_vpx()
{
    #-- vpx
    wk_dir="libvpx-1.9.0"
    create_dir ${wk_dir} && cd ${wk_dir}

    PATH=$FFMPEGPATH ./configure \
        --prefix=$FFMPEGPREFIX \
        --disable-examples \
        --disable-unit-tests \
        --enable-vp9-highbitdepth \
        --as=yasm
    PATH=$FFMPEGPATH make -j 20 && make install
}

compile_fdkaac()
{
    #-- fdkaac
    wk_dir="fdk-aac-master"
    create_dir ${wk_dir} && cd ${wk_dir}

    autoreconf -fiv && ./configure --prefix=$FFMPEGPREFIX --disable-shared
    make -j20 && make install
}

compile_opus()
{
    #-- opus
    wk_dir="opus-master"
    create_dir ${wk_dir} && cd ${wk_dir}

    ./autogen.sh && ./configure --prefix=$FFMPEGPREFIX --disable-shared
    make -j 20 && make install
}

compile_aom()
{
    #-- aom
    wk_dir="aom_build"
    create_dir ${wk_dir} && cd ${wk_dir}

    PATH="$FFMPEGPATH" cmake \
        -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX \
        -DENABLE_TESTS=OFF \
        -DENABLE_NASM=on \
        ../aom
    PATH=$FFMPEGPATH make -j20 && make install
}

compile_svt()
{
    #-- svt
    wk_dir="SVT-AV1/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    PATH=$FFMPEGPATH cmake \
        -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_DEC=OFF \
        -DBUILD_SHARED_LIBS=OFF ..
    PATH=$FFMPEGPATH make -j20 && make install
}

compile_dav1d()
{
    #-- dav1d
    wk_dir="dav1d/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    meson setup \
        -Denable_tools=false \
        -Denable_tests=false \
        --default-library=static \
        .. \
        --prefix $FFMPEGPREFIX \
        --libdir=$FFMPEGPREFIX/lib
    ninja && ninja install
}

compile_vmaf()
{
    #-- vmaf
    wk_dir="vmaf-2.1.1/libvmaf/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    meson setup -Denable_tests=false \
        -Denable_docs=false \
        --buildtype=release \
        --default-library=static \
        .. \
        --prefix $FFMPEGPREFIX \
        --bindir=$FFMPEGPREFIX/bin \
        --libdir=$FFMPEGPREFIX/lib
    ninja && ninja install
}

compile_ffmpeg()
{
    #-- ffmpeg
    wk_dir="ffmpeg/build"
    create_dir ${wk_dir} && cd ${wk_dir}

    PATH="$FFMPEGPATH" PKG_CONFIG_PATH="${FFMPEGPKGCONFIG}" ../configure \
        --prefix=$FFMPEGPREFIX \
        --pkg-config-flags="--static" \
        --extra-cflags="-I $FFMPEGPREFIX/include" \
        --extra-ldflags="-L $FFMPEGPREFIX/lib" \
        --extra-libs="-lpthread -lm" \
        --ld="g++" \
        --enable-libvorbis \
        --enable-gnutls \
        --enable-libaom \
        --enable-libass \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-sdl \
        --enable-gpl \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libfdk-aac \
        --enable-libopus \
        --enable-libsvtav1 \
        --enable-libdav1d \
        --enable-nonfree
    
    PATH="$FFMPEGPATH" make -j20 && make install
}

compile_distributor()
{
    components=$1
    cd $FFMPEGROOT

    echo ""
    if [ "${runOpt}" != "c" ]; then
        read -p "continue? [y/n/c] def[y]:" runOpt
        if [ "$runOpt" = "n" ];then exit 0; fi
    fi

    echo "======> compile ${components} <======"
    build_func="compile_${components}"
    echo "Build components: ${components}"
    echo "Build components func: ${build_func}"
    ${build_func}
    res=$?
    echo "======> compile ${components} finish res:${res} <======"
}


# ============> compile select <============
runOpt=""
setup_env
case $1 in
    'ffmpeg')
        compile_distributor "ffmpeg"
        ;;
    *)
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
        compile_distributor "ffmpeg"
esac

set +e
