#!/usr/bin/env python3
"""Extract explicit literal i18n calls; never modify application source."""

import json
import os
import re
import subprocess
from pathlib import Path

from extraction_error import ExtractionError, has_literal_message_fields
from r_extract import extract_r


def is_mason_source(path):
    """Recognize .mas and exact native special components in the reviewed SGN root."""
    value = Path(path)
    return value.suffix == ".mas" or (
        not value.is_absolute()
        and ".." not in value.parts
        and len(value.parts) >= 2
        and value.parts[0] == "mason"
        and (value.name in ("autohandler", "dhandler") or value.as_posix() == "mason/tools/bulk/tabs/clone_search.html")
    )


def registered_source_suffix(path):
    """Registration requires a qualified compiler format, never a Perl default."""
    if is_mason_source(path):
        return ".mas"
    suffix = Path(path).suffix
    if suffix in (".pm", ".pl", ".js", ".mjs", ".cjs", ".R", ".r"):
        return suffix
    raise ExtractionError("Unsupported registered i18n source format for " + str(path))


def tag_end(text, start):
    """Find an HTML tag end outside quoted attrs and embedded Mason expressions."""
    quote = None
    i = start
    while i < len(text):
        if text.startswith("<%", i):
            end = text.find("%>", i + 2)
            if end < 0:
                raise ExtractionError("unterminated Mason expression in tag")
            i = end + 2
            continue
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == ">":
            return i
        i += 1
    return -1


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals,too-many-statements
def regions(text, suffix):
    """Separate Mason embedded languages before lexing their marked calls."""
    if suffix != ".mas":
        if suffix not in (".pm", ".pl", ".js", ".mjs", ".cjs"):
            raise ExtractionError("Unsupported embedded source format: " + repr(suffix))
        return [(0, text, "js" if suffix in (".js", ".mjs", ".cjs") else "perl")]
    result = []
    covered = []
    cursor = 0
    while cursor < len(text):
        candidates = [(text.find(marker, cursor), marker) for marker in ("<%", "<&", "<script")]
        candidates = [(offset, marker) for offset, marker in candidates if offset >= 0]
        if not candidates:
            break
        start, marker = min(candidates)
        if marker == "<script":
            opening = tag_end(text, start)
            end = text.lower().find("</script", opening)
            if opening < 0 or end < 0:
                raise ExtractionError("unterminated Mason script element")
            result.append((opening + 1, text[opening + 1 : end], "js"))
            cursor = tag_end(text, end) + 1
            covered.append((start, cursor))
        elif marker == "<&":
            end = text.find("&>", start + 2)
            if end < 0:
                raise ExtractionError("unterminated Mason component call")
            source = text[start + 2 : end]
            # A literal Mason path is not Perl: /generic_message.mas can be
            # lexed as a regex spanning quoted HTML and hide marked arguments.
            header = re.match(r"\s*\|?\s*/?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\s*(?:,|$)", source)
            if header:
                source = "".join(c if c in "\r\n" else " " for c in header[0]) + source[header.end() :]
            result.append((start + 2, source, "perl"))
            cursor = end + 2
            covered.append((start, cursor))
        else:
            named = re.match(
                r"<%(init|perl|once|shared|args|flags|attr|method|def|doc|text|cleanup)(?:\s[^>]*)?>",
                text[start:],
            )
            if named:
                name = named.group(1)
                body_start = start + named.end()
                end = text.find("</%" + name + ">", body_start)
                if end < 0:
                    raise ExtractionError("unterminated Mason " + name + " block")
                if name not in ("doc", "text"):
                    result.append((body_start, text[body_start:end], "perl"))
                cursor = end + len(name) + 4
                covered.append((start, cursor))
            else:
                end = text.find("%>", start + 2)
                if end < 0:
                    raise ExtractionError("unterminated Mason expression")
                result.append((start + 2, text[start + 2 : end], "perl"))
                cursor = end + 2
                covered.append((start, cursor))
    # Mason control lines contain Perl, but exclude lines inside existing regions.
    offset = 0
    for line in text.splitlines(keepends=True):
        if line.startswith("%") and not any(a <= offset < b for a, b in covered):
            result.append((offset + 1, line[1:], "perl"))
        offset += len(line)
    return sorted(result)


