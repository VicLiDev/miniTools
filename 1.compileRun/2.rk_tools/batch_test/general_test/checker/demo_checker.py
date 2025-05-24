#!/usr/bin/env python
#########################################################################
# File Name: demo_checker.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:59:53 PM CST
#########################################################################

import hashlib

def md5_frame(frame_bytes):
    return hashlib.md5(frame_bytes).hexdigest()

def verify_demo(yuv_path, demo_path, width=1920, height=1080):
    frame_size = width * height * 3 // 2
    with open(demo_path, 'r') as ref_file:
        ref_md5_list = [line.strip() for line in ref_file.readlines()]
    with open(yuv_path, 'rb') as f:
        frame_index = 0
        for expected_md5 in ref_md5_list:
            frame = f.read(frame_size)
            if not frame:
                print(f"[DEMO FAIL] Unexpected end of file at frame {frame_index}")
                return
            actual_md5 = md5_frame(frame)
            if actual_md5 != expected_md5:
                print(f"[DEMO FAIL] Frame {frame_index}: {actual_md5} ≠ {expected_md5}")
                return
            frame_index += 1
    print(f"[DEMO PASS] {yuv_path}")
