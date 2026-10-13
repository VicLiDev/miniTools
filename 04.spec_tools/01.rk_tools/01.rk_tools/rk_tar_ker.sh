#!/usr/bin/env bash
#########################################################################
# File Name: rk_tar_ker.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 20 May 2026 10:57:15 AM CST
#########################################################################

# include/linux/rockchip/cpu.h
# drivers/soc/rockchip/rockchip-cpuinfo.c
# include/soc/rockchip/rockchip_opp_select.h
# drivers/soc/rockchip/rockchip_opp_select.c
# include/soc/rockchip/rockchip_iommu.h
# drivers/iommu/rockchip-iommu.c
# drivers/iommu/rk-iommu.c

source ${HOME}/bin/_select_node.sh
source ${HOME}/bin/_dir_file_opt.sh

sel_tag_tar_ker="rk_tar_ker: "

# src -- from kernel
ker_dir_lst=(
    ${HOME}/Projects/kernel
    ${HOME}/Projects/kernel2
    ${HOME}/Projects/kernel3
    )
src_ker=""
src_mpp=""

# target -- current build kernel
target_ker=""
target_mpp=""

# backup/resume dir
pkg_dir=""
pkg_f_dir=""
pkg_mpp_dir=""
pkg_resume_f=""
tar_file_lst_name="rk_tar_file_list.txt"


