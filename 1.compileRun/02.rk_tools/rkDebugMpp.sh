#!/usr/bin/env bash
#########################################################################
# File Name: rkDebugMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Aug  9 16:58:55 2023
#########################################################################

# set -e

dbgPltName=""
dbgToolName=""
prjRoot=`git rev-parse --show-toplevel`
adbCmd=""

sel_tag_plt="rk_mpp_plt_d: "
sel_tag_tool="rk_mpp_tool_d: "

pltList=(
    "android_32"
    "android_64"
    "linux_32"
    "linux_64"
    "linux_x86_64"
    )

toolList=(
    "gdb"
    "gdbNet"
    "lldb"
    )


function dbgLldb()
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
    devName=`${adbCmd} devices | grep -v "List of devices attached" | cut -f 1`
    listenP="8888"
    echo "selected lldb-server: ${LldbSer}"
    haveSer=$(${adbCmd} shell which lldb-server)
    if [ -z "$haveSer" ]; then ${adbCmd} push ${LldbSer} /vendor/bin; fi
    
    
    # server
    startSerCmd="lldb-server p --server --listen \"*:$listenP\""
    echo "startSerCmd"
    ${adbCmd} shell $startSerCmd &
    
    
    # client
    debugCmdFile="${prjRoot}/debug.lldb"
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

