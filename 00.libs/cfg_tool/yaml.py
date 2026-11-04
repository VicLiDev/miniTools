"""YAML adapter for the unified config tool (ruamel.yaml round-trip)."""
from __future__ import annotations

import io
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
    format_scalar as _json_format,
    is_index as _json_is_index,
    parse_pointer,
)

try:
    from ruamel.yaml import YAML
    from ruamel.yaml.comments import CommentedMap, CommentedSeq
except ImportError as _ruamel_exc:  # pragma: no cover - depends on host packages
    YAML = None  # type: ignore[assignment]
    CommentedMap = None  # type: ignore[assignment]
    CommentedSeq = None  # type: ignore[assignment]
    _RUAMEL_IMPORT_ERROR = _ruamel_exc
else:
    _RUAMEL_IMPORT_ERROR = None


class YamlError(Exception):
    """YAML read/write/CLI error."""


def _yaml_require() -> None:
    if YAML is None:
        detail = f": {_RUAMEL_IMPORT_ERROR}" if _RUAMEL_IMPORT_ERROR else ""
        raise YamlError(
            "ruamel.yaml is required for YAML support; install it with "
            f"'python3 -m pip install ruamel.yaml'{detail}"
        )


def _yaml_rt() -> "YAML":
    _yaml_require()
    yaml = YAML(typ="rt")
    yaml.preserve_quotes = True
    yaml.width = 4096
    yaml.allow_unicode = True
    yaml.default_flow_style = False
    return yaml


def _yaml_safe_load(text: str):
    _yaml_require()
    return YAML(typ="safe").load(text)


def _yaml_parse_pointer(pointer: str) -> List[str]:
    try:
        return parse_pointer(pointer)
    except PointerError as exc:
        raise YamlError(str(exc)) from exc


def _yaml_new_container(next_token: str) -> object:
    _yaml_require()
    return CommentedSeq() if _json_is_index(next_token) else CommentedMap()


def _yaml_empty_mapping() -> object:
    _yaml_require()
    return CommentedMap()


def _yaml_parent(doc: object, tokens: List[str], create: bool):
    cur = doc
    for i, token in enumerate(tokens[:-1]):
        next_token = tokens[i + 1]
        if isinstance(cur, dict):
            if token not in cur:
                if not create:
                    raise KeyError(token)
                cur[token] = _yaml_new_container(next_token)
            cur = cur[token]
        elif isinstance(cur, list):
            if token == "-":
                raise YamlError("'-' is only valid as the final token")
            if not token.isdigit():
                raise YamlError(f"invalid list index: {token}")
            index = int(token)
            if index > len(cur):
                raise YamlError(f"list index out of range: {token}")
            if index == len(cur):
                if not create:
                    raise KeyError(token)
                cur.append(_yaml_new_container(next_token))
            cur = cur[index]
        else:
            raise YamlError(f"cannot traverse scalar at: {token}")
    return cur, tokens[-1]


def _yaml_dump_text(value: object) -> str:
    yaml = _yaml_rt()
    buf = io.StringIO()
    yaml.dump(value, buf)
    text = buf.getvalue()
    # ruamel adds a document-end marker for root scalars.
    if not isinstance(value, (dict, list)) and text.endswith("\n...\n"):
        text = text[:-5]
    return text


def _yaml_format(value: object, as_json: bool = False,
                 as_yaml: bool = False) -> str:
    if as_json:
        return _json_format(value, True)
    if as_yaml:
        return _yaml_dump_text(value).rstrip("\n")
    return _json_format(value, False)


