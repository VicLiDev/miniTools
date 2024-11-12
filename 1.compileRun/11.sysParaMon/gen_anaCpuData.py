#!/usr/bin/env python
#########################################################################
# File Name: gen_anaCpuData.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Nov 2024 11:00:54 AM CST
#########################################################################

def read_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    # data_dict = {cpu: [[sample1], [sample2],...],
    #              cpu0: [[sample1], [sample2],...]
    #              cpu2: [[sample1], [sample2],...]
    #             }
    data_dict = {}
    with open(filename, 'r') as file:
        for line in file:
            if line[:3] == "cpu":
                cur_line_l = line.strip().split()

                if cur_line_l[0] not in data_dict:
                    data_dict[cur_line_l[0]] = []
                idx = cur_line_l[0]
                cur_line_l.pop(0)
                data_dict[idx].append(list(map(int, cur_line_l[:])))
    return data_dict

# 每一行中的字段表示：
# user：用户态时间（不包含 nice 值调整过的进程）
# nice：nice 值调整过的用户态时间
# system：系统态时间（内核态时间）
# idle：空闲时间
# iowait：等待 I/O 操作时间
# irq：硬中断时间
# softirq：软中断时间
# steal：虚拟化环境中等待实际 CPU 时间
# guest：虚拟 CPU 用户态时间
# guest_nice：nice 值调整过的虚拟 CPU 用户态时间
#
# CPU 占用率的计算公式为：
# CPU Usage = (total_delta − idle_delta) / total_delta x 100%
# 其中：
# total_delta 是两次采样之间 CPU 时间的总变化，即所有时间统计字段的总和变化。
# idle_delta 是两次采样之间空闲时间的变化，通常包括 idle 和 iowait 两个字段。
def calcCpuUsage(data):
    usage = {}

    for cpu_id in data:
        usage[cpu_id] = []
        for loop in range(len(data[cpu_id]) - 1):
            prev = data[cpu_id][loop]
            curr = data[cpu_id][loop + 1]

            # 计算 total 和 idle 时间的差异
            prev_total = sum(prev)
            curr_total = sum(curr)

            prev_idle = prev[3] + prev[4]  # idle + iowait
            curr_idle = curr[3] + curr[4]

            total_delta = curr_total - prev_total
            idle_delta = curr_idle - prev_idle

            if total_delta > 0:
                usage[cpu_id].append(100 * (total_delta - idle_delta) / total_delta)
            else:
                usage[cpu_id].append(-1)

    return usage

import matplotlib.pyplot as plt
import numpy as np

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

'''
fileNames = ["file1.txt", "file2.txt"]
mDataGrp = [[1, 2, 3, 4],
            [4, 3, 2, 6]]
plotVal(fileNames, mDataGrp, refLineEn = [True, True], refLine = [2, 3], \
        showName = True, showTag = True, showLine = True, calcAvg = True)
'''

def main():
    data = read_data("gen_cpudata.txt")
    usage = calcCpuUsage(data)

    # dump data
    cpu_list = list(usage.keys())
    # join 用于将 可迭代对象（如列表、元组、集合等）中的元素连接为一个字符串
    # 基本语法
    # str.join(iterable)
    # str：分隔符字符串，用于连接每个元素。
    # iterable：一个可迭代对象，如列表、元组、集合等。其中的元素必须是字符串类型。
    print(" ".join([f"{cpu_id:>7}" for cpu_id in cpu_list]))
    for loop in range(len(usage[cpu_list[0]])):
        tmp = []
        for idx in cpu_list:
            tmp.append(usage[idx][loop])
        print(" ".join([f"{u:>6.2f}%" for u in tmp]))
    # print(" ".join([f"{cpu_id:>7}" for cpu_id in cpu_list]))

    # # plot
    # dataTag = []
    # mDataGrp = []
    # for idx in usage:
    #     dataTag.append(idx)
    #     mDataGrp.append(usage[idx])
    # plotVal(dataTag, mDataGrp, showLine = True)
    # # print(data.keys())
    # # print(data['cpu'])


if __name__ == "__main__":
    main()
