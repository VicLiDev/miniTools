#########################################################################
# File Name: ffmpegbuild.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2022年05月27日 星期五 14时49分55秒
#########################################################################
#!/bin/bash

set -e

setup_env()
{
    # create directory
    if [ ! -d "${HOME}/Projects/ffmpeg_source" ]; then
        echo "create dir ${HOME}/Projects/ffmpeg_source"
        mkdir ~/Projects/ffmpeg_source
    fi
    if [ ! -d "${HOME}/Projects/ffmpeg_source/bin" ]; then
        echo "create dir ${HOME}/Projects/ffmpeg_source/bin"
        mkdir ~/Projects/ffmpeg_source/bin
    fi
    if [ ! -d "${HOME}/Projects/ffmpeg_source/ffmpeg_build" ]; then
        echo "create dir ${HOME}/Projects/ffmpeg_source/ffmpeg_build"
        mkdir ~/Projects/ffmpeg_source/ffmpeg_build
    fi
    
    # set env
    FFMPEGPATH="$HOME/Projects/ffmpeg_source/bin:$PATH" && \
        FFMPEGPREFIX="$HOME/Projects/ffmpeg_source/ffmpeg_build" && \
        FFMPEGBIN="$HOME/Projects/ffmpeg_source/bin" && \
        FFMPEGPKGCONFIG="$HOME/Projects/ffmpeg_build/lib/pkgconfig" && \
        FFMPEGROOT="$HOME/Projects/ffmpeg_source"
}

compile_nasm()
{
    #-- nasm
    cd $FFMPEGROOT
    echo "======> compile nasm <======"
    if [ ! -d "nasm-2.15.05" ]; then
        mkdir nasm-2.15.05
    fi
    cd nasm-2.15.05
    ./autogen.sh && PATH=$FFMPEGPATH ./configure --prefix=$HOME/ffmpeg_build --bindir=$FFMPEGBIN
    make -j20 && make install
    echo "======> compile nasm finish <======"
}

compile_x264()
{
    #-- 264
    cd $FFMPEGROOT
    echo "======> compile x264 <======"
    if [ ! -d "x264" ]; then
        mkdir x264
    fi
    cd x264
    PATH=$FFMPEGPATH PKG_CONFIG_PATH=$FFMPEGPKGCONFIG ./configure --prefix=$FFMPEGPREFIX --bindir=$FFMPEGBIN --enable-static --enable-pic
    PATH=$FFMPEGPATH make -j 20 && make install
    echo "======> compile x264 finish <======"
}

compile_x265()
{
    #-- 265
    cd $FFMPEGROOT
    echo "======> compile x265 <======"
    if [ ! -d "multicoreware-x265_git-e3713124dccd/build/linux" ]; then
        mkdir multicoreware-x265_git-e3713124dccd/build/linux
    fi
    cd multicoreware-x265_git-e3713124dccd/build/linux
    PATH=$FFMPEGPATH cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX -DENABLE_SHARED=off ../../source
    PATH=$FFMPEGPATH make -j20 && make install
    echo "======> compile x265 finish <======"
}

compile_vpx()
{
    #-- vpx
    cd $FFMPEGROOT
    echo "======> compile vpx <======"
    if [ ! -d "libvpx-1.9.0" ]; then
        mkdir libvpx-1.9.0
    fi
    cd libvpx-1.9.0
    PATH=$FFMPEGPATH ./configure --prefix=$FFMPEGPREFIX --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm
    PATH=$FFMPEGPATH make -j 20 && make install
    echo "======> compile vpx finish <======"
}

compile_fdkaac()
{
    #-- fdkaac
    cd $FFMPEGROOT
    echo "======> compile fdkaac <======"
    if [ ! -d "fdk-aac-master" ]; then
        mkdir fdk-aac-master
    fi
    cd fdk-aac-master
    autoreconf -fiv && ./configure --prefix=$FFMPEGPREFIX --disable-shared
    make -j20 && make install
    echo "======> compile fdkaac finish <======"
}

compile_opus()
{
    #-- opus
    cd $FFMPEGROOT
    echo "======> compile opus <======"
    if [ ! -d "opus-master" ]; then
        mkdir opus-master
    fi
    cd opus-master
    ./autogen.sh && ./configure --prefix=$FFMPEGPREFIX --disable-shared
    make -j 20 && make install
    echo "======> compile opus finish <======"
}

compile_aom()
{
    #-- aom
    cd $FFMPEGROOT
    echo "======> compile aom <======"
    if [ ! -d "aom_build" ]; then
        mkdir aom_build
    fi
    cd aom_build
    PATH="$FFMPEGPATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX -DENABLE_TESTS=OFF -DENABLE_NASM=on ../aom
    PATH=$FFMPEGPATH make -j20 && make install
    echo "======> compile aom finish <======"
}

compile_svt()
{
    #-- svt
    cd $FFMPEGROOT
    echo "======> compile svt <======"
    if [ ! -d "SVT-AV1/build" ]; then
        mkdir SVT-AV1/build
    fi
    cd SVT-AV1/build
    PATH=$FFMPEGPATH cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=$FFMPEGPREFIX -DCMAKE_BUILD_TYPE=Release -DBUILD_DEC=OFF -DBUILD_SHARED_LIBS=OFF ..
    PATH=$FFMPEGPATH make -j20 && make install
    echo "======> compile svt finish <======"
}

compile_dav1d()
{
    #-- dav1d
    cd $FFMPEGROOT
    echo "======> compile dav1d <======"
    if [ ! -d "dav1d/build" ]; then
        mkdir dav1d/build
    fi
    cd dav1d/build
    meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix $FFMPEGPREFIX --libdir=$FFMPEGPREFIX/bin
    ninja && ninja install
    echo "======> compile dav1d finish <======"
}

compile_vmaf()
{
    #-- vmaf
    cd $FFMPEGROOT
    echo "======> compile vmaf <======"
    if [ ! -d "vmaf-2.1.1/libvmaf/build" ]; then
        mkdir vmaf-2.1.1/libvmaf/build
    fi
    cd vmaf-2.1.1/libvmaf/build
    meson setup -Denable_tests=false -Denable_docs=false --buildtype=release \
        --default-library=static .. --prefix $FFMPEGPREFIX --bindir=$FFMPEGPREFIX/bin --libdir=$FFMPEGPREFIX/lib
    ninja && ninja install
    echo "======> compile vmaf finish <======"
}

compile_ffmpeg()
{
    #-- ffmpeg
    cd $FFMPEGROOT
    echo "======> compile ffmpeg <======"
    if [ ! -d "ffmpeg/build" ]; then
        mkdir ffmpeg/build
    fi
    cd ffmpeg/build
    PATH="$FFMPEGPATH" PKG_CONFIG_PATH="FFMPEGPKGCONFIG" ../configure \
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
    echo "======> compile ffmpeg finish <======"
}


# ============> compile select <============
setup_env
case $1 in
    'all')
        compile_nasm
        compile_x264
        compile_x265
        compile_vpx
        compile_fdkaac
        compile_opus
        compile_aom
        compile_svt
        compile_dav1d
        compile_vmaf
        compile_ffmpeg
        ;;
    'ffmpeg')
        compile_ffmpeg
        ;;
    *)
        compile_nasm
        compile_x264
        compile_x265
        compile_vpx
        compile_fdkaac
        compile_opus
        compile_aom
        compile_svt
        compile_dav1d
        compile_vmaf
        compile_ffmpeg
esac

set +e
