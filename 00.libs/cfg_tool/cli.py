"""Command-line dispatch for the unified config tool."""
from __future__ import annotations

import sys
from typing import Sequence


CFG_USAGE = """usage: 05.cfg.py <format> <command> [args]

formats:
  ini        flat [section] / key = value file
  json       JSON object/array, JSON Pointer paths
  yaml       YAML mapping/sequence, JSON Pointer paths (ruamel.yaml)
  xml        XML document, XPath paths (lxml)

run '05.cfg.py <format> --help' for format-specific commands.
"""


def main(argv: Sequence[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(CFG_USAGE, end="")
        return 0

    fmt = argv[0]
    rest = argv[1:]

    if fmt == "ini":
        from .ini import _ini_main
        return _ini_main(rest)
    if fmt == "json":
        from .json import _json_main
        return _json_main(rest)
    if fmt == "yaml":
        from .yaml import _yaml_main
        return _yaml_main(rest)
    if fmt == "xml":
        from .xml import _xml_main
        return _xml_main(rest)

    print(f"cfg: unsupported format: {fmt}", file=sys.stderr)
    print(CFG_USAGE, end="", file=sys.stderr)
    return 2
