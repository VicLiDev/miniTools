#!/usr/bin/env python
#########################################################################
# File Name: 2.color_palette.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue  2 Sep 20:35:28 2024
#########################################################################


import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider, Button

def yuv_to_rgb(y, u, v):
    r = y + 1.402 * (v - 128)
    g = y - 0.344136 * (u - 128) - 0.714136 * (v - 128)
    b = y + 1.772 * (u - 128)
    return np.clip([r, g, b], 0, 255).astype(int)

def rgb_to_yuv(r, g, b):
    y = 0.299 * r + 0.587 * g + 0.114 * b
    u = -0.14713 * r - 0.28886 * g + 0.436 * b + 128
    v = 0.615 * r - 0.51499 * g - 0.10001 * b + 128
    return np.clip([y, u, v], 0, 255).astype(int)

# Flag to avoid recursive updates
updating = False

def update_yuv(val):
    global updating
    if updating:
        return

    updating = True
    y = y_slider.val
    u = u_slider.val
    v = v_slider.val

    r, g, b = yuv_to_rgb(y, u, v)

    r_slider.set_val(r)
    g_slider.set_val(g)
    b_slider.set_val(b)

    color_image[:, :] = (r, g, b)
    color_display.set_data(color_image)

    # rgb_text.set_text(f'RGB: ({r}, {g}, {b})')
    fig.canvas.draw_idle()
    updating = False

def update_rgb(val):
    global updating
    if updating:
        return

    updating = True
    r = r_slider.val
    g = g_slider.val
    b = b_slider.val

    y, u, v = rgb_to_yuv(r, g, b)

    y_slider.set_val(y)
    u_slider.set_val(u)
    v_slider.set_val(v)

    color_image[:, :] = (r, g, b)
    color_display.set_data(color_image)

    # rgb_text.set_text(f'RGB: ({r}, {g}, {b})')
    fig.canvas.draw_idle()
    updating = False

def reset_y(event):
    y_slider.reset()

def reset_u(event):
    u_slider.reset()

def reset_v(event):
    v_slider.reset()

def reset_r(event):
    r_slider.reset()

def reset_g(event):
    g_slider.reset()

def reset_b(event):
    b_slider.reset()

# Initial YUV and RGB values
y_init, u_init, v_init = 128, 128, 128
r_init, g_init, b_init = yuv_to_rgb(y_init, u_init, v_init)

# Create the figure and axes for display
fig, ax = plt.subplots()
plt.subplots_adjust(left=0.1, bottom=0.45)

# Create the color display area
color_image = np.zeros((100, 100, 3), dtype=np.uint8)
color_image[:, :] = (r_init, g_init, b_init)
color_display = ax.imshow(color_image)
ax.axis('off')

# <轴坐标系>
# 使用时，坐标是根据轴的坐标系给出的transform=ax.transAxes。在此坐标系中：
# 坐标区的左下角是(0, 0)。
# 坐标区的右上角是(1, 1)。
# (0.5, 0.5)是轴的中心。
# <在上下文中>
# 0.5在 x 轴上使文本水平居中。
# -0.2在 y 轴上将文本放在轴下方，这在您想要显示绘图区域外面的文本（如标签或注释）时很有用。
# Display the initial RGB values
# rgb_text = ax.text(0.5, -0.05, f'RGB: ({r_init}, {g_init}, {b_init})', ha='center', va='center', transform=ax.transAxes, fontsize=12)

# Create YUV sliders
axcolor = 'lightgoldenrodyellow'
ax_y = plt.axes([0.1, 0.35, 0.65, 0.03], facecolor=axcolor)
ax_u = plt.axes([0.1, 0.3, 0.65, 0.03], facecolor=axcolor)
ax_v = plt.axes([0.1, 0.25, 0.65, 0.03], facecolor=axcolor)

y_slider = Slider(ax_y, 'Y', 0, 255, valinit=y_init)
u_slider = Slider(ax_u, 'U', 0, 255, valinit=u_init)
v_slider = Slider(ax_v, 'V', 0, 255, valinit=v_init)

y_slider.on_changed(update_yuv)
u_slider.on_changed(update_yuv)
v_slider.on_changed(update_yuv)

# Create RGB sliders
ax_r = plt.axes([0.1, 0.2, 0.65, 0.03], facecolor=axcolor)
ax_g = plt.axes([0.1, 0.15, 0.65, 0.03], facecolor=axcolor)
ax_b = plt.axes([0.1, 0.1, 0.65, 0.03], facecolor=axcolor)

r_slider = Slider(ax_r, 'R', 0, 255, valinit=r_init)
g_slider = Slider(ax_g, 'G', 0, 255, valinit=g_init)
b_slider = Slider(ax_b, 'B', 0, 255, valinit=b_init)

r_slider.on_changed(update_rgb)
g_slider.on_changed(update_rgb)
b_slider.on_changed(update_rgb)

# Create reset buttons for each channel
reset_y_ax = plt.axes([0.85, 0.35, 0.1, 0.04])
reset_u_ax = plt.axes([0.85, 0.3, 0.1, 0.04])
reset_v_ax = plt.axes([0.85, 0.25, 0.1, 0.04])
reset_r_ax = plt.axes([0.85, 0.2, 0.1, 0.04])
reset_g_ax = plt.axes([0.85, 0.15, 0.1, 0.04])
reset_b_ax = plt.axes([0.85, 0.1, 0.1, 0.04])

reset_y_button = Button(reset_y_ax, 'Reset Y', color=axcolor, hovercolor='0.975')
reset_u_button = Button(reset_u_ax, 'Reset U', color=axcolor, hovercolor='0.975')
reset_v_button = Button(reset_v_ax, 'Reset V', color=axcolor, hovercolor='0.975')
reset_r_button = Button(reset_r_ax, 'Reset R', color=axcolor, hovercolor='0.975')
reset_g_button = Button(reset_g_ax, 'Reset G', color=axcolor, hovercolor='0.975')
reset_b_button = Button(reset_b_ax, 'Reset B', color=axcolor, hovercolor='0.975')

reset_y_button.on_clicked(reset_y)
reset_u_button.on_clicked(reset_u)
reset_v_button.on_clicked(reset_v)
reset_r_button.on_clicked(reset_r)
reset_g_button.on_clicked(reset_g)
reset_b_button.on_clicked(reset_b)

plt.show()

