#!/opt/homebrew/anaconda3/bin/python

# conver 16 hexadecimal bit to 10 hexadecimal val

import ctypes

while True:
    val = input('input 16 hexadecimal or q(quit):').strip()
    if val == 'q':
        exit(0)
    if val == '':
        continue

    try:
        if val[:2] == '0x' or val[:2] == '0X':
            if (len(val) < 6) : # 10 bit
                num = int(val, 16)
                if int(val, 16) & 0x200:
                    num = num | 0xfc00
                print("10 hexadecimal 10bit: %d" % ( ctypes.c_int16(num).value) )
            else :  # 45 bit
                num = int(val, 16)
                if int(val, 16) & 0x100000000000:
                    num = num | 0xffffe00000000000
                print("10 hexadecimal 45bit: %d" % ( ctypes.c_int64(num).value) )
        print()
    except:
        print("invalue input {}".format(val))
        print()
        continue
