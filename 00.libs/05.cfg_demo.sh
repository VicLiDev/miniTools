#!/usr/bin/env bash
#########################################################################
# File Name: 05.cfg_demo.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 04 Nov 2026 10:00:00 AM CST
#########################################################################

# INI/JSON/YAML/XML self-test for 05.cfg.py / 05.cfg.sh.
# Run: bash 00.libs/05.cfg_demo.sh
#
# 文件按格式分区, 每个分区再按功能拆成独立函数:
#   json_setup / json_test_read / json_test_write / json_test_edge / json_test_cli
#   yaml_*  xml_*  ini_*
# 每个 run_<format> 按顺序调用本格式的函数; main 负责汇总执行.

script_dir=$(dirname "$(readlink -f "$0")")
source "${script_dir}/05.cfg.sh"

cfg_py="${script_dir}/05.cfg.py"
cfg_sh="${script_dir}/05.cfg.sh"

red=$'\033[1;31m'
green=$'\033[1;32m'
cyan=$'\033[1;36m'
nc=$'\033[0m'

pass=0
fail=0

# ---- common helpers ------------------------------------------------------
chk()
{
    local desc="$1" expected="$2" actual="$3"
    if [ "${actual}" = "${expected}" ]; then
        pass=$((pass + 1))
        printf '    %sPASS%s  %s\n' "${green}" "${nc}" "${desc}"
    else
        fail=$((fail + 1))
        printf '    %sFAIL%s  %s\n' "${red}" "${nc}" "${desc}"
        printf '          expected: [%s]\n' "${expected}"
        printf '          actual  : [%s]\n' "${actual}"
    fi
}

chk_rc()
{
    local desc="$1" expected="$2" actual="$3"
    chk "${desc}" "${expected}" "${actual}"
}

# 执行一条命令, 按退出状态判定通过/失败 (用于 ini 测试).
chk_cmd()
{
    local desc="$1"
    shift
    if "$@"; then
        pass=$((pass + 1))
        printf '    %sPASS%s  %s\n' "${green}" "${nc}" "${desc}"
    else
        fail=$((fail + 1))
        printf '    %sFAIL%s  %s\n' "${red}" "${nc}" "${desc}"
    fi
}

banner()
{
    printf '%s==> %s%s\n' "${cyan}" "$1" "${nc}"
}

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

# ---- JSON ----------------------------------------------------------------
json_setup()
{
    banner "setup"
    json_file="${tmp}/t.json"
    cat > "${json_file}" <<'EOF'
{
  "server": {
    "host": "localhost",
    "port": 8080,
    "tags": ["a", "b"]
  },
  "debug": true,
  "empty": null
}
EOF
}

json_test_read()
{
    banner "read"
    chk "get string"  "localhost" "$(python3 "${cfg_py}" json get "${json_file}" /server/host)"
    chk "get int"     "8080"      "$(python3 "${cfg_py}" json get "${json_file}" /server/port)"
    chk "get bool"    "true"      "$(python3 "${cfg_py}" json get "${json_file}" /debug)"
    chk "get null"    "null"      "$(python3 "${cfg_py}" json get "${json_file}" /empty)"
    chk "get array"   "b"         "$(python3 "${cfg_py}" json get "${json_file}" /server/tags/1)"
    chk "get array --json" '["a","b"]' \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/tags --json)"
    chk "get object --json" '{"host":"localhost","port":8080,"tags":["a","b"]}' \
        "$(python3 "${cfg_py}" json get "${json_file}" /server --json)"

    python3 "${cfg_py}" json get "${json_file}" /nope >/dev/null 2>&1
    chk_rc "missing key rc" 1 "$?"
    chk "get-default" "fallback" \
        "$(python3 "${cfg_py}" json get-default "${json_file}" /nope fallback)"
    chk "get-all" "localhost" \
        "$(python3 "${cfg_py}" json get-all "${json_file}" /server/host)"
    chk "keys" $'host\nport\ntags' \
        "$(python3 "${cfg_py}" json keys "${json_file}" /server)"

    python3 "${cfg_py}" json has "${json_file}" /server/host
    chk_rc "has true" 0 "$?"
    python3 "${cfg_py}" json has "${json_file}" /nope
    chk_rc "has false" 1 "$?"
}

