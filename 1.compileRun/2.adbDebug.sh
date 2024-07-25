#!/usr/bin/env bash
#########################################################################
# File Name: adbdebug.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu Jul 21 10:03:21 2022
#########################################################################

help(){
    echo "<app> l : select lldb"
    echo "<app> g : select gdb"
}

if [ $# -lt 1 ]; then
    SelectedTool="lldb"
    echo "default select lldb"
else
    case $1 in
        'l')
            SelectedTool="lldb"
            echo "select lldb"
            ;;
        'g')
            SelectedTool="gdb"
            echo "select gdb"
            ;;
        *)
            help
            exit
            ;;
    esac
fi
echo ""


if  [ "${SelectedTool}" = "lldb" ]; then
    NDKRoot="${HOME}/work/android/ndk/android-ndk-r23b"
    LldbPath="toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux"
    Platform="arm"
    # Platform="aarch64"
    # Platform="x86_64"
    # Platform="i386"
    SelectedLldb="${NDKRoot}/${LldbPath}/${Platform}/lldb-server"
    adb push ${SelectedLldb} /vendor/bin
    echo "selected lldb-server: ${SelectedLldb}"
    echo ""
    echo "====> embedded platform <===="
    echo "cd /vendor/bin"
    echo "lldb-server p --server --listen \"*:8888\""
    echo ""
    echo "====> PC platform <===="
    echo "platform select remote-android"
    echo "platform connect connect://0:8888"
    echo "platform settings -w <path: local or remote>"
    echo "file mpi_dec_test"
    echo "r -i /sdcard/output.h264 -t 7"
elif [ ${SelectedTool} = "gdb" ]; then
    adb forward tcp:8887 tcp:8888
    adb forward --list
    echo "local port:  8887"
    echo "remote port: 8888"
    echo ""

    echo "====> embedded platform <===="
    echo "gdbserver :8888   <app> <param>"
    echo "gdbserver :8888   --attach <pid>"
    echo ""

    echo "====> PC platform <===="
    echo "android app:"
    echo "    /home/lhj/work/android/ndk/android-ndk-r23b/prebuilt/linux-x86_64/bin/gdb"
    echo "    /home/lhj/work/android/ndk/android-ndk-r16b/prebuilt/linux-x86_64/bin/gdb"
    echo "    /home/lhj/work/android/ndk/android-ndk-r16b/prebuilt/linux-x86_64/bin/ndk-gdb"
    echo "gdb <app/lib>"
    echo "(gdb) target remote 127.0.0.1:8887"
else
    help
fi
