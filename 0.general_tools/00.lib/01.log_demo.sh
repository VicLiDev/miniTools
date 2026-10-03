#!/usr/bin/env bash
#########################################################################
# File Name: 01.log_demo.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 30 Sep 2026 06:10:00 PM CST
#########################################################################

# 01.log.sh 功能验证 demo
#   bash 0.general_tools/00.lib/01.log_demo.sh
# 每个场景在独立子 shell 中运行, 分别捕获 stdout / stderr / 日志文件, 再断言内容.

script_dir=$(dirname "$(readlink -f "$0")")
source "${script_dir}/01.log.sh"

# 控制台配色: 复用库解析出的颜色; 非终端时为空, 重定向输出不会混入 ANSI
log_refresh
c_ok="${_log_green}"; c_bad="${_log_red}"; c_ttl="${_log_cyan}"; c_off="${_log_nc}"

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

esc=$'\033'
n_pass=0
n_fail=0

chk()
{
    local _desc="$1"
    shift
    if "$@"; then
        echo "    ${c_ok}PASS${c_off}  ${_desc}"
        n_pass=$((n_pass + 1))
    else
        echo "    ${c_bad}FAIL${c_off}  ${_desc}"
        n_fail=$((n_fail + 1))
    fi
}

has()    { grep -qF -- "$2" "$1"; }
hasnt()  { ! grep -qF -- "$2" "$1"; }
has_re() { grep -qE -- "$2" "$1"; }
has_esc(){ grep -q -- "${esc}" "$1"; }

LOGFILE=""

run_case()
{
    local _name="$1"
    local _fn="$2"
    local _dir="${work_dir}/${_name}"

    echo "${c_ttl}==> ${_name}${c_off}"
    mkdir -p "${_dir}"
    LOGFILE="${_dir}/run.log"
    ( "${_fn}" ) >"${_dir}/out" 2>"${_dir}/err" || true
    out="${_dir}/out"
    err="${_dir}/err"
    log="${_dir}/run.log"
}

# ---------------------------------------------------------------------------
#  场景
# ---------------------------------------------------------------------------

case_default()
{
    log_setup "${LOGFILE}"
    log "info-msg"
    log_dbg "dbg-msg"
    log_warn "warn-msg"
    log_fail "fail-msg"
    log_pass "pass-msg"
}

case_verbose()
{
    log_setup "${LOGFILE}" 0 1
    log "info-msg"
    log_dbg "dbg-msg"
}

case_quiet()
{
    log_setup "${LOGFILE}" 1
    log "info-msg"
    log_pass "pass-msg"
    log_warn "warn-msg"
    log_fail "fail-msg"
}

case_level()
{
    log_setup "${LOGFILE}"
    log_set_level error
    log "info-msg"
    log_warn "warn-msg"
    log_fail "fail-msg"
}

case_ts_tag()
{
    log_setup "${LOGFILE}"
    log_set_tag "DEMO"
    log_set_ts "+%Y"
    log "ts-msg"
}

case_color_on()
{
    log_setup "${LOGFILE}"
    log_set_color on
    log "info-msg"
    log_pass "pass-msg"
}

case_color_auto_pipe()
{
    log_setup "${LOGFILE}"
    log_pass "pass-msg"
}

case_route()
{
    log_setup "${LOGFILE}"
    log_out "out-msg"
    log "err-msg"
    log_fonly "file-msg"
}

case_struct()
{
    log_setup "${LOGFILE}"
    log_title "TITLE"
    log_kv "key" "val" 8
    log_step 2 5 "doing"
    log_sep "-" 10
}

case_summary()
{
    log_setup "${LOGFILE}" 1
    log "info-msg"
    log_summary "SUMMARY-msg"
}

# ---------------------------------------------------------------------------
#  断言
# ---------------------------------------------------------------------------

run_case "default(INFO 级别)" case_default
chk "info 上控制台"            has   "${err}" "info-msg"
chk "dbg 被抑制"               hasnt "${err}" "dbg-msg"
chk "warn/fail/pass 上控制台"  has   "${err}" "warn-msg"
chk "文件含 info"              has   "${log}" "info-msg"
chk "文件含 dbg (全量)"        has   "${log}" "dbg-msg"
chk "非 TTY 自动无色"          hasnt "${err}" "${esc}"

run_case "verbose(DEBUG)" case_verbose
chk "dbg 上控制台"             has "${err}" "dbg-msg"
chk "文件含 dbg"               has "${log}" "dbg-msg"

run_case "quiet(仅 WARN/ERROR)" case_quiet
chk "info 被抑制"              hasnt "${err}" "info-msg"
chk "pass 被抑制"              hasnt "${err}" "pass-msg"
chk "warn 保留"                has   "${err}" "warn-msg"
chk "fail 保留"                has   "${err}" "fail-msg"
chk "quiet 下文件仍含 info"    has   "${log}" "info-msg"

run_case "level=error" case_level
chk "info 被抑制"              hasnt "${err}" "info-msg"
chk "warn 被抑制"              hasnt "${err}" "warn-msg"
chk "fail 保留"                has   "${err}" "fail-msg"

run_case "时间戳 + 标签" case_ts_tag
chk "标签前缀"                 has_re "${err}" '^\[20[0-9][0-9]\] \[DEMO\] ts-msg'

run_case "color=on 强制上色" case_color_on
chk "控制台含 ANSI"            has_esc "${err}"
chk "文件无色(颜色仅控制台)"   hasnt "${log}" "${esc}"

run_case "color=auto 重定向无色" case_color_auto_pipe
chk "控制台无色"               hasnt "${err}" "${esc}"

run_case "输出路由" case_route
chk "log_out -> stdout"        has   "${out}" "out-msg"
chk "log -> stderr"            has   "${err}" "err-msg"
chk "log_out 不走 stderr"      hasnt "${err}" "out-msg"
chk "log_fonly 不上控制台"     hasnt "${err}" "file-msg"
chk "log_fonly 写文件"         has   "${log}" "file-msg"

run_case "结构辅助" case_struct
chk "title"                    has "${err}" "TITLE"
chk "kv 对齐"                  has_re "${err}" 'key[[:space:]]+: val'
chk "step 前缀"                has "${err}" "[2/5] doing"
chk "sep 自定义字符"           has "${err}" "----------"

run_case "summary 不受 quiet 影响" case_summary
chk "info 被抑制"              hasnt "${err}" "info-msg"
chk "summary 上 stdout"        has "${out}" "SUMMARY-msg"
chk "summary 写文件"           has "${log}" "SUMMARY-msg"

# ---------------------------------------------------------------------------

echo
if [ "${n_fail}" -eq 0 ]; then
    echo "${c_ok}结果: ${n_pass} passed, ${n_fail} failed${c_off}"
else
    echo "${c_bad}结果: ${n_pass} passed, ${n_fail} failed${c_off}"
fi
[ "${n_fail}" -eq 0 ]
