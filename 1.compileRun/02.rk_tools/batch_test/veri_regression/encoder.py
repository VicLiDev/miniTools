#!/usr/bin/env python
#########################################################################
# File Name: encoder.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 27 May 2025 07:58:39 PM CST
#########################################################################

class EncExecutor:
    def __init__(self):
        self.mpp_spec_map = {"hevc" : 16777220,
                             "h265" : 16777220,
                             "avc"  : 7,
                             "h264" : 7,
                             "vp9"  : 10,
                             "av1"  : 16777224,
                             "avs2" : 16777223}

    def setup(self):
        pass

    def run(self):
        pass
