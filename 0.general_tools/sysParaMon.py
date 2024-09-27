#!/usr/bin/env python
#########################################################################
# File Name: sysParaMon.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 20 Sep 09:50:32 2024
#########################################################################

# 使用方法：
#
# 监控其他数据：
# 1. 修改 runCmd 为需要监控的数据命令
# 2. 修改函数：parse_data(cmd_res)，处理得到的数据，返回一个字典，
#    这个字典的key是要更新的tag，val是tag对应的值


# FuncAnimation：用于每隔一定的时间间隔（interval=1000毫秒，即1秒）更新图像。
# blit=True：提高绘图效率，只更新需要变化的部分。

# FuncAnimation 是 matplotlib.animation 模块中的一个函数，主要用于创建动态的、
# 可动画的图像。它可以使得图像随着时间逐帧更新，这种功能在可视化实时数据时非常
# 有用，比如实时数据采集、动态模拟等。
#
# 参数详解
# fig：
#   传入要绘制动画的 matplotlib 图形对象（Figure），即你要在哪个图形上绘制动画。
# func：
#   传入每一帧的更新函数。这个函数将会被反复调用，来更新每一帧的图像。它应该接收
#   一个帧索引参数（或自定义的参数），并返回要更新的图像对象。
# frames：
#   定义动画的帧数，可以是一个可迭代对象或整数。如果是整数，则动画会生成对应数量
#   的帧，帧索引从0开始。如果是一个可迭代对象，则每次调用 func 时会将其中的值传给
#   func。
# init_func (可选)：
#   一个初始化函数，只在动画开始时调用一次，通常用于设置静态背景等。返回值与 func
#   一样，应该是要绘制的 matplotlib 对象。
# fargs (可选)：
#   用于向 func 传递额外的参数。传入一个元组，作为传给 func 的额外参数。
# interval (可选)：
#   控制每帧之间的间隔时间，单位是毫秒。默认值是200毫秒，即每秒播放5帧。可以通过
#   增大或减小该值来加快或减慢动画的播放速度。
# repeat (可选)：
#   一个布尔值，决定动画是否重复播放。默认是 True，即动画播放结束后会自动重复。
# blit (可选)：
#   如果设置为 True，则只重新绘制图像中发生变化的部分，而不是重绘整个图形，这样
#   可以显著提升性能。使用blit时，通常需要返回所有更新的图像对象。

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import itertools
import subprocess
import io
import csv
import threading
import queue
import time
from itertools import chain

