#!env python

'''
ex: echo "12 8" | python ./14.pip_display.py >> /dev/ttys001
    cat tmp.txt | awk '{print $2,$3}' | python ./14.pip_display.py >> /dev/ttys001
'''

import os
import sys
import time

def init_pic(frmW, frmH, flag, delay=0):
    for y in range(frmH):
        for x in range(frmW):
            # prn is 1-base
            print('\033[{};{}H'.format(y + 1, x + 1) + flag, end="", flush=True)
            time.sleep(delay)
        print()

def modify_pix(x, y, flag, delay=0):
    time.sleep(delay)
    print('\033[{};{}H'.format(y, x) + flag, end="", flush=True)


if __name__ == '__main__':
    os.system('')  # start VT-100 in windows console
    os.system('clear')

    frmW = 192
    frmH = 100
    div = 4
    if (frmW % div):
        frmW = int(frmW / div + 1)
    else:
        frmW = int(frmW / div)
    if (frmH % div):
        frmH = int(frmH / div + 1)
    else:
        frmH = int(frmH / div)

    init_pic(frmW, frmH, "-")
    # modify_pix(5, 3, "x")

    loc_x = 0
    loc_y = 0
    for line in sys.stdin:
        nums = line.split()
        loc_x = int(nums[0])
        loc_y = int(nums[1])
        # print("x:{}y:{}".format(int(loc_x/div+1), int(loc_y/div+1)))
        modify_pix(int(loc_x/div+1), int(loc_y/div+1), "x", 0.2)

