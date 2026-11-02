#!/usr/bin/env python3
"""Create, validate, install and atomically select data-only translation packs."""

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import tempfile
from pathlib import Path

from catalog import (
    API,
    LOCALE,
    MAX_BYTES,
    SCHEMA,
    json_bytes,
    placeholders,
    validate_control_placeholders,
    validate_language_name,
)
from plural import parse_plural, validate_ast

HASH = re.compile(r"[a-f0-9]{64}")
PART = re.compile(r"[a-z][a-z0-9_]*")


def sha(data):
    """Return a byte-identity SHA-256 fingerprint."""
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    """Decode bounded regular JSON and reject duplicate object fields."""
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
        raise ValueError("unsafe input file")

    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)


def validate_catalog(catalog):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=unidiomatic-typecheck,too-many-branches
    """Validate metadata, plural proof, variables and complete message forms."""
    if (
        not isinstance(catalog, dict)
        or type(catalog.get("schema")) is not int
        or type(catalog.get("api")) is not int
        or catalog.get("schema") != SCHEMA
        or catalog.get("api") != API
    ):
        raise ValueError("unsupported catalog schema or API")
    if "languageName" in catalog:
        validate_language_name(catalog["languageName"])
    locale = catalog.get("locale", "")
    if not isinstance(locale, str) or not LOCALE.fullmatch(locale) or locale == "en":
        raise ValueError("invalid catalog locale")
    if (
        catalog.get("direction") not in ("ltr", "rtl")
        or not isinstance(catalog.get("sourceRevision"), str)
        or not HASH.fullmatch(catalog["sourceRevision"])
    ):
        raise ValueError("invalid direction or source revision")
    if type(catalog.get("nplurals")) is not int or not 1 <= catalog["nplurals"] <= 6:
        raise ValueError("invalid plural count")
    validate_ast(catalog.get("pluralAst"))
    rule = parse_plural(catalog.get("pluralForms"))
    if catalog["nplurals"] != rule["nplurals"] or catalog["pluralAst"] != rule["ast"]:
        raise ValueError("plural formula and AST mismatch")
    messages = catalog.get("messages")
    if not isinstance(messages, dict) or len(messages) > 20000:
        raise ValueError("invalid messages")
    for key, value in messages.items():
        if not isinstance(key, str) or key.count("\x04") != 1 or "\x00" in key or not key.split("\x04", 1)[1]:
            raise ValueError("invalid message key")
        if not isinstance(value, dict) or set(value) != {"plural", "forms"}:
            raise ValueError("invalid message record")
        plural = value["plural"]
        if plural is not None and (not isinstance(plural, str) or not plural.strip()):
            raise ValueError("invalid plural source")
        forms = value["forms"]
        if not isinstance(forms, list) or len(forms) != (catalog["nplurals"] if plural else 1):
            raise ValueError("incomplete translation record")
        variables = placeholders(key.split("\x04", 1)[1])
        if plural and placeholders(plural) != variables:
            raise ValueError("plural placeholder mismatch")
        if any(
            not isinstance(text, str) or not text.strip() or "\x00" in text or placeholders(text) != variables
            for text in forms
        ):
            raise ValueError("invalid translation or placeholder mismatch")
        context, source = key.split("\x04", 1)
        validate_control_placeholders(context, source, forms)
    return catalog


