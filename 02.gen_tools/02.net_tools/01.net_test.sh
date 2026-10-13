#!/usr/bin/env bash
#########################################################################
# File Name: 01.net_test.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Mon 12 Oct 2026 04:50:00 PM CST
#
# 网络健康检查工具（稳定的 CLI 测速/诊断，替代浏览器测速）
#
# 设计约定:
#   - 对外只暴露一个函数 nettest；其余全部 _nettest_ 前缀，sourced 不污染命名空间
#   - 方法固定（固定测速源 + 固定并发）→ 每次/每台机结果可直接对比
#   - 内部自动清理代理；并【分别】测“直连 / 走代理”两种速度
#   - 代理来源: --proxy > 环境变量(http_proxy…) > macOS 系统代理(scutil)
#   - 兼容 bash / zsh；跨平台 macOS / Linux；强制 LC_ALL=C 保证解析稳定
#
# 分层（自底向上，互不反向依赖）:
#   0) 配置    _nettest_cfg_*     只读配置，集中管理
#   1) 基础件  _nettest_*         纯工具/探测，无业务编排
#   2) 测速源  _nettest_pick_source
#   3) 测量    _nettest_measure_* 单次测量原语，只返回数据
#   4) 报告    _nettest_print_*   只做格式化，不测量
#   5) 编排    _nettest_run_once  串起“采集→聚合→渲染”，只做编排
#   6) 入口    nettest            参数解析 + 校验 + 监控循环
#########################################################################

# =====================================================================
# 0) 配置（集中管理；换目标/镜像只改这里）
# =====================================================================
_nettest_cfg_net_targets()    { echo "223.5.5.5 119.29.29.29 114.114.114.114"; }
_nettest_cfg_net_targets6()   { echo "2400:3200::1 240c::6666"; }
_nettest_cfg_mirror_dirs()    { echo "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/24.04 \
https://mirrors.ustc.edu.cn/ubuntu-releases/24.04 \
https://mirrors.nju.edu.cn/ubuntu-releases/24.04 \
https://mirror.nju.edu.cn/ubuntu-releases/24.04 \
https://mirrors.aliyun.com/ubuntu-releases/24.04 \
https://mirrors.cloud.tencent.com/ubuntu-releases/24.04"; }
_nettest_cfg_fallback_files() { echo "https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ls-lR.gz \
https://mirrors.ustc.edu.cn/ubuntu/ls-lR.gz \
https://mirrors.nju.edu.cn/ubuntu/ls-lR.gz"; }
_nettest_cfg_upload_url()     { echo "https://speed.cloudflare.com/__up"; }
_nettest_cfg_upload_mb()      { echo "30"; }
_nettest_cfg_trace_host()     { echo "mirrors.tuna.tsinghua.edu.cn"; }
_nettest_cfg_dns_domains()    { echo "www.baidu.com www.taobao.com github.com"; }
_nettest_cfg_ua()             { echo "nettest/1.0"; }

# =====================================================================
# 1) 基础件（纯工具/探测，无业务编排）
# =====================================================================

# --- 1.1 数值 ---
_nettest_mbps() { awk -v b="${1:-0}" -v d="${2:-1}" 'BEGIN{printf "%.0f", b*8/d/1e6}'; }

# 聚合: <mode:best|median> <v1> <v2> ...  -> 一个数
_nettest_agg()
{
    local mode="$1"; shift
    [ "$#" -eq 0 ] && { echo 0; return; }
    if [ "$mode" = "median" ]; then
        printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+2)/2)]}'
    else
        printf '%s\n' "$@" | sort -n | tail -1
    fi
}

# 聚合文件里某一列: <mode> <col> <file> -> 一个数
_nettest_agg_col() { _nettest_agg "$1" $(awk -v c="$2" '{print $c}' "$3"); }

_nettest_is_posint()    { case "$1" in ''|*[!0-9]*) return 1;; esac; [ "$1" -gt 0 ]; }
_nettest_is_nonnegint() { case "$1" in ''|*[!0-9]*) return 1;; esac; return 0; }

# --- 1.2 环境 ---
_nettest_check_deps()
{
    local miss=""
    command -v curl >/dev/null 2>&1 || miss="$miss curl"
    command -v ping >/dev/null 2>&1 || miss="$miss ping"
    [ -n "$miss" ] && { echo "!! 缺少依赖:$miss（无法测速）"; return 1; }
    return 0
}

