#!/usr/bin/env sh
#########################################################################
# File Name: target_run_batch.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 08 Jan 2025 09:35:40 AM CST
#########################################################################

# usage: <exe> h265|h264|avs2|vp9|av1

cur_prot="h265"
streams_dir_root="/mnt/sdcard/test_stream"

strms_h265="
    Big_Buck_Bunny_360_10s_1MB.h265
    Big_Buck_Bunny_720_10s_1MB.h265
    Big_Buck_Bunny_1080_10s_1MB.h265
    H265_4k_60fps_20M-RIO.h265
    "
    # Big_Buck_Bunny_360_10s_2MB.h265
    # Big_Buck_Bunny_360_10s_5MB.h265
    # Big_Buck_Bunny_360_10s_10MB.h265
    # Big_Buck_Bunny_360_10s_20MB.h265
    # Big_Buck_Bunny_720_10s_2MB.h265
    # Big_Buck_Bunny_720_10s_5MB.h265
    # Big_Buck_Bunny_720_10s_10MB.h265
    # Big_Buck_Bunny_720_10s_20MB.h265
    # Big_Buck_Bunny_720_10s_30MB.h265
    # Big_Buck_Bunny_1080_10s_2MB.h265
    # Big_Buck_Bunny_1080_10s_5MB.h265
    # Big_Buck_Bunny_1080_10s_10MB.h265
    # Big_Buck_Bunny_1080_10s_20MB.h265
    # Big_Buck_Bunny_1080_10s_30MB.h265
strms_h264="
    Big_Buck_Bunny_360_10s_1MB.h264
    Big_Buck_Bunny_720_10s_1MB.h264
    Big_Buck_Bunny_1080_10s_1MB.h264
    bbb_sunflower_2160p_30fps_normal.h264
    "
    # Big_Buck_Bunny_360_10s_2MB.h264
    # Big_Buck_Bunny_360_10s_5MB.h264
    # Big_Buck_Bunny_360_10s_10MB.h264
    # Big_Buck_Bunny_360_10s_20MB.h264
    # Big_Buck_Bunny_360_10s_30MB.h264
    # Big_Buck_Bunny_720_10s_2MB.h264
    # Big_Buck_Bunny_720_10s_5MB.h264
    # Big_Buck_Bunny_720_10s_10MB.h264
    # Big_Buck_Bunny_720_10s_20MB.h264
    # Big_Buck_Bunny_720_10s_30MB.h264
    # Big_Buck_Bunny_1080_10s_2MB.h264
    # Big_Buck_Bunny_1080_10s_5MB.h264
    # Big_Buck_Bunny_1080_10s_10MB.h264
    # Big_Buck_Bunny_1080_10s_20MB.h264
    # Big_Buck_Bunny_1080_10s_30MB.h264
strms_vp9="
    Big_Buck_Bunny_360_10s_1MB.ivf
    Big_Buck_Bunny_720_10s_1MB.ivf
    Big_Buck_Bunny_1080_10s_1MB.ivf
    Sony_Food_Fizzle_4K_60fps_VP9.ivf
    "
    # Big_Buck_Bunny_360_10s_2MB.ivf
    # Big_Buck_Bunny_360_10s_5MB.ivf
    # Big_Buck_Bunny_360_10s_10MB.ivf
    # Big_Buck_Bunny_360_10s_20MB.ivf
    # Big_Buck_Bunny_360_10s_30MB.ivf
    # Big_Buck_Bunny_720_10s_2MB.ivf
    # Big_Buck_Bunny_720_10s_5MB.ivf
    # Big_Buck_Bunny_720_10s_10MB.ivf
    # Big_Buck_Bunny_720_10s_20MB.ivf
    # Big_Buck_Bunny_720_10s_30MB.ivf
    # Big_Buck_Bunny_1080_10s_2MB.ivf
    # Big_Buck_Bunny_1080_10s_5MB.ivf
    # Big_Buck_Bunny_1080_10s_10MB.ivf
    # Big_Buck_Bunny_1080_10s_20MB.ivf
    # Big_Buck_Bunny_1080_10s_30MB.ivf
strms_avs2="
    CCTV8K.AVS3.MP2.CB_10bit_HDR.avs2
    test5_avs3.avs2
    HDR10Plus_PA_DTSX_768x432_HDR_avs3_20s.avs2
    test1_avs2.avs2
    jellyfish-640x360-avs3-10bit.avs2
    CCTV4K.AVS2-10bit.AC3.CB.08-27-6s.avs2
    HDR-JNDNet_Test_qp37_avs3_HDR.avs2
    test5_avs2.avs2
    masterchef.australia.s12e59.hdtv.cavs-fqm[eztv.io].avs2
    HDRPlus_PA_DTSX_avs2_4K_18s.avs2
    "
strms_av1="
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
    Chimera-AV1-10bit-480x270-531kbps_fragmented.ivf
    Chimera-AV1-10bit-480x270-531kbps.ivf
    Chimera-AV1-10bit-768x432-1090kbps_fragmented.ivf
    Chimera-AV1-10bit-768x432-1090kbps.ivf
    Chimera-AV1-10bit-1280x720-2380kbps_fragmented.ivf
    Chimera-AV1-10bit-1280x720-2380kbps.ivf
    Chimera-AV1-10bit-1920x1080-6191kbps_fragmented.ivf
    Chimera-AV1-10bit-1920x1080-6191kbps.ivf
    Real_4K_HDR_60fps.ivf
    "
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
    # Sintel_360_10s_10MB.ivf
    # Sintel_360_10s_1MB.ivf
    # Sintel_360_10s_2MB.ivf
    # Sintel_360_10s_5MB.ivf
    # Sintel_720_10s_1MB.ivf
    # Sintel_720_10s_5MB.ivf
    # Sintel_720_10s_10MB.ivf
    # Sintel_720_10s_2MB.ivf
    # Sintel_720_10s_20MB.ivf
    # Sintel_720_10s_30MB.ivf
    # Sintel_1080_10s_10MB.ivf
    # Sintel_1080_10s_1MB.ivf
    # Sintel_1080_10s_20MB.ivf
    # Sintel_1080_10s_2MB.ivf
    # Sintel_1080_10s_30MB.ivf
    # Sintel_1080_10s_5MB.ivf

exe_dst="/root/bin"
exe="${exe_dst}/mpi_dec_test"
paras_h265="-t 16777220 -i "
paras_h264="-t 7 -i "
paras_vp9="-t 10 -i "
paras_avs2="-t 16777223 -i "
paras_av1="-t 16777224 -i "

test_cmd_h265="${exe} ${paras_h265}"
test_cmd_h264="${exe} ${paras_h264}"
test_cmd_avs2="${exe} ${paras_avs2}"
test_cmd_vp9="${exe} ${paras_vp9}"
test_cmd_av1="${exe} ${paras_av1}"


# main
cur_prot="$1"

eval test_cmd='$'test_cmd_${cur_prot}
if [ -z "${test_cmd}" ]; then echo "unsupport prot: ${cur_prot}"; exit 0; fi
eval test_strms='$'{strms_${cur_prot}}
for cur_strm in ${test_strms};
do
    cur_cmd="export mpp_syslog_perror=1 && ${test_cmd} ${streams_dir_root}/m_${cur_prot}/vstream/${cur_strm}"
    echo "cur run cmd: ${cur_cmd}"
    eval ${cur_cmd}
    if [ $? != 0 ];then echo "test error with cmd: ${cur_cmd}"; exit 1; fi
done