class YamlFile:
    def __init__(self, path, data, text: str = "",
                 trailing_newline: bool = True):
        self.path = Path(path)
        self.data = data
        self.text = text
        self.trailing_newline = trailing_newline
        self.dirty = False

    @classmethod
    def load(cls, path, create: bool = False):
        _yaml_require()
        p = Path(path)
        if not p.exists():
            if not create:
                raise YamlError(f"file not found: {path}")
            return cls(p, CommentedMap(), "", trailing_newline=True)
        try:
            text = p.read_text(encoding="utf-8-sig")
        except OSError as exc:
            raise YamlError(str(exc)) from exc
        if not text.strip():
            data = CommentedMap()
        else:
            try:
                data = _yaml_rt().load(text)
            except Exception as exc:
                raise YamlError(f"{path}: {exc}") from exc
            if data is None:
                data = CommentedMap()
        return cls(p, data, text, trailing_newline=text.endswith("\n"))

    def get(self, pointer: str, default=_MISSING):
        tokens = _yaml_parse_pointer(pointer)
        if not tokens:
            return self.data
        try:
            parent, key = _yaml_parent(self.data, tokens, create=False)
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
        tokens = _yaml_parse_pointer(pointer)
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
        parent, key = _yaml_parent(self.data, tokens, create=True)
        if isinstance(parent, dict):
            parent[key] = value
        elif isinstance(parent, list):
            if key == "-":
                parent.append(value)
            elif key.isdigit():
                index = int(key)
                if index > len(parent):
                    raise YamlError(f"list index out of range: {key}")
                if index == len(parent):
                    parent.append(value)
                else:
                    parent[index] = value
            else:
                raise YamlError(f"invalid list index: {key}")
        else:
            raise YamlError(f"cannot set value at: {pointer}")
        self.dirty = True
        return True

    def delete(self, pointer: str) -> bool:
        tokens = _yaml_parse_pointer(pointer)
        if not tokens:
            self.data = _yaml_empty_mapping()
            self.dirty = True
            return True
        try:
            parent, key = _yaml_parent(self.data, tokens, create=False)
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
        text = _yaml_dump_text(self.data)
        if self.trailing_newline:
            if not text.endswith("\n"):
                text += "\n"
        else:
            text = text.rstrip("\n")
        return text

    def save(self, backup: bool = False) -> bool:
        if not self.dirty:
            return False
        target = self.path.resolve() if self.path.exists() else self.path
        parent = target.parent
        if not parent.exists():
            raise YamlError(f"parent directory not found: {parent}")
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
        errors: List[str] = []
        warnings: List[str] = []
        return errors, warnings


YAML_USAGE = """usage: 05.cfg.py yaml <command> [args]

commands:
  get            <file> <pointer> [--json|--yaml]
  get-default    <file> <pointer> <default> [--json|--yaml]
  get-all        <file> <pointer> [--json|--yaml]
  has            <file> <pointer>
  set            <file> <pointer> <value> [--json|--yaml]
  set-if-missing <file> <pointer> <value> [--json|--yaml]
  del            <file> <pointer>
  keys           <file> [pointer]
  validate       <file>

env:
  CFG_BACKUP=1 or INI_BACKUP=1   create <file>.bak before writing
"""


def _yaml_err(message: str) -> None:
    print(f"yaml: {message}", file=sys.stderr)


def _yaml_load(path: str, create: bool = False) -> YamlFile:
    return YamlFile.load(path, create=create)


def _yaml_check_args(args: Sequence[str], count: int, usage: str) -> None:
    if len(args) != count:
        raise YamlError(f"usage: 05.cfg.py yaml {usage}")


def _yaml_pop_flags(args: Sequence[str]):
    rest = list(args)
    if rest and rest[-1] in ("--json", "--yaml"):
        flag = rest.pop()
        return rest, flag == "--json", flag == "--yaml"
    return rest, False, False


def _yaml_cmd_get(args: Sequence[str]) -> int:
    args, as_json, as_yaml = _yaml_pop_flags(args)
    _yaml_check_args(args, 2, "get <file> <pointer> [--json|--yaml]")
    doc = _yaml_load(args[0])
    try:
        value = doc.get(args[1])
    except KeyError:
        return 1
    print(_yaml_format(value, as_json, as_yaml))
    return 0


