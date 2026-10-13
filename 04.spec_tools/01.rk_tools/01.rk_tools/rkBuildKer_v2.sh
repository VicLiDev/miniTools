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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 全局参数(命令行可覆盖) ----
arg_ini=""
arg_ini_dir=""
arg_dir=""
arg_env="false"
arg_list="false"
arg_mod="false"
arg_kernel="false"
arg_dry="false"
arg_jobs=""

function usage()
{
    cat <<EOF
用法: rkBuildKer_v2.sh [选项]

  --ini <name|path>   指定平台(ini 文件名/平台名/唯一子串), 不指定则交互选择
  --ini-dir <dir>     平台 ini 目录(默认取 RK_KER_BD_INI_DIR >
                      脚本同目录 rk_ker_bd_ini)
  --dir <kernel_path> 切到内核源码目录(默认当前目录)
  --mod               强制按 build_kmod(单编模块)执行
  --kernel            强制按 build_kernel(整编内核)执行
  --env               只初始化环境并打印命令, 不编译
  --list              列出所有可用平台后退出
  --dry               只打印命令, 不真正执行
  --jobs <n>          并行度(默认 nproc+1)
  -h|--help           显示本帮助
EOF
}

function parse_args()
{
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ini)      arg_ini="$2"; shift ;;
            --ini-dir)  arg_ini_dir="$2"; shift ;;
            --dir)      arg_dir="$2"; shift ;;
            --env)      arg_env="true" ;;
            --list)     arg_list="true" ;;
            --mod)      arg_mod="true" ;;
            --kernel)   arg_kernel="true" ;;
            --dry)      arg_dry="true" ;;
            --jobs)     arg_jobs="$2"; shift ;;
            -h|--help)  usage; exit 0 ;;
            *) echo "未知参数: $1"; usage; exit 1 ;;
        esac
        shift
    done
}

# ---- ini 解析(不引入外部工具, 纯 awk) ----
# ini_get <file> <section> <key>  -> 打印值(取该节最后一个匹配)
function ini_get()
{
    awk -v sec="$2" -v key="$3" '
        /^[[:space:]]*\[/ {
            line=$0; sub(/^[[:space:]]*\[/,"",line); sub(/\].*$/,"",line)
            cur=line; next
        }
        {
            line=$0
            if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
            k=line; sub(/[[:space:]]*=.*/,"",k); gsub(/[[:space:]]/,"",k)
            if (cur==sec && k==key) {
                v=line; sub(/^[^=]*=[[:space:]]*/,"",v); sub(/[[:space:]]*$/,"",v)
                print v
            }
        }
    ' "$1"
}

# ini_patches <file> -> 按数值键序打印 "键<TAB>sed表达式"
function ini_patches()
{
    awk -v sec="config_patch" '
        /^[[:space:]]*\[/ {
            line=$0; sub(/^[[:space:]]*\[/,"",line); sub(/\].*$/,"",line)
            cur=line; next
        }
        {
            line=$0
            if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) next
            k=line; sub(/[[:space:]]*=.*/,"",k); gsub(/[[:space:]]/,"",k)
            if (cur==sec && k ~ /^[0-9]+$/) {
                v=line; sub(/^[^=]*=[[:space:]]*/,"",v); sub(/[[:space:]]*$/,"",v)
                printf "%s\t%s\n", k, v
            }
        }
    ' "$1" | sort -n -k1,1
}

# 展开 ~ 并处理 | 分隔的多候选路径: 输出所有"存在"的目录(空格分隔)。
# 用于 PATH(如 rust / bindgen / kernel-build-tools 需同时加入多个目录)。
# 若候选都不存在, 回退为全部展开后的目录。
function resolve_toolchain()
{
    local raw="$1" c
    local -a cands out
    IFS='|' read -r -a cands <<< "$raw"
    for c in "${cands[@]}"; do
        c="${c/#\~/$HOME}"
        [ -d "$c" ] && out+=("$c")
    done
    if [ "${#out[@]}" -eq 0 ]; then
        for c in "${cands[@]}"; do
            out+=("${c/#\~/$HOME}")
        done
    fi
    echo "${out[@]}"
}

function is_android_like()
{
    case "$1" in
        *android*|*fpga*) return 0 ;;
        *) return 1 ;;
    esac
}

