#!/usr/bin/env bash
#########################################################################
# File Name: rkBuildKer_v2.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# 说明: rkBuildKer.sh 的数据驱动重构版。
#   - 平台差异(arch/toolchain/defconfig/target/config_patch/flash)全部放进
#     rk_ker_bd_ini/*.ini, 本脚本只保留"机制"(选择/解析/编译/烧录)。
#   - 新增平台: 只需在 rk_ker_bd_ini/ 复制一份 ini 并改字段, 无需改本脚本。
# 参照: sdk_linux_gen 的"每板子一个 defconfig"思路。
#########################################################################

set -e

# ---- 全局参数(命令行可覆盖) ----
arg_ini=""
arg_dir=""
arg_env="false"
arg_list="false"
arg_mod="false"
arg_kernel="false"
arg_dry="false"
arg_jobs=""
arg_use_def="false"

# 平台 ini 目录固定为 ~/bin/rk_ker_bd_ini
ini_dir="${HOME}/bin/rk_ker_bd_ini"

# ---- 运行时状态(跨函数共享) ----
# 平台选择结果(select_platform)
tgt_ini=""
tgt_name=""
tgt_arch=""

# 内核版本(read_kernel_version)
KERNEL_VER=""
VERSION=0

# 平台配置(load_platform_config, 来自 ini)
tc_raw=""
tc_lt6=""
tc_cc=""
tc_cross=""
tc_extra=""
make_val=""
android_config=""
config_raw=""
target_raw=""
mode=""
build_mode_list=("build_kmod" "build_kernel")
kmod_dir=""
kmod_ko=""
flash_method="auto"
boot_img=""
flash_reset="true"
push_dir=""

# 工具链与编译命令(setup_toolchain / build_commands)
toolchain=""
config_cmd=()
build_cmd=()
kmod_cmd=()

# 平台列表(load_platform_list)
plt_names=()
plt_files=()

# ini 内容缓存(ini_load / ini_read), key: file|section|key
declare -A INI_CACHE=()

function usage()
{
    cat <<EOF
Usage: rkBuildKer_v2.sh [options]

  --ini <file>        Select platform by ini file (path, or filename under
                      ~/bin/rk_ker_bd_ini); interactive selection if omitted
  --dir <kernel_path> Change to kernel source directory (default: current dir)
  --mod               Force build_kmod (build module only)
  --kernel            Force build_kernel (build full kernel)
  --env               Only initialize environment and print commands, no build
  --list              List all available platforms and exit
  --dry               Only print commands, do not execute
  --jobs <n>          Parallelism (default: nproc+1)
  -y|--yes            Accept the cached/default choice of interactive
                      prompts instead of asking
  -h|--help           Show this help
EOF
}

function parse_args()
{
    while [[ ${#} -gt 0 ]]; do
        case "${1}" in
            --ini)      arg_ini="${2}"; shift ;;
            --dir)      arg_dir="${2}"; shift ;;
            --env)      arg_env="true" ;;
            --list)     arg_list="true" ;;
            --mod)      arg_mod="true" ;;
            --kernel)   arg_kernel="true" ;;
            --dry)      arg_dry="true" ;;
            --jobs)     arg_jobs="${2}"; shift ;;
            -y|--yes)   arg_use_def="true" ;;
            -h|--help)  usage; exit 0 ;;
            *) echo "Unknown option: ${1}"; usage; exit 1 ;;
        esac
        shift
    done
}

# ---- ini 解析(复用 00.libs/05.cfg.sh 配置模块) ----
# 每个 ini 只调用一次模块(ini entries), 之后查关联数组, 避免反复启动 python.

function ini_load()
{
    local file="${1}" section key value
    [ -n "${INI_CACHE["${file}|loaded"]+x}" ] && return 0
    [ -f "${file}" ] || { echo "error: ini not found: ${file}" >&2; exit 1; }

    while IFS=$'\t' read -r section key value; do
        INI_CACHE["${file}|${section}|${key}"]="${value}"
    done < <(ini_entries "${file}")

    INI_CACHE["${file}|loaded"]=1
}

