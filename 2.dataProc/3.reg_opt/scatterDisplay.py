#!/usr/bin/env python

try:
    import matplotlib.pyplot as plt
    import numpy as np
except Exception as err:
    print(err)
    exit(0)


def _gen_def_point(regCnt):
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

def _gen_plot_reg_data(regList):
    # reg val
    regXVal   = []
    regYVal   = []
    regSizes  = []
    regColors = []

    reg_cnt = len(regList)
    for i in range(reg_cnt):
        cur_reg = regList[i]
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
    return regXVal, regYVal, regSizes, regColors

colorList = [20, 60, 100]
colorList2 = ['r', 'g', 'b', 'c', 'm', 'y']
def plotRegs(fileName, regSet, hRefLine, vRefLine):
    # check
    regSet.sort_regs()
    regSet.sort_fields()
    if (regSet.regs[-1].reg_offset + 4) % 4:
        print("error: offset %d is not a multiple of 4!" % (regSet.regs[-1].reg_offset))

    # plot
    fig, ax = plt.subplots()

    # default val
    regCnt = int((regSet.regs[-1].reg_offset + 4) / 4)
    orgXVal, orgYVal, orgSizes, orgColors = _gen_def_point(regCnt)
    # ax.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)
    ax.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o')

    # plot reg
    regXVal, regYVal, regSizes, regColors = _gen_plot_reg_data(regSet.regs)
    # ax.scatter(regXVal, regYVal, s=regSizes, c=regColors, edgecolor="black", marker='.', vmin=0, vmax=100)
    ax.scatter(regXVal, regYVal, s=regSizes, c=regColors, edgecolor="black", marker='.')

    # reference line
    for i in range(len(hRefLine)):
        plt.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        plt.axvline(vRefLine[i], linestyle='--', c='orangered')

    ax.set_xlabel('reg idx')
    ax.set_ylabel('bit0-31')
    ax.set_title("Register distribution: %s" % (fileName))

    plt.show()

def _compareReg(reg1, reg2):
    if reg1.reg_offset != reg2.reg_offset:
        return False

    fieldCnt1 = len(reg1.fields)
    fieldCnt2 = len(reg2.fields)
    if fieldCnt1 != fieldCnt2:
        return False
    for i in range(fieldCnt1):
        cur_field1 = reg1.fields[i]
        cur_field2 = reg2.fields[i]
        if cur_field1.fld_offset != cur_field2.fld_offset \
                or cur_field1.fld_size != cur_field2.fld_size:
            return False
    return True


def plotRegsDiff(file1, file2, regSet1, regSet2, hRefLine, vRefLine):
    reg1_deleted = []
    reg2_added = []
    reg1_diff = []
    reg2_diff = []
    reg_plt_cnt1 = int((regSet1.regs[-1].reg_offset + 4) / 4)
    reg_plt_cnt2 = int((regSet2.regs[-1].reg_offset + 4) / 4)
    regCnt1 = len(regSet1.regs)
    regCnt2 = len(regSet2.regs)
    regSet1.sort_regs()
    regSet1.sort_fields()
    regSet2.sort_regs()
    regSet2.sort_fields()

    reg1_idx = 0
    reg2_idx = 0
    while True:
        if reg1_idx >= regCnt1 or reg2_idx >= regCnt2:
            break

        cur_reg1 = regSet1.regs[reg1_idx]
        cur_reg2 = regSet2.regs[reg2_idx]
        cur_reg1_off = cur_reg1.reg_offset
        cur_reg2_off = cur_reg2.reg_offset

        if cur_reg1_off == cur_reg2_off:
            if not _compareReg(cur_reg1, cur_reg2):
                reg1_diff.append(cur_reg1)
                reg2_diff.append(cur_reg2)
            reg1_idx += 1
            reg2_idx += 1
            continue
        elif cur_reg1_off < cur_reg2_off:
            reg1_deleted.append(cur_reg1)
            reg1_idx += 1
            continue
        else: # cur_reg1_off > cur_reg2_off
            reg2_added.append(cur_reg2)
            reg2_idx += 1
            continue

    if regCnt1 - reg1_idx > 0:
        reg1_deleted.extend(regSet1.regs[reg1_idx:])
    if regCnt2 - reg2_idx > 0:
        reg2_added.extend(regSet2.regs[reg2_idx:])

    # plot
    fig = plt.figure()
    ax1 = fig.add_subplot(2, 2, 1)
    ax2 = fig.add_subplot(2, 2, 2)
    ax3 = fig.add_subplot(2, 2, 3)
    ax4 = fig.add_subplot(2, 2, 4)

    # default val
    orgXVal, orgYVal, orgSizes, orgColors = _gen_def_point(max(reg_plt_cnt1, reg_plt_cnt2))
    ax1.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)
    ax2.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)
    ax3.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)
    ax4.scatter(orgXVal, orgYVal, s=orgSizes, c='w', edgecolor="black", marker='o', vmin=0, vmax=100)

    # ax 1: old deleted
    regXVal1, regYVal1, regSizes1, regColors1 = _gen_plot_reg_data(reg1_deleted)
    ax1.scatter(regXVal1, regYVal1, s=regSizes1, c=regColors1, edgecolor="black", marker='.', vmin=0, vmax=100)
    ax1.set_xlabel('reg idx')
    ax1.set_ylabel('bit0-31')
    ax1.set_title("Register old deleted %s" % (file1))
    # reference line
    for i in range(len(hRefLine)):
        ax1.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        ax1.axvline(vRefLine[i], linestyle='--', c='orangered')

    # ax 2: new added
    regXVal2, regYVal2, regSizes2, regColors2 = _gen_plot_reg_data(reg2_added)
    ax2.scatter(regXVal2, regYVal2, s=regSizes2, c=regColors2, edgecolor="black", marker='.', vmin=0, vmax=100)
    ax2.set_xlabel('reg idx')
    ax2.set_ylabel('bit0-31')
    ax2.set_title("Register new added %s" % (file2))
    # reference line
    for i in range(len(hRefLine)):
        ax2.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        ax2.axvline(vRefLine[i], linestyle='--', c='orangered')

    # ax 3: old diff
    regXVal3, regYVal3, regSizes3, regColors3 = _gen_plot_reg_data(reg1_diff)
    ax3.scatter(regXVal3, regYVal3, s=regSizes3, c=regColors3, edgecolor="black", marker='.', vmin=0, vmax=100)
    ax3.set_xlabel('reg idx')
    ax3.set_ylabel('bit0-31')
    ax3.set_title("Register old diff %s" % (file1))
    # reference line
    for i in range(len(hRefLine)):
        ax3.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        ax3.axvline(vRefLine[i], linestyle='--', c='orangered')

    # ax 4: new diff
    regXVal4, regYVal4, regSizes4, regColors4 = _gen_plot_reg_data(reg2_diff)
    ax4.scatter(regXVal4, regYVal4, s=regSizes4, c=regColors4, edgecolor="black", marker='.', vmin=0, vmax=100)
    ax4.set_xlabel('reg idx')
    ax4.set_ylabel('bit0-31')
    ax4.set_title("Register new diff %s" % (file2))
    # reference line
    for i in range(len(hRefLine)):
        ax4.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        ax4.axvline(vRefLine[i], linestyle='--', c='orangered')

    # reference line
    for i in range(len(hRefLine)):
        ax1.axhline(hRefLine[i], linestyle='--', c='r')
    for i in range(len(vRefLine)):
        ax1.axvline(vRefLine[i], linestyle='--', c='orangered')

    plt.show()
