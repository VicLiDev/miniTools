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
    echo "  u   download uboot.img"
    echo "  b   download boot.img"
    echo "  z   download zboot.img"
    echo "  k   download kernel.img"
    echo "  re  download resource.img"
    echo "  i   download update.img"
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
        # DI命令:烧写分区镜像
        # 目前已知的分区有-s(system 分区)、-k(kernel 分区)、-b(boot 分区)、
        # -r(recovery 分区) 、-m(misc 分区) 、 -u(uboot 分区) 、-t(trust 分区)
        # 和-re(resource 分区)
        'u')
            echo "========> writing uboot.img <========" && echo
            echo "File: ${IMAGE_PATH}/uboot.img"
            sudo upgrade_tool di -u ${IMAGE_PATH}/uboot.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        'b')
            echo "========> writing boot.img <========" && echo
            echo "File: ${IMAGE_PATH}/boot.img"
            sudo upgrade_tool di -b ${IMAGE_PATH}/boot.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        'z')
            echo "========> writing zboot.img <========" && echo
            echo "File: ${IMAGE_PATH}/zboot.img"
            sudo upgrade_tool di -b ${IMAGE_PATH}/zboot.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        'k')
            echo "========> writing kernel.img <========" && echo
            echo "File: ${IMAGE_PATH}/kernel.img"
            sudo upgrade_tool di -k ${IMAGE_PATH}/kernel.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        're')
            echo "========> writing resource.img <========" && echo
            echo "File: ${IMAGE_PATH}/resource.img"
            sudo upgrade_tool di -re ${IMAGE_PATH}/resource.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        'i')
            echo "========> writing update.img <========" && echo
            echo "File: ${IMAGE_PATH}/update.img"
            sudo upgrade_tool uf ${IMAGE_PATH}/update.img 
            if [ $? -eq 0 ]; then exit 0; fi
            ;;
        'm')
            ;;
    esac

    echo && echo "========> rebooting <========" && echo
    sudo upgrade_tool rd
    if [ $? -eq 0 ]; then exit 0; fi
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

