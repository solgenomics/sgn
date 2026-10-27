#!/usr/bin/env python3
"""Deterministic gettext source extraction and data-only SGN catalogs."""

import argparse
import ast
import hashlib
import json
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from extract import extract, po_quote, pot

SCHEMA = API = 1
LOCALE = re.compile(r"^[a-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$")
PLACEHOLDER = re.compile(r"%\{([A-Za-z][A-Za-z0-9_]*)\}")
MAX_BYTES = 2 * 1024 * 1024
# Translator notes and source references are excluded from MO/JSON outputs.
MAX_PO_BYTES = 4 * 1024 * 1024


def validate_language_name(value):
    """Native language names are display data, never markup or identifiers."""
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 200
        or any(ord(c) < 32 or 0x7F <= ord(c) <= 0x9F or c in "\u2028\u2029" for c in value)
    ):
        raise ValueError("invalid native language name")
    return value


def json_bytes(value):
    """Serialize canonical UTF-8 data for fingerprints and pack files."""
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def digest(value):
    """Return the SHA-256 fingerprint of supplied bytes."""
    return hashlib.sha256(value).hexdigest()


def source_revision(messages):
    """Fingerprint message identities independently of source references."""
    return digest(json_bytes([{k: m[k] for k in ("context", "source", "plural")} for m in messages]))


