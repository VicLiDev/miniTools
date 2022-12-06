#!/opt/homebrew/anaconda3/bin/python

def check_bit_reuse(regSet):
    regSet.sort_regs()
    regSet.sort_fields()

    reg_cnt = len(regSet.regs)
    reuse = 0
    last_offset = 0
    for i in range(reg_cnt):
        reuse = 0
        last_offset = 0
        cur_reg = regSet.regs[i]
        field_cnt = len(cur_reg.fields)
        for j in range(0, field_cnt):
            cur_field = cur_reg.fields[j]
            if cur_field.fld_offset < last_offset:
                reuse = 1
                break
            last_offset = last_offset + cur_field.fld_size
        if reuse:
            print(cur_reg)
