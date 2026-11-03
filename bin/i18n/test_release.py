#!/usr/bin/env python3
"""Release-source isolation, plural parity and transactional package regressions."""

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch

import catalog
import pack
from catalog_format import read_json, sha256_hex
from plural import parse_plural, validate_ast

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent


class ReleaseTests(unittest.TestCase):  # pylint: disable=too-many-public-methods
    """Prove the release and operator boundaries using actual offline commands."""

    def setUp(self):
        # unittest addCleanup retains ownership even after a failed assertion.
        # pylint: disable=consider-using-with
        self.temporary = tempfile.TemporaryDirectory(prefix="sgn-i18n-release-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def command(self, tool, *args, env=None, ok=True):
        """Run one real CLI operation and decode its structured receipt."""
        result = subprocess.run(
            [sys.executable, "-B", str(TOOLS / tool), *map(str, args)],
            text=True,
            capture_output=True,
            env=env,
            check=False,
            timeout=20,
        )
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return (json.loads(result.stdout) if result.stdout.strip() else None) if ok else result.stderr

    def without_parsers(self):
        """Build a PATH containing gettext alone for dependency-isolation checks."""
        tools = self.root / "gettext-only"
        tools.mkdir(exist_ok=True)
        for executable in ("msgcat", "msgfmt"):
            destination = tools / executable
            if not destination.exists():
                destination.symlink_to(shutil.which(executable))
        return {**os.environ, "PATH": str(tools), "PYTHONDONTWRITEBYTECODE": "1"}

    def native_catalog(self, version=1):
        """Return one bounded manufactured catalog with valid plural metadata."""
        return {
            "schema": 1,
            "api": 1,
            "locale": "es",
            "direction": "ltr",
            "languageName": "Español",
            "sourceRevision": "a" * 64,
            "nplurals": 2,
            "pluralForms": "nplurals=2; plural=(n != 1);",
            "pluralAst": parse_plural("nplurals=2; plural=(n != 1);")["ast"],
            "messages": {"controls.save\x04Save": {"plural": None, "forms": [f"Guardar {version}"]}},
        }

    def single_pack(self, version=1):
        """Create one portable package through its actual Node-free CLI."""
        source = self.root / f"catalog-{version}.json"
        source.write_bytes(catalog.json_bytes(self.native_catalog(version)))
        output = self.root / f"pack-{version}"
        manifest = self.command(
            "pack.py", "create", "--catalog", source, "--output", output, env=self.without_parsers()
        )
        return output, manifest

    def test_ready_pack_operator_needs_only_data_format_and_plural_modules(self):
        """Install tools run without importing the builder or source extractors."""
        operator = self.root / "operator"
        operator.mkdir()
        for name in ("sgn-i18n", "pack.py", "catalog_format.py", "plural.py"):
            shutil.copyfile(TOOLS / name, operator / name)
        source = self.root / "catalog.json"
        source.write_bytes(catalog.json_bytes(self.native_catalog()))
        env = {**os.environ, "PATH": str(self.root / "no-commands"), "PYTHONDONTWRITEBYTECODE": "1"}
        result = subprocess.run(
            [
                sys.executable,
                str(operator / "sgn-i18n"),
                "create",
                "--catalog",
                str(source),
                "--output",
                str(self.root / "pack"),
            ],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["locale"], "es")
        help_result = subprocess.run(
            [sys.executable, str(operator / "sgn-i18n"), "--help"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertIn("install --activate", help_result.stdout)
        self.assertNotIn("prepare", help_result.stdout)
        self.assertNotIn("extract", help_result.stdout)

    def test_shared_command_accepts_source_root_after_command(self):
        """The documented launcher and old direct syntax read the same source."""
        source = self.root / "source"
        (source / "locale").mkdir(parents=True)
        (source / "locale/sources.txt").write_text("")
        receipt = self.command("sgn-i18n", "extract", "--root", source)
        self.assertEqual(receipt["messages"], 0)
        template = (source / "locale/sgn.pot").read_bytes()
        self.assertEqual(self.command("catalog.py", "--root", source, "extract"), receipt)
        self.assertEqual((source / "locale/sgn.pot").read_bytes(), template)
        result = subprocess.run(
            [sys.executable, str(TOOLS / "sgn-i18n"), "freeze", "--help"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--root", result.stdout)

    def test_install_and_activate_needs_no_copied_hash_and_is_idempotent(self):
        """One command derives identity from the validated pack and preserves history."""
        package, manifest = self.single_pack()
        store = self.root / "store"
        receipt = self.command("sgn-i18n", "install", "--activate", "--pack", package, "--root", store)
        self.assertEqual(receipt["active"], manifest["catalogSha256"])
        self.assertEqual(receipt["active"], receipt["installed"])
        self.assertFalse(receipt["siteChecked"])
        selected = (store / "active/es").readlink()
        history = (store / "history/es.json").read_bytes()
        receipt = self.command("sgn-i18n", "install", "--activate", "--pack", package, "--root", store)
        self.assertTrue(receipt["unchanged"])
        self.assertEqual((store / "active/es").readlink(), selected)
        self.assertEqual((store / "history/es.json").read_bytes(), history)
        self.assertTrue(self.command("sgn-i18n", "rollback", "--locale", "es", "--root", store)["englishFallback"])

    def test_combined_install_respects_revision_and_failed_activation_preserves_selection(self):
        """Neither a wrong release gate nor a failed publish selects a new version."""
        store, _, two = self.prepared_store()
        package = self.root / "pack-2"
        before = (store / "active/es").readlink()
        history = (store / "history/es.json").read_bytes()
        error = self.command(
            "sgn-i18n",
            "install",
            "--activate",
            "--pack",
            package,
            "--root",
            store,
            "--expected-revision",
            "b" * 64,
            ok=False,
        )
        self.assertIn("source revision mismatch", error)
        with patch.object(pack, "publish_state", side_effect=PermissionError("injected activation failure")):
            with self.assertRaises(PermissionError):
                self.in_process("install", "--activate", "--pack", package, "--root", store)
        self.assertEqual((store / "active/es").readlink(), before)
        self.assertEqual((store / "history/es.json").read_bytes(), history)
        retry = self.command("sgn-i18n", "install", "--activate", "--pack", package, "--root", store)
        self.assertEqual(retry["active"], two["catalogSha256"])

    def test_revision_gate_cannot_be_silently_ignored_on_staging_only_install(self):
        """A misplaced gate stops before even creating the requested store."""
        package, _ = self.single_pack()
        store = self.root / "not-created"
        error = self.command(
            "sgn-i18n",
            "install",
            "--pack",
            package,
            "--root",
            store,
            "--expected-revision",
            "a" * 64,
            ok=False,
        )
        self.assertIn("requires --activate", error)
        self.assertFalse(store.exists())

    @staticmethod
    def footprint(root):
        """Capture all persistent names, pointers and file bytes, without following links."""
        result = {}
        for path in root.rglob("*"):
            if path.is_symlink():
                value = ("link", str(path.readlink()))
            elif path.is_file():
                value = ("file", path.read_bytes())
            else:
                value = ("directory", None)
            result[str(path.relative_to(root))] = value
        return result

    def diagnose(self, store, *arguments):
        """Run the real read-only command, retaining its human-readable output."""
        return subprocess.run(
            [sys.executable, str(TOOLS / "sgn-i18n"), "doctor", "--root", str(store), *arguments],
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )

    def test_doctor_does_not_create_a_typo_path_or_recover_an_interrupted_activation(self):
        """Inspection is read-only even on missing or interrupted operator state."""
        missing = self.root / "missing"
        result = self.diagnose(missing)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(missing.exists())
        package, _ = self.single_pack()
        store = self.root / "store"
        self.command("pack.py", "install", "--pack", package, "--root", store)
        pending = store / "state/es/generation-pending"
        pending.mkdir(parents=True)
        (store / "history").mkdir()
        (store / "history/es.json").symlink_to("../active/es/.history.json")
        (store / "migrations").mkdir()
        (store / "migrations/es.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "locale": "es",
                    "mode": "initial",
                    "generation": "state/es/generation-pending",
                }
            )
        )
        before = self.footprint(store)
        with patch.object(pack, "recover_migration", side_effect=AssertionError("doctor must not recover")):
            healthy, findings = pack.doctor(store, "es")
        self.assertFalse(healthy)
        self.assertTrue(any("unfinished activation" in message for _, message in findings))
        self.assertEqual(self.footprint(store), before)
        result = self.diagnose(store)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.footprint(store), before)

    def test_doctor_checks_active_and_rollback_bytes_without_blocking_recovery(self):
        """A selected path alone cannot conceal corruption or a broken rollback pack."""
        store, one, two = self.prepared_store()
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        before = self.footprint(store)
        result = self.diagnose(store, "--locale", "es")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("SGN's filesystem user has not been tested", result.stdout)
        self.assertIn("site not checked", result.stdout)
        self.assertEqual(self.footprint(store), before)
        selected = store / "installed/es" / two["catalogSha256"] / "catalog.json"
        selected.write_text("{}")
        before = self.footprint(store)
        result = self.diagnose(store, "--locale", "es")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("es: active:", result.stdout)
        self.assertIn("es: rollback pack", result.stdout)
        self.assertEqual(self.footprint(store), before)
        self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertIn("Guardar 1", (store / "active/es/sgn.json").read_text())
        self.assertEqual(
            (store / "active/es/sgn.json").resolve(), store / "installed/es" / one["catalogSha256"] / "catalog.json"
        )

    def language_site(self, language="es", redirect=False, runtime_status=200):
        """Serve only a controlled header contract; catalog JavaScript is never executed."""
        observed = []

        class Handler(BaseHTTPRequestHandler):
            """Expose the same header types as the existing bootstrap endpoint."""

            def do_HEAD(self):  # pylint: disable=invalid-name  # HTTP handler protocol name.
                """Record one HEAD request, optionally returning a forbidden redirect."""
                observed.append((self.command, self.path))
                status = runtime_status if self.path.endswith("runtime.js") else 200
                self.send_response(302 if redirect else status)
                self.send_header("Content-Type", "application/javascript; charset=UTF-8")
                self.send_header("Content-Language", language)
                if redirect:
                    self.send_header("Location", "/login")
                self.end_headers()

            def log_message(self, *_args):
                """Keep synthetic HTTP requests out of test output."""

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join)
        self.addCleanup(server.shutdown)
        return "http://127.0.0.1:" + str(server.server_port) + "/breedbase", observed

    def test_doctor_site_check_uses_only_head_and_does_not_claim_whole_site_acceptance(self):
        """A genuine language header is checked separately from local file health."""
        store, _, _ = self.prepared_store()
        site, observed = self.language_site()
        result = self.diagnose(store, "--locale", "es", "--site", site)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            observed, [("HEAD", "/breedbase/i18n/runtime.js"), ("HEAD", "/breedbase/i18n/bootstrap.js?lang=es")]
        )
        self.assertIn("exact package version and workflows not checked", result.stdout)
        other, _ = self.language_site(language="en")
        result = self.diagnose(store, "--locale", "es", "--site", other)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected es", result.stdout)
        redirect, requested = self.language_site(redirect=True)
        result = self.diagnose(store, "--locale", "es", "--site", redirect)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(requested), 1, "A login redirect must not turn into a successful check")
        broken, requested = self.language_site(runtime_status=404)
        result = self.diagnose(store, "--locale", "es", "--site", broken)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("runtime.js", result.stdout)
        self.assertEqual(requested, [("HEAD", "/breedbase/i18n/runtime.js")])

    def test_explicit_blank_revision_never_disables_the_requested_gate(self):
        """An empty editor/environment field is an error, not an absent gate."""
        package, manifest = self.single_pack()
        for activate in ([], ["--activate"]):
            with self.subTest(activate=activate):
                store = self.root / ("blank-active" if activate else "blank-staging")
                error = self.command(
                    "sgn-i18n",
                    "install",
                    *activate,
                    "--pack",
                    package,
                    "--root",
                    store,
                    "--expected-revision",
                    "",
                    ok=False,
                )
                self.assertIn("64-character", error)
                self.assertFalse(store.exists())
        store = self.root / "blank-explicit"
        activation = ("activate", "--locale", "es", "--hash", manifest["catalogSha256"], "--root", store)
        error = self.command("sgn-i18n", *activation, "--expected-revision", "", ok=False)
        self.assertIn("64-character", error)
        self.assertFalse(store.exists())

    def test_rejected_revision_does_not_recover_or_delete_a_pending_operation(self):
        """Package approval is checked before any journal recovery is authorized."""
        package, manifest = self.single_pack()
        store = self.root / "store"
        self.command("pack.py", "install", "--pack", package, "--root", store)
        pending = store / "state/es/generation-pending"
        pending.mkdir(parents=True)
        (store / "history").mkdir()
        (store / "history/es.json").symlink_to("../active/es/.history.json")
        (store / "migrations").mkdir()
        (store / "migrations/es.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "locale": "es",
                    "mode": "initial",
                    "generation": "state/es/generation-pending",
                }
            )
        )
        before = self.footprint(store)
        activation = ("activate", "--locale", "es", "--hash", manifest["catalogSha256"], "--root", store)
        error = self.command("sgn-i18n", *activation, "--expected-revision", "b" * 64, ok=False)
        self.assertIn("source revision mismatch", error)
        self.assertEqual(self.footprint(store), before)
        receipt = self.command("sgn-i18n", *activation, "--expected-revision", "a" * 64)
        self.assertEqual(receipt["active"], manifest["catalogSha256"])
        self.assertFalse((store / "migrations/es.json").exists())

    def test_doctor_accepts_the_runtime_regional_parent_without_extra_settings(self):
        """Requested and effective language can differ in a healthy supported setup."""
        store, _, _ = self.prepared_store()
        before = self.footprint(store)
        site, observed = self.language_site(language="es")
        result = self.diagnose(store, "--locale", "es-AR", "--site", site)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("es-AR uses the installed parent language es", result.stdout)
        self.assertIn("site language response is es", result.stdout)
        self.assertEqual(
            observed, [("HEAD", "/breedbase/i18n/runtime.js"), ("HEAD", "/breedbase/i18n/bootstrap.js?lang=es-AR")]
        )
        self.assertEqual(self.footprint(store), before)
        region = self.native_catalog()
        region["locale"] = "es-AR"
        source = self.root / "regional.json"
        source.write_bytes(catalog.json_bytes(region))
        package = self.root / "regional-pack"
        self.command("pack.py", "create", "--catalog", source, "--output", package)
        self.command("pack.py", "install", "--activate", "--pack", package, "--root", store)
        result = self.diagnose(store, "--locale", "es-AR", "--site", site)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected es-AR", result.stdout)

    def test_json_inputs_are_bounded_and_reject_non_json_numbers(self):
        """Malformed JSON cannot enter a ready pack or exceed the read limit."""
        source = self.root / "catalog.json"
        for token in ("NaN", "Infinity", "-Infinity"):
            source.write_text('{"unused":' + token + "}")
            with self.subTest(token=token), self.assertRaisesRegex(ValueError, "JSON number"):
                read_json(source)
        source.write_text('{"duplicate":1,"duplicate":2}')
        with self.assertRaisesRegex(ValueError, "duplicate JSON key"):
            read_json(source)
        source.write_text('"' + "x" * 100 + '"')
        with self.assertRaisesRegex(ValueError, "size limit"):
            read_json(source, limit=32)
        self.assertEqual(read_json(source, limit=102), "x" * 100)
        value = self.native_catalog()
        value["unexpected"] = float("nan")
        source.write_text(json.dumps(value))
        self.assertIn(
            "JSON number",
            self.command("pack.py", "create", "--catalog", source, "--output", self.root / "invalid", ok=False),
        )
        self.assertFalse((self.root / "invalid").exists())

    def test_plural_trees_match_all_existing_runtime_fixtures(self):
        """Plural trees match all existing runtime fixtures."""
        fixtures = json.loads((ROOT / "t/unit/SGN/i18n-fixtures.json").read_text())
        for locale, data in fixtures["catalogs"].items():
            with self.subTest(locale=locale):
                self.assertEqual(parse_plural(data["pluralForms"])["ast"], data["pluralAst"])
        for formula in (
            "nplurals=2; plural=(n+1);",
            "nplurals=2; plural=evil(n);",
            "nplurals=2; plural=n % 0;",
            "nplurals=2; plural=n % n;",
            "nplurals=2; plural=n != ١;",
            "nplurals=2; plural=2;",
            "nplurals=2; plural=(" * 40,
        ):
            with self.subTest(formula=formula), self.assertRaises(ValueError):
                parse_plural(formula)
        with self.assertRaises(ValueError):
            validate_ast({"type": "NUM", "val": True})

    def test_frozen_external_po_build_needs_only_snapshot_and_gettext(self):
        """Compile a frozen contract after deleting its entire application source."""
        source = self.root / "source"
        (source / "locale").mkdir(parents=True)
        (source / "trial.js").write_text('SGN.i18n.p("trial.name", "Trial name");\n')
        (source / "shared.js").write_text('SGN.i18n.p("controls.save", "Save");\n')
        (source / "locale/sources.txt").write_text("trial.js\nshared.js\n")
        (source / "locale/workflows.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "source_workflows": {"trial.js": "trials", "shared.js": "global"},
                    "common_sources": ["shared.js"],
                    "common_context_prefixes": [],
                }
            )
        )
        release = self.root / "release.json"
        # Source parsing has its own qualified extractor suites. The native CI
        # gate exercises the release/operator boundary without those parsers.
        messages = [
            {"context": "controls.save", "source": "Save", "plural": None, "references": ["shared.js:1"]},
            {"context": "trial.name", "source": "Trial name", "plural": None, "references": ["trial.js:1"]},
        ]
        release.write_bytes(catalog.json_bytes(catalog.freeze_release(source, messages, "fixture-v1")))
        release.with_suffix(".pot").write_text(catalog.pot(messages))
        self.assertTrue(release.with_suffix(".pot").is_file())
        data = catalog.validate_release(catalog.read_json(release, limit=catalog.MAX_RELEASE_BYTES))
        self.assertEqual(data["applicationVersion"], "fixture-v1")
        shutil.rmtree(source)
        # The deliberately unrelated filename proves PO Language metadata owns
        # the locale; no application checkout or language parsers remain.
        po = self.root / "translator-checked.po"
        env = self.without_parsers()
        empty_root = self.root / "no-source"
        empty_root.mkdir()
        self.command(
            "catalog.py",
            "--root",
            empty_root,
            "init",
            "--release",
            release,
            "--locale",
            "es",
            "--direction",
            "ltr",
            "--plural-forms",
            "nplurals=2; plural=(n != 1);",
            "--name",
            "Español",
            "--output",
            po,
            env=env,
        )
        text = (
            po.read_text()
            .replace('msgid "Trial name"\nmsgstr ""', 'msgid "Trial name"\nmsgstr "Nombre del ensayo"')
            .replace('msgid "Save"\nmsgstr ""', 'msgid "Save"\nmsgstr "Guardar"')
        )
        po.write_text(text)
        output = self.root / "build"
        self.command(
            "sgn-i18n", "build", "--root", empty_root, "--release", release, "--po", po, "--output", output, env=env
        )
        index = output / "es/sgn/index.json"
        package = self.root / "release-pack"
        manifest = self.command("pack.py", "create", "--catalog", index, "--output", package, env=env)
        store = self.root / "store"
        self.command("pack.py", "install", "--pack", package, "--root", store, env=env)
        self.command(
            "pack.py", "activate", "--locale", "es", "--hash", manifest["catalogSha256"], "--root", store, env=env
        )
        common = json.loads((store / "active/es/sgn/common.json").read_text())
        self.assertEqual(common["messages"]["controls.save\x04Save"]["forms"], ["Guardar"])
        self.command("pack.py", "rollback", "--locale", "es", "--root", store, env=env)
        self.assertFalse((store / "active/es/sgn/index.json").exists())

    def test_invalid_release_contracts_rejected_before_output(self):
        """Invalid release contracts rejected before output."""
        messages = [{"context": "save", "source": "Save", "plural": None, "references": ["page.js:1"]}]
        release = {
            "schema": 1,
            "api": 1,
            "domain": "sgn",
            "applicationVersion": "v1",
            "sourceRevision": catalog.source_revision(messages),
            "messages": messages,
            "partitions": {"common": [0]},
        }
        catalog.validate_release(release)
        for field, value in (
            ("sourceRevision", "b" * 64),
            ("schema", True),
            ("partitions", {"common": []}),
            ("partitions", {"common": [True]}),
            ("partitions", {"common": [0], "trials": [0]}),
        ):
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                catalog.validate_release({**release, field: value})
        invalid = self.root / "invalid.json"
        invalid.write_text(json.dumps({**release, "schema": True}))
        output = self.root / "unwritten"
        self.command(
            "catalog.py", "build", "--release", invalid, "--output", output, env=self.without_parsers(), ok=False
        )
        self.assertFalse(output.exists())

    def test_large_indexed_lifecycle_and_rollback_without_node(self):
        """Large indexed lifecycle and rollback without node."""
        # pylint: disable=too-many-locals
        directory = self.root / "indexed"
        directory.mkdir()
        entries = []
        for group in ("common", "trials"):
            data = self.native_catalog()
            data["messages"] = {
                f"{group}.{i}\x04Source {i}": {"plural": None, "forms": ["x" * 60000]} for i in range(20)
            }
            raw = catalog.json_bytes(data)
            self.assertLess(len(raw), catalog.MAX_BYTES)
            (directory / (group + ".json")).write_bytes(raw)
            entries.append({"name": group, "sha256": sha256_hex(raw)})
        self.assertGreater(sum(p.stat().st_size for p in directory.iterdir()), catalog.MAX_BYTES)
        (directory / "index.json").write_bytes(
            catalog.json_bytes({"schema": 1, "domain": "sgn", "sourceRevision": "b" * 64, "partitions": entries})
        )
        package = self.root / "indexed-pack"
        env = self.without_parsers()
        indexed = self.command("pack.py", "create", "--catalog", directory, "--output", package, env=env)
        single, first = self.single_pack()
        store = self.root / "store"
        for folder in (single, package):
            self.command("pack.py", "install", "--pack", folder, "--root", store, env=env)
        for version in (first, indexed):
            self.command(
                "pack.py", "activate", "--locale", "es", "--hash", version["catalogSha256"], "--root", store, env=env
            )
        before = (store / "history/es.json").read_bytes()
        same = self.command(
            "pack.py", "activate", "--locale", "es", "--hash", indexed["catalogSha256"], "--root", store, env=env
        )
        self.assertTrue(same["unchanged"])
        self.assertEqual((store / "history/es.json").read_bytes(), before)
        relocated = self.root / "container-mounted-store"
        store.rename(relocated)
        store = relocated
        self.assertTrue((store / "active/es/sgn/index.json").is_file())
        self.command("pack.py", "rollback", "--locale", "es", "--root", store, env=env)
        self.assertEqual(
            json.loads((store / "active/es/sgn.json").read_text())["messages"]["controls.save\x04Save"]["forms"],
            ["Guardar 1"],
        )
        self.assertFalse((store / "active/es/sgn/index.json").exists())
        self.command("pack.py", "rollback", "--locale", "es", "--root", store, env=env)
        self.assertFalse((store / "active/es/sgn.json").exists())
        self.assertTrue((store / "installed/es" / indexed["catalogSha256"]).is_dir())

    def in_process(self, *args):
        """Run the actual entry point while allowing targeted failure injection."""
        with patch.object(sys, "argv", ["pack.py", *map(str, args)]), contextlib.redirect_stdout(io.StringIO()):
            pack.main()

    def prepared_store(self, legacy=False):
        """Install two versions and select the first through native or legacy state."""
        first, one = self.single_pack(1)
        second, two = self.single_pack(2)
        store = self.root / "store"
        self.in_process("install", "--pack", first, "--root", store)
        self.in_process("install", "--pack", second, "--root", store)
        if legacy:
            current = f"installed/es/{one['catalogSha256']}/catalog.json"
            active = store / "active/es"
            active.mkdir(parents=True)
            (active / "sgn.json").symlink_to(store / current)
            (store / "history").mkdir()
            (store / "history/es.json").write_bytes(catalog.json_bytes([{"before": None, "after": current}]))
        else:
            self.in_process("activate", "--locale", "es", "--hash", one["catalogSha256"], "--root", store)
        return store, one, two

    def test_failed_generation_preparation_or_selector_preserves_active_and_history(self):
        """Failed generation preparation or selector preserves active and history."""
        store, _, two = self.prepared_store()
        active = store / "active/es"
        before_active = os.readlink(active)
        before_history = (store / "history/es.json").read_bytes()
        for operation in ("atomic_json", "atomic_link"):
            with (
                self.subTest(operation=operation),
                patch.object(pack, operation, side_effect=PermissionError("injected storage failure")),
            ):
                with self.assertRaises(PermissionError):
                    self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
            self.assertEqual(os.readlink(active), before_active)
            self.assertEqual((store / "history/es.json").read_bytes(), before_history)
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        before_active = os.readlink(active)
        before_history = (store / "history/es.json").read_bytes()
        with patch.object(pack, "atomic_json", side_effect=PermissionError("injected history failure")):
            with self.assertRaises(PermissionError):
                self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertEqual(os.readlink(active), before_active)
        self.assertEqual((store / "history/es.json").read_bytes(), before_history)
        self.in_process("rollback", "--locale", "es", "--root", store)

    def test_legacy_store_import_recovers_failed_migration_and_preserves_rollback(self):
        """Legacy store import recovers failed migration and preserves rollback."""
        store, one, two = self.prepared_store(legacy=True)
        before = (store / "history/es.json").read_bytes()
        original = pack.atomic_link

        def fail_active(path, target, *args, **kwargs):
            if path == store / "active/es":
                raise PermissionError("injected selector failure")
            original(path, target, *args, **kwargs)

        with patch.object(pack, "atomic_link", side_effect=fail_active), self.assertRaises(PermissionError):
            self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.assertFalse((store / "active/es").is_symlink())
        self.assertEqual((store / "history/es.json").read_bytes(), before)
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.assertTrue((store / "active/es").is_symlink())
        self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertEqual(
            (store / "active/es/sgn.json").resolve(), store / f"installed/es/{one['catalogSha256']}/catalog.json"
        )
        self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertTrue((store / "legacy-active/es").is_dir())
        self.assertTrue((store / "legacy-history/es.json").is_file())

    def test_wrong_installed_identity_is_refused_without_changing_state(self):
        """Wrong installed identity is refused without changing state."""
        store, one, _ = self.prepared_store()
        source = store / "installed/es" / one["catalogSha256"]
        fake = "c" * 64
        shutil.copytree(source, source.parent / fake)
        before = os.readlink(store / "active/es")
        with self.assertRaisesRegex(ValueError, "identity mismatch"):
            self.in_process("activate", "--locale", "es", "--hash", fake, "--root", store)
        self.assertEqual(os.readlink(store / "active/es"), before)

    def test_absolute_generations_remain_compatible_and_new_generations_can_move(self):
        """Existing stores upgrade without losing rollback or requiring equal mount paths."""
        store, one, two = self.prepared_store()
        selector = store / "active/es"
        generation = selector.resolve()
        runtime = generation / "sgn.json"
        target = runtime.resolve()
        # Recreate the previous installer's absolute selector representation.
        selector.unlink()
        selector.symlink_to(generation)
        runtime.unlink()
        runtime.symlink_to(target)
        history_before = (store / "history/es.json").read_bytes()
        self.in_process("activate", "--locale", "es", "--hash", one["catalogSha256"], "--root", store)
        self.assertEqual((store / "history/es.json").read_bytes(), history_before)
        selected = selector.readlink()
        self.in_process("activate", "--locale", "es", "--hash", one["catalogSha256"], "--root", store)
        self.assertEqual(selector.readlink(), selected, "A current relative generation remains a no-op")
        moved = self.root / "different-mount-path"
        store.rename(moved)
        self.assertIn("Guardar 1", (moved / "active/es/sgn.json").read_text())
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", moved)
        self.assertIn("Guardar 2", (moved / "active/es/sgn.json").read_text())
        self.in_process("rollback", "--locale", "es", "--root", moved)
        self.assertIn("Guardar 1", (moved / "active/es/sgn.json").read_text())
        self.in_process("activate", "--locale", "es", "--hash", one["catalogSha256"], "--root", moved)

    def test_corrupt_selected_pack_can_roll_back_to_valid_previous_version(self):
        """Corrupt selected pack can roll back to valid previous version."""
        store, one, two = self.prepared_store()
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        bad = store / "installed/es" / two["catalogSha256"] / "catalog.json"
        bad.write_text("{}")
        self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertEqual(
            (store / "active/es/sgn.json").resolve(), store / "installed/es" / one["catalogSha256"] / "catalog.json"
        )

    def test_indexed_create_rejects_missing_symlinked_or_conflicting_partitions(self):
        """Indexed create rejects missing symlinked or conflicting partitions."""
        directory = self.root / "source-index"
        directory.mkdir()
        data = self.native_catalog()
        raw = catalog.json_bytes(data)
        for name in ("common", "trials"):
            (directory / (name + ".json")).write_bytes(raw)
        index = {
            "schema": 1,
            "domain": "sgn",
            "sourceRevision": "b" * 64,
            "partitions": [{"name": name, "sha256": sha256_hex(raw)} for name in ("common", "trials")],
        }
        (directory / "index.json").write_bytes(catalog.json_bytes(index))
        for mode in ("missing", "symlink", "conflicting"):
            member = directory / "trials.json"
            member.unlink(missing_ok=True)
            if mode == "symlink":
                member.symlink_to(directory / "common.json")
            elif mode == "conflicting":
                changed = self.native_catalog(2)
                changed_bytes = catalog.json_bytes(changed)
                member.write_bytes(changed_bytes)
                index["partitions"][1]["sha256"] = sha256_hex(changed_bytes)
                (directory / "index.json").write_bytes(catalog.json_bytes(index))
            with self.subTest(mode=mode), self.assertRaises((ValueError, OSError)):
                pack.create_pack(directory, self.root / ("unwritten-" + mode))
            self.assertFalse((self.root / ("unwritten-" + mode)).exists())

    def test_first_activation_failed_history_or_selector_can_be_retried(self):
        """First activation failed history or selector can be retried."""
        package, manifest = self.single_pack()
        original = pack.atomic_link
        for failed_view in ("history", "active"):
            with self.subTest(failed_view=failed_view):
                store = self.root / ("initial-" + failed_view)
                self.in_process("install", "--pack", package, "--root", store)
                failed_path = store / ("history/es.json" if failed_view == "history" else "active/es")

                def fail_selected(path, target, *args, _failed_path=failed_path, **kwargs):
                    if path == _failed_path:
                        raise PermissionError("injected first selector failure")
                    original(path, target, *args, **kwargs)

                with patch.object(pack, "atomic_link", side_effect=fail_selected), self.assertRaises(PermissionError):
                    self.in_process("activate", "--locale", "es", "--hash", manifest["catalogSha256"], "--root", store)
                self.assertFalse((store / "active/es").exists())
                self.assertFalse((store / "history/es.json").is_symlink())
                self.assertFalse((store / "migrations/es.json").exists())
                self.in_process("activate", "--locale", "es", "--hash", manifest["catalogSha256"], "--root", store)
                self.in_process("rollback", "--locale", "es", "--root", store)

    def test_legacy_failed_history_view_reuses_identical_backup_on_retry(self):
        """Legacy failed history view reuses identical backup on retry."""
        store, _, two = self.prepared_store(legacy=True)
        original = pack.atomic_link
        before = (store / "history/es.json").read_bytes()

        def fail_history(path, target, *args, **kwargs):
            if path == store / "history/es.json":
                raise PermissionError("injected history view failure")
            original(path, target, *args, **kwargs)

        with patch.object(pack, "atomic_link", side_effect=fail_history), self.assertRaises(PermissionError):
            self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.assertEqual((store / "legacy-history/es.json").read_bytes(), before)
        self.assertEqual((store / "history/es.json").read_bytes(), before)
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.in_process("rollback", "--locale", "es", "--root", store)

    def test_keyboard_interrupt_restores_legacy_directory_before_returning(self):
        """Keyboard interrupt restores legacy directory before returning."""
        store, one, two = self.prepared_store(legacy=True)
        original = pack.atomic_link
        before = (store / "history/es.json").read_bytes()

        def interrupt_selector(path, target, *args, **kwargs):
            if path == store / "active/es":
                raise KeyboardInterrupt("injected process interruption")
            original(path, target, *args, **kwargs)

        with patch.object(pack, "atomic_link", side_effect=interrupt_selector), self.assertRaises(KeyboardInterrupt):
            self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.assertTrue((store / "active/es").is_dir())
        self.assertFalse((store / "active/es").is_symlink())
        self.assertEqual((store / "history/es.json").read_bytes(), before)
        self.assertFalse((store / "migrations/es.json").exists())
        current, _ = pack.read_state(store, "es")
        self.assertIn(one["catalogSha256"], current)
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)

    def test_next_command_recovers_sigkill_style_interrupted_legacy_rename(self):
        """Next command recovers sigkill style interrupted legacy rename."""
        store, one, two = self.prepared_store(legacy=True)
        active = store / "active/es"
        history = json.loads((store / "history/es.json").read_text())
        current = history[-1]["after"]
        (active / ".history.json").write_bytes(catalog.json_bytes(history))
        (active / ".state.json").write_bytes(catalog.json_bytes({"schema": 1, "locale": "es", "current": current}))
        generation = store / "state/es/generation-killed"
        generation.mkdir(parents=True)
        (store / "legacy-history").mkdir()
        shutil.copyfile(store / "history/es.json", store / "legacy-history/es.json")
        (store / "history/es.json").unlink()
        (store / "history/es.json").symlink_to("../active/es/.history.json")
        (store / "migrations").mkdir()
        (store / "migrations/es.json").write_bytes(
            catalog.json_bytes(
                {"schema": 1, "locale": "es", "mode": "legacy", "generation": "state/es/generation-killed"}
            )
        )
        (store / "legacy-active").mkdir()
        os.replace(active, store / "legacy-active/es")
        self.assertFalse(active.exists())
        recovered, recovered_history = pack.read_state(store, "es")
        self.assertEqual(recovered, current)
        self.assertEqual(recovered_history, history)
        self.assertTrue(active.is_dir())
        self.assertFalse(generation.exists())
        self.assertFalse((store / "migrations/es.json").exists())
        self.in_process("activate", "--locale", "es", "--hash", two["catalogSha256"], "--root", store)
        self.in_process("rollback", "--locale", "es", "--root", store)
        self.assertIn(one["catalogSha256"], str((store / "active/es/sgn.json").resolve()))

    def test_recovery_rejects_malformed_or_escaped_journal_without_moving_data(self):
        """Recovery rejects malformed or escaped journal without moving data."""
        store, _, _ = self.prepared_store(legacy=True)
        (store / "migrations").mkdir()
        marker = store / "migrations/es.json"
        valid = {"schema": 1, "locale": "es", "mode": "legacy", "generation": "state/es/generation-test"}
        for change in ({"schema": True}, {"locale": "uk"}, {"mode": "unknown"}, {"generation": "../../outside"}):
            marker.write_bytes(catalog.json_bytes({**valid, **change}))
            with self.subTest(change=change), self.assertRaises(ValueError):
                pack.read_state(store, "es")
            self.assertTrue((store / "active/es/sgn.json").exists())
            self.assertFalse((store / "legacy-active/es").exists())
        external = self.root / "external-state"
        external.mkdir()
        (store / "state").mkdir()
        (store / "state/es").symlink_to(external)
        marker.write_bytes(catalog.json_bytes(valid))
        with self.assertRaisesRegex(ValueError, "unsafe migration generation"):
            pack.read_state(store, "es")
        self.assertTrue((store / "active/es/sgn.json").exists())


if __name__ == "__main__":
    unittest.main()
