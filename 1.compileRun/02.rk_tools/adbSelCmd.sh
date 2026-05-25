#!/usr/bin/env bash
#########################################################################
# File Name: adbSelCmd.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 14 Mar 2024 05:12:51 PM CST
#########################################################################

# zsh
# alias clog='clear && adbCmd=$(adbs) && eval ${adbCmd} logcat -c && eval ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && eval ${adbCmd} root && eval ${adbCmd} remount && eval ${adbCmd} shell'

# bash
# alias clog='clear && adbCmd=$(adbs) && ${adbCmd} logcat -c && ${adbCmd} logcat'
# alias ldev='adbCmd=$(adbs) && ${adbCmd} root && ${adbCmd} remount && ${adbCmd} shell'

# use platform-tools ≥ 30.x(Android 11) clould fix adb forward(transport) not work issue

# adb 36.x 引入了更激进的连接管理和特性（libusb、并发探测、IPv6、auth 机制变化等），
# 对某些 Linux 开发板的 USB Gadget / 内核驱动兼容性不好，导致反复断连，直到某个
# transport 被“侥幸”稳定下来。
#
# 强制 adb 不走 libusb 后端
# adb 连接 USB 设备有两套路径：
# 路径                  说明
# libusb                新 adb 默认，跨平台、并发能力强
# usbfs (/dev/bus/usb)  老 adb 用的，宽容但老
# ADB_LIBUSB=0 即 禁用新路径，退回老的 USB 实现
# 这是以为使用新的 libusb，会出现linux系统链接不稳定的问题
# 如果想长期生效，也可以写在shell启动脚本里：
# echo 'export ADB_LIBUSB=0' >> ~/.bashrc
# echo 'export ADB_TRACE=' >> ~/.bashrc

# ADB_TRACE 是 adb 的 调试日志开关
# ADB_TRACE=usb,transport
# 会打印巨量调试日志
# ADB_TRACE= 即明确关闭 adb 调试日志
# 用途只有一个：防止之前设置过 ADB_TRACE，结果 adb 巨慢 / 看起来不稳定
# ADB_TRACE=

sel_tag_adbs="adb_s:"

cmd_orgAdbOpt=""
cmd_list_devs="false"
cmd_get_count="false"
cmd_gen_s_style="false"
cmd_sel_idx=""
cmd_soc_info=""
cmd_root_remount="false"
cmd_list_usb_serial="false"

devSerIDList=()
devTPIDList=()
devNameList=()
selectList=()
devUsbPathList=()

function help_info()
{
    echo "usage: adbs <adbsParas> [<orgAdbParas>]"
    echo "    -h|--help help info"
    echo "    -l List devices"
    echo "    -c Get device count"
    echo "    -s gen \"adb -s\" style cmd, default \"adb -t\" style"
    echo "    --idx <num>  Generates cmd with idx:num"
    echo "    --soc <info> Select device by device tree compatible info"
    echo "    -r           Root and remount devices with no info"
    echo "    -u           List USB serial port devices (ttyUSB/ttyACM)"
    echo
    echo "use session:                        "
    echo "    1. use adbs as adb command      "
    echo "       ex: adbs push <file> <dir>   "
    echo "           adbs -s push <file> <dir>"
    echo "    2. gen adb -t/-s prefix         "
    echo '       ex: adbCmd=$(adbs)           '
    echo '           adbCmd=$(adbs -s)        '
}

# 将 USB Vendor ID (十六进制) 转为厂商名称, 遇到未知 VID 则原样输出
function resolve_usb_vid_name()
{
    local vid="$1"
    [ -z "${vid}" ] && { echo "unknown"; return; }
    case "${vid}" in
        1a86) echo "QinHeng (CH340)" ;;
        10c4) echo "SiliconLabs (CP210x)" ;;
        0403) echo "FTDI" ;;
        067b) echo "Prolific (PL2303)" ;;
        1546) echo "Prolific (PL2303)" ;;
        16c0) echo "Van Ooijen (USBasp)" ;;
        2207) echo "Rockchip" ;;
        18d1) echo "Google" ;;
        2717) echo "Intel" ;;
        0483) echo "STMicroelectronics" ;;
        2341) echo "Arduino" ;;
        2a03) echo "Arduino.org" ;;
        1d50) echo "OpenMoko/JTAG" ;;
        0bda) echo "Realtek" ;;
        0b95) echo "ASIX" ;;
        *)    echo "${vid}" ;;
    esac
}

