#!/opt/homebrew/anaconda3/bin/python
# 程序说明：
# 从一个或者多个文件中读取一列数字，检查这一列数字是否为递增、将数据去重排序、将数据绘制到同一个坐标系中
# usage: <app> <file1> <file2> <file3>
import sys
import numpy as np
import math
import matplotlib.pyplot as plt

def loadData(fname):
    f = open(fname)
    lines = f.readlines()
    
    nums = []
    for line in lines:
        cur = int(line.strip('\n'))
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

def delRepAndSort(nums):
    newNums = list(set(nums))
    newNums.sort()
    # print(nums)
    # print(newNums)
    return newNums

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

global_color  = ['b', 'g', 'r', 'c', 'm', 'y', 'k', 'w']
global_marker = ['.', 'o', 'v', '^', '<', '1', '2', '3', '4', '8', ',']
tab_loc_ha = ['center', 'right', 'left']
tab_loc_va = ['center', 'top', 'bottom', 'baseline', 'center_baseline']

def plotVal(fileNames, dataGrp):
    if len(fileNames) != len(dataGrp):
        print("error: file cnt and data cnt is not equal")
        print("file cnt is %d data cnt is %d" % (len(fileNames), (len(dataGrp))))
        return

    fig = plt.figure()  # an empty figure with no Axes
    ax = fig.add_subplot()
    loopCnt = len(fileNames)

    for i in range(loopCnt):
        x = list(range(len(dataGrp[i])))
        ax.plot(x, dataGrp[i], marker=global_marker[i%len(global_marker)], \
                color=global_color[i%len(global_color)], linestyle='', \
                label=fileNames[i])  # Plot some data on the axes.
        for a, b in zip(x, dataGrp[i]):
            tab_loc_x = int(i / len(tab_loc_va))
            tab_loc_y = int(i % len(tab_loc_va))
            ax.text(a, b, (a, b), fontsize=10, ha=tab_loc_ha[tab_loc_x], \
                    va=tab_loc_va[tab_loc_y], color=global_color[i%len(global_color)])

    ax.legend()  # Add a legend.
    plt.axhline(10, linestyle='--', c='red')
    plt.axhline(20, linestyle='--', c='c')
    plt.axvline(10)
    plt.show()


def main():
    # dataGrpCnt = int(input("Please enter the cnt of data group: "))
    # fileNames = []
    # for i in range(dataGrpCnt):
    #     filename = str(input("Please enter file %d name: " % i))
    #     fileNames.append(filename)

    dataGrpCnt = len(sys.argv) - 1
    fileNames = []
    for i in range(dataGrpCnt):
        fileNames.append(str(sys.argv[i+1]))

    dataGrp =  loadDataGrp(fileNames)
    print("==================== result ====================")
    for i in range(dataGrpCnt):
        print("====> %s <====" % fileNames[i])
        print("cnt: %d" % (len(dataGrp[i])))
        print("avg: %d" % np.mean(dataGrp[i]))
        dataGrp[i] = delRepAndSort(dataGrp[i])
        checkNumsInc(dataGrp[i])
        
    print()
    plotVal(fileNames, dataGrp)


if __name__ == '__main__':
    main()
