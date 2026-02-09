# 程序说明：
# 从文件中读取一列数据，并以该值为y轴，绘制到坐标系中
import matplotlib.pyplot as plt
import numpy as np

global_color = ['b', 'g', 'r', 'c', 'm', 'y', 'k', 'w']

def plotPts(fileNames, dataGrp):
    if len(fileNames) != len(dataGrp):
        print("error: file cnt and data cnt is not equal")
        print("file cnt is %d data cnt is %d" % (len(fileNames), (len(dataGrp))))
        return

    fig = plt.figure()  # an empty figure with no Axes
    ax = fig.add_subplot()
    loopCnt = len(fileNames)

    for i in range(loopCnt):
        x = list(range(len(dataGrp[i])))
        ax.plot(x, dataGrp[i], marker=".", color=global_color[i], linestyle='', label=fileNames[i])  # Plot some data on the axes.
        print("data %d size:%d" % (i, len(dataGrp[i])))

    ax.legend()  # Add a legend.
    plt.show()

def loadData(fname):
    f = open(fname)
    lines = f.readlines()
    
    nums = []
    for line in lines:
        cur = int(line.strip('\n'))
        nums.append(cur)

    return nums

def main():
    dataGrpNums = int(input("Please enter data groups of data: "))
    dataGrp = []
    fileNames = []
    for i in range(dataGrpNums):
        filename = str(input("Please enter file%d name: " % i))
        nums = loadData(filename)
        fileNames.append(filename)
        dataGrp.append(nums)

    plotPts(fileNames, dataGrp)

if __name__ == '__main__':
    main()
