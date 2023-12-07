#!/opt/homebrew/anaconda3/bin/python

def _add_reg(file, reg):
    if (len(reg.fields) == 1) and (reg.fields[0].fld_offset == 0):
        field_name = reg.fields[0].field
        reg_name = "reg" + str(int(reg.reg_offset/4)) + field_name[field_name.index("_"):]
        file.write("    /* %s */\n" % (reg.register))
        file.write("    RK_U32 %s;\n\n" % (reg_name))
    else:
        file.write("    struct %s {\n" % (reg.register))

        last_proc_offset = -1;
        fld_reverse_cnt = 0
        for i in range(len(reg.fields)):
            cur_field = reg.fields[i]
            remain_bit = cur_field.fld_offset - last_proc_offset - 1
            if remain_bit > 0:
                file.write("        RK_U32 %s : %d;\n"
                           % (("reserve"+str(int(fld_reverse_cnt))).ljust(30,' '), remain_bit))
                fld_reverse_cnt = fld_reverse_cnt + 1
                last_proc_offset = last_proc_offset + remain_bit

            # add field
            fld_name = cur_field.field
            if (cur_field.field[:3] == "sw_"):
                fld_name = cur_field.field[3:]
            file.write("        RK_U32 %s : %d;\n" % (fld_name.ljust(30,' '), cur_field.fld_size))
            last_proc_offset = last_proc_offset + cur_field.fld_size

        if last_proc_offset < 31:
            file.write("        RK_U32 %s : %d;\n"
                       % (("reserve"+str(int(fld_reverse_cnt))).ljust(30,' '), 31 - last_proc_offset))


        file.write("    } reg%d;\n\n" % (int(reg.reg_offset/4)))

def add_file_head(fileName):
    file = open(fileName,'w')
    file.write('/*\n')
    file.write(' * Copyright 2022 Rockchip Electronics Co. LTD\n')
    file.write(' *\n')
    file.write(' * Licensed under the Apache License, Version 2.0 (the "License");\n')
    file.write(' * you may not use this file except in compliance with the License.\n')
    file.write(' * You may obtain a copy of the License at\n')
    file.write(' *')
    file.write(' *      http://www.apache.org/licenses/LICENSE-2.0\n')
    file.write(' *\n')
    file.write(' * Unless required by applicable law or agreed to in writing, software\n')
    file.write(' * distributed under the License is distributed on an "AS IS" BASIS,\n')
    file.write(' * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n')
    file.write(' * See the License for the specific language governing permissions and\n')
    file.write(' * limitations under the License.\n')
    file.write(' */\n\n')
    file.write("#ifndef __%s__\n" % (fileName.upper().replace('.', '_')))
    file.write("#define __%s__\n\n" % (fileName.upper().replace('.', '_')))
    file.close()

def add_file_tail(fileName):
    file = open(fileName,'a')
    file.write("#endif /* __%s__ */" % (fileName.upper().replace('.', '_')))
    file.close()

def gen_CHead_seg(fileName, regSet, segName, begIdx, endIdx):
    if begIdx > endIdx:
        print("error: offBegin %d > offEnd %d" % (offBegin, offEnd))
        return

    file = open(fileName,'a')
    regSet.sort_regs()
    regSet.sort_fields()

    file.write("typedef struct %s_t {\n" % (segName))

    reg_cnt = len(regSet.regs)
    last_reg_idx = begIdx - 1
    for i in range(reg_cnt):
        # check
        cur_reg = regSet.regs[i]
        cur_reg_idx = cur_reg.reg_offset / 4
        if cur_reg_idx < begIdx or cur_reg_idx > endIdx:
            continue

        # add reserve
        reserve_cnt = cur_reg_idx - last_reg_idx - 1;
        if reserve_cnt > 1:
            file.write("    RK_U32 reserve_reg%d_%d[%d];\n\n"
                       % (int(last_reg_idx+1), int(cur_reg_idx-1), reserve_cnt))
        elif reserve_cnt == 1:
            file.write("    RK_U32 reserve_reg%d;\n\n" % (int(cur_reg_idx-1)))
        last_reg_idx = cur_reg_idx - 1

        # add reg
        _add_reg(file, cur_reg)
        last_reg_idx = cur_reg_idx


    reserve_cnt = endIdx - last_reg_idx;
    if reserve_cnt > 1:
        file.write("    RK_U32 reserve_reg%d_%d[%d];\n\n"
                   % (int(last_reg_idx+1), int(endIdx), reserve_cnt))
    elif reserve_cnt == 1:
        file.write("    RK_U32 reserve_reg%d;\n\n" % (int(endIdx)))

    file.write("} %s;\n\n" % (segName))
    file.close()