_nettest_gateway()
{
    if [ "$(uname -s)" = "Darwin" ]; then
        route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}'
    else
        ip route 2>/dev/null | awk '/^default/{print $3; exit}'
    fi
}

_nettest_has_ipv6() { ifconfig 2>/dev/null | grep 'inet6' | grep -qv 'fe80'; }

# --- 1.3 网络请求 ---
# 统一 curl: 第一个参数是网卡(空=默认路由)，其余透传
_nettest_curl()
{
    local iface="$1"; shift
    local -a base=(curl -s -L -A "$(_nettest_cfg_ua)" --connect-timeout 5)
    if [ -n "$iface" ] && [ "$iface" != "-" ]; then
        "${base[@]}" --interface "$iface" "$@"
    else
        "${base[@]}" "$@"
    fi
}

# URL 是否存在（取 1 字节，HTTP 200/206 有效）
_nettest_url_ok()
{
    local code
    code=$(_nettest_curl "$2" -r 0-0 -o /dev/null -w '%{http_code}' --max-time 12 "$1" 2>/dev/null)
    [ "$code" = "206" ] || [ "$code" = "200" ]
}

# --- 1.4 延迟测量 ---
# ping 输出(stdin) -> "loss avg max mdev"（兼容 macOS round-trip / Linux rtt min）
_nettest_parse_ping()
{
    local o loss rtt
    o=$(cat)
    loss=$(printf '%s' "$o" | grep -oE '[0-9.]+% packet loss' | grep -oE '^[0-9.]+')
    rtt=$(printf '%s' "$o" | awk -F'= ' '/round-trip|rtt min/{print $2; exit}')
    if [ -z "$rtt" ]; then echo "${loss:-100} - - -"; return; fi
    echo "${loss:-0} $(echo "$rtt" | awk -F'/' '{print $2}') $(echo "$rtt" | awk -F'/' '{print $3}') $(echo "$rtt" | awk -F'/' '{print $4}' | awk '{print $1}')"
}
_nettest_ping_stats()
{
    if [ "$(uname -s)" = "Darwin" ]; then ping -c 20 -i 0.2 -t 10 "$1" 2>/dev/null
    else ping -c 20 -i 0.2 -w 10 "$1" 2>/dev/null; fi | _nettest_parse_ping
}
_nettest_ping6_stats()
{
    if [ "$(uname -s)" = "Darwin" ]; then
        if command -v ping6 >/dev/null 2>&1; then ping6 -c 10 -i 0.2 -t 10 "$1" 2>/dev/null
        else ping -6 -c 10 -i 0.2 -t 10 "$1" 2>/dev/null; fi
    else
        if command -v ping6 >/dev/null 2>&1; then ping6 -c 10 -i 0.2 -w 10 "$1" 2>/dev/null
        else ping -6 -c 10 -i 0.2 -w 10 "$1" 2>/dev/null; fi
    fi | _nettest_parse_ping
}

# --- 1.5 其它探测 ---
_nettest_dns_time()
{
    command -v python3 >/dev/null 2>&1 || { echo "(未装 python3, 跳过 DNS)"; return; }
    python3 - "$@" <<'PY'
import time,socket,sys
res=[]
for d in sys.argv[1:]:
    t=time.time()
    try: socket.getaddrinfo(d,443); res.append(f"{d}={(time.time()-t)*1000:.0f}ms")
    except Exception: res.append(f"{d}=FAIL")
print("  ".join(res))
PY
}

_nettest_sort_desc()
{
    local out; out=$(sort -V 2>/dev/null)
    [ -z "$out" ] && out=$(sort 2>/dev/null)
    printf '%s\n' "$out"
}

