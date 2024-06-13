#########################################################################
# File Name: lhjbackup.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue Apr  5 15:27:21 2022
#########################################################################
#!/bin/bash

# crontab -e
# * 4 * * * sh ~/Projects/Some-program/lhjbackup.sh

# src
srcDirPerLoc="$HOME/Documents/doc"
srcDirPerNetRoot="$HOME/Documents"
srcDirPerNet="doc"

srcDirWorkLoc="$HOME/Documents/rk-doc"
srcDirWorkNetRoot="$HOME/Documents/rk-doc"
srcDirWorkNet="2.工作资料 3.输出资料 4.总结汇报"

# dst
dstDirLoc="/Volumes/exdisk/document"
dstDirNet="$HOME/Library/CloudStorage/OneDrive-Personal/文档"

echo "==> backup per dir to loc"
time cp -r $srcDirPerLoc $dstDirLoc 2> /dev/null
# cp -r $srcDirPerNet $dstDirNet
echo

echo "==> backup work dir to loc"
time cp -r $srcDirWorkLoc $dstDirLoc 2> /dev/null
echo

echo "==> backup per dir to net"
time tar -zcPvf $dstDirLoc/netBackupTmp/perbackup$(date +%Y%m%d).tar.gz -C $srcDirPerNetRoot $srcDirPerNet 2> /dev/null
time cp $dstDirLoc/netBackupTmp/perbackup$(date +%Y%m%d).tar.gz $dstDirNet
echo
echo "==> backup work dir to net"
time tar -zcPvf $dstDirLoc/netBackupTmp/workbackup$(date +%Y%m%d).tar.gz -C $srcDirWorkNetRoot \
    --exclude="./2.工作资料/kernel编译/prebuilts" --exclude="./2.工作资料/kernel编译/prebuilts.zip" \
    --exclude="./2.工作资料/协议" \
    $srcDirWorkNet 2> /dev/null
time cp $dstDirLoc/netBackupTmp/workbackup$(date +%Y%m%d).tar.gz $dstDirNet
echo

#删除文件夹下超过30天的文件
find $dstDirLoc/netBackupTmp -mtime +30 -name "*.tar.gz" -exec rm -rf {} \;
find $dstDirNet -mtime +30 -name "*.tar.gz" -exec rm -rf {} \;
