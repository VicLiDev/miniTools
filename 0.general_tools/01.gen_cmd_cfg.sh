#!/usr/bin/env bash
#########################################################################
# File Name: 01.gen_cmd_cfg.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 14 Dec 2025 10:18:23 AM CST
#########################################################################

# source ${HOME}/Projects/miniTools/1.compileRun/0.gen_cmd_cfg.sh

# =============================================================================
# ============================ def config =====================================
# =============================================================================
# --------------------------------------
# ------> User local environment <------
# --------------------------------------
# 可执行文件
[ -d "${HOME}/bin" ] && export PATH="${HOME}/bin:${PATH}"
[ -d "${HOME}/local/bin" ] && export PATH="${HOME}/local/bin:${PATH}"
[ -d "${HOME}/.local/bin" ] && export PATH="${HOME}/.local/bin:${PATH}"
# ------------------------------------
# ------> libraries (optional) <------
# ------------------------------------
[ -d "${HOME}/local/lib" ] && export LD_LIBRARY_PATH="${HOME}/local/lib:${LD_LIBRARY_PATH}"
[ -d "${HOME}/local/lib64" ] && export LD_LIBRARY_PATH="${HOME}/local/lib64:${LD_LIBRARY_PATH}"
# -----------------------------
# ------> compile tools <------
# -----------------------------
[ -d "${HOME}/local/lib/pkgconfig" ] && export PKG_CONFIG_PATH="${HOME}/local/lib/pkgconfig:${PKG_CONFIG_PATH}"
[ -d "${HOME}/local/lib64/pkgconfig" ] && export PKG_CONFIG_PATH="${HOME}/local/lib64/pkgconfig:${PKG_CONFIG_PATH}"
[ -d "${HOME}/local/include" ] && export CPATH="${HOME}/local/include:${CPATH}"
# ------------------------------------
# ------> cmake / build system <------
# ------------------------------------
[ -d "${HOME}/local" ] && export CMAKE_PREFIX_PATH="${HOME}/local:${CMAKE_PREFIX_PATH}"
# --------------------------------------------------
# ------> manual opt usage (do NOT auto-add) <------
# --------------------------------------------------
# example:
# export PATH="$HOME/opt/node/bin:$PATH"
# ------------------------------
# ------> default editor <------
# ------------------------------
export EDITOR=vim
# ---------------------
# ------> proxy <------
# ---------------------
# set proxyIP and proxyPort
# 配置文件可以从其他系统的clash里copy
# nohup clash-linux-386-v1.16.0 -f ~/.config/clash/agentNeo.yaml &
if [[ -n "${proxyIP}" && -n "${proxyPort}" ]]
then
    export http_proxy=http://${proxyIP}:${proxyPort}
    export https_proxy=http://${proxyIP}:${proxyPort}
    export all_proxy=socks5://${proxyIP}:${proxyPort}
fi

# -------------------------
# ------> sys tools <------
# -------------------------
# -a（all）显示 所有文件，包括隐藏文件
# -l（long）长格式显示
# -h（human-readable） 人类可读的大小
# -F（文件类型标记）
#   效果示例：bin/      script*     link@     pipe|
#   含义：
#   符号 意义
#   /    目录
#   *    可执行文件
#   @    符号链接
#   =    socket
# -A（Almost all） 显示隐藏文件，但不显示 . 和 .. ，比 -a 更“干净”
# -C 按列输出（默认行为）
# --color=auto 根据文件类型显示颜色，Linux 专属
# -G（macOS / BSD）启用彩色输出（等价于 Linux 的 --color）
if [ "$(uname -s)" = "Linux" ]
then
    # echo "Linux"
    alias ls='ls --color=auto'
    alias ll='ls -alh'
    alias la='ls -A'
elif [ "$(uname -s)" = "Darwin" ]
then
    # echo "macOS"
    alias ls='ls -G'
    alias ll='ls -alh'
    alias la='ls -A'
    alias l='ls -CF'
else
    echo "unknow system"
fi
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv}'
# --------------------------
# ------> priv tools <------
# --------------------------
# fzf
if [ -n "$BASH_VERSION" ]; then
    # echo "bash"
    [ -f ~/.fzf.bash ] && source ~/.fzf.bash
elif [ -n "$ZSH_VERSION" ]; then
    # echo "zsh"
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
else
    echo "unknow shell"
fi
# opencode
export PATH=${HOME}/.opencode/bin:${PATH}
# ======> conda
conda_root=""
[ -e "${HOME}/miniforge3" ] && conda_root="${HOME}/miniforge3"
[ -e "${HOME}/anaconda3" ] && conda_root="${HOME}/anaconda3"
if [ -n "${conda_root}" ]; then
    __conda_setup=""
    if [ -n "$BASH_VERSION" ]; then
        __conda_setup="$("${conda_root}/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
    elif [ -n "$ZSH_VERSION" ]; then
        __conda_setup="$("${conda_root}/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
    fi
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "${conda_root}/etc/profile.d/conda.sh" ]; then
            . "${conda_root}/etc/profile.d/conda.sh"
        else
            export PATH="${conda_root}/bin:${PATH}"
        fi
    fi
    unset __conda_setup

    if [ -e "${conda_root}/bin/mamba" ]; then
        export MAMBA_EXE='/home/lhj/miniforge3/bin/mamba';
        export MAMBA_ROOT_PREFIX='/home/lhj/miniforge3';
        __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__mamba_setup"
        else
            alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
        fi
        unset __mamba_setup
    fi
fi
# esp32 env init
[ -e "${HOME}/esp/esp-idf/export.sh" ] && { alias esp_get_idf=". ~/esp/esp-idf/export.sh"; }

# =============================================================================
# =============================== tools =======================================
# =============================================================================

