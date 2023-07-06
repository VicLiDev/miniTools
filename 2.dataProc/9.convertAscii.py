#!/bin/python3
#########################################################################
# File Name: 9.convertAscii.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Jun 28 14:10:45 2023
#########################################################################

'''
intput:123
intput:0x9313233
0x9313233 mean 0x9 0x31 0x32 0x33
'''

if __name__ == '__main__':
    while True:
        val = input('\ninput ascii(ex:123) or hex(ex:0x93035) or q(quit):').strip()
        if val == 'q':
            exit(0)
        if val == '':
            continue

        try:
            if val[:2] == '0x' or val[:2] == '0X':
                hexdataTmp = val[2:]
                hexdatalist = []
                chrdatalist = []
                while len(hexdataTmp):
                    if len(hexdataTmp) % 2:
                        hexdatalist.append(hexdataTmp[0:1])
                        chrdatalist.append(chr(int(hexdataTmp[0:1], 16)))
                        hexdataTmp = hexdataTmp[1:]
                    else:
                        hexdatalist.append(hexdataTmp[0:2])
                        chrdatalist.append(chr(int(hexdataTmp[0:2], 16)))
                        hexdataTmp = hexdataTmp[2:]
                # print(hexdatalist)
                print("convert hex {} to ascii:{}".format(val, chrdatalist))
            else:
                outdataHex = []
                outdataDec = []
                outdataOct = []
                for idx in range(len(val)):
                    outdataHex.append(hex(ord(val[idx])))
                    outdataDec.append(ord(val[idx]))
                    outdataOct.append(oct(ord(val[idx])))
                print("convert ascii {} to Hex:{} Dec:{} Oct:{}".format(val, outdataHex, outdataDec, outdataOct))
        except:
            print("invalue input {}".format(val))
            print()
            continue