def indexed_data(directory):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=unidiomatic-typecheck,too-many-boolean-expressions
    """Validate a complete native index and every bounded, checksum-bound part."""
    index = read_json(directory / "index.json")
    if (
        not isinstance(index, dict)
        or set(index) != {"schema", "domain", "sourceRevision", "partitions"}
        or type(index["schema"]) is not int
        or index["schema"] != 1
        or index["domain"] != "sgn"
        or not isinstance(index["sourceRevision"], str)
        or not HASH.fullmatch(index["sourceRevision"])
    ):
        raise ValueError("invalid partition index")
    parts = index["partitions"]
    if not isinstance(parts, list) or not 1 <= len(parts) <= 64:
        raise ValueError("invalid partition count")
    files = {"index.json": sha((directory / "index.json").read_bytes())}
    catalogs = []
    messages = {}
    for part in parts:
        if (
            not isinstance(part, dict)
            or set(part) != {"name", "sha256"}
            or not isinstance(part["name"], str)
            or not PART.fullmatch(part["name"])
            or not isinstance(part["sha256"], str)
            or not HASH.fullmatch(part["sha256"])
        ):
            raise ValueError("invalid partition identity")
        name = part["name"] + ".json"
        if name in files:
            raise ValueError("duplicate partition")
        catalog = validate_catalog(read_json(directory / name))
        checksum = sha((directory / name).read_bytes())
        if checksum != part["sha256"]:
            raise ValueError("partition checksum mismatch")
        files[name] = checksum
        catalogs.append(catalog)
        for key, message in catalog["messages"].items():
            if key in messages and messages[key] != message:
                raise ValueError("conflicting translation across partitions")
            messages[key] = message
    if "common.json" not in files:
        raise ValueError("indexed catalog requires the common partition")
    first = catalogs[0]
    metadata = ("locale", "direction", "nplurals", "pluralForms", "pluralAst", "languageName")
    if any(any(catalog.get(field) != first.get(field) for field in metadata) for catalog in catalogs):
        raise ValueError("partition language metadata mismatch")
    return index, first, files


def manifest_for(directory, indexed=False):
    """Bind the published identity to every supplied runtime byte."""
    if indexed:
        index, catalog, files = indexed_data(directory)
        return {
            "schema": SCHEMA,
            "api": API,
            "locale": catalog["locale"],
            "direction": catalog["direction"],
            "domain": "sgn",
            "sourceRevision": index["sourceRevision"],
            "format": "indexed",
            "files": files,
            "catalogSha256": sha(json_bytes(files)),
        }
    catalog = validate_catalog(read_json(directory / "catalog.json"))
    return {
        "schema": SCHEMA,
        "api": API,
        "locale": catalog["locale"],
        "direction": catalog["direction"],
        "domain": "sgn",
        "sourceRevision": catalog["sourceRevision"],
        "catalogSha256": sha((directory / "catalog.json").read_bytes()),
    }


def validate_pack(directory):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=unidiomatic-typecheck
    """Accept legacy single catalogs and complete native indexed packages."""
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("unsafe pack directory")
    manifest = read_json(directory / "manifest.json")
    if (
        not isinstance(manifest, dict)
        or type(manifest.get("schema")) is not int
        or type(manifest.get("api")) is not int
    ):
        raise ValueError("manifest schema and API must be integer versions")
    indexed = manifest.get("format") == "indexed"
    expected = manifest_for(directory, indexed)
    names = {"manifest.json", *(expected["files"] if indexed else ["catalog.json"])}
    if {p.name for p in directory.iterdir()} != names or manifest != expected:
        raise ValueError("pack manifest or catalog checksum mismatch")
    catalog = validate_catalog(read_json(directory / ("common.json" if indexed else "catalog.json")))
    return manifest, catalog


def atomic_json(path, value):
    """Write a complete fsynced JSON file before renaming it into place."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".i18n-", delete=False) as handle:
        name = handle.name
        handle.write(json_bytes(value))
        handle.flush()
        os.fsync(handle.fileno())
    try:
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def atomic_link(path, target, replace_file=False):
    """Replace one selector symlink after the complete generation exists."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not path.is_symlink() and not replace_file:
        raise ValueError("refusing to replace a non-symlink active catalog")
    temporary = path.parent / (".i18n-link-" + str(os.getpid()))
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def target_of(link, root):
    """Resolve a legacy active catalog only inside this installation store."""
    if not link.is_symlink():
        if link.exists():
            raise ValueError("active catalog is not a selector symlink")
        return None
    target = link.resolve(strict=True)
    if not target.is_relative_to(root / "installed"):
        raise ValueError("active catalog escapes task-local store")
    return target


