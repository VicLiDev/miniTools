#!/opt/homebrew/anaconda3/bin/python

# func desc:
# define field reg regset

try:
    import copy
except Exception as err:
    print(err)
    exit(0)

class Field:
    def __init__(self):
        self.fld_offset = 0
        self.field = "NULL"
        self.fld_size = 0
        self.fld_default = 0
        self.fld_acm = 0
        self.fld_abstract = "NULL"
        self.fld_desc = "NULL"

    def __repr__(self):
        return "    fld [{}] offset:[{}] size:[{}] defVal:[{}] acm:[{}] abstract:[{}] desc:[{}]".format(
                self.field, self.fld_offset, self.fld_size, self.fld_default,
                self.fld_acm, self.fld_abstract, self.fld_desc.replace('\n', "  "))
        # return "    fld [{}] offset:[{}] size:[{}] defVal:[{}] acm:[{}] abstract:[{}]".format(
        #         self.field, self.fld_offset, self.fld_size, self.fld_default,
        #         self.fld_acm, self.fld_abstract)

    def reset(self):
        self.fld_offset = 0
        self.field = "NULL"
        self.fld_size = 0
        self.fld_default = 0
        self.fld_acm = 0
        self.fld_abstract = "NULL"
        self.fld_desc = "NULL"


class Reg:
    def __init__(self):
        self.reg_offset = 0
        self.register = "NULL"
        self.reg_abstract = "NULL"
        self.reg_default = 0
        # field
        self.fields = []

    def __repr__(self):
        print("reg %s offset:%d abstract:%s defVal:%d"
              % (self.register, self.reg_offset, self.reg_abstract, self.reg_default))
        for i in range(0, len(self.fields)):
            print(self.fields[i])
        return ""

    def sort_fields(self):
        self.fields = sorted(self.fields, key=lambda field:field.fld_size)
        self.fields = sorted(self.fields, key=lambda field:field.fld_offset)

    def add_field_tail(self, field):
        cur_field = copy.deepcopy(field)
        self.fields.append(cur_field)

    def reset(self):
        self.reg_offset = 0
        self.register = "NULL"
        self.reg_abstract = "NULL"
        self.reg_default = 0
        self.fields.clear()


class RegSet:
    def __init__(self):
        self.regs = []

    def __repr__(self):
        for i in range(0, len(self.regs)):
            print("reg idx:%d" % i)
            print(self.regs[i])
        return ""

    def sort_regs(self):
        self.regs = sorted(self.regs, key=lambda reg:reg.reg_offset)

    def sort_fields(self):
        for idx in range(0, len(self.regs)):
            self.regs[idx].sort_fields()

    def add_reg_tail(self, reg):
        cur_reg = copy.deepcopy(reg);
        self.regs.append(cur_reg)

    def reset(self):
        for idx in range(0, len(self.regs)):
            self.regs[i].reset()
        self.regs.clear()



if __name__ == '__main__':
    regs = RegSet()
    cur_reg = Reg()
    cur_field = Field()

    regs.reset()
    for i in range(0,3):
        cur_reg.reset()
        for j in range(0,5):  # field
            cur_field.reset()
            cur_field.fld_offset   = j
            cur_field.field        = "sw_xxx" + str(j)
            cur_field.fld_size     = j
            cur_field.fld_default  = 0
            cur_field.fld_acm      = 0
            cur_field.fld_abstract = "abstrct_" + str(j)
            cur_field.fld_desc     = "desc_" + str(j)
            cur_reg.add_field_tail(cur_field)
        cur_reg.reg_offset   = i
        cur_reg.register     = "SWREG" + str(i) + "_FUNC"
        cur_reg.reg_abstract = "NULL"
        cur_reg.reg_default  = 0
        regs.add_reg_tail(cur_reg)

    print(regs)

    print("====== sort reg")
    reg6 = Reg()
    reg6.reg_offset = 6
    regs.add_reg_tail(reg6)
    reg5 = Reg()
    reg5.reg_offset = 5
    regs.add_reg_tail(reg5)
    print(regs)
    regs.sort_regs()
    print(regs)

    print("====== sort field")
    field_7 = Field()
    field_7.fld_offset = 7
    reg6.add_field_tail(field_7)
    field_5 = Field()
    field_5.fld_offset = 5
    reg6.add_field_tail(field_5)
    print(regs)
    reg6.sort_fields()
    print(regs)
