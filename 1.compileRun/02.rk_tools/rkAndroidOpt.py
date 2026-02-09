#!/usr/bin/env bash
#########################################################################
# File Name: rkAndroidOpt.py
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Fri 06 Sep 2024 05:04:50 PM CST
#########################################################################

# # 快速输入
# adb shell input text <text>
# # 亮屏/熄屏
# adb shell input keyevent 26
# # 屏幕解锁
# # 这个命令会模拟从屏幕(300, 800)位置滑动到(300, 400)位置的操作，通常表现为屏幕向上滑动。
# adb shell input swipe 300 800 300 400
# # 点击屏幕
# adb shell input tap 500 500

# 分组后的按键选项数据
keycode_groups = {
    "Phone Keys": [
        ("KEYCODE_CALL", "拨号键"),
        ("KEYCODE_ENDCALL", "挂机键"),
        ("KEYCODE_HOME", "按键Home"),
        ("KEYCODE_MENU", "菜单键"),
        ("KEYCODE_BACK", "返回键"),
        ("KEYCODE_SEARCH", "搜索键"),
        ("KEYCODE_CAMERA", "拍照键"),
        ("KEYCODE_FOCUS", "拍照对焦键"),
        ("KEYCODE_POWER", "电源键"),
        ("KEYCODE_NOTIFICATION", "通知键"),
        ("KEYCODE_MUTE", "话筒静音键"),
        ("KEYCODE_VOLUME_MUTE", "扬声器静音键"),
        ("KEYCODE_VOLUME_UP", "音量增加键"),
        ("KEYCODE_VOLUME_DOWN", "音量减小键")
    ],
    "Control Keys": [
        ("KEYCODE_ENTER", "回车键"),
        ("KEYCODE_ESCAPE", "ESC键"),
        ("KEYCODE_DPAD_CENTER", "导航键 确定键"),
        ("KEYCODE_DPAD_UP", "导航键 向上"),
        ("KEYCODE_DPAD_DOWN", "导航键 向下"),
        ("KEYCODE_DPAD_LEFT", "导航键 向左"),
        ("KEYCODE_DPAD_RIGHT", "导航键 向右"),
        ("KEYCODE_MOVE_HOME", "光标移动到开始键"),
        ("KEYCODE_MOVE_END", "光标移动到末尾键"),
        ("KEYCODE_PAGE_UP", "向上翻页键"),
        ("KEYCODE_PAGE_DOWN", "向下翻页键"),
        ("KEYCODE_DEL", "退格键"),
        ("KEYCODE_FORWARD_DEL", "删除键"),
        ("KEYCODE_INSERT", "插入键"),
        ("KEYCODE_TAB", "Tab键"),
        ("KEYCODE_NUM_LOCK", "小键盘锁"),
        ("KEYCODE_CAPS_LOCK", "大写锁定键"),
        ("KEYCODE_BREAK", "Break/Pause键"),
        ("KEYCODE_SCROLL_LOCK", "滚动锁定键"),
        ("KEYCODE_ZOOM_IN", "放大键"),
        ("KEYCODE_ZOOM_OUT", "缩小键")
    ],
    "Basic Keys": [
        ("KEYCODE_0", "按键'0'"),
        ("KEYCODE_1", "按键'1'"),
        ("KEYCODE_2", "按键'2'"),
        ("KEYCODE_3", "按键'3'"),
        ("KEYCODE_4", "按键'4'"),
        ("KEYCODE_5", "按键'5'"),
        ("KEYCODE_6", "按键'6'"),
        ("KEYCODE_7", "按键'7'"),
        ("KEYCODE_8", "按键'8'"),
        ("KEYCODE_9", "按键'9'"),
        ("KEYCODE_A", "按键'A'"),
        ("KEYCODE_B", "按键'B'"),
        ("KEYCODE_C", "按键'C'"),
        ("KEYCODE_D", "按键'D'"),
        ("KEYCODE_E", "按键'E'"),
        ("KEYCODE_F", "按键'F'"),
        ("KEYCODE_G", "按键'G'"),
        ("KEYCODE_H", "按键'H'"),
        ("KEYCODE_I", "按键'I'"),
        ("KEYCODE_J", "按键'J'"),
        ("KEYCODE_K", "按键'K'"),
        ("KEYCODE_L", "按键'L'"),
        ("KEYCODE_M", "按键'M'"),
        ("KEYCODE_N", "按键'N'"),
        ("KEYCODE_O", "按键'O'"),
        ("KEYCODE_P", "按键'P'"),
        ("KEYCODE_Q", "按键'Q'"),
        ("KEYCODE_R", "按键'R'"),
        ("KEYCODE_S", "按键'S'"),
        ("KEYCODE_T", "按键'T'"),
        ("KEYCODE_U", "按键'U'"),
        ("KEYCODE_V", "按键'V'"),
        ("KEYCODE_W", "按键'W'"),
        ("KEYCODE_X", "按键'X'"),
        ("KEYCODE_Y", "按键'Y'"),
        ("KEYCODE_Z", "按键'Z'")
    ],
    "Symbols": [
        ("KEYCODE_PLUS", "按键'+'"),
        ("KEYCODE_MINUS", "按键'-'"),
        ("KEYCODE_STAR", "按键'*'"),
        ("KEYCODE_SLASH", "按键'/'"),
        ("KEYCODE_EQUALS", "按键'='"),
        ("KEYCODE_AT", "按键'@'"),
        ("KEYCODE_POUND", "按键'#'"),
        ("KEYCODE_APOSTROPHE", "按键'单引号'"),
        ("KEYCODE_BACKSLASH", "按键'\\'"),
        ("KEYCODE_COMMA", "按键','"),
        ("KEYCODE_PERIOD", "按键'.'"),
        ("KEYCODE_LEFT_BRACKET", "按键'['"),
        ("KEYCODE_RIGHT_BRACKET", "按键']'"),
        ("KEYCODE_SEMICOLON", "按键';'"),
        ("KEYCODE_GRAVE", "按键'`'"),
        ("KEYCODE_SPACE", "空格键")
    ],
    "Media Keys": [
        ("KEYCODE_MEDIA_PLAY", "多媒体键 播放"),
        ("KEYCODE_MEDIA_STOP", "多媒体键 停止"),
        ("KEYCODE_MEDIA_PAUSE", "多媒体键 暂停"),
        ("KEYCODE_MEDIA_PLAY_PAUSE", "多媒体键 播放/暂停"),
        ("KEYCODE_MEDIA_FAST_FORWARD", "多媒体键 快进"),
        ("KEYCODE_MEDIA_REWIND", "多媒体键 快退"),
        ("KEYCODE_MEDIA_NEXT", "多媒体键 下一首"),
        ("KEYCODE_MEDIA_PREVIOUS", "多媒体键 上一首"),
        ("KEYCODE_MEDIA_CLOSE", "多媒体键 关闭"),
        ("KEYCODE_MEDIA_EJECT", "多媒体键 弹出"),
        ("KEYCODE_MEDIA_RECORD", "多媒体键 录音")
    ]
}

