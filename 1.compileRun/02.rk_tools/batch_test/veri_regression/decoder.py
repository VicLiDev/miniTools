#!/usr/bin/env python
#########################################################################
# File Name: decoder.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:58:55 PM CST
#########################################################################

import os
import utils as utl
import subprocess
import av

class DecExecutor:
    def __init__(self, dev_wk_dir = "/sdcard", out_fname = "output"):
        self.mpp_spec_map = {"hevc" : 16777220,
                             "h265" : 16777220,
                             "avc"  : 7,
                             "h264" : 7,
                             "vp8"  : 9,
                             "vp9"  : 10,
                             "av1"  : 16777224,
                             "avs2" : 16777223,
                             "mpeg2video" : 2,
                             "mpeg4" : 4,
                             "mjpeg" : 8}

        self.cur_spec   = "hevc"
        self.cur_w      = 0
        self.cur_h      = 0
        self.cur_px_fmt = ""
        self.cur_bit_dp = 0
        self.multi_ins = False
        # Single Instance
        self.sgl_ins_exe = "mpi_dec_test"
        # Multiple Instances
        self.multi_ins_exe = "mpi_dec_multi_test"
        self.host_wk_dir = "."
        self.dev_wk_dir = dev_wk_dir
        self.out_file = out_fname

    def setup(self, spec = "hevc", w = 0, h = 0, multi_ins = False,
              host_wk_dir = ".", dev_wk_dir = "/sdcard"):
        self.cur_spec    = spec
        self.cur_w       = w
        self.cur_h       = h
        self.multi_ins   = multi_ins
        self.host_wk_dir = host_wk_dir
        self.dev_wk_dir  = dev_wk_dir

    def get_strm_infos(strm):
        # opencv 不支持获取 pix fmt
        # pillow 只支持图片，不支持视频
        # PyAV 是 FFmpeg 的 Python 绑定，但需要自己判断图片和视频，比较麻烦

        # # video
        # container = av.open(strm)
        # v_strm = container.streams.video[0]
        # return v_strm.codec_context.name, v_strm.width, v_strm.height, v_strm.codec_context.pix_fmt

        # # img
        # container = av.open(strm)
        # frame = next(container.decode(video=0))  # 解码第一帧
        # print(f"Pix_fmt: {frame.format.name}")   # 像素格式（如 'rgb24'）


        # -v error                 设置日志级别为 error，只显示错误信息，避免冗余输出。
        # -select_streams v:0      选择 第 0 个视频流（v:0 表示第一个视频轨道，跳过音频/字幕流）。
        # -show_entries stream=... 指定要显示的字段：
        #                          codec_name：编码格式（如 h264/hevc/av1）
        #                          width：视频宽度（像素）
        #                          height：视频高度（像素）
        #                          pix_fmt：像素格式（如 yuv420p/yuv422p）
        # -of csv=p=0              设置输出格式为 CSV，并去掉表头（p=0 表示不打印字段名）。
        # ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt -of csv=p=0 <input>
        ffprobe_cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                       "stream=codec_name,width,height,pix_fmt", "-of", "csv=p=0", strm]
        stdout, stderr, status = utl.run_command(ffprobe_cmd)
        if int(status) != 0:
            print("==> error:")
            print(f"cmd: {ffprobe_cmd}")
            print(f"stdout:\n{stdout}", )
            print(f"stderr:\n{stderr}")
            print(f"status: {status}")
            exit(0)
        info_lst = stdout.split(",")

        spec = info_lst[0]
        width = info_lst[1]
        height = info_lst[2]
        pix_fmt = info_lst[3]

        bit_depth_map = {'10le': 10, '10be': 10,
                         '12le': 12, '12be': 12,
                         '14le': 14, '14be': 14,
                         '16le': 16, '16be': 16}
        # 提取后缀并匹配
        suffix = pix_fmt[-4:]  # 取最后4个字符
        bit_dpt = bit_depth_map.get(suffix, 8)  # 默认8bit

        return spec, width, height, pix_fmt, bit_dpt

    def _chk_run_result(self, stdout, stderr, status, cmd):
        if int(status) != 0:
            print("==> error:")
            print("cmd: ", cmd)
            print(f"stdout:\n{stdout}", )
            print(f"stderr:\n{stderr}")
            print(f"status: {status}")
            exit(0)

    def ffmpeg_dec(self, file, out_fmt):
        ff_o_fname = self.host_wk_dir + '/' + self.out_file + "_ffmpeg.yuv"
        dec_cmd = f"ffmpeg -i {file} -c:v rawvideo".split()
        if len(out_fmt):
            dec_cmd = dec_cmd + f"-pix_fmt {out_fmt} {ff_o_fname} -y".split()
        else:
            dec_cmd = dec_cmd + f"{ff_o_fname} -y".split()
        stdout, stderr, status = utl.run_command(dec_cmd)
        self._chk_run_result(stdout, stderr, status, dec_cmd)

        return ff_o_fname

    def dev_run(self, strm_path, adb_prefix, en_slt = False):
        # push to dev
        push_cmd = adb_prefix + ["push", strm_path, self.dev_wk_dir]
        stdout, stderr, status = utl.run_command(push_cmd)
        self._chk_run_result(stdout, stderr, status, push_cmd)
        # exe dec
        dec_cmd = adb_prefix + ["shell", self.sgl_ins_exe,
                                "-i", self.dev_wk_dir + '/' + os.path.basename(strm_path),
                                "-w", str(self.cur_w),
                                "-h", str(self.cur_h),
                                "-t", str(self.mpp_spec_map[self.cur_spec])]
        if en_slt:
            dec_cmd = dec_cmd + ["-slt", self.dev_wk_dir + '/' + self.out_file]
        else:
            dec_cmd = dec_cmd + ["-o", self.dev_wk_dir + '/' + self.out_file]
        stdout, stderr, status = utl.run_command(dec_cmd)
        self._chk_run_result(stdout, stderr, status, dec_cmd)
        # pull from dev
        pull_cmd = adb_prefix + ["pull", self.dev_wk_dir + '/' + self.out_file,
                                 self.host_wk_dir]
        stdout, stderr, status = utl.run_command(pull_cmd)
        self._chk_run_result(stdout, stderr, status, pull_cmd)
        # rm strm in dev
        rm_cmd = adb_prefix + ["shell", "rm", self.dev_wk_dir + '/' + os.path.basename(strm_path)]
        stdout, stderr, status = utl.run_command(rm_cmd)
        self._chk_run_result(stdout, stderr, status, rm_cmd)
        rm_cmd = adb_prefix + ["shell", "rm", self.dev_wk_dir + '/' + self.out_file]
        stdout, stderr, status = utl.run_command(rm_cmd)
        self._chk_run_result(stdout, stderr, status, rm_cmd)

        return self.host_wk_dir + '/' + self.out_file

