#!/bin/python3
#########################################################################
# File Name: 14.align.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Dec 26 16:24:05 2023
#########################################################################

def align_data(val, align):
    val = int((val + align - 1) / align) * align
    return val

def alignDiv(val, align):
    return int(align_data(val, align) / align)

if __name__ == '__main__':
    # print("{} {}".format(align_data(4, 8), alignDiv(4, 8)))
    print("{}".format(alignDiv(192, 256) * alignDiv(200, 16) * 8192))