json_test_write()
{
    banner "write"
    python3 "${cfg_py}" json set "${json_file}" /server/port 9090
    chk "set existing" "9090" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/port)"

    python3 "${cfg_py}" json set "${json_file}" /server/port 9091 --json
    chk "set typed" "9091" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/port)"

    python3 "${cfg_py}" json set "${json_file}" /new/0/name test
    chk "set creates array path" "test" \
        "$(python3 "${cfg_py}" json get "${json_file}" /new/0/name)"

    python3 "${cfg_py}" json set-if-missing "${json_file}" /server/host other
    chk "set-if-missing noop" "localhost" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/host)"

    python3 "${cfg_py}" json set-if-missing "${json_file}" /server/newkey v
    chk "set-if-missing add" "v" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/newkey)"

    python3 "${cfg_py}" json del "${json_file}" /server/tags/0
    chk "del array item" "b" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/tags/0)"

    python3 "${cfg_py}" json del "${json_file}" /nope >/dev/null 2>&1
    chk_rc "del missing rc" 1 "$?"
}

json_test_edge()
{
    banner "validate / backup / paths"

    local dup_file="${tmp}/dup.json"
    local out
    printf '{"a": 1, "a": 2}\n' > "${dup_file}"
    out=$(python3 "${cfg_py}" json validate "${dup_file}" 2>&1)
    chk_rc "validate duplicate rc" 0 "$?"
    case "${out}" in
        *"duplicate key: a"*) chk "validate duplicate warning" "yes" "yes" ;;
        *) chk "validate duplicate warning" "yes" "no" ;;
    esac

    CFG_BACKUP=1 python3 "${cfg_py}" json set "${json_file}" /server/host backup
    chk "backup file" "yes" "$([ -f "${json_file}.bak" ] && echo yes || echo no)"
    chk "backup old value" "localhost" \
        "$(python3 "${cfg_py}" json get "${json_file}.bak" /server/host)"

    local space_dir="${tmp}/dir with space"
    local space_file="${space_dir}/a b.json"
    mkdir "${space_dir}"
    printf '{"x": 1}\n' > "${space_file}"
    python3 "${cfg_py}" json set "${space_file}" /x 2
    chk "path with spaces" "2" \
        "$(python3 "${cfg_py}" json get "${space_file}" /x)"

    local link_file="${tmp}/link.json"
    ln -s "${json_file}" "${link_file}"
    python3 "${cfg_py}" json set "${link_file}" /server/host linked
    chk "symlink remains" "yes" "$([ -L "${link_file}" ] && echo yes || echo no)"
    chk "symlink target updated" "linked" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/host)"
}

json_test_cli()
{
    banner "CLI / bash API"
    chk "python CLI" "linked" \
        "$(python3 "${cfg_py}" json get "${json_file}" /server/host)"
    chk "bash CLI" "linked" \
        "$(bash "${cfg_sh}" json get "${json_file}" /server/host)"
    chk "cfg_get" "linked" \
        "$(cfg_get json "${json_file}" /server/host)"
    chk "json_get" "linked" \
        "$(json_get "${json_file}" /server/host)"
    chk "cfg_get --json" '["b"]' \
        "$(cfg_get json "${json_file}" /server/tags --json)"
    cfg_set json "${json_file}" /server/port 7777 --json
    chk "cfg_set --json" "7777" \
        "$(cfg_get json "${json_file}" /server/port)"
}

run_json()
{
    banner "JSON"
    json_setup
    json_test_read
    json_test_write
    json_test_edge
    json_test_cli
}

# ---- YAML ----------------------------------------------------------------
yaml_setup()
{
    banner "yaml setup / read"
    yaml_file="${tmp}/t.yaml"
    cat > "${yaml_file}" <<'EOF'
# top comment
server:
  host: localhost   # inline comment
  port: 8080
  tags:
    - a
    - b
debug: true
empty: null
EOF
}

