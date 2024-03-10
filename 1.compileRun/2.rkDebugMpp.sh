#!/bin/bash
#########################################################################
# File Name: 2.rkDebugMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Aug  9 16:58:55 2023
#########################################################################

# set -e

dbgPltName=""
dbgToolName=""
prjRoot=`pwd`

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    )

toolList=(
    "gdb"
    "lldb"
    )


displayPlts()
{
    echo "Please select platform:"
    for ((i = 0; i < ${#pltList[@]}; i++))
    do
        echo "  ${i}. ${pltList[${i}]}"
    done
}

displayTools()
{
    echo "Please select tool:"
    for ((i = 0; i < ${#toolList[@]}; i++))
    do
        echo "  ${i}. ${toolList[${i}]}"
    done
}

selectPlatform()
{
    displayPlts
    echo "cur dir: `pwd`"

    defPltIdx=0
    while [ True ]
    do
        read -p "Please select debug plt or quit(q), def[${defPltIdx}]:" pltIdx
        pltIdx=${pltIdx:-${defPltIdx}}

        if [ "${pltIdx}" == "q" ]; then
            echo "======> quit <======"
            exit 0
        elif [[ -n ${pltIdx} && -z `echo ${pltIdx} | sed 's/[0-9]//g'` ]]; then
            dbgPltName=${pltList[${pltIdx}]}
            echo "--> selected dbg index:${pltIdx}, tool:${dbgPltName}"
            break
        else
            dbgPltName=""
            echo "--> please input num in scope 0-`expr ${#pltList[@]} - 1`"
            continue
        fi
    done
}

selectTool()
{
    displayTools
    echo "cur dir: `pwd`"

    defDbgTool=0
    while [ True ]
    do
        read -p "Please select debug tool or quit(q), def[${defDbgTool}]:" dbgTool
        dbgTool=${dbgTool:-${defDbgTool}}

        if [ "${dbgTool}" == "q" ]; then
            echo "======> quit <======"
            exit 0
        elif [[ -n $dbgTool && -z `echo $dbgTool | sed 's/[0-9]//g'` ]]; then
            dbgToolName=${toolList[${dbgTool}]}
            echo "--> selected dbg index:${dbgTool}, tool:${dbgToolName}"
            break
        else
            dbgToolName=""
            echo "--> please input num in scope 0-`expr ${#toolList[@]} - 1`"
            continue
        fi
    done
}

dbgLldb()
{
    # proc lldb tool
    NDKRoot="${HOME}/work/android/ndk/android-ndk-r23b"
    LldbPath="toolchains/llvm/prebuilt/linux-x86_64/lib64/clang/12.0.8/lib/linux"
    if [ ${dbgPltName} == "android_32" ]; then
        LldbSer="${NDKRoot}/${LldbPath}/arm/lldb-server"
    fi
    if [ ${dbgPltName} == "android_64" ]; then
        LldbSer="${NDKRoot}/${LldbPath}/aarch64/lldb-server"
    fi
    devName=`adb devices | grep -v "List of devices attached" | cut -f 1`
    listenP="8888"
    echo "selected lldb-server: ${LldbSer}"
    haveSer=$(adb shell which lldb-server)
    if [ -z "$haveSer" ]; then adb push ${LldbSer} /vendor/bin; fi
    
    
    # server
    startSerCmd="lldb-server p --server --listen \"*:$listenP\""
    echo "startSerCmd"
    adb shell $startSerCmd &
    
    
    # client
    debugCmdFile="debug.lldb"
    if [ ! -e ${debugCmdFile} ];then
        echo "# pwd: `pwd`" > ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "platform select remote-android" >> ${debugCmdFile}
        echo "platform connect connect://${devName}:$listenP" >> ${debugCmdFile}
        echo "platform settings -w /vendor/bin" >> ${debugCmdFile}
        echo "file mpi_dec_test" >> ${debugCmdFile}
        echo "b main" >> ${debugCmdFile}
        echo "r -i" >> ${debugCmdFile}
    fi
    lldb -s ${debugCmdFile}
}

dbgGdbPrepareEnv()
{
    RemoteGdbSer=$1
    debugCmdFile=$2

    # create host mirror
    debugDirRoot="${prjRoot}/preinstall"
    debugDirBin=""
    debugDirLib=""
    debugDirBin2=""
    debugDirLib2=""
    debugBin=""
    debugLib=""

    if [ ${dbgPltName} == "android_32" ]; then
        debugDirBin="${debugDirRoot}/vendor/bin"
        debugDirLib="${debugDirRoot}/vendor/lib"
        if [ -e ${debugCmdFile} ]; then
            binFile=`cat ${debugCmdFile} | grep serverCmd | awk '{print $3}'`
        else
            binFile="mpi_dec_test"
        fi
        debugBin="${prjRoot}/build/android/arm/test/${binFile}"
        debugLib="${prjRoot}/build/android/arm/mpp/libmpp.so"
    elif [ ${dbgPltName} == "android_64" ]; then
        debugDirBin="${debugDirRoot}/vendor/bin"
        debugDirLib="${debugDirRoot}/vendor/lib64"
        if [ -e ${debugCmdFile} ]; then
            binFile=`cat debug.gdb | grep serverCmd | awk '{print $3}'`
        else
            binFile="mpi_dec_test"
        fi
        debugBin="${prjRoot}/build/android/aarch64/test/${binFile}"
        debugLib="${prjRoot}/build/android/aarch64/mpp/libmpp.so"
    elif [ ${dbgPltName} == "linux_32" ]; then
        debugDirBin="${debugDirRoot}/usr/bin"
        debugDirLib="${debugDirRoot}/usr/lib"
        debugDirBin2="${debugDirRoot}/oem/usr/bin"
        debugDirLib2="${debugDirRoot}/oem/usr/lib"
        if [ -e ${debugCmdFile} ]; then
            binFile=`cat debug.gdb | grep serverCmd | awk '{print $3}'`
        else
            binFile="mpi_dec_test"
        fi
        debugBin="${prjRoot}/build/linux/arm/test/${binFile}"
        debugLib="${prjRoot}/build/linux/arm/mpp/librockchip_mpp.so.0"
    elif [ ${dbgPltName} == "linux_64" ]; then
        debugDirBin="${debugDirRoot}/usr/bin"
        debugDirLib="${debugDirRoot}/usr/lib64"
        debugDirBin2="${debugDirRoot}/oem/usr/bin"
        debugDirLib2="${debugDirRoot}/oem/usr/lib64"
        if [ -e ${debugCmdFile} ]; then
            binFile=`cat debug.gdb | grep serverCmd | awk '{print $3}'`
        else
            binFile="mpi_dec_test"
        fi
        debugBin="${prjRoot}/build/linux/aarch64/test/${binFile}"
        debugLib="${prjRoot}/build/linux/aarch64/mpp/librockchip_mpp.so.0"
    fi
    echo "exec file: ${debugBin}"


    # Create the host library file structure
    if [ ! -e ${debugDirBin} ];then mkdir -p ${debugDirBin}; fi
    if [ ! -e ${debugDirLib} ];then mkdir -p ${debugDirLib}; fi
    if [[ -e ${debugBin} && -e ${debugDirBin} ]]; then cp ${debugBin} ${debugDirBin}; fi
    if [[ -e ${debugLib} && -e ${debugDirLib} ]]; then cp ${debugLib} ${debugDirLib}; fi

    if [ -n ${debugDirBin2} ]; then
        if [ ! -e ${debugDirBin2} ];then mkdir -p ${debugDirBin2}; fi
        if [[ -e ${debugBin} && -e ${debugDirBin2} ]]; then cp ${debugBin} ${debugDirBin2}; fi
    fi
    if [ -n ${debugDirLib2} ]; then
        if [ ! -e ${debugDirLib2} ];then mkdir -p ${debugDirLib2}; fi
        if [[ -e ${debugLib} && -e ${debugDirLib2} ]]; then cp ${debugLib} ${debugDirLib2}; fi
    fi


    # proc gdb tool
    # CCToolsRoot="${HOME}/Projects/prebuilts/toolschain/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf"
    CCToolsRoot="${HOME}/Projects/prebuilts/toolchains"
    if [[ ${dbgPltName} == "android_32" || ${dbgPltName} == "linux_32" ]]; then
        LocGdbSerPath="arm/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin"
        LocGdbSer="${CCToolsRoot}/${LocGdbSerPath}/gdbserver"
        if [[ -e ${LocGdbSer} && -e ${debugDirBin} ]]; then cp ${LocGdbSer} ${debugDirBin}/${RemoteGdbSer}; fi

        haveSer=$(adb shell which ${RemoteGdbSer})
        if [ -z "$haveSer" ]; then
            echo "push ${debugDirBin}/${RemoteGdbSer} to plt"
            if [ ${dbgPltName} == "android_32" ]; then
                adb push ${debugDirBin}/${RemoteGdbSer} /vendor/bin;
            else # [ ${dbgPltName} == "linux_32" ]; then
                adb push ${debugDirBin}/${RemoteGdbSer} /usr/bin;
                adb push ${debugDirBin}/${RemoteGdbSer} /oem/usr/bin;
            fi
        fi
    elif [[ ${dbgPltName} == "android_64" || ${dbgPltName} == "linux_64" ]]; then
        LocGdbSerPath="aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin"
        LocGdbSer="${CCToolsRoot}/${LocGdbSerPath}/gdbserver"
        if [[ -e ${LocGdbSer} && -e ${debugDirBin} ]]; then cp ${LocGdbSer} ${debugDirBin}/${RemoteGdbSer}; fi

        haveSer=$(adb shell which ${RemoteGdbSer})
        if [ -z "$haveSer" ]; then
            echo "push ${debugDirBin}/${RemoteGdbSer} to plt"
            if [ ${dbgPltName} == "android_64" ]; then
                adb push ${debugDirBin}/${RemoteGdbSer} /vendor/bin;
            else # [ ${dbgPltName} == "linux_64" ]; then
                adb push ${debugDirBin}/${RemoteGdbSer} /usr/bin;
                adb push ${debugDirBin}/${RemoteGdbSer} /oem/usr/bin;
            fi
        fi
    else
        echo "RemoteGdbSer select error"
    fi
}

dbgGdbRun()
{
    RemoteGdbSer=$1
    debugCmdFile=$2

    # CCToolsRoot="${HOME}/work/android/ndk/android-ndk-r16b"
    # GdbPath="prebuilt/linux-x86_64/bin"
    # Gdb="${CCToolsRoot}/${GdbPath}/gdb"
    HostGdb="gdb-multiarch"

    listenP="8899"
    localP="8898"

    echo "selected gdbserver: ${RemoteGdbSer}"
    echo "selected gdb: ${HostGdb}"
    adb forward tcp:${localP} tcp:${listenP}
    echo "adb port map:"
    adb forward --list
    # adb push ${GdbSer} /vendor/bin


    # server
    # mpp cmd
    if [ -e ${debugCmdFile} ];then
        MppCmd=`cat ${debugCmdFile} | grep serverCmd | sed 's/.*serverCmd: //g'`;
    else
        MppCmd="mpi_dec_test -i /sdcard/test.h264"
    fi
    echo "server cmd: ${MppCmd}"
    startSerCmd="${RemoteGdbSer} localhost:$listenP ${MppCmd}"
    adb shell $startSerCmd &
    echo ""


    # client
    if [ ! -e ${debugCmdFile} ];then
        echo "# pwd: `pwd`" > ${debugCmdFile}
        echo "# serverCmd: mpi_dec_test -h" >> ${debugCmdFile}
        echo "# --attach <PID>" >> ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "# local sets" >> ${debugCmdFile}
        echo "# if --attach <pid> cancel this instruction" >> ${debugCmdFile}
        echo "set sysroot preinstall/" >> ${debugCmdFile}
        echo "# set solib-search-path preinstall/vendor/lib" >> ${debugCmdFile}
        echo "# cd preinstall" >> ${debugCmdFile}
        echo "# file preinstall/vendor/bin/mpi_dec_test" >> ${debugCmdFile}
        echo "# load preinstall/vendor/lib/libmpp.so" >> ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "# target sets" >> ${debugCmdFile}
        echo "target remote :${localP}" >> ${debugCmdFile}
        echo "# set sysroot remote:/" >> ${debugCmdFile}
        echo "# set solib-search-path target:/vendor/lib:/system/lib" >> ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "b main" >> ${debugCmdFile}
        echo "continue" >> ${debugCmdFile}
        echo "layout src" >> ${debugCmdFile}
    fi
    # gdb-multiarch
    ${HostGdb} --command=${debugCmdFile}


    adb forward --remove tcp:${localP}
    echo "adb port map:"
    adb forward --list
}

dbgGdb()
{
    debugCmdFile="debug.gdb"

    if [[ ${dbgPltName} == "android_32" || ${dbgPltName} == "linux_32" ]]; then
        RemoteGdbSer="gdbserver"
    elif [[ ${dbgPltName} == "android_64" || ${dbgPltName} == "linux_64" ]]; then
        RemoteGdbSer="gdbserver64"
    fi

    dbgGdbPrepareEnv ${RemoteGdbSer} ${debugCmdFile}
    dbgGdbRun ${RemoteGdbSer} ${debugCmdFile}
}

dbgGdb_x86()
{
    debugCmdFile="debug_x86.gdb"


    # server
    # mpp cmd
    HostGdb="gdb"
    if [ -e ${debugCmdFile} ];then
        MppCmd=`cat ${debugCmdFile} | grep serverCmd | sed 's/.*serverCmd: //g'`;
    else
        MppCmd="./build/linux/x86_64/test/mpi_dec_test -i ~/rk.h265"
    fi
    echo "run cmd: ${MppCmd}"
    echo ""


    # client
    if [ ! -e ${debugCmdFile} ];then
        echo "# pwd: `pwd`" > ${debugCmdFile}
        echo "# serverCmd: ./build/linux/x86_64/test/mpi_dec_test -h" >> ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "start" >> ${debugCmdFile}
        echo "layout src" >> ${debugCmdFile}
    fi
    # gdb-multiarch
    ${HostGdb} --command=${debugCmdFile} --args ${MppCmd}
}

selectTool
selectPlatform
echo "tool:$dbgToolName pltName:$dbgPltName"

if [ "$dbgToolName" = "gdb" ]; then
    if [ ${dbgPltName} != "linux_x86_64" ]; then
        dbgGdb
    else
        dbgGdb_x86
    fi
elif [ "$dbgToolName" = "lldb" ]; then
    dbgLldb
fi

# set +e
