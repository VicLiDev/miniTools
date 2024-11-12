#!/usr/bin/env python
#########################################################################
# File Name: thd_anaCpuData.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 12 Nov 2024 03:05:02 PM CST
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
    sys_usage = []
    thd_info = []

    # thd_info = [{thd_id:[utime, stime, cpuid]},
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
                # 由于抓log时多加了一个 stat开头，所以这里的字段位置会+1
                if fields[1] not in info_dict_tmp:
                    info_dict_tmp[fields[1]] = [int(fields[14]), int(fields[15]), int(fields[39]), fields[2]]
                else:
                    print(f"Error: thd_id repeated!!")
    return sys_usage, thd_info

def calculate_cpu_usage(sys_usage, thd_info):
    # 获取当前时间点的数据
    cpu_usages = []
    for loop in range(len(sys_usage) - 1):
        # 计算系统时间差
        uptime_delta = sys_usage[loop + 1] - sys_usage[loop]

        command="getconf CLK_TCK"
        stdout, stderr, status = run_command(command)
        clk_tck = int(stdout)

        # 计算 CPU 占用率
        cpu_usage_tmp = {}
        for key in thd_info[loop + 1]:
            if key in thd_info[loop]:
                # 计算线程时间差
                proc_time_delta = \
                        thd_info[loop + 1][key][0] + thd_info[loop + 1][key][1] \
                        - thd_info[loop][key][0] - thd_info[loop][key][1]

                cur_cpu_usage = -1
                if uptime_delta != 0:
                    cur_cpu_usage = 100 * (proc_time_delta / (uptime_delta * clk_tck))
                cpu_usage_tmp[key] = [cur_cpu_usage, thd_info[loop + 1][key][2], thd_info[loop + 1][key][3]]
            else:
                cpu_usage_tmp[key] = [-1, thd_info[loop + 1][key][2], thd_info[loop + 1][key][3]]
        cpu_usages.append(cpu_usage_tmp)
    return cpu_usages

def main():
    sys_usage,thd_info = read_file_to_list("thd_cpudata.txt")
    usages = calculate_cpu_usage(sys_usage, thd_info)
    for loop in range(len(usages)):
        for key in usages[loop]:
            print(f"thd_id:{key}  cpu_usage:{usages[loop][key][0]:>5.2f}%  cpu_id:{usages[loop][key][1]:<2} thd_name:{usages[loop][key][2]}")
        print()

if __name__ == "__main__":
    main()

