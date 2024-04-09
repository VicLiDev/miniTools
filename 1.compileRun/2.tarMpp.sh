#!/bin/bash
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


android_32_dir="${mppLibDir}/android_32"
android_64_dir="${mppLibDir}/android_64"
linux_32_dir="${mppLibDir}/linux_32"
linux_64_dir="${mppLibDir}/linux_64"

en_android="False"
en_linux="False"

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


function create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1"; mkdir -p $1; fi
}

function update_file()
{
	if [ ! -e $1 ]; then echo "error: src file $1 do not exist"; exit 1; fi
	if [ ! -e $2 ]; then echo "error: dst dir $2 do not exist"; exit 1; fi
	echo "copy $1 to $2"
	cp -r $1 $2
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
}



procParas $@

if [[ ${en_android} == "False" && ${en_linux} == "False" ]]; then
    echo "usage: ./2.tarMpp.sh -a -l"
    echo "  -a: tar android lib"
    echo "  -l: tar linux lib"
    exit 1
fi

if [ -e ${mppLibDir} ]; then rm -rf ${mppLibDir}; fi
if [ -e ${tarPkgName} ]; then rm -rf ${tarPkgName}; fi

if [ ${en_android} == "True" ]; then update_android; fi
if [ ${en_linux} == "True" ]; then update_linux; fi

echo tarcmd: "tar -czvf ${tarPkgName} ${mppLibDir}"
tar -czvf ${tarPkgName} ${mppLibDir}
