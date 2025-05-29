#!/usr/bin/env python
#########################################################################
# File Name: diff_checker.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 05:00:14 PM CST
#########################################################################

def diff_verify(yuv1_path, yuv2_path, width, height, pix_fmt, org_file, threshold=2):
    if pix_fmt == "nv12":
        frame_size = width * height * 3 // 2
    elif pix_fmt == "yuvj440p":
        frame_size = width * height * 2
    else:
        print("error: unsupport fmt")

    if width % 2 or height % 2:
        print("\033[0m\033[1;33mwarning\033[0m: width/height is odd number")

    with open(yuv1_path, 'rb') as f1, open(yuv2_path, 'rb') as f2:
        frm_idx = 0
        while True:
            d1 = f1.read(frame_size)
            d2 = f2.read(frame_size)
            if not d1 or not d2:
                break
            if len(d1) != len(d2):
                print(f"[\033[0m\033[1;31m DIFF FAIL \033[0m] Frm size mismatch at frm {frm_idx} | {org_file}")
                return
            diffs = sum(abs(a - b) > threshold for a, b in zip(d1, d2))
            if diffs > 0:
                print(f"[\033[0m\033[1;31m DIFF FAIL \033[0m] Frm {frm_idx} has {diffs} differing bytes | {org_file}")
                return
            frm_idx += 1
    print(f"[\033[0m\033[1;32m DIFF PASS \033[0m] {yuv1_path} vs {yuv2_path} | {org_file}")
