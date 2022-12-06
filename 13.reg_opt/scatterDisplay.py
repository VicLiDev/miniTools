#!/opt/homebrew/anaconda3/bin/python

import matplotlib.pyplot as plt
import numpy as np


def gen_def_point(regCnt):
    xVal = [[]]
    for i in range(0, regCnt):
        tmp = list([i] * 32)
        xVal.append(tmp)
    del xVal[0]
    # print(xVal)
    
    yVal = list(range(0, 32))
    yVal.extend(yVal * (regCnt-1))
    # print(yVal)
    
    sizes = [[]]
    for i in range(0, regCnt):
        tmp = list([20] * 32)
        sizes.append(tmp)
    del sizes[0]
    # print(sizes)
    
    colors = [[]]
    for i in range(0, regCnt):
        tmp = list([0] * 32)
        colors.append(tmp)
    del colors[0]
    # print(colors)

    return xVal, yVal, sizes, colors

colorList = [20, 60, 100]
colorList2 = ['r', 'g', 'b', 'c', 'm', 'y']
def plotRegs(regSet):
    # plot
    fig, ax = plt.subplots()

    # default val
    regSet.sort_regs()
    regSet.sort_fields()
    if (regSet.regs[-1].reg_offset + 4) % 4:
        print("error: offset %d is not a multiple of 4!" % (regSet.regs[-1].reg_offset))

    regCnt = int((regSet.regs[-1].reg_offset + 4) / 4)
    orgXVal, orgYVal, orgSizes, orgColors = gen_def_point(regCnt)
    ax.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)

    # reg val
    regXVal   = []
    regYVal   = []
    regSizes  = []
    regColors = []

    reg_cnt = len(regSet.regs)
    for i in range(reg_cnt):
        cur_reg = regSet.regs[i]
        field_cnt = len(cur_reg.fields)
        for j in range(0, field_cnt):
            cur_field = cur_reg.fields[j]
            for k in range(0, cur_field.fld_size):
                regXVal.append(cur_reg.reg_offset / 4)
                regYVal.append(cur_field.fld_offset + k)
                regSizes.append(200)
                regColors.append(colorList[j % 3])
                # ax.scatter(cur_reg.reg_offset / 4, cur_field.fld_offset + k, s=200,
                #            c=colorList2[j%6], edgecolor="black", marker='.', vmin=0, vmax=100)

    ax.scatter(regXVal, regYVal, s=regSizes, c=regColors, edgecolor="black", marker='.', vmin=0, vmax=100)

    ax.set_xlabel('reg idx')
    ax.set_ylabel('bit0-31')
    ax.set_title("Register distribution")

    plt.show()
