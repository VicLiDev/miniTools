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
  --enable-debug --disable-optimizations --disable-asm --disable-stripping 

make -j 20 && make install

gcc ../doc/examples/decode_video.c -o decode_video\
    -I ./ffmpeg_out/include \
    -L ./ffmpeg_out/lib \
    -lavcodec -lavfilter -lavformat -lavutil -lpthread -lm -lz -lX11 \
    -lva -lvdpau -lva-x11 -lva-drm -lvorbis -lvorbisenc -llzma -lswresample -lmp3lame -laom
