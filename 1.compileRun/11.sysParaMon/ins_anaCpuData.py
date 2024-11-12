#!/usr/bin/env python
#########################################################################
# File Name: ins_anaCpuData.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon 11 Nov 2024 11:06:36 AM CST
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

def read_file_to_list(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    # sysUsage = [sample1, sample2,...]
    # procUsage = [[sample1_utime, sample1_stime],
    #              [sample2_utime, sample2_stime],...]
    # cpuID = [sapple1, sample2,...]
    sysUsage = []
    procUsage = []
    cpuID = []
    with open(filename, 'r') as file:
        for line in file:
            if line[:4] == "uptm":
                sysUsage.append(float(line.split()[1]))
            elif line[:4] == "stat":
                fields = line.split()
                # 由于抓log时多加了一个 stat开头，所以这里的字段位置会+1
                procUsage.append([int(fields[14]), int(fields[15])])
                cpuID.append(int(fields[39]))
    return sysUsage, procUsage, cpuID

def calculate_cpu_usage(sysUsage, procUsage):
    # 获取当前时间点的数据
    cpu_usages = []
    for loop in range(len(sysUsage) - 1):
        # 计算时间差
        proc_time_delta = sum(procUsage[loop + 1]) - sum(procUsage[loop])
        uptime_delta = sysUsage[loop + 1] - sysUsage[loop]

        # 防止除零错误
        if uptime_delta == 0:
            cpu_usages.append(-1)
            continue

        command="getconf CLK_TCK"
        stdout, stderr, status = run_command(command)
        clk_tck = int(stdout)

        # 计算 CPU 占用率
        cur_cpu_usage = 100 * (proc_time_delta / (uptime_delta * clk_tck))
        cpu_usages.append(cur_cpu_usage)
    return cpu_usages

def main():
    sysUsg,procUsg,cpuID = read_file_to_list("ins_cpudata.txt")
    usages = calculate_cpu_usage(sysUsg, procUsg)
    usages = [ f"{p:>5.2f}%" for p in usages]
    cpuID.pop(0)
    for loop in range(len(usages)):
        print(f"cpu_usage: {usages[loop]} Main_thd_cpu_id: {cpuID[loop]}")
    # print("cpu Usage:       "," ".join(usages))
    # print("Main thd cpu ID: ", "".join([ f"{id:<7}" for id in cpuID]))

if __name__ == "__main__":
    main()
