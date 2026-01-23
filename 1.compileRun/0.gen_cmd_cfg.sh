#!/usr/bin/env bash
#########################################################################
# File Name: 0.gen_cmd_cfg.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 14 Dec 2025 10:18:23 AM CST
#########################################################################

# source ${HOME}/Projects/miniTools/1.compileRun/0.gen_cmd_cfg.sh

# =============================================================================
# ============================ def config =====================================
# =============================================================================
# ------------------------
# ------> path env <------
# ------------------------
export PATH=${HOME}/bin:${PATH}
export PATH="$HOME/.local/bin:$PATH"
# ------------------------------
# ------> default editor <------
# ------------------------------
export EDITOR=vim
# ---------------------
# ------> proxy <------
# ---------------------
# set proxyIP and proxyPort
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
# ======> miniforge3
if [ -f "${HOME}/miniforge3/etc/profile.d/mamba.sh" ]; then
    . "${HOME}/miniforge3/etc/profile.d/mamba.sh"
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
