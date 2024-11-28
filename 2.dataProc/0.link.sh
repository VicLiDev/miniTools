#!/usr/bin/env bash
#########################################################################
# File Name: 0.link.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Thu 28 Nov 2024 11:42:42 AM CST
#########################################################################

prjDir="${HOME}/Projects/miniTools"
subDir="2.dataProc"

rm ${HOME}/bin/vcut
ln -s ${prjDir}/${subDir}/18.vcut.sh ${HOME}/bin/vcut
