#!/usr/bin/env bash
#########################################################################
# File Name: rkut.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Thu 07 May 2026 09:46:45 AM CST
#########################################################################

# rkUT.sh - Rockchip upgrade_tool wrapper

UPGRADE_TOOL="${HOME}/bin/upgrade_tool"

# image directory (override via RKUT_IMAGE_PATH env)
image_path="${RKUT_IMAGE_PATH:-${HOME}/test}"

# firmware & loader file paths (override full path via env: RKUT_FW, RKUT_LOADER, etc.)
f_firmware="${RKUT_FW:-${image_path}/update.img}"
f_loader="${RKUT_LOADER:-${image_path}/MiniLoaderAll.bin}"

# partition image file paths
f_uboot="${RKUT_UBOOT:-${image_path}/uboot.img}"
f_boot="${RKUT_BOOT:-${image_path}/boot.img}"
f_kernel="${RKUT_KERNEL:-${image_path}/kernel.img}"
f_resource="${RKUT_RESOURCE:-${image_path}/resource.img}"
f_misc="${RKUT_MISC:-${image_path}/misc.img}"
f_trust="${RKUT_TRUST:-${image_path}/trust.img}"
f_system="${RKUT_SYSTEM:-${image_path}/system.img}"
f_recovery="${RKUT_RECOVERY:-${image_path}/recovery.img}"
f_parameter="${RKUT_PARAMETER:-${image_path}/parameter.txt}"
f_dtbo="${RKUT_DTBO:-${image_path}/dtbo.img}"
f_super="${RKUT_SUPER:-${image_path}/super.img}"
f_vbmeta="${RKUT_VBMETA:-${image_path}/vbmeta.img}"
f_baseparameter="${RKUT_BASEPARAMETER:-${image_path}/baseparameter.img}"

# ----------------------------------------------------------
# resolve a known image name to full path, or use as-is
# ----------------------------------------------------------
function resolve_img()
{
    local val=""
    case "$1" in
        firmware)      val="${f_firmware}" ;;
        loader)        val="${f_loader}" ;;
        uboot)         val="${f_uboot}" ;;
        boot)          val="${f_boot}" ;;
        kernel)        val="${f_kernel}" ;;
        resource)      val="${f_resource}" ;;
        misc)          val="${f_misc}" ;;
        trust)         val="${f_trust}" ;;
        system)        val="${f_system}" ;;
        recovery)      val="${f_recovery}" ;;
        parameter)     val="${f_parameter}" ;;
        dtbo)          val="${f_dtbo}" ;;
        super)         val="${f_super}" ;;
        vbmeta)        val="${f_vbmeta}" ;;
        baseparameter) val="${f_baseparameter}" ;;
        *)             val="$1" ;;
    esac
    echo "${val}"
}