# 通过 USB 物理路径前缀查询 SoC 型号 (读取 /proc/device-tree/compatible)
# $1: USB 物理路径前缀 (如 "usb:1-9")
# 输出: SoC 名称字符串, 未找到则为空
function query_soc_by_usb_path()
{
    local usb_path_prefix="$1"
    [ -z "${usb_path_prefix}" ] && return

    # USB 串口的 sysfs devpath 和 adb 设备的 USB 路径不一定完全一致, 差一级 Hub 是常见情况
    # 逐步向上匹配: 先精确匹配, 失败则去掉最后一段, 再试上一级 Hub
    # 例: "usb:1-9.3.2" -> "usb:1-9.3" -> "usb:1-9", 最多尝试 3 级
    local adb_line=""
    local _try="${usb_path_prefix}"
    for _i in 1 2 3; do
        adb_line=$(adb devices -l 2>/dev/null | grep -E "${_try}(\.|$| )" || true)
        [ -n "${adb_line}" ] && break
        # 去掉最后一段, 往上走一级 Hub
        local _prev="${_try}"
        _try="${_try%.*}"
        [ "${_try}" = "${_prev}" ] && break
    done
    [ -z "${adb_line}" ] && return

    # 多条匹配时取第一条 (最近的 Hub)
    adb_line=$(echo "${adb_line}" | head -1)

    # 提取 transport_id
    local tpid=$(echo "${adb_line}" | grep -oP 'transport_id:\K\d+')
    [ -z "${tpid}" ] && return

    # 通过 adb 查询 /proc/device-tree/compatible
    # compatible 是以 null 分隔的列表, 每行只保留第一个条目
    local compat=$(adb -t "${tpid}" shell "cat /proc/device-tree/compatible" 2>/dev/null | tr '\0' '\n' | head -1)
    [ -z "${compat}" ] && return

    # 解析: 如 "rockchip,rk3539-evb1-ddr4-v10" -> "rk3539-evb1-ddr4-v10"
    echo "${compat}" | sed -n 's/.*rockchip,\(.*\)/\1/p'
}