# ini_read <file> <section> <key> [default] -> 打印值(取该节最后一个匹配)
function ini_read()
{
    local file="${1}" section="${2}" key="${3}" default="${4:-}"
    local cache_key="${file}|${section}|${key}"
    ini_load "${file}"
    if [ -n "${INI_CACHE["${cache_key}"]+x}" ]; then
        printf '%s\n' "${INI_CACHE["${cache_key}"]}"
    else
        printf '%s\n' "${default}"
    fi
}

# ini_patches <file> -> 按数值键序打印 "键<TAB>补丁表达式"
function ini_patches()
{
    [ -f "${1}" ] || return 0
    ini_numbered "${1}" config_patch 2>/dev/null || true
}

# ---- 工具链 ----
# 展开 ~ 并处理 | 分隔的多候选路径: 输出所有"存在"的目录(空格分隔)。
# 用于 PATH(如 rust / bindgen / kernel-build-tools 需同时加入多个目录)。
# 若候选都不存在, 回退为全部展开后的目录。
function resolve_toolchain()
{
    local raw="${1}" c
    local -a cands out
    IFS='|' read -r -a cands <<< "${raw}"
    for c in "${cands[@]}"; do
        c="${c/#\~/${HOME}}"
        [ -d "${c}" ] && out+=("${c}")
    done
    if [ "${#out[@]}" -eq 0 ]; then
        for c in "${cands[@]}"; do
            out+=("${c/#\~/${HOME}}")
        done
    fi
    echo "${out[@]}"
}

# 平台名是否 Android: 只有 Android 平台需要自动选择 android-N.config
function is_android_platform()
{
    case "${1}" in
        *android*) return 0 ;;
        *) return 1 ;;
    esac
}

# android/fpga 平台可能使用 clang 工具链(path_android_lt6)
function is_android_like()
{
    case "${1}" in
        *android*|*fpga*) return 0 ;;
        *) return 1 ;;
    esac
}

# 自动检测 android-*.config: 取数字版本最大的那个(只返回 basename)
function detect_android_config()
{
    local best="" bestn=0 n f
    while IFS= read -r f; do
        n="$(basename "${f}" | sed -E 's/^android-([0-9]+)\.config$/\1/')"
        case "${n}" in ''|*[!0-9]*) continue ;; esac
        if [ "${n}" -gt "${bestn}" ]; then
            bestn="${n}"; best="$(basename "${f}")"
        fi
    done < <(find . -name 'android-*.config' 2>/dev/null | grep -E 'android-[0-9]+\.config$')
    echo "${best}"
}

# mpp Makefile 有 obj-m 时, 可单编模块, 由用户选择构建方式
function detect_kmod_default()
{
    local mk="drivers/video/rockchip/mpp/Makefile"
    [ -f "${mk}" ] && grep -qE '^[[:space:]]*obj-m' "${mk}"
}