function ranger()
{
    # 没装 ranger 就别建临时文件、别执行 command ranger（否则会抛 command not found）
    if ! command -v ranger &> /dev/null; then
        echo "ranger 未安装，请先安装：apt-get install ranger / brew install ranger" >&2
        return 1
    fi

    # IFS 设成只有 tab 和换行，避免后面 cat 出来的路径被空格/特殊字符切错
    local IFS=$'\t\n'

    # 建一个临时文件，用来在 ranger 内部和外部 shell 之间「传递当前目录路径」
    # （ranger 是子进程，没法直接改父 shell 的 PWD，只能通过文件中转）
    local tempfile="$(mktemp -t tmp.XXXXXX)"

    # command ranger：强制调用真正的 ranger 二进制，避免递归调用本函数
    # --cmd：在启动时给 ranger 注入一条按键映射
    #   map Q = 把 Q 键重定义成后面的命令链
    #   chain A; B = 依次执行 A 和 B
    #   shell echo \$PWD > $tempfile = 在 shell 里把当前目录写进临时文件
    #       注意 \$PWD 要转义，让它由 ranger 内部 shell 解释（ranger 的 PWD），
    #       而 $tempfile 不转义，由外层 zsh 提前展开成真实路径
    #   quitall = 退出 ranger
    # 整句效果：按 Q → 写路径 → 退出；按 q 走默认行为（直接退出，不写文件）
    command ranger --cmd="map Q chain shell echo \$PWD > $tempfile; quitall"

    # 退出 ranger 后回到这里。判断要不要 cd：
    #   - -s "$tempfile"：文件非空（说明按了 Q，写了路径进来）
    #   - 路径和当前 PWD 不同才有必要 cd，避免无意义的 cd
    if [[ -s "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$PWD" ]]; then
        cd -- "$(cat -- "$tempfile")" || return
    fi

    # 清理临时文件
    command rm -f -- "$tempfile" >/dev/null 2>&1
}

function mount_smb()
{
    # Linux
    # install CIFS maybe necessary
    # sudo apt-get install cifs-utils
    # macOS内置SMB客户端，无需安装额外包
    rmt_ip=${1}
    rmt_dir=${2}
    usr=${3}
    pw=${4}
    loc_dir=${5}
    loc_pfx=${6}
    # Linux
    loc_uid=""
    loc_gid=""
    # Mac
    loc_user=""
    loc_group=""

    if [ "$(uname)" = "Linux" ]
    then
        loc_uid=${7}
        loc_gid=${8}
    elif [ "$(uname)" = "Darwin" ]
    then
        # macOS不支持uid/gid直接映射，可忽略或替换为macOS的用户/组名
        loc_user=${7:-$(whoami)}  # 默认当前用户
        loc_group=${8:-staff}     # macOS默认用户组为staff
    else
        echo "Unsupported system"
        return 1
    fi

    if [[ -z "${rmt_ip}" || -z "${rmt_dir}" || -z "${usr}" || -z "${pw}" ]]
    then
        echo "Usage: mount_smb <srv_ip> <srv_dir> <usr> <pw> <loc_dir> <loc_prefix> <loc_uid> <loc_gid>"
        return 1
    fi


    if [ "$(uname)" = "Linux" ]
    then
        rmt_addr="//${rmt_ip}/${rmt_dir}"
        loc_mtp="${loc_dir}/${loc_pfx}_${rmt_dir}"
        [ ! -e ${loc_mtp} ] && mkdir -p ${loc_mtp}
        chmod 755 ${loc_mtp}
        # uid 和 gid 只是说文件挂载给谁，即挂在之后，ls可以查看当前文件所属用户
        # 如果想让其他人也访问的话，可以修改file_mode/dir_mode
        cmd="sudo mount -t cifs ${rmt_addr} ${loc_mtp} -o username=${usr},password=${pw},uid=${loc_uid},gid=${loc_gid},file_mode=0664,dir_mode=0775"
        echo "cur cmd: ${cmd}"
        eval ${cmd}
    elif [ "$(uname)" = "Darwin" ]
    then
        # 构造远程SMB地址和本地挂载点
        rmt_addr="//${usr}:${pw}@${rmt_ip}/${rmt_dir}"
        loc_mtp="${loc_dir}/${loc_pfx}_${rmt_dir}"

        # 创建挂载点（若不存在）
        if [ ! -d "${loc_mtp}" ]; then
            mkdir -p "${loc_mtp}"
            chmod 755 "${loc_mtp}"
        fi

        # macOS mount_smbfs命令（无需sudo，除非挂载到/Volumes外的系统目录）
        cmd="mount_smbfs ${rmt_addr} ${loc_mtp}"
        echo "cur cmd: ${cmd}"
        eval ${cmd}

        # 可选：调整挂载点权限（macOS中挂载后的文件权限由SMB服务器决定）
        # chown -R ${loc_user}:${loc_group} ${loc_mtp}
    fi
}


function _fmt_filter_files()
{
    local allowed="$1"
    shift
    local filtered=""

    for f in "$@"; do
        if [ -d "$f" ]; then
            # directory: let the formatter handle recursion
            filtered="${filtered} ${f}"
            continue
        fi
        local ext="${f##*.}"
        if [ "$ext" = "$f" ]; then
            # no extension: skip
            echo "[skip] ${f} (no extension)" >&2
            continue
        fi
        # check if extension is in allowed list
        if echo " ${allowed} " | grep -q " ${ext} "; then
            filtered="${filtered} ${f}"
        else
            echo "[skip] ${f} (unsupported extension: .${ext})" >&2
        fi
    done

    echo "${filtered}"
}

