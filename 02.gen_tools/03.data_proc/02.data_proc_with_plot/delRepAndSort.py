# 程序说明：
# 读取文件中的唯一一列数据，然后剔除重复元素，输出到另一个文件中
import numpy as np
import math

def dumpListToFile(fname, ldata):
    f = open(fname, "w")
    for i in ldata:
        f.write(str(i)+"\n")
    f.close()

def delRep(fname):
    f = open(fname)
    lines = f.readlines()

    nums = []
    for line in lines:
        cur = int(line.strip('\n'))
        nums.append(cur)

    newNums = list(set(nums))
    newNums.sort()
    # print(nums)
    # print(newNums)
    dumpListToFile("out"+fname, newNums)
    return

def main():
    filename = str(input("Please enter file name: "))
    delRep(filename)

if __name__ == '__main__':
    main()
