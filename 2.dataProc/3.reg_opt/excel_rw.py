#!/opt/homebrew/anaconda3/bin/python

# func desc:
# read/write reg info from/to excel

try:
    import pandas as pd
    import regdef
    import copy
except Exception as err:
    print(err)
    exit(0)


def load_excel(fileName):
    df = pd.read_excel(fileName)
    df.sort_values(by="reg_offset")

    regSet = regdef.RegSet()
    cur_reg = regdef.Reg()
    cur_field = regdef.Field()

    regSet.reset()
    last_line_offset = -1
    line_cnt = len(df.iloc[:, 0])
    for idx in range(0, line_cnt):
        cur_line = df.iloc[idx]

        cur_line_offset = cur_line["reg_offset"]

        if (idx == 0) or (cur_line_offset != last_line_offset):
            if idx != 0:
                regSet.add_reg_tail(cur_reg)
            # next reg
            cur_reg.reset()
            cur_reg.reg_offset   = cur_line["reg_offset"]
            cur_reg.register     = str(cur_line["register"])
            cur_reg.reg_abstract = str(cur_line["reg_abstract"])
            cur_reg.reg_default  = cur_line["reg_default"]

        cur_field.reset()
        cur_field.fld_offset   = cur_line["fld_offset"]
        cur_field.field        = str(cur_line["field"])
        cur_field.fld_size     = cur_line["fld_size"]
        cur_field.fld_default  = cur_line["fld_default"]
        cur_field.fld_acm      = cur_line["fld_acm"]
        cur_field.fld_abstract = str(cur_line["fld_abstract"])
        cur_field.fld_desc     = str(cur_line["fld_desc"])
        cur_reg.add_field_tail(cur_field)

        last_line_offset = cur_line_offset

        if idx == (line_cnt - 1):
            regSet.add_reg_tail(cur_reg)

    return regSet


def save_regs_to_file(fileName, regSet):
    colidx = ['field', 'register', 'reg_abstract', 'reg_offset',
              'reg_default', 'fld_offset', 'fld_size', 'fld_default',
              'fld_acm', 'fld_abstract', 'fld_desc']
    df = pd.DataFrame([], columns = colidx)

    reg_cnt = len(regSet.regs)
    for i in range(0, reg_cnt):
        cur_reg = regSet.regs[i]
        cur_line = ["", "", "", 0, 0, 0, 0, 0, 0, "", ""]

        cur_line[3] = cur_reg.reg_offset
        cur_line[1] = cur_reg.register
        cur_line[2] = cur_reg.reg_abstract
        cur_line[4] = cur_reg.reg_default

        field_cnt = len(cur_reg.fields)
        for j in range(0, field_cnt):
            cur_field = cur_reg.fields[j]

            cur_line[5]  = cur_field.fld_offset
            cur_line[0]  = cur_field.field
            cur_line[6]  = cur_field.fld_size
            cur_line[7]  = cur_field.fld_default
            cur_line[8]  = cur_field.fld_acm
            cur_line[9]  = cur_field.fld_abstract
            cur_line[10] = cur_field.fld_desc
            # print(cur_line)
            df.loc[len(df.index)] = cur_line

    # print(df)
    df.to_excel(fileName)


if __name__ == '__main__':
    regSet = load_excel("test.xlsx")
    regSet.sort_regs()
    regSet.sort_fields()
    # print(regSet)
    save_regs_to_file("output.xlsx", regSet)
