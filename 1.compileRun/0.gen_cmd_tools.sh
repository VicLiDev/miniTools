#!/usr/bin/env bash
#########################################################################
# File Name: 0.gen_cmd_tools.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sun 14 Dec 2025 10:18:23 AM CST
#########################################################################

# source ${HOME}/Projects/miniTools/1.compileRun/0.gen_cmd_tools.sh


function mount_smb()
{
    # install CIFS maybe necessary
    # sudo apt-get install cifs-utils

    rmt_ip=${1}
    rmt_dir=${2}
    usr=${3}
    pw=${4}
    loc_dir=${5}
    loc_pfx=${6}
    loc_uid=${7}
    loc_gid=${8}
    if [[ -z "${rmt_ip}" || -z "${rmt_dir}" || -z "${usr}" || -z "${pw}" ]]
    then
        echo "Usage: mount_smb <srv_ip> <srv_dir> <usr> <pw> <loc_dir> <loc_prefix> <loc_uid> <loc_gid>"
        return -1
    fi
    rmt_addr="//${rmt_ip}/${rmt_dir}"
    loc_mtp="${loc_dir}/${loc_pfx}_${rmt_dir}"
    [ ! -e ${loc_mtp} ] && mkdir -p ${loc_mtp}
    chmod 755 ${loc_mtp}
    # uid 和 gid 只是说文件挂载给谁，即挂在之后，ls可以查看当前文件所属用户
    # 如果想让其他人也访问的话，可以修改file_mode/dir_mode
    cmd="sudo mount -t cifs ${rmt_addr} ${loc_mtp} -o username=${usr},password=${pw},uid=${loc_uid},gid=${loc_gid},file_mode=0664,dir_mode=0775"
    echo "cur cmd: ${cmd}"
    eval ${cmd}
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
