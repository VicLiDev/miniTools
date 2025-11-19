#!/usr/bin/env bash
#########################################################################
# File Name: 20.sort_photos.sh
# Author: LiHongjin
# mail: 872648180@qq.com
# Created Time: Wed 19 Nov 2025 11:04:37 AM CST
#########################################################################

# 要整理的照片目录（可修改）
SRC_DIR="$1"

if [ -z "$SRC_DIR" ]; then
    echo "❗ 请提供要整理的目录，例如："
    echo "    ./sort_photos.sh /home/user/photos"
    exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
    echo "❗ 目录不存在：$SRC_DIR"
    exit 1
fi

# 需要 exiftool 来读取照片拍摄日期
if ! command -v exiftool >/dev/null 2>&1; then
    echo "❗ 未检测到 exiftool，请安装："
    echo "    sudo apt install libimage-exiftool-perl"
    exit 1
fi

echo "📁 开始整理目录：$SRC_DIR"
cd "$SRC_DIR"

# 支持的文件扩展名
# shopt -s nullglob 让 Bash 通配符在找不到匹配文件时返回空，而不是返回原内容。
# 如果某种格式不存在（例如没有 .mp4），而 未开启 nullglob，则：
# *.mp4 会变成一个字符串 "*.mp4"
# 脚本会错误地尝试处理这个不存在的文件
shopt -s nullglob
for file in *.{jpg,JPG,jpeg,JPEG,png,PNG,heic,HEIC,mp4,MP4,mov,MOV}; do
    # 获取 EXIF 拍摄日期
    DATE=$(exiftool -d "%Y-%m" -DateTimeOriginal "$file" | awk -F": " '{print $2}')

    # 如果没有 EXIF，则使用文件修改时间
    if [ -z "$DATE" ]; then
        DATE=$(date -r "$file" +"%Y-%m")
    fi

    # 创建年份-月份文件夹
    mkdir -p "$DATE"

    echo "➡️  $file → $DATE/"
    mv "$file" "$DATE"/
done

echo "✨ 所有照片已按年月整理完成！"

