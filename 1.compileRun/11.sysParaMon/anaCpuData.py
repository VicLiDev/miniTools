#!/usr/bin/env python
#########################################################################
# File Name: anaCpuData.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 04:19:49 PM CST
#########################################################################

import subprocess
import matplotlib.pyplot as plt
import numpy as np


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

global_color  = ['b', 'g', 'r', 'c', 'm', 'y', 'k']
global_marker = ['.', 'o', 'v', '^', '<', '1', '2', '3', '4', '8', ',']
global_line_s = ['-', '--', '-.', ':']
tab_loc_ha = ['center', 'right', 'left']
tab_loc_va = ['center', 'top', 'bottom', 'baseline', 'center_baseline']

def plotVal(fileNames, dataGrp, refLineEn = [False, False], refLine = [0, 0], \
            showName = False, showTag = False, showLine = False, calcAvg = False,
            title = "Def Title"):
    if len(fileNames) != len(dataGrp):
        print("error: file cnt and data cnt is not equal")
        print("file cnt is %d data cnt is %d" % (len(fileNames), (len(dataGrp))))
        return

    fig = plt.figure()  # an empty figure with no Axes
    ax = fig.add_subplot()
    # 获取当前图像的 canvas 对象
    manager = fig.canvas.manager
    # 设置窗口标题
    manager.set_window_title(title)
    ax.set_title(title)  # Add a title to the axes.
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
def gen_calculate_cpu_usage(data):
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

def gen_ana_data(data_dic):
    dataTag = []
    mDataGrp = []
    for key in data_dic:
        dataTag.append(key)
        mDataGrp.append([np.nan if v < 0 else v for v in data_dic[key]])
    plotVal(dataTag, mDataGrp, title = "gen data", showLine = True, refLineEn = [True, False], refLine = [100, 0])

def gen_dump_data(gen_usage_data_dic):
    gen_cpu_list = list(gen_usage_data_dic.keys())
    # join 用于将 可迭代对象（如列表、元组、集合等）中的元素连接为一个字符串
    # 基本语法
    # str.join(iterable)
    # str：分隔符字符串，用于连接每个元素。
    # iterable：一个可迭代对象，如列表、元组、集合等。其中的元素必须是字符串类型。
    print(" ".join([f"{cpu_id:>7}" for cpu_id in gen_cpu_list]))
    for loop in range(len(gen_usage_data_dic[gen_cpu_list[0]])):
        tmp = []
        for idx in gen_cpu_list:
            tmp.append(gen_usage_data_dic[idx][loop])
        print(" ".join([f"{u:>6.2f}%" for u in tmp]))
    # print(" ".join([f"{cpu_id:>7}" for cpu_id in gen_cpu_list]))

def ins_load_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    # sys_usage = [sample1, sample2,...]
    # proc_usage = [[sample1_utime, sample1_stime],
    #              [sample2_utime, sample2_stime],...]
    # cpu_id = [sapple1, sample2,...]
    sys_usage = []
    proc_usage = []
    cpu_id = []
    with open(filename, 'r') as file:
        for line in file:
            if line[:4] == "uptm":
                sys_usage.append(float(line.split()[1]))
            elif line[:4] == "stat":
                fields = line.split()
                # 由于抓log时多加了一个 stat开头，所以这里的字段位置会+1
                proc_usage.append([int(fields[14]), int(fields[15])])
                cpu_id.append(int(fields[39]))
    return [sys_usage, proc_usage, cpu_id]

def ins_calculate_cpu_usage(data_lst):
    # 获取当前时间点的数据
    cpu_usages = []
    for loop in range(len(data_lst[0]) - 1):
        # 计算时间差
        proc_time_delta = sum(data_lst[1][loop + 1]) - sum(data_lst[1][loop])
        uptime_delta = data_lst[0][loop + 1] - data_lst[0][loop]

        # 防止除零错误
        if uptime_delta == 0:
            cpu_usages.append(-1)
            continue

        command="getconf CLK_TCK"
        stdout, stderr, status = run_command(command)
        clk_tck = int(stdout)

        # 计算 CPU 占用率
        cur_cpu_usage = 100 * (proc_time_delta / (uptime_delta * clk_tck))
        cpu_usages.append([cur_cpu_usage, data_lst[2][loop + 1]])
    return cpu_usages

def ins_ana_data(data_lst):
    dataTag = ["cpu usage", "cpu id"]
    mDataGrp = [[np.nan if v[0] < 0 else v[0] for v in data_lst],
                [np.nan if v[1] < 0 else v[1] for v in data_lst]]
    plotVal(dataTag, mDataGrp, title = "ins data", showLine = True, refLineEn = [True, False], refLine = [100, 0])

def ins_dump_data(ins_usages):
    for loop in range(len(ins_usages)):
        print(f"cpu_usage: {ins_usages[loop][0]:>5.2f}% Main_thd_cpu_id: {ins_usages[loop][1]}")

