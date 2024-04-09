#!/bin/bash
#########################################################################
# File Name: 2.link.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Jul 25 14:39:36 2023
#########################################################################

# mpp
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.rkBuildMpp.sh ${HOME}/bin/rkBuildMpp.sh
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.rkDebugMpp.sh ${HOME}/bin/rkDebugMpp.sh

# kernel
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.rkBuildKer.sh ${HOME}/bin/rkBuildKer.sh
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.rkDebugKer.sh ${HOME}/bin/rkdebugKer.sh
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.rkUT.sh       ${HOME}/bin/rkUT.sh

# tools
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.adbDebug.sh   ${HOME}/bin/adbDebug.sh
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.adbKill.sh    ${HOME}/bin/adbKill.sh
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.adbSelCmd.sh  ${HOME}/bin/adbs
ln -s ${HOME}/Projects/miniTools/1.compileRun/2.tarMpp.sh     ${HOME}/bin/tarMpp.sh


# for prj
# ln -s ${HOME}/bin/rkBuildMpp.sh .prjBuild.sh
# ln -s ${HOME}/bin/rkDebugMpp.sh .prjDebug.sh
# ln -s ${HOME}/bin/rkBuildKer.sh .prjBuild.sh
# ln -s ${HOME}/bin/rkDebugKer.sh .prjDebug.sh
