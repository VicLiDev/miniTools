import matplotlib.pyplot as plt
import numpy as np

# ======================================================================== 创建
# -- method 1

plt.plot([1, 2, 3, 4], [1, 4, 2, 3])  # Matplotlib plot.

# -- method 2

fig_1 = plt.figure()  # an empty figure with no Axes
fig_2, ax_2 = plt.subplots()  # a figure with a single Axes
fig_3, axs_3 = plt.subplots(2, 2)  # a figure with a 2x2 grid of Axes

ax_1 = fig_1.add_subplot(111)
ax_1.plot([1, 2, 3, 4], [0, 2, 2, 2])  # Plot some data on the axes.

ax_2.plot([1, 2, 3, 4], [2, 2, 2, 2])  # Plot some data on the axes.

axs_3[0, 0].plot([1, 2, 3, 4], [0, 2, 3, 4])  # Plot some data on the axes.
axs_3[0, 1].plot([1, 2, 3, 4], [1, 2, 3, 4])  # Plot some data on the axes.
axs_3[1, 0].plot([1, 2, 3, 4], [2, 2, 3, 4])  # Plot some data on the axes.
axs_3[1, 1].plot([1, 2, 3, 4], [3, 2, 3, 4])  # Plot some data on the axes.

# plt.show()

# ========================================================================  绘制
x = np.linspace(0, 2, 100)

# -- 各种线型

ax_1.plot(x, 0.4*x, marker=".", color="r", linestyle="-")  # Plot some data on the axes.
ax_1.plot(x, 0.8*x, marker=",", c="g", linestyle="--")  # Plot some data on the axes.
ax_1.plot(x, 1.2*x, "r-.")  # Plot some data on the axes.
ax_1.plot(x, 1.6*x, marker="v", c="c", linestyle=":")  # Plot some data on the axes.

# -- marker --
# . point
# , pixel
# o circle
# v 下三角形
# ^ 上三角形
# < 左三角形

# -- color --
# b：blue
# g:green
# r:red
# c:cyan
# m:magenta
# y:yellow
# k:black
# w:white

# -- linestyle --
# - or solid 粗线
# -- or dashed dashed line
# -. or dashdot dash-dotted
# : or dotted dotted line
# 'None' draw nothing
# ' ' or '' 什么也不绘画

# -- 附加信息

ax_2.plot(x, x, label='linear')  # Plot some data on the axes.
ax_2.plot(x, x**2, label='quadratic')  # Plot more data on the axes...
ax_2.plot(x, x**3, label='cubic')  # ... and some more.
ax_2.set_xlabel('x label')  # Add an x-label to the axes.
ax_2.set_ylabel('y label')  # Add a y-label to the axes.
ax_2.set_title("Simple Plot")  # Add a title to the axes.
ax_2.legend()  # Add a legend.

# ========================================================================

plt.show()
