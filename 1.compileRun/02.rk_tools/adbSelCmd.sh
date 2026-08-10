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

# ===================== grep 用法说明 =====================
# 本脚本多处用 grep 从 adb 输出中提取字段, 统一说明涉及的选项与正则构件。
#
# 【选项】
#   -E   扩展正则(Extended)。使 + ? | () {} 等元字符无需反斜杠转义即可使用。
#        例: grep -E 'r[kv][0-9]+'   匹配 rk3588 / rv1106
#   -o   只输出命中的片段(Only matching), 不输出整行。常与 -E / -P 组合。
#        例: echo "rk3588-evb" | grep -oE 'r[kv][0-9]+'  ->  rk3588
#   -P   Perl 正则。支持更强的特性: \d \s \S 以及 \K(见下)。
#   -m1  匹配到第一个结果后立即停止(max count = 1), 避免读完全部输入。
#
# 【-P 模式专属构件】
#   \d   数字[0-9];  \s  空白(空格/制表符);  \S  非空白字符
#   \K   舍弃左侧已匹配内容, 仅保留 \K 右侧作为输出。用于"先定位再提取"。
#        例: echo "transport_id:3" | grep -oP 'transport_id:\K\d+'  ->  3
#        (匹配整串 "transport_id:3", 但 \K 丢掉 "transport_id:", 只输出 "3")
#
# 【基本正则构件】
#   [kv]    字符集合, 匹配 k 或 v 任一个
#   [0-9]   数字范围;  [0-9]+  数字出现 1 次或多次
#   ^       行首锚点;   $  行尾锚点(脚本里 grep device$ 用它定位行尾的 device)
#   \|      基本正则里的"或"需转义; 用 -E 后直接写 | 即可
#
# 【脚本中各处 grep 速查】
#   grep device$                       过滤 adb devices 输出, 取状态为 device 的行
#   grep -E "${_try}(\.|$| )"          按USB物理路径前缀匹配 adb 行
#   grep -oP 'transport_id:\K\d+'      提取 transport_id 数值
#   grep -oP 'uid=\K\d+'               提取 uid 数值(判断是否 root)
#   grep -m1 -E 'r[kv][0-9]'           取首个含 SoC 型号的 compatible 条目
#   grep -oP 'serID:\s*\K\S+'          按标签提取 serial id(忽略字段顺序)
#   grep -oP 'TrsptID:\s*\K\S+'        按标签提取 transport id(忽略字段顺序)

sel_tag_adbs="adb_s:"

cmd_orgAdbOpt=""
cmd_list_devs="false"
cmd_get_count="false"
cmd_gen_s_style="false"
cmd_sel_idx=""
cmd_soc_info=""
cmd_root_remount="false"
cmd_list_usb_serial="false"
cmd_proxy_cmd=""

devSerIDList=()
devTPIDList=()
devNameList=()
devChipList=()
selectList=()
devUsbPathList=()

# ===================== 远程模式 / ssh 隧道配置 =====================
#
# 【ADB client/server 架构】
#   adb 命令 (client) 默认连【本机 5037 端口】上的 adb server (daemon),
#   server 负责管理 USB 设备。client 与 server 不要求同一台机器:
#     -H <host:port>  指定连哪台主机上的 adb server (默认 localhost:5037)
#     -P <port>       只改端口 (与 -H 分开写)
#   ANDROID_ADB_SERVER_PORT 环境变量: 只改端口, 主机固定 localhost
#   三者等价 (都是连本机 50056 端口的 adb server):
#     adb -P 50056 shell
#     ANDROID_ADB_SERVER_PORT=50056 adb shell
#     adb -H localhost:50056 shell
#     ⚠ -H/-P 是 adb 全局选项, 必须放在命令 (shell/push/...) 之前,
#        adb shell -P 50056 会把 -P 当作 shell 参数, 不生效
#     ⚠ 环境变量是进程级 (影响该进程内所有 adb 调用); -H/-P 只影响本条命令
#     ⚠ 环境变量只能连本机; 要连远程主机的 server 只能用 -H
#
# 【为什么 adb server 只监听 localhost, 不对外】
#   ADB 协议无认证 —— 谁能连上谁就能控制设备 (推文件/刷机/偷数据)。
#   若 server 监听 0.0.0.0 对外开放, 任何能到达该 IP 的机器都能直接
#   adb -H <ip>:15037 操作所有设备。所以 server 端必须只绑 127.0.0.1,
#   对外访问一律走 SSH 隧道, 一次拿到三样:
#     ① 不暴露: server 继续只听 localhost, 网络层看不到 15037 端口
#     ② 有认证: 流量必须过 SSH (key 验证), 没有 key 谁也进不来
#     ③ 有加密: ADB 明文协议经 SSH 全程加密, 防中间人嗅探
#   ⚠ 切勿为了省事把 server 改成监听 0.0.0.0 用 -H 直连 —— 那是安全洞
#
# 【本地模式】
#   adb client 直连本机 adb server (默认 5037), 控制本机 USB 设备
#
# 【远程模式】
#   先建 ssh 隧道 localhost:LOCAL_PORT -> 远程:REMOTE_PORT,
#   再让 adb client 连本机 LOCAL_PORT, 实际命中远程的 adb server,
#   从而操作远程主机上插着的 USB 设备。
#   隧道在本机监听, 目标恒为 localhost:<LOCAL_PORT>, 故用环境变量
#   ANDROID_ADB_SERVER_PORT 即可 (等价 adb -H localhost:<LOCAL_PORT>):
#     adb client ──ANDROID_ADB_SERVER_PORT──→ 隧道端口 (本机)
#       ──SSH (加密+key认证)──→ 远程主机 15037 ──USB──→ device
#
# 配置持久化到 ${ADBS_CONF_FILE}, 可手动编辑 (KEY=VALUE)。
ADBS_CONF_DIR="${HOME}/.config/adbs"
ADBS_CONF_FILE="${ADBS_CONF_DIR}/adbs.conf"

