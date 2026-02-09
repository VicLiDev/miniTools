#!/usr/bin/env python
#########################################################################
# File Name: m_utils.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 27 May 2025 05:10:15 AM CST
#########################################################################

import os
import sys
import subprocess

def get_project_root(cur_file):
    """获取项目根目录"""
    current_dir = os.path.dirname(os.path.abspath(cur_file))
    while current_dir != os.path.dirname(current_dir):
        if any(os.path.exists(os.path.join(current_dir, marker))
               for marker in ['.git', 'pyproject.toml', 'setup.py']):
            return current_dir
        current_dir = os.path.dirname(current_dir)
    return os.path.dirname(cur_file)

prj_root = get_project_root(__file__)
if prj_root not in sys.path:
    sys.path.insert(0, prj_root + "/0.general_tools")
    sys.path.insert(0, prj_root + "/1.compileRun/2.rk_tools")

from sel_node import *
from adb_sel import *

# manager = adb_sel.ADBDevSelector()
# manager.proc_paras(sys.argv[1:])
# manager.execute()

def run_command(command, use_str = False):
    """执行给定的 shell 命令并返回输出、错误和执行状态"""
    try:
        result = subprocess.run(command, shell=use_str, check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # 返回标准输出、标准错误和执行状态
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        # 捕获并处理错误
        return e.stdout.strip(), e.stderr.strip(), e.returncode


'''
command = "echo \"hello\""
stdout, stderr, status = run_command(command, use_str=True)
# 输出命令的结果和状态
print("命令输出:\n", stdout)
print("错误输出:\n", stderr)
print("执行状态:", "成功" if status == 0 else f"失败 (状态码: {status})")

command = ["echo", "hello"]
stdout, stderr, status = run_command(command, use_str=False)
# 输出命令的结果和状态
print("命令输出:\n", stdout)
print("错误输出:\n", stderr)
print("执行状态:", "成功" if status == 0 else f"失败 (状态码: {status})")
'''
