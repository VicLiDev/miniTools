#!/usr/bin/env bash
#########################################################################
# File Name: 2.conVpn.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 20 Apr 2024 06:21:31 PM CST
#########################################################################

1. install vpnc is necessary
maybe:
sudo apt-get install network-manager-vpnc
or
sudo apt-get install vpnc

2. usage
input passwd manual:
sudo vpnc-connect --gateway=<serverIp> --id <groupName> --username <userNmae>
input passwd with clear text
sudo vpnc-connect --gateway=<serverIp> --id <groupName> --secret "<pw>" --username <userNmae> --password "<pw>"