# 配置项默认值 (无配置文件时使用)
cfg_mode="local"            # 模式: local | remote
cfg_remote_host=""          # ssh 目标, 如 user@1.2.3.4
cfg_local_port="5038"       # ssh 隧道本地监听端口
cfg_remote_port="5037"      # 远程 adb server 端口
cfg_scrcpy_port="27183"     # scrcpy 视频隧道本地监听端口 (scrcpy 默认值)
cfg_changed="false"         # 本次调用是否修改过配置 (用于决定是否落盘后退出)

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
    echo "proxy mode (run external adb-consuming tools on the selected device):"
    echo "    --proxy <cmd>  Run <cmd> with ADB env pinned to selected device"
    echo "                   extra args after <cmd> pass through to it"
    echo "    --scrcpy       Screen mirror: shortcut for --proxy scrcpy"
    echo "                   remote mode: auto ssh -L maps video port back,"
    echo "                   scrcpy video works through the tunnel"
    echo "                   video tunnel kept alive, --stop-tunnel to close"
    echo "    --             Forward everything after it verbatim to the proxied"
    echo "                   tool (its short options clash with adbs flags)"
    echo
    echo "mode & ssh tunnel (persisted to ${ADBS_CONF_FILE}):"
    echo "    --mode <local|remote> switch mode"
    echo "           local : use local adb server"
    echo "           remote: use remote adb server (auto setup/reuse ssh tunnel)"
    echo "    --local-port <port>   local tunnel listen port (default 5038)"
    echo "    --remote-host <host>  ssh target, e.g. user@1.2.3.4"
    echo "    --remote-port <port>  remote adb server port (default 5037)"
    echo "    --scrcpy-port <port>  scrcpy video tunnel port (default 27183)"
    echo "                           both ends equal (scrcpy tunnel-port single"
    echo "                           value); error out if occupied, pick a free one"
    echo "                           env SCRCPY_PORT overrides conf temporarily"
    echo "    --show-config         show current config"
    echo "    --stop-tunnel         stop all ssh tunnel"
    echo "    NOTE: options above only update config then exit, no adb command runs"
    echo
    echo "use session:                        "
    echo "    1. use adbs as adb command      "
    echo "       ex: adbs push <file> <dir>   "
    echo "           adbs -s push <file> <dir>"
    echo "    2. gen adb -t/-s prefix         "
    echo '       ex: adbCmd=$(adbs)           '
    echo '           adbCmd=$(adbs -s)        '
    echo "    3. proxy for tools that only know serial"
    echo '       ex: adbs --scrcpy'
    echo '           adbs --proxy atx-agent'
    echo '           adbs --scrcpy -- -r out.mp4   (-r 是 scrcpy 录像参数)'
}

# -------------------- 配置读写 --------------------

# 读取持久化配置文件 (KEY=VALUE), 安全逐行解析, 仅认已知键
# 环境变量 SCRCPY_PORT 可临时覆盖配置文件 (类比 adb 的 ANDROID_ADB_SERVER_PORT),
# 不落盘; 命令行 --scrcpy-port 仍优先 (在 proc_paras 中覆盖)
function load_config()
{
    if [ -f "${ADBS_CONF_FILE}" ]; then
        local k v
        while IFS='=' read -r k v; do
            # 跳过注释行和空行
            [[ "${k}" =~ ^[[:space:]]*# ]] && continue
            [ -z "${k}" ] && continue
            k="${k%%[[:space:]]*}"   # 去掉键两侧空白
            case "${k}" in
                MODE)        cfg_mode="${v}" ;;
                LOCAL_PORT)  cfg_local_port="${v}" ;;
                REMOTE_HOST) cfg_remote_host="${v}" ;;
                REMOTE_PORT) cfg_remote_port="${v}" ;;
                SCRCPY_PORT) cfg_scrcpy_port="${v}" ;;
            esac
        done < "${ADBS_CONF_FILE}"
    fi
    [ -n "${SCRCPY_PORT:-}" ] && cfg_scrcpy_port="${SCRCPY_PORT}"
}

# 校验配置合法性 (端口数字/模式取值), 非法则报错退出
function validate_config()
{
    case "${cfg_mode}" in
        local|remote) ;;
        *) echo "[adbs] invalid MODE: '${cfg_mode}' (expected local|remote)" >&2; exit 1 ;;
    esac
    local -a _ports=("${cfg_local_port}" "${cfg_remote_port}" "${cfg_scrcpy_port}")
    for _p in "${_ports[@]}"; do
        if ! [[ "${_p}" =~ ^[0-9]+$ ]] || [ "${_p}" -lt 1 ] || [ "${_p}" -gt 65535 ]; then
            echo "[adbs] invalid port: '${_p}' (expected 1..65535)" >&2; exit 1
        fi
    done
    if [ "${cfg_mode}" == "remote" ] && [ -z "${cfg_remote_host}" ]; then
        echo "[adbs] warning: REMOTE_HOST not set in remote mode," >&2
        echo "       use --remote-host <user@host> to specify it" >&2
    fi
}

# 把当前内存配置落盘
function save_config()
{
    mkdir -p "${ADBS_CONF_DIR}"
    cat > "${ADBS_CONF_FILE}" <<EOF
# adbSelCmd.sh 配置文件, 可手动编辑 (KEY=VALUE)
# MODE: local | remote
MODE=${cfg_mode}
LOCAL_PORT=${cfg_local_port}
REMOTE_HOST=${cfg_remote_host}
REMOTE_PORT=${cfg_remote_port}
SCRCPY_PORT=${cfg_scrcpy_port}
EOF
}

# 配置文件不存在时, 用当前内存值 (默认或已 load) 生成一份, 方便查看/编辑
function ensure_config_file()
{
    [ -f "${ADBS_CONF_FILE}" ] && return 0
    save_config
    echo "[adbs] default config generated: ${ADBS_CONF_FILE}" >&2
}