# 打印分组并提供选择功能
def print_grouped_keys_with_continuous_selection(groups):
    group_names = list(groups.keys())  # 获取所有分组名称
    option_to_keycode = {}  # 存储编号到KEYCODE的映射

    current_option_number = 1
    for group_name in group_names:
        group = groups[group_name]
        for keycode, description in group:
            option_to_keycode[current_option_number] = keycode
            current_option_number += 1

    total_groups = len(group_names)
    current_group_index = 0

    while True:
        # 获取当前分组名称和按键选项
        group_name = group_names[current_group_index]
        group = groups[group_name]

        # 打印当前分组的按键选项
        print(f"\n{group_name} (Group {current_group_index + 1}/{total_groups})")
        current_option_number = 1
        for i, (keycode, description) in enumerate(group):
            global_option_number = sum(len(groups[g]) for g in group_names[:current_group_index]) + i + 1
            print(f"[{global_option_number}] {description} ({keycode})")

        # 提示用户输入
        print("\nEnter the number to select a key, 'n' for next group, 'p' for previous group, 'q' to quit:")

        # 获取用户输入
        user_input = input("Your choice: ").strip()

        # 判断用户输入
        if user_input.isdigit():
            choice = int(user_input)
            if choice in option_to_keycode:
                return option_to_keycode[choice]  # 返回选择的 KEYCODE
            else:
                print("Invalid choice. Please select a valid number.")
        elif user_input.lower() == 'n':
            if current_group_index < total_groups - 1:
                current_group_index += 1  # 下一组
            else:
                print("You are on the last group.")
        elif user_input.lower() == 'p':
            if current_group_index > 0:
                current_group_index -= 1  # 上一组
            else:
                print("You are on the first group.")
        elif user_input.lower() == 'q':
            print("Exiting selection.")
            return None  # 用户选择退出
        else:
            print("Invalid input. Please try again.")

# 调用分页显示函数并选择按键
selected_keycode = print_grouped_keys_with_continuous_selection(keycode_groups)

if selected_keycode:
    print(f"Selected KEYCODE: {selected_keycode}")
else:
    print("No keycode selected.")

