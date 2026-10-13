#!/usr/bin/env bash
#########################################################################
# File Name: specDebug.sh
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 03 Jun 2026 10:51:30 AM CST
#########################################################################

# -x 是 --command 的 简单写法
gdb -x $(dirname $0)/spec_debug.gdb
