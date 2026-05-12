#!/usr/bin/env python
#########################################################################
# File Name: stress_test.py
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Tue 12 May 2026 04:01:53 PM CST
#########################################################################


"""
Android 系统压力测试工具 - 运行 `python3 stress_test.py -h` 查看用法。

压力测试原理:

本工具通过多线程并发对 Android 设备施加多种压力，旨在暴露系统在极端负载下的稳定性问题，
如内核 panic、GPU 故障、DDR 异常、看门狗超时、总线错误等。

1. dmesg_monitor (始终启用)
   通过 `dmesg -w` 实时读取内核日志流，对预设关键词进行匹配。匹配到关键错误时
   以红色高亮输出到终端，同时写入 summary 日志，方便事后分析。

2. graphic (GraphicBuffer 压力)
   快速循环执行 screencap 截屏 + screenrecord 录屏，频繁分配和释放 GraphicBuffer，
   对 GPU 和显示子系统施加压力。启用 --strace 后可追踪 screenrecord 的系统调用，
   用于排查 fd 泄漏、ioctl 异常等问题。

3. activity (Activity 生命周期压力)
   反复 am start 启动 Settings → am force-stop 强杀 → HOME 键，快速创建和销毁
   Activity 窗口，测试 SurfaceFlinger/EGL 的 buffer 分配与回收逻辑。

4. io (CPU + DDR + IO 压力)
   - CPU: 4 个后台进程持续执行 SHA1 计算，占满 CPU 核心。
   - DDR/IO: 循环执行 dd 大块写文件 → 拷贝 → 删除，产生大量内存带宽和存储 IO。
   同时记录 uptime 负载趋势，用于评估系统负载水平。

所有模块以 daemon 线程方式并发运行，Ctrl+C 或 SIGTERM 信号触发时统一清理子进程。
"""

import argparse
import signal
import subprocess
import threading
import time
import os
from datetime import datetime

DEFAULT_KEYWORDS = [
    "panic", "oops", "DDR", "Dram", "timeout",
    "watchdog", "Mali", "GPU", "bus error", "halt",
]

ALL_MODULES = ("graphic", "activity", "io")


