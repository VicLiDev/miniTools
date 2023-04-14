#########################################################################
# File Name: compile.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri May 27 11:23:39 2022
#########################################################################
#!/bin/bash

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
  --enable-debug --disable-optimizations --disable-asm --disable-stripping 
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
