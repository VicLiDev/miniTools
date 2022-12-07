#!/opt/homebrew/anaconda3/bin/python

import argparse
import excel_rw
import regproc
import gen_chead
import scatterDisplay


def main():
    # parser params
    parser = argparse.ArgumentParser(description='reg analyze')
    parser.add_argument('-i', type=str, default="", help="reg excele")
    parser.add_argument('-o', type=str, default="", help="reg excele")
    parser.add_argument('-c', action='store_true', default=False, help="check reg")
    parser.add_argument('-u', action='store_true', default=False, help="update reg name")
    parser.add_argument('-g', type=str, default="", help="generate chead")
    parser.add_argument('-p', action='store_true', default=False, help="plot reg scatter")
    parser.add_argument('--hl', type=float, nargs='+', help="reference line")
    parser.add_argument('--vl', type=float, nargs='+', help="reference line")
    args = parser.parse_args()
    print(args)
    print()

    # load excel
    if args.i == "":
        exit(0)
    regSet = excel_rw.load_excel(args.i)

    # sort
    regSet.sort_regs()
    regSet.sort_fields()

    # check reg
    if args.c:
        regproc.check_bit_reuse(regSet)
        regproc.check_reg_name(regSet, 0)

    # update reg name
    if args.c:
        regproc.check_reg_name(regSet, 1)

    # print(regSet)
    # gen c head
    if args.g:
        gen_chead.add_file_head(args.g)
        gen_chead.gen_CHead_seg(args.g, regSet, "Vdpu383RegVersion", 0, 0)
        gen_chead.gen_CHead_seg(args.g, regSet, "Vdpu383RegTest", 1, 20)
        gen_chead.add_file_tail(args.g)

    # plot
    if args.p:
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
        scatterDisplay.plotRegs(args.i, regSet, hl, vl)

    # write excel
    if args.o:
        save_regs_to_file(args.o, regSet)
    


if __name__ == '__main__':
    main()
