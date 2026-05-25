#!/usr/bin/env bash
#########################################################################
# File Name: 16.usbinfo.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Mon 25 May 2026 05:30:32 PM CST
#########################################################################

# ============================================================
# USB Device Info Script
#
# Usage: ./16.usbinfo.sh [options]
#   (none)      List all USB devices summary (like lsusb)
#   -a          Show all devices in detail (device + interface + endpoint)
#   -t          Show USB topology tree (like lsusb -t)
#   -d <path>   Show detail for a specific sysfs path
#               e.g. -d 1-9.3.2 or -d usb1
#   -p          List loaded USB drivers and their bound devices
#   -h          Show help (with usage guide)
#
# Data source: /sys/bus/usb/devices/ (sysfs)
# ============================================================

# ---------- Constants ----------

# USB Device Class (bDeviceClass, hex)
# Device-level class: if bDeviceClass != 0xff, the whole device belongs to this class.
# If bDeviceClass == 0xff (Vendor Specific), each interface defines its own class.
declare -A USB_CLASS=(
    [00]="Defined@Interface"
    [01]="Audio"                    # Sound cards, USB headsets
    [02]="Communications"           # Modems, virtual serial (CDC ACM)
    [03]="Human Interface Device"   # Keyboards, mice, gamepads
    [05]="Physical"                 # Force feedback devices
    [06]="Image"                    # Scanners, cameras
    [07]="Printer"                  # Printers
    [08]="Mass Storage"             # Flash drives, external HDDs
    [09]="Hub"                      # USB hubs
    [0a]="CDC-Data"                 # USB NIC (CDC ECM/NCM)
    [0b]="Smart Card"               # Card readers
    [0d]="Content Security"         # Dongles
    [0e]="Video"                    # Webcams
    [0f]="Personal Healthcare"      # Medical devices
    [10]="Audio/Video Devices"      # Consumer electronics with A/V
    [11]="Billboard Device"         # USB Type-C Billboard
    [12]="USB Type-C Bridge"        # USB-C controllers
    [dc]="Diagnostic Device"        # USB debug devices
    [e0]="Wireless Controller"      # Bluetooth, WiFi adapters
    [ef]="Miscellaneous"            # Composite devices
    [fe]="Application Specific"     # Firmware upgrade (e.g. Rockchip Maskrom)
    [ff]="Vendor Specific"          # Vendor-defined (common in embedded devices)
)

# USB speed
declare -A USB_SPEED=(
    [1.5]="Low Speed (1.5 Mbps)"        # USB 1.0 - mouse/keyboard
    [12]="Full Speed (12 Mbps)"         # USB 1.1 - general devices
    [480]="High Speed (480 Mbps)"       # USB 2.0 - common devices
    [5000]="Super Speed (5 Gbps)"       # USB 3.0/3.1 Gen1
    [10000]="Super Speed+ (10 Gbps)"    # USB 3.1 Gen2
    [20000]="Super Speed+ (20 Gbps)"    # USB 3.2 Gen2x2
)

# ---------- Helper functions ----------

# Convert hex class code to human-readable name
function usb_class_name()
{
    local code="$1"
    echo "${USB_CLASS[${code}]}"
}

# Read a sysfs attribute, return default value if file doesn't exist
function sysfs_read()
{
    local path="$1"
    local default="${2:-"-"}"
    if [ -f "${path}" ]; then
        local val=$(cat "${path}" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "${val}" ] && val="${default}"
        echo "${val}"
    else
        echo "${default}"
    fi
}

# List all endpoints of a device/interface
function list_endpoints()
{
    local devpath="$1"
    local ep_dir
    for ep_dir in "${devpath}"/ep_*; do
        [ -d "${ep_dir}" ] || continue
        local ep_name=$(basename "${ep_dir}")
        local ep_dir_attr=$(sysfs_read "${ep_dir}/direction")
        local ep_type=$(sysfs_read "${ep_dir}/type")
        local ep_maxpkt=$(sysfs_read "${ep_dir}/wMaxPacketSize")
        local ep_interval=$(sysfs_read "${ep_dir}/bInterval")

        printf "    %-10s  %-8s  %-10s  PktSize: %-6s  Interval: %s\n" \
               "${ep_name}" "${ep_dir_attr}" "${ep_type}" "0x${ep_maxpkt}" "${ep_interval}"
    done
}

