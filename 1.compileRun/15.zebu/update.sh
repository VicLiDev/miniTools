#!/usr/bin/env bash
#########################################################################
# File Name: update.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed Jan  3 09:29:40 2024
#########################################################################

set -e

# collect
wk_dir="/home/sfs/shareFs"
collect_folder="update"
collect_dir="${wk_dir}/${collect_folder}/"
compress_pkt="/home/sfs/shareFs/update.tar.gz"

# source
bootloader="${HOME}/Projects/fpga_tools/m_openocd/mImage/bl31_0x40040000.bin"
buildroot_dir="${HOME}/Projects/buildroot"
buildroot_sys_dir="${buildroot_dir}/output/target"
buildroot_fs="${buildroot_dir}/output/images/rootfs.cpio"
kernel_dir="${HOME}/Projects/kernel3"
kernel_dtb="${kernel_dir}/arch/arm64/boot/dts/rockchip/rk3576-fpga.dtb"
kernel_img="${kernel_dir}/arch/arm64/boot/Image"
kernel_ko="${kernel_dir}/drivers/video/rockchip/mpp/rk_vcodec.ko"
mpp_dir="${HOME}/Projects/mpp"
mpp_dec_exe="${mpp_dir}/build/linux/aarch64/test/mpi_dec_test"
mpp_lib="${mpp_dir}/build/linux/aarch64/mpp/librockchip_mpp.so.0"
# stream
h265_test_streams="${HOME}/Projects/streams/m_h265/vstream/Big_Buck_Bunny_360_10s_1MB.h265"
h264_test_streams="${HOME}/Projects/streams/m_h264/vstream/Big_Buck_Bunny_360_10s_1MB.h264"
avs2_test_streams="${HOME}/Projects/streams/m_avs2/vstream/test5_avs2.avs2"
vp9_test_streams="${HOME}/Projects/streams/m_vp9/vstream/Big_Buck_Bunny_360_10s_1MB.ivf"
av1_test_streams="${HOME}/Projects/streams/m_av1/vstream/Sintel_360_10s_1MB.ivf"
# av1_test_streams="${HOME}/Projects/streams/m_AV1_90_ser/vstream/cut4_10.ivf"

function update_file()
{
	if [ ! -e $1 ]; then echo "error: src file $1 do not exist"; exit 1; fi
	if [ ! -e $2 ]; then echo "error: dst dir $2 do not exist"; exit 1; fi
	echo "copy $1 to $2"
	cp -r $1 $2
}

function update_mpp_lib_exe()
{
	prot=${1}
	mpp_dir="${HOME}/Projects/dev383/${prot}"
	mpp_dec_exe="${mpp_dir}/build/linux/aarch64/test/mpi_dec_test"
	mpp_lib="${mpp_dir}/build/linux/aarch64/mpp/librockchip_mpp.so.0"
	if [ ! -d ${buildroot_sys_dir}/root/bin/${prot} ]; then
		mkdir -p ${buildroot_sys_dir}/root/bin/${prot};
	fi
	update_file ${mpp_dec_exe} ${buildroot_sys_dir}/root/bin/${prot}
	update_file ${mpp_lib}     ${buildroot_sys_dir}/root/bin/${prot}
}

function update_mpp_to_rootfs()
{
	if [ ! -d ${buildroot_sys_dir}/root/bin/ ]; then
		mkdir ${buildroot_sys_dir}/root/bin/;
	fi
	if [ ! -d ${buildroot_sys_dir}/root/streams/ ]; then
		mkdir ${buildroot_sys_dir}/root/streams/;
	fi

	# origin
	update_file ${mpp_dec_exe} ${buildroot_sys_dir}/root/bin
	update_file ${mpp_lib}     ${buildroot_sys_dir}/usr/lib64

	# for every protocol
	# update_mpp_lib_exe "hevc"
	# update_mpp_lib_exe "avc"
	# update_mpp_lib_exe "avs2"
	# update_mpp_lib_exe "vp9"
	# update_mpp_lib_exe "av1"

	# collect streams
	# update_file ${h265_test_streams} ${buildroot_sys_dir}/root/streams/
	# update_file ${h264_test_streams} ${buildroot_sys_dir}/root/streams/
	# update_file ${avs2_test_streams} ${buildroot_sys_dir}/root/streams/
	# update_file ${vp9_test_streams} ${buildroot_sys_dir}/root/streams/
	# update_file ${av1_test_streams} ${buildroot_sys_dir}/root/streams/

	# update test script
	update_file `pwd`/run_test.sh ${buildroot_sys_dir}/root/bin

    link_name="${buildroot_sys_dir}/usr/lib64/librockchip_mpp.so.1"
    # lib_name="${buildroot_sys_dir}/usr/lib64/librockchip_mpp.so.0"
    lib_name="librockchip_mpp.so.0"
    if [ ! -e ${link_name} ]; then ln -s ${lib_name} ${link_name}; fi

	cd ${buildroot_dir}
	sed -i '6a\exit 1' output/target/etc/network/if-pre-up.d/wait_iface
	make -j
}

function tar_data()
{
	if [ ! -d ${collect_dir} ]; then mkdir ${collect_dir}; fi
	
	update_file ${bootloader} ${collect_dir}
	update_file ${buildroot_fs}  ${collect_dir}
	update_file ${kernel_dtb} ${collect_dir}
	update_file ${kernel_img} ${collect_dir}
	# update_file ${kernel_ko}  ${collect_dir}
	
	tar -czvf ${compress_pkt} -C${wk_dir} ${collect_folder}
}

if [ -e ${collect_dir}/202* ]; then rm ${collect_dir}/202*; fi
touch ${collect_dir}`date +"%Y_%m_%d_%H:%M:%S"`
update_mpp_to_rootfs
tar_data

set +e
