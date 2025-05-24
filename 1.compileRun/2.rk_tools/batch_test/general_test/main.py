#!/usr/bin/env python
#########################################################################
# File Name: main.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:58:25 PM CST
#########################################################################

import os
import argparse

import yaml_cfg
from decoder import decode_video
from verifier import verify_all


def proc_paras():
    # 创建解析器
    parser = argparse.ArgumentParser(description="cmd paras proc")

    parser.add_argument("-c","--config", default="config.ymal", help="config file")
    parser.add_argument("-m","--mode",   default="", help="dec/enc test")
    parser.add_argument("-s","--spec",   default="", help="spec")
    # dec
    parser.add_argument("--tag",    default="", help="dec tag")
    parser.add_argument("--width",  default="", help="width")
    parser.add_argument("--height", default="", help="height")
    # enc

    # 解析命令行参数
    args = parser.parse_args()

    # 使用参数
    print("======> cmd paras <======")
    print(args)
    print()

    return args


def main():
    args = proc_paras()

    cfg_srv = yaml_cfg.YamlCfgService("config.yaml")

    # 更新信息
    # cfg_srv.dec_set_video_property("/videos/test1", "video1.h264", "height", 1088)
    # cfg_srv.dec_set_video_property("/videos/test1", "video1.h264", "spec", "h264")
    # cfg_srv.dec_set_video_property("/videos/test2", "video3.h264", "height", 1088)
    # cfg_srv.save()

    for path in cfg_srv.dec_get_all_paths():
        if "base" not in cfg_srv.dec_get_tags_for_path(path):
            break
        for video in cfg_srv.dec_get_videos_for_path(path):
            full_path = os.path.join(path, video['name'])
            print(f"======> cur video: {full_path}")
            # yuv_out = full_path + ".decoded.yuv"
            # decode_video(full_path, yuv_out)
            # verify_all(yuv_out, video)

    # 遍历所有视频
    for path, video in cfg_srv.dec_get_all_videos():
        print(f"{path}/{video['name']}")

    # 获取某路径下指定名称的视频
    # video1 = cfg_srv.dec_get_video_by_name("/videos/test1", "video1.h264")
    # print(video1["width"], video1.get("md5"))

if __name__ == "__main__":
    main()
