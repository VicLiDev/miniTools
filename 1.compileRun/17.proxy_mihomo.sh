#!/usr/bin/env bash
#########################################################################
# File Name: 17.proxy_mihomo.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Thu 18 Jun 2026 10:56:37 AM CST
#########################################################################
#
# =======================================================================
#  这个工具是什么
# =======================================================================
#  proxy_mihomo 不是代理内核,而是 mihomo (clash-meta) 的 CLI wrapper(壳),
#  由 init_tools.sh 软链为 ~/bin/m_proxy_mihomo(独立可执行,非 source)。
#  它通过三条通道管理 mihomo:
#
#    [A] RESTful API    curl 127.0.0.1:9090   运行时热改(不重启、不断连接)
#    [B] 配置文件       ~/.config/mihomo/     启动期配置(需重启)
#    [C] systemd        systemctl --user      进程生命周期
#
#  核心原则:能不重启就不重启 —— 运行时可改的走 API,改不了的才动文件+重启。
#
# =======================================================================
#  通道 A —— RESTful API (external-controller)
# =======================================================================
#    GET   /configs              读运行配置(mode / allow-lan / ports)
#    PATCH /configs              切模式 / 开关 LAN(热生效,连接不断)
#    PUT   /configs?force=true   热加载配置文件(config / update 切配置后)
#    GET   /proxies/<group>      列节点 ; /group/<g>/delay 测延迟
#    PUT   /proxies/<group>      切节点(立即生效)
#  - 鉴权:从 config.yaml 读 secret -> "Authorization: Bearer <secret>",api_call() 统一带上
#  - 防回环:main() 设 no_proxy=127.0.0.1,...,否则 global 模式下 API 请求会被
#          mihomo 自己代理回自己 -> HTTP 502
#  - 失败感知:api_call() 取 %{http_code};000 = API 不可达 -> 给"服务未运行"提示
#
# =======================================================================
#  通道 B —— 配置文件(API 改不了的才走这里)
# =======================================================================
#  监听端口(mixed-port / port / socks-port)在启动时绑定,API 改不了。
#  cmd_ports 流程:resolve_cfg_file() -> 校验 -> cp .bak.port -> sed 改 ->
#                  mihomo -t 预检(失败则回滚且不重启,避免 systemd crash loop)->
#                  systemctl restart -> poll is-active(失败再回滚)
#
#  config.yaml 是【符号链接】,指向当前激活的真实配置(XSUS.yaml / xxx.yaml):
#    - 切换配置 = ln -sfn <新>.yaml config.yaml + PUT /configs?force=true
#    - resolve_cfg_file() 跟着 symlink 找到真实文件
#  subscriptions.yaml:name <-> 订阅 URL 映射;subscribe 记录,update 重下载并(若激活)reload
#
# =======================================================================
#  通道 C —— systemd
# =======================================================================
#  ~/.config/systemd/user/mihomo.service:ExecStart = mihomo -d <cfg_dir>
#  start/stop/restart/status 走 systemctl --user;fg / bg / kill 是绕开 systemd
#  的备用进程管理。
#
# =======================================================================
#  三通道分工
# =======================================================================
#    API      运行时状态   零中断(node / mode / lan)
#    文件     启动期配置   需重启(ports)
#    systemd  进程本身     (start / stop)
#  比喻:mihomo = 引擎,config.yaml = 图纸(symlink 决定用哪张),
#        systemd = 点火开关,API = 行驶中的方向盘,本工具 = 统一的驾驶舱。
#
#########################################################################

# =============================================================================
#  shared helpers
# =============================================================================

# Resolve the real config file behind the <cfg_dir>/config.yaml symlink.
# args: <cfg_dir>   -> echoes the real path (or the symlink path if not a link)
function resolve_cfg_file()
{
    local f="${1}/config.yaml"
    [ -L "${f}" ] && f="$(readlink -f "${f}")"
    echo "${f}"
}

# Call the mihomo RESTful API. Sets the global API_HTTP_CODE.
# args: <api_url> <auth_header> <method> <path> [json_body]
function api_call()
{
    local api_url="${1}"
    local auth_header="${2}"
    local method="${3}"
    local path="${4}"
    local body="${5:-}"
    local args=(-s -o /dev/null -w "%{http_code}" -X "${method}")
    [ -n "${body}" ] && args+=(-H "Content-Type: application/json" -d "${body}")
    API_HTTP_CODE="$(curl "${args[@]}" ${auth_header} "${api_url}${path}" 2>/dev/null)"
}

