#!/bin/bash
#########################################################################
# File Name: test_mpp_arm_batch.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 19 Feb 2024 03:06:59 PM CST
#########################################################################

cur_prot="hevc"

streams_dir_root="/sdcard/m_av1"
strms_hevc="
    Big_Buck_Bunny_360_10s_5MB.h265
    "
    # pass
    # Big_Buck_Bunny_360_10s_5MB.h265
    # Big_Buck_Bunny_360_10s_1MB.h265
    # Big_Buck_Bunny_360_10s_2MB.h265
    # Big_Buck_Bunny_360_10s_20MB.h265
    # Big_Buck_Bunny_360_10s_10MB.h265
    # Big_Buck_Bunny_720_10s_1MB.h265
    # Big_Buck_Bunny_720_10s_5MB.h265
    # Big_Buck_Bunny_720_10s_2MB.h265
    # Big_Buck_Bunny_1080_10s_5MB.h265
    # Big_Buck_Bunny_1080_10s_2MB.h265
    # Big_Buck_Bunny_1080_10s_1MB.h265

    # error
    # Big_Buck_Bunny_720_10s_20MB.h265
    # Big_Buck_Bunny_720_10s_20MB.h265
    # Big_Buck_Bunny_720_10s_10MB.h265
    # Big_Buck_Bunny_720_10s_30MB.h265
    # Big_Buck_Bunny_1080_10s_10MB.h265 // segment fault
    # Big_Buck_Bunny_1080_10s_20MB.h265
    # Big_Buck_Bunny_1080_10s_30MB.h265
strms_avc="
    Big_Buck_Bunny_360_10s_1MB.h264
    "
    # pass
    # Big_Buck_Bunny_360_10s_1MB.h264
    # Big_Buck_Bunny_360_10s_30MB.h264
    # Big_Buck_Bunny_360_10s_2MB.h264
    # Big_Buck_Bunny_360_10s_20MB.h264
    # Big_Buck_Bunny_360_10s_5MB.h264
    # Big_Buck_Bunny_360_10s_10MB.h264
    # Big_Buck_Bunny_720_10s_1MB.h264
    # Big_Buck_Bunny_720_10s_20MB.h264
    # Big_Buck_Bunny_720_10s_2MB.h264
    # Big_Buck_Bunny_720_10s_5MB.h264
    # Big_Buck_Bunny_720_10s_10MB.h264
    # Big_Buck_Bunny_720_10s_30MB.h264
    # Big_Buck_Bunny_1080_10s_20MB.h264
    # Big_Buck_Bunny_1080_10s_5MB.h264
    # Big_Buck_Bunny_1080_10s_30MB.h264
    # Big_Buck_Bunny_1080_10s_1MB.h264
    # Big_Buck_Bunny_1080_10s_2MB.h264
    # Big_Buck_Bunny_1080_10s_10MB.h264
strms_vp9="
    Big_Buck_Bunny_360_10s_1MB.ivf
    "
    # pass
    # Big_Buck_Bunny_360_10s_1MB.ivf
    # Big_Buck_Bunny_360_10s_5MB.ivf
    # Big_Buck_Bunny_360_10s_30MB.ivf
    # Big_Buck_Bunny_360_10s_20MB.ivf
    # Big_Buck_Bunny_360_10s_10MB.ivf
    # Big_Buck_Bunny_360_10s_2MB.ivf
    # Big_Buck_Bunny_720_10s_2MB.ivf
    # Big_Buck_Bunny_720_10s_10MB.ivf
    # Big_Buck_Bunny_720_10s_5MB.ivf
    # Big_Buck_Bunny_720_10s_30MB.ivf
    # Big_Buck_Bunny_720_10s_1MB.ivf
    # Big_Buck_Bunny_720_10s_20MB.ivf
    # Big_Buck_Bunny_1080_10s_5MB.ivf
    # Big_Buck_Bunny_1080_10s_2MB.ivf
    # Big_Buck_Bunny_1080_10s_10MB.ivf
    # Big_Buck_Bunny_1080_10s_20MB.ivf
    # Big_Buck_Bunny_1080_10s_1MB.ivf
    # Big_Buck_Bunny_1080_10s_30MB.ivf