yaml_test_read()
{
    chk "yaml get string" "localhost" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/host)"
    chk "yaml get int" "8080" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/port)"
    chk "yaml get bool" "true" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /debug)"
    chk "yaml get null" "null" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /empty)"
    chk "yaml get array item" "b" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/tags/1)"
    chk "yaml get array --json" '["a","b"]' \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/tags --json)"
    chk "yaml get object --json" '{"host":"localhost","port":8080,"tags":["a","b"]}' \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server --json)"
    chk "yaml get scalar --yaml" "localhost" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/host --yaml)"

    python3 "${cfg_py}" yaml get "${yaml_file}" /nope >/dev/null 2>&1
    chk_rc "yaml missing key rc" 1 "$?"
    chk "yaml get-default" "fallback" \
        "$(python3 "${cfg_py}" yaml get-default "${yaml_file}" /nope fallback)"
    chk "yaml get-all" "localhost" \
        "$(python3 "${cfg_py}" yaml get-all "${yaml_file}" /server/host)"
    chk "yaml keys" $'host\nport\ntags' \
        "$(python3 "${cfg_py}" yaml keys "${yaml_file}" /server)"

    python3 "${cfg_py}" yaml has "${yaml_file}" /server/host
    chk_rc "yaml has true" 0 "$?"
    python3 "${cfg_py}" yaml has "${yaml_file}" /nope
    chk_rc "yaml has false" 1 "$?"
}

yaml_test_write()
{
    banner "yaml write"

    local order
    python3 "${cfg_py}" yaml set "${yaml_file}" /server/port 9090
    chk "yaml set existing" "9090" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/port)"
    chk "yaml top comment preserved" "yes" \
        "$(grep -qF '# top comment' "${yaml_file}" && echo yes || echo no)"
    chk "yaml inline comment preserved" "yes" \
        "$(grep -qF '# inline comment' "${yaml_file}" && echo yes || echo no)"
    order=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*:' "${yaml_file}" \
        | head -3 | cut -d: -f1 | paste -sd, -)
    chk "yaml key order preserved" "server,debug,empty" "${order}"

    python3 "${cfg_py}" yaml set "${yaml_file}" /server/port 9091 --json
    chk "yaml set typed --json" "9091" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/port)"

    python3 "${cfg_py}" yaml set "${yaml_file}" /new/0/name test
    chk "yaml set creates array path" "test" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /new/0/name)"

    python3 "${cfg_py}" yaml set "${yaml_file}" /typed '{"a": [1, 2]}' --yaml
    chk "yaml set typed --yaml nested" "2" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /typed/a/1)"
    python3 "${cfg_py}" yaml set "${yaml_file}" /typed_flag 123 --yaml
    chk "yaml set typed --yaml int" "123" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /typed_flag)"

    python3 "${cfg_py}" yaml set-if-missing "${yaml_file}" /server/host other
    chk "yaml set-if-missing noop" "localhost" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/host)"
    python3 "${cfg_py}" yaml set-if-missing "${yaml_file}" /server/newkey v
    chk "yaml set-if-missing add" "v" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/newkey)"

    python3 "${cfg_py}" yaml del "${yaml_file}" /server/tags/0
    chk "yaml del array item" "b" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/tags/0)"

    python3 "${cfg_py}" yaml del "${yaml_file}" /nope >/dev/null 2>&1
    chk_rc "yaml del missing rc" 1 "$?"
}

yaml_test_edge()
{
    banner "yaml validate / backup / paths"

    python3 "${cfg_py}" yaml validate "${yaml_file}"
    chk_rc "yaml validate rc" 0 "$?"

    CFG_BACKUP=1 python3 "${cfg_py}" yaml set "${yaml_file}" /server/host backup
    chk "yaml backup file" "yes" \
        "$([ -f "${yaml_file}.bak" ] && echo yes || echo no)"
    chk "yaml backup old value" "localhost" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}.bak" /server/host)"

    local space_dir="${tmp}/yaml dir with space"
    local space_file="${space_dir}/a b.yaml"
    mkdir "${space_dir}"
    printf 'x: 1\n' > "${space_file}"
    python3 "${cfg_py}" yaml set "${space_file}" /x 2
    chk "yaml path with spaces" "2" \
        "$(python3 "${cfg_py}" yaml get "${space_file}" /x)"

    local link_file="${tmp}/link.yaml"
    ln -s "${yaml_file}" "${link_file}"
    python3 "${cfg_py}" yaml set "${link_file}" /server/host linked
    chk "yaml symlink remains" "yes" \
        "$([ -L "${link_file}" ] && echo yes || echo no)"
    chk "yaml symlink target updated" "linked" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/host)"
}