# True if the last api_call returned a success status (200/204).
function api_ok()
{
    [ "${API_HTTP_CODE}" = "200" ] || [ "${API_HTTP_CODE}" = "204" ]
}

# =============================================================================
#  subcommand handlers (cmd_*)
# =============================================================================

function cmd_help()
{
    # args: <cfg_dir> <api_url> <secret>
    local cfg_dir="${1}"
    local api_url="${2}"
    local secret="${3}"
    echo "proxy_mihomo - RESTful API wrapper for mihomo (clash-meta)"
    echo ""
    echo "Usage:"
    echo "  proxy_mihomo subscribe <name> <url>          record subscription URL for a config"
    echo "  proxy_mihomo update [name]                   re-download config from recorded URL"
    echo "  proxy_mihomo mode                            select mode interactively"
    echo "  proxy_mihomo ports [mixed|split [..]]        show / set port mode (mixed 7890 | split 7890 7891)"
    echo "  proxy_mihomo config                          select config interactively"
    echo "  proxy_mihomo node [group]                    select node interactively (default: GLOBAL)"
    echo "  proxy_mihomo ping [group]                    test node latency (default: GLOBAL)"
    echo "  proxy_mihomo test [name]                     test current (or given) config file"
    echo "  proxy_mihomo lan [on|off]                    show / toggle lan access"
    echo "  proxy_mihomo start|stop|restart|status|log   service control & logs"
    echo "  proxy_mihomo fg|bg|kill|ps                   process: foreground/background/stop/check"
    echo ""
    echo "Config: ${cfg_dir}/config.yaml"
    echo "API:    ${api_url} (secret: ${secret:-none})"
}

function cmd_mode()
{
    # args: <api_url> <auth_header> [mode]
    local api_url="${1}"
    local auth_header="${2}"
    shift 2
    local mode="${1:-}"
    # no mode -> interactive select
    if [ -z "${mode}" ]; then
        local cur_mode
        cur_mode=$(curl -s ${auth_header} "${api_url}/configs" 2>/dev/null \
                   | python3 -c "import sys,json; print(json.load(sys.stdin).get('mode','unknown'))" 2>/dev/null)
        local modes=("rule" "global" "direct")
        echo "current mode: ${cur_mode}"
        local idx
        for idx in "${!modes[@]}"; do
            local lead=" "
            [ "${modes[$idx]}" = "${cur_mode}" ] && lead="*"
            printf "%s %d) %s\n" "${lead}" "$((idx+1))" "${modes[$idx]}"
        done
        local sel=""
        printf "Select mode [1-%d] (Enter to keep current, q to quit): " "${#modes[@]}"
        { read -r sel < /dev/tty; } 2>/dev/null
        echo
        [ -z "${sel}" ] || [ "${sel}" = "q" ] && return 0
        if [[ "${sel}" =~ ^[1-3]$ ]]; then
            mode="${modes[$((sel-1))]}"
        else
            echo "error: invalid selection '${sel}'" >&2
            return 1
        fi
    fi
    # validate + switch
    case "${mode}" in
        rule|global|direct) ;;
        *)
            echo "error: invalid mode '${mode}', use rule|global|direct" >&2
            return 1
            ;;
    esac
    api_call "${api_url}" "${auth_header}" PATCH /configs "{\"mode\":\"${mode}\"}"
    if [ "${API_HTTP_CODE}" = "000" ]; then
        echo "error: mihomo API unreachable; is the service running? ('proxy_mihomo status')" >&2
        return 1
    elif api_ok; then
        echo "mode switched to: ${mode}"
    else
        echo "error: failed to switch mode (HTTP ${API_HTTP_CODE})" >&2
        return 1
    fi
}

