#!env python

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


if __name__ == '__main__':
    while True:
        val = input('input reg idx/offset or q(quit):').strip()
        if val == 'q':
            exit(0)
        if val == '':
            continue

        try:
            if val[:2] == '0x' or val[:2] == '0X':
                print("offset [%s | %d] --> idx: [%d]" % (val, int(val, 16), int(val, 16)/4))
            else:
                print("idx [%s | 0x%x] --> offset: [%d | 0x%x]" % (val, int(val), int(val)*4, int(val)*4))
            print()
        except:
            print("invalue input {}".format(val))
            print()
            continue
