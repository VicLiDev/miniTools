#!/usr/bin/env python
#########################################################################
# File Name: all_anaCpuData.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 04:19:49 PM CST
#########################################################################

import subprocess

def run_command(command):
    """执行给定的 shell 命令并返回输出、错误和执行状态"""
    try:
        # 使用 subprocess.run() 执行命令
        result = subprocess.run(command, shell=True, check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # 返回标准输出、标准错误和执行状态
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        # 捕获并处理错误
        return e.stdout.strip(), e.stderr.strip(), e.returncode

'''
command = "echo \"hello\""
stdout, stderr, status = run_command(command)

# 输出命令的结果和状态
print("命令输出:\n", stdout)
print("错误输出:\n", stderr)
print("执行状态:", "成功" if status == 0 else f"失败 (状态码: {status})")
'''

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

'''
fileNames = ["file1.txt", "file2.txt"]
mDataGrp = [[1, 2, 3, 4],
            [4, 3, np.nan, 2, 6]]
plotVal(fileNames, mDataGrp, refLineEn = [True, True], refLine = [2, 3], \
        showName = True, showTag = True, showLine = True, calcAvg = True)
'''

def gen_load_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    data_dic = {}
    with open(filename, 'r') as file:
        cpu_list = file.readline().strip().split()
        for cpu_id in cpu_list:
            data_dic[cpu_id] = []
        for line in file:
            fields = list(map(float, line.strip().replace(" ", "").replace("%"," ").split()))
            loop = 0
            for cpu_id in cpu_list:
                data_dic[cpu_id].append(fields[loop])
                loop = loop + 1
    return data_dic

def gen_ana_data(data_dic):
    dataTag = []
    mDataGrp = []
    for key in data_dic:
        dataTag.append(key)
        mDataGrp.append([np.nan if v < 0 else v for v in data_dic[key]])
    plotVal(dataTag, mDataGrp, showLine = True)


def ins_load_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    data_lst = []
    with open(filename, 'r') as file:
        for line in file:
            fields = list(line.strip().replace(":", " ").replace("%"," ").split())
            data_lst.append([float(fields[1]), float(fields[3])])
    return data_lst

def ins_ana_data(data_lst):
    dataTag = ["cpu usage", "cpu id"]
    mDataGrp = [[np.nan if v[0] < 0 else v[0] for v in data_lst],
                [np.nan if v[1] < 0 else v[1] for v in data_lst]]
    plotVal(dataTag, mDataGrp, showLine = True)

def thd_load_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    data_lst = []
    with open(filename, 'r') as file:
        data_lst_tmp = []
        data_grp_tmp = []
        for line in file:
            fields = list(line.strip().replace(":", " ").replace("%"," ").split())
            if not len(fields):
                data_lst.append(data_grp_tmp)
                data_lst_tmp = []
                data_grp_tmp = []
                continue
            data_lst_tmp = [fields[1], float(fields[3]), int(fields[5]), fields[7]]
            data_grp_tmp.append(data_lst_tmp)
    return data_lst

def thd_ana_data_proc(data_lst, dic_id_field, dic_val_field):
    dataTag = []
    mDataGrp = []
    data_dic = {}

    for sublst1 in data_lst:
        for sublst2 in sublst1:
            if sublst2[dic_id_field] not in data_dic:
                data_dic[sublst2[dic_id_field]] = []
            if sublst2[dic_val_field] < 0:
                data_dic[sublst2[dic_id_field]].append(np.nan)
            else:
                data_dic[sublst2[dic_id_field]].append(sublst2[dic_val_field])

    dataTag = list(data_dic.keys())
    for cur_id in dataTag:
        mDataGrp.append(data_dic[cur_id])

    return dataTag,mDataGrp

def thd_ana_data(data_lst):
    # cpu_id
    dataTag_id,mDataGrp_id = thd_ana_data_proc(data_lst, 3, 2)
    plotVal(dataTag_id, mDataGrp_id, showLine = True)

    # cpu_usage
    dataTag_usg,mDataGrp_usg = thd_ana_data_proc(data_lst, 3, 1)
    plotVal(dataTag_usg, mDataGrp_usg, showLine = True)

    all_tag = [v+"_id" for v in dataTag_id] + [v+"_usage" for v in dataTag_usg]
    plotVal(all_tag, mDataGrp_id + mDataGrp_usg, showLine = True)


def main():
    genfname = "res_gen_data.txt"
    insfname = "res_ins_data.txt"
    thdfname = "res_thd_data.txt"

    command = f"./gen_anaCpuData.py > {genfname}"
    stdout, stderr, status = run_command(command)
    if status:
        print(f"error excute {command} status:{status}")
    command = f"./ins_anaCpuData.py > {insfname}"
    stdout, stderr, status = run_command(command)
    if status:
        print(f"error excute {command} status:{status}")
    command = f"./thd_anaCpuData.py > {thdfname}"
    stdout, stderr, status = run_command(command)
    if status:
        print(f"error excute {command} status:{status}")

    # gen data
    gen_data_dic = gen_load_data(genfname)
    gen_ana_data(gen_data_dic)
    # print(gen_data_dic)

    # ins data
    ins_data_lst = ins_load_data(insfname)
    ins_ana_data(ins_data_lst)

    # thd data
    thd_data_lst = thd_load_data(thdfname)
    thd_ana_data(thd_data_lst)

    plt.show()

if __name__ == "__main__":
    main()
