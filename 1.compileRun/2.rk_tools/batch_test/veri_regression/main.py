#!/usr/bin/env python
#########################################################################
# File Name: main.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Sat 17 May 2025 04:58:25 PM CST
#########################################################################

# 建议使用方式
#
# 初始化，初始化操作可以多次执行，但会覆盖之前的内容
# 初始化码流信息
# <exe> -c <base_cfg>.yaml --init info -o <config>.yaml
# 初始化 md5 值
# <exe> -c <config>.yaml --init md5 -o <config>.yaml
# 初始化 slt 文件
# <exe> -c <config>.yaml --init slt -o <config>.yaml
#
# 校验
# 校验 md5
# <exe> -c <config>.yaml -m dec --tag base -d "1 6" --chk md5 --dbg
# 校验 slt
# <exe> -c <config>.yaml -m dec --tag base -d "1 6" --chk slt --dbg
# 校验 yuv
# <exe> -c <config>.yaml -m dec --tag base -d "1 6" --chk yuv --dbg
#
# 输入的config文件默认为 ${HOME}/bin/veri_regression/config.yaml
# 输出的config文件如果不配置，会自动以时间进行命名，为了避免覆盖
#
#
# 使用实例
# ./main.py -c ./config.yaml --init info -o ~/bin/veri_regression/config.yaml
# ./main.py --init md5 -o ~/bin/veri_regression/config.yaml
# ./main.py --init slt -o ~/bin/veri_regression/config.yaml
# ./main.py -m dec --tag base -d "1 3" --chk md5
# ./main.py -m dec --tag base -d "1 3" --chk slt
# ./main.py -m dec --tag base -d "1 3" --chk yuv

import os
import argparse

import yaml_cfg
import utils as utl
import checker as chk
from decoder import *
from encoder import *
from pathlib import Path

init_list = ("info", "md5", "slt")
tag_list = ("all", "base", "buf_raster", "buf_fbc", "resolution", "pix_fmt")
spec_list = ("hevc", "h265", "avc", "h264", "vp9", "av1", "avs2")
chk_mtds = ("md5", "yuv", "slt")

host_wk_dir = Path.home() / 'bin'/ 'veri_regression'
host_wk_dir.mkdir(parents=True, exist_ok=True)
print('work dir: ', host_wk_dir.resolve())


def proc_paras():
    # 创建解析器
    parser = argparse.ArgumentParser(description="cmd paras proc")

    parser.add_argument("-c","--config", default=str(host_wk_dir) + "/config.yaml", help="input config file")
    parser.add_argument("-o","--cfg_out",default="", help="output config file")
    parser.add_argument("-d","--dev",    default="", help="dev list")
    parser.add_argument("-m","--mode",   default="", help="dec/enc test")
    parser.add_argument("-s","--spec",   default="", help=f"spec, {spec_list}")
    parser.add_argument("--chk",         default="md5", help=f"check method, {chk_mtds}")
    parser.add_argument("--dbg", action="store_true", default=False, help=f"dump debug info")
    # dec
    parser.add_argument("--init",   default="", help=f"{init_list}, " +
                                                     "init:spec,w,h,pix_fmt " +
                                                     "md5:yuv md5 value "+
                                                     "slt:verify file")
    parser.add_argument("--tag",    default="base", help=f"dec tag: {tag_list}")
    parser.add_argument("--width",  default="", help="width")
    parser.add_argument("--height", default="", help="height")
    parser.add_argument("--px_fmt", default="", help="pix format")
    parser.add_argument("--bit_dpt", default="", help="bit depth, 8/10")
    # enc

    # 解析命令行参数
    args = parser.parse_args()

    # 分割设备列表
    dev_adb = utl.ADBDevSelector()
    dev_adb.proc_paras(["-c"])
    dev_cnt = dev_adb.execute(quiet = True)
    args.dev = [ int(idx) for idx in args.dev.split() ]
    for dev_id in args.dev:
        if dev_id >= dev_cnt:
            print(f"error: dev opt must be in range 0-{dev_cnt-1}")
            exit(0)
    if len(args.dev) == 0:
        args.dev = list(range(dev_cnt))
        print(f"dev is None, set to all device: {args.dev}")

    # 使用参数
    print("======> cmd paras <======")
    # print(args)
    max_len = max(len(cur) for cur in vars(args).keys())
    # vars 用于返回对象的 __dict__ 属性
    for arg, value in vars(args).items():
        print(f"{arg:<{max_len}} = {value if len(str(value)) else '--'}")
    print()

    if not os.path.exists(args.config):
        # parser.print_help()
        print(f"error: config file {args.config} is not exist")
        exit(1)
    if len(args.mode) and args.mode not in ("dec", "enc"):
        print(f"error: mode opt must be in dec/enc, cur is {args.mode}")
        exit(1)
    if len(args.spec) and args.spec not in spec_list:
        print(f"error: spec opt must be in {spec_list}, cur is {args.spec}")
        exit(1)
    if len(args.chk) and args.chk not in chk_mtds:
        print(f"error: chk opt must be in {chk_mtds}, cur is {args.chk}")
        exit(1)
    if len(args.init) and args.init not in init_list:
        print(f"error: init opt must be in {init_list}, cur is {args.init}")
        exit(1)
    if len(args.tag) and args.tag not in tag_list:
        print(f"error: tag opt must be in {tag_list}, cur is {args.tag}")
        exit(1)

    return args

