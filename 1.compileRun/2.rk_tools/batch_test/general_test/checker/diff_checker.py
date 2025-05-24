#!/usr/bin/env python
#########################################################################
# File Name: diff_checker.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 05:00:14 PM CST
#########################################################################

def verify_diff(yuv1_path, yuv2_path, width, height, threshold=2):
    frame_size = width * height * 3 // 2
    with open(yuv1_path, 'rb') as f1, open(yuv2_path, 'rb') as f2:
        frame_index = 0
        while True:
            d1 = f1.read(frame_size)
            d2 = f2.read(frame_size)
            if not d1 or not d2:
                break
            if len(d1) != len(d2):
                print(f"[DIFF FAIL] Frame size mismatch at frame {frame_index}")
                return
            diffs = sum(abs(a - b) > threshold for a, b in zip(d1, d2))
            if diffs > 0:
                print(f"[DIFF FAIL] Frame {frame_index} has {diffs} differing bytes.")
                return
            frame_index += 1
    print(f"[DIFF PASS] {yuv1_path} vs {yuv2_path}")