function cmd_config()
{
    # args: <cfg_dir> <api_url> <auth_header> <mihomo_bin> [path]
    local cfg_dir="${1}"
    local api_url="${2}"
    local auth_header="${3}"
    local mihomo_bin="${4}"
    shift 4
    local cfg_path="${1:-}"
    local cur_link="${cfg_dir}/config.yaml"
    # current = the file config.yaml points to (symlink target) or config.yaml itself
    local cur_target
    cur_target="$(basename "$(resolve_cfg_file "${cfg_dir}")")"
    # no path -> interactive select (real files only, exclude the config.yaml symlink)
    if [ -z "${cfg_path}" ]; then
        local files=()
        local f
        while IFS= read -r f; do
            [ -n "${f}" ] && files+=("${f}")
        done < <(find "${cfg_dir}" -maxdepth 1 -type f \
                 \( -name '*.yaml' -o -name '*.yml' \) ! -name subscriptions.yaml \
                 2>/dev/null | sort)
        if [ "${#files[@]}" -eq 0 ]; then
            echo "no .yaml/.yml config files found in ${cfg_dir}" >&2
            return 1
        fi
        echo "# config dir: ${cfg_dir}"
        local idx
        for idx in "${!files[@]}"; do
            local lead=" "
            [ "$(basename "${files[$idx]}")" = "${cur_target}" ] && lead="*"
            printf "%s %d) %s\n" "${lead}" "$((idx+1))" "$(basename "${files[$idx]}")"
        done
        local sel=""
        printf "Select config [1-%d] (Enter to keep current, q to quit): " "${#files[@]}"
        { read -r sel < /dev/tty; } 2>/dev/null
        echo
        [ -z "${sel}" ] || [ "${sel}" = "q" ] && return 0
        if [[ "${sel}" =~ ^[0-9]+$ ]] && [ "${sel}" -ge 1 ] 2>/dev/null \
           && [ "${sel}" -le "${#files[@]}" ] 2>/dev/null; then
            cfg_path="${files[$((sel-1))]}"
        else
            echo "error: invalid selection '${sel}'" >&2
            return 1
        fi
    fi
    # validate
    if [ ! -f "${cfg_path}" ]; then
        echo "error: config not found: ${cfg_path}" >&2
        return 1
    fi
    local target_name
    target_name="$(basename "${cfg_path}")"
    # pre-check the target config BEFORE repointing the symlink, so a broken
    # config is rejected without leaving the symlink pointing at it (which
    # would crash mihomo on the next restart).
    if ! ${mihomo_bin} -t -d "${cfg_dir}" -f "${cfg_dir}/${target_name}" >/dev/null 2>&1; then
        echo "error: target config failed mihomo -t; not switching (symlink untouched)" >&2
        ${mihomo_bin} -t -d "${cfg_dir}" -f "${cfg_dir}/${target_name}" 2>&1 | tail -3 | sed 's/^/  /' >&2
        return 1
    fi
    # switch: repoint config.yaml symlink to the selected file, then reload
    ln -sfn "${target_name}" "${cur_link}"
    api_call "${api_url}" "${auth_header}" PUT "/configs?force=true" "{\"path\":\"${cur_link}\"}"
    if [ "${API_HTTP_CODE}" = "000" ]; then
        echo "error: mihomo API unreachable; is the service running? ('proxy_mihomo status')" >&2
        return 1
    elif api_ok; then
        echo "config switched to: ${target_name}"
    else
        echo "error: failed to switch config (HTTP ${API_HTTP_CODE})" >&2
        return 1
    fi
}

