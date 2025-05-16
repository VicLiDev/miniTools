#!/usr/bin/env bash
#########################################################################
# File Name: tarMpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Mar 2024 04:18:38 PM CST
#########################################################################

# usage: ./2.tarMpp.sh -a -l
# -a: tar android lib
# -l: tar linux lib

wk_dir="`pwd`"
mpp_root="${HOME}/Projects/mpp"
tar_pkt_name="mpplib.tar.gz"
mpp_lib_dir="mpplib"
push_tool="push.sh"
log_file="ReadMe.md"


android_32_dir="${mpp_lib_dir}/android_32"
android_64_dir="${mpp_lib_dir}/android_64"
linux_32_dir="${mpp_lib_dir}/linux_32"
linux_64_dir="${mpp_lib_dir}/linux_64"

cmd_sel_plt="None"
cmd_build="false"

function help()
{
    echo "usage: <ext> <-a|-l> [-b]"
    echo "  -a: tar android lib"
    echo "  -l: tar linux lib"
    echo "  -b: build mpp lib"
}

function proc_paras()
{
    # proc cmd paras
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -a)
                cmd_sel_plt="android"
                ;;
            -l)
                cmd_sel_plt="linux"
                ;;
            -b)
                cmd_build="true"
                ;;
            -h)
                help
                exit 1
                ;;
            *)
                echo "unknow para: ${key}"
                help
                exit 1
                ;;
        esac
        shift
    done

    # check paras
    if [[ ${cmd_sel_plt} != "android" && ${cmd_sel_plt} != "linux" ]]; then help; exit 1; fi

    # print result
    echo "======> cmd paras <======"
    echo "cmd_sel_plt : ${cmd_sel_plt}"
    echo "cmd_build   : ${cmd_build}"
    echo
}


function update_android()
{
    # android
    create_dir ${android_32_dir}
    create_dir ${android_64_dir}

    update_file ${mpp_root}/build/android/arm/mpp/libmpp.so                ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/mpp/legacy/libvpu.so         ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/test/mpi_dec_test            ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/test/mpi_dec_mt_test         ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/test/mpi_dec_multi_test      ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/test/mpi_enc_test            ${android_32_dir}
    update_file ${mpp_root}/build/android/arm/test/mpi_enc_mt_test         ${android_32_dir}
    update_file ${mpp_root}/build/android/aarch64/mpp/libmpp.so            ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/mpp/legacy/libvpu.so     ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/test/mpi_dec_test        ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/test/mpi_dec_mt_test     ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/test/mpi_dec_multi_test  ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/test/mpi_enc_test        ${android_64_dir}
    update_file ${mpp_root}/build/android/aarch64/test/mpi_enc_mt_test     ${android_64_dir}

    echo "adbCmd=adb"                                                    >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/libmpp.so          /vendor/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/libvpu.so          /vendor/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/libmpp.so          /system/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/libvpu.so          /system/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/mpi_dec_test       /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/mpi_enc_test       /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/mpi_dec_mt_test    /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/mpi_dec_multi_test /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_32/mpi_enc_mt_test    /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo ""                                                            >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/libmpp.so          /vendor/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/libvpu.so          /vendor/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/libmpp.so          /system/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/libvpu.so          /system/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/mpi_dec_test       /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/mpi_enc_test       /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/mpi_dec_mt_test    /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/mpi_dec_multi_test /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push android_64/mpi_enc_mt_test    /vendor/bin"   >> ${mpp_lib_dir}/${push_tool}
}

function update_linux()
{
    # linux
    create_dir ${linux_32_dir}
    create_dir ${linux_64_dir}

    update_file ${mpp_root}/build/linux/arm/mpp/librockchip_mpp.so.0            ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/mpp/legacy/librockchip_vpu.so.0     ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/test/mpi_dec_test                   ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/test/mpi_dec_mt_test                ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/test/mpi_dec_multi_test             ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/test/mpi_enc_test                   ${linux_32_dir}
    update_file ${mpp_root}/build/linux/arm/test/mpi_enc_mt_test                ${linux_32_dir}
    update_file ${mpp_root}/build/linux/aarch64/mpp/librockchip_mpp.so.0        ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/mpp/legacy/librockchip_vpu.so.0 ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/test/mpi_dec_test               ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/test/mpi_dec_mt_test            ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/test/mpi_dec_multi_test         ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/test/mpi_enc_test               ${linux_64_dir}
    update_file ${mpp_root}/build/linux/aarch64/test/mpi_enc_mt_test            ${linux_64_dir}

    echo "adbCmd=adb"                                                       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/librockchip_mpp.so.0   /usr/lib"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/librockchip_vpu.so.0   /usr/lib"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_test           /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_enc_test           /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_mt_test        /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_multi_test     /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_enc_mt_test        /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/librockchip_mpp.so.0   /oem/usr/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/librockchip_vpu.so.0   /oem/usr/lib"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_test           /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_enc_test           /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_mt_test        /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_dec_multi_test     /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_32/mpi_enc_mt_test        /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo ""                                                                 >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/librockchip_mpp.so.0   /usr/lib64"     >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/librockchip_vpu.so.0   /usr/lib64"     >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_test           /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_enc_test           /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_mt_test        /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_multi_test     /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_enc_mt_test        /usr/bin"       >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/librockchip_mpp.so.0   /oem/usr/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/librockchip_vpu.so.0   /oem/usr/lib64" >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_test           /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_enc_test           /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_mt_test        /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_dec_multi_test     /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
    echo "\${adbCmd} push linux_64/mpi_enc_mt_test        /oem/usr/bin"   >> ${mpp_lib_dir}/${push_tool}
}

function add_log()
{
    echo "create time: `date +"%Y_%m_%d_%H:%M:%S"`" > ${mpp_lib_dir}/${log_file}
    echo "collect dir: ~${mpp_root#${HOME}}" >> ${mpp_lib_dir}/${log_file}
}


# ====== main ======

prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prj_root_dir}/0.general_tools/0.dir_file_opt.sh

proc_paras $@

[ -e ${mpp_lib_dir} ] && rm -rf ${mpp_lib_dir}
[ -e ${tar_pkt_name} ] && rm -rf ${tar_pkt_name}

if [ ${cmd_sel_plt} == "android" ]; then
    if [ "${cmd_build}" == "true" ]; then
        cd ${mpp_root}
        rm -rf build && git checkout build/
        bash .prjBuild.sh -p 0 -i "false"
        bash .prjBuild.sh -p 1 -i "false"
        cd ${wk_dir}
    fi
    update_android
elif [ ${cmd_sel_plt} == "linux" ]; then
    if [ "${cmd_build}" == "true" ]; then
        cd ${mpp_root}
        rm -rf build && git checkout build/
        bash .prjBuild.sh -p 2 -i "false"
        bash .prjBuild.sh -p 3 -i "false"
        cd ${wk_dir}
    fi
    update_linux
fi

add_log

echo tarcmd: "tar -czvf ${tar_pkt_name} ${mpp_lib_dir}"
tar -czvf ${tar_pkt_name} ${mpp_lib_dir}