# --- 1.6 代理 ---
# 探测: --proxy 参数 > 环境变量 > macOS 系统代理 -> URL 或空
_nettest_detect_proxy()
{
    local arg="$1"
    [ -n "$arg" ] && { echo "$arg"; return; }
    [ -n "${https_proxy:-}" ] && { echo "$https_proxy"; return; }
    [ -n "${http_proxy:-}" ]  && { echo "$http_proxy";  return; }
    [ -n "${all_proxy:-}" ]   && { echo "$all_proxy";   return; }
    if [ "$(uname -s)" = "Darwin" ]; then
        local p host port
        p=$(scutil --proxy 2>/dev/null)
        if echo "$p" | grep -q 'HTTPSEnable : 1'; then
            host=$(echo "$p" | awk '/HTTPSProxy/{print $3}'); port=$(echo "$p" | awk '/HTTPSPort/{print $3}')
            [ -n "$host" ] && { echo "http://$host:$port"; return; }
        fi
        if echo "$p" | grep -q 'HTTPEnable : 1'; then
            host=$(echo "$p" | awk '/HTTPProxy/{print $3}'); port=$(echo "$p" | awk '/HTTPPort/{print $3}')
            [ -n "$host" ] && { echo "http://$host:$port"; return; }
        fi
        if echo "$p" | grep -q 'SOCKSEnable : 1'; then
            host=$(echo "$p" | awk '/SOCKSProxy/{print $3}'); port=$(echo "$p" | awk '/SOCKSPort/{print $3}')
            [ -n "$host" ] && { echo "socks5://$host:$port"; return; }
        fi
    fi
    echo ""
}
_nettest_proxy_on()  { export http_proxy="$1" https_proxy="$2"; [ -n "$3" ] && export all_proxy="$3"; return 0; }
_nettest_proxy_off() { unset http_proxy https_proxy all_proxy; return 0; }

# =====================================================================
# 2) 测速源解析（多镜像 + 存在性校验 + 兜底）
# =====================================================================
_nettest_pick_source()
{
    local iface="$1" d name url list
    for d in $(_nettest_cfg_mirror_dirs); do
        list=$(_nettest_curl "$iface" "$d/" 2>/dev/null | grep -oE 'ubuntu-[0-9.]+-(desktop|live-server)-amd64\.iso')
        name=$(printf '%s\n' "$list" | _nettest_sort_desc | tail -1)
        [ -z "$name" ] && continue
        url="$d/$name"
        _nettest_url_ok "$url" "$iface" && { echo "$url"; return 0; }
    done
    for d in $(_nettest_cfg_fallback_files); do
        _nettest_url_ok "$d" "$iface" && { echo "$d"; return 0; }
    done
    echo ""; return 1
}

# =====================================================================
# 3) 测量原语（只测量/返回数据）
# =====================================================================

# 重复采集: <n> <outfile> <cmd...>  —— 执行 cmd n 次，每次输出追加到 outfile
_nettest_collect()
{
    local n="$1" out="$2"; shift 2
    : > "$out"
    local r=1
    while [ "$r" -le "$n" ]; do "$@" >> "$out"; r=$((r+1)); done
}

