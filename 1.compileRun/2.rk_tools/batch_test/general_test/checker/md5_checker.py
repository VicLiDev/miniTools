#!/usr/bin/env python
#########################################################################
# File Name: md5_checker.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 05:00:38 PM CST
#########################################################################

import hashlib

def md5sum(filepath):
    h = hashlib.md5()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b''):
            h.update(chunk)
    return h.hexdigest()

def verify_md5(filepath, reference_md5):
    current_md5 = md5sum(filepath)
    if current_md5 != reference_md5:
        print(f"[MD5 FAIL] {filepath}: {current_md5} ≠ {reference_md5}")
    else:
        print(f"[MD5 PASS] {filepath}")