function cmd_node()
{
    # args: <cfg_dir> <api_url> <secret> [group] [name]
    local cfg_dir="${1}"
    local api_url="${2}"
    local secret="${3}"
    shift 3
    local group="${1:-GLOBAL}"
    local name="${2:-}"
    proxyApiUrl="${api_url}" proxySecret="${secret}" proxyCfgDir="${cfg_dir}" \
        python3 - "$group" "$name" <<'PY'
import sys, os, json, urllib.request, urllib.parse, urllib.error, unicodedata
api = os.environ["proxyApiUrl"].rstrip("/")
secret = os.environ.get("proxySecret", "")
group, name = sys.argv[1], sys.argv[2]
headers = {"Authorization": "Bearer " + secret} if secret else {}
enc = urllib.parse.quote(group, safe="")

def req(method, path, data=None):
    r = urllib.request.Request(api + path, data=data, headers=headers, method=method)
    if data is not None:
        r.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(r, timeout=40) as resp:
        return resp.status, resp.read().decode()

def disp_w(s):
    w = 0
    for ch in s:
        if unicodedata.category(ch).startswith("C") or unicodedata.combining(ch):
            continue
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w

def pad(s, w):
    return s + " " * (w - disp_w(s))

def switch_to(target):
    data = json.dumps({"name": target}).encode()
    try:
        req("PUT", "/proxies/" + enc, data)
    except urllib.error.HTTPError as e:
        sys.stderr.write("error: failed to switch node (HTTP %s)\n" % e.code)
        sys.exit(1)
    print("node switched to: %s (group: %s)" % (target, group))

try:
    _, body = req("GET", "/proxies/" + enc)
except urllib.error.HTTPError as e:
    sys.stderr.write("error: group '%s' not found (HTTP %s)\n" % (group, e.code))
    sys.exit(1)
d = json.loads(body)
members = d.get("all", [])
now = d.get("now", "")
if not members:
    print("group '%s' has no members" % group)
    sys.exit(0)
w = max(disp_w(n) for n in members)

if name:
    # non-interactive: numeric index (in range) or node name
    if name.isdigit() and 1 <= int(name) <= len(members):
        target = members[int(name) - 1]
    else:
        target = name
    switch_to(target)
else:
    # list with index, mark current, then interactive select
    delays = {}
    try:
        q = urllib.parse.urlencode({"timeout": "5000",
                                    "url": "http://www.gstatic.com/generate_204"})
        _, dbody = req("GET", "/group/%s/delay?%s" % (enc, q))
        delays = json.loads(dbody)
    except Exception:
        delays = {}

    def delay_of(n):
        d = delays.get(n)
        if isinstance(d, int) and d > 0:
            return "%5d ms" % d
        return "   FAIL"

    cfg_link = os.path.join(os.environ.get("proxyCfgDir", ""), "config.yaml")
    if os.path.exists(cfg_link):
        print("# config: %s" % os.path.basename(os.path.realpath(cfg_link)))
    print("# group: %s  (members: %d)" % (group, len(members)))
    if now:
        print("# current: %s  (* = current)" % now)
    print("-" * 60)
    for i, n in enumerate(members, 1):
        lead = "*" if n == now else " "
        print("%s %2d) %s  %s" % (lead, i, pad(n, w), delay_of(n)))
    sys.stdout.write("\nSelect node [1-%d] (Enter to keep current, q to quit): "
                     % len(members))
    sys.stdout.flush()
    sel = ""
    try:
        # read from controlling terminal (stdin is the heredoc script source)
        with open("/dev/tty") as tty:
            sel = tty.readline().strip()
    except OSError:
        # no controlling terminal (non-interactive) -> skip switching
        sys.exit(0)
    if sel == "" or sel.lower() == "q":
        sys.exit(0)
    if sel.isdigit() and 1 <= int(sel) <= len(members):
        switch_to(members[int(sel) - 1])
    else:
        sys.stderr.write("error: invalid selection '%s'\n" % sel)
        sys.exit(1)
PY
}

function cmd_ping()
{
    # args: <api_url> <secret> [group]
    local api_url="${1}"
    local secret="${2}"
    shift 2
    local group="${1:-GLOBAL}"
    local test_url="http://www.gstatic.com/generate_204"
    local timeout_ms="5000"
    proxyApiUrl="${api_url}" proxySecret="${secret}" \
        python3 - "$group" "$test_url" "$timeout_ms" <<'PY'
import sys, os, json, urllib.request, urllib.parse, urllib.error, unicodedata

def disp_w(s):
    """display width: wide/fullwidth chars count 2, zero-width chars count 0."""
    w = 0
    for ch in s:
        if unicodedata.category(ch).startswith("C") or unicodedata.combining(ch):
            continue
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w

def pad(s, w):
    return s + " " * (w - disp_w(s))

api = os.environ["proxyApiUrl"].rstrip("/")
secret = os.environ.get("proxySecret", "")
group, test_url, timeout_ms = sys.argv[1], sys.argv[2], sys.argv[3]
headers = {"Authorization": "Bearer " + secret} if secret else {}
def get(path):
    req = urllib.request.Request(api + path, headers=headers)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode())
enc = urllib.parse.quote(group, safe="")
try:
    g = get("/proxies/" + enc)
except urllib.error.HTTPError as e:
    sys.stderr.write("error: group '%s' not found (HTTP %s)\n" % (group, e.code))
    sys.exit(1)
members = g.get("all", [])
now = g.get("now", "")
if not members:
    print("group '%s' has no members" % group)
    sys.exit(0)
q = urllib.parse.urlencode({"timeout": timeout_ms, "url": test_url})
try:
    delays = get("/group/%s/delay?%s" % (enc, q))
except Exception as e:
    sys.stderr.write("error: delay test failed: %s\n" % e)
    sys.exit(1)
ok = sorted([(n, d) for n, d in delays.items() if isinstance(d, int) and d > 0],
            key=lambda x: x[1])
ok_names = set(n for n, _ in ok)
fail = [n for n in members if n not in ok_names]
print("# group: %s  (members: %d, ok: %d, fail: %d)"
      % (group, len(members), len(ok), len(fail)))
print("# test url: %s  timeout: %sms" % (test_url, timeout_ms))
if now:
    print("# current: %s  (* = current)" % now)
