#!/usr/bin/env python3
"""PPI regressions for heredoc-heavy native SGN and literal-only marked calls."""

import json
import os
import subprocess
import tempfile
import unittest

# Test names state their contracts; raw source fixtures retain exact line layouts.
# pylint: disable=missing-function-docstring
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from extract import ExtractionError, extract_file, is_mason_source, perl_extract

PROJECT_ROOT = Path(__file__).resolve().parents[2]


# Audited grammar traversal or explicit source-fixture boundary.
# pylint: disable=too-many-public-methods
class PPIExtractionTests(unittest.TestCase):
    """Exercise the p p i extraction tests contracts."""

    def records(self, source, suffix=".pm"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / ("fixture" + suffix)
            path.write_text(source, encoding="utf-8")
            return extract_file(path, root)

    def test_shared_helper_acquisition_singular_and_plural(self):
        rows = self.records("""
my SGN::I18N $tr = SGN::I18N::translate($c);
SGN::I18N::translate($tr, 'helper.name', 'Name: %{name}', {name => $name});
SGN::I18N::translate($tr, 'helper.html', 'A & B', undef, {entities => '<>&', decode => 1});
SGN::I18N::translate($tr, 'helper.fallback', 'Name: %{name}', {name => $token}, {fallback => $original});
SGN::I18N::translate($tr, 'helper.count', '%{count} trial', {count => $n},
    {plural => ['%{count} trials', $n], entities => '<>&', decode => 1});
""")
        self.assertEqual(
            [(r["context"], r["source"], r["plural"]) for r in rows],
            [
                ("helper.name", "Name: %{name}", None),
                ("helper.html", "A & B", None),
                ("helper.fallback", "Name: %{name}", None),
                ("helper.count", "%{count} trial", "%{count} trials"),
            ],
        )

    def test_shared_helper_rejects_dynamic_message_or_plural(self):
        for source in (
            "SGN::I18N::translate($tr, 'helper.name', $english);",
            "SGN::I18N::translate($tr, 'helper.count', 'One', undef, {plural => [$many, $n]});",
            "SGN::I18N::translate($tr, 'helper.count', 'One', undef, $options);",
        ):
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records(source)

    def test_exact_native_html_component_is_mason_not_generic_html(self):
        for name in ("mason/tools/bulk/tabs/clone_search.html",):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / name
                path.parent.mkdir(parents=True)
                path.write_text("<% $c->i18n->p('html.native', 'Native caption') %>")
                rows = extract_file(path, root)
                self.assertEqual(
                    [(r["context"], r["reference"]) for r in rows],
                    [("html.native", name + ":1")],
                )
        self.assertFalse(is_mason_source("mason/unreviewed.html"))
        self.assertFalse(is_mason_source("assets/mason/tools/bulk/tabs/clone_search.html"))

    def test_bare_mason_component_paths_do_not_hide_argument_calls(self):
        source = """<& /generic_message.mas,
 message => '<p>' . $c->i18n->p('component.generic', 'Message') . '</p>' &>
<&| /generic_message.mas, message => $c->i18n->p('component.block', 'Block') &>Body</&>
<& /page/page_title.mas, title => $c->i18n->p('component.nested', 'Title') &>
<& $component, title => $c->i18n->p('component.dynamic', 'Dynamic') &>
"""
        rows = self.records(source, ".mas")
        self.assertEqual(
            {row["context"]: row["reference"] for row in rows},
            {
                "component.generic": "fixture.mas:2",
                "component.block": "fixture.mas:3",
                "component.nested": "fixture.mas:4",
                "component.dynamic": "fixture.mas:5",
            },
        )

    def test_mason_cleanup_is_a_perl_fragment(self):
        rows = self.records(
            "<%cleanup>\nmy $label = $c->i18n->p('cleanup.label', 'Search');\n</%cleanup>\n",
            ".mas",
        )
        self.assertEqual(
            [(row["context"], row["source"], row["reference"]) for row in rows],
            [("cleanup.label", "Search", "fixture.mas:2")],
        )

    def test_extensionless_mason_fragments_preserve_refs_and_ignore_markup(self):
        source = """<p>SGN.i18n.p('fake.markup', 'Not a marked call')</p>
<%init>
my $title=$c->i18n->p('special.title', 'Human title');
</%init>
<& /page/page_title.mas, title=>$c->i18n->p('special.component', 'Page title') &>
% my $button=$c->i18n->p('special.control', 'Save');
"""
        for name in ("mason/autohandler", "mason/site/error/dhandler"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / name
                path.parent.mkdir(parents=True)
                path.write_text(source)
                rows = extract_file(path, root)
                self.assertEqual(
                    {row["context"] for row in rows},
                    {"special.title", "special.component", "special.control"},
                )
                self.assertEqual(
                    {row["reference"] for row in rows},
                    {name + ":3", name + ":5", name + ":6"},
                )

    def test_unsupported_registered_files_fail_before_any_parser(self):
        for name in (
            "script/autohandler",
            "script/dhandler",
            "features/example/mason/autohandler",
            "mason/Autohandler",
            "mason/autoHandler",
            "file.py",
            "file.txt",
            "file.json",
            "file.tt",
            "file.html",
            "file.jsx",
            "file.ts",
        ):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("")
                with (
                    patch("extract.subprocess.run") as parser,
                    self.assertRaisesRegex(ExtractionError, "not.*supported|Unsupported"),
                ):
                    extract_file(path, root)
                parser.assert_not_called()
        self.assertTrue(is_mason_source("mason/nested/autohandler"))
        self.assertFalse(is_mason_source("assets/mason/autohandler"))
        self.assertFalse(is_mason_source("mason/../script/autohandler"))

    def test_all_tracked_native_special_components_are_parseable_as_data(self):
        if (PROJECT_ROOT / ".git").exists():
            # Worktrees have a .git file; repositories have a .git directory.
            # A present but invalid Git checkout must fail, not fall back.
            paths = subprocess.check_output(
                ["git", "-C", str(PROJECT_ROOT), "ls-files", "-z", "--", "mason"],
                text=True,
            ).split("\0")
        else:
            # Committed runtime archives deliberately omit Git metadata. The
            # complete source-image proof covers this exact mason namespace.
            mason_root = PROJECT_ROOT / "mason"
            self.assertTrue(
                mason_root.is_dir(),
                "The runtime archive must contain the full Mason tree",
            )
            paths = [path.relative_to(PROJECT_ROOT).as_posix() for path in mason_root.rglob("*") if path.is_file()]
        special = sorted(
            path for path in paths if path.startswith("mason/") and Path(path).name in ("autohandler", "dhandler")
        )
        expected = {
            "mason/autohandler",
            "mason/barcode/tool/autohandler",
            "mason/dhandler",
            "mason/feature/types/autohandler",
            "mason/help/autohandler",
            "mason/publication/banners/autohandler",
            "mason/search/autohandler",
            "mason/search/expression/autohandler",
            "mason/search/phenotypes/autohandler",
            "mason/search/transcripts/autohandler",
            "mason/secretom/autohandler",
            "mason/site/error/dhandler",
            "mason/tools/bulk/tabs/autohandler",
        }
        self.assertEqual(
            set(special),
            expected,
            "The full 13-component native corpus must be present",
        )
        for relative in special:
            with self.subTest(path=relative):
                rows = extract_file(PROJECT_ROOT / relative, PROJECT_ROOT)
                for row in rows:
                    self.assertTrue(row["reference"].startswith(relative + ":"))

    def test_actual_native_user_controller_nine_login_contexts(self):
        path = PROJECT_ROOT / "lib/SGN/Controller/AJAX/User.pm"
        records = extract_file(path, PROJECT_ROOT)
        expected = {
            "navigation.login." + name
            for name in (
                "sign_in",
                "main_site",
                "main_site_title",
                "profile",
                "lists",
                "datasets",
                "calendar_title",
                "calendar",
                "sign_out",
            )
        }
        navigation = [row for row in records if row["context"].startswith("navigation.login.")]
        self.assertEqual({row["context"] for row in navigation}, expected)
        self.assertEqual(len(navigation), 9)
        self.assertIn("account.server.incorrect_credentials", {row["context"] for row in records})
        source = path.read_text(encoding="utf-8")
        for row in records:
            line = int(row["reference"].rsplit(":", 1)[1])
            self.assertIn(row["context"], source.splitlines()[line - 1])

    def test_heredoc_quote_like_pod_regex_and_comments_are_opaque(self):
        source = """my $data = <<'DATA';
$c->i18n->p('fake.heredoc', 'Ignored');
apostrophes ' and " mixed.
DATA
my $qq = qq{$c->i18n->p('fake.qq', 'Ignored')};
my $q = q{$c->i18n->p('fake.q', 'Ignored')};
my $regex = qr/$c->i18n->p('fake.regex', 'Ignored')/;
=pod
$c->i18n->p('fake.pod', 'Ignored');
=cut
# $c->i18n->p('fake.comment', 'Ignored');
$c->i18n->p('real.before', 'Trial name');
my $end = <<END_HTML;
<a title="'broken quote for old lexer">fake text</a>
END_HTML
$c->i18n()->p('real.after', "Number of trials");
"""
        records = self.records(source)
        self.assertEqual([row["context"] for row in records], ["real.before", "real.after"])
        self.assertEqual([row["reference"] for row in records], ["fixture.pm:12", "fixture.pm:16"])

    def test_literal_alias_plural_unicode_empty_context_and_escapes(self):
        records = self.records("""my $translator = $c->i18n;
$translator->np('demo.count', '%{count} trial', '%{count} trials', $n, {count=>$n});
$c->i18n->p('', 'Вітаємо, %{name}.', {name=>$name});
$c->i18n->p('demo.escape', "Price \\$ and \\"quote\\"\\n");
""")
        self.assertEqual(len(records), 3)
        self.assertEqual(records[0]["plural"], "%{count} trials")
        self.assertEqual(records[1]["context"], "")
        self.assertEqual(records[1]["source"], "Вітаємо, %{name}.")
        self.assertEqual(records[2]["source"], 'Price $ and "quote"\n')

    def test_native_module_final_true_expression_keeps_source_lines(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = 'package Fixture;\n$c->i18n->p("native.final", "Native source");\n1\n'
            path = root / "fixture.pm"
            path.write_text(source)
            rows = extract_file(path, root)
            self.assertEqual(
                [(r["context"], r["reference"]) for r in rows],
                [("native.final", "fixture.pm:2")],
            )
            self.assertEqual(path.read_text(), source)
            path.write_text("package Fixture;\nif (1) {\n1\n")
            with self.assertRaises(ExtractionError):
                extract_file(path, root)

    def test_dynamic_concat_quote_like_and_incomplete_fail_closed(self):
        for source in [
            "$c->i18n->p('ctx', $english);",
            "$c->i18n->p('ctx', 'prefix' . $name);",
            '$c->i18n->p("ctx", "Hello $name");',
            "$c->i18n->p('ctx', qq{English});",
            "$c->i18n->p('ctx', 'English'",
            "my $text=<<END;\nunfinished\n",
        ]:
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records(source)

    def test_source_is_never_executed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "executed"
            path = root / "fixture.pm"
            path.write_text(
                "BEGIN { open my $h, '>', '" + str(marker) + "'; print $h 'bad'; }\n$c->i18n->p('safe', 'English');\n"
            )
            records = extract_file(path, root)
            self.assertEqual(records[0]["context"], "safe")
            self.assertFalse(marker.exists())

    def test_mason_batches_perl_and_embedded_script_with_correct_locations(self):
        records = self.records(
            """<p>Plain text stays untouched</p>
<%init>
my $label=$c->i18n->p('page.title','Trial name');
</%init>
<script>
var x="<% $c->i18n->p('page.inline','Edit Trial Details') |h %>";
SGN.i18n.p('page.js','Save Changes');
</script>
""",
            ".mas",
        )
        self.assertEqual(
            {row["context"] for row in records},
            {"page.title", "page.inline", "page.js"},
        )
        self.assertEqual(
            {row["reference"] for row in records},
            {"fixture.mas:3", "fixture.mas:6", "fixture.mas:7"},
        )

    def test_configured_backend_is_shell_free_and_unavailable_never_silent(self):
        for value in ["perl /helper.pl", "[]", '["nonexistent-i18n-parser-command"]']:
            with (
                self.subTest(value=value),
                patch.dict(os.environ, {"SGN_I18N_PERL_COMMAND": value}),
                self.assertRaises(ExtractionError),
            ):
                self.records("$c->i18n->p('ctx','English');")

    def test_typed_constructor_alias_and_unsupported_known_chain(self):
        records = self.records("""my $i18n = SGN::I18N->new(locale=>'en');
$i18n->p('', 'Text');
SGN::I18N->new(locale=>'en')->np('count', '%{count} item', '%{count} items', $n, {count=>$n});
$widget->p('unrelated', 'Widget property');
""")
        self.assertEqual(
            [(row["context"], row["source"]) for row in records],
            [("", "Text"), ("count", "%{count} item")],
        )
        for source in [
            "$c->i18n->for_locale($locale)->p('ctx', 'Text');",
            "my $i18n=SGN::I18N->new(); $i18n->unknown()->p('ctx','Text');",
        ]:
            with (
                self.subTest(source=source),
                self.assertRaisesRegex(ExtractionError, "unsupported known i18n receiver chain"),
            ):
                self.records(source)

    def test_explicit_typed_injected_translator_and_reassignment(self):
        source = """sub render {
my SGN::I18N $render_i18n = _presentation_i18n(shift);
$render_i18n->p('view.title', 'Trial design');
}
"""
        records = self.records(source)
        self.assertEqual(
            [(row["context"], row["source"]) for row in records],
            [("view.title", "Trial design")],
        )
        with self.assertRaisesRegex(ExtractionError, "Ambiguous or reassigned translator alias"):
            self.records(source.replace("$render_i18n->p", "$render_i18n = Widget->new(); $render_i18n->p"))

    def test_reassigned_alias_cannot_capture_unrelated_widget_property(self):
        source = "my $i18n=SGN::I18N->new(); $i18n=Widget->new(); $i18n->p('widget','Property');"
        with self.assertRaisesRegex(ExtractionError, "Ambiguous or reassigned translator alias"):
            self.records(source)

    def test_known_cross_fragment_aliases_fail_at_original_use_lines(self):
        for declaration in [
            "my SGN::I18N $translator = injected();",
            "my $translator = SGN::I18N->new();",
            "my $translator = $c->i18n;",
        ]:
            source = "<%init>\n" + declaration + '\n</%init>\n<p><% $translator->p("ctx", "Text") |h %></p>\n'
            with (
                self.subTest(declaration=declaration),
                self.assertRaisesRegex(
                    ExtractionError,
                    "fixture.mas:4: unsupported cross-fragment translator alias",
                ),
            ):
                self.records(source, ".mas")
        # init may execute before the body even when it is later in the file.
        source = '<p><% $translator->p("ctx", "Text") |h %></p>\n<%init>\nmy $translator=$c->i18n;\n</%init>\n'
        with self.assertRaisesRegex(
            ExtractionError,
            "fixture.mas:1: unsupported cross-fragment translator alias",
        ):
            self.records(source, ".mas")
        for use in [
            '$translator->np("ctx","one","many",$n)',
            '$translator->for_locale($locale)->p("ctx","Text")',
        ]:
            source = '<%init>my $translator=$c->i18n;</%init>\n<script>\nvar text="<% ' + use + ' |h %>";\n</script>\n'
            with (
                self.subTest(use=use),
                self.assertRaisesRegex(
                    ExtractionError,
                    "fixture.mas:3: unsupported cross-fragment translator alias",
                ),
            ):
                self.records(source, ".mas")

    def test_cross_fragment_widget_shadowing_is_ambiguous_and_never_translated(self):
        source = """<%init>my $translator=$c->i18n;</%init>
<%perl>
{ my $translator=Widget->new(); $translator->p("widget", "Property"); }
</%perl>
"""
        with self.assertRaisesRegex(
            ExtractionError,
            "fixture.mas:3: unsupported cross-fragment translator alias",
        ):
            self.records(source, ".mas")
        source = source.replace("my $translator=Widget", "my $widget=Widget").replace(
            '$translator->p("widget"', '$widget->p("widget"'
        )
        self.assertEqual(self.records(source, ".mas"), [])
        # Separately proved local translators can still translate within their
        # own block; direct controller calls work across arbitrary fragments.
        source = """<%init>my $translator=$c->i18n;</%init>
<%perl>my $translator=SGN::I18N->new(); $translator->p("local", "Local text");</%perl>
<p><% $c->i18n->p("direct", "Direct text") |h %></p>
"""
        rows = self.records(source, ".mas")
        self.assertEqual(
            [(row["context"], row["reference"]) for row in rows],
            [("local", "fixture.mas:2"), ("direct", "fixture.mas:3")],
        )

    def test_cross_fragment_discovery_keeps_data_opaque_and_never_executes_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "executed"
            path = root / "fixture.mas"
            source = """<%init>
BEGIN { open my $h, '>', 'MARKER'; print $h 'bad'; }
my $example=<<'DATA';
my SGN::I18N $translator=injected();
DATA
# my $translator=$c->i18n;
my $quoted=q{my $translator=SGN::I18N->new();};
</%init>
<%doc>my $translator=$c->i18n;</%doc>
<%text>my $translator=$c->i18n;</%text>
<p><% $translator->p("widget", "Property") |h %></p>
<p><% $c->i18n->p("safe", "Safe text") |h %></p>
""".replace("MARKER", str(marker))
            path.write_text(source, encoding="utf-8")
            rows = extract_file(path, root)
            self.assertEqual(
                [(row["context"], row["reference"]) for row in rows],
                [("safe", "fixture.mas:12")],
            )
            self.assertFalse(marker.exists())

    def test_old_perl_helper_protocol_fails_explicitly(self):
        old = json.dumps({"schema": 2, "parser": "PPI", "parserVersion": "1.291", "records": []})
        with patch(
            "extract.subprocess.run",
            return_value=SimpleNamespace(returncode=0, stdout=old, stderr=""),
        ):
            with self.assertRaisesRegex(ExtractionError, "incompatible protocol"):
                perl_extract(
                    "fixture.mas",
                    [
                        {
                            "source": "my $translator=$c->i18n;",
                            "line_offset": 0,
                            "fragment": True,
                        }
                    ],
                )


# pylint: enable=too-many-public-methods


if __name__ == "__main__":
    unittest.main()