strms_avs2="
    test5_avs2.avs2
    "
    # pass
    # CCTV8K.AVS3.MP2.CB_10bit_HDR.avs2
    # test5_avs3.avs2
    # HDR10Plus_PA_DTSX_768x432_HDR_avs3_20s.avs2
    # jellyfish-640x360-avs3-10bit.avs2
    # CCTV4K.AVS2-10bit.AC3.CB.08-27-6s.avs2
    # HDR-JNDNet_Test_qp37_avs3_HDR.avs2
    # test5_avs2.avs2
    # masterchef.australia.s12e59.hdtv.cavs-fqm[eztv.io].avs2

    # error
    # test1_avs2.avs2
    # HDRPlus_PA_DTSX_avs2_4K_18s.avs2
strms_av1="
    Sintel_360_10s_1MB.ivf
    Sintel_360_10s_2MB.ivf
    Sintel_360_10s_5MB.ivf
    Sintel_360_10s_10MB.ivf
    Sintel_720_10s_1MB.ivf
    Sintel_720_10s_2MB.ivf
    Sintel_720_10s_5MB.ivf
    Sintel_720_10s_10MB.ivf
    Sintel_1080_10s_1MB.ivf
    Sintel_1080_10s_2MB.ivf
    Sintel_1080_10s_5MB.ivf
    Sintel_1080_10s_10MB.ivf
    Sintel_1080_10s_20MB.ivf
    Chimera-AV1-10bit-480x270-531kbps_fragmented.ivf
    Chimera-AV1-10bit-480x270-531kbps.ivf
    Chimera-AV1-10bit-768x432-1090kbps_fragmented.ivf
    Chimera-AV1-10bit-768x432-1090kbps.ivf
    Chimera-AV1-10bit-1280x720-2380kbps_fragmented.ivf
    Chimera-AV1-10bit-1280x720-2380kbps.ivf
    Chimera-AV1-10bit-1920x1080-6191kbps_fragmented.ivf
    Chimera-AV1-10bit-1920x1080-6191kbps.ivf
    Chimera-AV1-8bit-480x270-552kbps_fragmented.ivf
    Chimera-AV1-8bit-480x270-552kbps.ivf
    Chimera-AV1-8bit-768x432-1160kbps_fragmented.ivf
    Chimera-AV1-8bit-768x432-1160kbps.ivf
    Chimera-AV1-8bit-1280x720-3363kbps_fragmented.ivf
    Chimera-AV1-8bit-1280x720-3363kbps.ivf
    Chimera-AV1-8bit-1920x1080-6736kbps_fragmented.ivf
    Chimera-AV1-8bit-1920x1080-6736kbps.ivf
    Japan_AV1-8bit-3840x2160-12mbps.ivf
    Japan_AV1-8bit-7680x4320-26mbps.ivf
    Japan_AV1-8bit-3840x2160-12mbps.ivf
    Japan_AV1-8bit-7680x4320-26mbps.ivf
    "
    # pass
    # Sintel_360_10s_1MB.ivf
    # Sintel_360_10s_2MB.ivf
    # Sintel_360_10s_5MB.ivf
    # Sintel_360_10s_10MB.ivf
    # Sintel_720_10s_1MB.ivf
    # Sintel_720_10s_2MB.ivf
    # Sintel_720_10s_5MB.ivf
    # Sintel_720_10s_10MB.ivf
    # Sintel_1080_10s_1MB.ivf
    # Sintel_1080_10s_2MB.ivf
    # Sintel_1080_10s_5MB.ivf
    # Sintel_1080_10s_10MB.ivf
    # Sintel_1080_10s_20MB.ivf

    # error
    # Sintel_720_10s_20MB.ivf
    # Sintel_720_10s_30MB.ivf
    # Sintel_1080_10s_30MB.ivf

    # Chimera-AV1-10bit-480x270-531kbps_fragmented.ivf
    # Chimera-AV1-10bit-480x270-531kbps.ivf
    # Chimera-AV1-10bit-768x432-1090kbps_fragmented.ivf
    # Chimera-AV1-10bit-768x432-1090kbps.ivf
    # Chimera-AV1-10bit-1280x720-2380kbps_fragmented.ivf
    # Chimera-AV1-10bit-1280x720-2380kbps.ivf
    # Chimera-AV1-10bit-1920x1080-6191kbps_fragmented.ivf
    # Chimera-AV1-10bit-1920x1080-6191kbps.ivf
    # Chimera-AV1-8bit-480x270-552kbps_fragmented.ivf
    # Chimera-AV1-8bit-480x270-552kbps.ivf
    # Chimera-AV1-8bit-768x432-1160kbps_fragmented.ivf
    # Chimera-AV1-8bit-768x432-1160kbps.ivf
    # Chimera-AV1-8bit-1280x720-3363kbps_fragmented.ivf
    # Chimera-AV1-8bit-1280x720-3363kbps.ivf
    # Chimera-AV1-8bit-1920x1080-6736kbps_fragmented.ivf
    # Chimera-AV1-8bit-1920x1080-6736kbps.ivf
    # Japan_AV1-8bit-3840x2160-12mbps.ivf
    # Japan_AV1-8bit-7680x4320-26mbps.ivf
    # Japan_AV1-8bit-3840x2160-12mbps.ivf
    # Japan_AV1-8bit-7680x4320-26mbps.ivf

    # Chimera-AV1-8bit-480x270-552kbps-354.avif
    # Chimera-AV1-10bit-480x270-531kbps-354.avif
    # Chimera-AV1-8bit-768x432-1160kbps-354.avif
    # Chimera-AV1-10bit-768x432-1090kbps-34.avif
    # Chimera-AV1-8bit-1280x720-3363kbps-354.avif
    # Chimera-AV1-10bit-1280x720-2380kbps-100.avif
    # Chimera-AV1-8bit-1920x1080-6736kbps-100.avif
    # Chimera-AV1-8bit-1920x1080-6736kbps-354.avif
    # Chimera-AV1-10bit-1920x1080-6191kbps-162.avif
    # Chimera-AV1-8bit-480x270-552kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-10bit-480x270-531kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-8bit-768x432-1160kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-10bit-768x432-1090kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-8bit-1280x720-3363kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-10bit-1280x720-2380kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-8bit-1920x1080-6736kbps_fragmented_cbcs_v2.ivf
    # Chimera-AV1-10bit-1920x1080-6191kbps_fragmented_cbcs.ivf