function usage()
{
    echo "Usage: $0 <mode> [kernel_dir]"
    echo ""
    echo "Modes:"
    echo "  from [kernel_dir]  Copy files+mpp from source kernel to current kernel for build test"
    echo "  pkg                Copy current kernel files to package folder and pack as tar.gz"
    echo "  resume             Copy package folder contents back to current kernel for regression"
    echo "  mpp                Only package mpp driver and pack as tar.gz"
    echo ""
    echo "Available kernel dirs:"
    local _i
    for ((_i = 0; _i < ${#ker_dir_lst[@]}; _i++)); do
        echo "  ${_i}. ${ker_dir_lst[${_i}]}"
    done
    echo ""
    echo "File list: <kernel_git_dir>/${tar_file_lst_name}"
    if [ -f "${tar_file_lst}" ]; then
        echo "Content:"
        cat -n "${tar_file_lst}" | sed 's/^/  /'
    else
        echo "  (not found, one path per line, # for comment, e.g.:)"
        echo "  # comment line"
        echo "  include/linux/rockchip/cpu.h"
        echo "  drivers/soc/rockchip/rockchip-cpuinfo.c"
    fi
    exit 1
}

function init_env()
{
    target_ker="$(git rev-parse --show-toplevel 2>/dev/null)"
    [ -z "${target_ker}" ] && { echo "[ERROR] not in kernel dir"; exit 1; }
    target_mpp="${target_ker}/drivers/video/rockchip/mpp"
    echo "[INFO] kernel git dir: ${target_ker}"

    pkg_dir="${target_ker}/update_ker"
    pkg_f_dir="${pkg_dir}/files"
    pkg_mpp_dir="${pkg_dir}/mpp"
    pkg_resume_f="${pkg_dir}/readme.sh"

    tar_file_lst="${target_ker}/${tar_file_lst_name}"
    if [ -f "${tar_file_lst}" ]; then
        echo "[INFO] file list: ${tar_file_lst}"
        # mapfile -t: read lines from stdin into array, -t strips trailing newline
        # < <(...): process substitution, grep output as stdin for mapfile
        mapfile -t file_lst < <(grep -v "^#" "${tar_file_lst}")
        echo "[INFO] loaded ${#file_lst[@]} file(s) from ${tar_file_lst}"
    else
        echo "[INFO] file list not found: ${tar_file_lst}, skip"
        file_lst=()
    fi
}

function copy_from_src_ker()
{
    ker_dir="$1"
    echo "[INFO] copy_from_src_ker: src=${ker_dir}"

    [ ! -d "${ker_dir}" ] && { echo "[ERROR] kernel dir not found: ${ker_dir}"; exit 1; }

    for file in "${file_lst[@]}"
    do
        update_file ${ker_dir}/${file} ${target_ker}/${file}
    done

    [ ! -d "${src_mpp}" ] && { echo "[ERROR] mpp dir not found: ${src_mpp}"; exit 1; }
    remove_dir ${target_mpp}
    update_file ${src_mpp} ${target_mpp}
    echo "[INFO] copy_from_src_ker: done"
}

function copy_to_pkg()
{
    echo "[INFO] copy_to_pkg: dest=${pkg_f_dir}"
    create_dir ${pkg_f_dir}

    for file in "${file_lst[@]}"
    do
        update_file ${target_ker}/${file} ${pkg_f_dir}
    done

    remove_dir ${pkg_mpp_dir}
    update_file ${target_mpp} ${pkg_mpp_dir}
    echo "[INFO] copy_to_pkg: done"
}

function resume_to_ker_tree()
{
    echo "[INFO] resume_to_ker_tree: deploy pkg -> current kernel tree"

    [ ! -d "${pkg_dir}" ] && { echo "[ERROR] pkg dir not found: ${pkg_dir}, run 'pkg' mode first"; exit 1; }

    remove_dir ${target_mpp}

    for file in "${file_lst[@]}"
    do
        update_file ${pkg_f_dir}/$(basename ${file}) ./${file}
    done

    update_file ${pkg_mpp_dir} ${target_mpp}
    echo "[INFO] resume_to_ker_tree: done"
}

function gen_deploy_tool()
{
    echo "[INFO] gen_deploy_tool: ${pkg_resume_f}"
    cat > ${pkg_resume_f} << EOF
#!/usr/bin/env bash
# create time: $(date +"%Y-%m-%d %H:%M:%S")
# from kernel: ${target_ker}

pkg_root="\$(dirname "\$0")"
ker_dir="\${1:-\$(git rev-parse --show-toplevel)}"
echo "kernel dir: \${ker_dir}"
target_mpp=\${ker_dir}/drivers/video/rockchip/mpp
[ -z "\${ker_dir}" ] && { echo "Please set target kernel dir"; exit 1; }

[ -e "\${target_mpp}" ] && { echo "Please back up \${target_mpp}, and then redeploy"; exit 1; }
$(for file in ${file_lst[@]}; do echo "cp \${pkg_root}/files/$(basename ${file}) \${ker_dir}/${file}"; done)
cp -r \${pkg_root}/mpp "\${target_mpp}"

# fix dtc build error:
# sed -i "s/^YYLTYPE yylloc/extern YYLTYPE yylloc/" scripts/dtc/dtc-parser.tab.c

echo "===== deploy done ====="
EOF

    echo "[INFO] gen_deploy_tool: done"
}

function pkg_mpp()
{
    local ker_dir="$1"
    local mpp_dir="${ker_dir}/drivers/video/rockchip/mpp"
    echo "[INFO] pkg_mpp: kernel=${ker_dir}, mpp=${mpp_dir}"
    [ ! -d "${mpp_dir}" ] && { echo "[ERROR] mpp dir not found: ${mpp_dir}"; exit 1; }

    # mktemp -d: create a temporary directory with unique name, e.g. /tmp/tmp.xYz123
    # trap ... EXIT: auto cleanup tmp dir when script exits (normal or error)
    local tmp_dir="$(mktemp -d)"
    trap "rm -rf ${tmp_dir}" EXIT

    cp -r ${mpp_dir} ${tmp_dir}/mpp
    echo "# create time: $(date +"%Y-%m-%d %H:%M:%S")" > ${tmp_dir}/mpp/readme.txt
    echo "# from kernel: ${ker_dir}" >> ${tmp_dir}/mpp/readme.txt

    tar_pkg="$(pwd)/mpp.tar.gz"
    echo "[INFO] packing: tar czf ${tar_pkg} -C ${tmp_dir} mpp"
    tar czf ${tar_pkg} -C ${tmp_dir} mpp
    echo "[INFO] package saved: ${tar_pkg}"
    echo "[INFO] pkg_mpp: done"
}


function main()
{
    echo "===== rk_tar_ker: kernel file packaging tool ====="

    mode="$1"
    [ -z "${mode}" ] && { echo "[ERROR] no mode specified"; usage; }

    case "${mode}" in
        from)
            init_env
            if [ -n "$2" ]; then
                src_ker="$2"
                echo "[INFO] mode: from, kernel_dir=${src_ker}"
            else
                select_node "${sel_tag_tar_ker}" "ker_dir_lst" "src_ker" "select source kernel dir"
                echo "[INFO] mode: from, kernel_dir=${src_ker}"
            fi
            src_mpp="${src_ker}/drivers/video/rockchip/mpp"
            echo "[INFO] source kernel : ${src_ker}"
            echo "[INFO] source mpp    : ${src_mpp}"
            echo "[INFO] target mpp    : ${target_mpp}"
            copy_from_src_ker "${src_ker}"
            ;;
        pkg)
            init_env
            echo "[INFO] mode: pkg"
            echo "[INFO] source kernel : ${src_ker}"
            echo "[INFO] source mpp    : ${src_mpp}"
            echo "[INFO] target mpp    : ${target_mpp}"
            echo "[INFO] pkg dir       : ${pkg_dir}"
            remove_dir ${pkg_dir}
            create_dir ${pkg_dir}
            create_dir ${pkg_f_dir}
            copy_to_pkg
            gen_deploy_tool
            tar_pkg="${pkg_dir}.tar.gz"
            tar_pkg_name="$(basename ${pkg_dir})"
            echo "[INFO] packing: tar czf ${tar_pkg} -C ${target_ker} ${tar_pkg_name}"
            tar czf ${tar_pkg} -C ${target_ker} ${tar_pkg_name}
            echo "[INFO] package saved: ${tar_pkg}"
            ;;
        resume)
            init_env
            echo "[INFO] mode: resume"
            echo "[INFO] target mpp    : ${target_mpp}"
            echo "[INFO] pkg dir       : ${pkg_dir}"
            resume_to_ker_tree
            ;;
        mpp)
            if [ -n "$2" ]; then
                mpp_ker="$2"
                echo "[INFO] mode: mpp, kernel_dir=${mpp_ker}"
            else
                select_node "${sel_tag_tar_ker}" "ker_dir_lst" "mpp_ker" "select kernel dir"
                echo "[INFO] mode: mpp, kernel_dir=${mpp_ker}"
            fi
            pkg_mpp "${mpp_ker}"
            ;;
        *)
            echo "[ERROR] unknown mode: ${mode}"
            usage
            ;;
    esac

    echo "===== rk_tar_ker: done ====="

}

main $@

