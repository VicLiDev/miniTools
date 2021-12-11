#!/bin/bash
# rockchip update tools

PWD=`pwd`
REMOTE_USER=lhj
REMOTE_IP=10.10.10.65
REMOTE_DIR=/home/lhj/Projects/kernel
REMOTE_PATH=${REMOTE_USER}@${REMOTE_IP}:${REMOTE_DIR}

#IMAGE_PATH=~/test
#scp -r ${REMOTE_PATH}/boot.img ${IMAGE_PATH}

IMAGE_PATH=/home/lhj/Projects/kernel
IMAGE_PATH=/home/lhj/test

rkut_help(){
    echo "usage: rkut.sh <opt>"
    echo "opt:"
    echo "  b   download boot.img"
}

if [ $# -lt 1 ]; then
    echo "error: para is less than 1"
    rkut_help
    exit
else
    case $1 in
        '-h')
            rkut_help
            exit
            ;;
        'b')
            echo "========> writing boot <========" && echo
            echo "File: ${IMAGE_PATH}/boot.img"
            sudo upgrade_tool di -b ${IMAGE_PATH}/boot.img 
            ;;
        'm')
            ;;
    esac

    echo && echo "========> rebooting <========" && echo
    sudo upgrade_tool rd
fi





#echo "====> writing loader" && echo 
#sudo upgrade_tool ul ${IMAGE_PATH}/rk356x_spl_loader_v1.00.100.bin
#sudo upgrade_tool ul ${IMAGE_PATH}/MiniLoaderAll.bin 
#echo "====> writing parameter" && echo
#sudo upgrade_tool di -p ${IMAGE_PATH}/parameter.txt 
#echo "====> writing trust" && echo
#sudo upgrade_tool di -trust ${IMAGE_PATH}/trust.img 
#echo "====> writing uboot" && echo
#sudo upgrade_tool di -u ${IMAGE_PATH}/uboot.img 
#echo "====> writing boot" && echo
#sudo upgrade_tool di -b ${IMAGE_PATH}/boot.img 
#sudo upgrade_tool di -r ${IMAGE_PATH}/recovery.img 
#echo "====> writing misc" && echo
#sudo upgrade_tool di -m ${IMAGE_PATH}/misc.img 
#echo "====> writing oem" && echo
#sudo upgrade_tool di -oem ${IMAGE_PATH}/oem.img
#echo "====> writing rootfs" && echo
#sudo upgrade_tool di -rootfs ${IMAGE_PATH}/rootfs.img
#echo "====> writing userdata" && echo
#sudo upgrade_tool di -userdata ${IMAGE_PATH}/userdata.img

