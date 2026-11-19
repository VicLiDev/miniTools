#!/usr/bin/env bash
#########################################################################
# File Name: rkbuildMpp.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: 2023年04月14日 星期五 08时47分56秒
#########################################################################

# set -e

cmd_sel_plt=""
cmd_install="true"
cmd_ins_dev=""
cmd_use_def="false"

sel_tag_mpp="rk_mpp_b: "
sel_tag_mpp_ko="rk_mpp_ko_b: "

plt_lst=(
    # branch: develp
    "lib_android_32"
    "lib_android_64"
    "lib_linux_32"
    "lib_linux_64"
    "lib_linux_riscv64"
    "lib_linux_x86_64"
    # branch: kmpp_develop
    "ko_mkf_one_ko"
    "ko_mkf_multi_ko"
    "ko_cmk_one_ko"
    "ko_cmk_multi_ko"
    # branch: kmpp
    "ko_kmpp"
    # branch: devlop2
    "ko_develop2"
    )

m_sel=""

kdir_lst=(
    "${HOME}/Projects/kernel"
    "${HOME}/Projects/kernel2"
    "${HOME}/Projects/kernel3"
    )

# 内核构建环境, 由 query_ker_env 填充
m_sel_kdir=""
ker_arch=""
ker_toolchains=""
ker_make_cmd=""
ker_cross_cmp=""

linux_toolchain_dir="${HOME}/Projects/prebuilts"

# 推送列表: 各平台的库不同, demo 程序都一样
android_lib_lst=(
    mpp/libmpp.so
    mpp/legacy/libvpu.so
    )

linux_lib_lst=(
    mpp/librockchip_mpp.so.0
    mpp/librockchip_mpp.so
    mpp/librockchip_mpp.so.1
    mpp/legacy/librockchip_vpu.so.0
    )

demo_lst=(
    mpp/vproc/iep2/test/iep2_test
    test
    mpp/base/test
    )

# ko 产物列表: 核心模块加载, 测试模块只推送不加载
# 当前是单 ko 构建, osal/sys/mpp_service 的源文件都并进 kmpp.ko;
# 本地不存在的 ko 会被跳过
mkf_core_ko_lst=(
    ./kmpp.ko
    )

mkf_test_ko_lst=(
    ./kmpp_test.ko
    ./kmpp_cfg_test.ko
    ./osal_test.ko
    ./kmpi_vdec_test.ko
    ./kmpi_venc_test.ko
    ./kmpi_venc_cfg_test.ko
    ./kmpi_vsp_test.ko
    )

cmk_core_ko_lst=(
    ./build/kmpp.ko
    )

cmk_test_ko_lst=(
    ./test/kmpp_test/build/kmpp_test.ko
    ./test/kmpp_cfg_test/build/kmpp_cfg_test.ko
    ./test/osal_test/build/osal_test.ko
    ./test/kmpi_vdec_test/build/kmpi_vdec_test.ko
    ./test/kmpi_venc_test/build/kmpi_venc_test.ko
    ./test/kmpi_venc_cfg_test/build/kmpi_venc_cfg_test.ko
    ./test/kmpi_vsp_test/build/kmpi_vsp_test.ko
    ./test/sym_test/sym_test/build/sym_test.ko
    ./test/sym_test/sym1/build/sym1.ko
    ./test/sym_test/sym2/build/sym2.ko
    ./test/sym_test/sym3/build/sym3.ko
    ./test/sym_test/sym4/build/sym4.ko
    )

function push_bins_to_device()
{
    adbCmd="${1}"
    file_dir="${2}"
    device_dir="${3}"

    ${adbCmd} shell "ls -d ${device_dir} > /dev/null 2>&1"
    [ "$?" -ne "0" ] && { echo "Error: device dir not exist: ${device_dir}"; return; }

    if [ -d "${file_dir}" ]; then
        for cur_bin_file in `find ${file_dir} -maxdepth 1 -type f -executable`
        do
            [ ! -e ${cur_bin_file} ] && continue

            echo "==> push <${cur_bin_file}> to device <${device_dir}>"
            ${adbCmd} push ${cur_bin_file} ${device_dir}
        done
    elif [ -f "${file_dir}" ]; then
        [ ! -e ${file_dir} ] && continue

        echo "==> push <${file_dir}> to device <${device_dir}>"
        ${adbCmd} push ${file_dir} ${device_dir}
    else
        echo "Error: adbCmd:${adbCmd} file_dir:${file_dir} device_dir:${device_dir}"
    fi
}