function code_fmt_a()
{
    # ---- help ----
    for a in "$@"; do
        if [ "$a" = "-h" ] || [ "$a" = "--help" ]; then
            echo "Usage: code_fmt_a [-r] [-h] [files...]"
            echo ""
            echo "  Format C/C++/Java/C# source files via astyle."
            echo ""
            echo "  Options:"
            echo "    -r           Recursively search directories for supported files"
            echo "    -h, --help   Show this help"
            echo ""
            echo "  Supported: c, cpp, cc, cxx, h, hpp, hxx, m, mm, cs, java"
            echo "  Config:    generates .astylerc in current dir if not present"
            return 0
        fi
    done

    local recursive=0
    if [ "$1" = "-r" ]; then
        recursive=1
        shift
    fi

    local allowed=(c cpp cc cxx h hpp hxx m mm cs java)
    local files

    if [ $recursive -eq 1 ]; then
        local search_dirs="${@:-.}"
        echo "==> Recursively searching: ${search_dirs}"
        local name_args=""
        for ext in "${allowed[@]}"; do
            [ -n "$name_args" ] && name_args="${name_args} -o"
            name_args="${name_args} -name \"*.${ext}\""
        done
        files=$(eval "find ${search_dirs} -type f \( ${name_args} \)" 2>/dev/null | sort | tr '\n' ' ')
    else
        files=$(_fmt_filter_files "${allowed[*]}" "$@")
    fi

    cfg_file=".astylerc"

    echo "========================="
    echo "==> Format via astyle <=="
    echo "========================="

    if [ -e ${cfg_file} ]
    then
        echo "==> Use ${cfg_file} in cur dir"
    else
        echo "==> Use newly created ${cfg_file} in cur dir"

        echo "# directory setting"            >  ${cfg_file}
        # --recursive 期望的是 目录或通配符，否则会报 “Recursive option with no wildcard”
        # echo "--recursive"                    >> ${cfg_file}
        # echo "--exclude=../build"             >> ${cfg_file}
        # echo "--exclude=../prebuild"          >> ${cfg_file}
        echo ""                               >> ${cfg_file}
        echo "# bracket style setting"        >> ${cfg_file}
        echo "--style=linux"                  >> ${cfg_file}
        echo ""                               >> ${cfg_file}
        echo "# indent setting"               >> ${cfg_file}
        echo "--indent=spaces=4"              >> ${cfg_file}
        echo "#--indent-switches"             >> ${cfg_file}
        echo "#--indent-preprocessor"         >> ${cfg_file}
        echo "--min-conditional-indent=0"     >> ${cfg_file}
        echo "--max-instatement-indent=120"   >> ${cfg_file}
        echo "--max-code-length=160"          >> ${cfg_file}
        echo ""                               >> ${cfg_file}
        echo "# padding setting"              >> ${cfg_file}
        echo "#--break-blocks"                >> ${cfg_file}
        echo "#--pad-oper"                    >> ${cfg_file}
        echo "#--pad-first-paren-out"         >> ${cfg_file}
        echo "--pad-header"                   >> ${cfg_file}
        echo "#--unpad-paren"                 >> ${cfg_file}
        echo "#--align-pointer=name"          >> ${cfg_file}
        echo ""                               >> ${cfg_file}
        echo "# formatting setting"           >> ${cfg_file}
        echo "--keep-one-line-blocks"         >> ${cfg_file}
        echo "--keep-one-line-statements"     >> ${cfg_file}
        echo "--convert-tabs"                 >> ${cfg_file}
        echo ""                               >> ${cfg_file}
        echo "# other setting"                >> ${cfg_file}
        echo "#--quiet"                       >> ${cfg_file}
        echo "--suffix=none"                  >> ${cfg_file}
        echo "--lineend=linux"                >> ${cfg_file}
    fi

    if [ -z "${files// /}" ]; then
        echo "==> No supported files to format (nothing to do)"
        return 0
    fi

    echo "==> Format files: ${files}"
    cmd="astyle --quiet --options=${cfg_file} ${files}"
    echo "==> cmd: ${cmd}"
    eval ${cmd}

    if [ "$?" = "0" ]
    then
        echo "==> Format finished"
    else
        echo "==> Format failed"
    fi
}


function code_fmt_c()
{
    # ---- help ----
    for a in "$@"; do
        if [ "$a" = "-h" ] || [ "$a" = "--help" ]; then
            echo "Usage: code_fmt_c [-r] [-h] [files...]"
            echo ""
            echo "  Format C/C++/Java/C#/JS/Python source files via clang-format."
            echo ""
            echo "  Options:"
            echo "    -r           Recursively search directories for supported files"
            echo "    -h, --help   Show this help"
            echo ""
            echo "  Supported: c, cpp, cc, cxx, h, hpp, hxx, m, mm, cs, java,"
            echo "             js, json, proto, py"
            echo "  Config:    generates .clang-format in current dir if not present"
            return 0
        fi
    done

    local recursive=0
    if [ "$1" = "-r" ]; then
        recursive=1
        shift
    fi

    local allowed=(c cpp cc cxx h hpp hxx m mm cs java js json proto py)
    local files

    if [ $recursive -eq 1 ]; then
        local search_dirs="${@:-.}"
        echo "==> Recursively searching: ${search_dirs}"
        local name_args=""
        for ext in "${allowed[@]}"; do
            [ -n "$name_args" ] && name_args="${name_args} -o"
            name_args="${name_args} -name \"*.${ext}\""
        done
        files=$(eval "find ${search_dirs} -type f \( ${name_args} \)" 2>/dev/null | sort | tr '\n' ' ')
    else
        files=$(_fmt_filter_files "${allowed[*]}" "$@")
    fi

    cfg_file=".clang-format"

    echo "==============================="
    echo "==> Format via clang-format <=="
    echo "==============================="

    if [ -e ${cfg_file} ]
    then
        echo "==> Use ${cfg_file} in cur dir"
    else
        echo "==> Use newly created ${cfg_file} in cur dir"

        # Google 风格空格规则
        echo "BasedOnStyle: Google"               >  ${cfg_file}
        # 缩紧为4
        echo "IndentWidth: 4"                     >> ${cfg_file}
        echo ""                                   >> ${cfg_file}
        # 自己来定义花括号规则
        echo "BreakBeforeBraces: Custom"          >> ${cfg_file}
        echo "BraceWrapping:"                     >> ${cfg_file}
        # 函数左花括号换行
        echo "    AfterFunction: true         "   >> ${cfg_file}
        # if/for/while 左花括号在同一行
        echo "    AfterControlStatement: false"   >> ${cfg_file}
        echo ""                                   >> ${cfg_file}
        # 访问控制关键字顶格
        echo "AccessModifierOffset: -4"           >> ${cfg_file}
        echo ""                                   >> ${cfg_file}
        # 不打散表达式
        # echo "BreakBinaryOperations: Never"       >> ${cfg_file}
        # echo "BreakBeforeBinaryOperators: None"   >> ${cfg_file}
        # echo ""                                   >> ${cfg_file}
        # 参数换行对齐方式
        # echo "AlignAfterOpenBracket: Align"       >> ${cfg_file}

    fi

    if [ -z "${files// /}" ]; then
        echo "==> No supported files to format (nothing to do)"
        return 0
    fi

    echo "==> Format files: ${files}"
    cmd="clang-format -i ${files}"
    echo "==> cmd: ${cmd}"
    eval $cmd

    if [ "$?" = "0" ]
    then
        echo "==> Format finished"
    else
        echo "==> Format failed"
    fi
}