yaml_test_cli()
{
    banner "yaml CLI / bash API"
    chk "yaml python CLI" "linked" \
        "$(python3 "${cfg_py}" yaml get "${yaml_file}" /server/host)"
    chk "yaml bash CLI" "linked" \
        "$(bash "${cfg_sh}" yaml get "${yaml_file}" /server/host)"
    chk "yaml cfg_get" "linked" \
        "$(cfg_get yaml "${yaml_file}" /server/host)"
    chk "yaml_get" "linked" \
        "$(yaml_get "${yaml_file}" /server/host)"
    chk "yaml cfg_get --json" '["b"]' \
        "$(cfg_get yaml "${yaml_file}" /server/tags --json)"
    cfg_set yaml "${yaml_file}" /server/port 7777 --json
    chk "yaml cfg_set --json" "7777" \
        "$(cfg_get yaml "${yaml_file}" /server/port)"
}

run_yaml()
{
    banner "YAML"
    yaml_setup
    yaml_test_read
    yaml_test_write
    yaml_test_edge
    yaml_test_cli
}

# ---- XML -----------------------------------------------------------------
xml_setup()
{
    banner "xml setup / read"
    xml_file="${tmp}/t.xml"
    cat > "${xml_file}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!-- top comment -->
<config>
  <!-- server comment -->
  <server host="localhost" port="8080">
    <name>web</name>
    <tags>
      <tag>a</tag>
      <tag>b</tag>
    </tags>
    <script><![CDATA[if (a < b) x++;]]></script>
  </server>
  <debug enabled="true">yes</debug>
</config>
EOF
}

xml_test_read()
{
    chk "xml get text" "web" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/name)"
    chk "xml get attribute" "localhost" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/@host)"
    local xml_server xml_server_marker
    xml_server=$(python3 "${cfg_py}" xml get "${xml_file}" /config --xml)
    xml_server_marker='<server host="localhost" port="8080">'
    if printf '%s\n' "${xml_server}" | grep -qF '<!-- server comment -->' \
        && printf '%s\n' "${xml_server}" | grep -qF "${xml_server_marker}"; then
        chk "xml get --xml" "yes" "yes"
    else
        chk "xml get --xml" "yes" "no"
    fi

    python3 "${cfg_py}" xml get "${xml_file}" /nope >/dev/null 2>&1
    chk_rc "xml missing xpath rc" 1 "$?"
    chk "xml get-default" "fallback" \
        "$(python3 "${cfg_py}" xml get-default "${xml_file}" /nope fallback)"
    chk "xml get-all" $'a\nb' \
        "$(python3 "${cfg_py}" xml get-all "${xml_file}" //tag)"

    local xml_has_yes xml_has_no
    python3 "${cfg_py}" xml has "${xml_file}" /config/server
    xml_has_yes=$?
    python3 "${cfg_py}" xml has "${xml_file}" /nope
    xml_has_no=$?
    chk "xml has 0/1" "0/1" "${xml_has_yes}/${xml_has_no}"
}

xml_test_write()
{
    banner "xml write"
    python3 "${cfg_py}" xml set "${xml_file}" /config/server/name newname
    chk "xml set text" "newname" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/name)"

    python3 "${cfg_py}" xml set "${xml_file}" /config/server/name '<b>bold</b>' --xml
    chk "xml set --xml children" "bold" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/name/b)"

    python3 "${cfg_py}" xml set-attr "${xml_file}" /config/server host example.com
    python3 "${cfg_py}" xml set-attr "${xml_file}" /config/server data-x 7
    local xml_host xml_data
    xml_host=$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/@host)
    xml_data=$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/@data-x)
    chk "xml set-attr" "example.com/7" "${xml_host}/${xml_data}"

    python3 "${cfg_py}" xml add "${xml_file}" /config/server newtag --text hello
    chk "xml add text" "hello" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/newtag)"

    python3 "${cfg_py}" xml add "${xml_file}" /config/server attrnode --attr id=7
    chk "xml add attr" "7" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/attrnode/@id)"

    python3 "${cfg_py}" xml add "${xml_file}" /config/server first --text one --index 0
    chk "xml add index" "one" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" '/config/server/*[1]')"

    python3 "${cfg_py}" xml set "${xml_file}" //tag x --all
    chk "xml set --all" $'x\nx' \
        "$(python3 "${cfg_py}" xml get-all "${xml_file}" //tag)"

    python3 "${cfg_py}" xml del "${xml_file}" /config/server/tags/tag
    chk "xml del" "x" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/server/tags/tag)"

    python3 "${cfg_py}" xml del "${xml_file}" /config/server/tags/tag --all
    python3 "${cfg_py}" xml has "${xml_file}" /config/server/tags/tag
    chk_rc "xml del --all" 1 "$?"

    printf '<r><a>1</a>TAIL<b>2</b></r>\n' > "${tmp}/tail.xml"
    python3 "${cfg_py}" xml replace "${tmp}/tail.xml" /r/a '<x/>'
    chk "xml replace preserves tail" "<r><x/>TAIL<b>2</b></r>" \
        "$(cat "${tmp}/tail.xml")"
}

