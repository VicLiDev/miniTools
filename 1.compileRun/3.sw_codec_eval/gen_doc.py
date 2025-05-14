#!/usr/bin/env python
#########################################################################
# File Name: gen_doc.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Tue 06 May 2025 08:29:35 PM CST
#########################################################################

try:
    import openpyxl
    import pandas as pd
    import copy
except Exception as err:
    print(err)
    exit(0)


eval_data = "out_eval_data.txt"
excel_f  = "data.xlsx"

def read_file_to_list(filename):
    """逐行读取文件到列表中，不缓存整个文件"""
    lines = []
    with open(filename, 'r') as file:
        for line in file:
            lines.append(line.strip().split())
    return lines

def load_txt(file_n):
    data_txt = read_file_to_list(file_n)
    tbl_core_info = []
    tbl_head = []
    tbl_data = []
    data_pkt = []

    print()
    print(f"======> file {file_n}")

    # 由 grp 分割测试组，
    for cur_cfg in data_txt:
        if cur_cfg[0] == "grp":
            if len(tbl_core_info) != 0:
                data_pkt.append({
                    "core": copy.deepcopy(tbl_core_info),
                    "head": copy.deepcopy(tbl_head),
                    "data": copy.deepcopy(tbl_data),
                    })
            tbl_core_info.clear()
            tbl_head.clear()
            tbl_data.clear()
        elif cur_cfg[0] == "core":
            tbl_core_info.append(cur_cfg)
        elif cur_cfg[0] == "testType":
            tbl_head = cur_cfg
        else:
            tbl_data.append(cur_cfg)
    data_pkt.append({
        "core": copy.deepcopy(tbl_core_info),
        "head": copy.deepcopy(tbl_head),
        "data": copy.deepcopy(tbl_data),
        })


    # 由字符串计算帧率
    for idx in range(len(data_pkt)):
        cur_pkt = data_pkt[idx]

        fps_idx = cur_pkt["head"].index("frame/s")
        for row in cur_pkt["data"]:
            if len(row) != len(cur_pkt["head"]):
                print(f"line error:\n{row}")
                continue

            try:
                expr = row[fps_idx]
                if '/' in expr:
                    numerator, denominator = map(float, expr.split('/'))
                    row[fps_idx] = round(numerator / denominator, 3)  # 保留3位小数
            except Exception:
                # row[fps_idx] = None  # 无法解析时置为空
                pass


    for idx in range(len(data_pkt)):
        print(f"\n\ncur group {idx}\n")
        cur_pkt = data_pkt[idx]

        for i in range(len(cur_pkt["core"])):
            print(cur_pkt["core"][i])

        print("\n", cur_pkt["head"])
        for i in range(len(cur_pkt["data"])):
            print(cur_pkt["data"][i])


    return data_pkt

def write_to_excel(eval_data_pkt):
    try:
        eval_df_datas = []

        # 创建 DataFrame
        for idx in range(len(eval_data_pkt)):
            eval_df_core = pd.DataFrame(
                [row[1:] for row in eval_data_pkt[idx]["core"]],  # 去掉每行的 "core" 前缀
                columns=["ID", "Enabled", "Frequency (kHz)"]
            )
            eval_df_datas.append(eval_df_core)

            eval_df_video = pd.DataFrame(
                eval_data_pkt[idx]["data"],
                columns=eval_data_pkt[idx]["head"]  # 直接用 codec_type 行作为表头
            )
            eval_df_datas.append(eval_df_video)

        # 写入同一个Excel文件的不同Sheet
        with pd.ExcelWriter(excel_f) as writer:
            write_loc = 0

            for df_data in eval_df_datas:
                df_data.to_excel(writer, sheet_name="Codec Data", index=False, startrow=write_loc)
                write_loc = write_loc + len(df_data) + 2

        print(f"数据已写入 {excel_f}")
    except Exception as e:
        print(f"写入 Excel 失败: {e}")
        print("check eval df empty")
        for df_data in eval_df_datas:
            print(df_data.empty)



def main():
    eval_data_pkt = load_txt(eval_data)
    write_to_excel(eval_data_pkt)

if __name__ == "__main__":
    main()