def source_messages(root):
    """Extract the explicit source registry after validating its paths."""
    paths = [
        line.strip()
        for line in (root / "locale/sources.txt").read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    for path in paths:
        if Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError("source path must stay inside project")
    return extract(root, paths)


def read_mo(data):
    """Read GNU MO strings without gettext's Plural-Forms callback compiler."""
    if len(data) < 28 or len(data) > MAX_BYTES:
        raise ValueError("invalid MO size")
    magic = struct.unpack("<I", data[:4])[0]
    order = "<" if magic == 0x950412DE else ">" if magic == 0xDE120495 else None
    if order is None:
        raise ValueError("invalid MO magic")
    _, revision, count, originals, translations, _, _ = struct.unpack(order + "7I", data[:28])
    if revision != 0 or count > 20000:
        raise ValueError("unsupported MO revision or entry count")
    result = {}
    for i in range(count):
        parts = []
        for table in (originals, translations):
            offset = table + i * 8
            if offset + 8 > len(data):
                raise ValueError("invalid MO table")
            length, begin = struct.unpack(order + "2I", data[offset : offset + 8])
            if begin + length >= len(data) or data[begin + length] != 0:
                raise ValueError("invalid MO string boundary")
            parts.append(data[begin : begin + length].decode("utf-8"))
        if parts[0] in result:
            raise ValueError("duplicate MO source")
        result[parts[0]] = parts[1]
    return result


def parse_plural(root, expression):
    """Compile a trusted plural grammar to validated data-only AST nodes."""
    if len(expression) > 512:
        raise ValueError("plural expression too large")
    program = (
        "const fs=require('fs'); const api=require(process.argv[1]); const "
        "x=JSON.parse(fs.readFileSync(0,'utf8')); "
        "process.stdout.write(JSON.stringify(api.parsePlural(x)));"
    )
    run = subprocess.run(
        ["node", "-e", program, str(root / "static/js/sgn-i18n.js")],
        input=json.dumps(expression),
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    if run.returncode:
        raise ValueError("unsupported or unsafe plural expression: " + run.stderr.strip()[:200])
    result = json.loads(run.stdout)
    validate_plural_safety(result["ast"], result["nplurals"])
    return result


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=redefined-outer-name
def validate_plural_safety(ast, nplurals):
    """Prove the supported integer grammar cannot divide by zero or overflow forms.

    Standard language formulas use modulo by positive constants, comparisons,
    and ternaries selecting fixed form indices. Reject unprovable extensions.
    This complements runtime samples with an all-count conservative bound.
    """

    def constant(node):
        """Return a literal AST integer, or no value for a nonconstant node."""
        while node.get("type") == "GROUP":
            node = node["expr"]
        return node.get("val") if node.get("type") == "NUM" else None

    def bounds(node):
        """Prove conservative plural-index bounds for every supported count."""
        kind = node["type"]
        if kind == "NUM":
            return node["val"], node["val"]
        if kind == "VAR":
            return 0, 9007199254740991
        if kind == "GROUP":
            return bounds(node["expr"])
        if kind == "TERNARY":
            bounds(node["expr"])
            left, right = bounds(node["truthy"]), bounds(node["falsey"])
            return min(left[0], right[0]), max(left[1], right[1])
        left, right = bounds(node["left"]), bounds(node["right"])
        if kind == "MOD":
            divisor = constant(node["right"])
            if divisor is None or divisor <= 0:
                raise ValueError("plural modulo divisor must be a positive integer constant")
            return 0, min(left[1], divisor - 1)
        return 0, 1

    low, high = bounds(ast)
    if low < 0 or high >= nplurals:
        raise ValueError("plural index cannot be proven inside the catalog form count")


# pylint: enable=redefined-outer-name


def metadata(header):
    """Read unique gettext metadata fields without evaluating values."""
    result = {}
    for line in header.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            if key in result:
                raise ValueError("duplicate PO header: " + key)
            result[key] = value.strip()
    return result


def placeholders(text):
    """Collect complete named interpolation fields and reject malformed ones."""
    result = set(PLACEHOLDER.findall(text))
    remaining = PLACEHOLDER.sub("", text)
    if "%{" in remaining:
        raise ValueError("invalid named placeholder")
    return result


def validate_control_placeholders(context, source, forms):
    """One native menu control cannot be duplicated like ordinary text values."""
    if (context, source) in {
        ("file_list.datatable.length_menu", "Show %{menu} entries"),
        ("odk.table.length", "Show %{menu} entries"),
    }:
        if any(PLACEHOLDER.findall(text).count("menu") != 1 or "_MENU_" in text for text in forms):
            raise ValueError(context + " must contain exactly one %{menu} control placeholder")


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals
def compile_po(root, path, current_messages):
    """Validate gettext input and compile exact compatible message forms."""
    if path.stat().st_size > MAX_PO_BYTES:
        raise ValueError("PO exceeds size limit")
    with tempfile.TemporaryDirectory(prefix="sgn-i18n-mo-") as temporary:
        mo = Path(temporary) / "catalog.mo"
        run = subprocess.run(
            [
                "msgfmt",
                "--check",
                "--check-format",
                "--check-header",
                "-o",
                str(mo),
                str(path),
            ],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if run.returncode:
            raise ValueError("msgfmt rejected " + str(path) + ": " + run.stderr.strip())
        catalog = read_mo(mo.read_bytes())
    info = metadata(catalog.pop("", ""))
    locale = info.get("Language", "")
    if not LOCALE.fullmatch(locale) or locale == "en":
        raise ValueError("invalid or reserved Language in PO")
    if path.parent.parent.name != locale:
        raise ValueError("PO directory and Language must agree")
    native_name = info.get("X-SGN-Language-Name")
    if native_name is not None:
        validate_language_name(native_name)
    direction = info.get("X-SGN-Direction", "")
    if direction not in ("ltr", "rtl"):
        raise ValueError("X-SGN-Direction must be ltr or rtl")
    formula = info.get("Plural-Forms", "")
    plural = parse_plural(root, formula)
    revision = source_revision(current_messages)
    # The fingerprint records catalog provenance. Exact context + English text
    # (and exact plural source) determine compatibility, not the whole digest.
    # Incomplete older languages must remain useful after unrelated additions.
    expected = {m["context"] + "\x04" + m["source"]: m for m in current_messages}
    messages = {}
    for original, target in sorted(catalog.items()):
        sources = original.split("\x00")
        key = sources[0]
        if key not in expected:
            raise ValueError("unregistered or obsolete source in PO: " + key)
        source = expected[key]
        original_plural = sources[1] if len(sources) == 2 else None
        if len(sources) > 2 or original_plural != source["plural"]:
            raise ValueError("stale plural source: " + source["context"])
        forms = target.split("\x00")
        required = plural["nplurals"] if original_plural else 1
        # msgfmt omits empty/fuzzy singulars; incomplete plurals omit whole record.
        if len(forms) != required or any(not item.strip() for item in forms):
            continue
        variables = placeholders(source["source"])
        if original_plural and placeholders(original_plural) != variables:
            raise ValueError("plural source placeholder mismatch: " + source["context"])
        if any(placeholders(item) != variables for item in forms):
            raise ValueError("translation placeholder mismatch: " + source["context"])
        validate_control_placeholders(source["context"], source["source"], forms)
        messages[key] = {"plural": original_plural, "forms": forms}
    result = {
        "schema": SCHEMA,
        "api": API,
        "locale": locale,
        "direction": direction,
        "sourceRevision": revision,
        "nplurals": plural["nplurals"],
        "pluralForms": plural.get("normalized", formula),
        "pluralAst": plural["ast"],
        "messages": messages,
    }
    if native_name is not None:
        result["languageName"] = native_name
    # JSON record overhead can exceed the independent pack limit even when
    # the PO and MO inputs fit. Reject before build writes any language output.
    if len(json_bytes(result)) > MAX_BYTES:
        raise ValueError("compiled catalog exceeds the independent pack size limit")
    return result


# pylint: enable=too-many-branches,too-many-locals


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals
def partition_sources(root, messages):
    """Assign reviewed sources and their authored UI components to workflows."""
    manifest = json.loads((root / "locale/workflows.json").read_text())
    if manifest.get("schema") != 1:
        raise ValueError("unsupported workflow manifest")
    owners = manifest["source_workflows"]
    registered = {
        line.strip()
        for line in (root / "locale/sources.txt").read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    if set(owners) != registered or any(
        not re.fullmatch(r"[a-z][a-z0-9_]*", group) or group == "common" for group in owners.values()
    ):
        raise ValueError("workflow assignments must exactly cover registered sources")
    common = set(manifest["common_sources"])
    prefixes = manifest["common_context_prefixes"]
    if not common <= registered or any(not isinstance(p, str) or not p for p in prefixes):
        raise ValueError("invalid shared workflow sources or contexts")
    # Follow authored component/class references, not aggregate webpack imports:
    # globally defining a class does not mean every page invokes that workflow.
    edges = {}
    for path in registered - common:
        text = (root / path).read_text(encoding="utf-8")
        targets = set()
        if path.startswith("mason/"):
            for match in re.finditer(r"<&\|?\s*[\'\"]?([A-Za-z0-9_./-]+\.mas)", text):
                value = match[1]
                target = "mason" + value if value.startswith("/") else str(Path(path).parent / value)
                if target in registered:
                    targets.add(target)
        if Path(path).suffix in (".mas", ".js", ".mjs", ".cjs"):
            for name in re.findall(r"\b(?:CXGN|solGS)(?:\.[A-Za-z][A-Za-z0-9_]*)+", text):
                target = "js/source/legacy/" + name.replace(".", "/") + ".js"
                if target in registered:
                    targets.add(target)
        edges[path] = targets - common
    sources = {group: {p for p, owner in owners.items() if owner == group} for group in sorted(set(owners.values()))}
    for group, paths in sources.items():
        pending = list(paths - common)
        while pending:
            for target in edges.get(pending.pop(), set()) - paths:
                paths.add(target)
                pending.append(target)
    common_contexts = {
        m["context"]
        for m in messages
        if m["context"].startswith(tuple(prefixes)) or any(ref.rsplit(":", 1)[0] in common for ref in m["references"])
    }
    result = {"common": [m for m in messages if m["context"] in common_contexts]}
    for group, paths in sources.items():
        contexts = {
            m["context"]
            for m in messages
            if m["context"] not in common_contexts and any(ref.rsplit(":", 1)[0] in paths for ref in m["references"])
        }
        result[group] = [m for m in messages if m["context"] in contexts]
    expected = {(m["context"], m["source"], m["plural"]) for m in messages}
    actual = {(m["context"], m["source"], m["plural"]) for part in result.values() for m in part}
    if expected != actual:
        raise ValueError("partitioned sources lost message identities")
    return result


# pylint: enable=too-many-branches,too-many-locals


def partition_po_entries(path):
    """Canonicalize with GNU gettext, then select whole entries in linear time."""
    run = subprocess.run(
        ["msgcat", "--force-po", "--no-wrap", str(path)], capture_output=True, text=True, timeout=10, check=False
    )
    if run.returncode:
        raise ValueError("msgcat rejected " + str(path) + ": " + run.stderr.strip())
    entries = []
    for block in run.stdout.split("\n\n"):
        context = None
        active = False
        for line in block.splitlines():
            if line.startswith("msgctxt "):
                context = ast.literal_eval(line[len("msgctxt ") :])
                active = True
            elif active and line.startswith('"'):
                context += ast.literal_eval(line)
            else:
                active = False
        header = context is None and bool(re.search(r'^msgid ""$', block, re.M))
        entries.append((context, header, block))
    return entries


def compile_partition(root, path, messages, *, invert=False, entries=None):
    """Filter authoritative PO before the unchanged bounded MO/JSON compiler."""
    contexts = {m["context"] for m in messages}
    entries = partition_po_entries(path) if entries is None else entries
    selected_blocks = [block for context, header, block in entries if header or ((context in contexts) != invert)]
    with tempfile.TemporaryDirectory(prefix="sgn-i18n-partition-") as temporary:
        selected = Path(temporary) / path.parent.parent.name / "LC_MESSAGES" / "sgn.po"
        selected.parent.mkdir(parents=True)
        selected.write_text("\n\n".join(selected_blocks) + "\n")
        return compile_po(root, selected, [] if invert else messages)


def init_po(messages, locale, direction, formula, native_name=None):
    """Create an empty language catalog with explicit locale metadata."""
    if not LOCALE.fullmatch(locale) or direction not in ("ltr", "rtl"):
        raise ValueError("invalid locale or direction")
    text = pot(messages)
    headers = [
        "Language: " + locale,
        "PO-Revision-Date: 2026-10-04 00:00+0000",
        "Last-Translator: SGN translation team",
        "Language-Team: " + locale,
        "Plural-Forms: " + formula,
        "X-SGN-Direction: " + direction,
        "X-SGN-Source-Revision: " + source_revision(messages),
    ]
    if native_name is not None:
        headers.append("X-SGN-Language-Name: " + validate_language_name(native_name))
    insertion = "".join(po_quote(header + "\n") + "\n" for header in headers)
    text = text.replace(
        '"Content-Transfer-Encoding: 8bit\\n"\n',
        '"Content-Transfer-Encoding: 8bit\\n"\n' + insertion,
    )
    # Source POT has two generic slots; use the locale's explicit count.
    match = re.search(r"\bnplurals\s*=\s*([1-6])\s*;", formula)
    if not match:
        raise ValueError("unsupported nplurals")
    slots = "\n".join("msgstr[" + str(i) + '] ""' for i in range(int(match.group(1))))
    return text.replace('msgstr[0] ""\nmsgstr[1] ""', slots)


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals,too-many-statements
def main():
    """Run the command-line operation and fail on invalid input."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("extract")
    commands.add_parser("update")
    build = commands.add_parser("build")
    build.add_argument("--output", type=Path, default=Path("locale/build"))
    build.add_argument(
        "--legacy-single-file",
        action="store_true",
        help="Export a bounded legacy language pack for existing offline pack tools",
    )
    build.add_argument(
        "--po",
        action="append",
        type=Path,
        help="compile only selected PO files, including external translator work",
    )
    init = commands.add_parser("init")
    init.add_argument("--locale", required=True)
    init.add_argument("--direction", choices=("ltr", "rtl"), required=True)
    init.add_argument("--plural-forms", required=True)
    init.add_argument("--output", type=Path, required=True)
    init.add_argument("--name", help="native language name, such as Français; optional for old packs")
    args = parser.parse_args()
    root = args.root.resolve()
    messages = source_messages(root)
    if args.command == "extract":
        output = root / "locale/sgn.pot"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(pot(messages), encoding="utf-8")
        print(json.dumps({"messages": len(messages), "sourceRevision": source_revision(messages)}))
    elif args.command == "update":
        template = root / "locale/sgn.pot"
        template.write_text(pot(messages), encoding="utf-8")
        for path in sorted((root / "locale").glob("*/LC_MESSAGES/sgn.po")):
            with tempfile.TemporaryDirectory(prefix="sgn-i18n-merge-") as temporary:
                merged = Path(temporary) / "merged.po"
                run = subprocess.run(
                    [
                        "msgmerge",
                        "--quiet",
                        "--no-wrap",
                        "-o",
                        str(merged),
                        str(path),
                        str(template),
                    ],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=False,
                )
                if run.returncode:
                    raise ValueError("msgmerge rejected " + str(path))
                text = merged.read_text(encoding="utf-8")
                revision_line = po_quote("X-SGN-Source-Revision: " + source_revision(messages) + "\n")
                if re.search(r'^"X-SGN-Source-Revision:.*"$', text, re.M):
                    text = re.sub(
                        r'^"X-SGN-Source-Revision:.*"$',
                        lambda _, line=revision_line: line,
                        text,
                        flags=re.M,
                    )
                else:
                    text = text.replace(
                        '"Content-Transfer-Encoding: 8bit\\n"',
                        '"Content-Transfer-Encoding: 8bit\\n"\n' + revision_line,
                    )
                path.write_text(text, encoding="utf-8")
        print(json.dumps({"updated": True, "sourceRevision": source_revision(messages)}))
    elif args.command == "init":
        if args.output.exists():
            raise ValueError("refusing to overwrite an existing translation")
        parse_plural(root, args.plural_forms)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            init_po(messages, args.locale, args.direction, args.plural_forms, args.name),
            encoding="utf-8",
        )
    else:
        expected = pot(messages)
        if (root / "locale/sgn.pot").read_text(encoding="utf-8") != expected:
            raise ValueError("POT is stale; run extract and merge/review translations")
        paths = (
            [path if path.is_absolute() else root / path for path in args.po]
            if args.po
            else sorted((root / "locale").glob("*/LC_MESSAGES/sgn.po"))
        )
        output = args.output if args.output.is_absolute() else root / args.output
        if (root / "locale/workflows.json").is_file() and not args.legacy_single_file:
            partitions = partition_sources(root, messages)
            builds = []
            locales = set()
            for path in paths:
                # Filled obsolete sources must not disappear behind the filter.
                entries = partition_po_entries(path)
                compile_partition(root, path, messages, invert=True, entries=entries)
                catalogs = {
                    name: compile_partition(root, path, source, entries=entries) for name, source in partitions.items()
                }
                locale = catalogs["common"]["locale"]
                if locale in locales:
                    raise ValueError("duplicate locale in selected PO files")
                locales.add(locale)
                builds.append((locale, catalogs))
            # Validate every partition of every language before writing outputs.
            for locale, catalogs in builds:
                directory = output / locale / "sgn"
                directory.mkdir(parents=True, exist_ok=True)
                entries = []
                for name, catalog in catalogs.items():
                    data = json_bytes(catalog)
                    (directory / (name + ".json")).write_bytes(data)
                    entries.append({"name": name, "sha256": digest(data)})
                index = {
                    "schema": 1,
                    "domain": "sgn",
                    "sourceRevision": source_revision(messages),
                    "partitions": entries,
                }
                (directory / "index.json").write_bytes(json_bytes(index))
                (output / locale / "sgn.json").unlink(missing_ok=True)
            print(
                json.dumps(
                    {
                        "locales": len(builds),
                        "partitions": len(partitions),
                        "messages": len(messages),
                        "sourceRevision": source_revision(messages),
                    }
                )
            )
        else:
            catalogs = [compile_po(root, path, messages) for path in paths]
            if len({catalog["locale"] for catalog in catalogs}) != len(catalogs):
                raise ValueError("duplicate locale in selected PO files")
            for catalog in catalogs:
                path = output / catalog["locale"] / "sgn.json"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(json_bytes(catalog))
            print(
                json.dumps(
                    {
                        "catalogs": len(catalogs),
                        "messages": len(messages),
                        "sourceRevision": source_revision(messages),
                    }
                )
            )


# pylint: enable=too-many-branches,too-many-locals,too-many-statements


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error)) from error