def checked_target(root, locale, target):
    """Check an activation/history target against its locale and published hash."""
    if target is None:
        return None
    if not isinstance(target, str):
        raise ValueError("invalid activation target")
    match = re.fullmatch(r"installed/([a-z]{2,8}(?:-[A-Za-z0-9]{2,8})*)/([a-f0-9]{64})/(catalog|index)\.json", target)
    if not match or match[1] != locale:
        raise ValueError("activation target escapes locale store")
    path = root / target
    if path.is_symlink() or path.resolve(strict=True) != path:
        raise ValueError("unsafe activation target")
    manifest, _ = validate_pack(path.parent)
    if (
        manifest["locale"] != locale
        or manifest["catalogSha256"] != match[2]
        or (match[3] == "index") != (manifest.get("format") == "indexed")
    ):
        raise ValueError("installed pack identity mismatch")
    return path


def validate_history(history, locale):
    """Validate bounded history structure without loading inactive translations."""
    if not isinstance(history, list) or len(history) > 10000 or len(json_bytes(history)) > MAX_BYTES:
        raise ValueError("invalid activation history")
    pattern = r"installed/" + re.escape(locale) + r"/[a-f0-9]{64}/(?:catalog|index)\.json"
    previous = None
    for entry in history:
        if not isinstance(entry, dict) or set(entry) != {"before", "after"}:
            raise ValueError("invalid activation history entry")
        if entry["before"] is not None and (
            not isinstance(entry["before"], str) or not re.fullmatch(pattern, entry["before"])
        ):
            raise ValueError("invalid history target")
        if not isinstance(entry["after"], str) or not re.fullmatch(pattern, entry["after"]):
            raise ValueError("invalid history target")
        if previous is not None and entry["before"] != previous:
            raise ValueError("discontinuous activation history")
        previous = entry["after"]
    return history


def recover_migration(root, locale):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=unidiomatic-typecheck,too-many-boolean-expressions,too-many-branches,too-many-statements
    """Reconcile only an explicitly journaled interrupted store migration.

    A missing selector alone never authorizes restoring a historic directory.
    The marker, paths and old state must all agree before recovery changes data.
    """
    marker = root / "migrations" / (locale + ".json")
    if not marker.exists() and not marker.is_symlink():
        return
    migration = read_json(marker)
    if (
        not isinstance(migration, dict)
        or set(migration) != {"schema", "locale", "mode", "generation"}
        or type(migration["schema"]) is not int
        or migration["schema"] != 1
        or migration["locale"] != locale
        or migration["mode"] not in ("initial", "legacy")
    ):
        raise ValueError("invalid migration journal")
    relative = migration["generation"]
    if not isinstance(relative, str) or not re.fullmatch(
        r"state/" + re.escape(locale) + r"/generation-[A-Za-z0-9_-]+", relative
    ):
        raise ValueError("migration generation escapes locale state store")
    generation = root / relative
    if generation.resolve() != generation:
        raise ValueError("unsafe migration generation")
    active = root / "active" / locale
    legacy = root / "legacy-active" / locale
    history_view = root / "history" / (locale + ".json")
    wanted = str(Path("../active") / locale / ".history.json")
    if active.is_symlink():
        if active.resolve(strict=True) != generation:
            raise ValueError("migration journal disagrees with active selector")
        # The commit happened before process interruption; its generation is
        # authoritative. Normal read_state validates both metadata and history.
        marker.unlink()
        return
    if migration["mode"] == "initial":
        if active.exists():
            raise ValueError("unexpected state during initial activation recovery")
        if history_view.exists() and not history_view.is_symlink() and read_json(history_view) != []:
            raise ValueError("unexpected history during initial activation recovery")
        if history_view.is_symlink():
            if os.readlink(history_view) != wanted:
                raise ValueError("unexpected history view selector")
            history_view.unlink()
        marker.unlink()
        if generation.is_dir() and not generation.is_symlink():
            shutil.rmtree(generation, ignore_errors=True)
        return
    directory = active if active.exists() else legacy
    if directory.is_symlink() or not directory.is_dir() or directory.resolve(strict=True) != directory:
        raise ValueError("no safe legacy directory for migration recovery")
    if active.exists() and legacy.exists():
        raise ValueError("conflicting legacy migration directories")
    state = read_json(directory / ".state.json")
    if (
        not isinstance(state, dict)
        or set(state) != {"schema", "locale", "current"}
        or type(state["schema"]) is not int
        or state["schema"] != 1
        or state["locale"] != locale
    ):
        raise ValueError("invalid legacy migration state")
    history = validate_history(read_json(directory / ".history.json"), locale)
    target = target_of(directory / "sgn.json", root)
    current = str(target.relative_to(root)) if target else None
    if state["current"] != current or (history[-1]["after"] if history else None) != current:
        raise ValueError("legacy migration state and history disagree")
    checked_target(root, locale, current)
    if history_view.is_symlink():
        if os.readlink(history_view) != wanted:
            raise ValueError("unexpected history view selector")
    elif history_view.exists() and read_json(history_view) != history:
        raise ValueError("legacy history changed during migration")
    if directory == legacy:
        active.parent.mkdir(parents=True, exist_ok=True)
        os.replace(legacy, active)
    marker.unlink()
    if generation.is_dir() and not generation.is_symlink():
        shutil.rmtree(generation, ignore_errors=True)


