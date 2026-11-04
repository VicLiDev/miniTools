"""JSON adapter for the unified config tool."""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import List, Sequence

from .common import (
    MISSING as _MISSING,
    PointerError,
    backup_enabled as _backup_enabled,
    detect_indent as _json_detect_indent,
    format_scalar as _json_format,
    is_index as _json_is_index,
    parse_pointer,
)


class JsonError(Exception):
    """JSON read/write/CLI error."""


def _json_parse_pointer(pointer: str) -> List[str]:
    try:
        return parse_pointer(pointer)
    except PointerError as exc:
        raise JsonError(str(exc)) from exc


def _json_new_container(next_token: str) -> object:
    return [] if _json_is_index(next_token) else {}


def _json_parent(doc: object, tokens: List[str], create: bool):
    cur = doc
    for i, token in enumerate(tokens[:-1]):
        next_token = tokens[i + 1]
        if isinstance(cur, dict):
            if token not in cur:
                if not create:
                    raise KeyError(token)
                cur[token] = _json_new_container(next_token)
            cur = cur[token]
        elif isinstance(cur, list):
            if token == "-":
                raise JsonError("'-' is only valid as the final token")
            if not token.isdigit():
                raise JsonError(f"invalid list index: {token}")
            index = int(token)
            if index > len(cur):
                raise JsonError(f"list index out of range: {token}")
            if index == len(cur):
                if not create:
                    raise KeyError(token)
                cur.append(_json_new_container(next_token))
            cur = cur[index]
        else:
            raise JsonError(f"cannot traverse scalar at: {token}")
    return cur, tokens[-1]


class JsonFile:
    def __init__(self, path, data, text: str, indent=2,
                 trailing_newline: bool = True, duplicates=None):
        self.path = Path(path)
        self.data = data
        self.text = text
        self.indent = indent
        self.trailing_newline = trailing_newline
        self.duplicates = duplicates or []
        self.dirty = False

    @classmethod
    def load(cls, path, create: bool = False):
        p = Path(path)
        if not p.exists():
            if not create:
                raise JsonError(f"file not found: {path}")
            return cls(p, {}, "", indent=2, trailing_newline=True)
        try:
            text = p.read_text(encoding="utf-8-sig")
        except OSError as exc:
            raise JsonError(str(exc)) from exc
        duplicates = []

        def hook(pairs):
            seen = set()
            for key, value in pairs:
                if key in seen:
                    duplicates.append(key)
                seen.add(key)
            return dict(pairs)

        if not text.strip():
            data = {}
        else:
            try:
                data = json.loads(text, object_pairs_hook=hook)
            except json.JSONDecodeError as exc:
                raise JsonError(f"{path}: {exc}") from exc
        return cls(p, data, text, indent=_json_detect_indent(text),
                   trailing_newline=text.endswith("\n"),
                   duplicates=duplicates)

    def get(self, pointer: str, default=_MISSING):
        tokens = _json_parse_pointer(pointer)
        if not tokens:
            return self.data
        try:
            parent, key = _json_parent(self.data, tokens, create=False)
            if isinstance(parent, dict):
                value = parent[key]
            else:
                if key == "-" or not key.isdigit():
                    raise KeyError(key)
                value = parent[int(key)]
        except (KeyError, IndexError):
            if default is not _MISSING:
                return default
            raise KeyError(pointer) from None
        return value

    def get_all(self, pointer: str):
        return [self.get(pointer)]

    def has(self, pointer: str) -> bool:
        try:
            self.get(pointer)
        except KeyError:
            return False
        return True

    def set(self, pointer: str, value: object, if_missing: bool = False) -> bool:
        tokens = _json_parse_pointer(pointer)
        if not tokens:
            if if_missing:
                return False
            self.data = value
            self.dirty = True
            return True
        if if_missing:
            try:
                self.get(pointer)
                return False
            except KeyError:
                pass
        parent, key = _json_parent(self.data, tokens, create=True)
        if isinstance(parent, dict):
            parent[key] = value
        elif isinstance(parent, list):
            if key == "-":
                parent.append(value)
            elif key.isdigit():
                index = int(key)
                if index > len(parent):
                    raise JsonError(f"list index out of range: {key}")
                if index == len(parent):
                    parent.append(value)
                else:
                    parent[index] = value
            else:
                raise JsonError(f"invalid list index: {key}")
        else:
            raise JsonError(f"cannot set value at: {pointer}")
        self.dirty = True
        return True

    def delete(self, pointer: str) -> bool:
        tokens = _json_parse_pointer(pointer)
        if not tokens:
            self.data = {}
            self.dirty = True
            return True
        try:
            parent, key = _json_parent(self.data, tokens, create=False)
        except (KeyError, IndexError):
            return False
        if isinstance(parent, dict):
            if key not in parent:
                return False
            del parent[key]
        elif isinstance(parent, list):
            if key == "-" or not key.isdigit():
                return False
            index = int(key)
            if index >= len(parent):
                return False
            parent.pop(index)
        else:
            return False
        self.dirty = True
        return True

    def keys(self, pointer: str = ""):
        value = self.get(pointer)
        if isinstance(value, dict):
            return list(value.keys())
        if isinstance(value, list):
            return [str(i) for i in range(len(value))]
        return []

    def dump(self) -> str:
        text = json.dumps(self.data, indent=self.indent, ensure_ascii=False,
                          sort_keys=False)
        if self.trailing_newline:
            text += "\n"
        return text

    def save(self, backup: bool = False) -> bool:
        if not self.dirty:
            return False
        target = self.path.resolve() if self.path.exists() else self.path
        parent = target.parent
        if not parent.exists():
            raise JsonError(f"parent directory not found: {parent}")
        text = self.dump()
        fd, tmp_name = tempfile.mkstemp(prefix=target.name + ".",
                                        suffix=".tmp", dir=str(parent))
        os.close(fd)
        tmp = Path(tmp_name)
        try:
            tmp.write_text(text, encoding="utf-8")
            if target.exists():
                if backup:
                    shutil.copy2(target, Path(str(target) + ".bak"))
                shutil.copystat(target, tmp)
            else:
                os.chmod(tmp, 0o644)
            os.replace(tmp, target)
        except Exception:
            try:
                tmp.unlink()
            except OSError:
                pass
            raise
        self.path = target
        self.dirty = False
        return True

    def validate(self):
        errors = []
        warnings = [f"duplicate key: {key}" for key in self.duplicates]
        return errors, warnings