# pylint: enable=too-many-branches,too-many-locals,too-many-statements


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-nested-blocks,too-many-statements
def tokens(text, language):
    """Bounded lexical scanner for marked calls, comments, strings and delimiters."""
    i = 0
    while i < len(text):
        ch = text[i]
        if ch.isspace():
            i += 1
            continue
        if language == "perl" and ch == "#":
            end = text.find("\n", i)
            i = len(text) if end < 0 else end + 1
            continue
        if language == "js" and text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end + 1
            continue
        if language == "js" and text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                raise ExtractionError("unterminated JavaScript comment")
            i = end + 2
            continue
        if ch in "'\"`":
            quote = ch
            start = i
            i += 1
            value = ""
            dynamic = quote == "`"
            while i < len(text) and text[i] != quote:
                ch = text[i]
                if language == "perl" and quote == '"' and ch in "$@":
                    dynamic = True
                if ch == "\\":
                    i += 1
                    if i >= len(text):
                        raise ExtractionError("unterminated escape")
                    escaped = text[i]
                    if language == "perl" and quote == "'":
                        value += escaped if escaped in "'\\" else "\\" + escaped
                    else:
                        escapes = {
                            "n": "\n",
                            "r": "\r",
                            "t": "\t",
                            "b": "\b",
                            "f": "\f",
                            "\\": "\\",
                            "'": "'",
                            '"': '"',
                            "/": "/",
                        }
                        if escaped not in escapes:
                            # Unmarked application strings may use any escape.
                            # Marked literals must use portable escapes or UTF-8.
                            dynamic = True
                            value += "\\" + escaped
                        else:
                            value += escapes[escaped]
                else:
                    value += ch
                i += 1
            if i >= len(text):
                raise ExtractionError("unterminated string")
            i += 1
            yield ("dynamic" if dynamic else "string", value, start)
        elif ch.isalpha() or ch == "_":
            start = i
            i += 1
            while i < len(text) and (text[i].isalnum() or text[i] == "_"):
                i += 1
            yield ("name", text[start:i], start)
        else:
            start = i
            if text.startswith("->", i):
                yield ("symbol", "->", start)
                i += 2
            else:
                yield ("symbol", ch, start)
                i += 1


# pylint: enable=too-many-branches,too-many-nested-blocks,too-many-statements


