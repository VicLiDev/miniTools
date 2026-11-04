#!/usr/bin/env bash
#########################################################################
# File Name: 05.cfg.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 04 Nov 2026 10:00:00 AM CST
#########################################################################

# usage:
#     1. source $(dirname $(readlink -f $0))/../00.libs/05.cfg.sh
#        or after run init_tools.sh
#        source ${HOME}/bin/_cfg.sh
#     2. 通用接口 (ini 路径 /section/key; json/yaml/xml 路径按各自格式):
#          cfg_get         <format> <file> <path> [--json|--yaml|--xml]
#                          [--all] [--ns p=u]
#          cfg_get_default <format> <file> <path> <default> [--json|--yaml|--xml]
#                          [--ns p=u]
#          cfg_get_all     <format> <file> <path> [--json|--yaml|--xml]
#                          [--ns p=u]
#          cfg_has         <format> <file> <path> [--ns p=u]
#          cfg_set         <format> <file> <path> <value> [--json|--yaml|--xml]
#                          [--all] [--ns p=u]
#          cfg_set_if_missing <format> <file> <path> <value> [--json|--yaml]
#          cfg_del         <format> <file> <path> [--all] [--ns p=u]
#          cfg_del_section <format> <file> <path>     (ini only)
#          cfg_sections    <format> <file>            (ini only)
#          cfg_keys        <format> <file> <path>     (ini/json/yaml)
#          cfg_entries     <format> <file> [path]     (ini only)
#          cfg_numbered    <format> <file> <path>     (ini only)
#          cfg_validate    <format> <file>
#          cfg_run         <format> <command> [args...]
#     3. ini 兼容接口 (直接转发, 直接转发):
#          ini_get / ini_get_default / ini_get_all / ini_has
#          ini_set / ini_set_if_missing / ini_del / ini_del_section
#          ini_sections / ini_keys / ini_entries / ini_numbered / ini_validate
#     4. json 兼容接口:
#          json_get / json_get_default / json_get_all / json_has
#          json_set / json_set_if_missing / json_del / json_keys / json_validate
#     5. yaml 兼容接口:
#          yaml_get / yaml_get_default / yaml_get_all / yaml_has
#          yaml_set / yaml_set_if_missing / yaml_del / yaml_keys / yaml_validate
#     6. xml 兼容接口 (XPath, --ns prefix=uri):
#          xml_get / xml_get_default / xml_get_all / xml_has
#          xml_set / xml_set_attr / xml_add / xml_del / xml_replace / xml_validate
#     7. 说明:
#          - 解析/写入由同目录的 05.cfg.py 完成, 本文件只做 Bash 转发.
#          - 退出码: 0 成功/找到, 1 未找到, 2 用法/IO/解析错误.
#          - 写文件前设置 CFG_BACKUP=1 (或 INI_BACKUP=1) 可生成 <file>.bak 备份.
#          - 也可以直接执行: 05.cfg.sh json get <file> <pointer>
#          - yaml 写入依赖 ruamel.yaml (保留注释/顺序), 缺失时报错.
#          - xml 写入依赖 lxml; 默认操作第一个匹配, --all 操作全部匹配.

_cfg_self="${BASH_SOURCE[0]}"
_cfg_self="$(readlink -f "${_cfg_self}" 2>/dev/null || printf '%s' "${_cfg_self}")"
_CFG_SH_DIR="$(dirname "${_cfg_self}")"
_CFG_PY="${_CFG_SH_DIR}/05.cfg.py"
[ -f "${_CFG_PY}" ] || _CFG_PY="${HOME}/bin/_cfg.py"

function _cfg_err()
{
    echo "cfg: $*" >&2
}

function _cfg_run()
{
    if [ ! -f "${_CFG_PY}" ]; then
        _cfg_err "helper not found: ${_CFG_PY}"
        return 2
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        _cfg_err "python3 not found"
        return 2
    fi
    python3 "${_CFG_PY}" "$@"
}

# 通用入口: cfg_run <format> <command> [args...]
function cfg_run()
{
    _cfg_run "$@"
}

