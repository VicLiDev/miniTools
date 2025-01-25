#!/usr/bin/env sh
#########################################################################
# File Name: target_run_test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 08 Jan 2025 09:35:06 AM CST
#########################################################################

#============ test paras ============

mount_point="/mnt/sdcard"
sd_dev="/dev/mmcblk1p1"

exe_dst="/root/bin"
lib_dst="/usr/lib64"
spt_dst="/root"

strm_h265="${mount_point}/test_stream/m_h265/vstream/Big_Buck_Bunny_360_10s_1MB.h265"
strm_h264="${mount_point}/test_stream/m_h264/vstream/Big_Buck_Bunny_360_10s_1MB.h264"
strm_vp9="${mount_point}/test_stream/m_vp9/vstream/Big_Buck_Bunny_360_10s_1MB.ivf"
strm_avs2="${mount_point}/test_stream/m_avs2/vstream/test1_avs2.avs2"
# strm_av1="${mount_point}/test_stream/m_av1/vstream/Chimera-AV1-8bit-480x270-552kbps_fragmented.ivf"
strm_av1="${mount_point}/test_stream/m_av1/vstream/vcut05.10_15.ivf"
if [ ! -e ${sd_dev} ]; then
    strm_h265="${HOME}/vstream/Big_Buck_Bunny_1080_10s_5MB.h265"
    strm_h264="${HOME}/vstream/Big_Buck_Bunny_1080_10s_1MB.h264"
    strm_vp9="${HOME}/vstream/Big_Buck_Bunny_1080_10s_2MB.ivf"
    strm_avs2="${HOME}/vstream/AVS2_1920x1080_1_23988363253.avs2"
    strm_av1="${HOME}/vstream/Sintel_1080_10s_2MB.ivf"
fi

h265_paras="-t 16777220 -n 1  -i ${strm_h265}"
h264_paras="-t 7        -n 1  -i ${strm_h264}"
vp9_paras="-t 10        -n 1  -i ${strm_vp9}"
avs2_paras="-t 16777223 -n 1  -i ${strm_avs2}"
# av1_paras="-t 16777224 -n 1  -i ${strm_av1}"
av1_paras="-t 16777224  -n 1  -i ${strm_av1}"

exe="${exe_dst}/mpi_dec_test"

test_cmd_hevc="${exe} ${h265_paras}"
test_cmd_avc="${exe} ${h264_paras}"
test_cmd_avs2="${exe} ${avs2_paras}"
test_cmd_vp9="${exe} ${vp9_paras}"
test_cmd_av1="${exe} ${av1_paras}"

#============ parse opt ============

opt_init="True"
opt_test="False"
opt_sd="False"
opt_prot="hevc"
opt_irq="False"
opt_reg="False"

function help()
{
    echo "usage: <exe> [opts]"
    echo "  --: no input update file to fpga and update ko         "
    echo "  t <prot>: exe test, prot could be hevc|avc|avs2|vp9|av1"
    echo "  sd: mount/unmount sdcard                               "
    echo "  reg: dump reg toggle, echo 0/1 > paras                 "
}

function parse_cmd()
{
    echo "intput para: $@"
    for para in $@
    do
        opt_init="False"
        case ${para} in
        "help"|"h")
            help
            exit 0
            ;;
        "sd")
            opt_sd="True"
            ;;
        "t")
            opt_test="True"
            ;;
        "hevc"|"avc"|"avs2"|"vp9"|"av1")
            opt_prot=${para}
            ;;
        "irq")
            opt_irq="True"
            ;;
        "reg")
            opt_reg="True"
            ;;
        *)
            opt_init="True"
            ;;
        esac
    done

    echo "opt_init : ${opt_init}"
    echo "opt_test : ${opt_test}"
    echo "opt_sd   : ${opt_sd}"
    echo "opt_prot : ${opt_prot}"
    echo "opt_irq  : ${opt_irq}"
    echo "opt_reg  : ${opt_reg}"
}

#============ important func ============

function create_dir()
{
    if [ ! -d $1 ]; then echo "create dir $1"; mkdir -p $1; fi
}

function mount_toggle()
{
    create_dir ${mount_point}

    if [ -n "`df -h | grep mmcblk | sed "s/.* //g"`" ]; then
        echo "umount sd card from ${mount_point}"
        umount ${mount_point};
    else
        echo "mount sd card(${sd_dev}) to ${mount_point}"
        mount ${sd_dev} ${mount_point}
    fi
}

function update_file()
{
    if [ ! -e $1 ]; then echo "src file $1 do not exist"; exit 1; fi
    if [ ! -e $2 ]; then echo "dst dir $2 do not exist"; exit 1; fi
    echo "copy $1 to $2"
    cp -r $1 $2
}


function update_all_file()
{
    if [ -e ${sd_dev} ]; then
        update_file "${mount_point}/exec/rk_vcodec.ko"         "${exe_dst}"
        update_file "${mount_point}/exec/librockchip_mpp.so.0" "${lib_dst}"
        update_file "${mount_point}/exec/mpi_dec_test"         "${exe_dst}"
        update_file "${mount_point}/exec/target_run_test.sh"   "${exe_dst}"
        update_file "${mount_point}/exec/target_run_batch.sh"  "${spt_dst}"
    fi

    if [ -n "`lsmod | grep rk_vcodec`" ]; then
        echo "rmmod old rk_vcodec.ko"
        rmmod rk_vcodec.ko
    fi
    echo "insmod rk_vcodec.ko"
    insmod ${exe_dst}/rk_vcodec.ko
}


function update_all()
{
    # create dir
    create_dir "${mount_point}"
    create_dir "${exe_dst}"

    [ -e ${sd_dev} ] && mount ${sd_dev} ${mount_point}
    if [ $? -ne 0 ]; then echo "mount sdcard faile"; fi


    # update file
    update_all_file
    link_name="${lib_dst}/librockchip_mpp.so.1"
    lib_name="${lib_dst}/librockchip_mpp.so.0"
    rm ${link_name} && ln -s ${lib_name} ${link_name}


    [ -e ${sd_dev} ] && umount ${mount_point}
}

function main()
{
    parse_cmd $@

    if [ "${opt_init}" == "True" ]; then
        echo "update lib/exe/ko ..."
        update_all
    fi

    # run test
    if [ "${opt_test}" == "True" ]; then
        export mpp_syslog_perror=1
        if [ -n "`ps aux | grep tail | grep message`" ]; then
            tail -f /var/log/message &
        fi
        eval test_cmd='$'test_cmd_${opt_prot}
        echo "test cmd: ${test_cmd}"
        ${test_cmd}
    fi

    # mount sd toggle
    if [ "${opt_sd}" == "True" ]; then mount_toggle; fi

    # enable/disable irq
    if [ "${opt_irq}" == "True" ]; then
        echo "enable reg dump"
        echo 0x104 > /sys/module/rk_vcodec/parameters/mpp_dev_debug
        echo "cur irq dump: `cat /sys/module/rk_vcodec/parameters/mpp_dev_debug`"
    fi

    # enable/disable reg dump
    if [ "${opt_reg}" == "True" ]; then
        echo "enable reg dump"
        echo 0xc3000 > /sys/module/rk_vcodec/parameters/mpp_dev_debug
        echo "cur reg dump: `cat /sys/module/rk_vcodec/parameters/mpp_dev_debug`"
    fi
}

main $@
