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

import time
import random
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import itertools

import subprocess


# 模拟数据查询函数
def query_data():
    # 这里可以替换为实际的查询数据逻辑，比如从数据库或者API查询
    # return random.randint(1, 100)

    # 执行命令并捕获输出
    runCmd="adbs --idx 0 shell ps -A | grep mediaserver | awk '{print $2}'"
    result = subprocess.run(runCmd, shell=True, executable='/bin/bash', capture_output=True, text=True)
    # 输出命令的标准输出
    # print(result.stdout)

    runCmd = "adbs --idx 0 shell cat /proc/{}/status | grep -i vmrss ".format(result.stdout.replace("\n", "")) + "| awk '{print $2}'"
    result = subprocess.run(runCmd, shell=True, executable='/bin/bash', capture_output=True, text=True)
    return int(result.stdout)

# 初始化数据
x_data = []
y_data = []

# 设置图形
fig, ax = plt.subplots()
line, = ax.plot([], [], lw=2)

# 固定坐标轴范围
ax.set_xlim(0, 10)  # 固定X轴范围，例如显示10秒内的数据
ax.set_ylim(0, 120)  # 固定Y轴范围

# 设置坐标轴标签
ax.set_xlabel("Time (s)")
ax.set_ylabel("Value")

# 更新函数，用于动画绘图
def update(frame):
    current_time = frame
    new_data = query_data()  # 查询数据

    # 将数据添加到列表
    x_data.append(current_time)
    y_data.append(new_data)

    # 更新绘图数据
    line.set_data(x_data, y_data)

    # 如果数据超过X轴范围，可以选择暂停动画或其他处理方式
    # if current_time > ax.get_xlim()[1]:
    #     ax.set_xlim(0, current_time + 10)  # 动态扩展X轴范围
    # if new_data > ax.get_ylim()[1]:
    #     ax.set_ylim(0, new_data * 2)

    # 动态设置 x 和 y 轴的范围
    ax.set_xlim(min(x_data) - 1, max(x_data) + 1)
    ax.set_ylim(min(y_data) - 1, max(y_data) + 1)

    # 如果X轴超出范围，可以动态调整X轴范围
    # if len(x_data) > 10:
    #     ax.set_xlim(x_data[-10], x_data[-1])

    return line,

# 使用FuncAnimation动态更新图像
# interval，(可选)，控制每帧之间的间隔时间，单位是毫秒。默认值是200毫秒，即每秒
# 播放5帧
# 创建一个无限的迭代器
# 通过使用 itertools.count，可以在 FuncAnimation 中实现无限延拓的动画，而无需预先
# 定义 frames 参数。这种方法特别适合需要动态更新数据的情况，确保动画可以持续进行。
frames = itertools.count(start=0)
ani = FuncAnimation(fig, update, frames=frames, interval=1000, blit=True)

# 显示图像
plt.show()