xml_test_preserve()
{
    banner "xml preserve"
    chk "xml comment preserved" "yes" \
        "$(grep -qF '<!-- server comment -->' "${xml_file}" && echo yes || echo no)"
    chk "xml whitespace preserved" "yes" \
        "$(grep -q '^  <server ' "${xml_file}" && echo yes || echo no)"
    chk "xml declaration preserved" "yes" \
        "$(head -1 "${xml_file}" | grep -q '<?xml' && echo yes || echo no)"
    chk "xml cdata preserved" "yes" \
        "$(grep -qF '<![CDATA[if (a < b) x++;]]>' "${xml_file}" && echo yes || echo no)"
}

xml_test_namespaces()
{
    banner "xml namespaces"
    local ns_file="${tmp}/ns.xml"
    cat > "${ns_file}" <<'EOF'
<?xml version="1.0"?>
<root xmlns="urn:demo" xmlns:x="urn:x">
  <item id="1">one</item>
  <x:item id="2">two</x:item>
</root>
EOF
    chk "xml namespace default" "one" \
        "$(python3 "${cfg_py}" xml get "${ns_file}" '//d:item' --ns d=urn:demo)"
    chk "xml namespace prefix" "two" \
        "$(python3 "${cfg_py}" xml get "${ns_file}" '//x:item' --ns x=urn:x)"
    python3 "${cfg_py}" xml add "${ns_file}" /d:root y:new --text hi \
        --ns d=urn:demo --ns y=urn:y
    chk "xml namespace add" "hi" \
        "$(python3 "${cfg_py}" xml get "${ns_file}" '//y:new' --ns y=urn:y)"
}

xml_test_edge()
{
    banner "xml validate / backup / paths"

    printf '<r><a></r>\n' > "${tmp}/bad.xml"
    python3 "${cfg_py}" xml get "${tmp}/bad.xml" /r >/dev/null 2>&1
    chk_rc "xml invalid rc" 2 "$?"
    python3 "${cfg_py}" xml validate "${xml_file}"
    chk_rc "xml validate rc" 0 "$?"

    local xml_val_out xml_val_rc
    xml_val_out=$(python3 "${cfg_py}" xml validate "${tmp}/bad.xml" 2>&1)
    xml_val_rc=$?
    if [ "${xml_val_rc}" -eq 1 ] \
        && printf '%s\n' "${xml_val_out}" | grep -q 'error:'; then
        chk "xml validate invalid rc/stderr" "yes" "yes"
    else
        chk "xml validate invalid rc/stderr" "yes" "no"
    fi

    CFG_BACKUP=1 python3 "${cfg_py}" xml set "${xml_file}" /config/debug backup
    local xml_bak_val=""
    if [ -f "${xml_file}.bak" ]; then
        xml_bak_val=$(python3 "${cfg_py}" xml get "${xml_file}.bak" /config/debug)
    fi
    if [ -f "${xml_file}.bak" ] && [ "${xml_bak_val}" = "yes" ]; then
        chk "xml backup" "yes" "yes"
    else
        chk "xml backup" "yes" "no"
    fi

    local link_file="${tmp}/link.xml"
    ln -s "${xml_file}" "${link_file}"
    python3 "${cfg_py}" xml set "${link_file}" /config/debug linked
    local xml_link_val
    xml_link_val=$(python3 "${cfg_py}" xml get "${xml_file}" /config/debug)
    if [ -L "${link_file}" ] && [ "${xml_link_val}" = "linked" ]; then
        chk "xml symlink" "yes" "yes"
    else
        chk "xml symlink" "yes" "no"
    fi

    local space_dir="${tmp}/xml dir with space"
    local space_file="${space_dir}/a b.xml"
    mkdir "${space_dir}"
    printf '<?xml version="1.0"?><r><x>1</x></r>\n' > "${space_file}"
    python3 "${cfg_py}" xml set "${space_file}" /r/x 2
    chk "xml path with spaces" "2" \
        "$(python3 "${cfg_py}" xml get "${space_file}" /r/x)"
}

