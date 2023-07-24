#!/bin/bash
#########################################################################
# File Name: 7.udooneo_build.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年07月24日 星期一 23时09分09秒
#########################################################################


# ======> uboot <======

# git clone https://github.com/UDOOboard/uboot-imx

cross_compiler="${HOME}/Projects/compiler/gcc-linaro-5.5.0-2017.10-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-"

ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make udoo_neo_defconfig
ARCH=arm CROSS_COMPILE=${cross_compiler} make




# ======> kernel <======

# git clone https://github.com/UDOOboard/linux_kernel

# scripts/dtc/dtc-lexer.lex.c modify maybe is necessary:
# YYLTYPE yylloc;
# to
# extern YYLTYPE yylloc;

cross_compiler="${HOME}/Projects/compiler/gcc-linaro-5.5.0-2017.10-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-"

ARCH=arm make udoo_neo_defconfig
ARCH=arm CROSS_COMPILE=${cross_compiler} make zImage -j5
