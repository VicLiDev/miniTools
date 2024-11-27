#!/usr/bin/env python
#########################################################################
# File Name: test_mpp_arm_cmodel.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Mon Nov 20 16:12:20 2023
#########################################################################

import os
import pytest
import subprocess
import common.common as com
import common.mpp_opt as mppOpt
import common.cmod_opt as cmodOpt
import argparse

prot = "av1"

dev_idx = 0

# build paras
mppDir = "/data"
cmodDir = "path_to_cmodel"
# run paras
cmodWorkDirMap = { "hevc" : "{}/c_model_hevc_v2/build".format(cmodDir),
                   "avc" : "{}/c_model_h264_v2/jm18.6/".format(cmodDir),
                   "vp9"  : "{}/c_model_vp9_10bit/libvpx-1.11.0/build".format(cmodDir),
                   "avs2" : "{}/c_model_avs2/RD19.5/Lbuild".format(cmodDir),
                   "av1"  : "{}/c_model_av1/build".format(cmodDir)}
cmodRunCmdMap = { "hevc" : "./hm -b 0 -e 5 -g hevc_cmodel_cfg -f cabac=0xFFFFFFFFFFFFFFFF -d testOut -i ",
                  "avc" : "./build/jm -b 0 -e 3 -g build/h264_cmodel_cfg -f cabac=0xFFFFFFFFFFFFFFFF -d build -i ",
                  "vp9"  : "./vpxdec -o testOut/rec.yuv -b 0 -e 3 -g vp9_cmodel_cfg -f cabac=0xFFFFFFFFFFFFFFFF,loopfilter=0xFFFFFFFFFFFFFFFF -d testOut -i ",
                  "avs2" : "./Lbuild/bin/ldecod -o output/rec.yuv -b 0 -e 5 -g source/bin/avs2_file_cmodel_cfg -f cabac=0xFFFFFFFFFFFFFFFF -d testOut -i ",
                  "av1"  : "./aomdec -o testOut/output.yuv -b 0 -e 3 -c av1_vdp_cfg -g av1_cmodel_cfg -f cabac=0xFFFFFFFFFFFFFFFF,inter=0x50000 -d testOut -i "}
mppProcMap = { "hevc" : 16777220,
               "avc" : 7,
               "vp9"  : 10,
               "avs2" : 16777223,
               "av1"  : 16777224 }
mppRuncmd = "mpi_dec_test -t {} -fpga fpga_file -i ".format(mppProcMap[prot])

regParseTool = "{}/script_tools/reg_parser/exe_reg_parser_{}".format(cmodDir, prot)


dataDir=os.getcwd()
mppDirPre="/sdcard/"
cmdDirPre="/home/lhj/test/"


def checkRes(data1Dir, data2Dir, cmpFile1, cmpFile2):
    ret, res = subprocess.getstatusoutput("ls -al {} | grep Frame | wc -l".format(data1Dir))
    if ret :
        print(res)
    print("dir1 frmCnt: {}".format(res))
    frmCnt = int(res)
    ret, res = subprocess.getstatusoutput("ls -al {} | grep Frame | wc -l".format(data2Dir))
    if ret :
        print(res)
    print("dir2 frmCnt: {}".format(res))
    frmCnt2 = int(res)

    cmpFrmCnt = 0
    cmpFrmBg = 0
    if (frmCnt < frmCnt2) :
        cmpFrmCnt = frmCnt
        ret, res = subprocess.getstatusoutput("ls -al {} | grep Frame | sed \"s/.*Frame//g\" | sort | head -n 1".format(data1Dir))
        cmpFrmBg = int(res)
    else:
        cmpFrmCnt = frmCnt2
        ret, res = subprocess.getstatusoutput("ls -al {} | grep Frame | sed \"s/.*Frame//g\" | sort | head -n 1".format(data2Dir))
        cmpFrmBg = int(res)

    for frmIdx in range(cmpFrmCnt):
        file1 = "{}/Frame{}/{}".format(data1Dir, str(frmIdx + cmpFrmBg).zfill(4), cmpFile1)
        file2 = "{}/Frame{}/{}".format(data2Dir, str(frmIdx + cmpFrmBg).zfill(4), cmpFile2)
        # ret, res = subprocess.getstatusoutput("sed -i '$d' {}".format(file2))
        # if ret :
        #     print(res)
        # stats = os.stat(file2)
        # if (stats.st_size == 0):
        #     continue
        com.cmpData(file1, file2, False);
        # com.cmpData(file1, file2, True);