exe="mpi_dec_test"
paras_hevc="-t 16777220 -i "
paras_avc="-t 7 -i "
paras_vp9="-t 10 -i "
paras_avs2="-t 16777223 -i "
paras_av1="-t 16777224 -i "

test_cmd_hevc="${exe} ${paras_hevc}"
test_cmd_avc="${exe} ${paras_avc}"
test_cmd_avs2="${exe} ${paras_avs2}"
test_cmd_vp9="${exe} ${paras_vp9}"
test_cmd_av1="${exe} ${paras_av1}"


# main
adb shell io -4 -w 0x26004300 0x00070007

cur_prot="$1"

eval test_cmd='$'test_cmd_${cur_prot}
if [ -z "${test_cmd}" ]; then echo "unsupport prot: ${cur_prot}"; exit 0; fi
eval test_strms='$'{strms_${cur_prot}}
for cur_strm in ${test_strms};
do
    echo ""
    cur_cmd="adb shell ${test_cmd} ${streams_dir_root}/${cur_strm}"
    echo "cur run cmd: ${cur_cmd}"
    ${cur_cmd}
    if [ $? != 0 ];then
        echo -e "test \033[0m\033[1;31m error \033[0m"
        echo "cur error cmd: ${cur_cmd}"
        # exit 1
    else
        echo -e "test \033[0m\033[1;32m pass \033[0m"
    fi

    read -p "continue? [y/n]:" runOpt; if [ "$runOpt" == "n" ];then exit 0; fi
done