# 自动检测 android-*.config: 取数字版本最大的那个(只返回 basename)
function detect_android_config()
{
    local best="" bestn=0 n f
    while IFS= read -r f; do
        n="$(basename "$f" | sed -E 's/^android-([0-9]+)\.config$/\1/')"
        case "$n" in ''|*[!0-9]*) continue ;; esac
        if [ "$n" -gt "$bestn" ]; then
            bestn="$n"; best="$(basename "$f")"
        fi
    done < <(find . -name 'android-*.config' 2>/dev/null | grep -E 'android-[0-9]+\.config$')
    echo "$best"
}

# mode=auto 时: 若 mpp 的 Makefile 里有 obj-m, 则默认单编模块
function detect_kmod_default()
{
    local mk="drivers/video/rockchip/mpp/Makefile"
    [ -f "$mk" ] && grep -qE '^[[:space:]]*obj-m' "$mk"
}

# ---- 平台枚举 / 选择 ----
function load_platform_list()
{
    local f n
    plt_names=(); plt_files=()
    for f in "$ini_dir"/*.ini; do
        [ -e "$f" ] || continue
        n="$(ini_get "$f" platform name)"
        [ -z "$n" ] && n="$(basename "$f" .ini)"
        plt_names+=("$n")
        plt_files+=("$f")
    done
}

function resolve_ini()
{
    local v="$1" i match="" cnt=0 base
    [ -f "$v" ] && { echo "$v"; return 0; }
    [ -f "$ini_dir/$v" ] && { echo "$ini_dir/$v"; return 0; }
    [ -f "$ini_dir/$v.ini" ] && { echo "$ini_dir/$v.ini"; return 0; }

    for i in "${!plt_names[@]}"; do
        base="$(basename "${plt_files[$i]}" .ini)"
        if [ "${plt_names[$i]}" = "$v" ] || [ "$base" = "$v" ] \
           || [ "$(basename "${plt_files[$i]}")" = "$v" ]; then
            match="${plt_files[$i]}"; cnt=$((cnt+1))
        fi
    done
    [ "$cnt" -eq 1 ] && { echo "$match"; return 0; }
    [ "$cnt" -gt 1 ] && { echo "多个平台匹配 '$v'" >&2; return 1; }

    for i in "${!plt_names[@]}"; do
        case "${plt_names[$i]}" in
            *"$v"*) match="${plt_files[$i]}"; cnt=$((cnt+1)) ;;
        esac
    done
    [ "$cnt" -eq 1 ] && { echo "$match"; return 0; }
    echo "无法匹配平台: $v" >&2
    return 1
}

# ---- 编译命令执行 ----
function run()
{
    echo; echo "==> $*"
    [ "$arg_dry" = "true" ] && return 0
    "$@"
}

function apply_config_patch()
{
    local idx expr patched
    while IFS=$'\t' read -r idx expr; do
        [ -z "$expr" ] && continue
        echo "config_patch[$idx]: $expr"
        sed -i "$expr" .config
    done < <(ini_patches "$ini")
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
    if [ "$flash_method" = "rkut" ]; then
        echo; echo "======> copy ${boot_img} to ~/test <======"
        cp "$boot_img" "$HOME/test"
        echo "======> download ${boot_img} <======"
        rkut.sh -di -b
        [ "$flash_reset" = "true" ] && rkut.sh -rd
    elif [ "$flash_method" = "adb" ]; then
        echo; echo "======> reload ${kmod_ko} <======"
        local adbCmd
        adbCmd="$(adbs)"
        [ -z "$adbCmd" ] && return 0
        "$adbCmd" push "${kmod_dir}/${kmod_ko}" "$push_dir"
        if "$adbCmd" shell lsmod | grep -q "$(basename "$kmod_ko" .ko)"; then
            echo "rmmod old $(basename "$kmod_ko" .ko)"
            "$adbCmd" shell rmmod "$(basename "$kmod_ko" .ko)"
        fi
        echo "insmod $(basename "$kmod_ko" .ko)"
        "$adbCmd" shell insmod "${push_dir}/${kmod_ko}"
    fi
}

# ---- 主流程 ----
function main()
{
    parse_args "$@"

    # 定位 ini 目录
    if [ -n "$arg_ini_dir" ]; then
        ini_dir="$arg_ini_dir"
    elif [ -n "$RK_KER_BD_INI_DIR" ]; then
        ini_dir="$RK_KER_BD_INI_DIR"
    elif [ -d "$SCRIPT_DIR/rk_ker_bd_ini" ]; then
        ini_dir="$SCRIPT_DIR/rk_ker_bd_ini"
    else
        ini_dir="$HOME/bin/rk_ker_bd_ini"
    fi

    load_platform_list
    [ "${#plt_files[@]}" -eq 0 ] && { echo "ini 目录无平台配置: $ini_dir" >&2; exit 1; }

    if [ "$arg_list" = "true" ]; then
        local i
        for i in "${!plt_names[@]}"; do
            printf "%2d. %-20s (%s)\n" "$i" "${plt_names[$i]}" "$(basename "${plt_files[$i]}")"
        done
        exit 0
    fi

    # 选择平台
    if [ -n "$arg_ini" ]; then
        ini="$(resolve_ini "$arg_ini")" || exit 1
        sel_name="$(ini_get "$ini" platform name)"
    else
        source "$HOME/bin/_select_node.sh"
        local sel_name=""
        select_node "rk_kernel_b: " "plt_names" "sel_name" "platform"
        local i
        for i in "${!plt_names[@]}"; do
            [ "${plt_names[$i]}" = "$sel_name" ] && ini="${plt_files[$i]}"
        done
    fi
    [ -z "$ini" ] && { echo "未选择平台" >&2; exit 1; }

    # 进入内核目录
    [ -n "$arg_dir" ] && cd "$arg_dir"
    [ -f "Makefile" ] || { echo "警告: 当前目录无 Makefile(非内核树?): $(pwd)" >&2; }

    # 内核版本
    local VERSION=0 KERNEL_VER=""
    if KERNEL_VER="$(make kernelversion 2>/dev/null)" && [ -n "$KERNEL_VER" ]; then
        VERSION="${KERNEL_VER%%.*}"
    fi
    echo "KERNEL_VER = ${KERNEL_VER}"
    echo "VERSION    = ${VERSION}"

    # 读取 ini 字段
    local arch name make_val tc_raw tc_lt6 toolchain
    name="$(ini_get "$ini" platform name)"
    arch="$(ini_get "$ini" platform arch)"
    tc_raw="$(ini_get "$ini" toolchain path)"
    tc_lt6="$(ini_get "$ini" toolchain path_android_lt6)"
    make_val="$(ini_get "$ini" toolchain make)"

    [ -z "$arch" ] && { echo "缺少 platform.arch" >&2; exit 1; }
    [ -z "$make_val" ] && { echo "缺少 toolchain.make" >&2; exit 1; }

    # 工具链选择(优先级链, 对齐 SDK kernel-helper 思路)
    local path_val
    if is_android_like "$name" && [ -n "$tc_lt6" ] \
       && [ "$VERSION" -ge 1 ] && [ "$VERSION" -lt 6 ]; then
        path_val="$tc_lt6"
    else
        path_val="$tc_raw"
    fi
    toolchain="$(resolve_toolchain "$path_val")"

    # 所有存在的工具链目录按顺序 prepend 到 PATH(支持 rust/bindgen 等多目录)
    local -a tc_dirs
    read -r -a tc_dirs <<< "$toolchain"
    local path_prefix=""
    for d in "${tc_dirs[@]}"; do
        path_prefix="${path_prefix}${path_prefix:+:}${d}"
    done
    [ -n "$path_prefix" ] && export PATH="${path_prefix}:${PATH}"

    # [toolchain] env: 额外环境变量(KEY=value, | 分隔), 如 Rust 的
    # RUSTC / BINDGEN / LIBCLANG_PATH / KBUILD_GENDWARFKSYMS_STABLE
    local env_raw env_val k v
    env_raw="$(ini_get "$ini" toolchain env)"
    if [ -n "$env_raw" ]; then
        local -a env_toks
        IFS='|' read -r -a env_toks <<< "$env_raw"
        for env_val in "${env_toks[@]}"; do
            [ -z "$env_val" ] && continue
            k="${env_val%%=*}"; v="${env_val#*=}"
            v="${v/#\~/$HOME}"
            echo "export ${k}=${v}"
            export "${k}=${v}"
        done
    fi

    # 拆分 make 模板
    local -a make_arr
    read -r -a make_arr <<< "$make_val"

    # android config 解析
    local android_config=""
    local ac_val; ac_val="$(ini_get "$ini" build android_config)"
    if [ -n "$ac_val" ]; then
        if [ "$ac_val" = "auto" ]; then
            is_android_like "$name" && android_config="$(detect_android_config)"
        else
            android_config="$ac_val"
        fi
    fi
    echo "android_config = ${android_config:-<none>}"

    # build 字段
    local config_raw target_raw mode
    config_raw="$(ini_get "$ini" build config)"
    target_raw="$(ini_get "$ini" build target)"
    mode="$(ini_get "$ini" build mode)"; mode="${mode:-auto}"

    # kmod 字段
    local kmod_dir kmod_ko
    kmod_dir="$(ini_get "$ini" kmod dir)"; kmod_dir="${kmod_dir:-drivers/video/rockchip/mpp}"
    kmod_ko="$(ini_get "$ini" kmod ko)"; kmod_ko="${kmod_ko:-rk_vcodec.ko}"

    # flash 字段
    local flash_method boot_img flash_reset push_dir
    flash_method="$(ini_get "$ini" flash method)"; flash_method="${flash_method:-auto}"
    boot_img="$(ini_get "$ini" flash boot_img)"; boot_img="${boot_img:-boot.img}"
    flash_reset="$(ini_get "$ini" flash reset)"; flash_reset="${flash_reset:-true}"
    push_dir="$(ini_get "$ini" flash push_dir)"; push_dir="${push_dir:-/data}"

    # 构建模式
    if [ "$arg_kernel" = "true" ] && [ "$arg_mod" = "true" ]; then
        echo "--kernel 与 --mod 不能同时指定" >&2; exit 1
    fi
    [ "$arg_kernel" = "true" ] && mode="build_kernel"
    [ "$arg_mod" = "true" ] && mode="build_kmod"
    if [ "$mode" = "auto" ]; then
        if detect_kmod_default; then mode="build_kmod"; else mode="build_kernel"; fi
    fi
    [ "$flash_method" = "auto" ] && flash_method=$([ "$mode" = "build_kmod" ] && echo adb || echo rkut)

    # 拼接命令(数组, 避免字符串拼装的 word-splitting 隐患)
    local jobs
    jobs="${arg_jobs:-$(( $(nproc) + 1 ))}"
    local -a config_toks target_toks
    config_raw="${config_raw//\$\{android_config\}/$android_config}"
    read -r -a config_toks <<< "$config_raw"
    read -r -a target_toks <<< "$target_raw"

    local -a config_cmd build_cmd kmod_cmd
    config_cmd=( "${make_arr[@]}" ARCH="$arch" "${config_toks[@]}" )
    build_cmd=( "${make_arr[@]}" ARCH="$arch" "${target_toks[@]}" -j"$jobs" )
    kmod_cmd=( "${make_arr[@]}" ARCH="$arch" -C "$PWD" M="$PWD/$kmod_dir" modules -j"$jobs" )

    # 打印摘要
    echo
    echo "platform    = ${name}"
    echo "arch        = ${arch}"
    echo "toolchain   = ${toolchain}"
    echo "mode        = ${mode}"
    echo "m_make      = ${make_val}"
    echo "config cmd  = ${config_cmd[*]}"
    echo "build  cmd  = ${build_cmd[*]}"
    echo "kmod   cmd  = ${kmod_cmd[*]}"

    [ "$arg_env" = "true" ] && exit 0

    if [ "$mode" = "build_kmod" ]; then
        build_kmod
    else
        build_kernel
    fi
    do_flash
}

main "$@"
