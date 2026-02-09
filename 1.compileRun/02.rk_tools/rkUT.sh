#!/usr/bin/env bash

# rockchip update tools usage:

# LD list device
# UF upgrade firmware
# UL upgrade loader
# DI download image
# DB download boot
# EF erase flash
# TD test device
# RD reset device

# DI:
# -s  (system 分区)
# -k  (kernel 分区)
# -b  (boot 分区)
# -r  (recovery 分区)
# -m  (misc 分区)
# -u  (uboot 分区)
# -t  (trust 分区)
# -re (resource 分区)

image_path=${HOME}/Projects/kernel
image_path=${HOME}/test
opt1=""
opt2=""
opt_para1=""
opt_para2=""
use_org_tool=""
exe_cmd=""

f_firmware="update.img"
f_loader="loader.bin"

f_di_u_boot="uboot.img"
f_di_boot="boot.img"
f_di_zboot="zboot.img"
f_di_kernel="kernel.img"
f_di_resource="resource.img"
f_di_misc="misc.img"
f_di_trust="trust.img"
f_di_system="system.img"
f_di_recovery="recovery.img"

function rkut_help()
{
    echo "usage: rkut.sh <opt1> [<opt_para1>] [<opt2>]"
    echo "opt:"
    echo "  -ld  list device"
    echo "  -uf  upgrade firmware"
    echo "  -ul  upgrade loader"
    echo "  -di  download image"
    echo "  -db  download boot"
    echo "  -ef  erase flash"
    echo
    echo "  --> di opt <--"
    echo "  -s  system  "
    echo "  -k  kernel  "
    echo "  -b  boot    "
    echo "  -r  recovery"
    echo "  -m  misc    "
    echo "  -u  uboot   "
    echo "  -t  trust   "
    echo "  -re resource"
    echo
    echo "  ==> Professional Command <=="
    echo "  -td  test device"
    echo "  -rd  reset device"
    echo
    echo "  -urk use the rk tool directly"
}

function proc_paras()
{
    if [ $# -lt 1 ]; then
        echo "error: para is less than 1"
        rkut_help
        exit 0
    else
        # proc cmd paras
        while [[ $# -gt 0 ]]; do
            key="$1"
            case ${key} in
                -h)
                    rkut_help
                    exit 0
                    ;;
                -ld)
                    opt1="LD"
                    shift # move to next para
                    ;;
                -uf)
                    echo "======> writing firmware <======"
                    echo "File: ${image_path}/${f_firmware}"
                    opt1="UF"
                    opt_para1="${image_path}/${f_firmware}"
                    shift # move to next para
                    ;;
                -ul)
                    echo "======> writing loader <======"
                    echo "File: ${image_path}/${f_loader}"
                    opt1="UL"
                    opt_para1="${image_path}/${f_loader}"
                    shift # move to next para
                    ;;
                -di)
                    echo "======> download image <======"
                    opt1="DI"
                    shift # move to next para
                    case $1 in
                        -s)
                            echo "======> writing system.img <======"
                            echo "File: ${image_path}/${f_di_system}"
                            opt2="-s"
                            opt_para2="${image_path}/${f_di_system}"
                            ;;
                        -k)
                            echo "======> writing kernel.img <======"
                            echo "File: ${image_path}/${f_di_kernel}"
                            opt2="-k"
                            opt_para2="${image_path}/${f_di_kernel}"
                            ;;
                        -b)
                            echo "======> writing boot.img <======"
                            echo "File: ${image_path}/${f_di_boot}"
                            opt2="-b"
                            opt_para2="${image_path}/${f_di_boot}"
                            ;;
                        -r)
                            echo "======> writing recovery.img <======"
                            echo "File: ${image_path}/${f_di_recovery}"
                            opt2="-r"
                            opt_para2="${image_path}/${f_di_recovery}"
                            ;;
                        -m)
                            echo "======> writing misc.img <======"
                            echo "File: ${image_path}/${f_di_misc}"
                            opt2="-m"
                            opt_para2="${image_path}/${f_di_misc}"
                            ;;
                        -u)
                            echo "======> writing uboot.img <======"
                            echo "File: ${image_path}/${f_di_u_boot}"
                            opt2="-u"
                            opt_para2="${image_path}/${f_di_u_boot}"
                            ;;
                        -t)
                            echo "======> writing uboot.img <======"
                            echo "File: ${image_path}/${f_di_trust}"
                            opt2="-t"
                            opt_para2="${image_path}/${f_di_trust}"
                            ;;
                        -re)
                            echo "======> writing resource.img <======"
                            echo "File: ${image_path}/${f_di_resource}"
                            opt2="-re"
                            opt_para2="${image_path}/${f_di_resource}"
                            ;;
                    esac
                    ;;
                -db)
                    echo "======> writing boot <======"
                    echo "File: ${image_path}/${f_loader}"
                    opt1="UL"
                    opt_para1="${image_path}/${f_loader}"
                    shift # move to next para
                    ;;
                -ef)
                    echo "======> writing erase flash <======"
                    echo "File: ${image_path}/${f_firmware}"
                    opt1="EF"
                    opt_para1="${image_path}/${f_firmware}"
                    shift # move to next para
                    ;;
                -td)
                    echo "======> test device <======"
                    opt1="TD"
                    shift # move to next para
                    ;;
                -rd)
                    echo "======> reset device <======"
                    opt1="RD"
                    shift # move to next para
                    ;;
                -urk)
                    use_org_tool="true"
                    break
                    ;;
                *)
                    # unknow para
                    echo "unknow para: ${key}"
                    rkut_help
                    exit 1
                    ;;
            esac
            shift # move to next para
        done

    fi
}

function main()
{
    proc_paras $@

    # exec
    if [ "${use_org_tool}" == "true" ]; then
        shift # move to next para
        exe_cmd="upgrade_tool $@"
    else
        exe_cmd="upgrade_tool ${opt1} ${opt_para1} ${opt2} ${opt_para2}"
    fi
    echo "cmd: ${exe_cmd}"
    ${exe_cmd}
    if [ $? -ne 0 ]; then exit 1; fi
}

main $@
