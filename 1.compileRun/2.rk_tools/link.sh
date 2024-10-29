#!/usr/bin/env bash
#########################################################################
# File Name: 2.link.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Jul 25 14:39:36 2023
#########################################################################

prjDir="${HOME}/Projects/miniTools"
subDir="1.compileRun/2.rk_tools"

# mpp
rm ${HOME}/bin/rkBuildMpp.sh
rm ${HOME}/bin/rkDebugMpp.sh
ln -s ${prjDir}/${subDir}/rkBuildMpp.sh ${HOME}/bin/rkBuildMpp.sh
ln -s ${prjDir}/${subDir}/rkDebugMpp.sh ${HOME}/bin/rkDebugMpp.sh

# kernel
rm ${HOME}/bin/rkBuildKer.sh
rm ${HOME}/bin/rkdebugKer.sh
rm ${HOME}/bin/rkUT.sh
ln -s ${prjDir}/${subDir}/rkBuildKer.sh ${HOME}/bin/rkBuildKer.sh
ln -s ${prjDir}/${subDir}/rkDebugKer.sh ${HOME}/bin/rkdebugKer.sh
ln -s ${prjDir}/${subDir}/rkUT.sh       ${HOME}/bin/rkUT.sh

# tools
rm ${HOME}/bin/adbDebug.sh
rm ${HOME}/bin/adbKill.sh
rm ${HOME}/bin/adbs
rm ${HOME}/bin/tarMpp.sh
ln -s ${prjDir}/${subDir}/adbDebug.sh   ${HOME}/bin/adbDebug.sh
ln -s ${prjDir}/${subDir}/adbKill.sh    ${HOME}/bin/adbKill.sh
ln -s ${prjDir}/${subDir}/adbSelCmd.sh  ${HOME}/bin/adbs
ln -s ${prjDir}/${subDir}/tarMpp.sh     ${HOME}/bin/tarMpp.sh


# for prj
# ln -s ${HOME}/bin/rkBuildMpp.sh .prjBuild.sh
# ln -s ${HOME}/bin/rkDebugMpp.sh .prjDebug.sh
# ln -s ${HOME}/bin/rkBuildKer.sh .prjBuild.sh
# ln -s ${HOME}/bin/rkDebugKer.sh .prjDebug.sh
