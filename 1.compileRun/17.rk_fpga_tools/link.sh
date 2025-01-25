#!/usr/bin/env bash
#########################################################################
# File Name: link.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Jul 25 14:39:36 2023
#########################################################################

prjDir="${HOME}/Projects/miniTools"
subDir="1.compileRun/17.rk_fpga_tools"
dstDir="${HOME}/Projects/openocd_rk"

rm ${dstDir}/dbg_host_boot_sys.sh
rm ${dstDir}/dbg_host_update_sdcard.sh
rm ${dstDir}/dbg_target_run_batch.sh
rm ${dstDir}/dbg_target_run_test.sh
ln -s ${prjDir}/${subDir}/host_boot_sys.sh      ${dstDir}/dbg_host_boot_sys.sh
ln -s ${prjDir}/${subDir}/host_update_sdcard.sh ${dstDir}/dbg_host_update_sdcard.sh
ln -s ${prjDir}/${subDir}/target_run_batch.sh   ${dstDir}/dbg_target_run_batch.sh
ln -s ${prjDir}/${subDir}/target_run_test.sh    ${dstDir}/dbg_target_run_test.sh