# 打印当前配置 (到 stdout)
function show_config()
{
    echo "MODE        = ${cfg_mode}"
    echo "LOCAL_PORT  = ${cfg_local_port}"
    echo "REMOTE_HOST = ${cfg_remote_host:-(not set)}"
    echo "REMOTE_PORT = ${cfg_remote_port}"
    echo "SCRCPY_PORT = ${cfg_scrcpy_port}"
}

# -------------------- ssh 隧道管理 --------------------

# 返回占用指定端口 (参数1, 缺省 LOCAL_PORT) 的 ssh 转发进程 pid。按端口查,
# 与 REMOTE_HOST 无关, 换了远端主机后仍能定位到旧隧道。端口未被 ssh 占用时输出为空。
# 同一端口可能被 ssh 同时监听 IPv4/IPv6, sort -u 已去重。
function ssh_port_owner_pid()
{
    local _port="${1:-${cfg_local_port}}"
    command -v ss > /dev/null 2>&1 || return
    ss -tlnpH 2>/dev/null \
        | grep -E ":${_port}\b" \
        | grep -oE 'users:\(\("ssh",pid=[0-9]+' \
        | grep -oE '[0-9]+$' \
        | sort -u
}

# 检查隧道是否可用: 返回 0 可用, 非 0 不可用。参数1/2 为本地端口/远端端口,
# 缺省用 LOCAL_PORT/REMOTE_PORT 配置。隧道以本地端口为唯一标识, 再用
# REMOTE_HOST 核对是否指向当前配置。两级判定:
#   1. pgrep 精确匹配本配置 (端口+远端主机) 的 ssh 转发进程。
#   2. 兜底: 本地端口在监听但看不到属主 (hidepid/跨用户), 无法核对主机, 信任复用。
#      属主可见时: 非 ssh (本机残留 adb server 误占) 或虽是 ssh 但步骤1未命中
#      (指向旧主机的残留隧道) 均不算可用, 由 ensure_ssh_tunnel 负责清理重建。
function ssh_tunnel_alive()
{
    local _lp="${1:-${cfg_local_port}}" _rp="${2:-${cfg_remote_port}}"
    [ -z "${cfg_remote_host}" ] && return 1
    # 1. 精确: 匹配本配置的 ssh 进程命令行
    pgrep -f "ssh.*-L ${_lp}:127.0.0.1:${_rp}.*${cfg_remote_host}" \
        > /dev/null 2>&1 && return 0
    # 2. 兜底: 本地端口在监听
    command -v ss > /dev/null 2>&1 || return 1
    local _ln
    _ln=$(ss -tlnpH 2>/dev/null | grep -E ":${_lp}\b")
    [ -z "${_ln}" ] && return 1
    # 看不到属主 (hidepid/跨用户) -> 可能是他人隧道, 无法核对主机, 信任复用
    echo "${_ln}" | grep -q 'users:(' || return 0
    # 属主可见但步骤1未命中: 非 ssh (本机残留 adb) 或指向旧主机的残留 ssh 隧道, 均不可用
    return 1
}

# 建立后台 ssh -L 转发隧道: 已存在直接复用, 不存在则建立, 失败返回非 0。
# $1: 本地监听端口 (缺省 LOCAL_PORT); $2: 远端目标端口 (缺省 REMOTE_PORT)。
# 远端主机始终读 REMOTE_HOST 配置。
# 复用者: adb 隧道 (默认端口); scrcpy 视频隧道 (两端同值, 以配置端口调用本函数)。
# 选项说明:
#   -fNT       -f 认证后转后台; -N 不执行远端命令; -T 不分配伪终端
#   ExitOnForwardFailure=yes  本地端口被占用导致转发失败时, ssh 立即退出
#   ServerAliveInterval/CountMax  连接保活, 远端失联后 ssh 自动退出 (避免僵尸隧道)
function ensure_ssh_tunnel()
{
    local _lp="${1:-${cfg_local_port}}" _rp="${2:-${cfg_remote_port}}"
    [ -z "${cfg_remote_host}" ] && {
        echo "[adbs] REMOTE_HOST not set in remote mode, use --remote-host to specify it" >&2
        return 1
    }
    ssh_tunnel_alive "${_lp}" "${_rp}" && return 0

    # 端口可能被占用导致 ssh -L 绑定失败, 识别并停掉占用进程:
    #   - 指向旧主机的残留 ssh 隧道 (换了 REMOTE_HOST 后遗留)
    #   - 本机残留的 adb server (之前隧道未就绪时 adb client 自启)
    local _stale
    _stale=$(ssh_port_owner_pid "${_lp}")
    if [ -n "${_stale}" ]; then
        echo "[adbs] stopping stale ssh tunnel (pid: ${_stale}) on :${_lp}" >&2
        local _q
        for _q in ${_stale}; do kill "${_q}" 2>/dev/null; done
        sleep 0.3
    fi
    if command -v ss > /dev/null 2>&1; then
        local _adb_pid
        _adb_pid=$(ss -tlnpH 2>/dev/null | grep -E ":${_lp}\b" \
            | grep -oE 'users:\(\("adb",pid=[0-9]+' | grep -oE '[0-9]+$')
        if [ -n "${_adb_pid}" ]; then
            echo "[adbs] killing stray local adb (pid ${_adb_pid}) on :${_lp}" >&2
            kill "${_adb_pid}" 2>/dev/null
            sleep 0.3
        fi
    fi

    echo "[adbs] setting up ssh tunnel: localhost:${_lp}" >&2
    echo "       -> ${cfg_remote_host}:${_rp}" >&2
    # ssh -f 认证后转后台, stdio 全部丢弃:
    #   - -f 后台化后本就无输出, 捕获无意义
    #   - 防止命令替换因 stdout 管道被后台进程继承而永久阻塞
    #     (真实 ssh -f 会自行关闭 stdio; 此处兜底不依赖其行为)
    ssh -fNT \
        -L "${_lp}:127.0.0.1:${_rp}" \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        "${cfg_remote_host}" < /dev/null > /dev/null 2>&1
    local rc=$?
    if [ ${rc} -ne 0 ]; then
        echo "[adbs] ssh tunnel setup failed (rc=${rc})" >&2
        return 1
    fi
    # ssh -f 转后台需要一点时间稳定, 轮询确认进程已存活; 每轮两次判定:
    #   1. ssh_tunnel_alive (严格: 端口监听 + 属主是目标 ssh + 主机匹配) 命中即成功
    #   2. pgrep (宽松: 只看端口形态, 不看主机/属主) 查不到 = ssh 进程已退出
    #      (认证失败 / ExitOnForwardFailure 绑定失败), 继续等没意义, 立即放弃
    #   第1行只回答"好了没", 回答不了"是不是已经没戏了", 两者缺一不可
    local _i
    for _i in $(seq 1 10); do
        ssh_tunnel_alive "${_lp}" "${_rp}" && return 0
        pgrep -f "ssh.*-L ${_lp}:127.0.0.1:${_rp}" > /dev/null 2>&1 || break
        sleep 0.3
    done
    ssh_tunnel_alive "${_lp}" "${_rp}" && return 0
    echo "[adbs] ssh tunnel process not detected after setup" >&2
    return 1
}