# ----------------------------------------------------------
# help
# ----------------------------------------------------------
function rkut_help()
{
    cat <<'HELPEOF'
usage: rkUT.sh <command> [args...]
       rkUT.sh -urk <raw upgrade_tool args...>

--- Device ---
  -ld                    List rockusb devices
  -cd <LocationID>       Choose device by LocationID
  -sd                    Switch device (loader -> maskrom)
  -td                    Test device
  -rd [subcode]          Reset device (subcode=3: loader->maskrom)
  -rp [pipe]             Reset pipe

--- Upgrade ---
  -uf [firmware]         Upgrade firmware (update.img)
  -ul [loader] [storage] Upgrade loader (MiniLoaderAll.bin)
  -db [loader]           Download boot (maskrom only)

--- Partition Table ---
  -pl                    Read partition list from device
  -dp [parameter]        Download (burn) partition table to device
  -gpt <param> <out>     Create GPT file from parameter file

--- Partition Image ---
  -di <part> [file]      Download image to partition
                         part: -b boot  -k kernel  -s system  -r recovery
                               -m misc  -u uboot   -t trust  -re resource
                               -p parameter (partition table)
                         Can specify multiple: -di -u -b (uses defaults)
                         Or with explicit files: -di -u /path/to/uboot.img -b /path/to/boot.img
                         Custom partition: -di -vendor vendor.img
                         Also: -di -dtbo -super -vbmeta -baseparameter
                         File is optional; defaults to image_path/<name>.img

--- Erase ---
  -ef [loader]           Erase flash (needs loader to enter maskrom)
  -el <sec> <count>      Erase sectors (emmc only)
  -eb <cs> <blk> <len>   Erase blocks

--- Info ---
  -rfi                   Read flash info
  -rci                   Read chip info
  -rid                   Read flash ID
  -rcb                   Read capability
  -cpu                   Read CPU ID
  -rsm                   Read secure mode
  -sfi [firmware]        Show firmware/loader info
  -rcl <file>            Read com log

--- Storage ---
  -ssd                   Switch storage device
  -su3                   Switch USB3

--- Low-level ---
  -rl <sec> <len> [file] Read LBA sectors
  -wl <sec> [size] <file> Write LBA sectors
  -rram <addr> <size> [file]  Read RAM
  -wram <addr> <file>        Write RAM
  -eram <addr>                Execute RAM
  -ufx <fw> <addr>           Write firmware to RAM
  -run <uaddr> <taddr> <baddr> <uboot> <trust> <boot>  Run system
  -wvd <dest> <id> <string>  Write vendor
  -wvd <dest> <id> -fin <file>
  -rvd <dest> <id>           Read vendor
  -rvd <dest> <id> -fout <file>

--- Misc ---
  -urk                   Use upgrade_tool directly (pass all remaining args)
  -h                     Show this help

Environment:
  RKUT_IMAGE_PATH  Image directory (default: ~/test)
  RKUT_FW          Firmware full path (default: image_path/update.img)
  RKUT_LOADER      Loader full path (default: image_path/MiniLoaderAll.bin)
  RKUT_UBOOT, RKUT_BOOT, RKUT_KERNEL, ...  Override partition image full paths

Examples:
  # List connected devices
  rkUT.sh -ld

  # Upgrade whole firmware (uses default image_path/update.img)
  rkUT.sh -uf

  # Upgrade loader (uses default image_path/MiniLoaderAll.bin)
  rkUT.sh -ul

  # Download boot to device (uses default image_path/boot.img)
  rkUT.sh -di -b

  # Download multiple partitions at once
  rkUT.sh -di -u -b -re

  # Download with explicit file path
  rkUT.sh -di -b /tmp/my_boot.img

  # Download custom partition
  rkUT.sh -di -vendor /path/to/vendor.img

  # Read partition table from device
  rkUT.sh -pl

  # Burn partition table to device
  rkUT.sh -dp

  # Show firmware info
  rkUT.sh -sfi
HELPEOF
}

# ----------------------------------------------------------
# parameter processing
# ----------------------------------------------------------
# Global variables set by proc_paras:
#   exe_cmd       final command string

exe_cmd=""

