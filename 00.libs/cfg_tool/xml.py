"""XML adapter for the unified config tool (lxml + XPath)."""
from __future__ import annotations

import copy
import io
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

from .common import MISSING as _MISSING, backup_enabled as _backup_enabled

try:
    from lxml import etree
except ImportError as _lxml_exc:  # pragma: no cover - depends on host packages
    etree = None  # type: ignore[assignment]
    _LXML_IMPORT_ERROR = _lxml_exc
else:
    _LXML_IMPORT_ERROR = None


class XmlError(Exception):
    """XML read/write/CLI error."""


class XmlFormatError(XmlError):
    """XML input is not well-formed."""


_XML_DECL_RE = re.compile(br"^\s*<\?xml\b[^>]*\?>", re.S)
_XML_ENCODING_RE = re.compile(
    br"encoding\s*=\s*[\"']\s*([A-Za-z0-9._-]+)\s*[\"']"
)
_XML_STANDALONE_RE = re.compile(
    br"standalone\s*=\s*[\"']\s*(yes|no)\s*[\"']", re.IGNORECASE
)
_XML_NCNAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]*$")


def _xml_require() -> None:
    if etree is None:
        detail = f": {_LXML_IMPORT_ERROR}" if _LXML_IMPORT_ERROR else ""
        raise XmlError(
            "lxml is required for XML support; install it with "
            f"'python3 -m pip install lxml'{detail}"
        )


def _xml_parser():
    _xml_require()
    return etree.XMLParser(
        resolve_entities=False,
        no_network=True,
        load_dtd=False,
        recover=False,
        strip_cdata=False,
        remove_blank_text=False,
        remove_comments=False,
        remove_pis=False,
    )