def read_state(root, locale):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=unidiomatic-typecheck,too-many-branches
    """Read one selected generation, or import a legacy single-file store."""
    recover_migration(root, locale)
    active = root / "active" / locale
    if active.is_symlink():
        generation = active.resolve(strict=True)
        if not generation.is_relative_to(root / "state" / locale):
            raise ValueError("active generation escapes locale state store")
        state = read_json(generation / ".state.json")
        if (
            not isinstance(state, dict)
            or set(state) != {"schema", "locale", "current"}
            or type(state["schema"]) is not int
            or state["schema"] != 1
            or state["locale"] != locale
        ):
            raise ValueError("invalid selected generation")
        history = validate_history(read_json(generation / ".history.json"), locale)
        current = state["current"]
        if current is not None:
            if not isinstance(current, str) or not re.fullmatch(
                r"installed/" + re.escape(locale) + r"/[a-f0-9]{64}/(?:catalog|index)\.json", current
            ):
                raise ValueError("invalid current generation target")
            target = root / current
            runtime = generation / ("sgn" if target.name == "index.json" else "sgn.json")
            expected = target.parent if target.name == "index.json" else target
            if not runtime.is_symlink() or runtime.resolve() != expected:
                raise ValueError("runtime selector and generation state disagree")
    else:
        if active.exists() and not active.is_dir():
            raise ValueError("invalid legacy active directory")
        selected = target_of(active / "sgn.json", root)
        current = str(selected.relative_to(root)) if selected else None
        history_path = root / "history" / (locale + ".json")
        if history_path.is_symlink():
            wanted = str(Path("../active") / locale / ".history.json")
            if os.readlink(history_path) != wanted:
                raise ValueError("unexpected history view selector")
            history = validate_history(read_json(active / ".history.json"), locale)
        else:
            history = validate_history(read_json(history_path), locale) if history_path.exists() else []
        # Recover old-tool interruptions: the last history write preceded or
        # followed a selector update that did not finish. Never guess a target.
        while history and current != history[-1]["after"] and current == history[-1]["before"]:
            history = history[:-1]
    if (history[-1]["after"] if history else None) != current:
        raise ValueError("no matching activation history; active state changed")
    return current, history


