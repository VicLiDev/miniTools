#!/usr/bin/env python3
#########################################################################
# File Name: 24.xml_fmt.py
# Author: Hongjin Li
# mail: 872648180@qq.com
# Created Time: Sat 23 May 2026 01:41:52 PM CST
# Description: Format XML files with proper indentation and inline leaf text.
#########################################################################

"""xml_fmt - 格式化 XML 文件，叶子节点文本内联，自动缩进。

工作原理:
  1. 用 lxml 解析 XML，不做 remove_blank_text，保留原始文本中的换行结构。
  2. _clean_tree() 递归清理树：
     - 去除纯格式空白节点（无文本的空白 text/tail）
     - 叶子节点的文本 strip 后，若原始包含换行则加 \n 前缀标记
  3. fmt_element() 递归输出每个元素：
     - 叶子节点，文本原始无换行且整行不超过 width → 单行内联
       例: <jointPort>joint3_870</jointPort>
     - 叶子节点，文本原始有换行或超过 width → 多行展开
       例:
           <angleThresh>
               14.4e-01 8.4e-01 8.4e-01
           </angleThresh>
     - 有子节点 → 标签各占一行，子元素缩进一级
  4. 缩进通过 indent 参数控制（默认 4 空格），宽度通过 width 控制（默认 120）。

依赖: pip install lxml
"""

import argparse
import copy
import sys

from lxml import etree


def _clean_tree(root):
    """递归清理树：去除纯格式空白节点和前后空白，保留文本内的结构换行。"""
    for el in root:
        _clean_tree(el)
    # el.text 是标签后的内容，el.tail 是标签后的尾随内容
    # 清理尾随空白（尾随文本只是排版用的）
    if root.tail and not root.tail.strip():
        root.tail = None
    # 叶子节点：strip text 保留结构
    if not list(root) and root.text:
        stripped = root.text.strip()
        # 如果原始文本包含换行，保留为一个空格分隔的紧凑形式
        # 但标记为"需要换行"（用特殊内部标记）
        if "\n" in root.text:
            root.text = "\n" + stripped  # \n 前缀表示原始有换行
        else:
            root.text = stripped
    # 非叶子节点：如果 text 是纯空白就清掉
    elif root.text and not root.text.strip():
        root.text = None
    else:
        # 有混合内容，strip
        if root.text:
            root.text = root.text.strip() or None


def _join_fit(tokens, max_width):
    """贪心填充：尽可能多地将 token 放到一行，返回行列表。"""
    if not tokens:
        return []
    lines, cur = [], [tokens[0]]
    cur_len = len(tokens[0])
    for tok in tokens[1:]:
        added = cur_len + 1 + len(tok)
        if added <= max_width:
            cur.append(tok)
            cur_len = added
        else:
            lines.append(" ".join(cur))
            cur = [tok]
            cur_len = len(tok)
    lines.append(" ".join(cur))
    return lines


def fmt_element(el, indent, level, width):
    """递归格式化 XML 元素，返回缩进字符串。"""
    prefix = " " * (indent * level)
    child_prefix = " " * (indent * (level + 1))
    attrs = "".join(f' {k}="{v}"' for k, v in el.attrib.items())

    # 叶子节点（无子元素）且有文本
    if not list(el) and (el.text or "").strip():
        text = el.text.lstrip("\n").strip()
        original_multiline = el.text.startswith("\n") if el.text else False
        # 短文本且原始是单行 -> 单行内联
        single = f"{prefix}<{el.tag}{attrs}>{text}</{el.tag}>"
        if len(single) <= width and not original_multiline:
            return single
        # 多行或超长：开标签一行，文本缩进一级，闭合标签一行
        text_width = max(width - len(child_prefix), 20)
        text_lines = _join_fit(text.split(), text_width)
        lines = [f"{prefix}<{el.tag}{attrs}>"]
        lines.extend(child_prefix + tl for tl in text_lines)
        lines.append(f"{prefix}</{el.tag}>")
        return "\n".join(lines)

    # 有子节点
    lines = [f"{prefix}<{el.tag}{attrs}>"]
    for child in el:
        lines.append(fmt_element(child, indent, level + 1, width))
    lines.append(f"{prefix}</{el.tag}>")
    return "\n".join(lines)


