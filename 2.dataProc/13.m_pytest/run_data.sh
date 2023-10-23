#!/bin/bash
#########################################################################
# File Name: run_data.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Oct 23 14:54:36 2023
#########################################################################

runDir="$1"
cd $runDir
if [ $? -ne 0 ]; then echo "cd build dir failed"; echo "cur Dir: `pwd`"; exit 1; fi
echo "build dir: `pwd`"

proc="$2"
stm_source="$3"
runCmd=""
case ${proc} in
    "hevc")
        cmdProc=16777220
        ;;
    "h264")
        cmdProc=7
        ;;
    "vp9")
        cmdProc=10
        ;;
    "avs2")
        cmdProc=16777223
        ;;
    "av1")
        cmdProc=16777224
        ;;
    *)
        echo "unsupport cmd"
        ;;
esac

runCmd="./test/mpi_dec_test  -t ${cmdProc} -fpga fpga_file -i ${stm_source}"
echo "run cmd: ${runCmd}"
export fpga_debug=0x00000100
${runCmd}
if [ $? -ne 0 ]; then echo "run error"; exit 1; fi
