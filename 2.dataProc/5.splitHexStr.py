#!env python

'''
cat log.txt | python 15.splitHexStr.py
echo "abc" | python 5.splitHexStr.py
'''

import os
import sys
import time

def readBit(begin, end, m_str, retStr = False):
    data_bin_str = ""
    m_str = m_str.strip()
    for loop in range(len(m_str)):
        strtmp = m_str[loop]
        data16 = int(strtmp, 16)
        data_bin = bin(data16)[2:]
        data_str = str(data_bin).zfill(4)
        data_bin_str += data_str
    begin_idx = len(data_bin_str) - end - 1
    end_idx = len(data_bin_str) - begin 
    if retStr == True:
        return data_bin_str[begin_idx : end_idx]
    else :
        return int(data_bin_str[begin_idx : end_idx], 2)

if __name__ == '__main__':
    for line in sys.stdin:
        nums_str_hex = line.split()[0]
        nums_str_bin_src = ""
        nums_str_bin_dst_split = ""

        # convert to bin
        for loop in range(len(nums_str_hex)):
            nums_str_bin_src += str(bin(int(nums_str_hex[loop], 16))[2:]).zfill(4)

        # split with space
        for loop in range(len(nums_str_bin_src)):
            if loop % 4 == 0:
                nums_str_bin_dst_split += " "
            nums_str_bin_dst_split += nums_str_bin_src[loop]

        print("origin data:{}".format(nums_str_hex))
        print("bin data:{}".format(nums_str_bin_src))
        print("bin data split by spc:{}".format(nums_str_bin_dst_split))

        # dump data test
        print()
        print("read bit test:")
        print("{}".format(readBit(1, 3, nums_str_hex, True)), end="")
        print(" ", end="")
        print("{}".format(readBit(0, 0, nums_str_hex, True)), end="")
        print()
        print("{}".format(readBit(0, 3, nums_str_hex)))