# 关闭占用指定端口 (参数1, 缺省 LOCAL_PORT) 的 ssh 隧道进程。按端口查,
# 与 REMOTE_HOST 无关, 换了远端主机后仍能停掉旧隧道; 配置轮转时用旧端口调用。
function stop_ssh_tunnel()
{
    local _port="${1:-${cfg_local_port}}"
    local pids=""
    # 1. 优先按端口找占用该端口的 ssh 进程
    pids=$(ssh_port_owner_pid "${_port}")
    # 2. 兜底: ss 看不到属主 (hidepid) 时, 按本地端口 pgrep 匹配
    if [ -z "${pids}" ]; then
        pids=$(pgrep -f "ssh.*-L ${_port}:" 2>/dev/null || true)
    fi
    if [ -z "${pids}" ]; then
        echo "[adbs] no ssh tunnel process found on :${_port}" >&2
        return 0
    fi
    local p
    for p in ${pids}; do kill "${p}" 2>/dev/null; done
    echo "[adbs] ssh tunnel stopped on :${_port} (pid: ${pids})" >&2
}


# -------------------- general --------------------

# 设备表表头 (调用方决定输出到 stdout/stderr)
function print_dev_header()
{
    printf "  %1s  %-8s %-4s %-18s %-12s %s\n" "#" CHIP TID SERIAL USB DTS
}

# 从 adb devices -l 输出中提取 serID/tpid/usb 三元组 (逐行对齐, 缺项留空)。
# ⚠ 三条数组必须逐行对齐: 若用三条独立 awk 各自过滤, 某行缺 usb:/transport_id
#   (网络设备/offline/unauthorized) 会导致后续索引整体错位, --proxy 包装脚本
#   按 usb 路径钉设备时会静默钉到错误设备。故单次 awk 逐行输出三元组,
#   过滤条件统一为 device 状态, 结构上保证对齐。
function extract_dev_triples()
{
    devSerIDList=()
    devTPIDList=()
    devUsbPathList=()
    local _sn _tp _usb
    while IFS=$'\t' read -r _sn _tp _usb; do
        devSerIDList+=("${_sn}")
        devTPIDList+=("${_tp}")
        devUsbPathList+=("${_usb}")
    done < <(echo "${1}" | awk '$2=="device"{
        s=$1; t=""; u="";
        for(i=1;i<=NF;i++) {
            if($i~/^transport_id:/) t=substr($i,14);
            if($i~/^usb:/)          u=substr($i,5)
        }
        print s "\t" t "\t" u
    }')
}

