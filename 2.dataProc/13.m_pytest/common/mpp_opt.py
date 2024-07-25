#!env python
#########################################################################
# File Name: mpp_opt.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Nov 20 15:13:59 2023
#########################################################################

import os
import common.common as com

def buildMpp(buildDir, buildCmd):
    print()
    com.runApp(buildDir, buildCmd, "buildMpp: " + buildDir)

def runMpp(appDir, runProc, test_stream):
    procMap = { "hevc" : 16777220,
                "h264" : 7,
                "vp9"  : 10,
                "avs2" : 16777223,
                "av1"  : 16777224 }
    runcmd = "./test/mpi_dec_test  -t {} -fpga fpga_file -i {}".format(procMap[runProc], test_stream)
    os.environ["fpga_debug"] = "0x00000100"
    com.runApp(appDir, runcmd, "runMpp: " + appDir)