JSON_USAGE = """usage: 05.cfg.py json <command> [args]

commands:
  get            <file> <pointer> [--json]
  get-default    <file> <pointer> <default> [--json]
  get-all        <file> <pointer> [--json]
  has            <file> <pointer>
  set            <file> <pointer> <value> [--json]
  set-if-missing <file> <pointer> <value> [--json]
  del            <file> <pointer>
  keys           <file> [pointer]
  validate       <file>

env:
  CFG_BACKUP=1 or INI_BACKUP=1   create <file>.bak before writing
"""


def _json_err(message: str) -> None:
    print(f"json: {message}", file=sys.stderr)


def _json_load(path: str, create: bool = False) -> JsonFile:
    return JsonFile.load(path, create=create)


def _json_check_args(args: Sequence[str], count: int, usage: str) -> None:
    if len(args) != count:
        raise JsonError(f"usage: 05.cfg.py json {usage}")


def _json_pop_flag(args: Sequence[str], flag: str):
    rest = list(args)
    if rest and rest[-1] == flag:
        return rest[:-1], True
    return rest, False


def _json_cmd_get(args: Sequence[str]) -> int:
    args, as_json = _json_pop_flag(args, "--json")
    _json_check_args(args, 2, "get <file> <pointer> [--json]")
    doc = _json_load(args[0])
    try:
        value = doc.get(args[1])
    except KeyError:
        return 1
    print(_json_format(value, as_json))
    return 0


def _json_cmd_get_default(args: Sequence[str]) -> int:
    args, as_json = _json_pop_flag(args, "--json")
    _json_check_args(args, 3, "get-default <file> <pointer> <default> [--json]")
    doc = _json_load(args[0])
    try:
        value = doc.get(args[1])
    except KeyError:
        print(args[2])
        return 0
    print(_json_format(value, as_json))
    return 0


def _json_cmd_get_all(args: Sequence[str]) -> int:
    args, as_json = _json_pop_flag(args, "--json")
    _json_check_args(args, 2, "get-all <file> <pointer> [--json]")
    doc = _json_load(args[0])
    try:
        values = doc.get_all(args[1])
    except KeyError:
        return 1
    for value in values:
        print(_json_format(value, as_json))
    return 0


def _json_cmd_has(args: Sequence[str]) -> int:
    _json_check_args(args, 2, "has <file> <pointer>")
    doc = _json_load(args[0])
    return 0 if doc.has(args[1]) else 1


def _json_cmd_set(args: Sequence[str], if_missing: bool = False) -> int:
    args, as_json = _json_pop_flag(args, "--json")
    usage = "set-if-missing" if if_missing else "set"
    _json_check_args(args, 3, f"{usage} <file> <pointer> <value> [--json]")
    value: object = args[2]
    if as_json:
        try:
            value = json.loads(args[2])
        except json.JSONDecodeError as exc:
            raise JsonError(f"invalid JSON value: {exc}") from exc
    doc = _json_load(args[0], create=True)
    doc.set(args[1], value, if_missing=if_missing)
    doc.save(backup=_backup_enabled())
    return 0


def _json_cmd_del(args: Sequence[str]) -> int:
    _json_check_args(args, 2, "del <file> <pointer>")
    doc = _json_load(args[0])
    if not doc.delete(args[1]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _json_cmd_keys(args: Sequence[str]) -> int:
    if len(args) not in (1, 2):
        raise JsonError("usage: 05.cfg.py json keys <file> [pointer]")
    doc = _json_load(args[0])
    pointer = args[1] if len(args) == 2 else ""
    try:
        keys = doc.keys(pointer)
    except KeyError:
        return 1
    for key in keys:
        print(key)
    return 0


def _json_cmd_validate(args: Sequence[str]) -> int:
    _json_check_args(args, 1, "validate <file>")
    doc = _json_load(args[0])
    errors, warnings = doc.validate()
    for warning in warnings:
        _json_err(f"warning: {warning}")
    for error in errors:
        _json_err(f"error: {error}")
    return 1 if errors else 0


def _json_main(argv: Sequence[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(JSON_USAGE, end="")
        return 0

    command = argv[0]
    args = argv[1:]

    try:
        if command == "get":
            return _json_cmd_get(args)
        if command == "get-default":
            return _json_cmd_get_default(args)
        if command == "get-all":
            return _json_cmd_get_all(args)
        if command == "has":
            return _json_cmd_has(args)
        if command == "set":
            return _json_cmd_set(args)
        if command == "set-if-missing":
            return _json_cmd_set(args, if_missing=True)
        if command == "del":
            return _json_cmd_del(args)
        if command == "keys":
            return _json_cmd_keys(args)
        if command == "validate":
            return _json_cmd_validate(args)
    except (JsonError, OSError) as exc:
        _json_err(str(exc))
        return 2

    _json_err(f"unknown command: {command}")
    print(JSON_USAGE, end="", file=sys.stderr)
    return 2