class ParaMonitor:
    def __init__(self, runCmd, parse_data, ax_title, use_legend = False):
        self.runCmd = runCmd
        self.parse_data = parse_data

        self.x_data = []
        self.y_data = {}
        self.lines = {}
        self.tags = [] # 用于存储每条曲线的标签
        self.texts = {} # 用于存储每条曲线的文本对象

        # 创建队列，用于线程间通信
        self.tag_queue = queue.Queue()
        self.data_queue = queue.Queue() # 用于存储后台线程获取到的数据

        # 创建图形
        self.fig, self.ax = plt.subplots()
        # 设置坐标轴标签
        self.ax.set_xlabel("Time (s)")
        self.ax.set_ylabel("Value")
        self.ax.set_title("Monitor " + ax_title)

        self.use_legend = use_legend

        # 启动后台数据获取线程
        threading.Thread(target=self.fetch_data, daemon=True).start()

        # 创建动画
        self.frames = itertools.count(start=0, step=1)
        self.ani = FuncAnimation(self.fig, self.update, frames=self.frames, init_func=self.init, blit=False, interval=1000)

    # 初始化函数：清空线条数据和文本
    def init(self):
        for line in self.lines.values():
            line.set_data([], [])
        for text in self.texts.values():
            text.set_text('')
        return list(self.lines.values()) + list(self.texts.values())

    # 数据生成函数
    def gen_data(self):
        # 从队列中获取最新的数据
        while self.data_queue.empty():
            time.sleep(0.5)
        data = self.data_queue.get()

        # 解析数据
        for tag, line in self.lines.items():
            if len(self.y_data[tag]) < len(self.x_data):
                # 填充 y_data[tag] 到 len(x_data)-1，使用 np.nan 代替 0
                self.y_data[tag].extend([np.nan] * (len(self.x_data) - 1 - len(self.y_data[tag])))
            if len(self.y_data[tag]) == len(self.x_data) - 1:
                self.y_data[tag].append(data.get(tag, np.nan))
            elif len(self.y_data[tag]) == len(self.x_data):
                self.y_data[tag][-1] = data.get(tag, np.nan)

            # 设置曲线数据
            line.set_data(self.x_data, self.y_data[tag])

            # 在曲线的右端显示标签，但先确保x_data和y_data都是有限值
            if len(self.x_data) > 0 and len(self.y_data[tag]) > 0:
                if np.isfinite(self.x_data[-1]) and np.isfinite(self.y_data[tag][-1]):
                    self.texts[tag].set_position((self.x_data[-1], self.y_data[tag][-1]))
                    self.texts[tag].set_text(tag)
                else:
                    # 如果数据不可用，清除文本，避免出现无限值
                    self.texts[tag].set_text('')

    # 更新函数：更新每帧数据
    def update(self, frame):
        # 假设我们希望在没有新数据的情况下跳过更新
        # if skip_update_inv_data and data_queue.empty():
        #     return []  # 跳过更新，返回空列表

        self.x_data.append(frame)

        # 处理来自其他线程的曲线调整请求
        while self.tag_queue.empty():
            time.sleep(0.5)
        new_tags = self.tag_queue.get()
        self.adjust_curves(new_tags)

        # 生成并更新数据
        self.gen_data()

        # 动态调整 x 轴和 y 轴范围
        if len(self.x_data) > 0:
            self.ax.set_xlim(min(self.x_data) - 1, max(self.x_data) + 1)
        if self.y_data:
            # 使用 np.nanmin 和 np.nanmax 忽略 np.nan 值
            y_min = np.nanmin(list(chain.from_iterable(self.y_data.values())))
            y_max = np.nanmax(list(chain.from_iterable(self.y_data.values())))
            self.ax.set_ylim(y_min - 1, y_max + 1)

        # 动态更新图例
        if self.use_legend:
            update_legend()

        return list(self.lines.values()) + list(self.texts.values())

    # 动态添加或删除曲线，并给每条曲线分配标签
    def adjust_curves(self, new_tags):
        # 添加新标签对应的曲线和文本
        for tag in new_tags:
            if tag not in self.tags:
                self.tags.append(tag)
                # 创建新曲线并设置标签
                line, = self.ax.plot([], [], lw=2, label=tag)
                self.lines[tag] = line
                self.y_data[tag] = []
                self.texts[tag] = self.ax.text(0, 0, '', fontsize=9, verticalalignment='center')

        # 删除不再需要的曲线和文本
        for tag in self.tags[:]:
            if tag not in new_tags:
                # 从图中移除曲线
                self.lines[tag].remove()
                # 从图中移除文本标签
                self.texts[tag].remove()
                del self.lines[tag]
                del self.y_data[tag]
                del self.texts[tag]
                self.tags.remove(tag)

    # 动态更新图例
    def update_legend():
        # 移除旧的图例（如果存在）
        if ax.get_legend() is not None:
            ax.get_legend().remove()
    
        # 创建新的图例
        ax.legend(loc='upper right')

    # 后台线程获取数据
    def fetch_data(self):
        while True:
            try:
                result = subprocess.run(self.runCmd, shell=True, capture_output=True, text=True)
                if result.returncode == 0:
                    parsed_data = self.parse_data(result)
                    current_tags = list(parsed_data.keys())
                    self.tag_queue.put(current_tags)
                    self.data_queue.put(parsed_data)
                else:
                    print(f"Command failed with return code {result.returncode}")
            except Exception as e:
                print(f"Error running command: {e}")
            time.sleep(1) # 数据刷新间隔，可以根据需要调整

    def show(self):
        plt.show()

# 使用示例
test_y = np.sin(np.linspace(0, 2 * np.pi, 100))  # 计算正弦值
test_cur_idx = 0
def parse_data_demo(cmd_res):
    # 数据解析函数
    parsed_data = {}

    global test_y
    global test_cur_idx
    parsed_data["sin"] = test_y[test_cur_idx]
    test_cur_idx = (test_cur_idx + 1) % len(test_y)
    return parsed_data

def mon_demo():
    monitor = ParaMonitor("", parse_data_demo, "demo")
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
    monitor = ParaMonitor(run_cmd, parse_data_rss, "rss")
    monitor.show()


if __name__ == "__main__":
    from multiprocessing import  Process

    # p1 = Process(target=mon_demo, args=('Python', i))
    p1 = Process(target=mon_demo)
    p1.start()

    p2 = Process(target=mon_rss)
    p2.start()

    p1.join()
    p2.join()