# ---- 平台枚举 / 选择 ----
function load_platform_list()
{
    local f n
    [ "${#plt_files[@]}" -gt 0 ] && return 0
    plt_names=(); plt_files=()
    for f in "${ini_dir}"/*.ini; do
        [ -e "${f}" ] || continue
        n="$(ini_read "${f}" platform name)"
        [ -z "${n}" ] && n="$(basename "${f}" .ini)"
        plt_names+=("${n}")
        plt_files+=("${f}")
    done
}

# 查找命令行传入的 ini 文件: 依次尝试当前/指定路径、补 .ini、ini 目录.
# 命中时输出绝对路径; 未命中返回 1.
function find_ini_file()
{
    local v="${1}" p
    [ -n "${v}" ] || return 1
    for p in "${v}" "${v}.ini" "${ini_dir}/${v}" "${ini_dir}/${v}.ini"; do
        [ -f "${p}" ] || continue
        readlink -f "${p}"
        return 0
    done
    return 1
}

# ---- 编译命令执行 ----
function run()
{
    echo; echo "==> ${*}"
    [ "${arg_dry}" = "true" ] && return 0
    "${@}"
}

# 应用 [config_patch]:
#   CONFIG_FOO=y|m|n   声明式: 先删掉该符号的旧行, 再追加一行(推荐)
#                      不依赖 .config 当前内容(有没有这一行、是不是 is not set 都行),
#                      这正是 sed 替换做不到的: 行不存在时 sed 会静默失效.
#   其他               当作 sed 表达式执行, 兼容旧 ini
function apply_config_patch()
{
    local idx expr sym
    while IFS=$'\t' read -r idx expr; do
        [ -z "${expr}" ] && continue
        echo "config_patch[${idx}]: ${expr}"
        case "${expr}" in
        CONFIG_[A-Za-z0-9_]*=[ymn])
            sym="${expr%%=*}"
            sed -i "/^# ${sym} is not set\$/d;/^${sym}=/d" .config
            if [ "${expr##*=}" = "n" ]; then
                echo "# ${sym} is not set" >> .config
            else
                echo "${expr}" >> .config
            fi
            ;;
        *)
            sed -i "${expr}" .config
            ;;
        esac
    done < <(ini_patches "${tgt_ini}")
}

function build_kernel()
{
    echo "======> compile kernel begin <======"
    run "${config_cmd[@]}"
    apply_config_patch
    run "${build_cmd[@]}"
    echo "======> compile kernel done <======"
}

function build_kmod()
{
    echo "======> compile ${kmod_ko} begin <======"
    run "${kmod_cmd[@]}"
    echo "======> compile ${kmod_ko} done <======"
}

function do_flash()
{
    if [ "${arg_dry}" = "true" ]; then
        echo
        echo "==> dry-run: skip flash (${flash_method})"
        return 0
    fi
    if [ "${flash_method}" = "rkut" ]; then
        echo; echo "======> copy ${boot_img} to ~/test <======"
        cp "${boot_img}" "${HOME}/test"
        echo "======> download ${boot_img} <======"
        rkut.sh -di -b
        [ "${flash_reset}" = "true" ] && rkut.sh -rd
    elif [ "${flash_method}" = "adb" ]; then
        echo; echo "======> reload ${kmod_ko} <======"
        local adbCmd
        # 本次调用带了 -y 时一并传给 adbs, 多设备时不再卡在交互提示
        local -a _adbs=(adbs)
        [ "${arg_use_def}" = "true" ] && _adbs+=(-y)
        adbCmd="$("${_adbs[@]}")"
        [ -z "${adbCmd}" ] && return 0
        ${adbCmd} push "${kmod_dir}/${kmod_ko}" "${push_dir}"
        if ${adbCmd} shell lsmod | grep -q "$(basename "${kmod_ko}" .ko)"; then
            echo "rmmod old $(basename "${kmod_ko}" .ko)"
            ${adbCmd} shell rmmod "$(basename "${kmod_ko}" .ko)"
        fi
        echo "insmod $(basename "${kmod_ko}" .ko)"
        ${adbCmd} shell insmod "${push_dir}/${kmod_ko}"
    fi
}

# ---- 主流程各阶段 ----
function show_platform_list()
{
    local i
    for i in "${!plt_names[@]}"; do
        printf "%2d. %-22s (%s)\n" "${i}" "${plt_names[${i}]}" \
               "$(basename "${plt_files[${i}]}")"
    done
}

# 选择平台: --ini 指定则解析, 否则交互选择; 结果写入 tgt_ini
function select_platform()
{
    local i
    if [ -n "${arg_ini}" ]; then
        # --ini 只按 ini 文件名/路径查找, 统一转绝对路径, 避免 cd 后失效.
        tgt_ini="$(find_ini_file "${arg_ini}")" || {
            echo "Cannot find ini file: ${arg_ini} (searched current dir and ${ini_dir})" >&2
            exit 1
        }
    else
        source "${HOME}/bin/_select_node.sh"
        local sel_name=""
        select_node "rk_kernel_b: " "plt_names" "sel_name" "platform" "" "${arg_use_def}"
        for i in "${!plt_names[@]}"; do
            [ "${plt_names[${i}]}" = "${sel_name}" ] && tgt_ini="${plt_files[${i}]}"
        done
    fi
    [ -z "${tgt_ini}" ] && { echo "No platform selected" >&2; exit 1; }
    return 0
}

function enter_kernel_dir()
{
    [ -n "${arg_dir}" ] && cd "${arg_dir}"
    if [ ! -f "Makefile" ]; then
        echo "Warning: no Makefile in current directory (not a kernel tree?):" \
             "$(pwd)" >&2
    fi
}

# 探测内核版本: KERNEL_VER 为完整版本, VERSION 为主版本号
function read_kernel_version()
{
    VERSION=0
    KERNEL_VER=""
    if KERNEL_VER="$(make kernelversion 2>/dev/null)" && [ -n "${KERNEL_VER}" ]; then
        VERSION="${KERNEL_VER%%.*}"
    fi
    echo "KERNEL_VER = ${KERNEL_VER}"
    echo "VERSION    = ${VERSION}"
}

function gen_make_cmd()
{
    local cmd="make"
    [ -n "${tc_cross}" ] && cmd="${cmd} CROSS_COMPILE=${tc_cross}"
    [ -n "${tc_extra}" ] && cmd="${cmd} ${tc_extra}"
    echo "${cmd}"
}

# 读取 ini 中的平台/构建/模块/烧录字段, 带默认值
function load_platform_config()
{
    # 先在当前 shell 载入缓存; ini_read 的 $(...) 在子 shell 中执行时可直接复用
    ini_load "${tgt_ini}"
    tgt_name="$(ini_read "${tgt_ini}" platform name)"
    tgt_arch="$(ini_read "${tgt_ini}" platform arch)"
    tc_raw="$(ini_read "${tgt_ini}" toolchain path)"
    tc_lt6="$(ini_read "${tgt_ini}" toolchain path_android_lt6)"
    tc_cc="$(ini_read "${tgt_ini}" toolchain cc)"
    tc_cross="$(ini_read "${tgt_ini}" toolchain cross)"
    tc_extra="$(ini_read "${tgt_ini}" toolchain extra)"

    [ -z "${tgt_arch}" ] && { echo "Missing platform.arch" >&2; exit 1; }
    case "${tc_cc}" in
        clang|gcc) ;;
        *) echo "Missing/invalid toolchain.cc (expect clang or gcc)" >&2; exit 1 ;;
    esac
    make_val="$(gen_make_cmd)"

    # android config 解析
    android_config=""
    local ac_val
    ac_val="$(ini_read "${tgt_ini}" build android_config)"
    if [ -n "${ac_val}" ]; then
        if [ "${ac_val}" = "auto" ]; then
            is_android_platform "${tgt_name}" && android_config="$(detect_android_config)"
        else
            android_config="${ac_val}"
        fi
    fi
    echo "android_config = ${android_config:-<none>}"

    # build 字段
    config_raw="$(ini_read "${tgt_ini}" build config)"
    target_raw="$(ini_read "${tgt_ini}" build target)"

    # kmod 字段
    kmod_dir="$(ini_read "${tgt_ini}" kmod dir)"
    kmod_dir="${kmod_dir:-drivers/video/rockchip/mpp}"
    kmod_ko="$(ini_read "${tgt_ini}" kmod ko)"; kmod_ko="${kmod_ko:-rk_vcodec.ko}"

    # flash 字段
    flash_method="$(ini_read "${tgt_ini}" flash method)"; flash_method="${flash_method:-auto}"
    boot_img="$(ini_read "${tgt_ini}" flash boot_img)"; boot_img="${boot_img:-boot.img}"
    flash_reset="$(ini_read "${tgt_ini}" flash reset)"; flash_reset="${flash_reset:-true}"
    push_dir="$(ini_read "${tgt_ini}" flash push_dir)"; push_dir="${push_dir:-/data}"
}

# 校验工具链是否真的可用: 目录存在 + ini 声明的编译器确实在目录里.
# 缺编译器时立刻报错, 而不是等到 kbuild 退化成主机 gcc 后报一堆无关的语法错误.
function check_toolchain()
{
    local d kind="${tc_cc}" prefix="${tc_cross}" hit="" want=""

    # cross 一律要求显式给出. 本机 x86 编译不带前缀虽然"能跑", 但会静默
    # 落到主机 gcc: 主机 gcc 与内核 .config 的编译器/版本不一致时报出来的
    # 是一堆无关的编译错误. 需要本机编译时显式写 host 前缀(如 x86_64-linux-gnu-),
    # 让校验能真正落到具体编译器上.
    # clang 侧同理: 空前缀在 5.12 之前的内核上没有架构表兜底, 会生成
    # --target= 并报 unknown target triple; arm32 的默认 ABI 也不符.
    if [ -z "${prefix}" ]; then
        echo "toolchain check: FAILED - no CROSS_COMPILE in [toolchain]:" >&2
        echo "    platform: ${tgt_name}" >&2
        echo "    make:     ${make_val}" >&2
        exit 1
    fi

    if [ "${kind}" = "clang" ]; then
        local -a cands=(clang)
        # 发行版/vendor 的交叉 clang 可能带前缀(如 aarch64-linux-gnu-clang).
        # 但它只有在 extra 用 CC= 显式指定时才会被 kbuild 调用: LLVM=1 固定调
        # 无前缀的 clang, 那种情况下不能拿前缀 clang 顶替, 否则校验通过而编译失败.
        case "${tc_extra}" in
            *CC=*clang*) cands+=("${prefix}clang") ;;
        esac
        want="${cands[*]}"
        want="${want// / or }"
        for d in ${toolchain}; do
            for c in "${cands[@]}"; do
                [ -x "${d}/${c}" ] && { hit="${d}/${c}"; break 2; }
            done
        done
    else
        want="${prefix}gcc"
        for d in ${toolchain}; do
            [ -x "${d}/${prefix}gcc" ] && { hit="${d}/${prefix}gcc"; break; }
        done
    fi

    if [ -z "${hit}" ]; then
        echo "toolchain check: FAILED - cannot find ${want}" >&2
        echo "    platform:   ${tgt_name}" >&2
        echo "    toolchains: ${toolchain}" >&2
        echo "    make:       ${make_val}" >&2
        exit 1
    fi

    # clang 模式下 CROSS_COMPILE 直接决定 --target, 与 arch 不符会编错架构
    if [ "${kind}" = "clang" ]; then
        case "${tgt_arch}:${prefix}" in
            arm64:aarch64*|arm:arm*|riscv:riscv*) ;;
            arm64:*|arm:*|riscv:*)
                echo "toolchain check: FAILED - CROSS_COMPILE '${prefix}'" \
                     "mismatches arch '${tgt_arch}'" >&2
                exit 1
                ;;
        esac
    fi

    # cc 只决定"找哪个编译器"; 真正的编译器选择开关在 extra 里, 两者必须一致,
    # 否则会出现"校验的是 clang, kbuild 用的是 gcc"的静默错配.
    case "${tc_cc}:${tc_extra}" in
        clang:*LLVM=*|clang:*CC=*clang*) ;;
        gcc:*LLVM=*|gcc:*CC=*clang*)
            echo "toolchain check: FAILED - cc=gcc but extra selects clang" >&2
            exit 1
            ;;
        clang:*)
            echo "toolchain check: FAILED - cc=clang but extra lacks LLVM=1" >&2
            exit 1
            ;;
    esac

    echo "toolchain check: ok (${kind}: ${hit})"
}

# 工具链选择 + PATH 注入 + [toolchain] env 环境变量
function setup_toolchain()
{
    ini_load "${tgt_ini}"
    # 优先级链: android/fpga 且内核 < 6 时使用 path_android_lt6
    local path_val
    if is_android_like "${tgt_name}" && [ -n "${tc_lt6}" ] \
       && [ "${VERSION}" -ge 1 ] && [ "${VERSION}" -lt 6 ]; then
        path_val="${tc_lt6}"
    else
        path_val="${tc_raw}"
    fi
    toolchain="$(resolve_toolchain "${path_val}")"

    # 所有存在的工具链目录按顺序 prepend 到 PATH(支持 rust/bindgen 等多目录)
    local -a tc_dirs
    read -r -a tc_dirs <<< "${toolchain}"
    local d path_prefix=""
    for d in "${tc_dirs[@]}"; do
        path_prefix="${path_prefix}${path_prefix:+:}${d}"
    done
    [ -n "${path_prefix}" ] && export PATH="${path_prefix}:${PATH}"

    # [toolchain] env: 额外环境变量(KEY=value, | 分隔), 如 Rust 的
    # RUSTC / BINDGEN / LIBCLANG_PATH / KBUILD_GENDWARFKSYMS_STABLE
    local env_raw env_val k v
    env_raw="$(ini_read "${tgt_ini}" toolchain env)"
    if [ -n "${env_raw}" ]; then
        local -a env_toks
        IFS='|' read -r -a env_toks <<< "${env_raw}"
        for env_val in "${env_toks[@]}"; do
            [ -z "${env_val}" ] && continue
            k="${env_val%%=*}"; v="${env_val#*=}"
            # 值中任意位置的 ~ 都展开(如 HOSTCFLAGS=-I~/...)
            v="${v//\~/${HOME}}"
            # LD_LIBRARY_PATH 追加到已有值后面, 不覆盖系统已有路径
            if [ "${k}" = "LD_LIBRARY_PATH" ] && [ -n "${LD_LIBRARY_PATH:-}" ]; then
                v="${v}:${LD_LIBRARY_PATH}"
            fi
            echo "export ${k}=${v}"
            export "${k}=${v}"
        done
    fi

    check_toolchain
}

# 决定 build_kmod / build_kernel 及烧录方式
function resolve_build_mode()
{
    if [ "${arg_kernel}" = "true" ] && [ "${arg_mod}" = "true" ]; then
        echo "--kernel and --mod cannot be used together" >&2; exit 1
    fi
    if [ "${arg_kernel}" = "true" ]; then
        mode="build_kernel"
    elif [ "${arg_mod}" = "true" ]; then
        mode="build_kmod"
    elif detect_kmod_default; then
        # 和 v1 一致: mpp 可单编时, 由用户选择整核还是单编模块
        if ! declare -F select_node >/dev/null 2>&1; then
            source "${HOME}/bin/_select_node.sh"
        fi
        select_node "rk_kernel_b_m: " "build_mode_list" "mode" "build method" "" \
                    "${arg_use_def}"
    else
        mode="build_kernel"
    fi
    if [ "${flash_method}" = "auto" ]; then
        flash_method="rkut"
        [ "${mode}" = "build_kmod" ] && flash_method="adb"
    fi
    return 0
}

# 拼接命令(数组, 避免字符串拼装的 word-splitting 隐患)
function build_commands()
{
    local -a make_arr
    read -r -a make_arr <<< "${make_val}"

    local jobs
    jobs="${arg_jobs:-$(( $(nproc) + 1 ))}"
    local -a config_toks target_toks
    config_raw="${config_raw//\$\{android_config\}/${android_config}}"
    read -r -a config_toks <<< "${config_raw}"
    read -r -a target_toks <<< "${target_raw}"

    config_cmd=( "${make_arr[@]}" ARCH="${tgt_arch}" "${config_toks[@]}" )
    build_cmd=( "${make_arr[@]}" ARCH="${tgt_arch}" "${target_toks[@]}" -j"${jobs}" )
    kmod_cmd=( "${make_arr[@]}" ARCH="${tgt_arch}" -C "${PWD}"
               M="${PWD}/${kmod_dir}" modules -j"${jobs}" )
}

function print_summary()
{
    echo
    printf '%-11s %s\n' "platform:"    "${tgt_name}"
    printf '%-11s %s\n' "arch:"        "${tgt_arch}"
    printf '%-11s %s\n' "toolchains:"  "${toolchain}"
    printf '%-11s %s\n' "mode:"        "${mode}"
    printf '%-11s %s\n' "m_make:"      "${make_val}"
    printf '%-11s %s\n' "config cmd:"  "${config_cmd[*]}"
    printf '%-11s %s\n' "build cmd:"   "${build_cmd[*]}"
    printf '%-11s %s\n' "kmod cmd:"    "${kmod_cmd[*]}"
}

function run_build()
{
    if [ "${mode}" = "build_kmod" ]; then
        build_kmod
    else
        build_kernel
    fi
}

# ---- 主流程 ----
function main()
{
    parse_args "${@}"

    # 加载 ini 模块(05.cfg.sh), 已加载则跳过
    if ! declare -F ini_entries >/dev/null 2>&1; then
        source "${HOME}/bin/_cfg.sh" 2>/dev/null ||
            { echo "error: ${HOME}/bin/_cfg.sh not found, run init_tools.sh" >&2; exit 1; }
    fi

    # --list / 交互选择需要扫描平台列表; --ini 直接给文件则不扫描.
    if [ "${arg_list}" = "true" ] || [ -z "${arg_ini}" ]; then
        load_platform_list
        [ "${#plt_files[@]}" -eq 0 ] && {
            echo "No platform ini found in: ${ini_dir}" >&2
            exit 1
        }
    fi

    if [ "${arg_list}" = "true" ]; then show_platform_list; exit 0; fi

    select_platform
    enter_kernel_dir
    read_kernel_version
    load_platform_config
    setup_toolchain
    resolve_build_mode
    build_commands
    print_summary

    [ "${arg_env}" = "true" ] && exit 0

    run_build
    do_flash
}

main "${@}"