def publish_state(root, locale, current, history):
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=too-many-locals,too-many-branches,too-many-statements
    """Select runtime pointers and history together, recovering interrupted imports."""
    validate_history(history, locale)
    active = root / "active" / locale
    states = root / "state" / locale
    states.mkdir(parents=True, exist_ok=True)
    generation = Path(tempfile.mkdtemp(dir=states, prefix="generation-"))
    committed = False
    marker = root / "migrations" / (locale + ".json")
    try:
        atomic_json(generation / ".state.json", {"schema": 1, "locale": locale, "current": current})
        atomic_json(generation / ".history.json", history)
        if current:
            target = checked_target(root, locale, current)
            (generation / ("sgn" if target.name == "index.json" else "sgn.json")).symlink_to(
                target.parent if target.name == "index.json" else target
            )
        history_view = root / "history" / (locale + ".json")
        wanted = Path("../active") / locale / ".history.json"
        mode = None
        if active.is_dir() and not active.is_symlink():
            old_current, old_history = read_state(root, locale)
            atomic_json(active / ".history.json", old_history)
            atomic_json(active / ".state.json", {"schema": 1, "locale": locale, "current": old_current})
            mode = "legacy"
        elif not active.exists() and not active.is_symlink():
            mode = "initial"
        if mode:
            # Publish recovery intent before changing either legacy metadata
            # views or the old directory. SIGKILL cannot leave an ambiguous gap.
            atomic_json(
                marker, {"schema": 1, "locale": locale, "mode": mode, "generation": str(generation.relative_to(root))}
            )
        if history_view.is_symlink():
            if os.readlink(history_view) != str(wanted):
                raise ValueError("unexpected history view selector")
        else:
            if history_view.exists():
                backup = root / "legacy-history" / (locale + ".json")
                backup.parent.mkdir(parents=True, exist_ok=True)
                if backup.exists() or backup.is_symlink():
                    # A failed earlier view replacement may already have saved
                    # the same bytes. A differing backup remains an error.
                    if read_json(backup) != read_json(history_view):
                        raise ValueError("legacy history backup differs from current history")
                else:
                    shutil.copyfile(history_view, backup)
            atomic_link(history_view, wanted, replace_file=True)
        if mode == "legacy":
            legacy = root / "legacy-active" / locale
            if legacy.exists() or legacy.is_symlink():
                raise ValueError("legacy active backup already exists")
            legacy.parent.mkdir(parents=True, exist_ok=True)
            os.replace(active, legacy)
        atomic_link(active, generation)
        committed = True
        if marker.exists():
            # A failed cleanup can safely be retried on the next command. It
            # cannot turn a completed selector commit into a reported failure.
            try:
                marker.unlink()
            except OSError:
                pass
    except BaseException:
        # KeyboardInterrupt/SystemExit can arrive after the rename syscall has
        # already committed. Preserve either complete generation, never delete
        # the one that the selector now references.
        committed = active.is_symlink() and active.resolve() == generation
        if marker.exists() or marker.is_symlink():
            recover_migration(root, locale)
        raise
    finally:
        if not committed:
            shutil.rmtree(generation, ignore_errors=True)


def create_pack(source, output):
    """Create a portable package from either native output layout."""
    if output.exists():
        raise ValueError("refusing to overwrite an existing pack")
    indexed = source.is_dir() or source.name == "index.json"
    directory = source if source.is_dir() else source.parent
    if indexed:
        _, _, files = indexed_data(directory)
        blobs = {name: (directory / name).read_bytes() for name in files}
    else:
        validate_catalog(read_json(source))
        blobs = {"catalog.json": source.read_bytes()}
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(dir=output.parent, prefix=".pack-"))
    try:
        for name, data in blobs.items():
            (stage / name).write_bytes(data)
        manifest = manifest_for(stage, indexed)
        (stage / "manifest.json").write_bytes(json_bytes(manifest))
        validate_pack(stage)
        os.replace(stage, output)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return manifest