# ---------- Core functions ----------

# List all USB devices summary
function list_all_devices()
{
    printf "%-6s %-8s %-12s %-5s %-10s %-10s %-10s %-25s %s\n" \
           "Bus" "Dev" "VID:PID" "Speed" "Class" "Driver" "Removable" "Product" "Manufacturer"
    printf "%s\n" "$(printf '%-6s %-8s %-12s %-5s %-10s %-10s %-10s %-25s %-15s' '' '' '' '' '' '' '' '' '' | tr ' ' '-')"

    for devpath in /sys/bus/usb/devices/*/; do
        devpath="${devpath%/}"

        # Skip interface entries (contain colon, e.g. 1-9.3.2:1.0)
        [[ "${devpath##*/}" == *":"* ]] && continue
        # Skip root hubs without idVendor
        local devname=$(basename "${devpath}")
        [[ "${devname}" == usb* && ! -f "${devpath}/idVendor" ]] && continue

        local busnum=$(sysfs_read "${devpath}/busnum" "?")
        local devnum=$(sysfs_read "${devpath}/devnum" "?")
        local vid=$(sysfs_read "${devpath}/idVendor")
        local pid=$(sysfs_read "${devpath}/idProduct")
        local speed=$(sysfs_read "${devpath}/speed")
        local devclass=$(sysfs_read "${devpath}/bDeviceClass")
        local driver=$(readlink -f "${devpath}/driver" 2>/dev/null)
        [ -n "${driver}" ] && driver=$(basename "${driver}") || driver="-"
        local removable=$(sysfs_read "${devpath}/removable")
        local product=$(sysfs_read "${devpath}/product")
        local manufacturer=$(sysfs_read "${devpath}/manufacturer")

        # Truncate long fields
        product="${product:0:24}"
        manufacturer="${manufacturer:0:15}"

        # Speed to human-readable
        local speed_str="${USB_SPEED[${speed}]}"
        [ -z "${speed_str}" ] && speed_str="${speed} Mbps"

        # Class to human-readable
        local class_hex=$(printf '%02x' $((16#${devclass:-0})))
        local class_name=$(usb_class_name "${class_hex}")

        printf "%-6s %-8s %-12s %-5s %-10s %-10s %-10s %-25s %s\n" \
               "${busnum}" "${devnum}" "${vid}:${pid}" "${speed_str:0:5}" \
               "${class_name:0:10}" "${driver:0:10}" "${removable:0:10}" \
               "${product}" "${manufacturer}"
    done
}

# Show full detail of a single device
function show_device_detail()
{
    local sysfs_path="$1"
    local sysfs_base="/sys/bus/usb/devices/${sysfs_path}"

    if [ ! -d "${sysfs_base}" ]; then
        echo "Error: ${sysfs_path} not found" >&2
        echo "Available devices:"
        ls /sys/bus/usb/devices/ | grep -v ':' | head -20
        return 1
    fi

    echo "========================================"
    echo " USB Device: ${sysfs_path}"
    echo "========================================"
    echo ""

    # --- Basic Info ---
    echo "[Basic Info]"
    echo "  sysfs path       : ${sysfs_base}"
    echo "  device node      : $(sysfs_read ${sysfs_base}/dev)"
    echo "  vid:pid          : $(sysfs_read ${sysfs_base}/idVendor):$(sysfs_read ${sysfs_base}/idProduct)"
    echo "  manufacturer     : $(sysfs_read ${sysfs_base}/manufacturer)"
    echo "  product          : $(sysfs_read ${sysfs_base}/product)"
    echo "  serial           : $(sysfs_read ${sysfs_base}/serial)"

    # --- USB Version ---
    echo ""
    echo "[USB Version & Speed]"
    local version=$(sysfs_read "${sysfs_base}/version")
    local speed=$(sysfs_read "${sysfs_base}/speed")
    local speed_str="${USB_SPEED[${speed}]}"
    [ -z "${speed_str}" ] && speed_str="${speed} Mbps"
    echo "  USB version      : ${version}       (bDevice USB spec, e.g. 2.00 = USB 2.0)"
    echo "  bcdDevice        : $(sysfs_read ${sysfs_base}/bcdDevice)   (device firmware/hardware version)"
    echo "  speed            : ${speed_str}"

    # --- Topology ---
    echo ""
    echo "[Topology]"
    echo "  busnum           : $(sysfs_read ${sysfs_base}/busnum)     (USB bus number, maps to lsusb Bus)"
    echo "  devnum           : $(sysfs_read ${sysfs_base}/devnum)     (device address on bus, maps to lsusb Device)"
    echo "  devpath          : $(sysfs_read ${sysfs_base}/devpath)    (port topology, e.g. 9.3.2 = port9.hub_port3.port2)"
    echo "  maxchild         : $(sysfs_read ${sysfs_base}/maxchild)   (downstream ports, >0 means this is a Hub)"

    # --- Class & Configuration ---
    echo ""
    echo "[Class & Configuration]"
    local devclass_hex=$(printf '%02x' $((16#$(sysfs_read ${sysfs_base}/bDeviceClass 0))))
    local subclass_hex=$(printf '%02x' $((16#$(sysfs_read ${sysfs_base}/bDeviceSubClass 0))))
    local protocol_hex=$(printf '%02x' $((16#$(sysfs_read ${sysfs_base}/bDeviceProtocol 0))))
    echo "  bDeviceClass     : 0x${devclass_hex}  $(usb_class_name ${devclass_hex})"
    echo "  bDeviceSubClass  : 0x${subclass_hex}"
    echo "  bDeviceProtocol  : 0x${protocol_hex}"
    echo "  bNumInterfaces   : $(sysfs_read ${sysfs_base}/bNumInterfaces)   (interfaces in current config)"
    echo "  bNumConfigurations: $(sysfs_read ${sysfs_base}/bNumConfigurations)  (total configs device supports)"
    echo "  bConfigurationValue: $(sysfs_read ${sysfs_base}/bConfigurationValue)  (currently active config)"
    echo "  bMaxPacketSize0  : $(sysfs_read ${sysfs_base}/bMaxPacketSize0)  (ep0 max packet size, 8/16/32/64)"

    # --- Power ---
    echo ""
    echo "[Power Management]"
    echo "  bMaxPower        : $(sysfs_read ${sysfs_base}/bMaxPower)   (power draw, unit 2mA, 500mA = 1A)"
    local bm_attr=$(sysfs_read "${sysfs_base}/bmAttributes")
    local power_str=""
    (( 0x80 & 16#${bm_attr:-0} )) && power_str="${power_str}BusPowered " || power_str="${power_str}SelfPowered "
    (( 0x40 & 16#${bm_attr:-0} )) && power_str="${power_str}RemoteWakeup "
    echo "  bmAttributes     : 0x${bm_attr}  (${power_str})"
    echo "  removable        : $(sysfs_read ${sysfs_base}/removable)  (unknown/fixed/removable)"

    # --- Driver ---
    echo ""
    echo "[Driver Binding]"
    local drv=$(readlink -f "${sysfs_base}/driver" 2>/dev/null)
    if [ -n "${drv}" ]; then
        echo "  driver           : $(basename "${drv}")"
    else
        echo "  driver           : (none)"
    fi
    echo "  quirks           : $(sysfs_read ${sysfs_base}/quirks 0x0)  (kernel quirk flags, 0 = no special handling)"

    # --- USB 3.0+ specific ---
    local ver_major="${version%%.*}"
    if [ "${ver_major}" -ge 3 ] 2>/dev/null; then
        echo ""
        echo "[USB 3.0+ Specific]"
        echo "  ltm_capable      : $(sysfs_read ${sysfs_base}/ltm_capable)  (supports Latency Tolerance Messages)"
        echo "  tx_lanes         : $(sysfs_read ${sysfs_base}/tx_lanes)     (transmit lanes)"
        echo "  rx_lanes         : $(sysfs_read ${sysfs_base}/rx_lanes)     (receive lanes)"
    fi

    # --- Interfaces ---
    local if_count=$(sysfs_read "${sysfs_base}/bNumInterfaces" 0)
    if [ "${if_count}" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "[Interfaces]"
        local dev_basename=$(basename "${sysfs_base}")
        local first=true
        for iface in /sys/bus/usb/devices/${dev_basename}:*/; do
            [ -d "${iface}" ] || continue
            ${first} && first=false

            local if_name=$(basename "${iface}")
            local if_class_hex=$(printf '%02x' $((16#$(sysfs_read ${iface}/bInterfaceClass 0))))
            local if_sub_hex=$(printf '%02x' $((16#$(sysfs_read ${iface}/bInterfaceSubClass 0))))
            local if_proto_hex=$(printf '%02x' $((16#$(sysfs_read ${iface}/bInterfaceProtocol 0))))
            local if_driver=$(readlink -f "${iface}/driver" 2>/dev/null)
            [ -n "${if_driver}" ] && if_driver=$(basename "${if_driver}") || if_driver="(none)"
            local if_ep=$(sysfs_read "${iface}/bNumEndpoints" 0)
            local if_class_name=$(usb_class_name "${if_class_hex}")

            printf "  %s  Class: 0x%s %-25s  SubClass: 0x%s  Protocol: 0x%s  Endpoints: %s  Driver: %s\n" \
                   "${if_name}" "${if_class_hex}" "${if_class_name:-?}" \
                   "${if_sub_hex}" "${if_proto_hex}" "${if_ep}" "${if_driver}"

            # List endpoints
            list_endpoints "${iface}"
        done
    fi

    # --- Runtime power state ---
    echo ""
    echo "[Runtime Power State]"
    echo "  runtime_status   : $(sysfs_read ${sysfs_base}/power/runtime_status)  (active/suspended)"
    echo "  autosuspend      : $(sysfs_read ${sysfs_base}/power/autosuspend)     (auto suspend delay ms, -1 = disabled)"
    echo "  connected_duration: $(sysfs_read ${sysfs_base}/power/connected_duration) ms (time since connected)"

    echo ""
    echo "========================================"
}

# Show detail of all devices
function show_all_detail()
{
    for devpath in /sys/bus/usb/devices/*/; do
        devpath="${devpath%/}"
        [[ "${devpath##*/}" == *":"* ]] && continue
        [ ! -f "${devpath}/idVendor" ] && continue

        local devname=$(basename "${devpath}")
        show_device_detail "${devname}"
        echo ""
    done
}

# Show USB topology tree
function show_topology()
{
    echo "USB Topology:"
    echo "-------------"
    lsusb -t 2>/dev/null || echo "(lsusb not available)"
}

# List USB drivers
function list_drivers()
{
    echo "USB Drivers:"
    echo "------------"
    local drv_dir
    for drv_dir in /sys/bus/usb/drivers/*/; do
        [ -d "${drv_dir}" ] || continue
        local drv_name=$(basename "${drv_dir}")
        local bindings=$(ls "${drv_dir}" 2>/dev/null | grep -v '^module$' | grep ':' | tr '\n' ' ')
        local bind_count=$(ls "${drv_dir}" 2>/dev/null | grep -v '^module$' | grep -c ':' 2>/dev/null)
        if [ "${bind_count}" -gt 0 ] 2>/dev/null; then
            printf "  %-15s (%d device(s)): %s\n" "${drv_name}" "${bind_count}" "${bindings}"
        else
            printf "  %-15s (no devices bound)\n" "${drv_name}"
        fi
    done
}

# ---------- Usage Guide ----------
function show_usage_guide()
{
    cat << 'USAGE_GUIDE'

===== USB 信息字段使用场景速查 =====

[VID:PID (Vendor ID : Product ID)]
  含义  : USB-IF 分配的厂商标识 + 厂商自定义的产品标识, 硬件固化不可变
  场景  :
    - udev 规则匹配设备 (ATTRS{idVendor}=="2207", ATTRS{idProduct}=="0006")
    - 判断接入的是哪款开发板 / 芯片型号
    - 区分同厂商的不同产品

[USB 物理路径 (devpath, 如 9.3.2)]
  含义  : 设备在 USB 总线拓扑中的端口位置, 换口则变
  场景  :
    - 多台同型号设备接入时, 通过物理路径区分它们
    - adb devices -l 输出的 usb:1-9.3.2 即来源于此
    - 与 ttyUSB 设备的 sysfs 路径关联, 定位串口对应哪台设备

[bDeviceClass / bInterfaceClass]
  含义  : 设备或接口的功能类别
  场景  :
    - 0xff (Vendor Specific): 嵌入式 Linux 开发板 (如 Rockchip ADB/Gadget)
    - 0x09 (Hub): 判断是否为集线器
    - 0x08 (Mass Storage): U 盘、移动硬盘
    - 0x02 (Communications): USB 串口/调制解调器 (CDC ACM -> /dev/ttyACM*)
    - 0x03 (HID): 键盘鼠标, 不需要额外驱动
    - 0x0e (Video): 摄像头 (UVC)

[speed]
  含义  : 当前协商速率
  场景  :
    - 诊断 USB 2.0 设备插在 USB 3.0 口却跑 Full Speed 的问题
    - 判断 Hub/线缆是否成为瓶颈

[driver]
  含义  : 内核驱动名称
  场景  :
    - usbfs: libusb / adb 直接通过 usbfs 与设备通信 (Vendor Specific 设备)
    - hub: 集线器
    - btusb: 蓝牙设备
    - cdc_acm: USB 虚拟串口 (映射为 /dev/ttyACM*)
    - (none): 设备未被内核接管, 可用 usbfs/libusb 直接访问

[serial]
  含义  : 设备序列号, 用于唯一标识同一型号的不同个体
  场景  :
    - udev 规则通过 ATTRS{serial} 创建稳定的 /dev 软链接
    - adb serial ID (adb devices 输出的序列号) 可能与此相同

[bMaxPower]
  含义  : 设备最大功耗, 单位 2mA (500mA = 1A)
  场景  :
    - 判断是否超出 USB Hub/端口供电能力
    - 自供电 vs 总线供电设备的功耗规划

[removable]
  含义  : 设备是否可热插拔
  场景  :
    - fixed: 主板内置设备 (如摄像头、蓝牙)
    - removable: 外接设备

[端点 (Endpoint)]
  含义  : 设备与主机通信的数据通道
  场景  :
    - Bulk: 大块数据传输 (U盘, 串口) -> 可靠但不保证实时
    - Interrupt: 低延迟小数据 (键盘, 鼠标) -> 保证最大延迟
    - Isochronous: 实时流数据 (摄像头, 音频) -> 不保证可靠但保证带宽
    - Control: 设备配置/枚举用 (所有设备必有 ep0)

USAGE_GUIDE
}

# ---------- main ----------
function main()
{
    local opt_show_all=false
    local opt_show_tree=false
    local opt_show_detail_dev=""
    local opt_show_drivers=false

    while getopts "atd:ph" opt; do
        case ${opt} in
            a) opt_show_all=true ;;
            t) opt_show_tree=true ;;
            d) opt_show_detail_dev="${OPTARG}" ;;
            p) opt_show_drivers=true ;;
            h) echo "Usage: $0 [-a] [-t] [-d <sysfs_path>] [-p] [-h]"
               echo "  (none)    List all USB devices summary"
               echo "  -a        Show all devices in detail"
               echo "  -t        Show USB topology tree"
               echo "  -d <path> Show detail for a device (e.g. -d 1-9.3.2)"
               echo "  -p        List USB drivers and bound devices"
               echo "  -h        Show help (with usage guide)"
               exit 0 ;;
            *) exit 1 ;;
        esac
    done

    if ${opt_show_all}; then
        show_all_detail
    elif ${opt_show_tree}; then
        show_topology
    elif [ -n "${opt_show_detail_dev}" ]; then
        show_device_detail "${opt_show_detail_dev}"
    elif ${opt_show_drivers}; then
        list_drivers
    else
        list_all_devices
    fi

    # Append usage guide when no specific option is given
    if ! ${opt_show_all} && ! ${opt_show_tree} && [ -z "${opt_show_detail_dev}" ] && ! ${opt_show_drivers}; then
        show_usage_guide
    fi
}

main "$@"
