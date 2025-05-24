#!/usr/bin/env python
#########################################################################
# File Name: decoder.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:58:55 PM CST
#########################################################################

import subprocess

def decode_video(input_file, output_file):
    cmd = [
        "ffmpeg", "-y", "-i", input_file,
        "-c:v", "rawvideo", "-pix_fmt", "yuv420p",
        output_file
    ]
    subprocess.run(cmd, check=True)
