#!/bin/python3
#########################################################################
# File Name: test_all.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri Oct 20 14:54:27 2023
#########################################################################

import os
import pytest
import subprocess

curProc = "hevc"
buildDir1 = "${HOME}/Projects/mpp/build/linux/x86_64"
buildDir2 = "${HOME}/Projects/mpp2/build/linux/x86_64"

sgl_file = "${HOME}/path/to/stream"
batch_dir = "/path/to/stream/dir"

def buildMpp(buildDir):
    compileCmd = "./make-Makefiles.bash"
    buildCmd = "bash ./build_mpp.sh  {} {}".format(buildDir, compileCmd)
    print("==> build mpp cmd: {}".format(buildCmd))
    ret, res = subprocess.getstatusoutput(buildCmd)
    assert ret == 0, "build error, cmd: {}".format(buildCmd)

def runMpp(appDir, runProc, test_stream):
    runCmd = "bash ./run_data.sh  {} {} {}".format(appDir, runProc, test_stream)
    print("==> run mpp cmd: {}".format(runCmd))
    ret, res = subprocess.getstatusoutput(runCmd)
    assert ret == 0, "running error, cmd: {}".format(runCmd)

def cmpData(dataDir1, dataDir2):
    cmpCmd = "~/Projects/miniTools/2.dataProc/12.cmp_dir.sh {} {}".format(dataDir1, dataDir2)
    print("==> cmp data cmd: {}".format(cmpCmd))
    ret, res = subprocess.getstatusoutput(cmpCmd)
    assert ret == 0, "data check error, cmp cmd: {}".format(cmpCmd)

def test_sgl():
    print()
    source = sgl_file

    # build mpp
    buildMpp(buildDir1)
    buildMpp(buildDir2)

    # run mpp
    runMpp(buildDir1, curProc, source)
    runMpp(buildDir2, curProc, source)

    # check data
    cmpData("{}/{}".format(buildDir1, curProc), "{}/{}".format(buildDir2, curProc))

def test_batch_by_dir():
    print()
    batchTestDir = batch_dir

    # build mpp
    buildMpp(buildDir1)
    buildMpp(buildDir2)

    for item in os.scandir(batchTestDir):
        print()
        if (not item.is_file()):
            continue

        source = "{}/{}".format(batchTestDir, item.name)
        print("==> cur stream: {}".format(source))
        # run mpp
        runMpp(buildDir1, curProc, source)
        runMpp(buildDir2, curProc, source)

        # check data
        cmpData("{}/{}".format(buildDir1, curProc), "{}/{}".format(buildDir2, curProc))

def test_batch_by_list():
    print()

    # build mpp
    buildMpp(buildDir1)
    buildMpp(buildDir2)

    mFile = open("source_list.txt", mode='r')
    strms = mFile.readlines()
    for curStrm in strms:   #把lines中的数据逐行读取出来
        print()
        source = curStrm.strip()
        print("==> cur stream: {}".format(source))
        # run mpp
        runMpp(buildDir1, curProc, source)
        runMpp(buildDir2, curProc, source)

        # check data
        cmpData("{}/{}".format(buildDir1, curProc), "{}/{}".format(buildDir2, curProc))

if __name__ == "__main__":
    pytest.main(["./test_all.py::test_sgl", "-s", "-v", "-x"])
