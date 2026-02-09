#!/usr/bin/env bash
#########################################################################
# File Name: 6.LinuxProxy.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: 2023年06月27日 星期二 19时57分23秒
#########################################################################

# 配置文件可以从其他系统的clash里copy
nohup clash-linux-386-v1.16.0 -f ~/.config/clash/agentNeo.yaml &

# set in .zshrc
# export http_proxy=http://127.0.0.1:8090
# export https_proxy=http://127.0.0.1:8090
# export all_proxy=socks5://127.0.0.1:8091

# manual set
# git config --global http.proxy http://127.0.0.1:8890
# git config --global https.proxy https://127.0.0.1:8890
# git config --global https.proxy socks5://127.0.0.1:8091
