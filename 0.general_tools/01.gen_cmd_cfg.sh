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
