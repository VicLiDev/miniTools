#!/usr/bin/env python
#########################################################################
# File Name: cmod_opt.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Nov 20 17:07:02 2023
#########################################################################

import os
import common.common as com

m_path = os.path.abspath(__file__)
m_dir = os.path.dirname(os.path.abspath(__file__))

def buildCmod(cmodDir, proc):
    compileToolDir = cmodDir + "/script_tools"
    toolsCmd = "bash compileRun.sh {} b".format(proc)
    com.runApp(compileToolDir, toolsCmd, "buildCmod: " + cmodDir)

if __name__ == "__main__":
    buildDir = "/path/to/cmod"
    proc = "hevc"
    buildCmod(buildDir, proc)
