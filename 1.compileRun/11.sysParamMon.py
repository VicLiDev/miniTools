#!/usr/bin/env python
#########################################################################
# File Name: 11.sysParamMon.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 20 Sep 09:50:32 2024
#########################################################################

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

# user control
need_update_legend = False  # 控制是否更新图例
skip_update_inv_data = True  # 控制是否跳过没有数据的时间点

# 初始化数据
x_data = []
y_data = {}
lines = {}
tags = []  # 用于存储每条曲线的标签
texts = {}  # 用于存储每条曲线的文本对象

# 创建一个队列，用于线程间通信
tag_queue = queue.Queue()
data_queue = queue.Queue()  # 用于存储后台线程获取到的数据

# 创建图形
fig, ax = plt.subplots()

# 设置坐标轴标签
ax.set_xlabel("Time (s)")
ax.set_ylabel("Value")
ax.set_title("Monitor ax")

# 初始化函数：清空线条数据和文本
def init():
    for line in lines.values():
        line.set_data([], [])
    for text in texts.values():
        text.set_text('')
    return list(lines.values()) + list(texts.values())

# 数据生成函数
def gen_data():
    # 从队列中获取最新的数据
    if not data_queue.empty():
        csv_data = data_queue.get()

        # 解析CSV数据
        for tag, line in lines.items():
            if len(y_data[tag]) < len(x_data):
                # 填充 y_data[tag] 到 len(x_data)-1，使用 np.nan 代替 0
                y_data[tag].extend([np.nan] * (len(x_data) - 1 - len(y_data[tag])))
            if len(y_data[tag]) == len(x_data) - 1:
                # 获取当前标签的值
                matched_row = next((row for row in csv_data if row["object"] == tag), None)
                if matched_row:
                    cur_rss_val = int(matched_row["RSS"])
                else:
                    cur_rss_val = np.nan  # 没有数据时用 np.nan 填充
                y_data[tag].append(cur_rss_val)
            elif len(y_data[tag]) == len(x_data):
                # 如果已经有足够的数据，覆盖最后一个值
                matched_row = next((row for row in csv_data if row["object"] == tag), None)
                if matched_row:
                    y_data[tag][-1] = int(matched_row["RSS"])
                else:
                    y_data[tag][-1] = np.nan

            # 设置曲线数据
            line.set_data(x_data, y_data[tag])

            # 在曲线的右端显示标签，但先确保x_data和y_data都是有限值
            if len(x_data) > 0 and len(y_data[tag]) > 0:
                if np.isfinite(x_data[-1]) and np.isfinite(y_data[tag][-1]):
                    texts[tag].set_position((x_data[-1], y_data[tag][-1]))
                    texts[tag].set_text(tag)
                else:
                    # 如果数据不可用，清除文本，避免出现无限值
                    texts[tag].set_text('')

# 更新函数：更新每帧数据
def update(frame):
    # 假设我们希望在没有新数据的情况下跳过更新
    if skip_update_inv_data == True and data_queue.empty():
        return []  # 跳过更新，返回空列表

    x_data.append(frame)

    # 处理来自其他线程的曲线调整请求
    while not tag_queue.empty():
        new_tags = tag_queue.get()
        adjust_curves(new_tags)

    # 生成并更新数据
    gen_data()

    # 动态调整 x 轴和 y 轴范围
    if len(x_data) > 0:
        ax.set_xlim(min(x_data) - 1, max(x_data) + 1)
    if y_data:
        # 使用 np.nanmin 和 np.nanmax 忽略 np.nan 值
        y_min = np.nanmin(list(chain.from_iterable(y_data.values())))
        y_max = np.nanmax(list(chain.from_iterable(y_data.values())))
        ax.set_ylim(y_min - 1, y_max + 1)

    # 动态更新图例
    if need_update_legend:
        update_legend()

    return list(lines.values()) + list(texts.values())

# 动态添加或删除曲线，并给每条曲线分配标签
def adjust_curves(new_tags):
    global tags, lines, y_data, texts

    # 添加新标签对应的曲线和文本
    for tag in new_tags:
        if tag not in tags:
            tags.append(tag)
            line, = ax.plot([], [], lw=2, label=tag)  # 创建新曲线并设置标签
            lines[tag] = line
            y_data[tag] = []
            texts[tag] = ax.text(0, 0, '', fontsize=9, verticalalignment='center')

    # 删除不再需要的曲线和文本
    for tag in tags[:]:
        if tag not in new_tags:
            lines[tag].remove()  # 从图中移除曲线
            texts[tag].remove()  # 从图中移除文本标签
            del lines[tag]
            del y_data[tag]
            del texts[tag]
            tags.remove(tag)

# 动态更新图例
def update_legend():
    # 移除旧的图例（如果存在）
    if ax.get_legend() is not None:
        ax.get_legend().remove()

    # 创建新的图例
    ax.legend(loc='upper right')

# 后台线程获取数据
def fetch_data():
    runCmd = "adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    while True:
        try:
            result = subprocess.run(runCmd, shell=True, executable='/bin/bash', capture_output=True, text=True)
            if result.returncode == 0:
                csv_data_stream = io.StringIO(result.stdout)
                csv_reader = csv.DictReader(csv_data_stream)
                csv_data = list(csv_reader)

                # 提取当前可用的标签
                current_tags = [row["object"] for row in csv_data]

                # 将当前标签放入队列，以便在更新中使用
                tag_queue.put(current_tags)

                # 将数据放入数据队列
                data_queue.put(csv_data)
            else:
                print(f"Command failed with return code {result.returncode}")
        except Exception as e:
            print(f"Error running command: {e}")
        time.sleep(1)  # 数据刷新间隔，可以根据需要调整

# 启动后台数据获取线程
threading.Thread(target=fetch_data, daemon=True).start()

# 创建动画
frames = itertools.count(start=0, step=1)  # step=1 表示每帧递增1，调整为适合的时间步长
ani = FuncAnimation(fig, update, frames=frames, init_func=init, blit=False, interval=1000)

plt.show()
