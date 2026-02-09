#!/usr/bin/env python
#########################################################################
# File Name: slt_checker.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 28 May 2025 09:30:54 PM CST
#########################################################################

import filecmp

def slt_cmp_verify(file1, file2, org_file):
    # shallow=False：比较文件内容（而非仅文件属性）
    res = filecmp.cmp(file1, file2, shallow=False)
    if res:
        print(f"[\033[0m\033[1;32m SLT PASS \033[0m] {org_file}")
    else:
        print(f"[\033[0m\033[1;31m SLT FAIL \033[0m] {org_file}: {file1} ≠ {file2}")
    return res
