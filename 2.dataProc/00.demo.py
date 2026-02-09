#!/bin/python3
#########################################################################
# File Name: 00.demo.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Dec 26 16:24:05 2023
#########################################################################

# 保存一些可以记录，但又不足以作为一个demo的内容

def align_data(val, align):
    val = int((val + align - 1) / align) * align
    return val

def alignDiv(val, align):
    return int(align_data(val, align) / align)

def genCmdParaByBit():
    para = 0;
    while True:
        val = input('to set bit or q(quit): ').strip()
        if val == 'q':
            exit(0)
        if val == '':
            continue

        bitloc = int(val)
        para |= 1 << bitloc
        print("final para: 0x%x" % (para))

if __name__ == '__main__':
    # print("{} {}".format(align_data(4, 8), alignDiv(4, 8)))
    print("{}".format(alignDiv(192, 256) * alignDiv(200, 16) * 8192))
