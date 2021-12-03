# 程序说明：
# 从文件中读取一列数字，检查这一列数字是否为递增
import numpy as np
import math

def checkSort(fname):
    f = open(fname)
    lines = f.readlines()
    
    lineNum = 0
    prev = 0
    cur = 0
    for line in lines:
        lineNum = lineNum + 1
        cur = int(line.strip('\n'))
        if prev > cur:
            print("not increase in lineNum:", lineNum)

        prev = cur
    return

def main():
    filename = str(input("Please enter file name: "))
    checkSort(filename)

if __name__ == '__main__':
    main()

