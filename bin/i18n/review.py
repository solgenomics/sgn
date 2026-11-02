#!/usr/bin/env python3
"""Export one frozen workflow into a separate gettext review workspace."""
import argparse
from pathlib import Path

from catalog import partition_po_entries, read_unique_json, validate_release


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
    release = validate_release(read_unique_json(args.release))
    if args.workflow not in release["partitions"]:
        raise ValueError("unknown workflow; choose: " + ", ".join(release["partitions"]))
    if args.output.exists():
        raise ValueError("refusing to overwrite an existing review workspace")
    all_messages = [release["messages"][index] for index in release["partitions"][args.workflow]]
    if not 1 <= args.limit <= 500 or not 0 <= args.offset < len(all_messages):
        raise ValueError("review requires an existing offset and a batch limit from 1 to 500")
    messages = all_messages[args.offset : args.offset + args.limit]
    contexts = {message["context"] for message in messages}
    entries = partition_po_entries(args.po)
    selected = [block for context, header, block in entries if header or context in contexts]
    args.output.mkdir(parents=True)
    (args.output / "review.po").write_text("\n\n".join(selected) + "\n", encoding="utf-8")
    next_offset = args.offset + len(messages)
    next_batch = (
        "Next batch: --offset " + str(next_offset) + " --limit " + str(args.limit)
        if next_offset < len(all_messages)
        else "Last batch in this workflow"
    )
    (args.output / "REVIEW.md").write_text(
        "# Translation review: "
        + args.workflow
        + "\n\n"
        + "Application version: "
        + release["applicationVersion"]
        + "\n\n"
        + "Source revision: "
        + release["sourceRevision"]
        + "\n\n"
        + str(len(messages))
        + " of "
        + str(len(all_messages))
        + " source messages, starting at offset "
        + str(args.offset)
        + ". "
        + next_batch
        + ". Filled text may be machine-generated; "
        + "export does not certify human review. Keep the original PO intact.\n\n"
        + "| English term | Meaning in this workflow | Approved wording | Reviewer |\n"
        + "|---|---|---|---|\n"
        + "| accession | Germplasm record | | |\n| trial | Breeding experiment | | |\n"
        + "| plot | Experimental field unit | | |\n| seedlot | Physical seed batch | | |\n",
        encoding="utf-8",
    )
    print(str(args.output / "review.po"))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from error
