#!/usr/bin/env python
#########################################################################
# File Name: adb_sel.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 27 May 2025 03:32:02 AM CST
#########################################################################

import sys
import os
import re
import subprocess
from typing import List, Dict, Optional, Tuple
from pathlib import Path

def get_project_root(cur_file):
    """获取项目根目录"""
    current_dir = os.path.dirname(os.path.abspath(cur_file))
    while current_dir != os.path.dirname(current_dir):
        if any(os.path.exists(os.path.join(current_dir, marker))
               for marker in ['.git', 'pyproject.toml', 'setup.py']):
            return current_dir
        current_dir = os.path.dirname(current_dir)
    return os.path.dirname(cur_file)

prj_root = get_project_root(__file__)
if prj_root not in sys.path:
    sys.path.insert(0, prj_root + "/0.general_tools")
    from sel_node import Selector


class ADBDevSelector:
    """Main class for ADB device management and selection"""

    def __init__(self):
        self.dev_ser_id_list: List[str] = []
        self.dev_tp_id_list: List[str] = []
        self.dev_name_list: List[str] = []
        self.select_list: List[str] = []

        # Command flags (matches shell script variables)
        self.cmd_org_adb_opt: List[str] = []
        self.cmd_list_devs: bool = False
        self.cmd_get_count: bool = False
        self.cmd_gen_s_style: bool = False
        self.cmd_sel_idx: Optional[int] = None

        # Configuration
        self.sel_tag_adbs: str = "adb_s:"

    def help_info(self) -> None:
        """Display help information with precise alignment using multiple prints"""
        print("Usage: <exe> <adbsParas> [<orgAdbParas>]")
        print("Options:")
        print("  -h, --help    Show this help message and exit")
        print("  -l            List all connected devices")
        print("  -c            Get count of connected devices")
        print("  -s            Generate command in 'adb -s' style, default 'adb -t' style")
        print("  --idx <num>   Generate command for device at index num")
        print()
        print("Usage Session:")
        print("  1. Use as regular adb command:")
        print("       adbs shell ls /sdcard")
        print("       adbs -s push file.txt /sdcard/")
        print("  2. Generate adb command prefix:")
        print("       adb_cmd=$(adbs)          # Uses transport ID")
        print("       adb_cmd=$(adbs -s)       # Uses serial number")

    def proc_paras(self, args: List[str]) -> None:
        # init cmd paras
        self.cmd_org_adb_opt: List[str] = []
        self.cmd_list_devs: bool = False
        self.cmd_get_count: bool = False
        self.cmd_gen_s_style: bool = False
        self.cmd_sel_idx: Optional[int] = None

        """Process command line parameters"""
        i = 0
        while i < len(args):
            arg = args[i]
            if arg in ('-h', '--help'):
                self.help_info()
                sys.exit(0)
            elif arg == '-l':
                self.cmd_list_devs = True
            elif arg == '-c':
                self.cmd_get_count = True
            elif arg == '-s':
                self.cmd_gen_s_style = True
            elif arg == '--idx':
                if i + 1 < len(args):
                    self.cmd_sel_idx = int(args[i+1])
                    i += 1
                else:
                    print("Error: --idx requires an argument", file=sys.stderr)
                    sys.exit(1)
            else:
                # Remaining arguments are adb parameters
                self.cmd_org_adb_opt = args[i:]
                break
            i += 1

    def gen_dev_info_list(self) -> None:
        """Generate device information lists"""
        try:
            # Get device serial IDs
            output = subprocess.check_output(['adb', 'devices'], text=True)
            self.dev_ser_id_list = [
                line.split()[0] for line in output.splitlines() 
                if line.strip() and 'device' in line and not line.startswith('List')
            ]

            if not self.dev_ser_id_list:
                print("No device found!", file=sys.stderr)
                sys.exit(0)

            # Get transport IDs
            output = subprocess.check_output(['adb', 'devices', '-l'], text=True)
            self.dev_tp_id_list = []
            for line in output.splitlines():
                if 'transport_id' in line:
                    transport_id = re.search(r'transport_id:(\d+)', line)
                    if transport_id:
                        self.dev_tp_id_list.append(transport_id.group(1))

            # Get device names
            self.dev_name_list = []
            for tp_id in self.dev_tp_id_list:
                try:
                    output = subprocess.check_output(
                        ['adb', '-t', tp_id, 'shell', 'cat /proc/device-tree/compatible'],
                        text=True, stderr=subprocess.PIPE
                    )
                    name_tmp = output.replace('\x00', '').strip()
                    name_tmp = max(name_tmp.split('rockchip,'), key=len)
                    self.dev_name_list.append(name_tmp)
                except subprocess.CalledProcessError:
                    self.dev_name_list.append("unknown")

            # Create selection list (matches shell script format)
            self.select_list = [
                f"{self.dev_name_list[i]} ==> serID: {self.dev_ser_id_list[i]} ==> TrsptID: {self.dev_tp_id_list[i]}"
                for i in range(len(self.dev_tp_id_list))
            ]

        except subprocess.CalledProcessError as e:
            print(f"ADB command failed: {e}", file=sys.stderr)
            sys.exit(1)

    def gen_adb_cmd(self) -> Optional[str]:
        """Generate ADB command based on selection"""
        selected_dev = ""

        if self.cmd_sel_idx is None:
            if len(self.dev_tp_id_list) > 1:
                # Use node selection tool here (implement or import as needed)
                # selected_dev = self.select_node_interactive()
                selector = Selector()
                selected_dev = selector.select_node(sel_tag=self.sel_tag_adbs,
                                                    items=self.select_list,
                                                    sel_tip="a device")
            else:
                selected_dev = self.select_list[0]
        else:
            selected_dev = self.select_list[self.cmd_sel_idx]

        if not selected_dev:
            return None

        # Extract serial or transport ID based on style
        if self.cmd_gen_s_style:
            # Format: "adb -s SERIAL"
            serial = selected_dev.split('==>')[1].strip().split()[1]
            return f"adb -s {serial}"
        else:
            # Format: "adb -t TRANSPORT_ID"
            tp_id = selected_dev.split('==>')[2].strip().split()[1]
            return f"adb -t {tp_id}"

    def select_node_interactive(self) -> str:
        """Interactive device selection (simplified version)"""
        print("Please select a device:")
        for i, item in enumerate(self.select_list):
            print(f"  {i}. {item}")

        while True:
            try:
                choice = input(f"Select device [0-{len(self.select_list)-1}], q to quit: ")
                if choice.lower() == 'q':
                    print("===> Operation cancelled <===", file=sys.stderr)
                    sys.exit(1)

                if choice.isdigit() and 0 <= int(choice) < len(self.select_list):
                    selected = self.select_list[int(choice)]
                    print(f"--> Selected: {selected}", file=sys.stderr)
                    return selected

                print(f"Please enter a number between 0-{len(self.select_list)-1}")
            except KeyboardInterrupt:
                print("\nOperation cancelled by user", file=sys.stderr)
                sys.exit(1)

    def execute(self, quiet = False) -> None:
        """Main execution flow"""
        self.gen_dev_info_list()

        if self.cmd_get_count:
            if not quiet:
                print(len(self.select_list))
            return len(self.select_list)
        elif self.cmd_list_devs:
            for item in self.select_list:
                if not quiet:
                    print(item)
            return self.select_list
        else:
            adb_cmd = self.gen_adb_cmd()
            if not adb_cmd:
                sys.exit(0)
            if not self.cmd_org_adb_opt:
                if not quiet:
                    print(adb_cmd)
                return adb_cmd
            else:
                full_cmd = f"{adb_cmd} {' '.join(self.cmd_org_adb_opt)}"
                subprocess.run(full_cmd, shell=True)

# 提供全局单例方便使用，可以定义一些函数，函数内部使用这个单例，这样就可以在主调
# 模块使用
_default_selector = ADBDevSelector()

def main():
    """Entry point for command line execution"""
    manager = ADBDevSelector()
    manager.proc_paras(sys.argv[1:])
    manager.execute()

if __name__ == "__main__":
    main()
