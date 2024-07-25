#!env python
#########################################################################
# File Name: compareBs.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed May 31 14:24:21 2023
#########################################################################
# usage:
#       python ./% <beginFrm> <endFrm> <ctuSize>

import sys, os

mc_file_line_idx = 0
dblk_file_line_idx = 0

def initDic(m_dic, ctuSize):
    for x in range(ctuSize / 4):
        for y in range(ctuSize / 4):
            m_dic[(x, y)] = [0, 0, 0]


def readBit(begin, end, m_str):
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
    return int(data_bin_str[begin_idx : end_idx], 2)

def readBsFromMc(bs_dic, file):
    global mc_file_line_idx
    while True:
        line = file.readline()
        if (not line):
            print("mc reach file eof line:%d" % (mc_file_line_idx))
            return
        mc_file_line_idx += 1

        bsV = readBit(0, 0, line)
        bsH = readBit(1, 1, line)
        loc_x = readBit(4, 7, line)
        loc_y = readBit(8, 11, line)

        endFlag = readBit(12, 12, line)
        plane = readBit(24, 25, line)
        if endFlag:
            break
        if plane != 0:
            continue

        bs_dic[(loc_x, loc_y)] = [bsH, bsV, mc_file_line_idx]

    return



def readBsFromDblk(bs_dic, file, ctu_size):
    global dblk_file_line_idx
    # x_range = ctu_size / 4;
    # y_range = ctu_size / 4;

    # for y in range(y_range):
    #     for x in range(x_range):
    #         line = file.readline()
    #         if (not line):
    #             print("dblk reach file eof")
    #             return
    #         dblk_file_line_idx += 1
    #         bsV = readBit(0, 0, line)
    #         bsH = readBit(1, 1, line)
    #         bs_dic[(x, y)] =  [bsH, bsV, dblk_file_line_idx]

    while True:
        line = file.readline()
        if (not line):
            print("dblk reach file eof line:%d" % (dblk_file_line_idx))
            return
        dblk_file_line_idx += 1

        bsV = readBit(0, 0, line)
        bsH = readBit(1, 1, line)
        loc_x = readBit(8, 11, line)
        loc_y = readBit(12, 15, line)

        endFlag = readBit(4, 7, line)
        if endFlag:
            break

        bs_dic[(loc_x, loc_y)] = [bsH, bsV, dblk_file_line_idx]



def compareBs(dic_a, dic_b):
    result = True

    for key, val in dic_a.items():
        if val[0:2] != dic_b[key][0:2]:
            print("pix loc in ctu:[x:{} y:{}]".format(key[0] * 4, key[1] * 4))
            print("mc bsV:%d bsH:%d lineIdx in file:%d" % (val[1], val[0], val[2]))
            print("dblk bsV:%d bsH:%d lineIdx in file:%d" % (dic_b[key][1], dic_b[key][0], dic_b[key][2]))
            result = False

    return result

def main():
    if (int(len(sys.argv) - 1 < 2)):
        print("error: arg cnt {} < 2".format(len(sys.argv) - 1))
        print("usage:")
        print("    python ./% <beginFrm> <endFrm> [<ctuSize>]    ctuSize default is 64")
        exit(0)
    begin = int(sys.argv[1])
    end = int(sys.argv[2])
    ctuSize = 64
    if (int(len(sys.argv) - 1 >= 3)):
        ctuSize = int(sys.argv[3])

    mc_bs = {}
    dblk_bs = {}

    for frmIdx in range(end - begin + 1):
        # file frame
        rootDir = "testOut/Frame"
        mc_file = rootDir + str(frmIdx + begin).zfill(4) + "/mc_data_bs_out.dat"
        dblk_file = rootDir + str(frmIdx + begin).zfill(4) + "/filterd_inter_luma_bs.dat"

        if os.path.exists(mc_file):
            file_mc = open(mc_file, mode='r')
        else:
            print("file %s is not exit" % (mc_file))
            exit(0)
        if os.path.exists(dblk_file):
            file_dblk = open(dblk_file, mode='r')
        else:
            print("file %s is not exit" % (dblk_file))
            exit(0)
        file_mc.seek(0, 2)
        file_dblk.seek(0, 2)
        mc_eof = file_mc.tell()
        dblk_eof = file_dblk.tell()

        file_mc.seek(0)
        file_dblk.seek(0)
        print("")
        print("======> frame %d <======" % (frmIdx + begin))
        print("==> mc file:{}".format(mc_file))
        print("==> dblk file:{}".format(dblk_file))
        global mc_file_line_idx
        global dblk_file_line_idx
        mc_file_line_idx = 0
        dblk_file_line_idx = 0

        # ctu
        ctuIdx = 0
        while True:
            initDic(mc_bs, ctuSize)
            initDic(dblk_bs, ctuSize)
            if ((file_mc.tell() >= mc_eof and file_dblk.tell() < dblk_eof)
                or (file_mc.tell() < mc_eof and file_dblk.tell() >= dblk_eof)):
                print("error: file not meet eof together!")
                print("mc:%d mc_eof:%d dblk:%d dblk_eof:%d"
                        % (file_mc.tell(), mc_eof, file_dblk.tell(), dblk_eof))
                exit(-1)
            if (file_mc.tell() >= mc_eof and file_dblk.tell >= dblk_eof):
                break
            readBsFromMc(mc_bs, file_mc)
            readBsFromDblk(dblk_bs, file_dblk, ctuSize)
            result = compareBs(mc_bs, dblk_bs)
            if result:
                print("ctu:{} compare pass".format(ctuIdx))
            else:
                print("ctu:{} compare error".format(ctuIdx))
            ctuIdx += 1

if __name__ == "__main__":
    main()
