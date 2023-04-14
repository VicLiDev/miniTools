#!/usr/bin/python

'''
cat log.txt | python 15.splitHexStr.py
'''

import os
import sys
import time

# def global data:   x, y ctuidx all info

def get_bit(st, ed):
    pass

def load_field(st, end, field_name):
    # read from file
    # add to global data
    pass

def readfile(fName):
    pass
    load_field(fName, st, end, field_name)

if __name__ == '__main__':
    for line in sys.stdin:
        nums_str = line.split()
        nums_str_bin_src = ""
        nums_str_bin_dst = ""
        
        # convert to bin
        for loop in range(len(nums_str[0][0:16])):
            nums_str_bin_src += str(bin(int(nums_str[0][loop], 16))[2:]).zfill(4)

        # split with space
        for loop in range(len(nums_str_bin_src[0:48])):
            if loop % 6 == 0:
                nums_str_bin_dst += " "
            nums_str_bin_dst += nums_str_bin_src[loop]

        print(nums_str_bin_src)
        # split with space
        nums_str_bin_dst += " "
        nums_str_bin_dst += nums_str_bin_src[48]
        nums_str_bin_dst += " "
        nums_str_bin_dst += nums_str_bin_src[49:56]
        nums_str_bin_dst += " "
        nums_str_bin_dst += nums_str_bin_src[56]
        nums_str_bin_dst += " "
        nums_str_bin_dst += nums_str_bin_src[57:64]

        print(nums_str_bin_dst)