function chk_ssh_safe()
{
    # =================================================================
    # SSH 安全自检：列出失败/可疑登录、成功登录、爆破强度统计
    #
    # 会自动探测环境（直连/纯 DNAT vs SNAT），并标注下面每一项检查
    # 在当前环境下是否有效：
    #   - SNAT（路由器源地址转换）会把外网连接的源 IP 全部改写成路由器
    #     的内网地址，导致「按 IP 溯源 / 识别陌生来源」类检查失效。
    # =================================================================

    local AUTH_LOG="/var/log/auth.log"

    # ---- 参数处理 ----
    case "${1}" in
        -h|--help)
            echo "用法: chk_ssh_safe [选项]"
            echo "  (无参数)        执行 SSH 安全自检（失败/可疑登录、成功登录、爆破统计）"
            echo "  -c, --clear     清空 ${AUTH_LOG}（清除历史登录信息，需 sudo 密码）"
            echo "  -e, --explain   打印 DNAT/SNAT/masquerade 原理详解（含数据流示意图）"
            echo "  -h, --help      显示本帮助"
            return 0
            ;;
        -c|--clear)
            echo "==> 清空 ${AUTH_LOG}（含 SSH/sudo 等所有认证记录，需 sudo）"
            if sudo truncate -s 0 "${AUTH_LOG}" 2>/dev/null; then
                echo "==> 已清空。rsyslog 会继续写入新记录，之后统计即为干净数据。"
            else
                echo "==> 清空失败（sudo 被取消或权限不足）"
                return 1
            fi
            return 0
            ;;
        -e|--explain)
            echo "======> NAT 原理详解（DNAT / SNAT / masquerade）======"
            cat <<'CHK_SSH_EXPLAIN'

【DNAT / SNAT 各按什么方向生效（Linux netfilter 钩子）】
  一个包穿过路由器: 入站 ──►[PREROUTING]──► 路由判断 ──►[POSTROUTING]──► 出站
  · DNAT 在「入站」生效(PREROUTING，包刚进来还没路由时)——改「目的」。
  · SNAT 在「出站」生效(POSTROUTING，包发出去之前)——改「源」；masquerade 就是这里的 SNAT。
  总结: DNAT=进来改目的(Destination, 入站)；SNAT=出去改源(Source, 出站)。
  落到端口转发: 外网包入站→PREROUTING 里 DNAT 改目的(端口转发规则本身，不受 masq 开关影响)；
                路由后从 LAN 口出站→POSTROUTING 里若 LAN masq 开则 SNAT 改源。
  ⇒ 关 LAN masq 只去掉「出站改源」，不影响「入站改目的」——端口转发照常，源 IP 恢复。

【masquerade 按「出口方向」生效 —— WAN / LAN 各在何时起作用】
  规则: masq 标在哪个区域，就作用于「从该区域接口发出去(egress)」的流量——包从哪个网口出，就看那个口所在区域的 masq。
  WAN masq 生效 = 包从 WAN 口出 = 内网→互联网(上网):
    内网电脑 ──►[LAN进]路由器[WAN出·WAN masq 改源→公网IP]──► 互联网
  LAN masq 生效 = 包从 LAN 口出 = 互联网→内网(端口映射):
    互联网客户端 ──►[WAN进·DNAT改目的]路由器[LAN出·若LAN masq开则改源→路由器LAN IP]──► 内网服务器
  ⇒ 上网走 WAN 口→靠 WAN masq(必须开)；端口映射走 LAN 口→LAN masq 开了会污染源 IP(不要开)。

【两个方向，两种 NAT —— 理解一切的钥匙】
  方向① 内网 → 公网（上网）              需要 SNAT → WAN 区「IP 动态伪装」必须开 ✅
  方向② 公网 → 内网（端口映射/发布服务） 只需 DNAT → 不要 SNAT，关掉 LAN masq ❌

【端口转发 = DNAT(改目的)；masquerade 是叠加的 SNAT(改源)】
  外网客户端(真实IP A) ──► [路由器] 对这个包做两件事：
                            ① DNAT：改「目的」 公网IP:P → 服务器:22   (端口映射核心，必须)
                            ② masq：改「源」   A → 路由器IP           (额外叠加的 SNAT，可去掉)
                               ▼
                            服务器(看到的源 = 路由器IP)
  ① ② 是两件独立的事「叠」在一起。关 LAN masq = 只做① 不做②  → 服务器看到真实源 A。

【为什么共享上网必须 SNAT —— 私有 IP 在公网不可路由】
  没有 SNAT(上不了网):
    电脑 192.168.1.100 ──请求──► 8.8.8.8
    8.8.8.8 回包: 目的=192.168.1.100 → 私有地址，公网不认识，回包丢失 ❌
  有 SNAT(WAN masq 开):
    电脑 192.168.1.100 ──► 路由器 ──源改成公网IP 1.2.3.4──► 8.8.8.8
                                                          │
    8.8.8.8 回包: 目的=1.2.3.4 ◄──路由器◄─────────────────┘
        │ 查 NAT 表，目的改回 192.168.1.100
        └─► 电脑 ✅

【WAN 勾选 IP 动态伪装 = 对外翻译/隐藏内网 IP（靠端口区分多设备 = NAPT）】
  手机 192.168.1.101 ─┐
  电脑 192.168.1.100 ─┼─► 路由器(SNAT) ──► 公网: 源 IP 全是 1.2.3.4
  电视 192.168.1.102 ─┘
  外网只看到 1.2.3.4 一个 IP，三个内网私有 IP 被翻译掉。
  回包靠端口号区分: 1.2.3.4:50001→手机  :50002→电脑  :50003→电视  (这就是 NAPT/PAT)

