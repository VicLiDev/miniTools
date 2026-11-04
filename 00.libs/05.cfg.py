#!/usr/bin/env python3
#########################################################################
# File Name: 05.cfg.py
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Wed 04 Nov 2026 10:00:00 AM CST
#########################################################################

# usage:
#   05.cfg.py <format> <command> [args]
#
# formats:
#   ini        flat [section] / key = value file
#   json       JSON object/array, JSON Pointer paths
#   yaml       YAML mapping/sequence, JSON Pointer paths
#   xml        XML document, XPath paths (lxml)
#
# ini commands:
#   get        <file> <section> <key>
#   get-default<file> <section> <key> <default>
#   get-all    <file> <section> <key>
#   has        <file> <section> <key>
#   set        <file> <section> <key> <value>
#   set-if-missing <file> <section> <key> <value>
#   del        <file> <section> <key>
#   del-section<file> <section>
#   sections   <file>
#   keys       <file> <section>
#   entries    <file> [section]
#   numbered   <file> <section>
#   validate   <file>
#
# json commands (JSON Pointer /a/b/0):
#   get            <file> <pointer> [--json]
#   get-default    <file> <pointer> <default> [--json]
#   get-all        <file> <pointer> [--json]
#   has            <file> <pointer>
#   set            <file> <pointer> <value> [--json]
#   set-if-missing <file> <pointer> <value> [--json]
#   del            <file> <pointer>
#   keys           <file> [pointer]
#   validate       <file>
#
# yaml commands (JSON Pointer /a/b/0):
#   get            <file> <pointer> [--json|--yaml]
#   get-default    <file> <pointer> <default> [--json|--yaml]
#   get-all        <file> <pointer> [--json|--yaml]
#   has            <file> <pointer>
#   set            <file> <pointer> <value> [--json|--yaml]
#   set-if-missing <file> <pointer> <value> [--json|--yaml]
#   del            <file> <pointer>
#   keys           <file> [pointer]
#   validate       <file>
#
# xml commands (XPath /a/b, --ns prefix=uri):
#   get            <file> <xpath> [--xml] [--all] [--ns p=u]
#   get-default    <file> <xpath> <default> [--xml] [--ns p=u]
#   get-all        <file> <xpath> [--xml] [--ns p=u]
#   has            <file> <xpath> [--ns p=u]
#   set            <file> <xpath> <value> [--xml] [--all] [--ns p=u]
#   set-attr       <file> <xpath> <name> <value> [--all] [--ns p=u]
#   add            <file> <parent-xpath> <tag> [--text T] [--attr k=v]...
#                  [--index N] [--ns p=u]
#   del            <file> <xpath> [--all] [--ns p=u]
#   replace        <file> <xpath> <xml-fragment> [--all] [--ns p=u]
#   validate       <file>
#
# 说明:
#   - 按行解析, 保留注释/空行/顺序; 写入使用临时文件 + os.replace 原子替换.
#   - 支持的格式: [section], key = value, 整行 # 或 ; 注释.
#   - 值必须单行; 值中的 # ; = | 空格原样保留, 不解析内联注释.
#   - 重复 key: 读取取最后一个; 写入更新最后一个; validate 报 warning.
#   - 退出码: 0 成功/找到; 1 未找到; 2 用法/IO/解析错误.
#   - 写文件时设置 INI_BACKUP=1 可生成 <file>.bak 备份.
#   - 与 05.cfg.sh 配合使用: source 05.cfg.sh 后调用 ini_get/ini_set 等.
#   - XML 使用 lxml 与 XPath 路径; --ns prefix=uri 指定命名空间;
#     写回保留注释/空白/CDATA/XML 声明/doctype.
#
# 实现拆分在 cfg_tool/ 包中, 本文件仅保留入口与命令说明:
#   cfg_tool/common.py  共享工具 (JSON Pointer / 备份开关)
#   cfg_tool/ini.py     INI 适配器
#   cfg_tool/json.py    JSON 适配器
#   cfg_tool/yaml.py    YAML 适配器
#   cfg_tool/xml.py     XML 适配器
#   cfg_tool/cli.py     格式分发与总帮助

from __future__ import annotations

import os
import sys

# 解析真实路径, 这样通过 ~/bin/_cfg.py 软链接调用时也能找到 cfg_tool 包.
_here = os.path.dirname(os.path.realpath(__file__))
if _here not in sys.path:
    sys.path.insert(0, _here)

from cfg_tool.cli import main


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