# 列出所有 USB 串口设备 (ttyUSB/ttyACM) 的详细信息
# 工作流程:
#   1. 扫描 /dev/ttyUSB* 和 /dev/ttyACM* 收集设备列表
#   2. 对每个设备, 通过 sysfs 从串口节点桥接到 USB 设备, 读取 VID/PID/product 等属性
#   3. 获取平台 (SoC) 信息, 按优先级依次尝试:
#      a. 通过 USB Hub 路径匹配 adb 设备, 远程查询 /proc/device-tree/compatible (最准确)
#      b. product 字符串中直接含 SoC 名称 (如 Rockchip Gadget 的 "rk3588_s")
#      c. manufacturer 字段
#      d. 通过 VID 解析已知的厂商名称
#   4. 通过 stty 查询当前波特率
#   5. 格式化输出表格
function list_usb_serial_devs()
{
    local tty_list=()

    # 收集所有 ttyUSB 和 ttyACM 设备
    for dev in /dev/ttyUSB* /dev/ttyACM*; do
        [ -e "${dev}" ] || continue
        tty_list+=("${dev}")
    done

    if [ ${#tty_list[@]} -eq 0 ]; then
        echo "No USB serial port device found (ttyUSB*/ttyACM*)" >&2
        exit 0
    fi

    printf "%-3s %-12s %-10s %-10s %-8s %-22s %-23s\n" \
           "#" "DEVICE" "DRIVER" "VID:PID" "BAUD" "PRODUCT" "PLATFORM"
    # tr ' ' '-': 把空格替换为 '-', 生成与表头等宽的分隔线
    # printf 输出空字符串按列宽左对齐, 填充的空格被 tr 全部替换为 '-'
    local _sep=$(printf '%-3s %-12s %-10s %-10s %-8s %-22s %-23s' '' '' '' '' '' '' '' | tr ' ' '-')
    printf "%s\n" "${_sep}"

    local idx=1
    for dev in "${tty_list[@]}"; do
        local devname=$(basename "${dev}")
        # 主设备/次设备号
        local maj_min=$(stat -c "%t:%T" "${dev}" 2>/dev/null)

        # 解析 sysfs 路径: 串口设备节点不含 USB 信息, 需要 syspath 桥接到 USB 子系统
        # syspath 指向设备对象 (非驱动), 其下有两个软链接:
        #   device -> USB 接口级设备 (硬件端, 可查 VID/PID/product 等)
        #   driver -> 内核驱动     (软件端, 可查驱动名称)
        # 优先用 /sys/class/tty/, 它总有 'device' 软链接
        local syspath=""
        if [ -d "/sys/class/tty/${devname}" ]; then
            syspath="/sys/class/tty/${devname}"
        else
            syspath=$(readlink -f "/sys/dev/char/${maj_min}" 2>/dev/null)
        fi

        local driver="" vendor_id="" prod_id="" platform="" product="" baud=""

        if [ -n "${syspath}" ] && [ -d "${syspath}" ]; then
            # 通过 'device' 软链接解析到 USB 接口级路径
            local iface_path=""
            if [ -L "${syspath}/device" ]; then
                iface_path=$(readlink -f "${syspath}/device")
            elif [[ "${syspath}" == *":"* ]]; then
                # 已在接口/设备级路径 (如 ttyUSB 风格)
                iface_path="${syspath}"
            fi

            if [ -n "${iface_path}" ] && [ -d "${iface_path}" ]; then
                # 从接口级 driver/ 软链接获取驱动名称
                if [ -L "${iface_path}/driver" ]; then
                    driver=$(basename "$(readlink -f "${iface_path}/driver")")
                fi

                # 向上遍历找到 USB 设备根目录 (含有 idVendor)
                local usb_dev_path="${iface_path}"
                local _p
                for _up in "" ".." "../.."; do
                    [ -z "${_up}" ] && _p="${iface_path}" || _p="${iface_path}/${_up}"
                    [ -f "${_p}/idVendor" ] && { usb_dev_path="${_p}"; break; }
                done

                # USB attributes
                vendor_id=$(cat "${usb_dev_path}/idVendor" 2>/dev/null | tr -d '[:space:]')
                prod_id=$(cat "${usb_dev_path}/idProduct" 2>/dev/null | tr -d '[:space:]')
                product=$(cat "${usb_dev_path}/product" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                # 平台信息 (SoC), 按优先级依次尝试:
                # 1. 通过 USB Hub 路径匹配 adb 设备, 远程查询 /proc/device-tree/compatible (最准确)
                local _usb_phy=$(cat "${usb_dev_path}/devpath" 2>/dev/null)
                local _busnum=$(cat "${usb_dev_path}/busnum" 2>/dev/null)
                if [ -n "${_usb_phy}" ] && [ -n "${_busnum}" ]; then
                    platform=$(query_soc_by_usb_path "usb:${_busnum}-${_usb_phy}")
                fi

                # 2. product 字符串中直接含 SoC 名称 (如 Rockchip Gadget 的 "rk3588_s", "rk3566_t")
                [ -z "${platform}" ] && {
                    local _manufacturer=$(cat "${usb_dev_path}/manufacturer" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if [[ "${product}" =~ ^[Rr][Kk][0-9] ]]; then
                        platform="${product}"
                    elif [ -n "${_manufacturer}" ]; then
                        platform="${_manufacturer}"
                    fi
                }

                # 兜底: 通过 VID 解析已知的厂商/芯片名称
                [ -z "${platform}" ] && platform=$(resolve_usb_vid_name "${vendor_id}")
            fi
        fi

        # 波特率: 通过 stty 查询 (非侵入式, 仅读取 termios 设置)
        baud=$(stty -F "${dev}" speed 2>/dev/null) || baud="N/A"

        # 格式化 VID:PID
        local vidpid="${vendor_id}:${prod_id}"
        [ "${vidpid}" = ":" ] && vidpid="-"

        # 截断过长字段以对齐
        product="${product:0:21}"
        platform="${platform:0:23}"

        printf "%-3s %-12s %-10s %-10s %-8s %-22s %-23s\n" \
               "${idx}" "${devname}" "${driver:-"-"}" "${vidpid}" "${baud}" "${product:-"-"}" "${platform:-"-"}"

        ((idx++))
    done

    echo ""
    echo "Total: ${#tty_list[@]} USB serial device(s)"
}

function root_remount_no_info_devs()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    # USB 物理路径 (如 1-9.3.2): 描述设备在 USB 总线拓扑中的物理位置, 同一设备换口则变,
    # 用于区分多台同型号 adb 设备
    # VID:PID (如 2207:350a): 描述设备的身份, 由硬件固化, 换口不变, 用于标识 USB 串口设备的类型
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print substr($i,5)}'))

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    local need_root_tpids=()
    local -A need_root_usb
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        # `adb shell id` returns uid=0(root) when rooted, uid=2000(shell) when not
        local uid=`adb -t ${devTPIDList[${i}]} shell id 2>/dev/null | grep -oP 'uid=\K\d+'`
        if [ "${uid}" != "0" ]; then
            need_root_tpids+=(${devTPIDList[${i}]})
            need_root_usb[${devUsbPathList[${i}]}]=1
        fi
    done
    [ ${#need_root_tpids[@]} -eq 0 ] && return;

    for tpid in "${need_root_tpids[@]}"; do
        echo "[${tpid}] not rooted, executing root..." >&2
        adb -t ${tpid} root
    done
    sleep 2
    # 重新获取: root 后 transport_id 会变, usb 路径是稳定的
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print substr($i,5)}'))
    # 仅对需要 root 的设备执行 remount (通过稳定的 USB 路径匹配)
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        if [[ -n "${need_root_usb[${devUsbPathList[${i}]}]}" ]]; then
            adb -t ${devTPIDList[${i}]} remount
        fi
    done
    sleep 1
}

function gen_dev_info_list()
{
    devSerIDList=(`adb devices | grep device$ | awk '{print $1}'`)
    devTPIDList=($(adb devices -l | awk '/transport_id/{print $(NF)}' | cut -d':' -f2))
    devUsbPathList=($(adb devices -l | awk '/usb:/{for(i=1;i<=NF;i++) if($i~/^usb:/) print substr($i,5)}'))
    devNameList=()
    selectList=()

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        nameTmp=`adb -t ${devTPIDList[${i}]} shell "cat /proc/device-tree/compatible" | tr -d "\0"`
        nameTmp=${nameTmp%rockchip*}
        nameTmp=${nameTmp#"rockchip,"}
        devNameList[${i}]=${nameTmp}
        selectList[${i}]="${devNameList[${i}]} ==> serID: ${devSerIDList[${i}]} ==> usb: ${devUsbPathList[${i}]} ==> TrsptID: ${devTPIDList[${i}]}"
    done
}

function gen_adb_cmd()
{
    mSelectedDev=""

    if [ "${cmd_sel_idx}" == "" ]; then
        if [ ${#devTPIDList[@]} -gt 1 ]; then
            select_node "${sel_tag_adbs}" "selectList" "mSelectedDev" "device"
        else
            mSelectedDev=${selectList[0]}
        fi
    else
        mSelectedDev=${selectList[${cmd_sel_idx}]}
    fi

    if [ "${cmd_gen_s_style}" == "true" ]; then
        adbCmd="adb -s `echo ${mSelectedDev#*==>} | awk '{print $2}'`"
    else
        adbCmd="adb -t `echo ${mSelectedDev##*==>} | awk '{print $2}'`"
    fi

    echo ${adbCmd}
}

function proc_paras()
{
    while [[ $# -gt 0 ]]; do
        key="$1"
        case ${key} in
            -h|--hlep) help_info; exit 0 ;;
            -l)        cmd_list_devs="true" ;;
            -c)        cmd_get_count="true" ;;
            -s)        cmd_gen_s_style="true" ;;
            -r)        cmd_root_remount="true" ;;
            -u)        cmd_list_usb_serial="true" ;;
            --idx)     cmd_sel_idx="$2"; shift ;;
            --soc)     cmd_soc_info="$2"; shift ;;
            *)         cmd_orgAdbOpt=$@; return ;;
        esac
        shift
    done
}

