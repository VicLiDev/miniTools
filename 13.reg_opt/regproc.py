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

def check_reg_name(regSet, update):
    regSet.sort_regs()
    regSet.sort_fields()

    reg_cnt = len(regSet.regs)
    for i in range(reg_cnt):
        cur_reg = regSet.regs[i]
        reg_name_old = cur_reg.register
        reg_name_new = str("SWREG" + str(int(cur_reg.reg_offset / 4))
                           + cur_reg.register[cur_reg.register.index("_"):])
        if reg_name_new != reg_name_old:
            print("reg_name:[%s] offset:[%d 0x%x] \nshould be [%s]\n"
                  % (reg_name_old, cur_reg.reg_offset, cur_reg.reg_offset, reg_name_new))
            if update:
                regSet.regs[i] = reg_name_new