xml_test_cli()
{
    banner "xml CLI / bash API"
    chk "xml python CLI" "linked" \
        "$(python3 "${cfg_py}" xml get "${xml_file}" /config/debug)"
    chk "xml bash CLI" "linked" \
        "$(bash "${cfg_sh}" xml get "${xml_file}" /config/debug)"
    chk "xml cfg_get" "linked" \
        "$(cfg_get xml "${xml_file}" /config/debug)"
    chk "xml_get" "linked" \
        "$(xml_get "${xml_file}" /config/debug)"
    cfg_set xml "${xml_file}" /config/debug 7777
    chk "xml cfg_set" "7777" \
        "$(cfg_get xml "${xml_file}" /config/debug)"
}

run_xml()
{
    banner "XML"
    xml_setup
    xml_test_read
    xml_test_write
    xml_test_preserve
    xml_test_namespaces
    xml_test_edge
    xml_test_cli
}

# ---- INI -----------------------------------------------------------------
ini_eq()      { [ "$1" = "$2" ]; }
ini_not()     { ! "$@"; }
ini_rc_of()   { "$@" >/dev/null 2>&1; echo $?; }
ini_out_has() { local needle="$1"; shift; "$@" | grep -qxF -- "${needle}"; }

ini_setup()
{
    ini_dir="${tmp}/ini"
    mkdir -p "${ini_dir}"
    ini_file="${ini_dir}/base.ini"
    cat > "${ini_file}" <<'EOF'
# top comment
[platform]
name = 3588_android
arch = arm64
empty =
dup = first
dup = last

[toolchain]
path = /opt/a|/opt/b
env = A=1|B=2

[config_patch]
10 = tenth
2 = second
1 = first
EOF
}

ini_test_read()
{
    banner "read"
    chk_cmd "get existing" ini_eq "$(ini_get "${ini_file}" platform name)" "3588_android"
    chk_cmd "get empty value rc=0" [ "$(ini_rc_of ini_get "${ini_file}" platform empty)" -eq 0 ]
    chk_cmd "get empty value" ini_eq "$(ini_get "${ini_file}" platform empty)" ""
    chk_cmd "get missing rc=1" [ "$(ini_rc_of ini_get "${ini_file}" platform missing)" -eq 1 ]
    chk_cmd "get missing empty" ini_eq "$(ini_get "${ini_file}" platform missing 2>/dev/null)" ""
    chk_cmd "get-default missing" ini_eq "$(ini_get_default "${ini_file}" platform missing fallback)" "fallback"
    chk_cmd "get-default existing" ini_eq "$(ini_get_default "${ini_file}" platform name fallback)" "3588_android"
    chk_cmd "get-all duplicates" ini_eq "$(ini_get_all "${ini_file}" platform dup)" $'first\nlast'
    chk_cmd "has existing" ini_has "${ini_file}" platform name
    chk_cmd "has missing" ini_not ini_has "${ini_file}" platform missing
    chk_cmd "sections" ini_out_has toolchain ini_sections "${ini_file}"
    chk_cmd "keys" ini_out_has arch ini_keys "${ini_file}" platform
    chk_cmd "entries" ini_out_has $'platform\tname\t3588_android' ini_entries "${ini_file}" platform
    chk_cmd "numbered sort" ini_eq "$(ini_numbered "${ini_file}" config_patch)" $'1\tfirst\n2\tsecond\n10\ttenth'
    chk_cmd "validate" ini_validate "${ini_file}"
}