def format_xml(tree, indent=4, width=120, xml_declaration=True, encoding="UTF-8"):
    """格式化 XML 树，返回字符串。"""
    root = tree.getroot() if hasattr(tree, "getroot") else tree
    # 深拷贝避免修改原树
    root = copy.deepcopy(root)
    _clean_tree(root)
    body = fmt_element(root, indent, 0, width)
    header = f'<?xml version="1.0" encoding="{encoding}"?>' if xml_declaration else ""
    parts = [p for p in (header, body) if p]
    return "\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser(
        prog="xml_fmt",
        description="格式化 XML 文件：叶子节点文本内联，自动缩进。",
        epilog="示例:\n"
               "  xml_fmt param.xml              # 查看格式化结果\n"
               "  xml_fmt -i param.xml           # 原位格式化\n"
               "  xml_fmt -i --indent 4 f.xml    # 4 空格缩进，原位保存\n"
               "  cat raw.xml | xml_fmt -         # stdin 输入\n"
               "  xml_fmt a.xml b.xml c.xml       # 批量格式化\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="要格式化的 XML 文件路径。支持多个文件批量处理。"
             "使用 - 表示从 stdin 读取。",
    )
    parser.add_argument(
        "-i", "--inplace",
        action="store_true",
        help="原位编辑，直接覆盖原文件",
    )
    parser.add_argument(
        "--indent",
        type=int,
        default=4,
        choices=range(1, 9),
        metavar="N",
        help="缩进空格数 (1-8，默认: 4)",
    )
    parser.add_argument(
        "--no-decl",
        action="store_true",
        help="省略 XML 声明头",
    )
    parser.add_argument(
        "-w", "--width",
        type=int,
        default=120,
        metavar="N",
        help="最大行宽，超过则长文本换行 (默认: 120)",
    )
    parser.add_argument(
        "--encoding",
        default="UTF-8",
        help="XML 文件编码 (默认: UTF-8)",
    )
    parser.add_argument(
        "-o", "--output",
        metavar="FILE",
        help="输出到指定文件（非原位模式下默认输出到 stdout）",
    )
    parser.add_argument(
        "-V", "--version",
        action="version",
        version="%(prog)s 1.0.0",
    )

    args = parser.parse_args()

    if not args.files:
        parser.print_help(sys.stderr)
        sys.exit(1)

    try:
        fpath = None
        if "-" in args.files:
            if len(args.files) > 1:
                print("错误: 使用 stdin(-) 时不能同时指定其他文件", file=sys.stderr)
                sys.exit(1)
            content = sys.stdin.buffer.read()
            el = etree.fromstring(content, parser=etree.XMLParser())
            result = format_xml(el, indent=args.indent, width=args.width,
                                xml_declaration=not args.no_decl, encoding=args.encoding)
        else:
            fpath = args.files[0]
            try:
                tree = etree.parse(fpath, parser=etree.XMLParser())
            except FileNotFoundError:
                print(f"错误: 文件不存在: {fpath!r}", file=sys.stderr)
                sys.exit(1)
            except etree.XMLSyntaxError as e:
                print(f"错误: XML 解析失败 ({fpath!r}): {e}", file=sys.stderr)
                sys.exit(1)
            result = format_xml(tree, indent=args.indent, width=args.width,
                                xml_declaration=not args.no_decl, encoding=args.encoding)

        if args.output:
            with open(args.output, "w", encoding=args.encoding) as f:
                f.write(result)
        elif args.inplace and fpath:
            with open(fpath, "w", encoding=args.encoding) as f:
                f.write(result)
        else:
            sys.stdout.write(result)
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
