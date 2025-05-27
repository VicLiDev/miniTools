#!/usr/bin/env python
#########################################################################
# File Name: sel_node.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 27 May 2025 03:44:09 AM CST
#########################################################################

# import sys
# import os
#
# def get_project_root(cur_file):
#     """获取项目根目录"""
#     current_dir = os.path.dirname(os.path.abspath(cur_file))
#     # 当遇到根目录 '/' 时停止
#     while current_dir != os.path.dirname(current_dir):
#         # 使用生成器表达式（Generator Expression）
#         # os.path.join(current_dir, marker)
#         #   生成当前目录下可能的标记文件完整路径（例如 /home/user/project/.git）。
#         # os.path.exists()
#         #   检查文件或目录是否存在。
#         # any() + 生成器表达式
#         #   对列表 ['.git', 'pyproject.toml', 'setup.py'] 中的每个标记文件，检查
#         #   是否存在。如果任一文件存在，则 any() 返回 True。
#         # 典型标记文件：
#         #   .git：Git 仓库根目录
#         #   pyproject.toml：Python 项目配置文件（现代 Poetry/Pipenv 项目）
#         #   setup.py：传统 Python 项目配置文件
#         if any(os.path.exists(os.path.join(current_dir, marker))
#                for marker in ['.git', 'pyproject.toml', 'setup.py']):
#             return current_dir
#         # 向上一级目录
#         current_dir = os.path.dirname(current_dir)
#     return os.path.dirname(cur_file)
#
# # 设置路径
# prj_root = get_project_root(__file__)
# if prj_root not in sys.path:
#     sys.path.insert(0, prj_root + "/0.general_tools")
#     from sel_node import Selector



import os
import re
import sys
from pathlib import Path

class Selector:
    def __init__(self):
        self.cache_file = Path.home() / 'bin' / 'select.cache'
        self.sel_tag = ""
        self.display_color = 36  # Cyan
        # self.cache_file - Path 对象，表示缓存文件的路径
        # .parent - 获取父目录路径
        # .mkdir() - 创建目录的方法
        # parents=True - 参数：自动创建所有必要的父目录
        # exist_ok=True - 参数：目录已存在时不报错
        self.cache_file.parent.mkdir(parents=True, exist_ok=True)

    def display(self, items, tip):
        """Display selection items with numbers"""
        print(f"\033[0m\033[1;{self.display_color}m", file=sys.stderr)
        print(f"Please select {tip}:", file=sys.stderr)
        for i, item in enumerate(items):
            print(f"  {i}. {item}", file=sys.stderr)

    def read_selection_cache(self, sel_tag, default=0):
        """Read cached selection index for the given tag"""
        if not sel_tag or not self.cache_file.exists():
            return default

        with open(self.cache_file, 'r') as f:
            for line in f:
                if line.startswith(sel_tag):
                    return int(line[len(sel_tag):].strip())
        return default

    def write_selection_cache(self, sel_tag, selection):
        """Write selection index to cache file"""
        if not sel_tag:
            return

        cache_lines = []
        updated = False

        # Read existing cache if it exists
        if self.cache_file.exists():
            with open(self.cache_file, 'r') as f:
                cache_lines = f.readlines()

        # Update or add the selection
        new_line = f"{sel_tag}{selection}\n"
        for i, line in enumerate(cache_lines):
            if line.startswith(sel_tag):
                cache_lines[i] = new_line
                updated = True
                break

        if not updated:
            cache_lines.append(new_line)

        # Write back to file
        with open(self.cache_file, 'w') as f:
            f.writelines(cache_lines)

    def select_node(self, sel_tag, items, sel_tip):
        """
        Interactive selection from a list of items

        Args:
            sel_tag: Unique tag for caching the selection
            items: List of items to select from
            sel_tip: Description of what's being selected

        Returns:
            The selected item or None if user quits
        """
        if not items:
            return None

        default_idx = self.read_selection_cache(sel_tag)

        self.display(items, sel_tip)
        print(f"cur dir: {os.getcwd()}", file=sys.stderr)

        while True:
            try:
                user_input = input(
                    f"Please select {sel_tip} or quit(q), def[{default_idx}]: "
                ).strip()

                if user_input.lower() == 'q':
                    print("======> quit <======", file=sys.stderr)
                    sys.exit(1)

                # Use default if input is empty
                selection_idx = int(user_input) if user_input else default_idx

                if 0 <= selection_idx < len(items):
                    selected = items[selection_idx]
                    print(f"--> selected index:{selection_idx}, {sel_tip}:{selected}",
                          file=sys.stderr)
                    self.write_selection_cache(sel_tag, selection_idx)
                    print("\033[0m", file=sys.stderr)
                    return selected

                print(f"--> please input num in scope 0-{len(items)-1}", file=sys.stderr)

            except ValueError:
                print("--> please enter a valid number", file=sys.stderr)

if __name__ == "__main__":
    selector = Selector()

    # Example list to select from
    test_items = ["Option A", "Option B", "Option C"]

    # Using a tag to remember the selection
    selected = selector.select_node(
            sel_tag="test_selection:",
            items=test_items,
            sel_tip="test option")

    print(f"You selected: {selected}")