print("-" * 60)
w = max(disp_w(n) for n in members)
for n, d in ok:
    mark = "*" if n == now else " "
    print("  %s %s  %5d ms" % (mark, pad(n, w), d))
if fail:
    print("-" * 60)
    for n in fail:
        mark = "*" if n == now else " "
        print("  %s %s  %5s" % (mark, pad(n, w), "FAIL"))
PY
}

function cmd_lan()
{
    # args: <api_url> <auth_header> [on|off]
    local api_url="${1}"
    local auth_header="${2}"
    shift 2
    if [ -z "${1}" ]; then
        # show lan status and proxy ports
        curl -s ${auth_header} "${api_url}/configs" 2>/dev/null | python3 -c "
import sys, json
c = json.load(sys.stdin)
print('allow-lan: {}'.format(c.get('allow-lan', False)))
for k in ('mixed-port', 'port', 'socks-port', 'redir-port', 'tproxy-port'):
    if k in c:
        print('  {}: {}'.format(k, c[k]))
" 2>/dev/null
    else
        local lan_val="${1}"
        case "${lan_val}" in
            on|true|1)  lan_val="true" ;;
            off|false|0) lan_val="false" ;;
            *)
                echo "error: use 'on/off' or 'true/false'" >&2
                return 1
                ;;
        esac
        api_call "${api_url}" "${auth_header}" PATCH /configs "{\"allow-lan\":${lan_val}}"
        if [ "${API_HTTP_CODE}" = "000" ]; then
            echo "error: mihomo API unreachable; is the service running? ('proxy_mihomo status')" >&2
            return 1
        elif api_ok; then
            echo "allow-lan: ${lan_val}"
        else
            echo "error: failed to set allow-lan (HTTP ${API_HTTP_CODE})" >&2
            return 1
        fi
    fi
}