def main():
    # Audited JSON boundary and explicit transaction state machine.
    # pylint: disable=too-many-locals,too-many-branches,too-many-statements
    """Run a bounded local operation under the operator store lock."""
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("create")
    create.add_argument(
        "--catalog", type=Path, required=True, help="sgn.json, index.json, or indexed catalog directory"
    )
    create.add_argument("--output", type=Path, required=True)
    validate = commands.add_parser("validate")
    validate.add_argument("--pack", type=Path, required=True)
    for name in ("install", "activate", "rollback"):
        command = commands.add_parser(name)
        command.add_argument("--root", type=Path, required=True)
        if name == "install":
            command.add_argument("--pack", type=Path, required=True)
        else:
            command.add_argument("--locale", required=True)
            if name == "activate":
                command.add_argument("--hash", required=True)
                command.add_argument("--expected-revision")
    args = parser.parse_args()
    if args.command == "create":
        print(json.dumps(create_pack(args.catalog, args.output)))
        return
    if args.command == "validate":
        print(json.dumps(validate_pack(args.pack)[0]))
        return
    root = args.root.resolve()
    if root == Path("/") or len(root.parts) < 3:
        raise ValueError("use a task-local pack store")
    root.mkdir(parents=True, exist_ok=True)
    if not (root / ".sgn-i18n-store").exists():
        if any(root.iterdir()):
            raise ValueError("refusing to initialize a nonempty directory as a pack store")
        (root / ".sgn-i18n-store").write_text("schema=1\n")
    with (root / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.command == "install":
            manifest, _ = validate_pack(args.pack)
            destination = root / "installed" / manifest["locale"] / manifest["catalogSha256"]
            if destination.exists():
                existing, _ = validate_pack(destination)
                if existing != manifest:
                    raise ValueError("installed pack collision")
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                stage = Path(tempfile.mkdtemp(dir=destination.parent, prefix=".install-"))
                try:
                    for source in args.pack.iterdir():
                        (stage / source.name).write_bytes(source.read_bytes())
                    validate_pack(stage)
                    os.replace(stage, destination)
                finally:
                    if stage.exists():
                        shutil.rmtree(stage)
            print(json.dumps({"installed": manifest["catalogSha256"], "locale": manifest["locale"]}))
            return
        if not LOCALE.fullmatch(args.locale) or args.locale == "en":
            raise ValueError("invalid locale")
        current, history = read_state(root, args.locale)
        if args.command == "activate":
            if not HASH.fullmatch(args.hash):
                raise ValueError("invalid catalog hash")
            directory = root / "installed" / args.locale / args.hash
            manifest, _ = validate_pack(directory)
            if manifest["locale"] != args.locale or manifest["catalogSha256"] != args.hash:
                raise ValueError("installed pack identity mismatch")
            if args.expected_revision and manifest["sourceRevision"] != args.expected_revision:
                raise ValueError("source revision mismatch; activation refused")
            target = str(
                (directory / ("index.json" if manifest.get("format") == "indexed" else "catalog.json")).relative_to(
                    root
                )
            )
            if current == target:
                print(json.dumps({"active": args.hash, "unchanged": True}))
                return
            publish_state(root, args.locale, target, history + [{"before": current, "after": target}])
            print(json.dumps({"active": args.hash, "locale": args.locale, "catalogRoot": str(root / "active")}))
        else:
            if not history or current is None:
                raise ValueError("no matching activation to roll back; active state changed")
            previous = history[-1]["before"]
            checked_target(root, args.locale, previous)
            publish_state(root, args.locale, previous, history[:-1])
            print(json.dumps({"rolledBack": True, "locale": args.locale, "englishFallback": previous is None}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, json.JSONDecodeError) as error:
        raise SystemExit(str(error)) from error