function gen_dev_info_list()
{
    # adb devices -l 只调一次, 复用给 serID/tpid/usb, 避免重复往返
    local _devl
    _devl=$(adb devices -l)
    extract_dev_triples "${_devl}"
    devNameList=()
    devChipList=()
    selectList=()

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    # 并行抓取每台设备的 compatible: adb over 网络往返开销大,
    # 串行会随设备数线性累加, 并行后总耗时近似单次往返
    # timeout 3 兜底: 单台设备 adbd 无响应时 (adb 客户端无超时),
    # 避免 wait 挂死整个菜单; 超时的设备名显示 "--"
    local _tmpdir
    _tmpdir=$(mktemp -d)
    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        ( timeout 3 adb -t ${devTPIDList[${i}]} \
            shell "cat /proc/device-tree/compatible" 2>/dev/null \
            | tr '\0' '\n' > "${_tmpdir}/${i}.raw" ) &
    done
    wait

    for ((i = 0; i < ${#devTPIDList[@]}; i++))
    do
        # compatible 以 null 分隔多条, 先按 null 拆行, 取首个含 rk/rv 的条目
        local compatRaw=$(cat "${_tmpdir}/${i}.raw" 2>/dev/null)
        nameTmp=$(echo "${compatRaw}" | grep -m1 -E 'r[kv][0-9]')
        # 去掉厂商前缀(首个逗号前的部分), 如 rockchip,xxx -> xxx
        nameTmp=${nameTmp#rockchip,}
        devNameList[${i}]=${nameTmp}
        # 芯片名称: 取板级名首个 "-" 之前的部分 (如 rk3588, rv1126b, rk3588s)
        local chipTmp=${nameTmp%%-*}
        devChipList[${i}]=${chipTmp}
        # 字段顺序: 芯片 -> TrsptID -> serID -> usb 路径 -> 设备树(板级名)
        selectList[${i}]=$(printf \
            "%-8s %-4s %-18s %-12s %s" \
            "${devChipList[${i}]:--}" "${devTPIDList[${i}]}" \
            "${devSerIDList[${i}]}" "${devUsbPathList[${i}]:--}" \
            "${devNameList[${i}]:--}")
    done
    rm -rf "${_tmpdir}"
}

function gen_adb_cmd()
{
    mSelectedDev=""

    if [ "${cmd_sel_idx}" == "" ]; then
        if [ ${#devTPIDList[@]} -gt 1 ]; then
            select_node "${sel_tag_adbs}" "selectList" "mSelectedDev" "device" "$(print_dev_header)"
            # select_node 只回传条目文本, 回查其在 selectList 中的下标
            for ((i = 0; i < ${#selectList[@]}; i++)); do
                [ "${selectList[${i}]}" == "${mSelectedDev}" ] && { cmd_sel_idx=${i}; break; }
            done
        else
            cmd_sel_idx=0
            mSelectedDev=${selectList[0]}
        fi
    else
        mSelectedDev=${selectList[${cmd_sel_idx}]}
    fi

    if [ "${cmd_gen_s_style}" == "true" ]; then
        adbCmd="adb -s ${devSerIDList[${cmd_sel_idx}]}"
    else
        adbCmd="adb -t ${devTPIDList[${cmd_sel_idx}]}"
    fi

    # 远程模式: 前置 adb server 端口环境变量, 让回显的命令也能命中隧道。
    # 用 env 前缀而非 VAR=val, 因为 adbCmd 会被无引号展开再执行,
    # 裸 VAR=val 会被当作命令名; env 是独立命令, 展开执行都正确。
    [ "${cfg_mode}" == "remote" ] && \
        adbCmd="env ANDROID_ADB_SERVER_PORT=${cfg_local_port} ${adbCmd}"

    echo ${adbCmd}
}


# ---------------------- usb/root/remount ----------------------

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
    # 唯一匹配才可信: 0 条继续往上; 多条说明已到达被多设备共享的根 Hub, 结果歧义, 放弃
    local adb_line=""
    local _try="${usb_path_prefix}"
    for _i in 1 2 3; do
        local _matches=$(adb devices -l 2>/dev/null | grep -E "${_try}(\.|$| )" || true)
        if [ -n "${_matches}" ]; then
            local _cnt=$(echo "${_matches}" | grep -c .)
            if [ "${_cnt}" -eq 1 ]; then
                adb_line="${_matches}"
                break
            fi
            # 多条匹配: 前缀已共享, 越往上只会越多, 直接放弃
            return
        fi
        # 去掉最后一段, 往上走一级 Hub
        local _prev="${_try}"
        _try="${_try%.*}"
        [ "${_try}" = "${_prev}" ] && break
    done
    [ -z "${adb_line}" ] && return

    # 提取 transport_id
    local tpid=$(echo "${adb_line}" | grep -oP 'transport_id:\K\d+')
    [ -z "${tpid}" ] && return

    # 通过 adb 查询 /proc/device-tree/compatible
    # compatible 是以 null 分隔的列表, 每行只保留第一个条目
    local compat=$(timeout 3 adb -t "${tpid}" \
        shell "cat /proc/device-tree/compatible" 2>/dev/null | tr '\0' '\n' | head -1)
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
    local _sep=\
        $(printf '%-3s %-12s %-10s %-10s %-8s %-22s %-23s' '' '' '' '' '' '' '' | tr ' ' '-')
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
                product=$(cat "${usb_dev_path}/product" 2>/dev/null \
                    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                # 平台信息 (SoC), 按优先级依次尝试:
                # 1. 通过 USB Hub 路径匹配 adb 设备, 远程查询 /proc/device-tree/compatible (最准确)
                local _usb_phy=$(cat "${usb_dev_path}/devpath" 2>/dev/null)
                local _busnum=$(cat "${usb_dev_path}/busnum" 2>/dev/null)
                if [ -n "${_usb_phy}" ] && [ -n "${_busnum}" ]; then
                    platform=$(query_soc_by_usb_path "usb:${_busnum}-${_usb_phy}")
                fi

                # 2. product 字符串中直接含 SoC 名称 (如 Rockchip Gadget 的 "rk3588_s", "rk3566_t")
                [ -z "${platform}" ] && {
                    local _manufacturer=$(cat "${usb_dev_path}/manufacturer" 2>/dev/null \
                        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
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
               "${idx}" "${devname}" "${driver:-"-"}" "${vidpid}" \
               "${baud}" "${product:-"-"}" "${platform:-"-"}"

        ((idx++))
    done

    echo ""
    echo "Total: ${#tty_list[@]} USB serial device(s)"
}

function root_remount_no_info_devs()
{
    # 逐行对齐提取 serID/tpid/usb (见 extract_dev_triples 注释)
    extract_dev_triples "$(adb devices -l)"
    # USB 物理路径 (如 1-9.3.2): 描述设备在 USB 总线拓扑中的物理位置, 同一设备换口则变,
    # 用于区分多台同型号 adb 设备
    # VID:PID (如 2207:350a): 描述设备的身份, 由硬件固化, 换口不变, 用于标识 USB 串口设备的类型

    [ ${#devTPIDList[@]} -eq 0 ] && { echo "No device found!" >&2; exit 0; }

    local need_root_tpids=()
    local -A need_root_usb
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        # `adb shell id` returns uid=0(root) when rooted, uid=2000(shell) when not
        local uid=`timeout 3 adb -t ${devTPIDList[${i}]} shell id 2>/dev/null | grep -oP 'uid=\K\d+'`
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
    extract_dev_triples "$(adb devices -l)"
    # 仅对需要 root 的设备执行 remount (通过稳定的 USB 路径匹配)
    for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
        if [[ -n "${need_root_usb[${devUsbPathList[${i}]}]}" ]]; then
            adb -t ${devTPIDList[${i}]} remount
        fi
    done
    sleep 1
}


# -------------------- scrcpy --------------------

# 生成"钉死目标设备"的 adb 包装脚本 (供 --proxy/--scrcpy 使用)
#
# 【问题】scrcpy 等外部程序只认 serial (-s), 不支持 transport ID (-t),
#   而多台同 serial 设备 (如全 0 序列号) 只有 -t 能区分。
# 【解决】scrcpy 支持 ADB 环境变量指定 adb 路径:
#   1. 本函数生成临时包装脚本, 内部统一用 -t <transport_id> 定位目标设备;
#   2. 调用方以 ADB=<脚本路径> 启动外部程序, 其所有 adb 调用都走包装脚本。
# 【为什么包装脚本要重新解析 transport id】
#   adb 的 transport id 在设备重连/adb server 重启后会重编号, 生成时刻注入的
#   旧 tpid 可能已失效或指向别的设备 (多台同型号设备环境会静默错控设备, 如
#   scrcpy 镜像到了隔壁同型号设备)。故包装脚本每次被调用时, 先按目标设备的
#   USB 物理路径 (设备重连不变, 最稳定) 重新解析当前 transport id;
#   无 usb 路径 (网络设备) 时按 serial 解析, 重复 serial 视为无法区分;
#   解析不到则报错退出 —— 宁可失败也不连错设备。
# 【包装脚本处理三类命令】
#   1. adb devices: 拦截 → 伪造单设备列表输出, 让外部程序以为只有一个设备
#   2. adb reverse: 拦截 → 强制失败, 逼 scrcpy 4.x 走 forward 回退:
#      部分设备 (RK adbd) 的 reverse 注册成功但设备端 socket 连不上;
#      且 adb server 非本机 (隧道/容器) 时 reverse 宿主端在远端, scrcpy 本地
#      连不上。forward 回退端口固定 27183, 便于做端口映射。--remove/--list 放行。
#   3. 其他命令 (如 shell/push): 剥离 -s/--serial 参数 (避免与 -t 冲突),
#      → 改用 adb -t <tp_id> <原始命令> 执行
# 【实现要点】
#   用 sed 做占位符替换而非直接展开变量: heredoc 加引号 (<<'EOF') 禁展开,
#   保护脚本内 $1 $@ $# 等不被提前解释; __USBPATH__/__SERIAL__/__APORT__
#   是唯一注入点。远程模式注入 export ANDROID_ADB_SERVER_PORT, 让包装器内的
#   adb 走 ssh 隧道; 本地模式该行为空 (sed 替换成空行, 无副作用)。
#   ⚠ scrcpy 视频平面: 远程模式下 adb forward 的监听端口绑在远端主机,
#     scrcpy 连本机端口会落空。--scrcpy 已在 main 中自动建 ssh -L 把远端
#     27183 映射回本机 (见 ensure_ssh_tunnel 参数化用法), 非默认端口时补 --tunnel-port。
function gen_adb_wrapper()
{
    # 从 adbCmd 反查选中的设备 idx。
    # ⚠ 不能用 cmd_sel_idx: gen_adb_cmd 里 select_node 的交互选择发生在命令替换
    #   (adbCmd=`gen_adb_cmd`) 的子 shell 中, 匹配出的 cmd_sel_idx 传不回父 shell,
    #   父 shell 中它是空串, 数组索引 "" 会落到第 0 台设备 (多台设备时静默错控)。
    #   adbCmd 是子 shell 输出的正确结果, 从它反查最可靠。
    local _sel_idx=""
    if [[ "${adbCmd}" == *"-t "* ]]; then
        # -t 风格 (默认): 末字段是 transport id (兼容远程模式 env 前缀)
        local _tp="${adbCmd##* }"
        for ((i = 0; i < ${#devTPIDList[@]}; i++)); do
            [ "${devTPIDList[${i}]}" == "${_tp}" ] && { _sel_idx=${i}; break; }
        done
    else
        # -s 风格: -s 后跟 serial
        local _sn_tmp="${adbCmd##*-s }"
        _sn_tmp="${_sn_tmp%% *}"
        for ((i = 0; i < ${#devSerIDList[@]}; i++)); do
            [ "${devSerIDList[${i}]}" == "${_sn_tmp}" ] && { _sel_idx=${i}; break; }
        done
    fi
    [ -z "${_sel_idx}" ] && { echo "[adbs] cannot resolve selected device" >&2; return 1; }

    local _wrap
    _wrap=$(mktemp /tmp/adb_t_XXXXXX) || return 1
    local _port_line=""
    [ "${cfg_mode}" == "remote" ] && _port_line="export ANDROID_ADB_SERVER_PORT=${cfg_local_port}"
    sed -e "s|__USBPATH__|${devUsbPathList[${_sel_idx}]:-}|" \
        -e "s|__SERIAL__|${devSerIDList[${_sel_idx}]}|" \
        -e "s|__APORT__|${_port_line}|" > "${_wrap}" <<'EOF'
#!/bin/bash
__APORT__
# 生成时刻注入的定位键:
#   __USBPATH__  目标设备 USB 物理路径 (最稳定, 设备重连不变)
#   __SERIAL__   目标设备 serial (仅 __USBPATH__ 为空时使用, 如网络设备)
# transport id 在设备重连/adb server 重启后会重编号, 生成时刻的 tpid 不可信,
# 每次调用都按定位键重新解析当前 transport id; 解析不到则报错退出,
# 宁可失败也不连错设备 (多台同型号设备环境会静默错控设备)。
_devl=$(adb devices -l 2>/dev/null)
_line=""
if [ -n "__USBPATH__" ]; then
    # 有 usb 物理路径: 只按路径匹配 (字段级: 路径后必须空白或行尾, 防误配相似路径)
    _line=$(echo "${_devl}" | grep -m1 -E "usb:__USBPATH__([[:space:]]|$)")
else
    # 无 usb 路径 (网络设备): 按 serial 匹配; 重复 serial 无法区分, 视为未命中
    _line=$(echo "${_devl}" | grep -E "^__SERIAL__[[:space:]]")
    [ "$(echo "${_line}" | grep -c .)" -ne 1 ] && _line=""
fi
_tp=$(echo "${_line}" | grep -oP 'transport_id:\K\d+')
_sn=$(echo "${_line}" | awk '{print $1}')
[ -z "${_tp}" ] && { echo "target device not found" >&2; exit 1; }
if [ "$1" = "devices" ]; then
    # 拦截 devices 命令: 只返回目标设备, 让外部程序以为只有一个设备
    [ -z "${_sn}" ] && exit 0
    printf 'List of devices attached\n%s\tdevice\n' "${_sn}"
elif [ "$1" = "start-server" ] || [ "$1" = "kill-server" ] \
    || [ "$1" = "version" ] || [ "$1" = "help" ]; then
    # server 管理/全局命令: 原样转发, 不注入 -t。
    # adb -t N start-server 会 protocol fault (rc=255), scrcpy 4.x 对
    # start-server 退出码敏感, 一旦失败直接中止。
    exec adb "$@"
else
    # 其他命令: 剥离 -s/--serial 避免 adb 同时收到 -t 和 -s 冲突,
    # 统一通过 -t <transport_id> 定位设备
    # 初始化空数组, 用于收集过滤后的参数
    _a=()
    while [ $# -gt 0 ]; do
        case "$1" in
            # -s|--serial: 跳过标志和紧随的 serial 值(shift 2);
            # shift 2 失败时 (如 -s 是末位参数) 至少 shift 1 保证循环能结束
            -s|--serial) shift 2 2>/dev/null || shift ;;
            # --serial=xxx: 丢弃该参数; 必须 shift, 否则死循环
            --serial=*) shift ;;
            # 其他参数: 保留到数组 _a
            *) _a+=("$1"); shift ;;
        esac
    done
    # scrcpy 4.x 默认用 adb reverse 建隧道: 部分设备 (RK adbd) 注册成功但
    # 设备端 socket 连不上, 且 adb server 非本机时 reverse 宿主端在远端,
    # scrcpy 本地连不上。强制 reverse 注册失败逼 scrcpy 走 forward 回退;
    # --remove/--list/--remove-all 等清理命令必须放行。
    if [ "${_a[0]}" = "reverse" ] && [ "${_a[1]:-}" != "--remove" ] \
        && [ "${_a[1]:-}" != "--list" ] && [ "${_a[1]:-}" != "--remove-all" ]; then
        echo "adb: error: reverse tunnel not supported" >&2
        exit 1
    fi
    # 用 transport ID 执行过滤后的命令, 剥离的 -s 被替换为 -t
    exec adb -t "${_tp}" "${_a[@]}"
fi
EOF
    chmod +x "${_wrap}"
    echo "${_wrap}"
}

# 代理模式主流程: 不执行 adb 本身, 而是生成"钉死目标设备"的 adb 包装器,
# 以 ADB 环境变量交给外部程序 (scrcpy 等只认 serial 的工具) 使用,
# 内部统一用 -t <transport_id> 定位, 绕过 serial 重复问题。
# 调用前需已完成设备选择 (gen_adb_cmd), 由 main 代理分支调用, 路径内 exit。
function run_proxy_cmd()
{
    local _wrap
    _wrap=$(gen_adb_wrapper) || exit 1
    local _extra=()
    # Ctrl-C / 正常退出只清理临时包装脚本; scrcpy 隧道常驻, 不随退出销毁
    # (复用/轮转/手动关闭均与 adb 隧道一致, 见 ensure_ssh_tunnel 注释)
    trap 'rm -f "${_wrap}"' EXIT INT
    if [ "${cmd_proxy_cmd}" == "scrcpy" ]; then
        if [ "${cfg_mode}" == "remote" ]; then
            # 远端模式视频隧道 = ensure_ssh_tunnel P P 特例 (scrcpy tunnel-port
            # 单值, 隧道两端同值)。原理:
            #   scrcpy 4.x 默认 adb reverse 建通道, wrapper 强制失败后回退
            #   forward: 远端 adb server 执行 forward tcp:P localabstract:scrcpy
            #   (监听在远端主机), scrcpy 同时连本机 127.0.0.1:P → 需 ssh -L
            #   把本机 P 接回远端 P。forward 是 scrcpy 经 ADB 环境变量自己发的,
            #   adbs 只建隧道 + 必要时补 --tunnel-port。
            #   三个 P 必须相同: --tunnel-port=P 同时驱动远端 forward 监听端口
            #   与本机连接端口, 隧道是透明管道, 远端配 Q 则流量无人监听。
            #   端口被占/建失败 → 报错提示换 --scrcpy-port (不做自动顺延)。
            if ! ensure_ssh_tunnel "${cfg_scrcpy_port}" "${cfg_scrcpy_port}"; then
                echo "[adbs] scrcpy tunnel setup failed on :${cfg_scrcpy_port}," >&2
                echo "       if the port is occupied, pick another one with --scrcpy-port <port>" >&2
                exit 1
            fi
            _sport=${cfg_scrcpy_port}
            if [ "${_sport}" != "27183" ] \
                && [[ "${cmd_orgAdbOpt}" != *"--tunnel-port"* ]]; then
                _extra+=(--tunnel-port="${_sport}")
            fi
            echo "[adbs] scrcpy video tunnel: localhost:${_sport} -> ${cfg_remote_host}:${_sport}" >&2
        elif [ -n "${ANDROID_ADB_SERVER_PORT}" ] \
            && [ "${ANDROID_ADB_SERVER_PORT}" != "5037" ]; then
            # 容器等场景: adb server 非本机但无 ssh 通道, 无法自动建隧道, 打印提示
            echo "[adbs] tip: adb server 非本机, scrcpy 隧道端口需映射:" >&2
            echo "       ssh -L 27183:127.0.0.1:27183 <server_host>" >&2
            echo "       (容器场景: 把容器内 27183 端口发布到宿主机)" >&2
        fi
    fi
    echo "[adbs] proxying '${cmd_proxy_cmd}' via ${_wrap}" >&2
    ADB="${_wrap}" ${cmd_proxy_cmd} ${cmd_orgAdbOpt} "${_extra[@]}"
    local _rc=$?
    rm -f "${_wrap}"
    exit ${_rc}
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
            --proxy)   [ -z "$2" ] && \
                           { echo "[adbs] --proxy requires a command" >&2; exit 1; }
                       cmd_proxy_cmd="$2"; shift ;;
            --scrcpy)  cmd_proxy_cmd="scrcpy" ;;
            --idx)     cmd_sel_idx="$2"; shift ;;
            --soc)     cmd_soc_info="$2"; shift ;;
            # ---- 模式 / 隧道配置 (修改后落盘并退出) ----
            --mode)        cfg_mode="$2"; shift; cfg_changed="true" ;;
            --remote-host) cfg_remote_host="$2"; shift; cfg_changed="true" ;;
            --local-port)  cfg_local_port="$2";  shift; cfg_changed="true" ;;
            --remote-port) cfg_remote_port="$2"; shift; cfg_changed="true" ;;
            --scrcpy-port) cfg_scrcpy_port="$2"; shift; cfg_changed="true" ;;
            --show-config) show_config; exit 0 ;;
            --stop-tunnel) stop_ssh_tunnel; stop_ssh_tunnel "${cfg_scrcpy_port}"; exit 0 ;;
            --)            shift; cmd_orgAdbOpt=$@; return ;;
            *)             cmd_orgAdbOpt=$@; return ;;
        esac
        shift
    done
}

# ====== main ======
source ${HOME}/bin/_select_node.sh

function main()
{
    load_config
    # 配置文件不存在则用默认值自动生成一份, 保证文件始终存在
    ensure_config_file
    # 快照变更前的配置, 用于检测隧道相关参数是否真正变化 (决定是否轮转隧道)
    local _old_mode="${cfg_mode}" _old_host="${cfg_remote_host}" \
          _old_lport="${cfg_local_port}" _old_rport="${cfg_remote_port}" \
          _old_sport="${cfg_scrcpy_port}"
    proc_paras $@

    # 仅修改配置的调用: 校验 -> 落盘 -> 打印 -> 退出 (不执行 adb 命令)
    if [ "${cfg_changed}" == "true" ]; then
        validate_config
        save_config
        echo "[adbs] config updated:" >&2
        show_config >&2
        # 配置变更即作为隧道生命周期事件: 若隧道相关参数 (模式/主机/端口) 真正变化,
        # 则停掉旧隧道 (用旧端口, 兼容 LOCAL_PORT 变更)。
        # 随后远程模式一律确保隧道就绪: 参数变了就重建, 没变但隧道缺失就补建,
        # 已就绪则直接复用。adb 隧道与 scrcpy 视频隧道同步预创建,
        # 之后运行时只需检查, 不再被动创建/轮转。
        local _old_sig="${_old_mode}|${_old_host}|${_old_lport}|${_old_rport}|${_old_sport}"
        local _new_sig="${cfg_mode}|${cfg_remote_host}|${cfg_local_port}|${cfg_remote_port}|${cfg_scrcpy_port}"
        if [ "${_old_sig}" != "${_new_sig}" ] && [ "${_old_mode}" == "remote" ]; then
            stop_ssh_tunnel "${_old_lport}"
            # scrcpy 视频隧道与 adb 隧道同机制 (仅端口不同, 两端同值),
            # 配置轮转时用旧 scrcpy 端口停掉 (正常随 scrcpy 退出已清理, 防残留)
            stop_ssh_tunnel "${_old_sport}"
        fi
        if [ "${cfg_mode}" == "remote" ]; then
            ensure_ssh_tunnel \
                || echo "[adbs] tunnel not up yet; will retry on next adbs run" >&2
            # scrcpy 视频隧道同机制预创建: 配置了远程相关参数即建,
            # --scrcpy 运行时只检查复用 (见 run_proxy_cmd);
            # 失败报错 (如端口被占), 不阻塞配置生效
            ensure_ssh_tunnel "${cfg_scrcpy_port}" "${cfg_scrcpy_port}" || {
                echo "[adbs] scrcpy tunnel setup failed on :${cfg_scrcpy_port}," >&2
                echo "       if the port is occupied, pick another one with --scrcpy-port <port>" >&2
            }
        fi
        exit 0
    fi

    # -u 列出本机 USB 串口, 属本机硬件操作, 不走隧道, 最先处理
    if [ "${cmd_list_usb_serial}" == "true" ]; then
        if [ "${cfg_mode}" == "remote" ]; then
            echo "[adbs] -u is a local hardware op, skipped in remote mode" >&2
            exit 0
        fi
        list_usb_serial_devs; exit 0
    fi

    # 以下为依赖 adb 设备的操作: 远程模式需先确保 ssh 隧道就绪,
    # 并让本进程内所有 adb 调用都连到隧道端口 (通过 export 给子进程)
    if [ "${cfg_mode}" == "remote" ]; then
        ensure_ssh_tunnel || exit 1
        export ANDROID_ADB_SERVER_PORT="${cfg_local_port}"
    fi

    [ "${cmd_root_remount}" == "true" ] && { root_remount_no_info_devs; exit 0; }

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
        [ ${#soc_match_list[@]} -eq 0 ] && \
            { echo "No device matching '${cmd_soc_info}' found!" >&2; exit 1; }
        if [ ${#soc_match_list[@]} -eq 1 ]; then
            cmd_sel_idx="${soc_match_list[0]}"
        else
            echo "Multiple devices matching '${cmd_soc_info}', using the first one:" >&2
            print_dev_header >&2
            for idx in "${soc_match_list[@]}"; do
                echo " [$idx] ${selectList[${idx}]}" >&2
            done
            cmd_sel_idx="${soc_match_list[0]}"
        fi
    fi

    if [ ${cmd_get_count} == "true" ]; then
        echo "${#selectList[@]}"
    elif [ "${cmd_list_devs}" == "true" ]; then
        print_dev_header
        for ((cur_idx = 0; cur_idx < ${#selectList[@]}; cur_idx++))
        do
            printf " %2d  %s\n" "${cur_idx}" "${selectList[${cur_idx}]}"
        done
    else
        adbCmd=`gen_adb_cmd`
        [ -z "${adbCmd}" ] && exit 0
        [ -n "${cmd_proxy_cmd}" ] && run_proxy_cmd
        [ -z "${cmd_orgAdbOpt}" ] && echo ${adbCmd} || ${adbCmd} ${cmd_orgAdbOpt}
    fi
}

main $@
