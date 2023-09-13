#!/bin/python3
#########################################################################
# File Name: 11.genCmdParaByBit.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Sep 13 10:18:22 2023
#########################################################################

if __name__ == '__main__':
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