def checkReg(file1, file2, frmNo):
    ret = com.cmpData(file1, file2, False);
    if ret :
        com.runApp(os.getcwd(), "{} {} > regParseMpp.txt".format(regParseTool, file1, frmNo), "Reg Parse Mpp")
        com.runApp(os.getcwd(), "{} {} > regParseCmod.txt".format(regParseTool, file2, frmNo), "Reg Parse Cmod")
        # if frmNo > 0:
        #     com.runApp(os.getcwd(), "{} {} | sed '/frame_no={}/,$d' > regParseMpp.txt".format(regParseTool, file1, frmNo), "Reg Parse Mpp")
        #     com.runApp(os.getcwd(), "{} {} | sed '/frame_no={}/,$d' > regParseCmod.txt".format(regParseTool, file2, frmNo), "Reg Parse Cmod")
        # else:
        #     com.runApp(os.getcwd(), "{} {} | sed '/frame_no={}/,/frame_no={}/!d' > regParseMpp.txt".format(regParseTool, file1, frmNo-1, frmNo), "Reg Parse Mpp")
        #     com.runApp(os.getcwd(), "{} {} | sed '/frame_no={}/,/frame_no={}/!d' > regParseCmod.txt".format(regParseTool, file2, frmNo-1, frmNo), "Reg Parse Cmod")
        print("vimdiff regParseMpp.txt regParseCmod.txt")

import subprocess

