#!/usr/bin/env python3
"""Prepare editable gettext workspaces and package saved translations."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path

import catalog
from catalog_format import MAX_RELEASE_BYTES, json_bytes, read_json

TOOLS = Path(__file__).resolve().parent
OPERATOR_FILES = ("sgn-i18n", "pack.py", "catalog_format.py", "plural.py")


def unused_output(output):
    """Reject an occupied destination before running any expensive source tools."""
    output = output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError("Output already exists; choose a new folder: " + str(output))
    return output


@contextmanager
def staged_output(output):
    """Keep failed output private and never replace an existing workspace."""
    output = unused_output(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(dir=output.parent, prefix=".sgn-i18n-"))
    try:
        yield stage
        if output.exists() or output.is_symlink():
            raise ValueError("Output appeared while preparing; choose a new folder: " + str(output))
        stage.rename(output)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def regular_workspace_file(workspace, path):
    """Never edit or package a symlink to another person's original file."""
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(workspace):
        raise ValueError("Expected a regular file inside the workspace: " + str(path))
    return path


def load_workspace(path):
    """Validate the standard frozen inputs without invoking a source parser."""
    workspace = path.resolve(strict=True)
    if not workspace.is_dir():
        raise ValueError("Workspace is not a folder: " + str(path))
    release_path = regular_workspace_file(workspace, workspace / "release.json")
    release = catalog.validate_release(read_json(release_path, limit=MAX_RELEASE_BYTES))
    template = regular_workspace_file(workspace, workspace / "release.pot")
    if template.stat().st_size > MAX_RELEASE_BYTES or template.read_text(encoding="utf-8") != catalog.pot(
        release["messages"]
    ):
        raise ValueError("release.pot does not match release.json; obtain the original release files")
    return workspace, release


def po_inputs(paths):
    """Use validated PO metadata for locale names, independently of filenames."""
    result = {}
    for path in paths:
        if not path.is_file():
            raise ValueError("PO file does not exist: " + str(path))
        locale = catalog.compile_partition(path, [])["locale"]
        if locale in result:
            raise ValueError("More than one PO has Language " + locale)
        result[locale] = path
    if not result:
        raise ValueError("No PO files selected; provide --po or use source locale catalogs")
    return result


def notice_files(base, source_mode=False):
    """Preserve available attribution without inventing a new notice format."""
    result = {}
    notices = base / "notices"
    if notices.is_symlink():
        raise ValueError("Notices must be regular files, not symlinks")
    if notices.is_dir():
        for path in notices.rglob("*"):
            if path.is_symlink():
                raise ValueError("Notices must be regular files, not symlinks")
            if path.is_file():
                result[path.relative_to(notices)] = path
    parents = (base, base / "locale") if source_mode else (base,)
    for parent in parents:
        for pattern in ("LICENSE*", "COPYING*", "NOTICE*", "TRANSLATION_SOURCES.md"):
            for path in parent.glob(pattern):
                if path.is_symlink():
                    raise ValueError("Notices must be regular files, not symlinks")
                if path.is_file():
                    name = Path("locale") / path.name if parent != base else Path(path.name)
                    result.setdefault(name, path)
    attribution = base / "docs/i18n/TRANSLATION_SOURCES.md"
    if source_mode and attribution.is_file() and not attribution.is_symlink():
        result[Path("TRANSLATION_SOURCES.md")] = attribution
    return result


def copy_notices(notices, destination):
    """Copy already identified notice files before publishing an output folder."""
    for name, source in notices.items():
        target = destination / "notices" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def copy_tools(destination, operator=False):
    """Ship the matching Python files, without Node or parser dependencies."""
    names = OPERATOR_FILES if operator else tuple(p.name for p in sorted(TOOLS.glob("*.py"))) + ("sgn-i18n",)
    destination.mkdir(parents=True)
    for name in names:
        shutil.copyfile(TOOLS / name, destination / name)