# 将 /section/key 拆成 section 和 key
function _cfg_ini_path()
{
    local path="${1:-}" section key
    path="${path#/}"
    if [ -z "${path}" ] || [ "${path#*/}" = "${path}" ]; then
        _cfg_err "ini path must be /section/key: ${1:-}"
        return 2
    fi
    section="${path%%/*}"
    key="${path#*/}"
    if [ -z "${section}" ] || [ -z "${key}" ]; then
        _cfg_err "ini path must be /section/key: ${1:-}"
        return 2
    fi
    printf '%s\t%s\n' "${section}" "${key}"
}

# 将 /section 拆成 section
function _cfg_ini_section()
{
    local path="${1:-}"
    path="${path#/}"
    if [ -z "${path}" ] || [ "${path#*/}" != "${path}" ]; then
        _cfg_err "ini section path must be /section: ${1:-}"
        return 2
    fi
    printf '%s\n' "${path}"
}

function cfg_get()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini get "${file}" "${section}" "${key}" ;;
        json)
            _cfg_run json get "${file}" "${path}" "${@:4}" ;;
        yaml)
            _cfg_run yaml get "${file}" "${path}" "${@:4}" ;;
        xml)
            _cfg_run xml get "${file}" "${path}" "${@:4}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_get_default()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" def="${4:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini get-default "${file}" "${section}" "${key}" "${def}" ;;
        json)
            _cfg_run json get-default "${file}" "${path}" "${def}" "${@:5}" ;;
        yaml)
            _cfg_run yaml get-default "${file}" "${path}" "${def}" "${@:5}" ;;
        xml)
            _cfg_run xml get-default "${file}" "${path}" "${def}" "${@:5}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_get_all()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini get-all "${file}" "${section}" "${key}" ;;
        json)
            _cfg_run json get-all "${file}" "${path}" "${@:4}" ;;
        yaml)
            _cfg_run yaml get-all "${file}" "${path}" "${@:4}" ;;
        xml)
            _cfg_run xml get-all "${file}" "${path}" "${@:4}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_has()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini has "${file}" "${section}" "${key}" ;;
        json)
            _cfg_run json has "${file}" "${path}" ;;
        yaml)
            _cfg_run yaml has "${file}" "${path}" ;;
        xml)
            _cfg_run xml has "${file}" "${path}" "${@:4}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_set()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" value="${4:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini set "${file}" "${section}" "${key}" "${value}" ;;
        json)
            _cfg_run json set "${file}" "${path}" "${value}" "${@:5}" ;;
        yaml)
            _cfg_run yaml set "${file}" "${path}" "${value}" "${@:5}" ;;
        xml)
            _cfg_run xml set "${file}" "${path}" "${value}" "${@:5}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_set_if_missing()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" value="${4:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini set-if-missing "${file}" "${section}" "${key}" "${value}" ;;
        json)
            _cfg_run json set-if-missing "${file}" "${path}" "${value}" "${@:5}" ;;
        yaml)
            _cfg_run yaml set-if-missing "${file}" "${path}" "${value}" "${@:5}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_del()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" parsed section key
    case "${fmt}" in
        ini)
            parsed="$(_cfg_ini_path "${path}")" || return 2
            IFS=$'\t' read -r section key <<< "${parsed}"
            _cfg_run ini del "${file}" "${section}" "${key}" ;;
        json)
            _cfg_run json del "${file}" "${path}" ;;
        yaml)
            _cfg_run yaml del "${file}" "${path}" ;;
        xml)
            _cfg_run xml del "${file}" "${path}" "${@:4}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_del_section()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" section
    case "${fmt}" in
        ini)
            section="$(_cfg_ini_section "${path}")" || return 2
            _cfg_run ini del-section "${file}" "${section}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_sections()
{
    local fmt="${1:-}" file="${2:-}"
    case "${fmt}" in
        ini) _cfg_run ini sections "${file}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_keys()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" section
    case "${fmt}" in
        ini)
            section="$(_cfg_ini_section "${path}")" || return 2
            _cfg_run ini keys "${file}" "${section}" ;;
        json)
            if [ -n "${path}" ]; then
                _cfg_run json keys "${file}" "${path}"
            else
                _cfg_run json keys "${file}"
            fi ;;
        yaml)
            if [ -n "${path}" ]; then
                _cfg_run yaml keys "${file}" "${path}"
            else
                _cfg_run yaml keys "${file}"
            fi ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_entries()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" section
    case "${fmt}" in
        ini)
            if [ -n "${path}" ]; then
                section="$(_cfg_ini_section "${path}")" || return 2
                _cfg_run ini entries "${file}" "${section}"
            else
                _cfg_run ini entries "${file}"
            fi ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_numbered()
{
    local fmt="${1:-}" file="${2:-}" path="${3:-}" section
    case "${fmt}" in
        ini)
            section="$(_cfg_ini_section "${path}")" || return 2
            _cfg_run ini numbered "${file}" "${section}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

