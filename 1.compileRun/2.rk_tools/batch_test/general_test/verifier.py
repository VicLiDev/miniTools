#!/usr/bin/env python
#########################################################################
# File Name: verifier.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:59:22 PM CST
#########################################################################

from checker.md5_checker import verify_md5
from checker.diff_checker import verify_diff
from checker.demo_checker import verify_demo

def verify_all(yuv_path, video_info):
    if "md5" in video_info:
        verify_md5(yuv_path, video_info["md5"])
    if "reference_yuv" in video_info:
        verify_diff(yuv_path, video_info["reference_yuv"],
                    video_info["width"], video_info["height"])
    if "demo_info" in video_info:
        verify_demo(yuv_path, video_info["demo_info"])
