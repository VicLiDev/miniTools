# 程序说明：
# 从文件中读取一列数据，并以该值为y轴，绘制到坐标系中
import matplotlib.pyplot as plt
import numpy as np

def plotPts(ldata, ldata2):
    fig = plt.figure()  # an empty figure with no Axes
    ax = fig.add_subplot()

    x = list(range(len(ldata)))
    ax.plot(x, ldata, marker=".", color="r", linestyle='', label='data1')  # Plot some data on the axes.
    print("data size:", len(ldata))

    x2 = list(range(len(ldata2)))
    ax.plot(x2, ldata2, marker=".", color="g", linestyle='', label='data2')  # Plot some data on the axes.
    print("data2 size:", len(ldata2))
    
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
    filename = str(input("Please enter file name: "))
    nums = loadData(filename)
    filename = str(input("Please enter file2 name: "))
    nums2 = loadData(filename)
    plotPts(nums, nums2)

if __name__ == '__main__':
    main()
