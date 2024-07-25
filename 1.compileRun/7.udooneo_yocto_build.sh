#!env bash
#########################################################################
# File Name: yocto_build.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年07月24日 星期一 23时19分36秒
#########################################################################

# https://github.com/nxp-imx/meta-imx
# https://github.com/nxp-imx/imx-manifest

# mkdir ~/bin
# 
# 
# mkdir fsl-release-bsp && cd fsl-release-bsp
# # repo init -u git://git.freescale.com/imx/fsl-arm-yocto-bsp.git -b imx-4.1-krogoth
# repo init -u git://git.freescale.com/imx/fsl-arm-yocto-bsp.git -b imx-4.1-krogoth -m scmimx-4.1.15-2.0.0.xml
# # repo sync






# doc:
#
# https://www.nxp.com/docs/en/user-guide/IMX_YOCTO_PROJECT_USERS_GUIDE.pdf

# download reop
#
# curl http://commondatastorage.googleapis.com/git-repo-downloads/repo  > ~/bin/repo
# chmod a+x ~/bin/repo


yocto_dir=fsl-release-bsp

mkdir ${yocto_dir}
cd ${yocto_dir}
repo init -u https://github.com/nxp-imx/imx-manifest -b imx-linux-mickledore -m imx-6.1.22-2.0.0.xml
repo sync

MACHINE=imx6sxsabresd DISTRO=fsl-imx-xwayland source imx-setup-release.sh -b bld-xwayland

# Image Name	        Description
# imx-image-core	    core image with basic graphics and no multimedia
# imx-image-multimedia	image with multimedia and graphics
# imx-image-full	    image with multimedia and machine learning and Qt
bitbake imx-image-core