function cmd_ports()
{
    # args: <cfg_dir> <api_url> <auth_header> <mihomo_bin> [mixed [port] | split [http] [socks]]
    #   (no action)         show current ports + meaning + LAN IPs + client hints
    #   mixed [port]        switch to mixed-port (default 7890), restart
    #   split [http] [socks] switch to separate port + socks-port (default 7890/7891), restart
    local cfg_dir="${1}"
    local api_url="${2}"
    local auth_header="${3}"
    local mihomo_bin="${4}"
    shift 4
    local action="${1:-}"

    # ---------- show ----------
    if [ -z "${action}" ]; then
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" ${auth_header} "${api_url}/configs" 2>/dev/null)
        if [ "${code}" != "200" ]; then
            echo "error: mihomo API unreachable (HTTP ${code:-000}); is the service running?" >&2
            echo "  try: proxy_mihomo status" >&2
            return 1
        fi
        curl -s ${auth_header} "${api_url}/configs" 2>/dev/null | python3 -c "
import sys, json
c = json.load(sys.stdin)
print('allow-lan:  {}'.format(c.get('allow-lan', False)))
mp = c.get('mixed-port', 0) or 0
p  = c.get('port', 0) or 0
sp = c.get('socks-port', 0) or 0
print('mixed-port: {}'.format(mp))
print('port:       {}  (http proxy)'.format(p))
print('socks-port: {}  (socks5 proxy)'.format(sp))
print('')
print('# port types:')
print('#   port         HTTP proxy  - only HTTP/HTTPS traffic')
print('#   socks-port   SOCKS5      - any TCP traffic (more universal)')
print('#   mixed-port   HTTP+SOCKS5 on ONE port (recommended)')
print('')
active = mp or p or sp
socks  = mp or sp
print('# clients -> host=<LAN-IP>  port={}'.format(active))
print('# this shell:')
print('#   export https_proxy=http://127.0.0.1:{0} http_proxy=http://127.0.0.1:{0}'.format(active))
if socks:
    print('#   export all_proxy=socks5h://127.0.0.1:{}'.format(socks))
" 2>/dev/null
        echo "# this machine LAN IPs (typical LAN segments; pick one your device can reach):"
        ip -4 addr show 2>/dev/null | awk '/inet / {
            split($2, a, "/"); ip = a[1]
            # keep 10/8 + 192.168/16 only; drop loopback, link-local, public,
            # and docker bridges (172.16-31). use `ip addr` if you need the rest.
            if (ip ~ /^10\./ || ip ~ /^192\.168\./) print "  " ip
        }'
        return
    fi

    # ---------- set: edit config.yaml (follow symlink) + validate + restart ----------
    local cfg_file
    cfg_file="$(resolve_cfg_file "${cfg_dir}")"
    if [ ! -f "${cfg_file}" ]; then
        echo "error: config not found: ${cfg_file}" >&2
        return 1
    fi
    # validate action + port args BEFORE touching the file
    local mp="" hp="" sp=""
    case "${action}" in
        mixed)
            mp="${2:-7890}"
            if ! [[ "${mp}" =~ ^[0-9]+$ ]] || [ "${mp}" -lt 1 ] || [ "${mp}" -gt 65535 ]; then
                echo "error: invalid port '${mp}' (must be 1-65535)" >&2
                return 1
            fi
            ;;
        split)
            hp="${2:-7890}"
            sp="${3:-7891}"
            if ! [[ "${hp}" =~ ^[0-9]+$ ]] || [ "${hp}" -lt 1 ] || [ "${hp}" -gt 65535 ] \
               || ! [[ "${sp}" =~ ^[0-9]+$ ]] || [ "${sp}" -lt 1 ] || [ "${sp}" -gt 65535 ]; then
                echo "error: invalid port '${hp}/${sp}' (each must be 1-65535)" >&2
                return 1
            fi
            if [ "${hp}" = "${sp}" ]; then
                echo "error: http port and socks port must differ" >&2
                return 1
            fi
            ;;
        *)
            echo "usage: proxy_mihomo ports [mixed [port] | split [http] [socks]]" >&2
            echo "  (no arg)       show current ports" >&2
            echo "  mixed [port]   one port for HTTP+SOCKS5 (default 7890)" >&2
            echo "  split [h] [s]  separate port (http) + socks-port (default 7890 7891)" >&2
            return 1
            ;;
    esac
    cp "${cfg_file}" "${cfg_file}.bak.port"
    # drop existing mixed-port / port / socks-port lines (keep redir/tproxy)
    sed -i '/^\(mixed-port\|port\|socks-port\):/d' "${cfg_file}"
    case "${action}" in
        mixed)
            sed -i "1i mixed-port: ${mp}" "${cfg_file}"
            echo "set: mixed-port ${mp}"
            ;;
        split)
            sed -i "1i socks-port: ${sp}" "${cfg_file}"
            sed -i "1i port: ${hp}" "${cfg_file}"
            echo "set: port ${hp}, socks-port ${sp}"
            ;;
    esac
    echo "(backup: ${cfg_file}.bak.port)"
    # validate the edited config BEFORE touching the service: a failed mihomo -t
    # means mihomo will exit with status 1 on start (it is not "overly strict" --
    # it matches runtime behavior). On failure we roll back and do NOT restart,
    # so systemd is not left in an auto-restart crash loop.
    if ! ${mihomo_bin} -t -d "${cfg_dir}" -f "${cfg_file}" >/dev/null 2>&1; then
        echo "error: mihomo -t rejected the edited config; rolling back" >&2
        ${mihomo_bin} -t -d "${cfg_dir}" -f "${cfg_file}" 2>&1 | tail -3 | sed 's/^/  /' >&2
        cp "${cfg_file}.bak.port" "${cfg_file}"
        echo "rolled back to ${cfg_file}.bak.port (service left untouched)" >&2
        return 1
    fi
    systemctl --user restart mihomo.service
    # post-restart health check; if the service does not become active within ~5s
    # (rare, since -t passed), roll back to the backup and restart on it.
    local i active=""
    for ((i = 0; i < 10; i++)); do
        sleep 0.5
        active="$(systemctl --user is-active mihomo.service 2>/dev/null)"
        [ "${active}" = "active" ] && break
    done
    if [ "${active}" != "active" ]; then
        echo "error: mihomo failed to start (${active:-unknown}); rolling back" >&2
        journalctl --user -u mihomo.service -n 4 --no-pager 2>&1 | sed 's/^/  /' >&2
        cp "${cfg_file}.bak.port" "${cfg_file}"
        systemctl --user restart mihomo.service
        echo "rolled back to ${cfg_file}.bak.port" >&2
        return 1
    fi
    echo "mihomo restarted (active); run 'proxy_mihomo ports' to confirm ports"
}

function cmd_fg()
{
    # args: <cfg_dir> <mihomo_bin>
    local cfg_dir="${1}"
    local mihomo_bin="${2}"
    if [ ! -f "${mihomo_bin}" ]; then
        echo "error: mihomo not found: ${mihomo_bin}" >&2
        return 1
    fi
    echo "starting mihomo in foreground (Ctrl+C to stop)..."
    echo "  config: ${cfg_dir}/config.yaml"
    exec ${mihomo_bin} -d "${cfg_dir}"
}