def _yaml_cmd_get_default(args: Sequence[str]) -> int:
    args, as_json, as_yaml = _yaml_pop_flags(args)
    _yaml_check_args(
        args, 3, "get-default <file> <pointer> <default> [--json|--yaml]"
    )
    doc = _yaml_load(args[0])
    try:
        value = doc.get(args[1])
    except KeyError:
        print(args[2])
        return 0
    print(_yaml_format(value, as_json, as_yaml))
    return 0


def _yaml_cmd_get_all(args: Sequence[str]) -> int:
    args, as_json, as_yaml = _yaml_pop_flags(args)
    _yaml_check_args(args, 2, "get-all <file> <pointer> [--json|--yaml]")
    doc = _yaml_load(args[0])
    try:
        values = doc.get_all(args[1])
    except KeyError:
        return 1
    for value in values:
        print(_yaml_format(value, as_json, as_yaml))
    return 0


def _yaml_cmd_has(args: Sequence[str]) -> int:
    _yaml_check_args(args, 2, "has <file> <pointer>")
    doc = _yaml_load(args[0])
    return 0 if doc.has(args[1]) else 1


def _yaml_cmd_set(args: Sequence[str], if_missing: bool = False) -> int:
    args, as_json, as_yaml = _yaml_pop_flags(args)
    usage = "set-if-missing" if if_missing else "set"
    _yaml_check_args(
        args, 3, f"{usage} <file> <pointer> <value> [--json|--yaml]"
    )
    value: object = args[2]
    if as_json:
        try:
            value = json.loads(args[2])
        except json.JSONDecodeError as exc:
            raise YamlError(f"invalid JSON value: {exc}") from exc
    elif as_yaml:
        try:
            value = _yaml_safe_load(args[2])
        except Exception as exc:
            raise YamlError(f"invalid YAML value: {exc}") from exc
    doc = _yaml_load(args[0], create=True)
    doc.set(args[1], value, if_missing=if_missing)
    doc.save(backup=_backup_enabled())
    return 0


def _yaml_cmd_del(args: Sequence[str]) -> int:
    _yaml_check_args(args, 2, "del <file> <pointer>")
    doc = _yaml_load(args[0])
    if not doc.delete(args[1]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _yaml_cmd_keys(args: Sequence[str]) -> int:
    if len(args) not in (1, 2):
        raise YamlError("usage: 05.cfg.py yaml keys <file> [pointer]")
    doc = _yaml_load(args[0])
    pointer = args[1] if len(args) == 2 else ""
    try:
        keys = doc.keys(pointer)
    except KeyError:
        return 1
    for key in keys:
        print(key)
    return 0


def _yaml_cmd_validate(args: Sequence[str]) -> int:
    _yaml_check_args(args, 1, "validate <file>")
    doc = _yaml_load(args[0])
    errors, warnings = doc.validate()
    for warning in warnings:
        _yaml_err(f"warning: {warning}")
    for error in errors:
        _yaml_err(f"error: {error}")
    return 1 if errors else 0


def _yaml_main(argv: Sequence[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(YAML_USAGE, end="")
        return 0

    command = argv[0]
    args = argv[1:]

    try:
        if command == "get":
            return _yaml_cmd_get(args)
        if command == "get-default":
            return _yaml_cmd_get_default(args)
        if command == "get-all":
            return _yaml_cmd_get_all(args)
        if command == "has":
            return _yaml_cmd_has(args)
        if command == "set":
            return _yaml_cmd_set(args)
        if command == "set-if-missing":
            return _yaml_cmd_set(args, if_missing=True)
        if command == "del":
            return _yaml_cmd_del(args)
        if command == "keys":
            return _yaml_cmd_keys(args)
        if command == "validate":
            return _yaml_cmd_validate(args)
    except (YamlError, OSError) as exc:
        _yaml_err(str(exc))
        return 2

    _yaml_err(f"unknown command: {command}")
    print(YAML_USAGE, end="", file=sys.stderr)
    return 2