# 下载: <conns> <dur> <url> <iface> <tmpbase> -> 总字节
_nettest_measure_download()
{
    local conns="$1" dur="$2" url="$3" iface="$4" tmpbase="${5:-${TMPDIR:-/tmp}}"
    local td total i
    local -a pids=()
    td=$(mktemp -d "$tmpbase/dl.XXXXXX") || { echo 0; return; }
    for i in $(seq 1 "$conns"); do
        (
            local start now rem n collected=0
            start=$(date +%s)
            while :; do
                now=$(date +%s); rem=$((dur - (now - start)))
                [ "$rem" -le 0 ] && break
                n=$(_nettest_curl "$iface" -o /dev/null -w '%{size_download}' --max-time "$rem" "$url" 2>/dev/null)
                [ -z "$n" ] && break
                collected=$((collected + n))
                [ "$n" -eq 0 ] && break
            done
            echo "$collected" > "$td/$i"
        ) &
        pids+=($!)
    done
    wait "${pids[@]}" 2>/dev/null || wait
    total=$(cat "$td"/* 2>/dev/null | awk '{s+=$1} END{print s+0}')
    rm -rf "$td"
    echo "${total:-0}"
}

# 上行: <url> <megabytes> <iface> <tmpbase> -> 字节/秒
_nettest_measure_upload()
{
    local url="$1" mb="$2" iface="$3" tmpbase="${4:-${TMPDIR:-/tmp}}" f sp
    f=$(mktemp "$tmpbase/up.XXXXXX") || { echo 0; return; }
    dd if=/dev/zero of="$f" bs=1048576 count="$mb" >/dev/null 2>&1
    sp=$(_nettest_curl "$iface" -o /dev/null -w '%{speed_upload}' --max-time 25 --data-binary "@$f" "$url" 2>/dev/null)
    rm -f "$f"
    echo "${sp:-0}"
}

# 下行“单连接/多连接”对: <conns> <dur> <url> <iface> <tmpbase> -> "single_mbps multi_mbps"
_nettest_measure_downlink()
{
    local b1 bN
    b1=$(_nettest_measure_download 1 "$2" "$3" "$4" "$5")
    bN=$(_nettest_measure_download "$1" "$2" "$3" "$4" "$5")
    echo "$(_nettest_mbps "$b1" "$2") $(_nettest_mbps "$bN" "$2")"
}

# 逐跳路径
_nettest_trace()
{
    local host="$1"
    if command -v mtr >/dev/null 2>&1; then
        mtr -r -c 10 "$host" 2>/dev/null
    elif command -v traceroute >/dev/null 2>&1; then
        traceroute -m 20 -w 1 -q 1 "$host" 2>/dev/null
    else
        echo "(未安装 traceroute/mtr, 跳过)"
    fi
}

# =====================================================================
# 4) 报告渲染（只做格式化，不测量）
# =====================================================================
_nettest_print_header()
{
    echo "==================================================================="
    echo "网络体检  $1   网卡=${2:-自动}  并发=$3  时长=${4}s"
    echo "测速源: ${5:-!! 未找到可用测速源(镜像不可达/文件不存在), 下行将不可用}"
    [ "$6" = "1" ] && echo "代理:   $7  (直连/代理分别测)"
    echo "-------------------------------------------------------------------"
}
_nettest_print_latency_head() { echo "[1] 延迟/抖动/丢包 (ms, 代理无关)"; }
_nettest_print_latency_row()  { echo "    $(echo "$2" | awk -v l="$1" '{printf "%-15s: 丢包%s%% avg=%s max=%s mdev=%s",l,$1,$2,$3,$4}')"; }

_nettest_print_downlink()
{
    local conns="$1" direct="$2" proxy="$3" has_proxy="$4"
    echo "-------------------------------------------------------------------"
    echo "[2] 下行吞吐 (单连接 / ${conns}连接)"
    echo "    直连  : 单连接 $(echo "$direct"|awk '{print $1}') Mbps | ${conns}连接 $(echo "$direct"|awk '{print $2}') Mbps"
    if [ "$has_proxy" = "1" ]; then
        echo "    代理  : 单连接 $(echo "$proxy"|awk '{print $1}') Mbps | ${conns}连接 $(echo "$proxy"|awk '{print $2}') Mbps"
    else
        echo "    代理  : (未配置代理 / 已跳过)"
    fi
}

_nettest_print_uplink()
{
    echo "-------------------------------------------------------------------"
    echo "[3] 上行吞吐 (Cloudflare, 国际线路, 仅参考)"
    echo "    直连  : $(_nettest_mbps "$1" 1) Mbps"
    [ "$3" = "1" ] && echo "    代理  : $(_nettest_mbps "$2" 1) Mbps"
}

_nettest_print_dns()
{
    echo "-------------------------------------------------------------------"
    echo "[4] DNS 解析耗时"
    echo "    $1"
}

_nettest_print_trace()
{
    echo "-------------------------------------------------------------------"
    echo "[5] 路径逐跳 (定位延迟/丢包出现在哪一跳)"
    _nettest_trace "$1"
    echo "==================================================================="
}

_nettest_append_log()
{
    local log="$1" ts="$2" iface="$3" gws="$4" loss_all="$5" jit_all="$6"
    local d_direct="$7" d_proxy="$8" up_direct="$9" up_proxy="${10}"
    local lossmax jitmax
    lossmax=$(echo "$loss_all" | awk '{m=0;for(i=1;i<=NF;i++)if($i+0>m)m=$i+0;print m}')
    jitmax=$(echo "$jit_all"   | awk '{m=0;for(i=1;i<=NF;i++)if($i+0>m)m=$i+0;print m}')
    [ -f "$log" ] || echo "time,iface,loss_gw,loss_worst,jitter_worst,down1_direct,downN_direct,downN_proxy,up_direct,up_proxy" >> "$log"
    echo "$ts,${iface:-auto},$(echo "$gws"|awk '{print $1}'),$lossmax,$jitmax,$(echo "$d_direct"|awk '{print $1}'),$(echo "$d_direct"|awk '{print $2}'),$(echo "${d_proxy:-0 0}"|awk '{print $2}'),$(_nettest_mbps "$up_direct" 1),$(_nettest_mbps "${up_proxy:-0}" 1)" >> "$log"
    echo "已写入日志: $log"
}

# =====================================================================
# 5) 编排：一次完整体检（采集 → 聚合 → 渲染）
#    <conns> <dur> <iface> <loop> <log> <proxy_arg> <do_proxy> <repeat> <agg> <trace>
# =====================================================================
_nettest_run_once()
{
    (
        export LC_ALL=C   # 固定英文输出，保证 ping/loss 解析稳定

        local conns="$1" dur="$2" iface="$3" loop="$4" log="$5" proxy_arg="$6" do_proxy="$7" repeat="$8" agg="$9" trace="${10}"

        # ---------- 准备 ----------
        _nettest_check_deps || exit 1
        local tmpbase; tmpbase=$(mktemp -d)
        trap 'rm -rf "$tmpbase"' EXIT INT TERM

        local proxy_show http_p="" https_p="" all_p=""
        proxy_show=$(_nettest_detect_proxy "$proxy_arg")
        case "$proxy_show" in
            socks*) all_p="$proxy_show";;
            "") ;;
            *) http_p="$proxy_show"; https_p="$proxy_show";;
        esac
        local has_proxy=0; [ -n "$proxy_show" ] && has_proxy=1
        [ "$do_proxy" = "0" ] && has_proxy=0
        _nettest_proxy_off   # 先进入"直连环境"

        local iso gw ts
        iso=$(_nettest_pick_source "$iface")
        gw=$(_nettest_gateway)
        ts=$(date '+%Y-%m-%d %H:%M:%S')

        _nettest_print_header "$ts" "$iface" "$conns" "$dur" "$iso" "$has_proxy" "$proxy_show"

        # ---------- [1] 延迟（代理无关）----------
        _nettest_print_latency_head
        local gws loss_all=0 jit_all=0 s t
        gws=$(_nettest_ping_stats "${gw:-0.0.0.0}")
        _nettest_print_latency_row "网关 ${gw:-?}" "$gws"
        for t in $(_nettest_cfg_net_targets); do
            s=$(_nettest_ping_stats "$t")
            _nettest_print_latency_row "$t" "$s"
            loss_all=$(echo "$loss_all $s" | awk '{print ($1>$3?$1:$3)}')
            jit_all=$(echo "$jit_all $s"   | awk '{print ($1>$5?$1:$5)}')
        done
        if _nettest_has_ipv6; then
            for t in $(_nettest_cfg_net_targets6); do
                _nettest_print_latency_row "$t" "$(_nettest_ping6_stats "$t")"
            done
        else
            echo "    IPv6           : (本机无全局 IPv6 地址, 跳过)"
        fi

        # ---------- [2] 下行：直连 / 代理 ----------
        local d_direct="0 0" d_proxy="0 0"
        if [ -n "$iso" ]; then
            _nettest_collect "$repeat" "$tmpbase/dl_direct" _nettest_measure_downlink "$conns" "$dur" "$iso" "$iface" "$tmpbase"
            d_direct="$(_nettest_agg_col "$agg" 1 "$tmpbase/dl_direct") $(_nettest_agg_col "$agg" 2 "$tmpbase/dl_direct")"
            if [ "$has_proxy" = "1" ]; then
                _nettest_proxy_on "$http_p" "$https_p" "$all_p"
                _nettest_collect "$repeat" "$tmpbase/dl_proxy" _nettest_measure_downlink "$conns" "$dur" "$iso" "$iface" "$tmpbase"
                _nettest_proxy_off
                d_proxy="$(_nettest_agg_col "$agg" 1 "$tmpbase/dl_proxy") $(_nettest_agg_col "$agg" 2 "$tmpbase/dl_proxy")"
            fi
        fi
        _nettest_print_downlink "$conns" "$d_direct" "$d_proxy" "$has_proxy"

        # ---------- [3] 上行：直连 / 代理 ----------
        local up_direct up_proxy=0
        _nettest_collect "$repeat" "$tmpbase/up_direct" _nettest_measure_upload "$(_nettest_cfg_upload_url)" "$(_nettest_cfg_upload_mb)" "$iface" "$tmpbase"
        up_direct=$(_nettest_agg_col "$agg" 1 "$tmpbase/up_direct")
        if [ "$has_proxy" = "1" ]; then
            _nettest_proxy_on "$http_p" "$https_p" "$all_p"
            _nettest_collect "$repeat" "$tmpbase/up_proxy" _nettest_measure_upload "$(_nettest_cfg_upload_url)" "$(_nettest_cfg_upload_mb)" "$iface" "$tmpbase"
            _nettest_proxy_off
            up_proxy=$(_nettest_agg_col "$agg" 1 "$tmpbase/up_proxy")
        fi
        _nettest_print_uplink "$up_direct" "$up_proxy" "$has_proxy"

        # ---------- [4] DNS ----------
        _nettest_print_dns "$(_nettest_dns_time $(_nettest_cfg_dns_domains))"

        # ---------- [5] 路径逐跳（可选）----------
        if [ "$trace" = "1" ]; then
            _nettest_print_trace "$(_nettest_cfg_trace_host)"
        else
            echo "==================================================================="
        fi

        # ---------- 日志 ----------
        [ "$loop" -gt 0 ] && _nettest_append_log "$log" "$ts" "$iface" "$gws" "$loss_all" "$jit_all" \
            "$d_direct" "$d_proxy" "$up_direct" "$up_proxy"
    )
}

# =====================================================================
# 6) 入口：参数解析 + 校验 + 监控循环
# =====================================================================
function nettest()
{
    local conns=8 dur=8 iface="" loop=0 log="$HOME/nettest.log" proxy="" do_proxy=1 repeat=1 agg="best" trace=0

    local a
    for a in "$@"; do
        case "$a" in
            -h|--help)
                echo "用法: nettest [选项]"
                echo "  (无参数)          单次网络体检（下行/上行/延迟/抖动/丢包/DNS/IPv6）"
                echo "  --conns N         并发连接数 (默认 8)"
                echo "  --dur N           每项测量时长秒 (默认 8)"
                echo "  --repeat N        每项重复 N 次 (默认 1)"
                echo "  --agg MODE        重复时的聚合: best(默认) | median"
                echo "  --trace           追加路径逐跳(traceroute/mtr)定位拥塞"
                echo "  --iface DEV       指定网卡 (macOS: 有线=en5, WiFi=en0; 默认系统路由)"
                echo "  --proxy URL       指定代理 URL (默认: 环境变量 -> macOS 系统代理)"
                echo "  --no-proxy        跳过代理测试，只测直连"
                echo "  --loop N          每 N 秒测一次并追加日志 (排查时段性拥塞)"
                echo "  --log PATH        日志路径 (默认 ~/nettest.log)"
                echo "  -h, --help        显示本帮助"
                return 0
                ;;
        esac
    done

    while [ $# -gt 0 ]; do
        case "$1" in
            --conns) conns="$2"; shift 2;;
            --dur)   dur="$2";   shift 2;;
            --repeat) repeat="$2"; shift 2;;
            --agg)   agg="$2";   shift 2;;
            --trace) trace=1; shift;;
            --iface) iface="$2"; shift 2;;
            --proxy) proxy="$2"; shift 2;;
            --no-proxy) do_proxy=0; shift;;
            --loop)  loop="$2";  shift 2;;
            --log)   log="$2";   shift 2;;
            *) echo "未知参数: $1"; return 1;;
        esac
    done

    _nettest_is_posint "$conns"     || { echo "错误: --conns 必须是正整数 (当前: $conns)";    return 1; }
    _nettest_is_posint "$dur"       || { echo "错误: --dur 必须是正整数 (当前: $dur)";        return 1; }
    _nettest_is_posint "$repeat"    || { echo "错误: --repeat 必须是正整数 (当前: $repeat)";  return 1; }
    _nettest_is_nonnegint "$loop"   || { echo "错误: --loop 必须是非负整数 (当前: $loop)";    return 1; }
    case "$agg" in best|median) ;; *) echo "错误: --agg 只能是 best 或 median"; return 1;; esac

    if [ "$loop" -gt 0 ]; then
        echo "监控模式: 每 ${loop}s 一次, 日志 $log (Ctrl+C 退出)"
        while true; do
            _nettest_run_once "$conns" "$dur" "$iface" "$loop" "$log" "$proxy" "$do_proxy" "$repeat" "$agg" "$trace"
            sleep "$loop"
        done
    else
        _nettest_run_once "$conns" "$dur" "$iface" "$loop" "$log" "$proxy" "$do_proxy" "$repeat" "$agg" "$trace"
    fi
}

# =====================================================================
# 被 source 时仅注册函数；直接执行(./01.net_test.sh 或 m_net_test.sh)时跑一次体检
# =====================================================================
_nettest_is_sourced()
{
    if [ -n "${ZSH_VERSION:-}" ]; then
        case "${ZSH_EVAL_CONTEXT:-}" in *:file*) return 0;; *) return 1;; esac
    fi
    if [ -n "${BASH_VERSION:-}" ]; then
        [ "${BASH_SOURCE[0]:-}" != "$0" ] && return 0 || return 1
    fi
    return 1
}

if ! _nettest_is_sourced; then
    nettest "$@"
fi
