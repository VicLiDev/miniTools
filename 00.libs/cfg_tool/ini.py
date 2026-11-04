"""INI adapter for the unified config tool."""
from __future__ import annotations

import os
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

from .common import backup_enabled as _backup_enabled


SECTION_RE = re.compile(r"^\s*\[([^\]]*)\]\s*(?:[#;].*)?$")
KEY_RE = re.compile(r"^\s*([^=]+?)\s*=\s*(.*?)\s*$")
COMMENT_RE = re.compile(r"^\s*[#;]")
NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


class IniError(Exception):
    """Raised for usage, IO, or format errors."""


@dataclass
class Entry:
    section: str
    key: str
    value: str
    line: int


class IniFile:
    """Line-oriented INI reader/writer.

    The class keeps every original line (including comments and blank
    lines) and only rewrites the line being changed.  This preserves the
    file layout much better than configparser.
    """

    def __init__(self, path: Path) -> None:
        self.path = Path(path)
        self.lines: List[str] = []
        self.eol = "\n"
        self.bom = False
        self.final_newline = True
        self.exists = False
        self.dirty = False

    @classmethod
    def load(cls, path: str | Path, create: bool = False) -> "IniFile":
        doc = cls(Path(path))
        if doc.path.exists():
            doc._read()
        elif not create:
            raise IniError(f"file not found: {doc.path}")
        return doc

    # ---- read ---------------------------------------------------------
    def _read(self) -> None:
        raw = self.path.read_bytes()
        self.bom = raw.startswith(b"\xef\xbb\xbf")
        text = raw.decode("utf-8", errors="surrogateescape")
        if self.bom and text.startswith("\ufeff"):
            text = text[1:]

        self.eol = "\r\n" if "\r\n" in text else "\n"
        self.final_newline = text.endswith(("\n", "\r"))
        self.lines = text.splitlines()
        self.exists = True

    def _text(self) -> str:
        body = self.eol.join(self.lines)
        if self.lines and self.final_newline:
            body += self.eol
        if self.bom:
            body = "\ufeff" + body
        return body

    def entries(self, section: Optional[str] = None) -> List[Entry]:
        """Return key entries in file order.  section=None means all."""
        out: List[Entry] = []
        cur = ""
        for idx, line in enumerate(self.lines):
            if not line.strip() or COMMENT_RE.match(line):
                continue

            m = SECTION_RE.match(line)
            if m:
                cur = m.group(1).strip()
                continue

            # An invalid section header must not be mistaken for a key.
            if line.lstrip().startswith("["):
                continue

            m = KEY_RE.match(line)
            if not m:
                continue
            key = m.group(1).strip()
            if not key:
                continue
            if section is None or cur == section:
                out.append(Entry(cur, key, m.group(2).strip(), idx))
        return out

    def sections(self) -> List[str]:
        out: List[str] = []
        for line in self.lines:
            m = SECTION_RE.match(line)
            if not m:
                continue
            name = m.group(1).strip()
            if name not in out:
                out.append(name)
        return out

    def get(
        self, section: str, key: str, default: Optional[str] = None
    ) -> Optional[str]:
        values = [e.value for e in self.entries(section) if e.key == key]
        return values[-1] if values else default

    def get_all(self, section: str, key: str) -> List[str]:
        return [e.value for e in self.entries(section) if e.key == key]

    def has(self, section: str, key: str) -> bool:
        return any(e.key == key for e in self.entries(section))

    def keys(self, section: str) -> List[str]:
        out: List[str] = []
        for entry in self.entries(section):
            if entry.key not in out:
                out.append(entry.key)
        return out

    def numbered(self, section: str) -> List[Entry]:
        """Entries whose key is numeric, sorted by numeric value."""
        items = [e for e in self.entries(section) if e.key.isdigit()]
        items.sort(key=lambda e: (int(e.key), e.line))
        return items

    # ---- write --------------------------------------------------------
    def _validate_section(self, section: str) -> str:
        section = section.strip()
        if not section:
            raise IniError("section must not be empty")
        if not NAME_RE.match(section):
            raise IniError(
                f"invalid section {section!r}; allowed: A-Z a-z 0-9 _ . -"
            )
        return section

    def _validate_key(self, key: str) -> str:
        key = key.strip()
        if not key:
            raise IniError("key must not be empty")
        if not NAME_RE.match(key):
            raise IniError(f"invalid key {key!r}; allowed: A-Z a-z 0-9 _ . -")
        return key

    def _validate_value(self, value: str) -> str:
        value = value.strip()
        if "\n" in value or "\r" in value:
            raise IniError("value must be a single line")
        return value

    def _section_span(self, section: str) -> Optional[Tuple[int, int]]:
        """Return (header_index, end_index) for the last matching section.

        end_index is the index of the next section header, or len(lines).
        """
        headers = [
            i
            for i, line in enumerate(self.lines)
            if (m := SECTION_RE.match(line)) and m.group(1).strip() == section
        ]
        if not headers:
            return None

        header = headers[-1]
        end = len(self.lines)
        for i in range(header + 1, len(self.lines)):
            if SECTION_RE.match(self.lines[i]):
                end = i
                break
        return header, end

    def set(
        self,
        section: str,
        key: str,
        value: str,
        if_missing: bool = False,
        backup: bool = False,
    ) -> bool:
        section = self._validate_section(section)
        key = self._validate_key(key)
        value = self._validate_value(value)

        if if_missing and self.has(section, key):
            return False

        span = self._section_span(section)
        if span is None:
            if self.lines and self.lines[-1].strip():
                self.lines.append("")
            self.lines.append(f"[{section}]")
            self.lines.append(f"{key} = {value}")
            self.dirty = True
        else:
            header, end = span
            key_lines = [
                e.line
                for e in self.entries(section)
                if e.key == key and header < e.line < end
            ]
            if key_lines:
                idx = key_lines[-1]
                indent = re.match(r"^\s*", self.lines[idx]).group(0)
                new_line = f"{indent}{key} = {value}"
                if self.lines[idx] != new_line:
                    self.lines[idx] = new_line
                    self.dirty = True
            else:
                # Insert after the last non-blank line of the section.
                insert = header + 1
                for i in range(header + 1, end):
                    if self.lines[i].strip():
                        insert = i + 1
                self.lines.insert(insert, f"{key} = {value}")
                self.dirty = True

        if not self.dirty:
            return False
        self.save(backup=backup)
        return True

    def delete(self, section: str, key: str, backup: bool = False) -> bool:
        section = self._validate_section(section)
        key = self._validate_key(key)

        span = self._section_span(section)
        if span is None:
            return False
        header, end = span

        key_lines = [
            e.line
            for e in self.entries(section)
            if e.key == key and header < e.line < end
        ]
        if not key_lines:
            return False

        for idx in reversed(key_lines):
            del self.lines[idx]
        self.dirty = True
        self.save(backup=backup)
        return True

    def delete_section(self, section: str, backup: bool = False) -> bool:
        section = self._validate_section(section)
        span = self._section_span(section)
        if span is None:
            return False

        header, end = span
        del self.lines[header:end]
        self.dirty = True
        self.save(backup=backup)
        return True

    def save(self, backup: bool = False) -> None:
        if not self.dirty:
            return

        target = self.path
        if target.is_symlink():
            target = target.resolve()
        target = target.absolute()

        parent = target.parent
        if not parent.is_dir():
            raise IniError(f"directory not found: {parent}")

        if backup and target.exists():
            shutil.copy2(target, str(target) + ".bak")

        fd, tmp = tempfile.mkstemp(
            prefix=f".{target.name}.", suffix=".tmp", dir=str(parent)
        )
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(self._text().encode("utf-8", errors="surrogateescape"))
            if target.exists():
                shutil.copystat(target, tmp)
            else:
                os.chmod(tmp, 0o644)
            os.replace(tmp, target)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise

        self.path = target
        self.exists = True
        self.dirty = False

    # ---- validate -----------------------------------------------------
    def validate(self) -> Tuple[List[str], List[str]]:
        errors: List[str] = []
        warnings: List[str] = []
        cur = ""
        seen_sections: set[str] = set()
        seen_keys: dict[str, set[str]] = {}

        for idx, line in enumerate(self.lines, start=1):
            stripped = line.strip()
            if not stripped or COMMENT_RE.match(line):
                continue

            m = SECTION_RE.match(line)
            if m:
                name = m.group(1).strip()
                if not name:
                    errors.append(f"line {idx}: empty section name")
                elif name in seen_sections:
                    warnings.append(f"line {idx}: duplicate section [{name}]")
                seen_sections.add(name)
                seen_keys.setdefault(name, set())
                cur = name
                continue

            if line.lstrip().startswith("["):
                errors.append(f"line {idx}: invalid section header: {line!r}")
                continue

            m = KEY_RE.match(line)
            if m:
                key = m.group(1).strip()
                if not key:
                    errors.append(f"line {idx}: empty key")
                elif key in seen_keys.setdefault(cur, set()):
                    warnings.append(
                        f"line {idx}: duplicate key {key!r} in section [{cur}]"
                    )
                seen_keys.setdefault(cur, set()).add(key)
                continue

            if "=" in line:
                errors.append(f"line {idx}: invalid key/value line: {line!r}")
            else:
                warnings.append(f"line {idx}: unrecognized line: {line!r}")

        if "" in seen_keys and seen_keys[""]:
            warnings.append("key(s) outside any section")
        return errors, warnings


