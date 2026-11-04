"""Helpers shared by the cfg_tool format adapters."""
from __future__ import annotations

import json
import os
from typing import List

MISSING = object()


class PointerError(Exception):
    """Raised for an invalid JSON Pointer."""


def backup_enabled() -> bool:
    return any(os.environ.get(name, "").strip().lower() in ("1", "true", "yes")
               for name in ("CFG_BACKUP", "INI_BACKUP"))


def parse_pointer(pointer: str) -> List[str]:
    if pointer == "":
        return []
    if not pointer.startswith("/"):
        raise PointerError(f"invalid JSON Pointer (must start with /): {pointer}")
    return [token.replace("~1", "/").replace("~0", "~")
            for token in pointer[1:].split("/")]


def is_index(token: str) -> bool:
    return token == "-" or token.isdigit()


def format_scalar(value: object, as_json: bool = False) -> str:
    if as_json:
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if isinstance(value, str):
        return value
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return json.dumps(value)
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def detect_indent(text: str):
    for line in text.splitlines()[1:]:
        if line.startswith("\t"):
            return "\t"
        if line.startswith(" "):
            count = len(line) - len(line.lstrip(" "))
            return count if count in (2, 4, 8) else 2
        if line.strip():
            break
    return 2