# 把列表里的文件逐个推送到设备的同一个目录
#   lst_name  列表名, 如 android_lib_lst、demo_lst
#   dst_dir   设备目录, 如 /vendor/lib64
function push_bins_list()
{
    adbCmd="${1}"
    lst_name="${2}"
    dst_dir="${3}"
    local -n req_lst="${lst_name}"
    local cur_file

    for cur_file in "${req_lst[@]}"; do
        push_bins_to_device "${adbCmd}" "${cur_file}" "${dst_dir}"
    done
}

function build_lib_android_32()
{
    echo "======> selected ${m_sel} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/arm \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_list "${adbCmd}" android_lib_lst /vendor/lib
        push_bins_list "${adbCmd}" demo_lst        /vendor/bin
        push_bins_list "${adbCmd}" android_lib_lst /system/lib
        push_bins_list "${adbCmd}" demo_lst        /system/bin
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_lib_android_64()
{
    echo "======> selected ${m_sel} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/android/aarch64 \
        && ./make-Android.bash

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_list "${adbCmd}" android_lib_lst /vendor/lib64
        push_bins_list "${adbCmd}" demo_lst        /vendor/bin
        push_bins_list "${adbCmd}" android_lib_lst /system/lib64
        push_bins_list "${adbCmd}" demo_lst        /system/bin
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_lib_linux_32()
{
    echo "======> selected ${m_sel} <======"
    linux_32_tc_dir="${linux_toolchain_dir}/toolchains/arm/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf"
    linux_32_tc="${linux_32_tc_dir}/bin/arm-linux-gnueabihf-"
    echo "toolchain: ${linux_32_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/arm \
        && sed -i "s/#SET(CMAKE_SYSTEM_PROCESSOR \"armv7-a_hardfp\")/SET(CMAKE_SYSTEM_PROCESSOR \"armv7-a_hardfp\")/g" arm.linux.cross.cmake \
        && ./make-Makefiles.bash --toolchain "${linux_32_tc}" \
        && make -j
    echo "toolchain: ${linux_32_tc}"

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_list "${adbCmd}" linux_lib_lst   /usr/lib
        push_bins_list "${adbCmd}" demo_lst        /usr/bin
        push_bins_list "${adbCmd}" linux_lib_lst   /oem/usr/lib
        push_bins_list "${adbCmd}" demo_lst        /oem/usr/bin
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_lib_linux_64()
{
    echo "======> selected ${m_sel} <======"
    linux_64_tc_dir="${linux_toolchain_dir}/toolchains/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu"
    linux_64_tc="${linux_64_tc_dir}/bin/aarch64-none-linux-gnu-"
    echo "toolchain: ${linux_64_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/aarch64 \
        && ./make-Makefiles.bash --toolchain "${linux_64_tc}" \
        && make -j
    echo "toolchain: ${linux_64_tc}"

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_list "${adbCmd}" linux_lib_lst   /usr/lib64
        push_bins_list "${adbCmd}" demo_lst        /usr/bin
        push_bins_list "${adbCmd}" linux_lib_lst   /oem/usr/lib
        push_bins_list "${adbCmd}" demo_lst        /oem/usr/bin
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_lib_linux_riscv64()
{
    echo "======> selected ${m_sel} <======"
    linux_riscv64_tc_dir="${linux_toolchain_dir}/toolchains/riscv_1860sdk/riscv64/Xuantie-900-gcc-linux-6.6.36-musl64-x86_64-V3.3.0"
    linux_riscv64_tc="${linux_riscv64_tc_dir}/bin/riscv64-unknown-linux-musl-"
    echo "toolchain: ${linux_riscv64_tc}"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/riscv64 \
        && ./make-Makefiles.bash --toolchain "${linux_riscv64_tc}" \
        && make -j
    echo "toolchain: ${linux_riscv64_tc}"

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        adbCmd=""
        [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
        [ -z "${adbCmd}" ] && exit 0

        push_bins_list "${adbCmd}" linux_lib_lst   /usr/lib
        push_bins_list "${adbCmd}" demo_lst        /usr/bin
        push_bins_list "${adbCmd}" linux_lib_lst   /oem/usr/lib
        push_bins_list "${adbCmd}" demo_lst        /oem/usr/bin
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_lib_linux_x86_64()
{
    echo "======> selected ${m_sel} <======"
    cd `git rev-parse --show-toplevel` \
        && cd build/linux/x86_64 \
        && ./make-Makefiles.bash

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function rmmod_ko()
{
    ko_mod_name="${1}"
    if [ -n "`${adbCmd} shell lsmod | grep -E \"^${ko_mod_name} \"`" ]; then
        echo "rmmod old ${ko_mod_name}.ko"
        ${adbCmd} shell rmmod ${ko_mod_name}.ko
    fi
}

function insmod_ko()
{
    ko_mod_name="${1}"
    ko_mod_dir="${2}"
    echo "insmod ${ko_mod_name}.ko"
    ${adbCmd} shell insmod ${ko_mod_dir}/${ko_mod_name}.ko
}

# 推送一组 ko 到设备的同一个目录, 本地不存在的 ko 跳过
#   lst_name  列表名, 如 mkf_core_ko_lst、cmk_test_ko_lst
#   dst_dir   设备目录, 如 /data
function push_ko_list()
{
    adbCmd="${1}"
    lst_name="${2}"
    dst_dir="${3}"
    local -n req_lst="${lst_name}"
    local cur_file

    for cur_file in "${req_lst[@]}"; do
        [ -f "${cur_file}" ] || continue
        echo "==> push <${cur_file}> to device <${dst_dir}>"
        ${adbCmd} push "${cur_file}" "${dst_dir}"
    done
}

# 卸载一组 ko, 元素本身也允许只写模块名
#   lst_name  列表名, 如 cmk_test_ko_lst
function rmmod_ko_list()
{
    lst_name="${1}"
    local -n mod_lst="${lst_name}"
    local cur_file

    for cur_file in "${mod_lst[@]}"; do
        rmmod_ko "`basename "${cur_file}" .ko`"
    done
}

# 按顺序加载一组 ko, 本地不存在的 ko 跳过(没编出来自然也推不上去)
#   lst_name  列表名, 如 mkf_core_ko_lst
#   dst_dir   设备目录, 如 /data
function insmod_ko_list()
{
    lst_name="${1}"
    dst_dir="${2}"
    local -n req_lst="${lst_name}"
    local cur_file

    for cur_file in "${req_lst[@]}"; do
        [ -f "${cur_file}" ] || continue
        insmod_ko "`basename "${cur_file}" .ko`" "${dst_dir}"
    done
}

function push_ko_to_device()
{
    build_sys="${1}"

    adbCmd=""
    [ -z "${cmd_ins_dev}" ] && { adbCmd=$(adbs); } || { adbCmd=$(adbs --idx ${cmd_ins_dev}); }
    [ -z "${adbCmd}" ] && exit 0

    f_result=$(${adbCmd} shell 'if [ -f /oem/usr/ko/insmod_ko.sh ]; then echo exists; else echo missing; fi')
    if [[ "${f_result}" == *exists* ]]; then
        echo "mv /oem/usr/ko/insmod_ko.sh /oem/usr/ko/insmod_ko.sh.bak and reboot maybe necessary"
        return
    fi

    local core_lst_name test_lst_name
    if [ "${build_sys}" = "mkf" ]; then
        core_lst_name="mkf_core_ko_lst"
        test_lst_name="mkf_test_ko_lst"
    elif [ "${build_sys}" = "cmk" ]; then
        core_lst_name="cmk_core_ko_lst"
        test_lst_name="cmk_test_ko_lst"
    else
        echo "build sys have not set"
        return
    fi

    # push: 核心模块和测试模块都推上去
    echo "======> push ko to dev <======"
    push_ko_list "${adbCmd}" "${test_lst_name}" /data
    push_ko_list "${adbCmd}" "${core_lst_name}" /data

    # rmmod: 先卸测试模块, 再卸核心模块
    rmmod_ko_list "${test_lst_name}"
    rmmod_ko_list "${core_lst_name}"

    # insmod: 只加载核心模块, 测试模块需要时手动加载
    insmod_ko_list "${core_lst_name}" /data
}

# 查询内核构建环境: 交互选择内核目录, 再从 rkBuildKer.sh 的 --env 输出里
# 取出工具链和 make 命令. 结果放到全局变量, 供各 build_ko_* 使用:
#   m_sel_kdir      选中的内核目录
#   ker_toolchains  工具链目录
#   ker_make_cmd    make 命令(已带 ARCH/CROSS_COMPILE)
#   ker_cross_cmp   从工具链目录里的 gcc 反推出的交叉前缀,
#                   如 riscv64-unknown-linux-musl-
function query_ker_env()
{
    select_node "${sel_tag_mpp_ko}" "kdir_lst" "m_sel_kdir" "kernel dir" "" \
        "${cmd_use_def}"

    local info_list
    info_list=`bash ~/bin/rkBuildKer.sh --dir ${m_sel_kdir} --env -y \
        | grep -E "arch:|toolchains|m_make"`
    ker_arch="`echo "${info_list}" | sed -n 's/^arch:[[:space:]]*//p'`"
    ker_toolchains="`echo "${info_list}" \
        | sed -n 's/^toolchains:[[:space:]]*//p'`"
    ker_make_cmd="`echo "${info_list}" | sed -n 's/^m_make:[[:space:]]*//p'`"
    ker_cross_cmp="$(find ${ker_toolchains} -maxdepth 1 -type f \
        | grep gcc$ | sed 's/gcc$//g')"
}

function build_ko_mkf()
{
    echo "======> selected ${m_sel} <======"
    query_ker_env

    mod_build_type="${1}"
    enable_one_ko="y"

    [ ${mod_build_type} = "one" ] && enable_one_ko="y"
    [ ${mod_build_type} = "multi" ] && enable_one_ko="n"

    echo "toolchains:  ${ker_toolchains}"
    echo "make_cmd:    ${ker_make_cmd}"
    echo "kernel dir:  ${m_sel_kdir}"
    echo "cross cmp:   ${ker_cross_cmp}"
    echo "arch:        ${ker_arch}"
    echo "module type: ${mod_build_type}"

    # build
    cd `git rev-parse --show-toplevel`
    export BUILD_ONE_KO=${enable_one_ko}
    export KERNEL_DIR=${m_sel_kdir}
    export CROSS_COMPILE=${ker_cross_cmp}
    export ARCH=${ker_arch}
    make all

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        # install
        push_ko_to_device "mkf"
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_ko_mkf_one_ko()   { build_ko_mkf "one"; }
function build_ko_mkf_multi_ko() { build_ko_mkf "multi"; }

function build_ko_cmk()
{
    echo "======> selected ${m_sel} <======"
    query_ker_env

    mod_build_type="${1}"
    build_wk_dir=""

    echo "toolchains:  ${ker_toolchains}"
    echo "make_cmd:    ${ker_make_cmd}"
    echo "kernel dir:  ${m_sel_kdir}"
    echo "arch:        ${ker_arch}"
    echo "module type: ${mod_build_type}"

    # build: 内核的 arch 名和构建目录名不同, 如 riscv 对应 build/riscv64
    case "${ker_arch}" in
        arm)    build_wk_dir="build/arm" ;;
        arm64)  build_wk_dir="build/aarch64" ;;
        riscv)  build_wk_dir="build/riscv64" ;;
        *)
            echo "no build dir for arch: ${ker_arch}"
            return 1
            ;;
    esac
    export MODULE_TYPE=${mod_build_type}
    cd `git rev-parse --show-toplevel` \
        && cd ${build_wk_dir} \
        && ./make-Kbuild.sh --kernel ${m_sel_kdir} \
            --toolchain ${ker_toolchains}

    if [ $? -eq 0 ]; then
        [ "${cmd_install}" == "false" ] && return

        echo "======> push lib and demo to dev <======"
        # install
        push_ko_to_device "cmk"
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_ko_cmk_one_ko()   { build_ko_cmk "one"; }
function build_ko_cmk_multi_ko() { build_ko_cmk "multi"; }

# 5.10 1106_linux
function build_ko_kmpp()
{
    echo "======> selected ${m_sel} <======"
    query_ker_env

    echo "toolchains: ${ker_toolchains}"
    echo "make_cmd: ${ker_make_cmd}"
    echo "arch: ${ker_arch}"

    # build
    kmpp_build_cmd="${ker_make_cmd} ARCH=${ker_arch} -C ${m_sel_kdir} M=`pwd` modules"
    echo "kmpp_build_cmd: ${kmpp_build_cmd}"
    export PATH=${ker_toolchains}:${PATH}
    cd `git rev-parse --show-toplevel` \
        && ${kmpp_build_cmd}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function build_ko_develop2()
{
    echo "======> selected ${m_sel} <======"
    query_ker_env

    echo "toolchains: ${ker_toolchains}"
    echo "make_cmd: ${ker_make_cmd}"

    # build
    cd `git rev-parse --show-toplevel` \
        && cd build/kmpp/aarch64 \
        && ./make-Kbuild.sh --kernel ${m_sel_kdir} \
            --toolchain ${ker_toolchains} --ndk ${ker_toolchains}

    if [ $? -eq 0 ]; then
        echo "======> build mpp sucess! <======"
    else
        echo "======> build mpp failed! <======"
        return 1
    fi
}

function usage()
{
    local i
    cat <<EOF
Usage: rkBuildMpp.sh [options]

  -p|--plt <index>     Build the target of the given index instead of
                       asking interactively (see the list below)
  -i|--install <bool>  Push the build result to the device after building
                       (true|false, default: true)
  -d|--dev <index>     Device index used by the push/insmod steps
                       (default: the one chosen by adbs)
  -y|--yes             Accept the cached/default choice of interactive
                       prompts instead of asking
  -h|--help            Show this help

Build targets:
EOF
    for i in "${!plt_lst[@]}"; do
        printf '  %2d  %s\n' "${i}" "${plt_lst[${i}]}"
    done
}

function parse_args()
{
    # 带值的选项解析完自身再 shift 一次跳过它的值, 循环末尾统一 shift
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            -p|--plt)       cmd_sel_plt="${2}"; shift ;;
            -i|--install)   cmd_install="${2}"; shift ;;
            -d|--dev)       cmd_ins_dev="${2}"; shift ;;
            -y|--yes)       cmd_use_def="true" ;;
            -h|--help)      usage; exit 0 ;;
            *)
                echo "Unknown option: ${1}"
                usage
                exit 1
                ;;
        esac
        shift
    done

    # 平台索引: 只允许数字, 且不能超出 plt_lst 的范围
    if [ -n "${cmd_sel_plt}" ]; then
        if [[ -n "${cmd_sel_plt//[0-9]/}" ]] \
            || [ "${cmd_sel_plt}" -ge "${#plt_lst[@]}" ]; then
            echo "Invalid platform index: ${cmd_sel_plt} (0-$(( ${#plt_lst[@]} - 1 )))"
            exit 1
        fi
    fi

    # 是否推送: 只允许 true/false
    if [ "${cmd_install}" != "true" ] && [ "${cmd_install}" != "false" ]; then
        echo "Invalid install flag: ${cmd_install} (true|false)"
        exit 1
    fi

    # print result
    echo "======> cmd paras <======"
    echo "cmd_sel_plt : ${cmd_sel_plt}"
    echo "cmd_install : ${cmd_install}"
    echo "cmd_ins_dev : ${cmd_ins_dev}"
    echo "cmd_no_ask  : ${cmd_use_def}"
    echo
}


function main()
{
    parse_args "${@}"

    cur_br=`git branch --show-current`
    echo "cur branch: $cur_br"
    source ${HOME}/bin/_select_node.sh

    if [ -z "${cmd_sel_plt}" ]; then
        select_node "${sel_tag_mpp}" "plt_lst" "m_sel" "platform" "" "${cmd_use_def}"
    else
        m_sel="${plt_lst[${cmd_sel_plt}]}"
    fi
    build_${m_sel}
}


main "$@"

# set +e
