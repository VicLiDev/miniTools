#!/usr/bin/env python
#########################################################################
# File Name: sysParaMon_run.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 27 Sep 2024 06:58:51 PM CST
#########################################################################

import sys
import os

mon_dir = os.path.dirname(__file__) + "/../../0.general_tools/"
sys.path.insert(0, mon_dir)

import sysParaMon


def mon_demo():
    run_cmd = "adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    monitor = sysParaMon.ParaMonitor(run_cmd, sysParaMon.parse_data_demo, "demo")
    monitor.show()


def parse_data_rss(cmd_res):
    # 数据解析函数
    parsed_data = {}

    csv_data_stream = io.StringIO(cmd_res.stdout)
    csv_reader = csv.DictReader(csv_data_stream)
    parsed_data = {row["object"]: float(row["RSS"]) for row in csv_reader}
    return parsed_data

def mon_rss():
    run_cmd = "adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    monitor = sysParaMon.ParaMonitor(run_cmd, sysParaMon.parse_data_rss, "rss")
    monitor.show()


def parse_data_pss(cmd_res):
    # 数据解析函数
    parsed_data = {}

    csv_data_stream = io.StringIO(cmd_res.stdout)
    csv_reader = csv.DictReader(csv_data_stream)
    parsed_data = {row["object"]: float(row["PSS"]) for row in csv_reader}
    return parsed_data

def mon_pss():
    run_cmd = "adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    monitor = sysParaMon.ParaMonitor(run_cmd, sysParaMon.parse_data_rss, "pss")
    monitor.show()


def parse_data_all_rss(cmd_res):
    parsed_data = {}
    parsed_data["all_rss"] = int(cmd_res.stdout)
    return parsed_data

def mon_all_rss():
    run_cmd = "adbs --idx 0 shell 'cat /proc/$(pidof mediaserver)/status' | grep -i vmrss | awk '{print $2}'"
    monitor = sysParaMon.ParaMonitor(run_cmd, parse_data_all_rss, "all rss")
    monitor.show()


if __name__ == "__main__":
    from multiprocessing import  Process

    p1 = Process(target=mon_demo)
    p1.start()

    p2 = Process(target=mon_rss)
    p2.start()

    p3 = Process(target=mon_pss)
    p3.start()

    p4 = Process(target=mon_all_rss)
    p4.start()

    p1.join()
    p2.join()
    p3.join()
    p4.join()
