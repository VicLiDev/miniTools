#!/opt/homebrew/anaconda3/bin/python

# ex: python ./main.py -i ~/Downloads/reg/rkvdec_v2_new.xlsx ~/Downloads/reg/vdpu_383_org.xlsx -d --hl 7.5 15.5 22.5

import argparse
import excel_rw
import regproc
import gen_chead
import scatterDisplay


def main():
    # parser params
    parser = argparse.ArgumentParser(description='reg analyze')
    parser.add_argument('-i', type=str, default="", nargs='+', help="reg excele")
    parser.add_argument('-o', type=str, default="", help="reg excele")
    parser.add_argument('-c', action='store_true', default=False, help="check reg")
    parser.add_argument('-u', action='store_true', default=False, help="update reg name")
    parser.add_argument('-d', action='store_true', default=False, help="compare 2 reg list")
    parser.add_argument('-g', type=str, default="", help="generate chead")
    parser.add_argument('-p', action='store_true', default=False, help="plot reg scatter")
    parser.add_argument('--hl', type=float, nargs='+', help="reference line")
    parser.add_argument('--vl', type=float, nargs='+', help="reference line")
    args = parser.parse_args()
    print(args)
    print()

    fileList = []
    if args.i == "":
        print("input file is necessary")
        exit(0)
    elif type(args.i) == type(str()):
        fileList.append(args.i)
    elif type(args.i) == type(list()):
        fileList.extend(args.i)
    # load excel
    regSet = excel_rw.load_excel(fileList[0])

    # sort
    regSet.sort_regs()
    regSet.sort_fields()

    # check reg
    if args.c:
        regproc.check_bit_reuse(regSet)
        regproc.check_reg_name(regSet, 0)

    # update reg name
    if args.u:
        regproc.check_reg_name(regSet, 1)

    # print(regSet)
    # gen c head
    if args.g:
        gen_chead.add_file_head(args.g)
        gen_chead.gen_CHead_seg(args.g, regSet, "Vdpu383RegVersion", 0, 0)
        gen_chead.gen_CHead_seg(args.g, regSet, "Vdpu383RegTest", 1, 20)
        gen_chead.add_file_tail(args.g)

    hl = []
    vl = []
    if type(args.hl) == type(int()):
        hl.append(args.hl)
    elif type(args.hl) == type(list()):
        hl.extend(args.hl)
    if type(args.vl) == type(int()):
        vl.append(args.vl)
    elif type(args.vl) == type(list()):
        vl.extend(args.vl)
    # plot
    if args.p:
        scatterDisplay.plotRegs(fileList[0], regSet, hl, vl)

    if args.d:
        if len(fileList) != 2:
            print("2 excel is necessary")
            exit(0)
        regSet2 = excel_rw.load_excel(fileList[1])
        scatterDisplay.plotRegsDiff(fileList[0], fileList[1], regSet, regSet2, hl, vl)

    # write excel
    if args.o:
        save_regs_to_file(args.o, regSet)
    


if __name__ == '__main__':
    main()
