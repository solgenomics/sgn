#!/usr/bin/env python3
"""Export one frozen workflow into a separate gettext review workspace."""

import argparse
from pathlib import Path

from catalog import partition_po_entries, validate_release
from catalog_format import MAX_RELEASE_BYTES, read_json


def main():
    """Preserve the original PO and export whole messages with their context."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["review"])
    parser.add_argument("--release", type=Path, required=True)
    parser.add_argument("--po", type=Path, required=True)
    parser.add_argument("--workflow", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()
    release = validate_release(read_json(args.release, limit=MAX_RELEASE_BYTES))
    if args.workflow not in release["partitions"]:
        raise ValueError("unknown workflow; choose: " + ", ".join(release["partitions"]))
    if args.output.exists():
        raise ValueError("refusing to overwrite an existing review workspace")
    all_messages = [release["messages"][index] for index in release["partitions"][args.workflow]]
    if not 1 <= args.limit <= 500 or not 0 <= args.offset < len(all_messages):
        raise ValueError("review requires an existing offset and a batch limit from 1 to 500")
    messages = all_messages[args.offset : args.offset + args.limit]
    identities = {(m["context"], m["source"], m["plural"]) for m in messages}
    entries = partition_po_entries(args.po)
    selected = [
        entry["text"]
        for entry in entries
        if entry["header"] or (entry["context"], entry["source"], entry["plural"]) in identities
    ]
    found = {(entry["context"], entry["source"], entry["plural"]) for entry in entries}
    if not identities <= found:
        raise ValueError("PO is missing selected messages; merge the release POT first")
    args.output.mkdir(parents=True)
    (args.output / "review.po").write_text("\n\n".join(selected) + "\n", encoding="utf-8")
    next_offset = args.offset + len(messages)
    next_batch = (
        "Next batch: --offset " + str(next_offset) + " --limit " + str(args.limit)
        if next_offset < len(all_messages)
        else "Last batch in this workflow"
    )
    report = f"""# Translation review: {args.workflow}

Application version: {release["applicationVersion"]}

Source revision: {release["sourceRevision"]}

{len(messages)} of {len(all_messages)} source messages, starting at offset {args.offset}.
{next_batch}. Filled text may be machine-generated; export does not certify human
review. Keep the original PO intact.

| English term | Meaning in this workflow | Approved wording | Reviewer |
|---|---|---|---|
| accession | Germplasm record | | |
| trial | Breeding experiment | | |
| plot | Experimental field unit | | |
| seedlot | Physical seed batch | | |
"""
    (args.output / "REVIEW.md").write_text(report, encoding="utf-8")
    print(str(args.output / "review.po"))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from error