USAGE = """usage: 05.cfg.py ini <command> [args]

commands:
  get            <file> <section> <key>
  get-default    <file> <section> <key> <default>
  get-all        <file> <section> <key>
  has            <file> <section> <key>
  set            <file> <section> <key> <value>
  set-if-missing <file> <section> <key> <value>
  del            <file> <section> <key>
  del-section    <file> <section>
  sections       <file>
  keys           <file> <section>
  entries        <file> [section]
  numbered       <file> <section>
  validate       <file>

env:
  INI_BACKUP=1   create <file>.bak before writing
"""


def _err(message: str) -> None:
    print(f"ini: {message}", file=sys.stderr)


def _load(path: str, create: bool = False) -> IniFile:
    return IniFile.load(path, create=create)


def _check_args(args: Sequence[str], count: int, usage: str) -> None:
    if len(args) != count:
        raise IniError(f"usage: 05.cfg.py ini {usage}")


def _cmd_get(args: Sequence[str]) -> int:
    _check_args(args, 3, "get <file> <section> <key>")
    doc = _load(args[0])
    value = doc.get(args[1], args[2])
    if value is None:
        return 1
    print(value)
    return 0


def _cmd_get_default(args: Sequence[str]) -> int:
    _check_args(args, 4, "get-default <file> <section> <key> <default>")
    doc = _load(args[0])
    value = doc.get(args[1], args[2], args[3])
    print(value)
    return 0