function dbgGdbPrepareEnv()
{
    RemoteGdbSer=$1
    debugCmdFile=$2

    # create host mirror
    dbgRootDir="${prjRoot}/preinstall"
    dbgBinSrcDir=()
    dbgLibSrcDir=()
    dbgBinDstDir=()
    dbgLibDstDir=()

    if [ ${dbgPltName} == "android_32" ]; then
        dbgBinSrcDir[0]="${prjRoot}/build/android/arm/test"
        dbgBinSrcDir[1]="${prjRoot}/build/android/arm/mpp/base/test"
        dbgLibSrcDir[0]="${prjRoot}/build/android/arm/mpp"

        dbgBinDstDir[0]="${dbgRootDir}/vendor/bin"
        dbgBinDstDir[1]="${dbgRootDir}/system/bin"
        dbgLibDstDir[0]="${dbgRootDir}/vendor/lib"
        dbgLibDstDir[1]="${dbgRootDir}/system/lib"
    elif [ ${dbgPltName} == "android_64" ]; then
        dbgBinSrcDir[0]="${prjRoot}/build/android/aarch64/test"
        dbgBinSrcDir[1]="${prjRoot}/build/android/aarch64/mpp/base/test"
        dbgLibSrcDir[0]="${prjRoot}/build/android/aarch64/mpp"

        dbgBinDstDir[0]="${dbgRootDir}/vendor/bin"
        dbgBinDstDir[1]="${dbgRootDir}/system/bin"
        dbgLibDstDir[0]="${dbgRootDir}/vendor/lib64"
        dbgLibDstDir[1]="${dbgRootDir}/system/lib64"
    elif [ ${dbgPltName} == "linux_32" ]; then
        dbgBinSrcDir[0]="${prjRoot}/build/linux/arm/test"
        dbgBinSrcDir[1]="${prjRoot}/build/linux/arm/mpp/base/test"
        dbgLibSrcDir[0]="${prjRoot}/build/linux/arm/mpp"

        dbgBinDstDir[0]="${dbgRootDir}/usr/bin"
        dbgBinDstDir[1]="${dbgRootDir}/oem/usr/bin"
        dbgLibDstDir[0]="${dbgRootDir}/usr/lib"
        dbgLibDstDir[1]="${dbgRootDir}/oem/usr/lib"
    elif [ ${dbgPltName} == "linux_64" ]; then
        dbgBinSrcDir[0]="${prjRoot}/build/linux/aarch64/test"
        dbgBinSrcDir[1]="${prjRoot}/build/linux/aarch64/mpp/base/test"
        dbgLibSrcDir[0]="${prjRoot}/build/linux/aarch64/mpp"

        dbgBinDstDir[0]="${dbgRootDir}/usr/bin"
        dbgBinDstDir[1]="${dbgRootDir}/oem/usr/bin"
        dbgBinDstDir[2]="${dbgRootDir}/bin"
        dbgLibDstDir[0]="${dbgRootDir}/usr/lib64"
        dbgLibDstDir[1]="${dbgRootDir}/oem/usr/lib64"
        dbgLibDstDir[2]="${dbgRootDir}/lib64"
    fi
    echo "exec bins dir: ${debugBin}"


    # Create the host library file structure
    # for dst dir
    for ((i = 0; i < ${#dbgBinDstDir[@]}; i++))
    do
        create_dir ${dbgBinDstDir[i]}
        create_dir ${dbgLibDstDir[i]}
        for ((j = 0; j < ${#dbgBinSrcDir[@]}; j++))
        do
            update_bins ${dbgBinSrcDir[j]} ${dbgBinDstDir[i]}
        done
        for ((j = 0; j < ${#dbgLibSrcDir[@]}; j++))
        do
            update_bins ${dbgLibSrcDir[j]} ${dbgLibDstDir[i]}
        done
    done

    # gdbNet do not need to proc tool
    if [ "${dbgToolName}" == "gdbNet" ]; then
        runOpt=""
        read -p "gdbNet need proc gdb tools? (y/[n])]:" -t 1 runOpt
        if [ "$runOpt" != "y" ]; then return 0; fi
    fi

    # proc gdb tool
    # CCToolsRoot="${HOME}/Projects/prebuilts/toolschain/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf"
    CCToolsRoot="${HOME}/Projects/prebuilts/toolchains"
    if [[ ${dbgPltName} == "android_32" || ${dbgPltName} == "linux_32" ]]; then
        LocGdbSerPath="arm/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin"
        LocGdbSer="${CCToolsRoot}/${LocGdbSerPath}/gdbserver"
        update_file ${LocGdbSer} ${dbgBinDstDir[0]}/${RemoteGdbSer}

        haveSer=$(${adbCmd} shell which ${RemoteGdbSer})
        if [ -z "$haveSer" ]; then
            echo "push ${dbgBinDstDir[0]}/${RemoteGdbSer} to plt"
            if [ ${dbgPltName} == "android_32" ]; then
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /vendor/bin;
            else # [ ${dbgPltName} == "linux_32" ]; then
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /usr/bin;
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /oem/usr/bin;
            fi
        fi
    elif [[ ${dbgPltName} == "android_64" || ${dbgPltName} == "linux_64" ]]; then
        LocGdbSerPath="aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin"
        LocGdbSer="${CCToolsRoot}/${LocGdbSerPath}/gdbserver"
        update_file ${LocGdbSer} ${dbgBinDstDir[0]}/${RemoteGdbSer}

        haveSer=$(${adbCmd} shell which ${RemoteGdbSer})
        if [ -z "$haveSer" ]; then
            echo "push ${dbgBinDstDir[0]}/${RemoteGdbSer} to plt"
            if [ ${dbgPltName} == "android_64" ]; then
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /vendor/bin;
            else # [ ${dbgPltName} == "linux_64" ]; then
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /usr/bin;
                ${adbCmd} push ${dbgBinDstDir[0]}/${RemoteGdbSer} /oem/usr/bin;
            fi
        fi
    else
        echo "RemoteGdbSer select error"
    fi
}

function dbgGdbRun()
{
    RemoteGdbSer=$1
    debugCmdFile=$2

    # CCToolsRoot="${HOME}/work/android/ndk/android-ndk-r16b"
    # GdbPath="prebuilt/linux-x86_64/bin"
    # Gdb="${CCToolsRoot}/${GdbPath}/gdb"
    HostGdb="gdb-multiarch"

    devIP="localhost"
    listenP="8899"
    localP="8898"

    echo "selected gdbserver: ${RemoteGdbSer}"
    echo "selected gdb: ${HostGdb}"
    if [ "${dbgToolName}" == "gdbNet" ]; then
        listenP=${localP}
    else
        ${adbCmd} forward tcp:${localP} tcp:${listenP}
        echo "${adbCmd} port map:"
        ${adbCmd} forward --list
        # ${adbCmd} push ${GdbSer} /vendor/bin
    fi


    # server
    # mpp cmd
    if [ -e ${debugCmdFile} ];then
        MppCmd=`cat ${debugCmdFile} | grep serverCmd | sed 's/.*serverCmd: //g'`;
        devIP=`cat ${debugCmdFile} | grep "^target" | sed 's/[a-z]* //g' | sed 's/:[0-9]*//g'`
    else
        MppCmd="mpi_dec_test -i /sdcard/test.h264"
        devIP="localhost"
    fi
    if [[ "${dbgToolName}" == "gdbNet" && ${devIP} == "localhost" ]]; then
        read -p "Please input dev ip: " devIP
        sed -i "s/^target.*/target remote ${devIP}:${localP}/" ${debugCmdFile}
    fi
    if [[ "${dbgToolName}" != "gdbNet" && ${devIP} != "localhost" ]]; then
        devIP="localhost"
        sed -i "s/^target.*/target remote ${devIP}:${localP}/" ${debugCmdFile}
    fi
    startSerCmd="${RemoteGdbSer} ${devIP}:${listenP} ${MppCmd}"
    echo "server cmd: ${startSerCmd}"
    if [ "${dbgToolName}" == "gdbNet" ]; then
        read -p "Please exec cmd in dev: << ${startSerCmd} >>"
    else
        ${adbCmd} shell $startSerCmd &
    fi
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
        echo "target remote ${devIP}:${localP}" >> ${debugCmdFile}
        echo "# set sysroot remote:/" >> ${debugCmdFile}
        echo "# set solib-search-path target:/vendor/lib:/system/lib" >> ${debugCmdFile}
        echo "" >> ${debugCmdFile}

        echo "b main" >> ${debugCmdFile}
        echo "continue" >> ${debugCmdFile}
        echo "layout src" >> ${debugCmdFile}
    fi
    # gdb-multiarch
    ${HostGdb} --command=${debugCmdFile}


    if [ "${dbgToolName}" != "gdbNet" ]; then
        ${adbCmd} forward --remove tcp:${localP}
        echo "${adbCmd} port map:"
        ${adbCmd} forward --list
    fi
}

function dbgGdb()
{
    debugCmdFile="${prjRoot}/debug.gdb"

    if [[ ${dbgPltName} == "android_32" || ${dbgPltName} == "linux_32" ]]; then
        RemoteGdbSer="gdbserver"
    elif [[ ${dbgPltName} == "android_64" || ${dbgPltName} == "linux_64" ]]; then
        RemoteGdbSer="gdbserver64"
    fi

    dbgGdbPrepareEnv ${RemoteGdbSer} ${debugCmdFile}
    dbgGdbRun ${RemoteGdbSer} ${debugCmdFile}
}

function dbgGdb_x86()
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

function main()
{
    adbCmd=$(adbs)
    [ -z "${adbCmd}" ] && exit 0
    source ${HOME}/bin/_dir_file_opt.sh
    source ${HOME}/bin/_select_node.sh
    select_node "${sel_tag_tool}" "toolList" "dbgToolName" "debug tool"
    select_node "${sel_tag_plt}" "pltList" "dbgPltName" "debug plt"
    echo "tool:$dbgToolName pltName:$dbgPltName"

    cd ${prjRoot}

    if [ -n "`echo $dbgToolName | grep gdb`" ]; then
        if [ ${dbgPltName} != "linux_x86_64" ]; then
            dbgGdb
        else
            dbgGdb_x86
        fi
    elif [ "$dbgToolName" = "lldb" ]; then
        dbgLldb
    fi
}

main "$@"

# set +e