【判断与处理】
  · 若日志里源 IP 全是路由器内网 IP(如 192.168.1.1)，说明在「方向② 」里误开了 SNAT(LAN masq)。
  · 关掉 LAN masq 后，方向② 只剩纯 DNAT，服务器恢复记录真实公网源 IP。
  · WAN masq 别动(方向① 上网要用)；只关 LAN masq。
CHK_SSH_EXPLAIN
            return 0
            ;;
    esac

    # ---- 0. 日志来源 & 环境探测 ----
    if [ ! -r "${AUTH_LOG}" ]; then
        echo "无法读取 ${AUTH_LOG}（需要 adm 组成员或 sudo）"
        echo "可改用： sudo journalctl -u ssh -u sshd --since '24 hours ago'"
        return 1
    fi

    # 取 sshd 日志里出现的所有「连接源 IP」（去重），判断是否全部落在私有内网段
    # —— SNAT 的特征：外网攻击者真实公网 IP 被抹掉，日志里只剩内网地址
    # 注意：先排除 "Server listening on ..." 这类启动行（会带入 0.0.0.0 监听地址，
    #       那不是连接来源，会让私有段判断误判为公网）
    local src_ips priv_all
    src_ips=$(grep -a sshd "${AUTH_LOG}" 2>/dev/null \
              | grep -avE "Server listening|re-executing|Received signal" \
              | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u \
              | grep -vE '^(0\.0\.0\.0|255\.255\.255\.255)$')
    priv_all=1
    [ -z "${src_ips}" ] && priv_all=0
    while read -r ip; do
        [ -z "${ip}" ] && continue
        case "${ip}" in
            10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;;  # 私有段，继续
            *) priv_all=0;;                                           # 出现公网 IP，非 SNAT
        esac
    done <<< "${src_ips}"

    local snat=0
    [ "${priv_all}" = "1" ] && [ -n "${src_ips}" ] && snat=1

    echo "################### SSH 安全自检 ###################"
    echo "日志来源: ${AUTH_LOG}"
    if [ "${snat}" = "1" ]; then
        echo "当前环境: [SNAT / 纯内网] 源 IP 全是路由器内网私有地址（公网真实来源被抹掉）"
        echo "           -> 按 IP 溯源 / 识别陌生来源的检查会失效。"
    else
        echo "当前环境: [直连 / 纯 DNAT] 源 IP 被保留，可正常溯源"
    fi
    echo ""

    # ---- 原理 & 操作指引（DNAT / SNAT / IP 动态伪装）----
    if [ "${snat}" = "1" ]; then
        echo "状态建议: ⚠ 当前为 SNAT 环境，建议按下方指引在路由器 Web 界面改成纯 DNAT"
    else
        echo "状态建议: ✓ 当前已是纯 DNAT（源 IP 保留），以下为原理与维护指引"
    fi
    echo "------> 原理 & 操作指引 <------"
    cat <<'CHK_SSH_NAT_INFO'
  · 检测当前是 DNAT 还是 SNAT：看 SSH 日志里的源 IP —— 真实公网 IP = 纯 DNAT；全是路由器内网 IP(如 192.168.x.1) = 被 SNAT 改写。(本工具「当前环境」即此判据)
  · DNAT(目的 NAT)：端口映射的核心，把「公网IP:外端口」改成「内网IP:内端口」，保留客户端真实源 IP。
  · SNAT/masquerade(源 NAT =「IP 动态伪装」)：把源 IP 改成路由器自己的 IP。端口转发里它「叠加」在 DNAT 之上(DNAT 改目的、masq 再改源)；去掉 masq = 露出本就在的 DNAT，而非「转成」DNAT。
  · 为什么共享上网必须 SNAT：内网私有 IP(192.168.x) 在公网不可路由，回包送不回来；路由器 SNAT 把源换成 WAN 公网 IP，外网才能回包到路由器、再转回内网。
  · WAN 区勾选 IP 动态伪装 = 内网出网时源 IP 换成路由器公网 IP(对外隐藏内网私有 IP，靠端口区分多台设备)——共享上网的根本，必须保留。
  · Web(LuCI)改成纯 DNAT：网络 → 防火墙 → 区域 → 编辑 lan → 取消「IP 动态伪装」→ 保存并应用。(wan 的保持勾选)
  · 影响/前提：去掉 LAN masq 后服务器记录真实源 IP(可溯源/封 IP)；前提是服务器网关指向本路由器，否则外网连不上。兜底：若改后外网 SSH 断，LuCI 仍可访问，勾回 lan 的「IP 动态伪装」即可。