def _cmd_get_all(args: Sequence[str]) -> int:
    _check_args(args, 3, "get-all <file> <section> <key>")
    doc = _load(args[0])
    values = doc.get_all(args[1], args[2])
    if not values:
        return 1
    for value in values:
        print(value)
    return 0


def _cmd_has(args: Sequence[str]) -> int:
    _check_args(args, 3, "has <file> <section> <key>")
    doc = _load(args[0])
    return 0 if doc.has(args[1], args[2]) else 1


def _cmd_set(args: Sequence[str], if_missing: bool = False) -> int:
    usage = (
        "set-if-missing <file> <section> <key> <value>"
        if if_missing
        else "set <file> <section> <key> <value>"
    )
    _check_args(args, 4, usage)
    doc = _load(args[0], create=True)
    doc.set(
        args[1],
        args[2],
        args[3],
        if_missing=if_missing,
        backup=_backup_enabled(),
    )
    return 0


def _cmd_del(args: Sequence[str]) -> int:
    _check_args(args, 3, "del <file> <section> <key>")
    doc = _load(args[0])
    return 0 if doc.delete(args[1], args[2], backup=_backup_enabled()) else 1


def _cmd_del_section(args: Sequence[str]) -> int:
    _check_args(args, 2, "del-section <file> <section>")
    doc = _load(args[0])
    return 0 if doc.delete_section(args[1], backup=_backup_enabled()) else 1


def _cmd_sections(args: Sequence[str]) -> int:
    _check_args(args, 1, "sections <file>")
    doc = _load(args[0])
    for section in doc.sections():
        print(section)
    return 0


def _cmd_keys(args: Sequence[str]) -> int:
    _check_args(args, 2, "keys <file> <section>")
    doc = _load(args[0])
    if args[1] not in doc.sections():
        return 1
    for key in doc.keys(args[1]):
        print(key)
    return 0


def _cmd_entries(args: Sequence[str]) -> int:
    if len(args) not in (1, 2):
        raise IniError("usage: 05.cfg.py ini entries <file> [section]")
    doc = _load(args[0])
    section = args[1] if len(args) == 2 else None
    if section is not None and section not in doc.sections():
        return 1
    for entry in doc.entries(section):
        print(f"{entry.section}\t{entry.key}\t{entry.value}")
    return 0


def _cmd_numbered(args: Sequence[str]) -> int:
    _check_args(args, 2, "numbered <file> <section>")
    doc = _load(args[0])
    if args[1] not in doc.sections():
        return 1
    for entry in doc.numbered(args[1]):
        print(f"{entry.key}\t{entry.value}")
    return 0


def _cmd_validate(args: Sequence[str]) -> int:
    _check_args(args, 1, "validate <file>")
    doc = _load(args[0])
    errors, warnings = doc.validate()
    for warning in warnings:
        _err(f"warning: {warning}")
    for error in errors:
        _err(f"error: {error}")
    return 1 if errors else 0


def _ini_main(argv: Sequence[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(USAGE, end="")
        return 0

    command = argv[0]
    args = argv[1:]

    try:
        if command == "get":
            return _cmd_get(args)
        if command == "get-default":
            return _cmd_get_default(args)
        if command == "get-all":
            return _cmd_get_all(args)
        if command == "has":
            return _cmd_has(args)
        if command == "set":
            return _cmd_set(args)
        if command == "set-if-missing":
            return _cmd_set(args, if_missing=True)
        if command == "del":
            return _cmd_del(args)
        if command == "del-section":
            return _cmd_del_section(args)
        if command == "sections":
            return _cmd_sections(args)
        if command == "keys":
            return _cmd_keys(args)
        if command == "entries":
            return _cmd_entries(args)
        if command == "numbered":
            return _cmd_numbered(args)
        if command == "validate":
            return _cmd_validate(args)
    except IniError as exc:
        _err(str(exc))
        return 2
    except OSError as exc:
        _err(str(exc))
        return 2

    _err(f"unknown command: {command}")
    print(USAGE, end="", file=sys.stderr)
    return 2