def run_gettext_merge(source, template, output):
    """Merge only a copied translation, preserving the supplied original bytes."""
    result = subprocess.run(
        ["msgmerge", "--quiet", "--no-wrap", "--output-file", str(output), str(source), str(template)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=30,
        check=False,
    )
    if result.returncode:
        raise ValueError("Cannot update the copied PO: " + result.stderr.strip())


def prepare_translation(source, template, output, release):
    """Merge and label one editable copy while retaining original notices and sources."""
    run_gettext_merge(source, template, output)
    entries = catalog.partition_po_entries(output)
    for entry in entries:
        if entry["header"]:
            entry["text"] = catalog.editable_po_header(
                entry["text"], release["sourceRevision"], "SGN " + release["applicationVersion"]
            )
    output.write_text("\n\n".join(entry["text"] for entry in entries) + "\n", encoding="utf-8")


def prepare(args):
    """Extract once and publish an editable copy, without modifying originals."""
    unused_output(args.output)
    if args.release:
        if not args.po:
            raise ValueError("Frozen prepare needs at least one --po file")
        release = catalog.validate_release(read_json(args.release, limit=MAX_RELEASE_BYTES))
        paths = [path.absolute() for path in args.po]
        notices = notice_files(args.release.resolve().parent)
    else:
        root = args.root.resolve()
        messages = catalog.source_messages(root)
        release = catalog.freeze_release(root, messages, args.application_version)
        paths = (
            [path.absolute() for path in args.po] if args.po else sorted((root / "locale").glob("*/LC_MESSAGES/sgn.po"))
        )
        notices = notice_files(root, source_mode=True)
    translations = po_inputs(paths)
    data = json_bytes(release)
    if len(data) > MAX_RELEASE_BYTES:
        raise ValueError("Release snapshot exceeds size limit")
    with staged_output(args.output) as stage:
        (stage / "release.json").write_bytes(data)
        template = stage / "release.pot"
        template.write_text(catalog.pot(release["messages"]), encoding="utf-8")
        target = stage / "translations"
        target.mkdir()
        for locale, source in translations.items():
            prepare_translation(source, template, target / (locale + ".po"), release)
        copy_tools(stage / "tools")
        copy_notices(notices, stage)
        example = "uk" if "uk" in translations else sorted(translations)[0]
        (stage / "README.md").write_text(
            f"""# Edit these translations

## Translator: open, edit and save

Install Poedit from https://poedit.com/download/ on your computer once.
In Poedit, choose File -> Open and select translations/{example}.po.
The Source text is English. Edit the Translation field and fill every plural form.
Keep named values such as %{{name}} unchanged. Mark uncertain text Needs Work.
Save, then return this whole folder to the release builder.

Editing needs no SGN, Python or translation server. Saving does not update a site.
Have a native speaker and a breeder review the wording before use.

## Builder: make the ready folder

Use Linux/POSIX, Python 3.9 or newer and GNU gettext (msgcat, msgfmt, msgmerge).
Open a terminal in this workspace folder, then run:

```sh
python3 tools/sgn-i18n package --workspace . --output ../ready-language-packs-v1
```

The new sibling ready-language-packs-v1 folder contains the language packs,
operator tools, installation instructions and exact release/PO copies used.
Existing output folders are refused; use ready-language-packs-v2 for a correction.
Give the whole ready folder to the administrator. Packaging does not activate it.

Keep release.json, release.pot, tools and notices with the translations.
Original source PO/POT files were not edited to make this workspace.
""",
            encoding="utf-8",
        )
    return {
        "workspace": str(args.output.absolute()),
        "locales": sorted(translations),
        "sourceRevision": release["sourceRevision"],
    }


def ready_notes(example):
    """Render the three ordinary operator actions for a validated locale tag."""
    return f"""# Install a language

## Before you start

The matching SGN application must already be installed. Use its server account
on a Linux/POSIX server with Python 3.9 or newer. Ready packs need no Node, Perl,
R or GNU gettext. The account needs write access to /srv/sgn-languages.
In Docker, its user ID must be able to read these mounted files inside the container.
Keep this whole ready folder together.

## 1. Install and select the pack

Open a terminal in this ready folder. Run both commands:

```sh
READY_DIR="$PWD"
python3 "$READY_DIR/operator-tools/sgn-i18n" install --activate \\
  --pack "$READY_DIR/{example}-pack" --root /srv/sgn-languages
```

The tool checks the files and reads the language/hash itself. A local receipt
does not mean the running site has applied the configuration. Keep this terminal
open: READY_DIR remembers the ready folder for the later commands.

## 2. Apply site settings once

The administrator edits the configuration used by the running site, usually
sgn_local.conf:

```text
i18n_enabled 1
i18n_enabled_locales en,{example}
i18n_catalog_dir /srv/sgn-languages/active
```

This enables translations, allows the listed languages and points SGN at the
selected files. Keep the final /active. For Docker, add this line to the web
service's existing volumes list without removing its other volumes:

```yaml
- /srv/sgn-languages:/srv/sgn-languages:ro
```

From the site's Compose project folder, find the web service and recreate it:

```sh
docker compose config --services
docker compose up -d --no-deps YOUR_SGN_SERVICE
```

Replace YOUR_SGN_SERVICE with the web service name. Keep the site's usual -f and
-p options on both commands. Restart alone does not add a new volume.
Without Docker, use the site's normal SGN restart command.

## 3. Check the result

In the same terminal, check the selected and previous files:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" doctor \\
  --root /srv/sgn-languages --locale {example}
```

To check the site's language resources too, replace YOUR_SITE_URL with its root
URL, for example https://example.org:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" doctor \\
  --root /srv/sgn-languages --locale {example} --site YOUR_SITE_URL
```

Doctor is read-only. Its site check reads resource headers; it does not prove
every screen or the exact remote pack version. Open a new page, choose the
language in the header and click the button beside the list. Check that messages
change and trial/accession names stay the same. Translations need human review.

## Update or undo

For an update, repeat step 1 from the new ready folder, including READY_DIR.
Open a new page. Existing settings and the whole-folder mount need no restart.
To undo the last activation:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" rollback \\
  --root /srv/sgn-languages --locale {example}
```

This selects the previous pack, or English fallback after the first activation.
To disable translations for the site, set i18n_enabled 0 and restart SGN.
In a new terminal, open the ready folder and set READY_DIR="$PWD" again.

Release files, saved PO copies and notices record the exact inputs used for
these packs. Edit the separate workspace to prepare the next version.
"""


def snapshot_inputs(workspace, release, stage):
    """Compile and ship exactly the same saved inputs even if the editor saves again."""
    paths = [regular_workspace_file(workspace, path) for path in sorted((workspace / "translations").glob("*.po"))]
    incoming = stage / ".inputs"
    incoming.mkdir()
    for index, source in enumerate(paths):
        shutil.copyfile(source, incoming / (str(index) + ".po"))
    snapshots = po_inputs(sorted(incoming.glob("*.po")))
    target = stage / "translations"
    target.mkdir()
    translations = {}
    for locale, source in snapshots.items():
        destination = target / (locale + ".po")
        source.rename(destination)
        translations[locale] = destination
    incoming.rmdir()
    shutil.copyfile(workspace / "release.json", stage / "release.json")
    if catalog.validate_release(read_json(stage / "release.json", limit=MAX_RELEASE_BYTES)) != release:
        raise ValueError("Release changed while packaging; retry with the saved workspace")
    (stage / "release.pot").write_text(catalog.pot(release["messages"]), encoding="utf-8")
    return translations


def build_saved_inputs(translations, release_path, output):
    """Run the current trusted compiler against staged copies, without source parsers."""
    command = [
        sys.executable,
        str(TOOLS / "catalog.py"),
        "build",
        "--release",
        str(release_path),
        "--output",
        str(output),
    ]
    for path in translations.values():
        command.extend(["--po", str(path)])
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", timeout=300, check=False)
    if result.returncode:
        raise ValueError("Cannot build the saved translations: " + result.stderr.strip())
    return json.loads(result.stdout)


def package(args):
    """Build all saved translations and publish a complete ready bundle, never a site."""
    unused_output(args.output)
    if os.name != "posix":
        raise ValueError("Build ready packs on the Linux/POSIX release builder; edit the PO in Poedit on your computer")
    # The editor route remains usable without this POSIX-only dependency.
    import pack  # pylint: disable=import-outside-toplevel

    workspace, release = load_workspace(args.workspace)
    notices = notice_files(workspace)
    with staged_output(args.output) as stage:
        translations = snapshot_inputs(workspace, release, stage)
        build = stage / ".build"
        build_receipt = build_saved_inputs(translations, stage / "release.json", build)
        receipts = []
        for locale in sorted(translations):
            manifest = pack.create_pack(build / locale / "sgn/index.json", stage / (locale + "-pack"))
            receipts.append({"locale": locale, "hash": manifest["catalogSha256"], "pack": locale + "-pack"})
        shutil.rmtree(build)
        copy_tools(stage / "operator-tools", operator=True)
        copy_notices(notices, stage)
        (stage / "README.md").write_text(
            ready_notes("uk" if "uk" in translations else sorted(translations)[0]), encoding="utf-8"
        )
    return {
        "output": str(args.output.absolute()),
        "sourceRevision": release["sourceRevision"],
        "coverage": build_receipt["coverage"],
        "packages": receipts,
    }


def main():
    """Prepare copied PO files or build their saved translations into ready packs."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("prepare", help="make a separate editable release workspace")
    command.add_argument("--output", type=Path, required=True)
    source = command.add_mutually_exclusive_group(required=True)
    source.add_argument("--application-version")
    source.add_argument("--release", type=Path)
    command.add_argument("--root", type=Path, default=Path.cwd())
    command.add_argument("--po", type=Path, action="append")
    command = commands.add_parser("package", help="make ready packs from saved workspace translations")
    command.add_argument("--workspace", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"prepare": prepare, "package": package}[args.command](args)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
        print("Translation workspace: " + str(error), file=sys.stderr)
        raise SystemExit(1) from error