function cmd_bg()
{
    # args: <cfg_dir> <mihomo_bin>
    local cfg_dir="${1}"
    local mihomo_bin="${2}"
    if [ ! -f "${mihomo_bin}" ]; then
        echo "error: mihomo not found: ${mihomo_bin}" >&2
        return 1
    fi
    if pgrep -f "mihomo.*-d ${cfg_dir}" &>/dev/null; then
        echo "error: mihomo is already running" >&2
        return 1
    fi
    nohup ${mihomo_bin} -d "${cfg_dir}" &>/dev/null &
    echo "mihomo started in background (pid: $!)"
}

function cmd_kill()
{
    # args: <cfg_dir>
    local cfg_dir="${1}"
    local pids
    pids=$(pgrep -f "mihomo.*-d ${cfg_dir}" 2>/dev/null)
    if [ -z "${pids}" ]; then
        echo "mihomo is not running" >&2
        return 1
    fi
    kill ${pids}
    echo "mihomo stopped (pid: ${pids})"
}

function cmd_ps()
{
    local pids
    pids=$(pgrep -af "mihomo" 2>/dev/null)
    if [ -z "${pids}" ]; then
        echo "mihomo is not running"
    else
        echo "${pids}"
    fi
}

function cmd_subscribe()
{
    # args: <cfg_dir> <config_name> <url>
    # record subscription URL <-> config file mapping in subscriptions.yaml
    local cfg_dir="${1}"
    local name="${2}"
    local url="${3}"
    if [ -z "${name}" ] || [ -z "${url}" ]; then
        echo "usage: proxy_mihomo subscribe <config_name> <url>" >&2
        return 1
    fi
    local map="${cfg_dir}/subscriptions.yaml"
    if [ ! -f "${map}" ]; then
        echo "# subscription mapping: <config-name>: <url>" > "${map}"
        echo "# recorded by 'proxy_mihomo subscribe <name> <url>'" >> "${map}"
    fi
    local tmp="${map}.tmp"
    grep -v "^${name}:" "${map}" 2>/dev/null > "${tmp}" || true
    echo "${name}: ${url}" >> "${tmp}"
    mv "${tmp}" "${map}"
    echo "subscribed: ${name} -> ${url}"
    echo "(recorded in ${map})"
}

function cmd_update()
{
    # args: <cfg_dir> <api_url> <auth_header> [config_name]
    # re-download a config from its recorded subscription URL, then reload
    local cfg_dir="${1}"
    local api_url="${2}"
    local auth_header="${3}"
    shift 3
    local name="${1:-}"
    local map="${cfg_dir}/subscriptions.yaml"
    local cur_link="${cfg_dir}/config.yaml"

    # resolve target config name (default: the current active config)
    if [ -z "${name}" ]; then
        name="$(basename "$(resolve_cfg_file "${cfg_dir}")")"
    fi

    if [ ! -f "${map}" ]; then
        echo "error: no ${map}; record one first:" >&2
        echo "  proxy_mihomo subscribe <name> <url>" >&2
        return 1
    fi
    local url
    url="$(grep "^${name}:" "${map}" | sed 's/^[^:]*:[[:space:]]*//' | head -1)"
    if [ -z "${url}" ]; then
        echo "error: no subscription URL for '${name}' in ${map}" >&2
        echo "  proxy_mihomo subscribe ${name} <url>" >&2
        return 1
    fi

    local target="${cfg_dir}/${name}"
    local tmp="${target}.dl"
    echo "downloading ${name} from subscription..."
    if ! curl -fsSL "${url}" -o "${tmp}" 2>/dev/null; then
        echo "error: download failed (${url})" >&2
        rm -f "${tmp}"
        return 1
    fi
    [ -f "${target}" ] && cp "${target}" "${target}.bak"
    mv "${tmp}" "${target}"
    echo "updated: ${target}"
    [ -f "${target}.bak" ] && echo "(backup: ${target}.bak)"

    # reload mihomo if the updated config is the active one
    local active=""
    active="$(basename "$(resolve_cfg_file "${cfg_dir}")")"
    if [ "${active}" = "${name}" ] || [ "${name}" = "config.yaml" ]; then
        api_call "${api_url}" "${auth_header}" PUT "/configs?force=true" "{\"path\":\"${cur_link}\"}"
        if [ "${API_HTTP_CODE}" = "000" ]; then
            echo "warning: mihomo API unreachable; reload skipped ('proxy_mihomo restart')" >&2
        elif api_ok; then
            echo "config reloaded"
        else
            echo "warning: reload failed (HTTP ${API_HTTP_CODE}); try 'proxy_mihomo restart'" >&2
        fi
    fi
}

