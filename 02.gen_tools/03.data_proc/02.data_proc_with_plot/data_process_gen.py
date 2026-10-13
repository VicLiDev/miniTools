#!/usr/bin/env python
# 程序说明：
# 从一个或者多个文件中读取一列数字，检查这一列数字是否为递增、将数据去重排序、将数据绘制到同一个坐标系中
# usage: <app> <file1> <file2> <file3>
import sys,getopt
import numpy as np
import math
import matplotlib.pyplot as plt

def loadData(fname):
    f = open(fname)
    lines = f.readlines()

    nums = []
    for line in lines:
        cur = float(line.strip('\n'))
        nums.append(cur)

    return nums

def loadDataGrp(fnames):
    dataGrp = []

    for i in range(len(fnames)):
        nums = loadData(fnames[i])
        dataGrp.append(nums)

    return dataGrp

def dumpListToFile(fname, ldata):
    f = open(fname, "w")
    for i in ldata:
        f.write(str(i)+"\n")
    f.close()

def compList(list1, list2):
    print("list1 size %d list2 size %d" % (len(list1), len(list2)))
    loopMax = len
    if len(list1) < len(list2):
        loopMax = len(list1)
    else:
        loopMax = len(list2)

    print("list1 != list2 in index ", end='')
    for i in range(loopMax):
        if list1[i] != list2[i]:
            print(" ", i, end='')
    print()

def sortPoints(nums, delRep):
    nums.sort()
    if delRep == True :
        # 先将列表转换为集合，因为集合是不重复的，故直接删除重复元素
        return list(set(nums))
    return nums

def checkNumsInc(nums):
    lineNum = 0
    prev = 0
    cur = 0
    print("not increase in lineNum: ", end = '')
    for i in range(len(nums)):
        lineNum = lineNum + 1
        cur = nums[i]
        if prev > cur:
            print(" ", lineNum, end='')
        prev = cur
    print()
    return

global_color  = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
global_marker = ['.', 'o', 'v', '^', '<', '1', '2', '3', '4', '8', ',']
global_line_s = ['-', '--', '-.', ':']
tab_loc_ha = ['center', 'right', 'left']
tab_loc_va = ['center', 'top', 'bottom', 'baseline', 'center_baseline']

def plotVal(fileNames, dataGrp, refLineEn = [False, False], refLine = [0, 0], \
            showName = False, showTag = False, showLine = False, calcAvg = False):
    if len(fileNames) != len(dataGrp):
        print("error: file cnt and data cnt is not equal")
        print("file cnt is %d data cnt is %d" % (len(fileNames), (len(dataGrp))))
        return

    fig = plt.figure()  # an empty figure with no Axes
    ax = fig.add_subplot()
    loopCnt = len(fileNames)

    for i in range(loopCnt):
        line_style = ['']
        if showLine == True:
            line_style = global_line_s
        x = list(range(len(dataGrp[i])))
        ax.plot(x, dataGrp[i], marker=global_marker[i%len(global_marker)], \
                color=global_color[i%len(global_color)], \
                linestyle=line_style[i%len(line_style)], \
                alpha=1/2, \
                label=fileNames[i])  # Plot some data on the axes.
        if showName == True:
            fname_plt_idx = int(len(x) / 2)
            fname_plt_point_x = x[fname_plt_idx]
            fname_plt_point_y = dataGrp[i][fname_plt_idx]
            plt.text(fname_plt_point_x, fname_plt_point_y, fileNames[i], \
                     fontsize=12, color=global_color[i%len(global_color)], \
                     ha="right", va="bottom")

        if showTag == True:
            for a, b in zip(x, dataGrp[i]):
                tab_loc_x = int(i / len(tab_loc_va))
                tab_loc_y = int(i % len(tab_loc_va))
                ax.text(a, b, (a, b), fontsize=10, ha=tab_loc_ha[tab_loc_x], \
                        va=tab_loc_va[tab_loc_y], color=global_color[i%len(global_color)])
        if calcAvg == True:
            avg = np.mean(dataGrp[i])
            plt.axhline(avg, color=global_color[i%len(global_color)], linestyle="dashdot", label="avg: "+str(avg))

        ax.legend()  # Add a legend.

    if refLineEn[0] == True:
        plt.axhline(refLine[0], linestyle='--', c='r')
    if refLineEn[1] == True:
        plt.axvline(refLine[1], linestyle='--', c='orangered')

    plt.show()

def help():
    print('opt:')
    print('  -h,--help  print help info')
    print('  -s     sort and delete repeate data')
    print('  --hl   add horizontal reference line')
    print('  --vl   add vertical reference line')
    print('  -n     display file name in point')
    print('  -t     display point tag')
    print('  -d     display diff')
    print('  -l     display line')
    print('  -a     display avg')
    print('  -f     input file')

def main(argv):

    # print('para num :', len(sys.argv))
    # print('para list:', str(sys.argv))

    # control para
    drAndSort = False
    refLineEn = [False, False] # [hor, ver]
    refLine = [0, 0] # [hor, ver]
    showName = False
    showTag = False
    showLine = False
    calcDiff = False
    calcAvg = False
    fileNames = []
    dataGrpCnt = 0

    try:
        opts, args = getopt.getopt(argv,"hsf:ntlad", ["help=", "hl=", "vl="])
    except getopt.GetoptError:
        help()
        sys.exit(2)

    for opt, arg in opts:
        if opt in ("-h", "--help"):
            help()
            sys.exit()
        elif opt in ("-s"):
            drAndSort = True
        elif opt in ("--hl"):
            refLineEn[0] = True
            refLine[0] = float(arg)
        elif opt in ("--vl"):
            refLineEn[1] = True
            refLine[1] = float(arg)
        elif opt in ("-n"):
            showName = True
        elif opt in ("-t"):
            showTag = True
        elif opt in ("-l"):
            showLine = True
        elif opt in ("-d"):
            calcDiff = True
        elif opt in ("-a"):
            calcAvg = True
        elif opt in ("-f"):
            fileNames.append(str(arg))
            dataGrpCnt += 1

    if dataGrpCnt == 0:
        help()
        sys.exit(0)


    dataGrp =  loadDataGrp(fileNames)
    print("==================== result ====================")
    for i in range(dataGrpCnt):
        print("====> %s <====" % fileNames[i])
        print("cnt: %d" % (len(dataGrp[i])))
        print("avg: %d" % np.mean(dataGrp[i]))
        # print("sum: %d" % sum(dataGrp[i]))
        if drAndSort == True:
            dataGrp[i] = sortPoints(dataGrp[i], False)
        if calcDiff == True:
            for j in range(len(dataGrp[i])-1):
                dataGrp[i][j] = dataGrp[i][j+1] - dataGrp[i][j]
            dataGrp[i].pop()
        checkNumsInc(dataGrp[i])

    print()
    plotVal(fileNames, dataGrp, refLineEn, refLine, showName, showTag, showLine, calcAvg)


if __name__ == '__main__':
    main(sys.argv[1:])   # 过滤掉命令行中的文件名