ini_test_write()
{
    banner "write"
    ini_set "${ini_file}" platform name 3588_linux
    chk_cmd "set existing" ini_eq "$(ini_get "${ini_file}" platform name)" "3588_linux"
    chk_cmd "comment preserved" grep -qF "# top comment" "${ini_file}"

    ini_set "${ini_file}" platform board evb1
    chk_cmd "set new key" ini_eq "$(ini_get "${ini_file}" platform board)" "evb1"

    ini_set "${ini_file}" extra foo bar
    chk_cmd "set new section" ini_eq "$(ini_get "${ini_file}" extra foo)" "bar"
    chk_cmd "sections after add" ini_out_has extra ini_sections "${ini_file}"

    ini_set_if_missing "${ini_file}" platform arch riscv
    chk_cmd "set-if-missing keeps existing" ini_eq "$(ini_get "${ini_file}" platform arch)" "arm64"
    ini_set_if_missing "${ini_file}" platform newkey newval
    chk_cmd "set-if-missing adds" ini_eq "$(ini_get "${ini_file}" platform newkey)" "newval"

    local special='a # b = c | d'
    ini_set "${ini_file}" platform special "${special}"
    chk_cmd "special value round-trip" ini_eq "$(ini_get "${ini_file}" platform special)" "${special}"
    ini_set "${ini_file}" platform blank ""
    chk_cmd "empty value round-trip" ini_eq "$(ini_get "${ini_file}" platform blank)" ""

    local new_file="${ini_dir}/new.ini"
    ini_set "${new_file}" sec key val
    chk_cmd "new file created" [ -f "${new_file}" ]
    chk_cmd "new file value" ini_eq "$(ini_get "${new_file}" sec key)" "val"

    ini_del "${ini_file}" platform board
    chk_cmd "del key" ini_not ini_has "${ini_file}" platform board
    chk_cmd "del missing rc=1" [ "$(ini_rc_of ini_del "${ini_file}" platform missing)" -eq 1 ]
    ini_del_section "${ini_file}" extra
    chk_cmd "del section" ini_not ini_has "${ini_file}" extra foo
    chk_cmd "section removed" ini_not ini_out_has extra ini_sections "${ini_file}"
}

ini_test_edge()
{
    banner "backup / edge"

    local backup_file="${ini_dir}/backup.ini"
    ini_set "${backup_file}" sec key old
    export INI_BACKUP=1
    ini_set "${backup_file}" sec key new
    unset INI_BACKUP
    chk_cmd "backup exists" [ -f "${backup_file}.bak" ]
    chk_cmd "backup content" grep -qF "key = old" "${backup_file}.bak"
    chk_cmd "backup current" ini_eq "$(ini_get "${backup_file}" sec key)" "new"

    local spaced_dir="${ini_dir}/dir with spaces"
    local spaced_file="${spaced_dir}/a.ini"
    mkdir -p "${spaced_dir}"
    ini_set "${spaced_file}" sec key "value with spaces"
    chk_cmd "path with spaces" ini_eq "$(ini_get "${spaced_file}" sec key)" "value with spaces"

    local link_file="${ini_dir}/link.ini"
    ln -s "${ini_file}" "${link_file}"
    ini_set "${link_file}" platform arch arm
    chk_cmd "symlink preserved" [ -L "${link_file}" ]
    chk_cmd "symlink writes target" ini_eq "$(ini_get "${ini_file}" platform arch)" "arm"

    printf '[platform]\r\nname = crlf\r\n' > "${ini_dir}/crlf.ini"
    chk_cmd "CRLF read" ini_eq "$(ini_get "${ini_dir}/crlf.ini" platform name)" "crlf"
    printf '\357\273\277[platform]\nname = bom\n' > "${ini_dir}/bom.ini"
    chk_cmd "BOM read" ini_eq "$(ini_get "${ini_dir}/bom.ini" platform name)" "bom"
    chk_cmd "reject newline value" [ "$(ini_rc_of ini_set "${ini_file}" platform name $'a\nb')" -eq 2 ]
}

ini_test_cli()
{
    banner "CLI"
    local cli_file="${ini_dir}/cli.ini"
    ini_set "${cli_file}" sec key cli
    chk_cmd "python CLI" ini_eq "$(python3 "${cfg_py}" ini get "${cli_file}" sec key)" "cli"
    chk_cmd "bash wrapper CLI" ini_eq "$(bash "${cfg_sh}" ini get "${cli_file}" sec key)" "cli"
}

run_ini()
{
    banner "INI"
    ini_setup
    ini_test_read
    ini_test_write
    ini_test_edge
    ini_test_cli
}

# ---- main ----------------------------------------------------------------
summary()
{
    printf '\n%s结果: %s passed, %s failed%s\n' \
        "${cyan}" "${pass}" "${fail}" "${nc}"
    [ "${fail}" -eq 0 ]
}

main()
{
    run_json
    run_yaml
    run_xml
    run_ini
    summary
}

main
