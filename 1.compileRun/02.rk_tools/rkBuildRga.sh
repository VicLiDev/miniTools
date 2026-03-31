#!/usr/bin/env bash
#########################################################################
# File Name: .prjBuild.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 16 Mar 2026 05:03:30 PM CST
#########################################################################

NDK_ROOT=${HOME}/work/android/ndk/android-ndk-r25c
LINUX_TC_DIR=${HOME}/Projects/prebuilts/toolchains
ARM_TOOLCHAIN_ROOT=${LINUX_TC_DIR}/arm/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf
AARCH64_TOOLCHAIN_ROOT=${LINUX_TC_DIR}/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu
ARM_TOOLCHAIN_NAME=arm-none-linux-gnueabihf
AARCH64_TOOLCHAIN_NAME=aarch64-none-linux-gnu

BUILD_TYPE=Release


and_arm_bld_dir="build_android_arm"
and_aarch_bld_dir="build_android_aarch64"
lnx_arm_bld_dir="build_linux_arm"
lnx_aarch_bld_dir="build_linux_aarch64"
meson_arm_bld_dir="build_meson_arm"
meson_aarch_bld_dir="build_meson_aarch64"

sel_tag_rga="rk_rga_b: "

plt_lst=(
    "lib_android32"
    "lib_android64"
    "lib_linux32"
    "lib_linux64"
    "lib_rt_thread"
    "meson_linux32"
    "meson_linux64"
    )

m_sel=""

# ============== 辅助函数 ==============
function get_script_dir()
{
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$SCRIPT_DIR"
}

function check_build_result()
{
    if [ $? -eq 0 ]; then
        echo "======> build rga success! <======"
        return 0
    else
        echo "======> build rga failed! <======"
        return 1
    fi
}

function clean_cmake_cache()
{
    local build_dir="$1"
    rm -f "${build_dir}/CMakeCache.txt"
    rm -rf "${build_dir}/CMakeFiles"
}

function enable_samples()
{
    local cmake_file="$(get_script_dir)/CMakeLists.txt"
    if grep -q '^[[:space:]]*#add_subdirectory(samples)' "${cmake_file}"; then
        sed -i 's/^[[:space:]]*#add_subdirectory(samples)/    add_subdirectory(samples)/' "${cmake_file}"
        echo "Enabled samples in CMakeLists.txt"
    fi
}

function gen_cross_file()
{
    local tc_root="$1"
    local tc_name="$2"
    local cpu_family="$3"
    local cpu="$4"
    local cross_file="cross_file.txt"

    cat > "${cross_file}" << EOF
[host_machine]
system = 'linux'
cpu_family = '${cpu_family}'
cpu = '${cpu}'
endian = 'little'

[binaries]
c = '${tc_root}/bin/${tc_name}-gcc'
cpp = '${tc_root}/bin/${tc_name}-g++'
ar = '${tc_root}/bin/${tc_name}-gcc-ar'
strip = '${tc_root}/bin/${tc_name}-strip'
EOF
    echo "${cross_file}"
}

