#!/usr/bin/env python
#########################################################################
# File Name: common.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Nov 20 17:32:28 2023
#########################################################################

import os
import subprocess

def cmpData(dataDir1, dataDir2, diffQ = True):
    quit_script = ""
    if diffQ:
        quit_script = "q"
    cmpCmd = "~/Projects/miniTools/2.dataProc/12.cmp_dir.sh {} {} {}".format(dataDir1, dataDir2, quit_script)
    print("==> cmp data cmd: {}".format(cmpCmd))
    ret, res = subprocess.getstatusoutput(cmpCmd)
    # if ret:
    print(res)
    if diffQ:
        assert ret == 0, "data check error, cmp cmd: {}".format(cmpCmd)
    return ret

def runApp(runDir, runCmd, comment = "comment"):
    oldWorkDir = os.getcwd()
    if len(runDir):
        if os.path.exists(runDir):
            os.chdir(runDir)
            # ret, res = subprocess.getstatusoutput("pwd")
            # print("pwd: " + res)
        else:
            print("dir {} do not exit".format(runDir))
            exit(-1)

    print("==> " + comment)
    print("==> workDir: " + os.getcwd())
    print("==> runCmd: " + runCmd)
    ret, res = subprocess.getstatusoutput(runCmd)
    if ret :
        print(res)
    assert ret == 0, "run cmd error, cmd: {}".format(runCmd)
    os.chdir(oldWorkDir)


if __name__ == "__main__":
    runDir = "/path/to/workDir"
    runCmd = "bash script_tools/compileRun.sh hevc b"
    runApp(runDir, runCmd)

    cmpDir1 = "/home/lhj/test/test.c"
    cmpDir2 = "/home/lhj/test/test.cpp"
    cmpDir2 = "/home/lhj/test/test.c"
    cmpData(cmpDir1, cmpDir2)