# =============================================================================
#  command-line dispatch
# =============================================================================

function dispatch()
{
    # args: <cfg_dir> <api_url> <mihomo_bin> <secret> <auth_header> <cmd> [params...]
    local cfg_dir="${1}"
    local api_url="${2}"
    local mihomo_bin="${3}"
    local secret="${4}"
    local auth_header="${5}"
    shift 5

    local cmd="${1}"
    shift 2>/dev/null

    case "${cmd}" in
        mode)
            cmd_mode "${api_url}" "${auth_header}" "$@"
            ;;
        config)
            cmd_config "${cfg_dir}" "${api_url}" "${auth_header}" "${mihomo_bin}" "$@"
            ;;
        subscribe)
            cmd_subscribe "${cfg_dir}" "$@"
            ;;
        update)
            cmd_update "${cfg_dir}" "${api_url}" "${auth_header}" "$@"
            ;;
        node)
            cmd_node "${cfg_dir}" "${api_url}" "${secret}" "$@"
            ;;
        ping)
            cmd_ping "${api_url}" "${secret}" "$@"
            ;;
        lan)
            cmd_lan "${api_url}" "${auth_header}" "$@"
            ;;
        ports)
            cmd_ports "${cfg_dir}" "${api_url}" "${auth_header}" "${mihomo_bin}" "$@"
            ;;
        test)
            if [ ! -f "${mihomo_bin}" ]; then
                echo "error: mihomo not found: ${mihomo_bin}" >&2
                return 1
            fi
            local cfg_file
            cfg_file="$(resolve_cfg_file "${cfg_dir}")"
            [ -n "${1:-}" ] && cfg_file="${cfg_dir}/${1}"
            if [ ! -f "${cfg_file}" ]; then
                echo "error: config not found: ${cfg_file}" >&2
                return 1
            fi
            echo "testing: ${cfg_file}"
            ${mihomo_bin} -t -d "${cfg_dir}" -f "${cfg_file}"
            ;;
        start|stop|restart|status)
            systemctl --user "${cmd}" mihomo.service "$@"
            ;;
        fg)
            cmd_fg "${cfg_dir}" "${mihomo_bin}"
            ;;
        bg)
            cmd_bg "${cfg_dir}" "${mihomo_bin}"
            ;;
        kill)
            cmd_kill "${cfg_dir}"
            ;;
        ps)
            cmd_ps
            ;;
        log)
            journalctl --user -u mihomo.service -f 2>/dev/null \
                || journalctl --user -u clash.service -f 2>/dev/null \
                || echo "error: no mihomo/clash user service found in journal" >&2
            ;;
        ""|-h|--help|help)
            cmd_help "${cfg_dir}" "${api_url}" "${secret}"
            ;;
        *)
            echo "error: unknown command '${cmd}'" >&2
            echo "run 'proxy_mihomo help' for usage" >&2
            return 1
            ;;
    esac
}

# =============================================================================
#  entry point
# =============================================================================

function main()
{
    local api_addr="${proxyMihomoAddr:-127.0.0.1:9090}"
    local api_url="http://${api_addr}"
    # API is local -> never route it through the proxy. Otherwise switching to
    # global mode loops the API call back through mihomo itself (HTTP 502).
    local api_host="${api_addr%%:*}"
    export no_proxy="${api_host},127.0.0.1,localhost"
    export NO_PROXY="${no_proxy}"
    local cfg_dir="${proxyMihomoCfgDir:-${HOME}/.config/mihomo}"
    local mihomo_bin="${proxyMihomoBin:-${HOME}/.local/bin/mihomo}"

    # read secret from config.yaml if exists
    local secret=""
    if [ -f "${cfg_dir}/config.yaml" ]; then
        secret=$(grep -E '^\s*secret:' "${cfg_dir}/config.yaml" 2>/dev/null \
                 | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
        # skip empty secret (placeholder comment like "secret: #xxx")
        [ -z "${secret// }" ] && secret=""
    fi
    local auth_header=""
    [ -n "${secret}" ] && auth_header="-H Authorization:\ Bearer\ ${secret}"

    dispatch "${cfg_dir}" "${api_url}" "${mihomo_bin}" "${secret}" "${auth_header}" "$@"
}

main "$@"
