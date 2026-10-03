#!/usr/bin/env bash
#########################################################################
# File Name: 04.csv.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Sep 2026 06:40:00 PM CST
#########################################################################

# usage:
#     1. source $(dirname $(readlink -f $0))/../0.general_tools/04.csv.sh
#        or
#        prj_root_dir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
#        source ${prj_root_dir}/0.general_tools/04.csv.sh
#        or after run init_tools.sh
#        source ${HOME}/bin/_csv.sh
#     2. 接口:
#          csv_field  <value>              字段转义, 输出到 stdout (不含换行)
#          csv_row    <v1> <v2> ...        生成一行 (分隔符分隔, 各字段转义)
#          csv_append <file> <v1> ...      追加一行到文件 (file 不存在则创建)
#          csv_header <file> <v1> ...      仅当 file 不存在或为空时写入表头行
#          csv_set_delim <char>            设置分隔符 (默认 ",")
#          csv_set_quote <minimal|always>  引号策略 (默认 minimal)
#     3. 说明:
#          - 默认"最小引号": 仅当字段含分隔符/双引号/CR/LF 时才加引号,
#            csv_set_quote always 则所有字段都加引号; 引号内的引号会翻倍.
#          - 支持空字段(如 csv_row "" b 输出 ",b"); 输出用 printf, 不会吞 "-n".

# 运行时配置
_csv_delim=","
_csv_quote="minimal"

# 转义单个字段, 结果写入全局 _csv_val (内部使用, 避免子 shell)
function _csv_escape()
{
    local v="${1:-}"
    if [ "${_csv_quote}" = "always" ]; then
        _csv_val="\"${v//\"/\"\"}\""
        return 0
    fi
    case "${v}" in
        *"${_csv_delim}"*|*"\""*|*$'\n'*|*$'\r'*)
            _csv_val="\"${v//\"/\"\"}\"" ;;
        *)
            _csv_val="${v}" ;;
    esac
}

# CSV 字段转义, 输出到 stdout (不含换行)
function csv_field()
{
    _csv_escape "${1:-}"
    printf '%s' "${_csv_val}"
}

# 生成一行 CSV: csv_row <v1> <v2> ...
function csv_row()
{
    local out="" v i=0
    for v in "$@"; do
        if [ "${i}" -gt 0 ]; then
            out+="${_csv_delim}"
        fi
        _csv_escape "${v}"
        out+="${_csv_val}"
        i=$((i + 1))
    done
    printf '%s\n' "${out}"
}

# 追加一行 CSV: csv_append <file> <v1> <v2> ...
function csv_append()
{
    local file="${1:-}"
    if [ -z "${file}" ]; then
        echo "csv: missing output file" >&2
        return 1
    fi
    shift
    csv_row "$@" >>"${file}"
}

# 仅当文件不存在或为空时写入一行 (表头): csv_header <file> <v1> ...
function csv_header()
{
    local file="${1:-}"
    if [ -z "${file}" ]; then
        echo "csv: missing output file" >&2
        return 1
    fi
    shift
    if [ ! -s "${file}" ]; then
        csv_row "$@" >>"${file}"
    fi
}

# 设置分隔符 (默认逗号); 空值告警并忽略
function csv_set_delim()
{
    local d="${1:-}"
    if [ -z "${d}" ]; then
        echo "csv: delimiter cannot be empty" >&2
        return 1
    fi
    _csv_delim="${d}"
}

# 设置引号策略: minimal (默认, 仅必要时加引号) | always (全部加引号)
function csv_set_quote()
{
    case "${1:-}" in
        minimal|always)
            _csv_quote="${1}" ;;
        *)
            echo "csv: invalid quote mode '${1:-}', use minimal|always" >&2
            return 1 ;;
    esac
}