def video_generator(cfg, args, check_cnd = True):
    dev_adb = utl.ADBDevSelector()
    dev_adb.proc_paras(["-l"])
    dev_lst = dev_adb.execute(quiet = True)
    dev_s_lst = [ cur.split('-')[0] for cur in dev_lst]

    if args.dbg:
        print("dev info:")
        for dev_info in dev_lst:
            print(dev_info)
        print(f"dev short list: {dev_s_lst}")

    for idx in args.dev:
        dev_adb.proc_paras(["--idx", f"{idx}"])
        adb_prefix = dev_adb.execute(quiet = True).split()
        plt_support = cfg.dec_get_support(dev_s_lst[idx])

        print(f"\nplatform: {dev_s_lst[idx]} support: {plt_support}")
        if args.dbg:
            print(f"adb prefix: {adb_prefix}")

        for path, video in cfg.dec_get_all_videos():
            path_tag = cfg.dec_get_tags_for_path(path)
            video_tag = video.get("tags", [])

            if video.get("spec") not in plt_support:
                continue
            if check_cnd:
                if args.tag not in path_tag and args.tag not in video_tag:
                    continue
                if len(args.spec) > 0 and args.spec != video.get("spec"):
                    continue
                if video.get("spec") not in plt_support:
                    continue
                if len(args.width) > 0 and args.width != video.get("width"):
                    continue
                if len(args.height) > 0 and args.height != video.get("height"):
                    continue
                if len(args.px_fmt) > 0 and args.px_fmt != video.get("pix_fmt"):
                    continue
                if len(args.bit_dpt) > 0 and args.bit_dpt != video.get("bit_depth"):
                    continue

            if args.dbg:
                print(f"{path}/{video['name']}")

            yield adb_prefix, path, video, dev_s_lst[idx]

def dec_regression(args, cfg):
    m_dec = DecExecutor()

    dev_adb = utl.ADBDevSelector()
    dev_adb.proc_paras(["-l"])
    dev_lst = dev_adb.execute(quiet = True)

    for cur_adb_pfx, cur_p, cur_v, cur_plt in video_generator(cfg, args, args.dev):
        cur_org_f = f"{cur_p + '/' + cur_v.get('name', '--')}"
        if args.dbg:
            print(f"cur video info: "+
                  f"spec: {cur_v.get('spec', '--')} "+
                  f"width: {cur_v.get('width', '--')} "+
                  f"height: {cur_v.get('height', '--')} "+
                  f"px_fmt: {cur_v.get('pix_fmt', '--')} "+
                  f"bit_dpt: {cur_v.get('bit_depth', '--')} "+
                  f"path: {cur_org_f}")

        m_dec.setup(cur_v.get("spec"), cur_v.get("width"), cur_v.get("height"),
                    host_wk_dir = str(host_wk_dir), dev_wk_dir = "/data")

        if args.chk == "md5":
            out_file = m_dec.dev_run(cur_org_f, cur_adb_pfx)
            if len(cur_v.get(f"md5_{cur_plt}", "")):
                res = chk.md5_verify(out_file, cur_v.get(f"md5_{cur_plt}"), cur_org_f)
            else:
                print(f"error: md5_{cur_plt} val is Null")
        elif args.chk == "slt":
            out_file = m_dec.dev_run(cur_org_f, cur_adb_pfx, True)
            if len(cur_v.get(f"slt_{cur_plt}", "")):
                res = chk.slt_cmp_verify(out_file, cur_v.get(f"slt_{cur_plt}"),
                                         cur_org_f)
            else:
                print(f"error: md5_{cur_plt} val is Null")
        elif args.chk == "yuv":
            ff_o_fmt = ""
            if cur_v.get('pix_fmt', "") == "yuv420p":
                ff_o_fmt = "nv12"
            elif cur_v.get('pix_fmt', "") == "yuvj440p":
                ff_o_fmt = "yuvj440p"
            else:
                print(f"error: unsupported format: {cur_v.get('pix_fmt', '')} | {cur_org_f}")
                continue

            ff_o_file = m_dec.ffmpeg_dec(cur_org_f, ff_o_fmt)
            dev_o_file = m_dec.dev_run(cur_org_f, cur_adb_pfx)
            res = chk.diff_verify(ff_o_file, dev_o_file,
                                  int(cur_v.get('width', '--')),
                                  int(cur_v.get('height', '--')),
                                  ff_o_fmt,
                                  cur_org_f, threshold = 10)
        else:
            print("No check method specified")