function push_bins_to_device()
{
    adbCmd="$1"
    file_dir="$2"
    device_dir="$3"

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


# ============== Android 32位 (armv7-a) ==============
function build_lib_android32()
{
    echo "======> selected ${m_sel} <======"

    local build_dir="${and_arm_bld_dir}"
    [ ! -d "${build_dir}" ] && mkdir -p "${build_dir}"
    clean_cmake_cache "${build_dir}"
    cd "${build_dir}"

    cmake .. \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=24 \
        -DCMAKE_ANDROID_ARCH_ABI=armeabi-v7a \
        -DCMAKE_ANDROID_NDK="${NDK_ROOT}" \
        -DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang \
        -DCMAKE_ANDROID_STL_TYPE=c++_static \
        -DCMAKE_BUILD_TARGET=android_ndk \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DCMAKE_INSTALL_PREFIX=install

    make -j$(nproc)
    check_build_result

    if [ "$?" = "0" ]; then
        adbCmd=$(adbs)
        [ -z "${adbCmd}" ] && exit 1

        push_bins_to_device "${adbCmd}" librga.so /vendor/lib
        push_bins_to_device "${adbCmd}" librga.so /system/lib

        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /vendor/bin
    fi
}

# ============== Android 64位 (arm64-v8a) ==============
function build_lib_android64()
{
    echo "======> selected ${m_sel} <======"

    local build_dir="${and_aarch_bld_dir}"
    [ ! -d "${build_dir}" ] && mkdir -p "${build_dir}"
    clean_cmake_cache "${build_dir}"
    cd "${build_dir}"

    cmake .. \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=24 \
        -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
        -DCMAKE_ANDROID_NDK="${NDK_ROOT}" \
        -DCMAKE_ANDROID_NDK_TOOLCHAIN_VERSION=clang \
        -DCMAKE_ANDROID_STL_TYPE=c++_static \
        -DCMAKE_BUILD_TARGET=android_ndk \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DCMAKE_INSTALL_PREFIX=install

    make -j$(nproc)
    check_build_result

    if [ "$?" = "0" ]; then
        adbCmd=$(adbs)
        [ -z "${adbCmd}" ] && exit 1

        push_bins_to_device "${adbCmd}" librga.so /vendor/lib64
        push_bins_to_device "${adbCmd}" librga.so /system/lib64

        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /vendor/bin
    fi
}

# ============== Linux 32位 (arm) ==============
function build_lib_linux32()
{
    echo "======> selected ${m_sel} <======"

    if [ ! -d "${ARM_TOOLCHAIN_ROOT}" ]; then
        echo "Error: ARM toolchain not found at ${ARM_TOOLCHAIN_ROOT}"
        return 1
    fi

    local build_dir="${lnx_arm_bld_dir}"
    [ ! -d "${build_dir}" ] && mkdir -p "${build_dir}"
    clean_cmake_cache "${build_dir}"
    cd "${build_dir}"

    local CC="${ARM_TOOLCHAIN_ROOT}/bin/${ARM_TOOLCHAIN_NAME}-gcc"
    local CXX="${ARM_TOOLCHAIN_ROOT}/bin/${ARM_TOOLCHAIN_NAME}-g++"

    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_CXX_COMPILER="${CXX}" \
        -DCMAKE_FIND_ROOT_PATH="${ARM_TOOLCHAIN_ROOT}" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_BUILD_TARGET=cmake_linux \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DCMAKE_INSTALL_PREFIX=install

    make -j$(nproc)
    check_build_result

    if [ "$?" = "0" ]; then
        adbCmd=$(adbs)
        [ -z "${adbCmd}" ] && exit 1

        push_bins_to_device "${adbCmd}" librga.so /usr/lib
        push_bins_to_device "${adbCmd}" librga.so /oem/usr/lib

        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /usr/bin
        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /oem/usr/bin
    fi
}

# ============== Linux 64位 (aarch64) ==============
function build_lib_linux64()
{
    echo "======> selected ${m_sel} <======"

    if [ ! -d "${AARCH64_TOOLCHAIN_ROOT}" ]; then
        echo "Error: AARCH64 toolchain not found at ${AARCH64_TOOLCHAIN_ROOT}"
        return 1
    fi

    local build_dir="${lnx_aarch_bld_dir}"
    [ ! -d "${build_dir}" ] && mkdir -p "${build_dir}"
    clean_cmake_cache "${build_dir}"
    cd "${build_dir}"

    local CC="${AARCH64_TOOLCHAIN_ROOT}/bin/${AARCH64_TOOLCHAIN_NAME}-gcc"
    local CXX="${AARCH64_TOOLCHAIN_ROOT}/bin/${AARCH64_TOOLCHAIN_NAME}-g++"

    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_C_COMPILER="${CC}" \
        -DCMAKE_CXX_COMPILER="${CXX}" \
        -DCMAKE_FIND_ROOT_PATH="${AARCH64_TOOLCHAIN_ROOT}" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_BUILD_TARGET=cmake_linux \
        -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
        -DCMAKE_INSTALL_PREFIX=install

    make -j$(nproc)
    check_build_result

    if [ "$?" = "0" ]; then
        adbCmd=$(adbs)
        [ -z "${adbCmd}" ] && exit 1

        push_bins_to_device "${adbCmd}" librga.so /usr/lib64
        push_bins_to_device "${adbCmd}" librga.so /oem/usr/lib

        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /usr/bin
        push_bins_to_device "${adbCmd}" samples/fmt_conv_demo/src   /oem/usr/bin
    fi
}

# ============== Meson Linux 32位 (arm) ==============
function build_meson_linux32()
{
    echo "======> selected ${m_sel} <======"

    if [ ! -d "${ARM_TOOLCHAIN_ROOT}" ]; then
        echo "Error: ARM toolchain not found at ${ARM_TOOLCHAIN_ROOT}"
        return 1
    fi

    local build_dir="${meson_arm_bld_dir}"
    local cross_file=$(gen_cross_file "${ARM_TOOLCHAIN_ROOT}" "${ARM_TOOLCHAIN_NAME}" "arm" "armv7")

    rm -rf "${build_dir}"
    meson setup "${build_dir}" --cross-file "${cross_file}"
    meson compile -C "${build_dir}"
    check_build_result
}

# ============== Meson Linux 64位 (aarch64) ==============
function build_meson_linux64()
{
    echo "======> selected ${m_sel} <======"

    if [ ! -d "${AARCH64_TOOLCHAIN_ROOT}" ]; then
        echo "Error: AARCH64 toolchain not found at ${AARCH64_TOOLCHAIN_ROOT}"
        return 1
    fi

    local build_dir="${meson_aarch_bld_dir}"
    local cross_file=$(gen_cross_file "${AARCH64_TOOLCHAIN_ROOT}" "${AARCH64_TOOLCHAIN_NAME}" "aarch64" "cortex-a53")

    rm -rf "${build_dir}"
    meson setup "${build_dir}" --cross-file "${cross_file}"
    meson compile -C "${build_dir}"
    check_build_result
}

# ============== 帮助信息 ==============
function show_help()
{
    echo "Usage: $0 [option]"
    echo ""
    echo "CMake Options:"
    echo "  lib_android32  - Build Android 32-bit (armeabi-v7a)"
    echo "  lib_android64  - Build Android 64-bit (arm64-v8a)"
    echo "  lib_linux32    - Build Linux 32-bit (arm)"
    echo "  lib_linux64    - Build Linux 64-bit (aarch64)"
    echo ""
    echo "Meson Options:"
    echo "  meson_linux32  - Build Linux 32-bit (arm) with Meson"
    echo "  meson_linux64  - Build Linux 64-bit (aarch64) with Meson"
    echo ""
    echo "  -h, --help     - Show this help"
}

# ============== 主函数 ==============
function main()
{
    cd "$(get_script_dir)"

    if [ -n "$1" ]; then
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            lib_android32|lib_android64|lib_linux32|lib_linux64|meson_linux32|meson_linux64)
                m_sel="$1"
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    else
        # 交互式选择
        cur_br=$(git branch --show-current 2>/dev/null || echo "unknown")
        echo "cur branch: $cur_br"

        if [ -f "${HOME}/bin/_select_node.sh" ]; then
            source ${HOME}/bin/_select_node.sh
            select_node "${sel_tag_rga}" "plt_lst" "m_sel" "platform"
        else
            echo "Error: ${HOME}/bin/_select_node.sh not found"
            echo "Please specify target directly: $0 <target>"
            show_help
            exit 1
        fi
    fi

    enable_samples
    build_${m_sel}
}

main $@
