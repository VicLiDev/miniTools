#!/usr/bin/env bash
#########################################################################
# File Name: ffmpeg_build_mac_test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri May 27 11:23:39 2022
#########################################################################

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
  --enable-debug=3 --disable-optimizations --disable-asm --disable-stripping 
  # --enable-libmp3lame \

make -j 20 && make install

# gcc /Users/lihongjin/Projects/ffmpeg/doc/examples/decode_video.c -o decode_video\
#     -I "${PWD}/ffmpeg_out/include" \
#     -L "${PWD}/ffmpeg_out/lib" \
#     -lavcodec -lavdevice -lavfilter -lavformat -lavutil

# gcc /Users/lihongjin/Projects/ffmpeg/doc/examples/decode_video.c -o decode_video \
#      -I "${PWD}/ffmpeg_out/include" \
#      -L "${PWD}/ffmpeg_out/lib" \
#      -lavcodec #-lavdevice -lavfilter -lavformat -lavutil