CHK_SSH_NAT_INFO
    echo ""

    # 可疑尝试匹配模式：补全原版只 grep "Failed password" 的盲区 ——
    # 多数扫描在 preauth 阶段就断开，只留下 "Invalid user" / "Connection reset [preauth]"
    local atk_pat='Failed password|Invalid user|Connection reset.*preauth|Connection closed.*preauth|Disconnected from.*preauth|kex_exchange_identification'

    # ---- 1. 失败 & 可疑登录尝试 ----
    echo "======> [1] 失败 & 可疑登录尝试"
    echo "场景对照 → 纯DNAT ✅ 能看到真实来源IP  |  SNAT ⚠️  只能看到'有人在试'(真实IP被抹掉)"
    if [ "${snat}" = "1" ]; then
        echo "▶ 当前[SNAT] ⚠️  受限：仍能看到有人在试，但真实 IP 被抹成内网地址"
    else
        echo "▶ 当前[纯DNAT] ✅ 有效：能看到真实来源 IP，可判断是否有人爆破"
    fi
    echo "------> current status <------"
    grep -aE "${atk_pat}" "${AUTH_LOG}" 2>/dev/null | tail -30
    echo ""

    # ---- 2. 成功登录记录 ----
    echo "======> [2] 成功登录记录（识别是否有陌生来源登入过）"
    echo "场景对照 → 纯DNAT ✅ 有效(靠IP识别陌生人)  |  SNAT ❌ 失效(源IP全是路由器,无法区分)"
    if [ "${snat}" = "1" ]; then
        echo "▶ 当前[SNAT] ❌ 失效：所有登录源 IP 都被改写成内网地址，无法靠 IP 区分陌生人（仅能核对用户名）"
    else
        echo "▶ 当前[纯DNAT] ✅ 有效：只应出现自己的用户名 + 自己的 IP，出现陌生 IP 即可能被入侵"
    fi
    echo "------> current status <------"
    grep -a "Accepted" "${AUTH_LOG}" 2>/dev/null | tail -30
    echo ""

    # ---- 3. 爆破 & 扫描强度统计 ----
    echo "======> [3] 爆破 & 扫描强度统计"
    echo "场景对照 → 纯DNAT ✅ 按来源IP统计  |  SNAT ⚠️  按IP无意义,改按事件类型计数"
    if [ "${snat}" = "1" ]; then
        echo "▶ 当前[SNAT] ⚠️  调整：按事件类型计数（见下）"
        echo "------> current status <------"
        echo -n "  Failed password (走到密码验证): "; grep -ac "Failed password"            "${AUTH_LOG}" 2>/dev/null
        echo -n "  Invalid user    (用户名不存在): "; grep -ac "Invalid user"               "${AUTH_LOG}" 2>/dev/null
        echo -n "  preauth 断开     (扫描/探测):   "; grep -acE "Connection (reset|closed).*preauth" "${AUTH_LOG}" 2>/dev/null
        echo -n "  kex 异常         (密钥交换探测): "; grep -ac "kex_exchange_identification" "${AUTH_LOG}" 2>/dev/null
    else
        echo "▶ 当前[纯DNAT] ✅ 有效：按来源 IP 统计，同一 IP 几十/上百次 = 自动化攻击"
        echo "------> current status <------"
        grep -aE "${atk_pat}" "${AUTH_LOG}" 2>/dev/null \
            | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | head
    fi
    echo ""

    # ---- 实时监控（需要时手动执行） ----
    echo "======> 实时监控（手动执行）"
    echo "  sudo tail -f /var/log/auth.log"
    echo "  sudo journalctl -u ssh -u sshd --since '1 hour ago'"
}

function chk_vnc_safe()
{
    # =================================================================
    # VNC 安全自检：监听暴露面、认证强度、连接来源分析
    #
    # 核心风险: VNC 若监听 0.0.0.0 并经路由器端口映射到公网，配合弱
    #   认证 VncAuth(8 字符 DES)，极易被扫描爆破。
    # 加固方向: VNC 收回本地(-localhost yes)，公网只暴露 SSH，远程
    #   访问走 SSH 加密隧道（详见 -e）。
    # =================================================================

    local VNC_LOG_DIR="$HOME/.vnc"

    # ---- 参数处理 ----
    case "${1}" in
        -h|--help)
            echo "用法: chk_vnc_safe [选项]"
            echo "  (无参数)      VNC 安全自检（监听暴露、认证、连接来源）"
            echo "  -e, --explain 打印 VNC 加固方案（SSH 隧道原理与 5 步操作）"
            echo "  -h, --help    显示本帮助"
            return 0
            ;;
        -e|--explain)
            echo "======> VNC 加固方案详解（SSH 隧道）======"
            cat <<'CHK_VNC_EXPLAIN'
核心思路: 把 VNC 收回本地(只听 127.0.0.1)，公网只暴露 SSH，
          远程访问经 SSH 加密隧道转发到本地 VNC。

【为什么不要直接暴露 VNC】
  · VncAuth 仅 8 字符密码 + DES 加密，弱认证，易被爆破/重放。
  · -localhost no 监听 0.0.0.0，配合端口映射即公网可达。
  · 公网对 5900/5990 的扫描非常普遍。

【SSH 隧道加固 5 步】
  1. 服务器端 VNC 只听本地:
       vncserver -geometry 1920x1080 :90 -localhost yes
       验证: ss -tlnp | grep 5990   应为 127.0.0.1:5990，而非 0.0.0.0:5990
  2. 路由器: 删除 VNC(5990) 映射，只保留 SSH(22)；
             外部端口用非标准号(如 22222→22)可挡自动扫描。
  3. SSH 加固: /etc/ssh/sshd_config 设 PasswordAuthentication no
             (先 ssh-keygen + ssh-copy-id 配好密钥再禁密码)、PermitRootLogin no。
  4. 客户端建隧道:
       ssh -L 5990:localhost:5990 user@<公网IP> -p <SSH端口>
       后台: ssh -fN -L 5990:localhost:5990 user@<公网IP> -p <SSH端口>
  5. VNC viewer 连 localhost:5990（不是服务器 IP），流量经 SSH 加密送达。

【改造前后】
  前: 公网暴露 VNC 5990(弱认证) → 5900/5990 常被扫
  后: 公网仅 SSH 22，VNC 收回本地 → 扫不到 VNC，SSH 密钥强认证

【autossh 自动重连】
  autossh -M 0 -fN -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" \
          -o "ExitOnForwardFailure=yes" -L 5990:localhost:5990 user@<IP> -p <端口>