def thd_load_data(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    sys_usage = []
    thd_info = []

    # thd_info = [{thd_id:[utime, stime, cpu_id, thd_name]},
    #             {},...]

    info_dict_tmp = {}

    with open(filename, 'r') as file:
        for line in file:
            if line[:4] == "uptm":
                sys_usage.append(float(line.split()[1]))

                info_dict_tmp = {}
                thd_info.append(info_dict_tmp)
            elif line[:4] == "stat":
                fields = line.split()
                if len(fields) < 3:
                    print(f"Error: invalid line")
                    continue
                # 由于抓log时多加了一个 stat开头，所以这里的字段位置会+1
                if fields[1] not in info_dict_tmp:
                    info_dict_tmp[fields[1]] = [int(fields[14]), int(fields[15]), int(fields[39]), fields[2]]
                else:
                    print(f"Error: thd_id repeated!!")
    return [sys_usage, thd_info]

def thd_calculate_cpu_usage(data_lst):
    # 获取当前时间点的数据
    cpu_usages = []
    for loop in range(len(data_lst[0]) - 1):
        # 计算系统时间差
        uptime_delta = data_lst[0][loop + 1] - data_lst[0][loop]

        command="getconf CLK_TCK"
        stdout, stderr, status = run_command(command)
        clk_tck = int(stdout)

        # 计算 CPU 占用率
        cpu_usage_tmp = {}
        for key in data_lst[1][loop + 1]:
            if key in data_lst[1][loop]:
                # 计算线程时间差
                proc_time_delta = \
                        data_lst[1][loop + 1][key][0] + data_lst[1][loop + 1][key][1] \
                        - data_lst[1][loop][key][0] - data_lst[1][loop][key][1]

                cur_cpu_usage = -1
                if uptime_delta != 0:
                    cur_cpu_usage = 100 * (proc_time_delta / (uptime_delta * clk_tck))
                cpu_usage_tmp[key] = [cur_cpu_usage, data_lst[1][loop + 1][key][2], data_lst[1][loop + 1][key][3]]
            else:
                cpu_usage_tmp[key] = [-1, data_lst[1][loop + 1][key][2], data_lst[1][loop + 1][key][3]]
        cpu_usages.append(cpu_usage_tmp)
    return cpu_usages

def thd_ana_data_proc(data_lst, dic_field_id, dic_field_val):
    '''
    field: thd_id cpu_usage cpu_id thd_name
    '''
    data_pure_lst = []
    data_dic = {}

    dataTag = []
    mDataGrp = []

    for loop in range(len(data_lst)):
        lst_tmp = []
        for key in data_lst[loop]:
            lst_tmp.append([key, float(f"{data_lst[loop][key][0]:>5.2f}"), int(data_lst[loop][key][1]), data_lst[loop][key][2]])
        data_pure_lst.append(lst_tmp)

    for sublst1 in data_pure_lst:
        for sublst2 in sublst1:
            if sublst2[dic_field_id] not in data_dic:
                data_dic[sublst2[dic_field_id]] = []
            if sublst2[dic_field_val] < 0:
                data_dic[sublst2[dic_field_id]].append(np.nan)
            else:
                data_dic[sublst2[dic_field_id]].append(sublst2[dic_field_val])

    dataTag = list(data_dic.keys())
    for cur_id in dataTag:
        mDataGrp.append(data_dic[cur_id])

    return dataTag,mDataGrp

def thd_ana_data(data_lst):
    # cpu_id
    dataTag_id,mDataGrp_id = thd_ana_data_proc(data_lst, 3, 2)
    dataTag_id = [v+"_id" for v in dataTag_id]
    plotVal(dataTag_id, mDataGrp_id, title = "thd data id", showLine = True)

    # cpu id summary
    mDataGrp_id_sum = []
    for loop in range(len(mDataGrp_id)):
        new_lst = [0, 0, 0, 0, 0, 0, 0, 0]
        for cur_id in mDataGrp_id[loop]:
            new_lst[cur_id] += 1
        mDataGrp_id_sum.append(new_lst)
    plotVal(dataTag_id, mDataGrp_id_sum, title = "thd data id summary", showLine = True)

    # cpu_usage
    dataTag_usg,mDataGrp_usg = thd_ana_data_proc(data_lst, 3, 1)
    dataTag_usg = [v+"_usage" for v in dataTag_usg]
    plotVal(dataTag_usg, mDataGrp_usg, title = "thd data usage", showLine = True, refLineEn = [True, False], refLine = [100, 0])

    all_tag = dataTag_id + dataTag_usg
    plotVal(all_tag, mDataGrp_id + mDataGrp_usg, title = "thd data id+usage", showLine = True, refLineEn = [True, False], refLine = [100, 0])

def thd_dump_data(thd_usages):
    for loop in range(len(thd_usages)):
        for key in thd_usages[loop]:
            print(f"thd_id:{key}  cpu_usage:{thd_usages[loop][key][0]:>5.2f}%  cpu_id:{thd_usages[loop][key][1]:<2} thd_name:{thd_usages[loop][key][2]}")
        print()

def main():
    genfname = "cpudata_gen.txt"
    insfname = "cpudata_ins.txt"
    thdfname = "cpudata_thd.txt"

    # gen data
    gen_org_data_dict = gen_load_data(genfname)
    gen_usage_data_dic = gen_calculate_cpu_usage(gen_org_data_dict)
    gen_ana_data(gen_usage_data_dic)
    gen_dump_data(gen_usage_data_dic)

    # ins data
    ins_org_data_lst = ins_load_data(insfname)
    ins_usage_data_lst = ins_calculate_cpu_usage(ins_org_data_lst)
    ins_ana_data(ins_usage_data_lst)
    ins_dump_data(ins_usage_data_lst)

    # thd data
    thd_org_data_lst = thd_load_data(thdfname)
    thd_usage_data_lst = thd_calculate_cpu_usage(thd_org_data_lst)
    thd_ana_data(thd_usage_data_lst)
    thd_dump_data(thd_usage_data_lst)

    plt.show()

if __name__ == "__main__":
    main()