def perl_extract(file, blocks):
    """Use trusted PPI helper argv; source reaches stdin strictly as JSON data."""
    configured = os.environ.get("SGN_I18N_PERL_COMMAND")
    if configured:
        try:
            command = json.loads(configured)
        except ValueError as error:
            raise ExtractionError("SGN_I18N_PERL_COMMAND must be a JSON argv array") from error
        if (
            not isinstance(command, list)
            or not command
            or any(not isinstance(value, str) or not value or "\x00" in value for value in command)
        ):
            raise ExtractionError("SGN_I18N_PERL_COMMAND must be a nonempty JSON argv array")
    else:
        command = ["perl", str(Path(__file__).with_name("perl_extract.pl"))]
    request = {"file": file, "blocks": blocks}
    try:
        run = subprocess.run(
            command,
            input=json.dumps(request, ensure_ascii=False),
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ExtractionError(
            "PPI extraction unavailable; install task-local Perl/PPI or configure SGN_I18N_PERL_COMMAND"
        ) from error
    if run.returncode:
        explanation = run.stderr.strip()[:500]
        raise ExtractionError("PPI extraction failed for " + file + ": " + explanation)
    try:
        result = json.loads(run.stdout)
    except ValueError as error:
        raise ExtractionError("PPI helper returned invalid JSON") from error
    if (
        not isinstance(result, dict)
        or result.get("schema") != 3
        or result.get("parser") != "PPI"
        or not isinstance(result.get("records"), list)
    ):
        raise ExtractionError("PPI helper returned an incompatible protocol")
    for record in result["records"]:
        if (
            not isinstance(record, dict)
            or not isinstance(record.get("context"), str)
            or not isinstance(record.get("source"), str)
            or not record["source"]
        ):
            raise ExtractionError("PPI helper returned invalid literal records")
        if record.get("plural") is not None and not isinstance(record["plural"], str):
            raise ExtractionError("PPI helper returned invalid plural source")
        if not isinstance(record.get("reference"), str) or not record["reference"].startswith(file + ":"):
            raise ExtractionError("PPI helper returned invalid source locations")
    return result["records"]


# Exact JSON scalar checks must reject bool and custom subclasses.
# pylint: disable=too-many-boolean-expressions,unidiomatic-typecheck
def javascript_extract(file, blocks):
    """Parse standard JavaScript with the trusted Acorn helper, without execution."""
    configured = os.environ.get("SGN_I18N_JAVASCRIPT_COMMAND")
    if configured:
        try:
            command = json.loads(configured)
        except ValueError as error:
            raise ExtractionError("SGN_I18N_JAVASCRIPT_COMMAND must be a JSON argv array") from error
        if (
            not isinstance(command, list)
            or not command
            or any(not isinstance(value, str) or not value or "\x00" in value for value in command)
        ):
            raise ExtractionError("SGN_I18N_JAVASCRIPT_COMMAND must be a nonempty JSON argv array")
    else:
        command = ["node", str(Path(__file__).with_name("javascript_extract.cjs"))]
    try:
        run = subprocess.run(
            command,
            input=json.dumps({"file": file, "blocks": blocks}, ensure_ascii=False),
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ExtractionError(
            "Acorn extraction unavailable; use task-local Node/Acorn or configure SGN_I18N_JAVASCRIPT_COMMAND"
        ) from error
    if run.returncode:
        raise ExtractionError("Acorn extraction failed for " + file + ": " + run.stderr.strip()[:500])
    try:
        result = json.loads(run.stdout)
    except ValueError as error:
        raise ExtractionError("Acorn helper returned invalid JSON") from error
    if (
        not isinstance(result, dict)
        or type(result.get("schema")) is not int
        or result["schema"] != 1
        or result.get("parser") != "Acorn"
        or result.get("parserVersion") != "8.18.0"
        or not isinstance(result.get("records"), list)
    ):
        raise ExtractionError("Acorn helper returned an incompatible protocol")
    for record in result["records"]:
        if not has_literal_message_fields(record):
            raise ExtractionError("Acorn helper returned invalid literal records")
        if record.get("plural") is not None and (not isinstance(record["plural"], str) or not record["plural"]):
            raise ExtractionError("Acorn helper returned invalid plural source")
        if (
            not isinstance(record.get("reference"), str)
            or not record["reference"].startswith(file + ":")
            or not record["reference"][len(file) + 1 :].isdigit()
        ):
            raise ExtractionError("Acorn helper returned invalid source locations")
    return result["records"]


# pylint: enable=too-many-boolean-expressions,unidiomatic-typecheck


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals,too-many-statements
def mask_mason_javascript(source, offset, text, perl_blocks):
    """Mask complete server delimiters; retain line numbers and dynamic ranges."""
    spans = []
    cursor = 0
    while cursor < len(source):
        choices = [(source.find(marker, cursor), marker) for marker in ("<%", "<&")]
        choices = [(start, marker) for start, marker in choices if start >= 0]
        if not choices:
            break
        start, marker = min(choices)
        named = (
            re.match(
                r"<%(init|perl|once|shared|args|flags|attr|method|def|doc|text|cleanup)(?:\s[^>]*)?>",
                source[start:],
            )
            if marker == "<%"
            else None
        )
        if named:
            name = named.group(1)
            body_start = start + named.end()
            body_end = source.find("</%" + name + ">", body_start)
            if body_end < 0:
                raise ExtractionError("unterminated nested Mason " + name + " block")
            end = body_end + len(name) + 4
            fragment = source[body_start:body_end]
            expression = False
            include_perl = name not in ("doc", "text")
        else:
            ending = "%>" if marker == "<%" else "&>"
            body_start = start + 2
            body_end = source.find(ending, body_start)
            if body_end < 0:
                raise ExtractionError("unterminated nested Mason expression")
            end = body_end + 2
            fragment = source[body_start:body_end]
            expression = True
            include_perl = True
        if include_perl:
            perl_blocks.append(
                {
                    "source": fragment,
                    "line_offset": text[: offset + body_start].count("\n"),
                    "fragment": True,
                }
            )
        spans.append((start, end, expression))
        cursor = end
    for match in re.finditer(r"(?m)^%[^\n]*", source):
        if any(start <= match.start() < end for start, end, _ in spans):
            continue
        perl_blocks.append(
            {
                "source": match.group(0)[1:],
                "line_offset": text[: offset + match.start()].count("\n"),
                "fragment": True,
            }
        )
        spans.append((match.start(), match.end(), False))
    masked = list(source)
    for start, end, expression in spans:
        for index in range(start, end):
            if masked[index] not in ("\n", "\r"):
                masked[index] = " "
        # An inert identifier parses in expression, declaration and receiver slots.
        # Nothing is executed; masked ranges still reject dynamic marked arguments.
        if expression:
            prefix = source[:start].rstrip()
            suffix = source[end:].lstrip()
            # Native optional_show.mas emits an optional chained suffix after
            # a complete call. Blank that dynamic suffix, not the call itself.
            if not (prefix.endswith(")") and suffix.startswith((";", "}"))):
                # Native stock-property components concatenate Mason output with
                # an identifier suffix. Spaces would split the inert identifier.
                joined = (start > 0 and re.match(r"[\w$]", source[start - 1])) or (
                    end < len(source) and re.match(r"[\w$]", source[end])
                )
                if joined and "\n" not in source[start:end] and "\r" not in source[start:end]:
                    masked[start:end] = "_" * (end - start)
                else:
                    masked[start] = "_"
    result = "".join(masked)
    # Acorn positions count UTF-16 code units; Python indices count Unicode points.
    ranges = [
        {
            "start": len(result[:start].encode("utf-16-le")) // 2,
            "end": len(result[:end].encode("utf-16-le")) // 2,
        }
        for start, end, _ in sorted(spans)
    ]
    return result, ranges


# pylint: enable=too-many-branches,too-many-locals,too-many-statements


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-branches,too-many-locals
def extract_file(path, root):
    """Parse one registered source file as data and retain source locations."""
    file = path.relative_to(root).as_posix()
    suffix = registered_source_suffix(file)
    text = path.read_text(encoding="utf-8")
    if suffix in (".R", ".r"):
        return extract_r(file, text)
    result = []
    chunks = regions(text, suffix)
    perl_blocks = []
    js_blocks = []
    mason_scripts = []
    for offset, source, language in chunks:
        if language == "perl":
            perl_blocks.append(
                {
                    "source": source,
                    "line_offset": text[:offset].count("\n"),
                    "fragment": suffix == ".mas",
                }
            )
        else:
            masked_ranges = []
            if suffix == ".mas":
                source, masked_ranges = mask_mason_javascript(source, offset, text, perl_blocks)
            if suffix == ".mas":
                opening = text[text.rfind("<script", 0, offset) : offset]
                if re.search(r"\btype\s*=\s*[\"\']module[\"\']", opening, re.I):
                    js_blocks.append(
                        {
                            "source": source,
                            "line_offset": text[:offset].count("\n"),
                            "source_type": "module",
                            "masked_ranges": masked_ranges,
                        }
                    )
                else:
                    mason_scripts.append((offset, source, masked_ranges))
            else:
                js_blocks.append(
                    {
                        "source": source,
                        "line_offset": text[:offset].count("\n"),
                        "source_type": ("module" if suffix == ".mjs" else "commonjs" if suffix == ".cjs" else "auto"),
                        "masked_ranges": masked_ranges,
                    }
                )
    if mason_scripts:
        # Classic script elements share the page's lexical environment. Blank HTML
        # separates their source while retaining the original line references.
        combined = ["\n" if character == "\n" else "\r" if character == "\r" else " " for character in text]
        for offset, source, _ in mason_scripts:
            combined[offset : offset + len(source)] = source
        combined = "".join(combined)
        ranges = []
        for offset, _, masked_ranges in mason_scripts:
            prefix = len(combined[:offset].encode("utf-16-le")) // 2
            ranges.extend({"start": prefix + item["start"], "end": prefix + item["end"]} for item in masked_ranges)
        js_blocks.append(
            {
                "source": combined,
                "line_offset": 0,
                "source_type": "script",
                "masked_ranges": ranges,
            }
        )
    if perl_blocks:
        result.extend(perl_extract(file, perl_blocks))
    if js_blocks:
        result.extend(javascript_extract(file, js_blocks))
    return result


# pylint: enable=too-many-branches,too-many-locals


def extract(root, paths):
    """Merge exact message identities without losing source references."""
    merged = {}
    for relative in sorted(paths):
        path = root / relative
        for message in extract_file(path, root):
            key = (message["context"], message["source"])
            if key not in merged:
                merged[key] = {**message, "references": []}
                del merged[key]["reference"]
            elif merged[key]["plural"] != message["plural"]:
                raise ExtractionError("conflicting plural source: " + message["context"])
            merged[key]["references"].append(message["reference"])
    return [merged[key] for key in sorted(merged)]


def po_quote(text):
    """Encode one gettext string without interpreting catalog contents."""
    return json.dumps(text, ensure_ascii=False)


def pot(messages):
    """Serialize the deterministic English gettext template."""
    lines = [
        "# SGN internationalization source catalog. Generated; do not edit.",
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: SGN i18n prototype 1\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        "",
    ]
    for message in messages:
        lines.append("#: " + " ".join(sorted(set(message["references"]))))
        lines += [
            "msgctxt " + po_quote(message["context"]),
            "msgid " + po_quote(message["source"]),
        ]
        if message["plural"]:
            lines += [
                "msgid_plural " + po_quote(message["plural"]),
                'msgstr[0] ""',
                'msgstr[1] ""',
            ]
        else:
            lines.append('msgstr ""')
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"
