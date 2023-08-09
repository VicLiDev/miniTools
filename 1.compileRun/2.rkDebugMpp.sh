#!/bin/bash
#########################################################################
# File Name: 2.rkDebugMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Aug  9 16:58:55 2023
#########################################################################

selectPlatform()
{
    echo "Please select platform:"
    echo "  1. android 32"
    echo "  2. android 64"
    echo "  3. linux 32"
    echo "  4. linux 64"
    read -p "Please select debug plt:" plt 
    if [ -n $plt ]; then
        case $plt in
            '1')
                dbgPltName="android_32"
                ToolPlatform="arm"
                ;;
            '2')
                dbgPltName="android_64"
                ToolPlatform="aarch64"
                ;;
            '3')
                dbgPltName="linux_32"
                ;;
            '4')
                dbgPltName="linux_64"
                ;;
        esac
    else
        plt="1"
        dbgPltName="android_32"
        echo "default platform: $dbgPltName"
    fi
}

selectTool()
{
    echo "Please select tool:"
    echo "  1. gdb"
    echo "  2. lldb"
    read -p "Please select debug tool:" dbgTool
    if [ -n $dbgTool ]; then
        case $dbgTool in
            '1')
                dbgToolName="gdb"
                ;;
            '2')
                dbgToolName="lldb"
                ;;
        esac
    else
        dbgTool="2"
        dbgToolName="lldb"
        echo "default dbg tool: $dbgToolName"
    fi
    return $dbgToolName
}

dbgLldb()
{
    # proc lldb tool
    NDKRoot="${HOME}/work/android/ndk/android-ndk-r23b"
    LldbPath="toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux"
    SelectedLldb="${NDKRoot}/${LldbPath}/${ToolPlatform}/lldb-server"
    devName="0"
    listenP="8888"
    echo "selected lldb-server: ${SelectedLldb}"
    adb push ${SelectedLldb} /vendor/bin
    
    
    # server
    startSerCmd="lldb-server p --server --listen \"*:$listenP\""
    echo "startSerCmd"
    adb shell $startSerCmd &
    
    
    # client
    debugCmdFile="debug.lldb"
    if [ ! -f $debugCmdFile ];then
        echo "platform select remote-android" > $debugCmdFile
        echo "platform connect connect://${devName}:$listenP" >> $debugCmdFile
        echo "platform settings -w /vendor/bin" >> $debugCmdFile
        echo "file mpi_dec_test" >> $debugCmdFile
        echo "b main" >> $debugCmdFile
        echo "r -i" >> $debugCmdFile
    fi
    lldb -s $debugCmdFile
}

dbgGdb()
{
    # proc lldb tool
    listenP="8888"

    # server
    startSerCmd="gdbserver localhost:$listenP"
    adb shell $startSerCmd &

    # client
    debugCmdFile="debug.gdb"
    if [ ! -f $debugCmdFile ];then
        echo "file mpi_dec_test" >> $debugCmdFile
        echo "start" > $debugCmdFile
    fi
    gdb-multiarch
}

selectTool
selectPlatform
echo "tool:$dbgToolName pltName:$dbgPltName"

if [ "$dbgToolName" = "gdb" ]; then
    dbgGdb
fi
if [ "$dbgToolName" = "lldb" ]; then
    dbgLldb
fi
