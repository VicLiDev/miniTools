#!/usr/bin/env python
#########################################################################
# File Name: verify.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 13 Sep 15:06:51 2024
#########################################################################

import os
import random
import pytest

def run_demo():
    # random_float = random.random()
    # print(random_float)

    # 按照 8K 计算
    # (1024 * 8 * 1024 * 4) * 3 * 3 * 2 = 603979776 byte = 0x24000000 byte
    # 603979776 / 8 = 75497472 = 0x4800000
    # 0xFFFFFFFFFFFFFFFF * 0x4800000 = 0x47ffffffffffffffb800000

    # 生成1到10之间的随机整数
    random_int = random.randint(1, 603979776)
    # 执行命令，但无法直接捕获输出
    run_demo_cmd = "./calc_with_carry_usin_long {} > /dev/null".format(random_int)
    print("demo cmd: ", run_demo_cmd)
    status = os.system(run_demo_cmd)

    # 检查状态码
    if status == 0:
        print("Command succeeded")
    else:
        print("Command failed")

def loadData(fname):
    f = open(fname)

    nums = []
    while True:
        line = f.readline()
        if not line:
            break
        cur = int(line.strip('\n'), 16)
        nums.append(cur)

    return nums

def test_01():
    data_fname = "data.txt"
    res_fname = "result.txt"

    for i in range(10000):
        print()
        print("test idx: ", i)
        run_demo()

        data_list = loadData(data_fname)
        file_result = loadData(res_fname)

        verify_res = sum(data_list)

        print("verify_res:  %x"%(verify_res))
        print("file_result: %x"%(file_result[0]))

        assert(verify_res == file_result[0])


if __name__ == "__main__":
    test_01()
    # pytest.main(["./verify.py", '-v'])
    # pytest.main(["", '-v'])
    # pytest.main(['-v'])