function proc_paras()
{
    if [ $# -lt 1 ]; then
        echo "error: no arguments provided"
        rkut_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        key="$1"
        case "${key}" in
            -h)
                rkut_help
                exit 0
                ;;
            # ---------- Device ----------
            -ld)
                exe_cmd="${UPGRADE_TOOL} LD"
                return
                ;;
            -cd)
                if [ $# -lt 2 ]; then echo "error: -cd requires <LocationID>"; exit 1; fi
                exe_cmd="${UPGRADE_TOOL} CD $2"
                return
                ;;
            -sd)
                exe_cmd="${UPGRADE_TOOL} SD"
                return
                ;;
            -td)
                exe_cmd="${UPGRADE_TOOL} TD"
                return
                ;;
            -rd)
                exe_cmd="${UPGRADE_TOOL} RD${2:+ $2}"
                return
                ;;
            -rp)
                exe_cmd="${UPGRADE_TOOL} RP${2:+ $2}"
                return
                ;;
            # ---------- Upgrade ----------
            -uf)
                shift
                local fw="${1:-firmware}"
                fw="$(resolve_img "$fw")"
                echo "======> upgrade firmware <======"
                echo "  File: ${fw}"
                exe_cmd="${UPGRADE_TOOL} UF \"${fw}\""
                return
                ;;
            -ul)
                shift
                local loader="${1:-loader}"
                loader="$(resolve_img "$loader")"
                local storage="$2"
                echo "======> upgrade loader <======"
                echo "  File: ${loader}"
                [ -n "${storage}" ] && echo "  Storage: ${storage}"
                exe_cmd="${UPGRADE_TOOL} UL \"${loader}\"${storage:+ ${storage}}"
                return
                ;;
            -db)
                shift
                local loader="${1:-loader}"
                loader="$(resolve_img "$loader")"
                echo "======> download boot <======"
                echo "  File: ${loader}"
                exe_cmd="${UPGRADE_TOOL} DB \"${loader}\""
                return
                ;;
            # ---------- Partition Table ----------
            -pl)
                echo "======> read partition list <======"
                exe_cmd="${UPGRADE_TOOL} PL"
                return
                ;;
            -dp)
                shift
                local param="${1:-parameter}"
                param="$(resolve_img "$param")"
                echo "======> download partition table <======"
                echo "  File: ${param}"
                exe_cmd="${UPGRADE_TOOL} DI -p \"${param}\""
                return
                ;;
            -gpt)
                if [ $# -lt 3 ]; then
                    echo "error: -gpt requires <parameter_file> <output_gpt>"
                    exit 1
                fi
                echo "======> create GPT <======"
                echo "  Input:  $2"
                echo "  Output: $3"
                exe_cmd="${UPGRADE_TOOL} GPT \"$2\" \"$3\""
                return
                ;;
            # ---------- Partition Image ----------
            -di)
                shift
                if [ $# -lt 1 ]; then
                    echo "error: -di requires at least one partition option"
                    exit 1
                fi
                local di_args=""
                while [[ $# -gt 0 ]]; do
                    local pkey="$1"
                    # stop on next top-level option
                    case "${pkey}" in
                        -ld|-cd|-sd|-td|-rd|-rp|-uf|-ul|-db|-pl|-dp|-gpt|-ef|-el|-eb|-rfi|-rci|-rid|-rcb|-cpu|-rsm|-sfi|-rcl|-ssd|-su3|-rl|-wl|-rram|-wram|-eram|-ufx|-run|-wvd|-rvd|-urk|-h)
                            break
                            ;;
                    esac
                    case "${pkey}" in
                        -p|-b|-k|-s|-r|-m|-u|-t|-re)
                            # known shorthand partition
                            local pname=""
                            case "${pkey}" in
                                -p)  pname="parameter" ;;
                                -b)  pname="boot" ;;
                                -k)  pname="kernel" ;;
                                -s)  pname="system" ;;
                                -r)  pname="recovery" ;;
                                -m)  pname="misc" ;;
                                -u)  pname="uboot" ;;
                                -t)  pname="trust" ;;
                                -re) pname="resource" ;;
                            esac
                            shift
                            # use default if next arg is missing or is another option
                            local pfile="${pname}"
                            if [[ $# -gt 0 && "${1}" != -* ]]; then
                                pfile="$1"
                                shift
                            fi
                            pfile="$(resolve_img "$pfile")"
                            echo "======> download ${pname} <======"
                            echo "  File: ${pfile}"
                            di_args="${di_args} ${pkey} \"${pfile}\""
                            ;;
                        -*)
                            # custom partition: -vendor vendor.img
                            local cname="${pkey#-}"
                            shift
                            local cfile="${image_path}/${cname}.img"
                            if [[ $# -gt 0 && "${1}" != -* ]]; then
                                cfile="$1"
                                shift
                            fi
                            echo "======> download ${cname} <======"
                            echo "  File: ${cfile}"
                            di_args="${di_args} -${cname} \"${cfile}\""
                            ;;
                        *)
                            echo "error: invalid DI argument: ${pkey}"
                            exit 1
                            ;;
                    esac
                done
                exe_cmd="${UPGRADE_TOOL} DI${di_args}"
                return
                ;;
            # ---------- Erase ----------
            -ef)
                shift
                local loader="${1:-loader}"
                loader="$(resolve_img "$loader")"
                echo "======> erase flash <======"
                echo "  Loader: ${loader}"
                exe_cmd="${UPGRADE_TOOL} EF \"${loader}\""
                return
                ;;
            -el)
                if [ $# -lt 3 ]; then
                    echo "error: -el requires <begin_sec> <sector_count>"
                    exit 1
                fi
                echo "======> erase LBA sectors <======"
                echo "  Sector: $2, Count: $3"
                exe_cmd="${UPGRADE_TOOL} EL $2 $3"
                return
                ;;
            -eb)
                if [ $# -lt 4 ]; then
                    echo "error: -eb requires <CS> <begin_block> <block_len> [--Force]"
                    exit 1
                fi
                echo "======> erase blocks <======"
                exe_cmd="${UPGRADE_TOOL} EB $2 $3 $4 $5"
                return
                ;;
            # ---------- Info ----------
            -rfi)
                exe_cmd="${UPGRADE_TOOL} RFI"
                return
                ;;
            -rci)
                exe_cmd="${UPGRADE_TOOL} RCI"
                return
                ;;
            -rid)
                exe_cmd="${UPGRADE_TOOL} RID"
                return
                ;;
            -rcb)
                exe_cmd="${UPGRADE_TOOL} RCB"
                return
                ;;
            -cpu)
                exe_cmd="${UPGRADE_TOOL} CPU"
                return
                ;;
            -rsm)
                exe_cmd="${UPGRADE_TOOL} RSM"
                return
                ;;
            -sfi)
                shift
                local fw="${1:-firmware}"
                fw="$(resolve_img "$fw")"
                exe_cmd="${UPGRADE_TOOL} SFI${fw:+ \"${fw}\"}"
                return
                ;;
            -rcl)
                if [ $# -lt 2 ]; then
                    echo "error: -rcl requires <output_file>"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} RCL \"$2\""
                return
                ;;
            # ---------- Storage ----------
            -ssd)
                exe_cmd="${UPGRADE_TOOL} SSD"
                return
                ;;
            -su3)
                exe_cmd="${UPGRADE_TOOL} SU3"
                return
                ;;
            # ---------- Low-level ----------
            -rl)
                if [ $# -lt 3 ]; then
                    echo "error: -rl requires <begin_sec> <sector_len> [output_file]"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} RL $2 $3${4:+ \"$4\"}"
                return
                ;;
            -wl)
                if [ $# -lt 3 ]; then
                    echo "error: -wl requires <begin_sec> [size_sec] <file>"
                    exit 1
                fi
                # if 3 args: wl <sec> <file>;  if 4 args: wl <sec> <size> <file>
                if [ $# -ge 4 ]; then
                    exe_cmd="${UPGRADE_TOOL} WL $2 $3 \"$4\""
                else
                    exe_cmd="${UPGRADE_TOOL} WL $2 \"$3\""
                fi
                return
                ;;
            -rram)
                if [ $# -lt 3 ]; then
                    echo "error: -rram requires <addr> <size> [output_file]"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} RRAM $2 $3${4:+ \"$4\"}"
                return
                ;;
            -wram)
                if [ $# -lt 3 ]; then
                    echo "error: -wram requires <addr> <file>"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} WRAM $2 \"$3\""
                return
                ;;
            -eram)
                if [ $# -lt 2 ]; then
                    echo "error: -eram requires <addr>"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} ERAM $2"
                return
                ;;
            -ufx)
                if [ $# -lt 3 ]; then
                    echo "error: -ufx requires <firmware> <begin_addr>"
                    exit 1
                fi
                local fw="$(resolve_img "$2")"
                exe_cmd="${UPGRADE_TOOL} UFX \"${fw}\" $3"
                return
                ;;
            -run)
                if [ $# -lt 7 ]; then
                    echo "error: -run requires <uboot_addr> <trust_addr> <boot_addr> <uboot> <trust> <boot>"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} RUN $2 $3 $4 \"$5\" \"$6\" \"$7\""
                return
                ;;
            -wvd)
                if [ $# -lt 4 ]; then
                    echo "error: -wvd requires <dest> <id> <string | -fin file>"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} WVD $2 $3 \"$4\" \"$5\""
                return
                ;;
            -rvd)
                if [ $# -lt 3 ]; then
                    echo "error: -rvd requires <dest> <id> [-fout file]"
                    exit 1
                fi
                exe_cmd="${UPGRADE_TOOL} RVD $2 $3 \"$4\""
                return
                ;;
            # ---------- Pass-through ----------
            -urk)
                shift
                exe_cmd="${UPGRADE_TOOL} $*"
                return
                ;;
            *)
                echo "error: unknown option: ${key}"
                rkut_help
                exit 1
                ;;
        esac
    done
}

# ----------------------------------------------------------
# main
# ----------------------------------------------------------
function main()
{
    proc_paras "$@"

    echo "cmd: ${exe_cmd}"
    eval "${exe_cmd}"
    local ret=$?
    if [ ${ret} -ne 0 ]; then
        echo "error: command failed (exit code ${ret})"
        exit ${ret}
    fi
}

main "$@"