def _xml_escape_attr(text: str) -> str:
    return (text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def _xml_is_element(node: object) -> bool:
    _xml_require()
    return isinstance(node, etree._Element) and not isinstance(
        node, (etree._Comment, etree._ProcessingInstruction)
    )


def _xml_bytes_end_newline(data: bytes) -> bool:
    return data.rstrip(b"\x00").endswith((b"\n", b"\r"))


def _xml_format(value: object, as_xml: bool = False) -> str:
    _xml_require()
    if isinstance(value, etree._Element):
        if as_xml:
            return etree.tostring(value, encoding="unicode", with_tail=False)
        return value.text or ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return repr(value)
    if value is None:
        return ""
    return str(value)


def _xml_resolve_qname(name: str, namespaces: dict) -> str:
    if not name:
        raise XmlError("empty element/attribute name")
    if name.startswith("{"):
        return name
    if ":" in name:
        prefix, local = name.split(":", 1)
        if not prefix or not local:
            raise XmlError(f"invalid qualified name: {name}")
        if prefix not in namespaces:
            raise XmlError(f"unknown namespace prefix: {prefix}")
        return f"{{{namespaces[prefix]}}}{local}"
    return name


class XmlFile:
    """XPath-based XML reader/writer using lxml.

    Parsing uses a hardened parser (no entity resolution, no network, no
    DTD loading, no recovery).  Comments, whitespace, CDATA sections and
    the XML declaration/encoding/doctype are preserved on save.
    """

    def __init__(self, path, tree, encoding: str = "UTF-8",
                 had_declaration: bool = False, standalone=None,
                 bom: bool = False, trailing_newline: bool = True) -> None:
        self.path = Path(path)
        self.tree = tree
        self.encoding = encoding
        self.had_declaration = had_declaration
        self.standalone = standalone
        self.bom = bom
        self.trailing_newline = trailing_newline
        self.dirty = False
        self.parser_errors: List[object] = []
        self._doctype = ""
        self._doctype_override: Optional[str] = None

    @classmethod
    def load(cls, path, create: bool = False):
        _xml_require()
        p = Path(path)
        if not p.exists():
            raise XmlError(f"file not found: {path}")
        try:
            data = p.read_bytes()
        except OSError as exc:
            raise XmlError(str(exc)) from exc

        parser = _xml_parser()
        try:
            tree = etree.parse(io.BytesIO(data), parser)
        except (etree.XMLSyntaxError, ValueError) as exc:
            raise XmlFormatError(f"{path}: {exc}") from exc

        head = data[3:] if data.startswith(b"\xef\xbb\xbf") else data
        decl = _XML_DECL_RE.match(head)
        had_declaration = decl is not None
        decl_text = decl.group(0) if decl else b""
        enc_match = _XML_ENCODING_RE.search(decl_text)
        if enc_match:
            encoding = enc_match.group(1).decode("ascii", "replace")
        else:
            encoding = tree.docinfo.encoding or "UTF-8"
        sa_match = _XML_STANDALONE_RE.search(decl_text)
        standalone = None
        if sa_match:
            standalone = sa_match.group(1).lower() == b"yes"

        doc = cls(
            p,
            tree,
            encoding=encoding,
            had_declaration=had_declaration,
            standalone=standalone,
            bom=data.startswith(b"\xef\xbb\xbf"),
            trailing_newline=_xml_bytes_end_newline(data),
        )
        doc.parser_errors = list(parser.error_log)
        doc._doctype = tree.docinfo.doctype or ""
        return doc

    # ---- XPath helpers ------------------------------------------------
    def _matches(self, xpath: str, namespaces) -> List[object]:
        _xml_require()
        try:
            result = self.tree.xpath(xpath, namespaces=namespaces or None)
        except etree.XPathError as exc:
            raise XmlError(f"invalid XPath: {xpath}: {exc}") from exc
        if isinstance(result, list):
            return result
        return [result]

    def _element_matches(self, xpath: str, namespaces,
                         content: bool = False) -> List[object]:
        matches = self._matches(xpath, namespaces)
        if content:
            elements = [m for m in matches
                        if isinstance(m, etree._Element)]
        else:
            elements = [m for m in matches if _xml_is_element(m)]
        if matches and not elements:
            raise XmlError(f"XPath does not select elements: {xpath}")
        return elements

    def _qname_namespaces(self, namespaces) -> dict:
        merged: dict = {}
        root = self.tree.getroot()
        if root is not None:
            for prefix, uri in (root.nsmap or {}).items():
                if prefix and uri:
                    merged[prefix] = uri
        merged.update(namespaces or {})
        return merged

    def _parse_fragment(self, value: str,
                        namespaces=None) -> Tuple[Optional[str], List[object]]:
        _xml_require()
        root = self.tree.getroot()
        nsmap = dict(root.nsmap or {}) if root is not None else {}
        for prefix, uri in (namespaces or {}).items():
            nsmap[prefix] = uri
        ns_parts: List[str] = []
        for prefix, uri in nsmap.items():
            if uri is None:
                continue
            attr = "xmlns" if prefix is None else f"xmlns:{prefix}"
            ns_parts.append(f' {attr}="{_xml_escape_attr(uri)}"')
        tag = "__cfg_fragment__"
        while tag in value:
            tag += "_"
        wrapper = (f"<{tag}{''.join(ns_parts)}>"
                   f"{value}</{tag}>")
        parser = _xml_parser()
        try:
            fragment = etree.fromstring(wrapper.encode("utf-8"), parser)
        except (etree.XMLSyntaxError, ValueError) as exc:
            raise XmlError(f"invalid XML fragment: {exc}") from exc
        return fragment.text, list(fragment)

    # ---- read ---------------------------------------------------------
    def get(self, xpath: str, default=_MISSING, namespaces=None):
        values = self.get_all(xpath, namespaces)
        if not values:
            if default is not _MISSING:
                return default
            raise KeyError(xpath)
        return values[0]

    def get_all(self, xpath: str, namespaces=None) -> List[object]:
        return self._matches(xpath, namespaces)

    def has(self, xpath: str, namespaces=None) -> bool:
        return bool(self._matches(xpath, namespaces))

    # ---- write --------------------------------------------------------
    def set(self, xpath: str, value: str, namespaces=None,
            all: bool = False, as_xml: bool = False) -> bool:
        targets = self._element_matches(xpath, namespaces)
        if not targets:
            return False
        if not all:
            targets = targets[:1]
        fragment = self._parse_fragment(value, namespaces) if as_xml else None
        for elem in targets:
            tail = elem.tail
            if fragment is not None:
                text, nodes = fragment
                for child in list(elem):
                    elem.remove(child)
                elem.text = text
                for node in nodes:
                    elem.append(copy.deepcopy(node))
            else:
                elem.text = value
            elem.tail = tail
        self.dirty = True
        return True

    def set_attr(self, xpath: str, name: str, value: str,
                 namespaces=None, all: bool = False) -> bool:
        targets = self._element_matches(xpath, namespaces)
        if not targets:
            return False
        if not all:
            targets = targets[:1]
        qname = _xml_resolve_qname(
            name, self._qname_namespaces(namespaces)
        )
        for elem in targets:
            try:
                elem.set(qname, value)
            except (TypeError, ValueError) as exc:
                raise XmlError(
                    f"invalid attribute name: {name}: {exc}"
                ) from exc
        self.dirty = True
        return True

    def add(self, parent_xpath: str, tag: str, text: Optional[str] = None,
            attrs=None, index: Optional[int] = None, namespaces=None) -> bool:
        parents = self._element_matches(parent_xpath, namespaces)
        if not parents:
            return False
        parent = parents[0]
        if index is not None and (index < 0 or index > len(parent)):
            raise XmlError(
                f"index out of range: {index} (0..{len(parent)})"
            )
        qname_namespaces = self._qname_namespaces(namespaces)
        qname = _xml_resolve_qname(tag, qname_namespaces)
        if ":" not in tag and not tag.startswith("{"):
            default_uri = (parent.nsmap or {}).get(None)
            if default_uri:
                qname = f"{{{default_uri}}}{tag}"
        try:
            child = etree.SubElement(parent, qname)
        except (TypeError, ValueError) as exc:
            raise XmlError(f"invalid element name: {tag}: {exc}") from exc
        if text is not None:
            child.text = text
        for attr_name, attr_value in attrs or []:
            attr_qname = _xml_resolve_qname(attr_name, qname_namespaces)
            try:
                child.set(attr_qname, attr_value)
            except (TypeError, ValueError) as exc:
                raise XmlError(
                    f"invalid attribute name: {attr_name}: {exc}"
                ) from exc
        if index is not None:
            parent.remove(child)
            parent.insert(index, child)
        self.dirty = True
        return True

    @staticmethod
    def _remove_element(elem) -> None:
        parent = elem.getparent()
        if parent is None:
            raise XmlError("cannot delete the root element")
        idx = parent.index(elem)
        tail = elem.tail
        if tail:
            if idx > 0:
                prev = parent[idx - 1]
                prev.tail = (prev.tail or "") + tail
            else:
                parent.text = (parent.text or "") + tail
        parent.remove(elem)

    def delete(self, xpath: str, namespaces=None,
               all: bool = False) -> bool:
        targets = self._element_matches(xpath, namespaces, content=True)
        if not targets:
            return False
        if not all:
            targets = targets[:1]
        for elem in reversed(targets):
            if elem.getparent() is None:
                raise XmlError("cannot delete the root element")
            self._remove_element(elem)
        self.dirty = True
        return True

    @staticmethod
    def _replace_at(parent, idx: int, elem, text: Optional[str],
                    nodes: List[object], tail: Optional[str]) -> None:
        if text:
            if idx > 0:
                prev = parent[idx - 1]
                prev.tail = (prev.tail or "") + text
            else:
                parent.text = (parent.text or "") + text
        parent.remove(elem)
        insert_at = idx
        for node in nodes:
            parent.insert(insert_at, node)
            insert_at += 1
        if tail:
            if insert_at > 0:
                prev = parent[insert_at - 1]
                prev.tail = (prev.tail or "") + tail
            else:
                parent.text = (parent.text or "") + tail

    def replace(self, xpath: str, fragment: str, namespaces=None,
                all: bool = False) -> bool:
        targets = self._element_matches(xpath, namespaces, content=True)
        if not targets:
            return False
        if not all:
            targets = targets[:1]
        text, nodes = self._parse_fragment(fragment, namespaces)
        for elem in reversed(targets):
            tail = elem.tail
            parent = elem.getparent()
            if parent is None:
                real = [n for n in nodes if _xml_is_element(n)]
                if (len(nodes) != 1 or len(real) != 1
                        or (text is not None and text.strip())):
                    raise XmlError(
                        "cannot replace the root element with a "
                        "multi-node fragment"
                    )
                new_root = copy.deepcopy(real[0])
                new_root.tail = None
                self._doctype_override = self._doctype or None
                self.tree._setroot(new_root)
            else:
                idx = parent.index(elem)
                copies = [copy.deepcopy(n) for n in nodes]
                self._replace_at(parent, idx, elem, text, copies, tail)
        self.dirty = True
        return True

    # ---- output -------------------------------------------------------
    def dump(self) -> bytes:
        _xml_require()
        encoding = self.encoding or "UTF-8"
        normalized = encoding.upper().replace("_", "-")
        xml_declaration = self.had_declaration
        if normalized not in ("UTF-8", "UTF8", "US-ASCII", "ASCII"):
            xml_declaration = True
        kwargs = {
            "encoding": encoding,
            "xml_declaration": xml_declaration,
            "pretty_print": False,
        }
        if xml_declaration and self.standalone is not None:
            kwargs["standalone"] = self.standalone
        if self._doctype_override and not (
            self.tree.docinfo.doctype or ""
        ):
            kwargs["doctype"] = self._doctype_override
        data = etree.tostring(self.tree, **kwargs)
        if self.bom and not data.startswith(b"\xef\xbb\xbf"):
            data = b"\xef\xbb\xbf" + data
        if self.trailing_newline and not _xml_bytes_end_newline(data):
            if normalized.startswith("UTF-16"):
                data += (b"\n\x00" if data.startswith(b"\xff\xfe")
                         else b"\x00\n")
            else:
                data += b"\n"
        return data

    def save(self, backup: bool = False) -> bool:
        if not self.dirty:
            return False
        target = self.path.resolve() if self.path.exists() else self.path
        parent = target.parent
        if not parent.exists():
            raise XmlError(f"parent directory not found: {parent}")
        data = self.dump()
        fd, tmp_name = tempfile.mkstemp(prefix=target.name + ".",
                                        suffix=".tmp", dir=str(parent))
        os.close(fd)
        tmp = Path(tmp_name)
        try:
            tmp.write_bytes(data)
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
        for entry in self.parser_errors:
            message = f"line {entry.line}: {entry.message}"
            if entry.level_name in ("WARNING", "INFO"):
                warnings.append(message)
            else:
                errors.append(message)
        return errors, warnings


XML_USAGE = """usage: 05.cfg.py xml <command> [args]

commands:
  get            <file> <xpath> [--xml] [--all] [--ns p=u]
  get-default    <file> <xpath> <default> [--xml] [--ns p=u]
  get-all        <file> <xpath> [--xml] [--ns p=u]
  has            <file> <xpath> [--ns p=u]
  set            <file> <xpath> <value> [--xml] [--all] [--ns p=u]
  set-attr       <file> <xpath> <name> <value> [--all] [--ns p=u]
  add            <file> <parent-xpath> <tag> [--text T] [--attr k=v]...
                 [--index N] [--ns p=u]
  del            <file> <xpath> [--all] [--ns p=u]
  replace        <file> <xpath> <xml-fragment> [--all] [--ns p=u]
  validate       <file>

notes:
  - paths are XPath expressions; use --ns prefix=uri for namespaces and
    repeat --ns for multiple prefixes.
  - a default XML namespace needs an explicit prefix, e.g. --ns
    d=urn:demo with //d:item.
  - --xml prints/sets XML instead of plain text; set --xml replaces the
    element's children with the parsed fragment.
  - --all applies writes/deletes to every match (default: first match).
  - set/add do not create missing files or elements.
  - a value starting with -- can be passed after a literal -- separator.

env:
  CFG_BACKUP=1 or INI_BACKUP=1   create <file>.bak before writing
"""


def _xml_err(message: str) -> None:
    print(f"xml: {message}", file=sys.stderr)


def _xml_load(path: str, create: bool = False) -> XmlFile:
    return XmlFile.load(path, create=create)


def _xml_check_args(args: Sequence[str], count: int, usage: str) -> None:
    if len(args) != count:
        raise XmlError(f"usage: 05.cfg.py xml {usage}")


def _xml_namespaces(entries: Sequence[str]) -> dict:
    namespaces: dict = {}
    for entry in entries:
        if "=" not in entry:
            raise XmlError(f"invalid --ns (expected prefix=uri): {entry}")
        prefix, uri = entry.split("=", 1)
        if not prefix or not _XML_NCNAME_RE.match(prefix):
            raise XmlError(f"invalid namespace prefix: {prefix!r}")
        if not uri:
            raise XmlError(f"empty namespace uri for prefix: {prefix}")
        namespaces[prefix] = uri
    return namespaces


def _xml_parse_attrs(entries: Sequence[str]) -> List[Tuple[str, str]]:
    attrs: List[Tuple[str, str]] = []
    for entry in entries:
        if "=" not in entry:
            raise XmlError(f"invalid --attr (expected key=value): {entry}")
        name, value = entry.split("=", 1)
        if not name:
            raise XmlError("empty attribute name")
        attrs.append((name, value))
    return attrs


def _xml_parse_index(value: Optional[str]) -> Optional[int]:
    if value is None:
        return None
    try:
        index = int(value)
    except ValueError:
        raise XmlError(f"invalid --index: {value}") from None
    if index < 0:
        raise XmlError(f"invalid --index: {value}")
    return index


def _xml_parse_opts(args: Sequence[str], allow_xml: bool = False,
                    allow_all: bool = False, allow_text: bool = False,
                    allow_attr: bool = False,
                    allow_index: bool = False):
    positionals: List[str] = []
    opts = {
        "xml": False,
        "all": False,
        "ns": [],
        "text": None,
        "attr": [],
        "index": None,
    }
    i = 0
    only_positionals = False
    while i < len(args):
        token = args[i]
        if only_positionals:
            positionals.append(token)
            i += 1
            continue
        if token == "--":
            only_positionals = True
            i += 1
            continue
        if token == "--xml" and allow_xml:
            opts["xml"] = True
            i += 1
            continue
        if token == "--all" and allow_all:
            opts["all"] = True
            i += 1
            continue
        if token == "--ns":
            if i + 1 >= len(args):
                raise XmlError("option --ns requires prefix=uri")
            opts["ns"].append(args[i + 1])
            i += 2
            continue
        if token.startswith("--ns="):
            opts["ns"].append(token[len("--ns="):])
            i += 1
            continue
        if allow_text and token == "--text":
            if i + 1 >= len(args):
                raise XmlError("option --text requires a value")
            opts["text"] = args[i + 1]
            i += 2
            continue
        if allow_text and token.startswith("--text="):
            opts["text"] = token[len("--text="):]
            i += 1
            continue
        if allow_attr and token == "--attr":
            if i + 1 >= len(args):
                raise XmlError("option --attr requires key=value")
            opts["attr"].append(args[i + 1])
            i += 2
            continue
        if allow_attr and token.startswith("--attr="):
            opts["attr"].append(token[len("--attr="):])
            i += 1
            continue
        if allow_index and token == "--index":
            if i + 1 >= len(args):
                raise XmlError("option --index requires a number")
            opts["index"] = args[i + 1]
            i += 2
            continue
        if allow_index and token.startswith("--index="):
            opts["index"] = token[len("--index="):]
            i += 1
            continue
        if token.startswith("--"):
            raise XmlError(f"unknown option: {token}")
        positionals.append(token)
        i += 1
    return positionals, opts


def _xml_cmd_get(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_xml=True, allow_all=True)
    _xml_check_args(
        args, 2,
        "get <file> <xpath> [--xml] [--all] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    values = doc.get_all(args[1], namespaces)
    if not values:
        return 1
    if not opts["all"]:
        values = values[:1]
    for value in values:
        print(_xml_format(value, opts["xml"]))
    return 0


def _xml_cmd_get_default(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_xml=True)
    _xml_check_args(
        args, 3,
        "get-default <file> <xpath> <default> [--xml] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    values = doc.get_all(args[1], namespaces)
    if not values:
        print(args[2])
        return 0
    print(_xml_format(values[0], opts["xml"]))
    return 0


def _xml_cmd_get_all(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_xml=True)
    _xml_check_args(
        args, 2,
        "get-all <file> <xpath> [--xml] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    values = doc.get_all(args[1], namespaces)
    if not values:
        return 1
    for value in values:
        print(_xml_format(value, opts["xml"]))
    return 0


def _xml_cmd_has(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args)
    _xml_check_args(args, 2, "has <file> <xpath> [--ns p=u]")
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    return 0 if doc.has(args[1], namespaces) else 1


def _xml_cmd_set(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_xml=True, allow_all=True)
    _xml_check_args(
        args, 3,
        "set <file> <xpath> <value> [--xml] [--all] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    if not doc.set(args[1], args[2], namespaces,
                   all=opts["all"], as_xml=opts["xml"]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _xml_cmd_set_attr(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_all=True)
    _xml_check_args(
        args, 4,
        "set-attr <file> <xpath> <name> <value> [--all] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    if not doc.set_attr(args[1], args[2], args[3], namespaces,
                        all=opts["all"]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _xml_cmd_add(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_text=True, allow_attr=True,
                                 allow_index=True)
    _xml_check_args(
        args, 3,
        "add <file> <parent-xpath> <tag> [--text T] [--attr k=v]... "
        "[--index N] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    attrs = _xml_parse_attrs(opts["attr"])
    index = _xml_parse_index(opts["index"])
    doc = _xml_load(args[0])
    if not doc.add(args[1], args[2], text=opts["text"], attrs=attrs,
                   index=index, namespaces=namespaces):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _xml_cmd_del(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_all=True)
    _xml_check_args(args, 2, "del <file> <xpath> [--all] [--ns p=u]")
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    if not doc.delete(args[1], namespaces, all=opts["all"]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _xml_cmd_replace(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args, allow_all=True)
    _xml_check_args(
        args, 3,
        "replace <file> <xpath> <xml-fragment> [--all] [--ns p=u]",
    )
    namespaces = _xml_namespaces(opts["ns"])
    doc = _xml_load(args[0])
    if not doc.replace(args[1], args[2], namespaces, all=opts["all"]):
        return 1
    doc.save(backup=_backup_enabled())
    return 0


def _xml_cmd_validate(args: Sequence[str]) -> int:
    args, opts = _xml_parse_opts(args)
    _xml_check_args(args, 1, "validate <file>")
    try:
        doc = _xml_load(args[0])
    except XmlFormatError as exc:
        _xml_err(f"error: {exc}")
        return 1
    errors, warnings = doc.validate()
    for warning in warnings:
        _xml_err(f"warning: {warning}")
    for error in errors:
        _xml_err(f"error: {error}")
    return 1 if errors else 0


def _xml_main(argv: Sequence[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(XML_USAGE, end="")
        return 0

    command = argv[0]
    args = argv[1:]

    try:
        if command == "get":
            return _xml_cmd_get(args)
        if command == "get-default":
            return _xml_cmd_get_default(args)
        if command == "get-all":
            return _xml_cmd_get_all(args)
        if command == "has":
            return _xml_cmd_has(args)
        if command == "set":
            return _xml_cmd_set(args)
        if command == "set-attr":
            return _xml_cmd_set_attr(args)
        if command == "add":
            return _xml_cmd_add(args)
        if command == "del":
            return _xml_cmd_del(args)
        if command == "replace":
            return _xml_cmd_replace(args)
        if command == "validate":
            return _xml_cmd_validate(args)
    except (XmlError, OSError) as exc:
        _xml_err(str(exc))
        return 2

    _xml_err(f"unknown command: {command}")
    print(XML_USAGE, end="", file=sys.stderr)
    return 2