class ExtremeStressTester(threading.Thread):
    def __init__(self, transport_id, output_dir, modules, use_strace=False, extra_keywords=None):
        super().__init__()
        self.transport_id = transport_id
        self.output_dir = os.path.join(output_dir, f"device_{transport_id}")
        os.makedirs(self.output_dir, exist_ok=True)
        self.summary_file = os.path.join(self.output_dir, "extreme_issue_summary.log")
        self.modules = modules
        self.use_strace = use_strace
        self.keywords = list(DEFAULT_KEYWORDS)
        if extra_keywords:
            self.keywords.extend(extra_keywords)
        self.is_running = True
        self._sub_processes = []

    def stop(self):
        self.is_running = False
        for proc in self._sub_processes:
            try:
                proc.kill()
            except ProcessLookupError:
                pass

    def run_adb_shell(self, cmd):
        full_cmd = ["adb", "-t", self.transport_id, "shell", cmd]
        return subprocess.run(full_cmd, capture_output=True, text=True,
                              encoding='utf-8', errors='ignore')

    def dmesg_monitor(self):
        print(f"[{self.transport_id}] Kernel Monitoring Started...")
        process = subprocess.Popen(
            ["adb", "-t", self.transport_id, "shell", "dmesg", "-w"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding='utf-8', errors='ignore',
        )
        self._sub_processes.append(process)

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = os.path.join(self.output_dir, f"kernel_death_{ts}.log")
        with open(log_path, "a", encoding='utf-8') as f, \
             open(self.summary_file, "w", encoding='utf-8') as summary:
            summary.write(f"\n--- Stress Test Session @ {datetime.now()} ---\n")
            for line in process.stdout:
                if not self.is_running:
                    break
                f.write(line)
                f.flush()
                for kw in self.keywords:
                    if kw.lower() in line.lower():
                        msg = f"[{datetime.now().strftime('%H:%M:%S')}] !!! {kw.upper()} !!! {line.strip()}"
                        print(f"\033[91m[{self.transport_id}] {msg}\033[0m")
                        summary.write(msg + "\n")
                        summary.flush()

    def graphic_buffer_bomb(self):
        print(f"[{self.transport_id}] GraphicBuffer Bomb Active...")
        if self.use_strace:
            screenrecord_cmd = (
                "strace -e trace=open,openat,close,dup,dup2,dup3,fcntl,ioctl "
                "-y -tt -f -ff screenrecord --time-limit 2 /data/local/tmp/sr.mp4"
            )
        else:
            screenrecord_cmd = "screenrecord --time-limit 2 /data/local/tmp/sr.mp4"
        while self.is_running:
            self.run_adb_shell("screencap -p /data/local/tmp/sc.png")
            self.run_adb_shell(screenrecord_cmd)
            time.sleep(0.5)

    def activity_lifecycle_stress(self):
        print(f"[{self.transport_id}] Activity LifeCycle Stress Active...")
        while self.is_running:
            self.run_adb_shell("am start -n com.android.settings/.Settings")
            time.sleep(0.8)
            self.run_adb_shell("am force-stop com.android.settings")
            self.run_adb_shell("input keyevent KEYCODE_HOME")
            time.sleep(0.5)

    def compute_io_stress(self):
        print(f"[{self.transport_id}] Compute & DDR Bandwidth Stress Active...")
        cpu_procs = []
        for _ in range(4):
            p = subprocess.Popen(
                ["adb", "-t", self.transport_id, "shell", "cat /dev/urandom | sha1sum"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            cpu_procs.append(p)
        self._sub_processes.extend(cpu_procs)

        load_log = open(os.path.join(self.output_dir, "load_trend.log"), "w", encoding='utf-8')
        try:
            while self.is_running:
                self.run_adb_shell("dd if=/dev/zero of=/data/local/tmp/extreme_dd bs=1M count=300")
                self.run_adb_shell("dd if=/data/local/tmp/extreme_dd of=/data/local/tmp/extreme_dd_bak bs=1M")
                self.run_adb_shell("rm -f /data/local/tmp/extreme_dd*")
                load_info = self.run_adb_shell("uptime").stdout.strip()
                load_log.write(f"{datetime.now()}: {load_info}\n")
                load_log.flush()
        finally:
            load_log.close()

    def run(self):
        threads = [
            threading.Thread(target=self.dmesg_monitor),
        ]
        if "graphic" in self.modules:
            threads.append(threading.Thread(target=self.graphic_buffer_bomb))
        if "activity" in self.modules:
            threads.append(threading.Thread(target=self.activity_lifecycle_stress))
        if "io" in self.modules:
            threads.append(threading.Thread(target=self.compute_io_stress))

        for t in threads:
            t.daemon = True
            t.start()

        try:
            while self.is_running:
                time.sleep(1)
        except KeyboardInterrupt:
            self.is_running = False


def parse_args():
    parser = argparse.ArgumentParser(
        description="Android system stress test tool.",
        epilog=(
            "Stress modules (-m):\n"
            "  all            Enable graphic + activity + io (default).\n"
            "  dmesg_monitor  Kernel log monitor, always enabled.\n"
            "  graphic        GraphicBuffer stress: screencap + screenrecord loop.\n"
            "  activity       Activity lifecycle: launch and force-stop Settings.\n"
            "  io             CPU/DDR/IO: 4x SHA1 workers + dd copy/delete loop.\n"
            "\n"
            "Examples:\n"
            "  %(prog)s -t 1 2 3                     all modules, 3 devices\n"
            "  %(prog)s -t 1 -m graphic io --strace  graphic+io with syscall trace\n"
            "  %(prog)s -t 1 -m activity -k fault    activity stress + extra keyword\n"
            "  %(prog)s -t 1 -o /tmp/out             custom output directory\n"
            "\n"
            "Default dmesg keywords:\n"
            "  panic, oops, DDR, Dram, timeout, watchdog, Mali, GPU, bus error, halt\n"
            "\n"
            "View transport IDs: adb devices -l\n"
            "Stop test: Ctrl+C"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-t", "--transport", nargs="+", required=True, metavar="ID",
        help="adb transport ID(s), from 'adb devices -l'",
    )
    parser.add_argument(
        "-o", "--output", default="./stress_test_output", metavar="DIR",
        help="output directory for logs (default: ./stress_test_output)",
    )
    parser.add_argument(
        "-m", "--modules", nargs="+",
        choices=["all", "graphic", "activity", "io"],
        default=["all"],
        help="modules to run: all (default), graphic, activity, io. "
             "dmesg_monitor is always on",
    )
    parser.add_argument(
        "--strace", action="store_true",
        help="trace syscalls (open/ioctl/fcntl etc.) during screenrecord "
             "(graphic module only)",
    )
    parser.add_argument(
        "-k", "--keywords", nargs="*", metavar="KW",
        help="additional dmesg keywords to match, appended to defaults",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if "all" in args.modules:
        modules = set(ALL_MODULES)
    else:
        modules = set(args.modules)

    os.makedirs(args.output, exist_ok=True)

    print("\n" + "=" * 50)
    print("!!! CAUTION: EXTREME STRESS TEST STARTING !!!")
    print("This test aims to trigger System Freeze, Restart or HW Panic.")
    print(f"  Devices : {args.transport}")
    print(f"  Modules : {sorted(modules)}")
    print(f"  Strace  : {args.strace}")
    print(f"  Output  : {args.output}")
    print("=" * 50 + "\n")

    testers = [
        ExtremeStressTester(tid, args.output, modules, args.strace, args.keywords)
        for tid in args.transport
    ]
    for t in testers:
        t.start()

    def shutdown(signum, frame):
        print(f"\nSignal {signum} received, stopping all testers...")
        for t in testers:
            t.stop()

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    try:
        for t in testers:
            t.join()
    except KeyboardInterrupt:
        for t in testers:
            t.stop()
    print("\nTest terminated.")


if __name__ == "__main__":
    main()