def enc_regression(args, cfg):
    m_enc = EncExecutor()
    m_enc.setup()
    m_enc.dev_run()

def main():
    args = proc_paras()

    cfg = yaml_cfg.YamlCfgService(args.config)

    if args.init == "info":
        if len(args.mode) == 0 or args.mode == "dec":
            for path, video in cfg.dec_get_all_videos():
                cur_org_f = f"{path}/{video['name']}"
                print(cur_org_f)
                spec, width, height, pix_fmt, bit_dpt = DecExecutor.get_strm_infos(cur_org_f)
                cfg.dec_set_video_property(path, video["name"], "spec", spec)
                cfg.dec_set_video_property(path, video["name"], "width", width)
                cfg.dec_set_video_property(path, video["name"], "height", height)
                cfg.dec_set_video_property(path, video["name"], "pix_fmt", pix_fmt)
                cfg.dec_set_video_property(path, video["name"], "bit_depth", bit_dpt)
        if len(args.mode) == 0 or args.mode == "enc":
            """TODO"""
            pass
        cfg.save(args.cfg_out)
        exit(0)
    elif args.init == "md5":
        dec_tmp = DecExecutor()

        if len(args.mode) == 0 or args.mode == "dec":
            for cur_adb_pfx, cur_p, cur_v, cur_plt in video_generator(cfg, args, True):
                cur_org_f = f"{cur_p + '/' + cur_v.get('name', '--')}"
                if len(cur_v.get(f"md5_{cur_plt}", "")):
                    print(f"{cur_org_f} md5 has inited")
                    continue
                dec_tmp.setup(cur_v.get("spec"), cur_v.get("width"), cur_v.get("height"),
                            host_wk_dir = str(host_wk_dir), dev_wk_dir = "/data")
                out_file = dec_tmp.dev_run(f"{cur_org_f}", cur_adb_pfx)

                md5_val = chk.md5sum(out_file)

                cfg.dec_set_video_property(cur_p, cur_v["name"], f"md5_{cur_plt}", md5_val)
        if len(args.mode) == 0 or args.mode == "enc":
            """TODO"""
            pass
        cfg.save(args.cfg_out)
        exit(0)
    elif args.init == "slt":
        dec_tmp = DecExecutor()

        if len(args.mode) == 0 or args.mode == "dec":
            for cur_adb_pfx, cur_p, cur_v, cur_plt in video_generator(cfg, args, True):
                cur_org_f = f"{cur_p + '/' + cur_v.get('name', '--')}"
                if len(cur_v.get(f"slt_{cur_plt}", "")):
                    print(f"{cur_org_f} slt has inited")
                    continue
                dec_tmp.setup(cur_v.get("spec"), cur_v.get("width"), cur_v.get("height"),
                            host_wk_dir = str(host_wk_dir), dev_wk_dir = "/data")
                out_file = dec_tmp.dev_run(f"{cur_org_f}", cur_adb_pfx, True)
                new_fname = f"{str(host_wk_dir)}/dec_{cur_plt}_{os.path.basename(cur_v.get('name', '--'))}.verify"
                os.rename(out_file, new_fname)

                cfg.dec_set_video_property(cur_p, cur_v["name"], f"slt_{cur_plt}", new_fname)
        if len(args.mode) == 0 or args.mode == "enc":
            """TODO"""
            pass
        cfg.save(args.cfg_out)
        exit(0)

    if args.mode == "dec":
        dec_regression(args, cfg)
    if args.mode == "enc":
        enc_regression(args, cfg)

if __name__ == "__main__":
    main()
