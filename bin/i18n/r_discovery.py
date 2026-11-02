"""Trusted R AST literal discovery; no message compilation or source execution."""

import hashlib
import json
import os
import subprocess
from pathlib import Path

from extraction_error import ExtractionError


# Exact JSON scalar checks must reject bool and custom subclasses.
# pylint: disable=duplicate-code,too-many-boolean-expressions,too-many-branches,unidiomatic-typecheck
def discover_r(files):
    """Batch source-as-data through the qualified parser; errors never mean zero."""
    configured = os.environ.get("SGN_I18N_R_DISCOVERY_COMMAND")
    if configured:
        try:
            command = json.loads(configured)
        except ValueError as error:
            raise ExtractionError("SGN_I18N_R_DISCOVERY_COMMAND must be a JSON argv array") from error
        if (
            not isinstance(command, list)
            or not command
            or any(not isinstance(arg, str) or not arg or "\x00" in arg for arg in command)
        ):
            raise ExtractionError("SGN_I18N_R_DISCOVERY_COMMAND must be a nonempty JSON argv array")
    else:
        command = [
            "Rscript",
            "--vanilla",
            str(Path(__file__).with_name("r_discover.R")),
        ]
    if not isinstance(files, list) or len(files) > 256:
        raise ExtractionError("R discovery requires a bounded file list")
    names = []
    for file in files:
        if (
            not isinstance(file, dict)
            or not isinstance(file.get("file"), str)
            or not file["file"]
            or not isinstance(file.get("source"), str)
            or len(file["source"].encode("utf-8")) > 2 * 1024 * 1024
        ):
            raise ExtractionError("Invalid R discovery source record")
        names.append(file["file"])
    if len(set(names)) != len(names):
        raise ExtractionError("Duplicate R discovery file identity")
    try:
        run = subprocess.run(
            command,
            input=json.dumps({"schema": 1, "files": files}, ensure_ascii=False),
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=60,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ExtractionError(
            "R discovery unavailable; configure qualified task-local SGN_I18N_R_DISCOVERY_COMMAND"
        ) from error
    if run.returncode:
        # A parser/library warning can echo source. No raw stderr is report data.
        raise ExtractionError("R discovery helper failed; inspect only sanitized tool diagnostics")
    try:
        result = json.loads(run.stdout)
    except ValueError as error:
        raise ExtractionError("R discovery helper returned invalid JSON") from error
    if (
        not isinstance(result, dict)
        or type(result.get("schema")) is not int
        or result["schema"] != 1
        or result.get("parser") != "R parseData"
        or (result.get("parserVersion"), result.get("jsonVersion")) not in {("4.5.0", "2.0.0"), ("4.5.1", "1.8.7")}
        or not isinstance(result.get("files"), list)
        or len(result["files"]) != len(files)
    ):
        raise ExtractionError("R discovery helper returned an incompatible protocol")
    mapped = {}
    for row in result["files"]:
        if (
            not isinstance(row, dict)
            or row.get("file") not in names
            or row["file"] in mapped
            or type(row.get("ok")) is not bool
            or not isinstance(row.get("records"), list)
        ):
            raise ExtractionError("R discovery helper returned invalid file records")
        if not row["ok"] and (
            row["records"] or row.get("error") not in ("R parser rejected source syntax", "R parse-data limit exceeded")
        ):
            raise ExtractionError("R discovery helper returned an invalid parse failure")
        source = files[names.index(row["file"])]["source"]
        for field in ("errorLine", "errorColumn"):
            if row.get(field) is not None and (
                type(row[field]) is not int or row[field] < (1 if field == "errorLine" else 0)
            ):
                raise ExtractionError("R discovery helper returned an invalid error location")
        row["sourceSha256"] = hashlib.sha256(source.encode("utf-8")).hexdigest()
        row["parserVersion"] = result["parserVersion"]
        for record in row["records"]:
            if (
                not isinstance(record, dict)
                or type(record.get("line")) is not int
                or record["line"] < 1
                or type(record.get("column")) is not int
                or record["column"] < 1
                or type(record.get("sensitiveAssignment")) is not bool
            ):
                raise ExtractionError("R discovery helper returned invalid token locations")
            if record["sensitiveAssignment"]:
                if record.get("value") is not None or record.get("protectionReason") not in (
                    "sensitive_assignment",
                    "sensitive_named_argument",
                    "external_credential_call_review",
                    "sensitive_context_depth_review",
                ):
                    raise ExtractionError("R discovery helper exposed a sensitive assignment")
            elif not isinstance(record.get("value"), str):
                raise ExtractionError("R discovery helper returned nonliteral data")
            source_position(source, record["line"], record["column"])
        mapped[row["file"]] = row
    return mapped


# pylint: enable=duplicate-code,too-many-boolean-expressions,too-many-branches,unidiomatic-typecheck


def source_position(source, line, r_column):
    """R parseData counts Unicode points and expands tabs to eight-column stops."""
    # R source lines advance on LF. Unicode separators inside a literal are
    # characters, not additional parseData source lines. Preserve CRLF bytes.
    pieces = source.split("\n")
    lines = [part + ("\n" if index < len(pieces) - 1 else "") for index, part in enumerate(pieces)]
    if not 1 <= line <= len(lines):
        raise ExtractionError("R discovery source line is outside the source")
    column = 1
    for index, character in enumerate(lines[line - 1]):
        if column == r_column:
            return sum(map(len, lines[: line - 1])) + index
        if character in "\r\n":
            break
        column = column + (8 - (column - 1) % 8) if character == "\t" else column + 1
    raise ExtractionError("R discovery source column is outside the source")