function cfg_validate()
{
    local fmt="${1:-}" file="${2:-}"
    case "${fmt}" in
        ini) _cfg_run ini validate "${file}" ;;
        json)
            _cfg_run json validate "${file}" ;;
        yaml)
            _cfg_run yaml validate "${file}" ;;
        xml)
            _cfg_run xml validate "${file}" ;;
        *) _cfg_err "unsupported format: ${fmt}"; return 2 ;;
    esac
}

# ---- ini compatibility wrappers --------------------------------------

function ini_get()            { _cfg_run ini get "$@"; }
function ini_get_default()    { _cfg_run ini get-default "$@"; }
function ini_get_all()        { _cfg_run ini get-all "$@"; }
function ini_has()            { _cfg_run ini has "$@"; }
function ini_set()            { _cfg_run ini set "$@"; }
function ini_set_if_missing() { _cfg_run ini set-if-missing "$@"; }
function ini_del()            { _cfg_run ini del "$@"; }
function ini_del_section()    { _cfg_run ini del-section "$@"; }
function ini_sections()       { _cfg_run ini sections "$@"; }
function ini_keys()           { _cfg_run ini keys "$@"; }
function ini_entries()        { _cfg_run ini entries "$@"; }
function ini_numbered()       { _cfg_run ini numbered "$@"; }
function ini_validate()       { _cfg_run ini validate "$@"; }

# ---- json compatibility wrappers -------------------------------------

function json_get()            { _cfg_run json get "$@"; }
function json_get_default()    { _cfg_run json get-default "$@"; }
function json_get_all()        { _cfg_run json get-all "$@"; }
function json_has()            { _cfg_run json has "$@"; }
function json_set()            { _cfg_run json set "$@"; }
function json_set_if_missing() { _cfg_run json set-if-missing "$@"; }
function json_del()            { _cfg_run json del "$@"; }
function json_keys()           { _cfg_run json keys "$@"; }
function json_validate()       { _cfg_run json validate "$@"; }

# ---- yaml compatibility wrappers -------------------------------------

function yaml_get()            { _cfg_run yaml get "$@"; }
function yaml_get_default()    { _cfg_run yaml get-default "$@"; }
function yaml_get_all()        { _cfg_run yaml get-all "$@"; }
function yaml_has()            { _cfg_run yaml has "$@"; }
function yaml_set()            { _cfg_run yaml set "$@"; }
function yaml_set_if_missing() { _cfg_run yaml set-if-missing "$@"; }
function yaml_del()            { _cfg_run yaml del "$@"; }
function yaml_keys()           { _cfg_run yaml keys "$@"; }
function yaml_validate()       { _cfg_run yaml validate "$@"; }

# ---- xml compatibility wrappers ---------------------------------------

function xml_get()         { _cfg_run xml get "$@"; }
function xml_get_default() { _cfg_run xml get-default "$@"; }
function xml_get_all()     { _cfg_run xml get-all "$@"; }
function xml_has()         { _cfg_run xml has "$@"; }
function xml_set()         { _cfg_run xml set "$@"; }
function xml_set_attr()    { _cfg_run xml set-attr "$@"; }
function xml_add()         { _cfg_run xml add "$@"; }
function xml_del()         { _cfg_run xml del "$@"; }
function xml_replace()     { _cfg_run xml replace "$@"; }
function xml_validate()    { _cfg_run xml validate "$@"; }


if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cfg_run "$@"
    exit $?
fi
