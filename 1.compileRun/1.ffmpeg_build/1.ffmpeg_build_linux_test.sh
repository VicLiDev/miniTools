#!/usr/bin/env bash
#########################################################################
# File Name: compile.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri May 27 11:23:39 2022
#########################################################################

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

# ln -s ${HOME}/Projects/miniTools/1.compileRun/1.ffmpeg_build_linux_test.sh .prjBuild.sh

prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.dir_file_opt.sh

create_dir build

cd build

../configure \
  --prefix="${PWD}/ffmpeg_out" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I ${PWD}/ffmpeg_out/include" \
  --extra-ldflags="-L ${PWD}/ffmpeg_out/lib" \
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

echo
echo
echo
echo "build mini demo"
gcc ../doc/examples/decode_video.c -o decode_video\
    -I ./ffmpeg_out/include \
    -L ./ffmpeg_out/lib \
    -lavcodec -lavfilter -lavformat -lavutil -lpthread -lm -lz -lX11 \
    -lva -lvdpau -lva-x11 -lva-drm -lvorbis -lvorbisenc -llzma -lswresample -lmp3lame -laom



# all static build
# ../configure --disable-ffplay --disable-indev=sndio --disable-outdev=sndio \
#     --extra-libs='-static -L/usr/lib' --extra-cflags='--static' \
#     --enable-gpl --enable-stripping
