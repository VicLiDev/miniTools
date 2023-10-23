#!/bin/bash
#########################################################################
# File Name: build_mpp.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Oct 23 15:50:49 2023
#########################################################################

buildDir="$1"
cd $buildDir
if [ $? -ne 0 ]; then echo "cd build dir failed"; echo "cur Dir: `pwd`"; exit 1; fi
echo "build dir: `pwd`"

buildCmd="$2"
echo "build cmd: ${buildCmd}"
${buildCmd}
if [ $? -ne 0 ]; then echo "build error"; exit 1; fi
