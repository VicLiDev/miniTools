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
from itertools import chain
import subprocess
import io
import csv

# 初始化数据
x_data = []
y_data = {}
lines = {}
tags = []  # 用于存储每条曲线的标签

# 创建图形
fig, ax = plt.subplots()

# 设置坐标轴标签
ax.set_xlabel("Time (s)")
ax.set_ylabel("Value")
ax.set_title("monitor ax")

# 初始化函数：清空线条数据
def init():
    for line in lines.values():
        line.set_data([], [])
    return list(lines.values())

def gen_data():
    #== demo
    # # 动态生成 y 数据并更新每条曲线的数据
    # for tag, line in lines.items():
    #     index = tags.index(tag)  # 每个标签的索引
    #     if len(y_data[tag]) == 0:
    #         y_data[tag] = []
    #     y_data[tag].append(np.sin(frame + (index * np.pi / len(tags))))  # 不同标签有不同相位偏移
    #     line.set_data(x_data, y_data[tag])

    #==  self data proc
    runCmd="adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    result = subprocess.run(runCmd, shell=True, executable='/bin/bash', capture_output=True, text=True)

    # 使用io.BytesIO将字节串包装成类文件对象
    csv_data_stream = io.BytesIO(result.stdout.encode())

    # 由于csv模块需要字符串，我们需要将字节串解码为字符串
    # 假设CSV数据是UTF-8编码的
    csv_data_stream = io.TextIOWrapper(csv_data_stream, encoding='utf-8')

    # 假设CSV文件的第一行是列名
    # with open('tmp.csv', mode='r', newline='', encoding='utf-8') as file:
    with csv_data_stream as file:
        csv_reader = csv.DictReader(file)

        for tag, line in lines.items():
            index = tags.index(tag)  # 每个标签的索引
            if len(y_data[tag]) == 0:
                y_data[tag] = []

            cur_rss_val = 0
            cur_pss_val = 0
            # 遍历CSV文件的每一行，每行都是一个字典
            for row in csv_reader:
                # row是一个字典，其键是列名，值是对应的数据
                # print("RSS:{}\t PSS: {} \t obj: {}".format(row["RSS"], row["PSS"], row["object"]))
                if tag == row["object"]:
                    cur_rss_val = int(row["RSS"])
                    cur_pss_val = int(row["RSS"])
                    break

            y_data[tag].append(cur_rss_val)
            line.set_data(x_data, y_data[tag])


# 更新函数：更新每帧数据
def update(frame):
    x_data.append(frame)

    gen_data()

    # 如果数据超过X轴范围，可以选择暂停动画或其他处理方式
    # if current_time > ax.get_xlim()[1]:
    #     ax.set_xlim(0, current_time + 10)  # 动态扩展X轴范围
    # if new_data > ax.get_ylim()[1]:
    #     ax.set_ylim(0, new_data * 2)

    # 动态调整 x 轴和 y 轴范围
    ax.set_xlim(min(x_data) - 1, max(x_data) + 1)
    ax.set_ylim(min(chain.from_iterable(y_data.values())) - 1,
                max(chain.from_iterable(y_data.values())) + 1)

    # 如果X轴超出范围，可以动态调整X轴范围
    # if len(x_data) > 10:
    #     ax.set_xlim(x_data[-10], x_data[-1])

    return list(lines.values())

# 动态添加或删除曲线，并给每条曲线分配标签
def adjust_curves(new_tags):
    global tags, lines, y_data

    # 如果有新标签，添加新曲线
    for tag in new_tags:
        if tag not in tags:
            tags.append(tag)
            line, = ax.plot([], [], lw=2, label=tag)  # 使用标签作为label
            lines[tag] = line
            y_data[tag] = []  # 初始化对应标签的y数据

    # 删除不存在的标签对应的曲线
    for tag in tags[:]:
        if tag not in new_tags:
            lines[tag].remove()  # 从图中移除曲线
            tags.remove(tag)
            del lines[tag]
            del y_data[tag]

    # 更新图例以显示新标签
    ax.legend()

def init_mdata_lins():
    runCmd="adbs --idx 0 shell 'showmap $(pidof mediaserver) -q -t -o csv'"
    result = subprocess.run(runCmd, shell=True, executable='/bin/bash', capture_output=True, text=True)

    # 使用io.BytesIO将字节串包装成类文件对象
    csv_data_stream = io.BytesIO(result.stdout.encode())

    # 由于csv模块需要字符串，我们需要将字节串解码为字符串
    # 假设CSV数据是UTF-8编码的
    csv_data_stream = io.TextIOWrapper(csv_data_stream, encoding='utf-8')

    tag_list=[]
    # 假设CSV文件的第一行是列名
    # with open('tmp.csv', mode='r', newline='', encoding='utf-8') as file:
    with csv_data_stream as file:
        csv_reader = csv.DictReader(file)

        # 遍历CSV文件的每一行，每行都是一个字典
        for row in csv_reader:
            # row是一个字典，其键是列名，值是对应的数据
            # print("RSS:{}\t PSS: {} \t obj: {}".format(row["RSS"], row["PSS"], row["object"]))
            tag_list.append(row["object"])

    adjust_curves(tag_list)


# 初始化曲线（初始有两条曲线）
adjust_curves(['curve_1', 'curve_2'])

# 使用FuncAnimation动态更新图像
# interval，(可选)，控制每帧之间的间隔时间，单位是毫秒。默认值是200毫秒，即每秒
# 播放5帧
# 创建一个无限的迭代器
# 通过使用 itertools.count，可以在 FuncAnimation 中实现无限延拓的动画，而无需预先
# 定义 frames 参数。这种方法特别适合需要动态更新数据的情况，确保动画可以持续进行。

# 创建一个无限的迭代器
frames = itertools.count(start=0, step=0.1)
# 创建动画
ani = FuncAnimation(fig, update, frames=frames, init_func=init, blit=True)

# 动态调整曲线数量和标签
# adjust_curves(['curve_1', 'curve_2', 'curve_3', 'curve_4'])  # 添加更多曲线
init_mdata_lins()

plt.show()
