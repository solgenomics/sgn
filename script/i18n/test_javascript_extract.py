#!/usr/bin/env python3
"""AST regressions for native JavaScript and Mason, without application execution."""
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from extract import extract_file, ExtractionError, javascript_extract

PROJECT_ROOT = Path(__file__).resolve().parents[2]


class JavaScriptExtractionTests(unittest.TestCase):
    def records(self, source, suffix='.js'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / ('fixture' + suffix)
            path.write_text(source, encoding='utf-8')
            return extract_file(path, root)

    def test_optional_mason_chain_suffix_keeps_static_captions(self):
        rows = self.records("""<script>
jQuery(function () {
widget.on('click', function () { return false; })<% $show ? '' : '.next().hide();' %>
});
SGN.i18n.p('optional.static', 'Show');
</script>""", '.mas')
        self.assertEqual([(r['context'], r['reference']) for r in rows],
                         [('optional.static', 'fixture.mas:5')])

    def test_dynamic_mason_identifier_slots_keep_static_captions_extractable(self):
        source = """<script>
var <% $js_object_name %> = new CXGN.Page.Form.JSFormPage('<% $object_id %>');
<% $js_object_name %>.render();
SGN.i18n.p('form.static', 'Loading');
</script>"""
        rows = self.records(source, '.mas')
        self.assertEqual([(r['context'], r['reference']) for r in rows],
                         [('form.static', 'fixture.mas:4')])
        with self.assertRaisesRegex(ExtractionError, 'dynamic Mason output'):
            self.records("<script>SGN.i18n.p('bad', <% $label %>);</script>", '.mas')

    def test_adjoining_mason_identifier_fragments_preserve_static_calls(self):
        source = """<script>
function <% $div_name %>_getProps() {
  SGN.i18n.p('props.load', 'Loading properties');
}
<% $div_name %>_getProps();
const prefix_<% $object_id %> = 1;
</script>"""
        rows = self.records(source, '.mas')
        self.assertEqual([(r['context'], r['reference']) for r in rows],
                         [('props.load', 'fixture.mas:3')])
        with self.assertRaisesRegex(ExtractionError, 'dynamic Mason output'):
            self.records("<script>SGN.i18n.p('bad', 'Name <% $id %>_suffix');</script>", '.mas')

    def test_extensionless_mason_uses_same_mixed_language_masking(self):
        source = """<%doc>
SGN.i18n.p('fake.document', 'Ignored');
</%doc>
<%init>
my $label=$c->i18n->p('handler.server', 'Server label');
</%init>
<script>
const translator=SGN.i18n;
const value="<% $c->i18n->p('handler.inline', 'Inline label') |h %>";
% if ($enabled) {
translator.p('handler.client', 'Client label');
% }
</script>
"""
        for name in ('mason/search/autohandler','mason/site/error/dhandler'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root=Path(directory);path=root/name;path.parent.mkdir(parents=True);path.write_text(source)
                rows=extract_file(path,root)
                self.assertEqual({row['context'] for row in rows},{'handler.server','handler.inline','handler.client'})
                self.assertEqual({row['reference'] for row in rows},{name+':5',name+':9',name+':11'})
                path.write_text('<script>const emoji="🌱"; SGN.i18n.p("ctx", "Hello <% $name %>");</script>')
                with self.assertRaisesRegex(ExtractionError,'dynamic Mason output'):
                    extract_file(path,root)


    def test_globals_reviewed_fallback_aliases_and_constructor(self):
        rows = self.records('''SGN.i18n.p('direct', 'Text');
if (!window.SGN.i18n) {window.SGN.i18n={p:function(c,s){return s;}};} window.SGN.i18n.p('window', 'Text');
const i18n = window.SGN && SGN.i18n;
i18n.np('count', '%{count} item', '%{count} items', count, {count});
const creationI18n = (window.SGN && window.SGN.i18n) || {p: function (ctx, source) {return source;}};
creationI18n.p('fallback', 'Hello, %{name}.', {name});
const translator = new SGN.I18N(payload);
const second = translator;
second.p('', 'Вітаємо 🌱');
new window.SGN.I18N(payload).p('constructor', 'Text');
''')
        self.assertEqual([row['context'] for row in rows], ['direct', 'window', 'count', 'fallback', '', 'constructor'])
        self.assertEqual(rows[2]['plural'], '%{count} items')
        self.assertEqual(rows[4]['source'], 'Вітаємо 🌱')
        self.assertEqual(rows[4]['reference'], 'fixture.js:9')

    def test_lexical_shadowing_parameters_loops_catch_and_hoisted_var(self):
        rows = self.records('''const i18n = SGN.i18n;
{ let i18n = widget; i18n.p('property', dynamic); }
function shadow(i18n) { i18n.p('parameter', dynamic); }
function hoisted() { SGN.i18n.p('localnamespace', dynamic); var SGN = widget; }
function windowShadow(window) { window.SGN.i18n.p('localwindow', dynamic); }
for (let i18n of widgets) { i18n.p('loop', dynamic); }
try {} catch (i18n) { i18n.p('catch', dynamic); }
function nested() { i18n.p('closure', 'Text'); }
i18n.p('outer', 'Text');
''')
        self.assertEqual([row['context'] for row in rows], ['closure', 'outer'])

    def test_comments_regex_literal_and_template_data_are_opaque(self):
        rows = self.records(r'''// SGN.i18n.p('comment', 'Ignored');
/* SGN.i18n.p('block', 'Ignored'); */
const regex = /SGN.i18n.p\('regex', 'Ignored'\)/g;
const quoted = "SGN.i18n.p('quote', 'Ignored')";
const template = `SGN.i18n.p('template', 'Ignored') ${widget.p('widget', dynamic)}`;
widget.p('widget', dynamic);
SGN.i18n.p('real', 'English');
''')
        self.assertEqual([row['context'] for row in rows], ['real'])
        self.assertEqual(rows[0]['reference'], 'fixture.js:7')

    def test_literal_unicode_escapes_constant_template_and_real_template_expression(self):
        rows = self.records(r'''SGN.i18n.p('', '\u0412\u0456\u0442\u0430\u0454\u043c\u043e \u{1F331}');
SGN.i18n.p('template.constant', `Quote: " and ' \nLine`);
const label = `Prefix ${SGN.i18n.p('nested.real', 'Nested text')}`;
''')
        self.assertEqual(rows[0]['source'], 'Вітаємо 🌱')
        self.assertEqual(rows[1]['source'], 'Quote: " and \' \nLine')
        self.assertEqual([row['context'] for row in rows], ['', 'template.constant', 'nested.real'])

    def test_dynamic_concat_interpolated_template_and_nonstring_fail(self):
        sources = ["SGN.i18n.p('ctx', english);", "SGN.i18n.p('ctx', 'Prefix '+name);",
                   "SGN.i18n.p('ctx', `Hello ${name}`);", "SGN.i18n.p(context, 'English');",
                   "SGN.i18n.np('ctx', 'Item', plural, n);", "SGN.i18n.p('ctx', /regex/);",
                   "SGN.i18n.p('ctx');", "SGN.i18n.p('ctx', '');"]
        for source in sources:
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records(source)

    def test_known_receiver_reassignment_chains_methods_and_destructuring_fail(self):
        sources = ["let i18n=SGN.i18n; i18n=widget; i18n.p('ctx','Text');",
                   "var i18n=widget; i18n=SGN.i18n; i18n.p('ctx','Text');",
                   "var i18n=SGN.i18n; var i18n=SGN.i18n; i18n.p('ctx','Text');",
                   "const i18n=SGN.i18n; i18n.p=widget.p; i18n.p('ctx','Text');",
                   "SGN.i18n=widget; SGN.i18n.p('ctx','Text');",
                   "if (!other) {SGN.i18n={p:function(c,s){return s;}};} SGN.i18n.p('ctx','Text');",
                   "if (!SGN.i18n) {} else {SGN.i18n={p:function(c,s){return s;}};} SGN.i18n.p('ctx','Text');",
                   "SGN.i18n.forLocale(locale).p('ctx','Text');",
                   "const i18n=SGN.i18n; i18n.unknown().p('ctx','Text');",
                   "const i18n=SGN.i18n || widget; i18n.p('ctx','Text');",
                   "{const undefined=widget; const i18n=SGN.i18n || undefined; i18n.p('ctx','Text');}",
                   "const i18n=choose ? SGN.i18n : widget; i18n.p('ctx','Text');",
                   "const {p}=SGN.i18n; p('ctx','Text');",
                   "const translate=SGN.i18n.p; translate('ctx','Text');",
                   "SGN.i18n[method]('ctx','Text');"]
        for source in sources:
            with self.subTest(source=source), self.assertRaises(ExtractionError):
                self.records(source)

    def test_static_computed_and_optional_receivers(self):
        rows = self.records("SGN['i18n']['p']('computed','Text'); window.SGN?.i18n?.p('optional','Text');")
        self.assertEqual([row['context'] for row in rows], ['computed', 'optional'])

    def test_syntax_errors_fail_and_modules_are_parsed(self):
        for source in ["const x = ; SGN.i18n.p('ctx','Text');", "SGN.i18n.p('ctx', 'Text'", "let = /unterminated;"]:
            with self.subTest(source=source), self.assertRaisesRegex(ExtractionError, 'syntax error'):
                self.records(source)
        for suffix in ['.mjs', '.cjs', '.js']:
            source = "import x from 'module'; SGN.i18n.p('module','Text');" if suffix != '.cjs' else "const x = require('module'); SGN.i18n.p('module','Text');"
            with self.subTest(suffix=suffix):
                self.assertEqual(self.records(source, suffix)[0]['context'], 'module')
        with self.assertRaisesRegex(ExtractionError, 'syntax error'):
            self.records("import x from 'module'; SGN.i18n.p('module','Text');", '.cjs')
        self.assertEqual(self.records("SGN.i18n.p('commonjs','Text'); return;", '.cjs')[0]['context'], 'commonjs')

    def test_invalid_control_or_lone_surrogate_literals_fail(self):
        for source in [r"SGN.i18n.p('ctx','\u0000');", r"SGN.i18n.p('ctx','\u0004');", r"SGN.i18n.p('ctx','\uD800');"]:
            with self.subTest(source=source), self.assertRaisesRegex(ExtractionError, 'invalid context'):
                self.records(source)

    def test_mason_masks_whole_expressions_and_control_lines_preserving_lines(self):
        rows = self.records('''<%init>
my $title=$c->i18n->p('page.server', 'Server text');
</%init>
<script>
const value = <% $number %>;
const quoted = "<% $c->i18n->p('page.inline', 'Inline text') |h %>";
% if ($enabled) {
SGN.i18n.p('page.js', 'Client text');
% }
</script>
''', '.mas')
        self.assertEqual({row['context'] for row in rows}, {'page.server', 'page.inline', 'page.js'})
        self.assertEqual({row['reference'] for row in rows}, {'fixture.mas:2', 'fixture.mas:6', 'fixture.mas:8'})

    def test_dynamic_mason_inside_marked_literal_fails_even_after_emoji(self):
        for message in ["'Hello <% $name %>'", "`Hello <% $name %>`"]:
            source = '<script>const emoji="🌱"; SGN.i18n.p("ctx", '+message+');</script>'
            with self.subTest(message=message), self.assertRaisesRegex(ExtractionError, 'dynamic Mason output'):
                self.records(source, '.mas')

    def test_classic_mason_scripts_share_alias_but_modules_are_independent(self):
        rows = self.records('''<script>const i18n=SGN.i18n;</script>
<p>Page HTML</p>
<script>i18n.p('shared', 'Text');</script>
<script type="module">const i18n=widget; i18n.p('modulewidget', dynamic); SGN.i18n.p('module','Text');</script>
''', '.mas')
        self.assertEqual({row['context'] for row in rows}, {'shared', 'module'})
        self.assertEqual({row['reference'] for row in rows}, {'fixture.mas:3', 'fixture.mas:4'})

    def test_source_is_never_executed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); marker = root / 'executed'; source = root / 'fixture.cjs'
            source.write_text("require('node:fs').writeFileSync(" + repr(str(marker)) + ", 'bad'); SGN.i18n.p('safe','Text');")
            self.assertEqual(extract_file(source, root)[0]['context'], 'safe')
            self.assertFalse(marker.exists())

    def test_configured_argv_unavailable_backend_and_protocol_are_not_silent(self):
        for configured in ['node helper.cjs', '[]', '["nonexistent-sgn-i18n-js-parser"]', '[false]']:
            with self.subTest(configured=configured), patch.dict(os.environ, {'SGN_I18N_JAVASCRIPT_COMMAND': configured}), self.assertRaises(ExtractionError):
                self.records("SGN.i18n.p('ctx','Text');")
        for output in ['not json', '{"schema":1,"parser":"Acorn","parserVersion":"unknown","records":[]}', '{"schema":true,"parser":"Acorn","parserVersion":"8.18.0","records":[]}']:
            with self.subTest(output=output), patch('extract.subprocess.run', return_value=SimpleNamespace(returncode=0, stdout=output, stderr='')), self.assertRaises(ExtractionError):
                javascript_extract('fixture.js', [{'source': "SGN.i18n.p('ctx','Text');", 'line_offset': 0}])

    def test_actual_marked_native_sources_and_call_locations(self):
        expected = {'js/source/legacy/CXGN/Trial.js': 40}
        for relative, count in expected.items():
            with self.subTest(relative=relative):
                rows = extract_file(PROJECT_ROOT / relative, PROJECT_ROOT)
                self.assertEqual(len(rows), count)
        relative = 'js/source/legacy/CXGN/BreedersToolbox/AddTrial.js'
        path = PROJECT_ROOT / relative
        rows = extract_file(path, PROJECT_ROOT)
        self.assertEqual(len({row['context'] for row in rows if row['context'].startswith('trial.create.design.description.')}), 13)
        self.assertIn('trial.create.review.treatment_summary', {row['context'] for row in rows})
        lines = path.read_text().splitlines()
        for row in rows:
            self.assertIn(row['context'], lines[int(row['reference'].rsplit(':', 1)[1]) - 1])


if __name__ == '__main__':
    unittest.main()
