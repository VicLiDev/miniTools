#!/usr/bin/env bash
#########################################################################
# File Name: run_test.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri Jan  5 14:34:30 2024
#########################################################################

function update_file()
{
	if [ ! -e $1 ]; then echo "error: src file $1 do not exist"; exit 1; fi
	if [ ! -e $2 ]; then echo "error: dst dir $2 do not exist"; exit 1; fi
	echo "copy $1 to $2"
	cp -r $1 $2
}

protocol=$1

if [ "${protocol}" != "hevc" ] \
	&& [ "${protocol}" != "avc" ] \
	&& [ "${protocol}" != "avs2" ] \
	&& [ "${protocol}" != "vp9" ] \
	&& [ "${protocol}" != "av1" ]; then
	echo "protocol must in hevc/avc/avs2/vp9/av1, instead ${protocol}"
	exit 1
fi

update_file ${HOME}/bin/${protocol}/mpi_dec_test ${HOME}/bin
update_file ${HOME}/bin/${protocol}/librockchip_mpp.so.0 /usr/lib64/

test_prot_code

case ${protocol} in
	"hevc")
		stream="/root/streams/Big_Buck_Bunny_360_10s_1MB.h265"
		test_prot_code=1677220
		;;
	"avc")
		stream="/root/streams/Big_Buck_Bunny_360_10s_1MB.h264"
		test_prot_code=7
		;;
	"avs2")
		stream="/root/streams/test5_avs2.avs2"
        test_prot_code=16777223
		;;
	"vp9")
		stream="/root/streams/Big_Buck_Bunny_360_10s_1MB.ivf"
		test_prot_code=10
		;;
	"av1")
		stream="/root/streams/Sintel_360_10s_1MB.ivf"
		test_prot_code=16777224
		;;
esac

test_cmd="mpi_dec_test -i ${stream} -t ${test_prot_code} -n 3"
echo "test cmd: ${test_cmd}"
${test_cmd}