CHK_VNC_EXPLAIN
            return 0
            ;;
    esac

    echo "################### VNC 安全自检 ###################"
    echo ""

    # ---- 1. VNC 进程 & 监听端口（暴露面）----
    echo "======> [1] VNC 进程 & 监听端口"
    echo "------> current status <------"
    local vnc_procs
    vnc_procs=$(pgrep -af 'Xtigervnc|Xvnc|x11vnc|tightvnc' 2>/dev/null | grep -v pgrep)
    if [ -z "${vnc_procs}" ]; then
        echo "  (未检测到 VNC 进程在运行)"
    else
        echo "${vnc_procs}" | sed 's/^/  /'
    fi
    echo ""
    echo "  监听端口 (0.0.0.0=公网暴露 / 127.0.0.1=仅本地):"
    ss -tlnp 2>/dev/null | grep -E ':(59[0-9][0-9])' | sed 's/^/  /' \
        || echo "  (无 VNC 端口监听)"
    echo ""

    # ---- 2. 监听暴露面判定 ----
    echo "======> [2] 监听暴露面判定"
    if ss -tln 2>/dev/null | grep -qE '^LISTEN.*0\.0\.0\.0:59[0-9][0-9]'; then
        echo "  ⚠ 危险: VNC 监听 0.0.0.0（公网可达）"
        echo "     建议 -localhost yes + SSH 隧道（chk_vnc_safe -e 看详情）"
    elif ss -tln 2>/dev/null | grep -qE '^LISTEN.*127\.0\.0\.1:59[0-9][0-9]'; then
        echo "  ✓ 安全: VNC 只监听 127.0.0.1（本地）"
    else
        echo "  (未检测到 VNC 监听)"
    fi
    echo ""

    # ---- 3. 认证方式（SecurityTypes，从进程参数看）----
    echo "======> [3] 认证方式（SecurityTypes）"
    echo "------> current status <------"
    if [ -n "${vnc_procs}" ]; then
        local sec
        sec=$(ps -eo args 2>/dev/null | grep -E '[X]tigervnc|[X]vnc' \
              | grep -oE 'SecurityTypes [^ ]+' | head -1)
        if [ -n "${sec}" ]; then
            echo "  ${sec}"
        else
            echo "  (命令行未显式指定 SecurityTypes)"
        fi
        echo "  说明: VncAuth=弱(8字符DES) / TLSVnc·X509=较强"
    else
        echo "  (无 VNC 进程)"
    fi
    echo ""

    # ---- 4. 连接来源分析（谁在连/试连 VNC）----
    echo "======> [4] 连接来源分析（谁在连/试连 VNC）"
    echo "------> current status <------"

    # 4.1 实时在线连接
    echo "  ▶ 实时在线连接（ESTAB）:"
    local estab
    estab=$(ss -tnp 2>/dev/null | grep ':59[0-9][0-9]' | grep ESTAB)
    if [ -n "${estab}" ]; then
        echo "${estab}" | sed 's/^/    /'
    else
        echo "    (无在线连接)"
    fi
    echo ""

    # 4.2 ~ 4.5 日志来源分析
    if ! ls "${VNC_LOG_DIR}"/*.log >/dev/null 2>&1; then
        echo "  (未找到 ${VNC_LOG_DIR}/*.log，跳过日志来源分析)"
        echo ""
    else
        # 4.2 成功连入历史（accepted，最敏感）
        echo "  ▶ 成功连入历史（accepted，最敏感）:"
        local acc
        acc=$(grep -ahE 'Connections: accepted:' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
              | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr)
        if [ -n "${acc}" ]; then echo "${acc}" | sed 's/^/    /'; else echo "    (无)"; fi
        echo ""

        # 4.3 所有连入尝试（closing，含成功/失败/探测）
        echo "  ▶ 所有连入尝试（closing，含成功/失败/探测）:"
        local cl
        cl=$(grep -ahE 'closing [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+::' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
             | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr)
        if [ -n "${cl}" ]; then echo "${cl}" | head -10 | sed 's/^/    /'; else echo "    (无)"; fi
        echo ""

        # 4.4 失败/拉黑/探测统计
        local n_auth n_blk n_rfb
        n_auth=$(grep -ahc 'Authentication failure' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
                 | awk '{s+=$1} END{print s+0}')
        n_blk=$(grep -ahc 'blacklisted' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
                | awk '{s+=$1} END{print s+0}')
        n_rfb=$(grep -ahc 'not an RFB' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
                | awk '{s+=$1} END{print s+0}')
        echo "  ▶ 失败/拉黑/探测统计:"
        echo "    认证失败(AuthFailure): ${n_auth}"
        echo "    被拉黑(blacklisted):   ${n_blk}"
        echo "    端口探测(not an RFB):  ${n_rfb}"
        if [ "${n_blk}" != "0" ]; then
            echo "    blacklisted 来源 TOP:"
            grep -ah 'blacklisted' "${VNC_LOG_DIR}"/*.log 2>/dev/null \
                | grep -oE 'blacklisted: [0-9.]+' | sort | uniq -c | sort -nr | head -5 \
                | sed 's/^/      /'
        fi
        echo ""

        # 4.5 NAT 环境判定（来源是否被路由器 SNAT 抹掉）
        echo "  ▶ NAT 环境判定（来源是否被路由器 SNAT 抹掉）:"
        local src_ips has_pub
        src_ips=$(grep -ahE 'Connections: (accepted|blacklisted):|closing [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+::' \
                  "${VNC_LOG_DIR}"/*.log 2>/dev/null \
                  | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u \
                  | grep -vE '^(0\.0\.0\.0|127\.0\.0\.1)$')
        if [ -z "${src_ips}" ]; then
            echo "    (日志无连接来源记录)"
        else
            has_pub=$(echo "${src_ips}" | grep -cvE '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)')
            if [ "${has_pub}" = "0" ]; then
                echo "    [SNAT] 来源全是私有内网段 → 真实公网被路由器抹，溯源失效"
            else
                echo "    [纯DNAT] 含公网来源，可溯源:"
                echo "${src_ips}" | grep -vE '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' \
                    | sed 's/^/      /'
            fi
        fi
    fi
    echo ""

    # ---- 实时监控（手动执行）----
    echo "======> 实时监控（手动执行）"
    echo "  tail -f ~/.vnc/*.log"
    echo "  详细加固方案: chk_vnc_safe -e"
}

function esp_init_prj()
{
    # ================================================
    # Usage:
    #   esp_init_prj <project_name> [path] [target]
    #
    #   project_name  - 项目名称 (必填)
    #   path          - 项目路径 (可选, 默认当前目录)
    #   target        - 目标芯片 (可选, 默认 esp32)
    #                   支持: esp32/esp32s2/esp32s3/esp32c3/esp32c6
    #
    # Example:
    #   esp_init_prj smart-home                   # 当前目录
    #   esp_init_prj smart-home ~/Projects/esp32  # 指定目录
    #   esp_init_prj sensor-node . esp32s3        # 指定芯片
    #
    # What it does:
    #   1. 检查 ESP-IDF 环境 ($IDF_PATH 或 ~/esp/esp-idf)
    #   2. 从 hello_world 模板复制并清理 .git
    #   3. 生成 CMakeLists.txt / main.c / .gitignore / sdkconfig.defaults
    #   4. 创建 components/ 目录用于放置自定义组件
    #   5. 生成 README.md (含 Quick Start 和项目结构说明)
    #   6. sdkconfig.defaults 预置:
    #      - 4MB Flash, 921600 烧录波特率
    #      - 日志级别 Info, FreeRTOS 栈溢出检测
    # ================================================

    # ---- 帮助 ----
    if [ "${1}" = "-h" ] || [ "${1}" = "--help" ] || [ -z "${1}" ]; then
        echo "Usage: esp_init_prj <project_name> [path] [target]"
        echo ""
        echo "  project_name  project name (required)"
        echo "  path          project root path (default: .)"
        echo "  target        chip target (default: esp32)"
        echo "                  esp32 | esp32s2 | esp32s3 | esp32c3 | esp32c6"
        echo ""
        echo "Examples:"
        echo "  esp_init_prj smart-home                   # current dir, esp32"
        echo "  esp_init_prj smart-home ~/Projects/esp32  # custom path"
        echo "  esp_init_prj sensor-node . esp32s3        # custom target"
        return 0
    fi

    local proj_name="${1}"
    local proj_path="${2:-.}"
    local target="${3:-esp32}"

    # ---- 检查 ESP-IDF 环境 ----
    local idf_path="${IDF_PATH}"
    if [ -z "${idf_path}" ]; then
        # 尝试默认路径
        if [ -f "${HOME}/esp/esp-idf/export.sh" ]; then
            idf_path="${HOME}/esp/esp-idf"
        else
            echo "Error: ESP-IDF not found"
            echo "  Please run 'esp_get_idf' or set IDF_PATH first"
            return 1
        fi
    fi
    local template="${idf_path}/examples/get-started/hello_world"
    if [ ! -d "${template}" ]; then
        echo "Error: template not found: ${template}"
        return 1
    fi

    # ---- 创建项目 ----
    local proj_dir="${proj_path}/${proj_name}"
    if [ -e "${proj_dir}" ]; then
        echo "Error: ${proj_dir} already exists"
        return 1
    fi

    echo "============================="
    echo "==> ESP32 Project Init <=="
    echo "============================="
    echo "  name:   ${proj_name}"
    echo "  path:   ${proj_dir}"
    echo "  target: ${target}"
    echo "  idf:    ${idf_path}"
    echo ""

    # 复制模板
    cp -r "${template}" "${proj_dir}"
    rm -rf "${proj_dir}/.git" 2>/dev/null  # 移除模板的 git 历史

    # ---- 更新 CMakeLists.txt ----
    cat > "${proj_dir}/CMakeLists.txt" << 'EOF'
# The following five lines of boilerplate have to be in your project's CMakeLists
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)

project(PROJ_PLACEHOLDER)
EOF
    sed -i "s/PROJ_PLACEHOLDER/${proj_name}/" "${proj_dir}/CMakeLists.txt"

    # ---- 写 main.c ----
    cat > "${proj_dir}/main/main.c" << 'EOF'
/**
 * @file main.c
 * @brief PROJ_PLACEHOLDER - ESP32 project
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "main";

void app_main(void)
{
    ESP_LOGI(TAG, "Hello from PROJ_PLACEHOLDER!");
    ESP_LOGI(TAG, "Free heap: %lu bytes", esp_get_free_heap_size());

    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "running... (%d)", ++count);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
EOF
    sed -i "s/PROJ_PLACEHOLDER/${proj_name}/" "${proj_dir}/main/main.c"

    # ---- 写 .gitignore ----
    cat > "${proj_dir}/.gitignore" << 'EOF'
# build artifacts
build/
managed_components/

# idf.py generated
sdkconfig
sdkconfig.old
sdkconfig.old.*

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF

    # ---- 写 sdkconfig.defaults ----
    cat > "${proj_dir}/sdkconfig.defaults" << EOF
# Flash
CONFIG_ESPTOOLPY_FLASHSIZE_4MB=y
CONFIG_ESPTOOLPY_BAUD_921600=y

# Log
CONFIG_LOG_DEFAULT_LEVEL_INFO=y
CONFIG_LOG_MAXIMUM_LEVEL_DEBUG=y

# FreeRTOS
CONFIG_FREERTOS_HZ=1000
CONFIG_FREERTOS_CHECK_STACKOVERFLOW_CANARY=y

# Partition Table
CONFIG_PARTITION_TABLE_SINGLE_APP=y
EOF

    # ---- 写 main/CMakeLists.txt (如需添加更多源文件) ----
    cat > "${proj_dir}/main/CMakeLists.txt" << 'EOF'
idf_component_register(SRCS "main.c"
                       INCLUDE_DIRS ".")
EOF

    # ---- 创建组件目录 ----
    mkdir -p "${proj_dir}/components"

    # ---- 创建 README.md ----
    cat > "${proj_dir}/README.md" << EOF
# ${proj_name}

ESP32 project (target: \`${target}\`)

## Quick Start

\`\`\`bash
# activate idf env
esp_get_idf

# build
cd ${proj_name}
idf.py set-target ${target}
idf.py build

# flash & monitor
idf.py -p /dev/ttyUSB0 flash monitor
\`\`\`

## Project Structure

\`\`\`
${proj_name}/
+-- CMakeLists.txt        # top-level cmake
+-- main/
|   +-- CMakeLists.txt    # main component
|   +-- main.c            # entry point (app_main)
+-- components/           # custom components
+-- sdkconfig.defaults    # project config defaults
+-- .gitignore
+-- README.md
\`\`\`
EOF

    # ---- 结果 ----
    echo ""
    echo "==> Done! Project created at: ${proj_dir}"
    echo ""
    echo "Next steps:"
    echo "  cd ${proj_dir}"
    echo "  esp_get_idf                          # activate ESP-IDF env"
    echo "  idf.py set-target ${target}          # set chip target"
    echo "  idf.py build                         # build"
    echo "  idf.py -p /dev/ttyUSB0 flash monitor # flash & monitor"
}
