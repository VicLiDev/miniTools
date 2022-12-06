#!/opt/homebrew/anaconda3/bin/python

import argparse
import excel_rw
import regproc
import gen_chead
import scatterDisplay


def main():
    # parser params
    parser = argparse.ArgumentParser(description='reg analyze')
    parser.add_argument('-f', type=str, help="reg excele")
    args = parser.parse_args()
    fileName = args.f
    if fileName == "":
        print(args.help)

    # load write excel
    regSet = excel_rw.load_excel(fileName)
    regSet.sort_regs()
    regSet.sort_fields()
    # print(regSet)
    # save_regs_to_file("output.xlsx", regSet)

    # check reg
    regproc.check_bit_reuse(regSet)

    # gen c head
    gen_chead.add_file_head("vdpu_383.h")
    gen_chead.gen_CHead_seg("vdpu_383.h", regSet, "Vdpu383RegVersion", 0, 0)
    gen_chead.gen_CHead_seg("vdpu_383.h", regSet, "Vdpu383RegTest", 1, 20)
    gen_chead.add_file_tail("vdpu_383.h")

    # plot
    scatterDisplay.plotRegs(regSet)

    


if __name__ == '__main__':
    main()
