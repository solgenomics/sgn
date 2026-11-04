"""Data-only language catalog rules shared by builders and site operators."""

import hashlib
import json
import re

SCHEMA = API = 1
LOCALE = re.compile(r"^[a-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$")
PLACEHOLDER = re.compile(r"%\{([A-Za-z][A-Za-z0-9_]*)\}")
MAX_BYTES = 2 * 1024 * 1024
MAX_PO_BYTES = 4 * 1024 * 1024
MAX_RELEASE_BYTES = 32 * 1024 * 1024


def json_bytes(value):
    """Serialize canonical UTF-8 JSON for fingerprints and files."""
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n"
    ).encode("utf-8")


def sha256_hex(data):
    """Return the SHA-256 hex fingerprint of supplied bytes."""
    return hashlib.sha256(data).hexdigest()


def read_json(path, limit=MAX_BYTES):
    """Read bounded UTF-8 JSON, rejecting duplicate keys and non-JSON numbers."""
    if path.is_symlink() or not path.is_file():
        raise ValueError("unsafe JSON input file")
    with path.open("rb") as source:
        data = source.read(limit + 1)
    if len(data) > limit:
        raise ValueError("JSON input exceeds size limit")

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    def invalid_number(value):
        raise ValueError("invalid JSON number: " + value)

    return json.loads(data.decode("utf-8"), object_pairs_hook=unique, parse_constant=invalid_number)


def validate_language_name(value):
    """Native names are Unicode display text, never markup or identifiers."""
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 200
        or any(ord(c) < 32 or 0x7F <= ord(c) <= 0x9F or c in "\u2028\u2029" for c in value)
    ):
        raise ValueError("invalid native language name")
    return value


def placeholders(text):
    """Collect complete named values and reject malformed placeholders."""
    result = set(PLACEHOLDER.findall(text))
    if "%{" in PLACEHOLDER.sub("", text):
        raise ValueError("invalid named placeholder")
    return result


def validate_control_placeholders(context, source, forms):
    """A native interactive selector must occur exactly once."""
    if (context, source) in {
        ("file_list.datatable.length_menu", "Show %{menu} entries"),
        ("odk.table.length", "Show %{menu} entries"),
    }:
        if any(PLACEHOLDER.findall(text).count("menu") != 1 or "_MENU_" in text for text in forms):
            raise ValueError(context + " must contain exactly one %{menu} control placeholder")
