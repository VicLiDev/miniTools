#!/usr/bin/env bash
#########################################################################
# File Name: 2.tarMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Mar 2024 04:18:38 PM CST
#########################################################################

# usage: ./2.tarMpp.sh -a -l
# -a: tar android lib
# -l: tar linux lib

mppRoot="${HOME}/Projects/mpp"
tarPkgName="mpplib.tar.gz"
mppLibDir="mpplib"
pushTool="push.sh"
logFile="ReadMe.md"


android_32_dir="${mppLibDir}/android_32"
android_64_dir="${mppLibDir}/android_64"
linux_32_dir="${mppLibDir}/linux_32"
linux_64_dir="${mppLibDir}/linux_64"

en_android="False"
en_linux="False"

function help()
{
    echo "usage: ./2.tarMpp.sh -a -l"
    echo "  -a: tar android lib"
    echo "  -l: tar linux lib"
}

function procParas()
{
    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -a)
                en_android="True"
                ;;
            -l)
                en_linux="True"
                ;;
            *)
                echo "unknow para: ${key}"
                exit 1
                ;;
        esac
        shift
    done
}


function update_android()
{
    # android
    create_dir ${android_32_dir}
    create_dir ${android_64_dir}

    update_file ${mppRoot}/build/android/arm/mpp/libmpp.so                ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/mpp/legacy/libvpu.so         ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/test/mpi_dec_test            ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/test/mpi_dec_mt_test         ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/test/mpi_dec_multi_test      ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/test/mpi_enc_test            ${android_32_dir}
    update_file ${mppRoot}/build/android/arm/test/mpi_enc_mt_test         ${android_32_dir}
    update_file ${mppRoot}/build/android/aarch64/mpp/libmpp.so            ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/mpp/legacy/libvpu.so     ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/test/mpi_dec_test        ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/test/mpi_dec_mt_test     ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/test/mpi_dec_multi_test  ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/test/mpi_enc_test        ${android_64_dir}
    update_file ${mppRoot}/build/android/aarch64/test/mpi_enc_mt_test     ${android_64_dir}

    echo "adb push android_32/libmpp.so          /vendor/lib"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/libvpu.so          /vendor/lib"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/libmpp.so          /system/lib"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/libvpu.so          /system/lib"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/mpi_dec_test       /vendor/bin"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/mpi_enc_test       /vendor/bin"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/mpi_dec_mt_test    /vendor/bin"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/mpi_dec_multi_test /vendor/bin"   >> ${mppLibDir}/${pushTool}
    echo "adb push android_32/mpi_enc_mt_test    /vendor/bin"   >> ${mppLibDir}/${pushTool}

    echo "adb push android_64/libmpp.so          /vendor/lib64" >> ${mppLibDir}/${pushTool}
    echo "adb push android_64/libvpu.so          /vendor/lib64" >> ${mppLibDir}/${pushTool}
    echo "adb push android_64/libmpp.so          /system/lib64" >> ${mppLibDir}/${pushTool}
    echo "adb push android_64/libvpu.so          /system/lib64" >> ${mppLibDir}/${pushTool}
}

function update_linux()
{
    # linux
    create_dir ${linux_32_dir}
    create_dir ${linux_64_dir}

    update_file ${mppRoot}/build/linux/arm/mpp/librockchip_mpp.so.0            ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/mpp/legacy/librockchip_vpu.so.0     ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/test/mpi_dec_test                   ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/test/mpi_dec_mt_test                ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/test/mpi_dec_multi_test             ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/test/mpi_enc_test                   ${linux_32_dir}
    update_file ${mppRoot}/build/linux/arm/test/mpi_enc_mt_test                ${linux_32_dir}
    update_file ${mppRoot}/build/linux/aarch64/mpp/librockchip_mpp.so.0        ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/mpp/legacy/librockchip_vpu.so.0 ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/test/mpi_dec_test               ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/test/mpi_dec_mt_test            ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/test/mpi_dec_multi_test         ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/test/mpi_enc_test               ${linux_64_dir}
    update_file ${mppRoot}/build/linux/aarch64/test/mpi_enc_mt_test            ${linux_64_dir}

    echo "adb push linux_32/librockchip_mpp.so.0   /usr/lib"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/librockchip_vpu.so.0   /usr/lib"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_test           /usr/bin"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_enc_test           /usr/bin"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_mt_test        /usr/bin"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_multi_test     /usr/bin"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_enc_mt_test        /usr/bin"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/librockchip_mpp.so.0   /oem/usr/lib" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/librockchip_vpu.so.0   /oem/usr/lib" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_test           /oem/usr/bin" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_enc_test           /oem/usr/bin" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_mt_test        /oem/usr/bin" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_dec_multi_test     /oem/usr/bin" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_32/mpi_enc_mt_test        /oem/usr/bin" >> ${mppLibDir}/${pushTool}

    echo "adb push linux_64/librockchip_mpp.so.0   /usr/lib64"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_64/librockchip_vpu.so.0   /usr/lib64"     >> ${mppLibDir}/${pushTool}
    echo "adb push linux_64/librockchip_mpp.so.0   /oem/usr/lib64" >> ${mppLibDir}/${pushTool}
    echo "adb push linux_64/librockchip_vpu.so.0   /oem/usr/lib64" >> ${mppLibDir}/${pushTool}
}

function add_log()
{
    echo "create time: `date +"%Y_%m_%d_%H:%M:%S"`" > ${mppLibDir}/${logFile}
    echo "collect dir: ~${mppRoot#${HOME}}" >> ${mppLibDir}/${logFile}
}


# ====== main ======

source $(dirname $(readlink -f $0))/../0.general_tools/0.dir_file_opt.sh

procParas $@

if [[ ${en_android} == "False" && ${en_linux} == "False" ]]; then help; exit 1; fi

if [ -e ${mppLibDir} ]; then rm -rf ${mppLibDir}; fi
if [ -e ${tarPkgName} ]; then rm -rf ${tarPkgName}; fi

if [ ${en_android} == "True" ]; then update_android; fi
if [ ${en_linux} == "True" ]; then update_linux; fi

add_log

echo tarcmd: "tar -czvf ${tarPkgName} ${mppLibDir}"
tar -czvf ${tarPkgName} ${mppLibDir}