# ====== main ======
source ${HOME}/bin/_select_node.sh

function main()
{
    proc_paras $@

    [ "${cmd_root_remount}" == "true" ] && { root_remount_no_info_devs; exit 0; }
    [ "${cmd_list_usb_serial}" == "true" ] && { list_usb_serial_devs; exit 0; }

    gen_dev_info_list

    # --soc: match device by SoC name pattern, set cmd_sel_idx
    if [ -n "${cmd_soc_info}" ]; then
        cmd_soc_info=$(echo "${cmd_soc_info}" | tr '[:upper:]' '[:lower:]')
        local soc_match_list=()
        for ((i = 0; i < ${#devNameList[@]}; i++)); do
            if [[ "${devNameList[${i}]}" == *"${cmd_soc_info}"* ]]; then
                soc_match_list+=(${i})
            fi
        done
        [ ${#soc_match_list[@]} -eq 0 ] && { echo "No device matching '${cmd_soc_info}' found!" >&2; exit 1; }
        if [ ${#soc_match_list[@]} -eq 1 ]; then
            cmd_sel_idx="${soc_match_list[0]}"
        else
            echo "Multiple devices matching '${cmd_soc_info}', using the first one:" >&2
            for idx in "${soc_match_list[@]}"; do
                echo "  [$idx] ${selectList[${idx}]}" >&2
            done
            cmd_sel_idx="${soc_match_list[0]}"
        fi
    fi

    if [ ${cmd_get_count} == "true" ]; then
        echo "${#selectList[@]}"
    elif [ "${cmd_list_devs}" == "true" ]; then
        for ((cur_idx = 0; cur_idx < ${#selectList[@]}; cur_idx++))
        do
            echo ${selectList[${cur_idx}]}
        done
    else
        adbCmd=`gen_adb_cmd`
        [ -z "${adbCmd}" ] && exit 0
        [ -z "${cmd_orgAdbOpt}" ] && echo ${adbCmd} || ${adbCmd} ${cmd_orgAdbOpt}
    fi
}

main $@
