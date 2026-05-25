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

    # <SSH 代理 - 方案一：git core.sshCommand>
    # SSH 不读 http_proxy/all_proxy 环境变量
    # 通过 git core.sshCommand 设置，让 git 调用 SSH 时自动带上 ProxyCommand
    # 等价于在 ~/.ssh/config 中写 ProxyCommand，但当前方法只影响 git 操作（不影响 ssh/scp 等）
    #
    # nc（netcat）的作用：SSH 只知道目标地址，不懂代理协议，需要一个中间人帮它走代理
    #   无代理：SSH ─────────────────────────────> github.com:22（直连，可能被 reset）
    #   有代理：SSH ──> nc ──> SOCKS5代理服务器 ──> github.com:22（nc 帮 SSH 建隧道）
    #
    # nc 参数说明：
    #   -X 5          使用 SOCKS5 协议（-X 4 = SOCKS4, -X connect = HTTP CONNECT）
    #   -x IP:PORT    代理服务器地址和端口
    #   %h %p         SSH 自动替换为目标主机名和端口（如 github.com 和 22）
    #
    # 工作流程：
    #   1. git 调用 SSH 时，SSH 执行 ProxyCommand 而不是直连目标
    #   2. nc 通过 SOCKS5 协议连接代理服务器，请求转发到 github.com:22
    #   3. 代理服务器与 github.com:22 建立 TCP 连接（隧道）
    #   4. nc 把隧道两端的标准输入输出交给 SSH
    #   5. SSH 在隧道上完成密钥交换、认证、数据传输（对上层透明）
    if command -v nc &> /dev/null; then
        git config --global core.sshCommand "ssh -o ProxyCommand='nc -X 5 -x ${proxyIP}:${proxyPort} %h %p'"
    fi

    # <SSH 代理 - 方案二：修改 ~/.ssh/config>
    # 直接修改 SSH 配置文件，影响所有 SSH 操作（git/ssh/scp 等）
    # 与方案一的区别：方案一只影响 git，本方案影响所有通过 SSH 的操作
    #
    # 分三种情况处理：
    #   1) 已有 github.com Host 块，且已有 ProxyCommand → 更新为当前代理地址
    #   2) 已有 github.com Host 块，但没有 ProxyCommand → 在块末尾（空行前）追加
    #   3) 没有 github.com Host 块 → 追加一个完整的 Host 块
    if command -v nc &> /dev/null; then
        _ssh_cfg="${HOME}/.ssh/config"
        _ssh_proxy_cfg="ProxyCommand nc -X 5 -x ${proxyIP}:${proxyPort} %h %p"
        if [ -f "${_ssh_cfg}" ]; then
            # grep -q "^Host github.com"：
            #   ^       行首锚定，避免匹配到 "# Host github.com" 注释行
            #   -q      quiet（静默模式），不输出匹配内容，只返回退出码（0=匹配到, 1=未匹配）
            if grep -q "^Host github.com" "${_ssh_cfg}"; then
                # 情况 1 或 2：已有 Host 块
                # 先尝试替换已有的 ProxyCommand（情况 1：有则更新；情况 2：无则什么都不做）
                # sed 命令详解：
                #   -i              直接修改文件（不输出到 stdout）
                #   "/^Host github.com/,/^$/"  地址范围：从 Host 行到空行（一个 Host 块）
                #   { ... }         在该范围内执行大括号内的命令
                #   s|ProxyCommand.*|${_ssh_proxy_cfg}|  替换整行 ProxyCommand 为新值
                #                  使用 | 作为分隔符（因为替换内容包含 /）
                sed -i "/^Host github.com/,/^$/{ s|ProxyCommand.*|${_ssh_proxy_cfg}| }" "${_ssh_cfg}"
                # 替换后再次检查，如果仍然没有 ProxyCommand → 说明原本就没有，需要追加（情况 2）
                # 用 sed 取出整个 Host 块内容（从 Host 行到空行），再 grep 查 ProxyCommand
                # 不用 grep -A5（固定行数可能不够，块内配置多时会漏掉）
                # sed 参数说明：
                #   -n              默认不输出任何行（安静模式），只输出 p 命令显式匹配的行
                #   "/^Host github.com/,/^$/p"  地址范围 + p 命令：打印从 Host 行到空行的所有内容
                #   如果不加 -n，sed 会先打印所有行，p 命令又会重复打印匹配的行（输出两份）
                if ! sed -n "/^Host github.com/,/^$/p" "${_ssh_cfg}" | grep -q "ProxyCommand"; then
                    # 在 Host 块的末尾（空行之前）追加 ProxyCommand
                    # sed i\ 命令详解：
                    #   "/^Host github.com/,/^$/"  地址范围：从 Host 行到空行
                    #   /^$/           匹配空行（块结尾）
                    #   i\\             insert：在匹配行之前插入
                    #   注意：POSIX sed 要求 \\ 后必须换行，插入内容写在下一行
                    sed -i "/^Host github.com/,/^$/{ /^$/i\\
    ${_ssh_proxy_cfg}
}" "${_ssh_cfg}"
                fi
            else
                # 情况 3：没有 Host 块 → 追加完整块
                printf '\nHost github.com\n    HostName github.com\n    User git\n    %s\n' "${_ssh_proxy_cfg}" >> "${_ssh_cfg}"
            fi
        else
            # ~/.ssh/config 不存在 → 创建文件并写入完整配置
            printf 'Host github.com\n    HostName github.com\n    User git\n    %s\n' "${_ssh_proxy_cfg}" > "${_ssh_cfg}"
            chmod 600 "${_ssh_cfg}"
        fi
        unset _ssh_proxy_cfg _ssh_cfg
    fi
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

# =============================================================================
# =============================== tools =======================================
# =============================================================================
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


function code_fmt_a()
{
    files="$@"
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
    files="$@"
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

function ck_ssh_safe()
{
    echo "======> log failed"
    echo "如果看到："
    echo "Failed password for invalid user admin from 185.xxx.xxx.xxx"
    echo "Failed password for root from 45.xxx.xxx.xxx"
    echo "说明有人在尝试登录你的服务器"
    echo "------> current status <------"
    grep "Failed password" /var/log/auth.log
    echo ""

    echo "======> log Accepted"
    echo "应该只看到："
    echo "自己的用户名"
    echo "自己的 IP"
    echo "如果有陌生 IP，说明已经被登录过"
    echo "------> current status <------"
    grep "Accepted" /var/log/auth.log
    echo ""

    echo "======> log Accepted"
    echo "看哪些 IP 在反复试密码，即 “扫端口 / 爆破”"
    echo "输出示例："
    echo "120  103.88.xx.xx"
    echo "87   45.142.xx.xx"
    echo "同一 IP 尝试几十、上百次 = 自动化攻击"
    echo "------> current status <------"
    grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head
    echo ""

    # 实时监控 SSH 尝试
    # sudo tail -f /var/log/auth.log
    # 什么都不做，只要看到类似：
    # Failed password for invalid user test from 91.xx.xx.xx
    # 就是公网在扫你。

    # 看 SSH 服务有没有被频繁访问
    # journalctl -u ssh --since "1 hour ago"
    # 或
    # journalctl -u sshd
}