def run_command(command):
    """执行给定的 shell 命令并返回输出、错误和执行状态"""
    try:
        # 使用 subprocess.run() 执行命令
        result = subprocess.run(command, shell=True, check=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # 返回标准输出、标准错误和执行状态
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.CalledProcessError as e:
        # 捕获并处理错误
        return e.stdout.strip(), e.stderr.strip(), e.returncode

'''
command = "echo \"hello\""
stdout, stderr, status = run_command(command)

# 输出命令的结果和状态
print("命令输出:\n", stdout)
print("错误输出:\n", stderr)
print("执行状态:", "成功" if status == 0 else f"失败 (状态码: {status})")
'''

def test_batch_by_list():
    print()

    # build
    # cmodOpt.buildCmod(cmodDir, prot)

    # run
    # os.environ["fpga_debug"] = "0x00000100"

    # adb cmd
    command = f"adbs --idx {dev_idx}"
    stdout, stderr, status = run_command(command)
    adbCmd = stdout

    mFile = open("source_list.txt", mode='r')
    strms = mFile.readlines()
    for curStrm in strms:   #把lines中的数据逐行读取出来
        source = curStrm.strip()
        if (len(source) == 0) or (source[0] == "#"):
            continue
        print()
        print("==> cur stream: {}".format(source))

        # ========== packet ==========
        # run mpp/cmod
        com.runApp("", f"{adbCmd} shell \"if [ -e /data/av1 ]; then rm -rf /data/av1; fi\"", "prepare Run Mpp")
        com.runApp("", f"{adbCmd} shell \"mkdir {mppDir}/{prot}\"", "prepare Run Mpp")
        # com.runApp("", "{} shell \"cd {} && {} {} -n 3\"".format(adbCmd, mppDir, mppRuncmd, mppDirPre + source), "Run Mpp")
        com.runApp("", "{} shell \"cd {} && {} {}\"".format(adbCmd, mppDir, mppRuncmd, mppDirPre + source), "Run Mpp")
        com.runApp(cmodWorkDirMap[prot], cmodRunCmdMap[prot] + cmdDirPre + source, "Run Cmod")

        # pull data from arm
        com.runApp("", "{} pull {}/{}".format(adbCmd, mppDir, prot), "Run Mpp pull")

        # check data
        if prot == "hevc":
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "spspps_debug.txt", "global_cfg_debug.txt")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "rps_debug.txt", "rps_128bit.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "scanlist_debug.txt", "scalinglist_128bit.dat")
        elif prot == "avc":
            checkRes("{}/{}".format(dataDir, prot), "{}/build".format(cmodWorkDirMap[prot]),
                     "global_cfg.dat", "global_cfg.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/build".format(cmodWorkDirMap[prot]),
                     "rps.dat", "cabac_framerps_128bit.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/build".format(cmodWorkDirMap[prot]),
                     "scanlist.dat", "cabac_scalinglist_128bit.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/build".format(cmodWorkDirMap[prot]),
                     "stream_in.dat", "stream_in_128bit.dat")
        elif prot == "vp9":
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "header_debug.txt", "cabac_header_debug.txt")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "global_cfg.dat", "global_cfg.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "stream_in.dat", "cabac_stream_in.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "segid_last.dat", "cabac_last_segid64.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "segid_cur.dat", "cabac_cur_segid_frame_64b.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cabac_kf_probe.dat", "cabac_kf_probe.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cabac_last_probe.dat", "cabac_pre_probe.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cabac_update_probe.dat", "cabac_fresh_probe.dat")
        elif prot == "avs2":
            pass
        elif prot == "av1":
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "header_debug.txt", "global_cfg_debug.txt")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cdf_rd_def.dat", "cabac_default_cdf.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cabac_cdf_out.dat", "cabac_cdf_out.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "cabac_cdf_in.dat", "cabac_cdf_in.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "stream_in.dat", "cabac_stream_in_128.dat")
            checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
                     "global_cfg.dat", "global_cfg.dat")

            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_cur_frame.dat", "colmv_cur_frame.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame0.dat", "colmv_ref_frame0.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame1.dat", "colmv_ref_frame1.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame2.dat", "colmv_ref_frame2.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame3.dat", "colmv_ref_frame3.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame4.dat", "colmv_ref_frame4.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame5.dat", "colmv_ref_frame5.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame6.dat", "colmv_ref_frame6.dat")
            # checkRes("{}/{}".format(dataDir, prot), "{}/testOut".format(cmodWorkDirMap[prot]),
            #          "colmv_ref_frame7.dat", "colmv_ref_frame7.dat")
        else:
            print("error unsupport prot")


        # ========== reg ==========
        # run mpp/cmod
        # com.runApp(dataDir, mppRuncmd + source, "Run Mpp")
        # com.runApp(cmodWorkDirMap[prot], cmodRunCmdMap[prot] + source + " --fpga", "Run Cmod")

        # for av1 reg
        # mppRegFile = "{}/{}".format(dataDir, "fpga_file")
        # streamDir, streamName = os.path.split(source)
        # cModRegFile = "{}/testOut/{}_fpga".format(cmodWorkDirMap[prot], streamName)
        # checkReg(mppRegFile, cModRegFile, 1)

def proc_paras():
    # 创建解析器
    parser = argparse.ArgumentParser(description="cmd paras proc demo")

    parser.add_argument("-p","--prot", type=str, default="av1", help="prot hevc|vp9|avs2|avc|av1")
    parser.add_argument("-d","--dev", type=int, default=0, help="device idx")

    args = parser.parse_args()

    prot = args.prot
    dev_idx = args.dev

    return

if __name__ == "__main__":
    proc_paras()
    pytest.main(["./test_mpp_arm_cmodel.py::test_batch_by_list", "-s", "-v", "-x"])
    # test_batch_by_list()
