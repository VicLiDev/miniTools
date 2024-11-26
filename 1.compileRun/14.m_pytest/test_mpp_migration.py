#!/usr/bin/env python
#########################################################################
# File Name: test_mpp_migration.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri Oct 20 14:54:27 2023
#########################################################################

import os
import pytest
import common.common as com
import common.mpp_opt as mppOpt

curProc = "hevc"
buildDir1 = "/home/lhj/Projects/mpp/build/linux/x86_64"
buildDir2 = "/home/lhj/Projects/mpp2/build/linux/x86_64"
buildCmd = "bash ./make-Makefiles.bash"

sgl_file = "/home/lhj/path/to/stream"
batch_dir = "/path/to/stream/dir"

def test_batch_by_list():
    print()

    # build mpp
    mppOpt.buildMpp(buildDir1, buildCmd)
    mppOpt.buildMpp(buildDir2, buildCmd)

    mFile = open("source_list.txt", mode='r')
    strms = mFile.readlines()
    for curStrm in strms:   #把lines中的数据逐行读取出来
        source = curStrm.strip()
        if (len(source) == 0) or (source[0] == "#"):
            continue
        print()
        print("==> cur stream: {}".format(source))
        # run mpp
        mppOpt.runMpp(buildDir1, curProc, source)
        mppOpt.runMpp(buildDir2, curProc, source)

        # check data
        com.cmpData("{}/{}".format(buildDir1, curProc), "{}/{}".format(buildDir2, curProc))

if __name__ == "__main__":
    pytest.main(["./test_mpp_migration.py::test_batch_by_list", "-s", "-v", "-x"])
    # test_batch_by_list()
