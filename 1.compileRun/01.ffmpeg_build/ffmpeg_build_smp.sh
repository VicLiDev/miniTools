#!/usr/bin/env bash
#########################################################################
# File Name: ffmpeg_build_smp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri May 27 11:23:39 2022
#########################################################################

# ==> for linux
# sudo apt-get install libaom-dev
# sudo apt-get install libx264-dev
# sudo apt-get install libx265-dev
# sudo apt-get install libvpx-dev
# sudo apt-get install libfdk-aac-dev
# sudo apt-get install libopus-dev
# sudo apt-get install libsvtav1-dev
# sudo apt-get install libsvtav1enc-dev
# sudo apt-get install libdav1d-dev
# sudo apt-get install libva-dev
# sudo apt-get install libvdpau-dev
# sudo apt-get install libva-x11-2
# sudo apt-get install libva-drm2
# sudo apt-get install liblzma-dev

sel_tag_ffmpeg_b_smp="ffmpeg_b_smp:"
install_pfx="$(pwd)/ffmpeg_out"

build_tp_lst=(
    "ffmpeg"
    "demo"
    )
m_sel_type=""

function build_ffmpeg_linux()
{
    if [ "${m_sel_type}" = "ffmpeg" ]
    then
        ../configure \
            --prefix="${install_pfx}" \
            --pkg-config=pkg-config
            --pkg-config-flags="--static" \
            --extra-cflags="-I ${install_pfx}/include" \
            --extra-ldflags="-L ${install_pfx}/lib" \
            --extra-libs="-lpthread -lm" \
            --ld="g++" \
            --bindir="$HOME/bin" \
            --enable-libvorbis \
            --enable-gnutls \
            --enable-libaom \
            --enable-libass \
            --enable-libfreetype \
            --enable-libfontconfig \
            --enable-libfribidi \
            --enable-libharfbuzz \
            --enable-libmp3lame \
            --enable-gpl \
            --enable-libx264 \
            --enable-libx265 \
            --enable-libvpx \
            --enable-libfdk-aac \
            --enable-libopus \
            --enable-libsvtav1 \
            --enable-libdav1d \
            --enable-nonfree \
            --enable-debug=3 --disable-optimizations --disable-asm --disable-stripping

        make -j 20 && make install
    fi

    if [ "${m_sel_type}" = "demo" ]
    then
        echo "build mini demo"
        gcc ../doc/examples/decode_video.c -o decode_video\
            -I ${install_pfx}/include \
            -L ${install_pfx}/lib \
            -lavcodec -lavfilter -lavformat -lavutil -lpthread -lm -lz -lX11 -ldrm \
            -lva -lvdpau -lva-x11 -lva-drm -lvorbis -lvorbisenc -llzma -lswresample -lmp3lame -laom
    fi


    # all static build
    # ../configure --disable-ffplay --disable-indev=sndio --disable-outdev=sndio \
    #     --extra-libs='-static -L/usr/lib' --extra-cflags='--static' \
    #     --enable-gpl --enable-stripping
}

function build_ffmpeg_mac()
{
    if [ "${m_sel_type}" = "ffmpeg" ]
    then
        ../configure \
            --prefix="${install_pfx}" \
            --pkg-config-flags="--static" \
            --extra-cflags="-I ${install_pfx}/include" \
            --extra-ldflags="-L ${install_pfx}/lib" \
            --extra-libs="-lpthread -lm" \
            --ld="g++" \
            --bindir="$HOME/bin" \
            --enable-libvorbis \
            --enable-gnutls \
            --enable-libaom \
            --enable-libass \
            --enable-libfreetype \
            --enable-debug=3 --disable-optimizations --disable-asm --disable-stripping 
            # --enable-libmp3lame \
        
        make -j 20 && make install
    fi

    if [ "${m_sel_type}" = "demo" ]
    then
        gcc /Users/lihongjin/Projects/ffmpeg/doc/examples/decode_video.c -o decode_video\
            -I "${install_pfx}/include" \
            -L "${install_pfx}/lib" \
            -lavcodec -lavdevice -lavfilter -lavformat -lavutil
        
        gcc /Users/lihongjin/Projects/ffmpeg/doc/examples/decode_video.c -o decode_video \
             -I "${install_pfx}/include" \
             -L "${install_pfx}/lib" \
             -lavcodec #-lavdevice -lavfilter -lavformat -lavutil
    fi
}

function main()
{
    source ${HOME}/bin/_dir_file_opt.sh
    source ${HOME}/bin/_select_node.sh

    select_node "${sel_tag_ffmpeg_b_smp}" "build_tp_lst" "m_sel_type" "build type"

    create_dir ${install_pfx}
    create_dir build
    cd build


    [ $(uname -s) = "Linux" ] && { echo "======> build ffmpeg-linux"; build_ffmpeg_linux; }
    [ $(uname -s) = "Darwin" ] && { echo "======> build ffmpeg-mac"; build_ffmpeg_mac; }
}

main "$@"
