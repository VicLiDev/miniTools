#########################################################################
# File Name: pullVideo.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu Jan 20 10:21:57 2022
#########################################################################
#!/usr/bin/env bash

videoDir="collect_video"
fileRootDir="/Volumes/RKshare/Video_4K_1080P_720P"

videoList=(
#================> mpeg1
"FILE/OPPO  090702/9.813/DAT/他还是不懂.DAT"
"FILE/OPPO  090702/客户提供的资源/PHILIPS/PI_AV_Test_Suite/Image Quality/Qual3_Original_QVGA_mpeg1_30fps.mpeg"
#================> mpeg2
"3DV/3d电视演示短片www.233d.com 左右格式 1920x1080 393M.mkv"
"BluRay/Apollo.13.1995.Blu-ray.DIY.1080p.AVC.DTSHDMA-YellowBeast@beAst/BDMV/STREAM/00125.m2ts"
"BluRay/Apollo.13.1995.Blu-ray.DIY.1080p.AVC.DTSHDMA-YellowBeast@beAst/BDMV/STREAM/50110.m2ts"
"Box_Soc_Video/性能测试/1080p-60F.avi"
#================> mpeg4
"Box_Soc_Video/性能测试/1080p-60F.avi"
"Box_Soc_Video/性能测试/720P_diyunan.h265 00_01_36-00_01_39.mp4"
"Box_Soc_Video/性能测试/OnlineNews.mp4"
#================> WMV
"视频/Video/29拷机片源8大混合/1920x1080,8000 Kbps,23.976fps,WMV3,WMA3,192 Kbps,高清试机短片系列.Good.Night.and.Good.Luck.wmv"
"视频/Video/tmp/test.wmv"
"WMV/tmp/CH1心理學可以告訴你什麼？.wmv"
#================> H.263
"FILE/OPPO  090702/客户提供的资源/PHILIPS/PI_AV_Test_Suite/Video Test Files/3G2_1.3g2"
"FILE/OPPO  090702/客户提供的资源/PHILIPS/PI_AV_Test_Suite/Video Test Files/3gp_1.3gp"
"FILE/OPPO  090702/客户提供的资源/PHILIPS/PI_AV_Test_Suite/Video Test Files/3GP_2.3gp"
"FILE/OPPO  090702/客户提供的资源/PHILIPS/片源总汇/3G2_1.3g2"
#================> vp6
"视频片源上传路径/VP6视频0.flv"
"视频片源上传路径/VP6视频0.flv"
#================> vp8
"视频/Video/29拷机片源8大混合/变形金刚2卷土重来sample.webmvp8.webm"
"视频/Video/Video_SCT/Shuttle_video_test/27-IFF_ILBM-VORBIS"
#================> rmvb
#================> H.264
"1920x1080,27.0 Mbps,23.976fps,AVC,DTS AC3 AC3,1536 Kbps,变形金刚2：卷土重来sample.mkv"
"HDL-video/rk1109_avc_test_stream/normal_source/720p/akiyo_1280x720_3mbps.bin"
"HDL-video/rk1109_avc_test_stream/normal_source/720p/BQMall_1280x720_8mbps.bin"
"24Bit音轨视频文件/1920x1080,12.4 Mbpss,AVC,23.976 fps,DTS 1536 Kbps,,Arahan.2004.BluRay.1080p.DTS.x264-CHD.sample.mkv"
#================> jpeg
"BluRay/Apollo.13.1995.Blu-ray.DIY.1080p.AVC.DTSHDMA-YellowBeast@beAst/BDMV/JAR/10001/BDLive_HSceneBG_generic.jpg"
"BluRay/Apollo.13.1995.Blu-ray.DIY.1080p.AVC.DTSHDMA-YellowBeast@beAst/BDMV/META/DL/A13_BDJ_Jacket_LRG.jpg"
"视频/2015show/gallery/01600_doodledoorjurassicicondorset_1920x1200.jpg"
)


prjRootDir=$(git -C $(dirname $(readlink -f $0)) rev-parse --show-toplevel)
source ${prjRootDir}/0.general_tools/0.dir_file_opt.sh

create_dir ${videoDir}
videoCnt=${#videoList[*]}
for ((loop=0; loop<videoCnt; loop++))
do
    echo "copying file: ""$fileRootDir/${videoList[loop]}"
    cp "$fileRootDir/${videoList[loop]}" ${videoDir}/
done
