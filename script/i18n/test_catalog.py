#!/usr/bin/env python3
"""Focused compiler, marked-call extraction and offline pack lifecycle tests."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from catalog import compile_po, init_po, json_bytes, read_mo, source_revision, MAX_BYTES, MAX_PO_BYTES
from extract import ExtractionError, extract, extract_file, pot
from pack import validate_ast, validate_catalog, validate_pack


SCRIPT_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_ROOT.parents[1]


class ExtractionTests(unittest.TestCase):
    def test_mixed_mason_locations_comments_and_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'page.mas'
            path.write_text('''<p>SGN.i18n.p('fake','Data value')</p>
<%init>
# $c->i18n->p('comment', 'Ignored');
my $example = "->p('string', 'Ignored')";
my $label = $c->i18n->p('trial.name', 'Trial name');
</%init>
<span><% $c->i18n->p('trial.name', 'Trial name') | h %></span>
<script src="/x?lang=<% $c->i18n->locale |u %>">
// SGN.i18n.p('comment', 'Ignored');
SGN.i18n.np('trial.count', '%{count} trial', '%{count} trials', n, {count:n});
</script>
''', encoding='utf-8')
            records = extract_file(path, root)
            self.assertEqual([r['context'] for r in records], ['trial.name', 'trial.name', 'trial.count'])
            self.assertEqual([r['reference'] for r in records], ['page.mas:5', 'page.mas:7', 'page.mas:10'])
            self.assertEqual(len(extract(root, ['page.mas'])), 2)
            self.assertIn('#: page.mas:5 page.mas:7', pot(extract(root, ['page.mas'])))

    def test_dynamic_and_concatenated_sources_fail(self):
        for source in ["$c->i18n->p('ctx', $english);", "$c->i18n->p('ctx', 'prefix' . $value);", '$c->i18n->p("ctx", "Hello $name");']:
            with self.subTest(source=source), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / 'test.pm'
                path.write_text(source)
                with self.assertRaises(ExtractionError):
                    extract_file(path, root)

    def test_javascript_no_comment_or_literal_false_positive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'test.js'
            path.write_text('''/* SGN.i18n.p('a','Fake') */
const x = "SGN.i18n.p('a','Fake')";
SGN.i18n.p('real', 'Quote: \\' and \\"');
''')
            records = extract_file(path, root)
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]['context'], 'real')
            self.assertEqual(records[0]['source'], 'Quote: \' and "')


class CompilerTests(unittest.TestCase):
    messages = [{'context':'demo.label','source':'Trial name','plural':None,'references':['demo.mas:1']},
                {'context':'demo.count','source':'%{count} trial','plural':'%{count} trials','references':['demo.js:2']}]

    def compile(self, alter=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'es/LC_MESSAGES/sgn.po'
            path.parent.mkdir(parents=True)
            text = init_po(self.messages, 'es', 'ltr', 'nplurals=2; plural=(n != 1);')
            text = text.replace('msgid "Trial name"\nmsgstr ""', 'msgid "Trial name"\nmsgstr "Nombre del ensayo"')
            text = text.replace('msgstr[0] ""\nmsgstr[1] ""', 'msgstr[0] "%{count} ensayo"\nmsgstr[1] "%{count} ensayos"')
            path.write_text(alter(text) if alter else text, encoding='utf-8')
            return compile_po(PROJECT_ROOT, path, self.messages)

    def test_compile_named_vars_and_safe_plural_ast(self):
        catalog = self.compile()
        self.assertEqual(catalog['messages']['demo.label\x04Trial name']['forms'], ['Nombre del ensayo'])
        self.assertEqual(catalog['messages']['demo.count\x04%{count} trial']['forms'][1], '%{count} ensayos')
        self.assertEqual(catalog['sourceRevision'], source_revision(self.messages))
        validate_catalog(catalog)
        self.assertEqual(json_bytes(catalog), json_bytes(self.compile()))

    def test_fuzzy_and_empty_omitted(self):
        catalog = self.compile(lambda s:s.replace('msgctxt "demo.label"', '#, fuzzy\nmsgctxt "demo.label"').replace('msgstr[1] "%{count} ensayos"', 'msgstr[1] ""'))
        self.assertEqual(catalog['messages'], {})

    def test_placeholder_mismatch(self):
        with self.assertRaisesRegex(ValueError, 'placeholder'):
            self.compile(lambda s:s.replace('%{count} ensayos', '%{name} ensayos'))

    def test_menu_control_must_occur_once(self):
        self.messages = self.messages + [{'context':'file_list.datatable.length_menu',
            'source':'Show %{menu} entries', 'plural':None, 'references':[]}]
        def translated(text, form):
            return text.replace('msgid "Show %{menu} entries"\nmsgstr ""',
                                'msgid "Show %{menu} entries"\nmsgstr ' + json.dumps(form))
        validate_catalog(self.compile(lambda text: translated(text, 'Mostrar %{menu} entradas')))
        with self.assertRaisesRegex(ValueError, 'exactly one.*menu'):
            self.compile(lambda text: translated(text, 'Mostrar %{menu} %{menu} entradas'))

    def test_repeated_values_remain_legal_outside_the_menu_control(self):
        catalog = self.compile(lambda text: text.replace(
            'msgstr[0] "%{count} ensayo"', 'msgstr[0] "%{count} / %{count} ensayo"').replace(
            'msgstr[1] "%{count} ensayos"', 'msgstr[1] "%{count} / %{count} ensayos"'))
        validate_catalog(catalog)
        self.assertEqual(catalog['messages']['demo.count\x04%{count} trial']['forms'][0].count('%{count}'), 2)
        self.messages = self.messages + [{'context':'demo.menu_description',
            'source':'Show %{menu} entries', 'plural':None, 'references':[]}]
        validate_catalog(self.compile(lambda text: text.replace(
            'msgid "Show %{menu} entries"\nmsgstr ""',
            'msgid "Show %{menu} entries"\nmsgstr "Mostrar %{menu} / %{menu} entradas"')))

    def test_large_reference_comments_do_not_expand_runtime_catalog(self):
        comments = '#: translator/source/reference.mas:1\n' * (MAX_BYTES // 35 + 1)
        self.assertGreater(len(comments.encode()), MAX_BYTES)
        self.assertLess(len(comments.encode()), MAX_PO_BYTES)
        self.assertEqual(json_bytes(self.compile()),
                         json_bytes(self.compile(lambda text: comments + text)))

    def test_source_and_runtime_size_limits_remain_independent(self):
        with self.assertRaisesRegex(ValueError, 'PO exceeds size limit'):
            self.compile(lambda text: '# ' + 'x' * MAX_PO_BYTES + '\n' + text)
        with self.assertRaisesRegex(ValueError, 'invalid MO size'):
            read_mo(bytes(MAX_BYTES + 1))

    def test_compact_po_mo_cannot_build_an_uninstallable_json_catalog(self):
        # Manufactured data tests the actual GNU MO -> JSON -> pack boundary.
        # It is not a corpus benchmark or a count of application UI messages.
        messages = [{'context':'',
                     'source':f'Entry {i:05d} abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcd',
                     'plural':None, 'references':[]} for i in range(18000)]
        from extract import po_quote
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'es/LC_MESSAGES/sgn.po'
            path.parent.mkdir(parents=True)
            text = init_po([], 'es', 'ltr', 'nplurals=2; plural=(n != 1);', 'Español')
            text += ''.join('\nmsgctxt ""\nmsgid '+po_quote(m['source'])+
                            '\nmsgstr "Translation"\n' for m in messages)
            path.write_text(text, encoding='utf-8')
            self.assertLess(path.stat().st_size, MAX_BYTES)
            mo = Path(directory)/'sgn.mo'
            subprocess.run(['msgfmt', '--check', '-o', str(mo), str(path)], check=True,
                           capture_output=True, timeout=10)
            self.assertLess(mo.stat().st_size, MAX_BYTES)
            self.assertEqual(len(read_mo(mo.read_bytes())), 18001)
            with self.assertRaisesRegex(ValueError, 'independent pack size limit'):
                compile_po(PROJECT_ROOT, path, messages)

    def test_external_po_build_preserves_read_only_application_and_rejects_duplicate_locale(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base/'application'
            (root/'locale').mkdir(parents=True)
            (root/'static/js').mkdir(parents=True)
            (root/'static/js/sgn-i18n.js').symlink_to(PROJECT_ROOT/'static/js/sgn-i18n.js')
            source = root/'demo.js'
            source.write_text("SGN.i18n.p('demo.label', 'Trial name');\n")
            original_source = source.read_bytes()
            (root/'locale/sources.txt').write_text('demo.js\n')
            messages = extract(root, ['demo.js'])
            template = pot(messages)
            (root/'locale/sgn.pot').write_text(template)
            po = base/'translator/fr/LC_MESSAGES/sgn.po'
            po.parent.mkdir(parents=True)
            text = init_po(messages, 'fr', 'ltr', 'nplurals=2; plural=(n > 1);', 'Français')
            po.write_text(text.replace('msgid "Trial name"\nmsgstr ""', 'msgid "Trial name"\nmsgstr "Nom de l’essai"'))
            output = base/'compiled'
            command = [sys.executable, str(SCRIPT_ROOT/'catalog.py'), '--root', str(root),
                       'build', '--po', str(po)]
            run = subprocess.run(command+['--output', str(output)], capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stdout+run.stderr)
            catalog = json.loads((output/'fr/sgn.json').read_text())
            self.assertEqual(catalog['languageName'], 'Français')
            self.assertEqual(catalog['messages']['demo.label\x04Trial name']['forms'], ['Nom de l’essai'])
            validate_catalog(catalog)
            self.assertEqual(source.read_bytes(), original_source)
            self.assertEqual((root/'locale/sgn.pot').read_text(), template)
            self.assertFalse((root/'locale/fr').exists())
            rejected_output = base/'duplicate-output'
            duplicate = subprocess.run(command+['--po', str(po), '--output', str(rejected_output)],
                                       capture_output=True, text=True, timeout=10)
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn('duplicate locale', duplicate.stderr)
            self.assertFalse(rejected_output.exists())

    def test_unrelated_source_revision_does_not_disable_valid_records(self):
        catalog = self.compile(lambda s:s.replace(source_revision(self.messages), '0' * 64))
        self.assertEqual(len(catalog['messages']), 2)

    def test_invalid_po_and_code_header_rejected(self):
        for alter in [lambda s:s + '\nmsgid broken\n', lambda s:s.replace('plural=(n != 1)', 'plural=(process.exit(0))')]:
            with self.subTest(alter=alter), self.assertRaises(ValueError):
                self.compile(alter)

    def test_malformed_mo_and_ast_rejected(self):
        with self.assertRaises(ValueError):
            read_mo(b'garbage')
        for ast in [{'type':'NUM','val':-1}, {'type':'CALL','function':'eval'}, {'type':'VAR','code':'evil'}]:
            with self.assertRaises(ValueError):
                validate_ast(ast)

    def test_update_preserves_translations_and_updates_provenance_automatically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'locale/es/LC_MESSAGES').mkdir(parents=True)
            (root/'locale/sources.txt').write_text('demo.js\n')
            (root/'demo.js').write_text("SGN.i18n.p('demo.label', 'Trial name');\nSGN.i18n.np('demo.count', '%{count} trial', '%{count} trials', n, {count:n});\n")
            text = init_po(self.messages, 'es', 'ltr', 'nplurals=2; plural=(n != 1);')
            text = text.replace('msgid "Trial name"\nmsgstr ""', 'msgid "Trial name"\nmsgstr "Nombre del ensayo"')
            po = root/'locale/es/LC_MESSAGES/sgn.po'
            po.write_text(text)
            with (root/'demo.js').open('a') as handle:
                handle.write("SGN.i18n.p('demo.new', 'New message');\n")
            run = subprocess.run([sys.executable, str(SCRIPT_ROOT/'catalog.py'), '--root',str(root),'update'],capture_output=True,text=True,timeout=10)
            self.assertEqual(run.returncode,0,run.stderr)
            self.assertIn('msgstr "Nombre del ensayo"',po.read_text())
            self.assertIn('X-SGN-Source-Revision: '+source_revision(extract(root,['demo.js'])),po.read_text())
            self.assertIn('msgctxt "demo.new"',(root/'locale/sgn.pot').read_text())


class PackTests(unittest.TestCase):
    messages = CompilerTests.messages
    compile = CompilerTests.compile
    def command(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT_ROOT / 'pack.py'), *map(str,args)], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return json.loads(result.stdout) if ok else result.stderr

    def menu_catalog(self):
        catalog = self.compile()
        catalog['messages']['file_list.datatable.length_menu\x04Show %{menu} entries'] = {
            'plural':None, 'forms':['Mostrar %{menu} entradas']}
        return catalog

    def test_duplicate_menu_rejected_at_json_create_and_install_with_valid_checksum(self):
        import hashlib
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog = self.menu_catalog()
            source = root/'catalog.json'
            source.write_bytes(json_bytes(catalog))
            self.command('create','--catalog',source,'--output',root/'pack')
            catalog['messages']['file_list.datatable.length_menu\x04Show %{menu} entries']['forms'] = [
                'Mostrar %{menu} %{menu} entradas']
            with self.assertRaisesRegex(ValueError, 'exactly one.*menu'):
                validate_catalog(catalog)
            source.write_bytes(json_bytes(catalog))
            self.assertIn('exactly one',self.command('create','--catalog',source,'--output',root/'bad-create',ok=False))
            self.assertFalse((root/'bad-create').exists())
            (root/'pack/catalog.json').write_bytes(source.read_bytes())
            manifest = json.loads((root/'pack/manifest.json').read_bytes())
            manifest['catalogSha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
            (root/'pack/manifest.json').write_bytes(json_bytes(manifest))
            with self.assertRaisesRegex(ValueError, 'exactly one.*menu'):
                validate_pack(root/'pack')
            self.assertIn('exactly one',self.command('install','--pack',root/'pack','--root',root/'store',ok=False))
            self.assertFalse((root/'store/installed/es'/manifest['catalogSha256']).exists())

    def test_previously_installed_duplicate_menu_cannot_activate_or_roll_back(self):
        import hashlib
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog = self.menu_catalog()
            source = root/'good.json'
            source.write_bytes(json_bytes(catalog))
            good = self.command('create','--catalog',source,'--output',root/'good-pack')
            store = root/'store'
            self.command('install','--pack',root/'good-pack','--root',store)
            self.command('activate','--locale','es','--hash',good['catalogSha256'],'--root',store)
            active = store/'active/es/sgn.json'
            before_target = os.readlink(active)
            before_history = (store/'history/es.json').read_bytes()
            # Model a pack admitted by the previous validator; its checksum and
            # installed directory identity both match the malformed catalog.
            catalog['messages']['file_list.datatable.length_menu\x04Show %{menu} entries']['forms'] = [
                'Mostrar %{menu} %{menu} entradas']
            data = json_bytes(catalog)
            bad_hash = hashlib.sha256(data).hexdigest()
            bad = store/'installed/es'/bad_hash
            bad.mkdir()
            (bad/'catalog.json').write_bytes(data)
            manifest = {**good, 'catalogSha256':bad_hash}
            (bad/'manifest.json').write_bytes(json_bytes(manifest))
            self.assertIn('exactly one',self.command('activate','--locale','es','--hash',bad_hash,'--root',store,ok=False))
            self.assertEqual(os.readlink(active),before_target)
            self.assertEqual((store/'history/es.json').read_bytes(),before_history)
            history = [{'before':str((bad/'catalog.json').relative_to(store)),
                        'after':str(active.resolve().relative_to(store))}]
            (store/'history/es.json').write_bytes(json_bytes(history))
            before_history = (store/'history/es.json').read_bytes()
            self.assertIn('exactly one',self.command('rollback','--locale','es','--root',store,ok=False))
            self.assertEqual(os.readlink(active),before_target)
            self.assertEqual((store/'history/es.json').read_bytes(),before_history)

    def test_unknown_locale_install_activate_rollback_and_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog = self.compile()
            catalog['locale'] = 'zz-ZZ'
            file = root / 'catalog.json'
            file.write_bytes(json_bytes(catalog))
            pack = root / 'pack'
            manifest = self.command('create','--catalog',file,'--output',pack)
            store = root / 'store'
            self.command('install','--pack',pack,'--root',store)
            self.command('activate','--locale','zz-ZZ','--hash',manifest['catalogSha256'],'--root',store,'--expected-revision',catalog['sourceRevision'])
            self.assertEqual(json.loads((store/'active/zz-ZZ/sgn.json').read_text())['locale'], 'zz-ZZ')
            self.command('rollback','--locale','zz-ZZ','--root',store)
            self.assertFalse((store/'active/zz-ZZ/sgn.json').exists())
            (pack/'catalog.json').write_text('{}')
            self.command('install','--pack',pack,'--root',store,ok=False)

    def test_stale_activation_and_traversal_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root/'catalog.json'
            file.write_bytes(json_bytes(self.compile()))
            manifest = self.command('create','--catalog',file,'--output',root/'pack')
            self.command('install','--pack',root/'pack','--root',root/'store')
            self.command('activate','--locale','es','--hash',manifest['catalogSha256'],'--root',root/'store','--expected-revision','0'*64,ok=False)
            self.command('activate','--locale','../../bad','--hash',manifest['catalogSha256'],'--root',root/'store',ok=False)

    def test_tampered_ast_and_zero_modulus_rejected_even_with_valid_hash(self):
        for change in [('pluralAst', {'type':'NUM','val':0}), ('pluralForms', 'nplurals=2; plural=(n % 0);'),
                       ('pluralForms', 'nplurals=2; plural=(n % (n==5000 ? 0 : 1));'),
                       ('pluralForms', 'nplurals=2; plural=(n==5000 ? 7 : 0);')]:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                catalog = self.compile()
                file = root/'catalog.json'
                file.write_bytes(json_bytes(catalog))
                pack = root/'pack'
                manifest = self.command('create','--catalog',file,'--output',pack)
                catalog[change[0]] = change[1]
                data = json_bytes(catalog)
                (pack/'catalog.json').write_bytes(data)
                import hashlib
                manifest['catalogSha256'] = hashlib.sha256(data).hexdigest()
                (pack/'manifest.json').write_bytes(json_bytes(manifest))
                self.command('install','--pack',pack,'--root',root/'store',ok=False)

    def test_standard_empty_context_and_strict_integer_versions(self):
        self.messages = [{**message,'context':''} if message['context']=='demo.label' else message
                         for message in self.messages]
        catalog = self.compile()
        self.assertEqual(catalog['messages']['\x04Trial name']['forms'],['Nombre del ensayo'])
        validate_catalog(catalog)
        for field in ('schema','api'):
            invalid = {**catalog,field:True}
            with self.subTest(field=field), self.assertRaisesRegex(ValueError,'schema or API'):
                validate_catalog(invalid)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root/'test.pm'
            source.write_text("$c->i18n->p('', 'Trial name');")
            self.assertEqual(extract_file(source,root)[0]['context'],'')
            file = root/'catalog.json'
            file.write_bytes(json_bytes(catalog))
            manifest = self.command('create','--catalog',file,'--output',root/'pack')
            validate_pack(root/'pack')
            for field in ('schema','api'):
                (root/'pack/manifest.json').write_bytes(json_bytes({**manifest,field:True}))
                with self.subTest(field=field), self.assertRaisesRegex(ValueError,'integer versions'):
                    validate_pack(root/'pack')



class LanguageNameTests(unittest.TestCase):
    messages = CompilerTests.messages
    compile = CompilerTests.compile
    def test_native_name_is_optional_and_preserved_in_pack(self):
        self.assertNotIn('languageName', self.compile())
        catalog = self.compile(lambda s: s.replace('"Language: es\\n"', '"Language: es\\n"\n"X-SGN-Language-Name: Español\\n"'))
        self.assertEqual(catalog['languageName'], 'Español')
        validate_catalog(catalog)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            file = root/'catalog.json'
            file.write_bytes(json_bytes(catalog))
            run = subprocess.run([sys.executable,str(SCRIPT_ROOT/'pack.py'),'create','--catalog',str(file),'--output',str(root/'pack')],capture_output=True,text=True)
            self.assertEqual(run.returncode,0,run.stderr)
            self.assertEqual(validate_pack(root/'pack')[1]['languageName'],'Español')

    def test_invalid_native_names_rejected_by_init_and_pack(self):
        for value in ('', ' ', 'a'*201, 'bad\nname', 'bad\x00name', 'bad\x85X-SGN-Direction: rtl', True, ['name']):
            with self.subTest(value=value), self.assertRaises(ValueError):
                init_po(self.messages,'es','ltr','nplurals=2; plural=(n != 1);',value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_catalog({**self.compile(),'languageName':value})

class WorkflowPartitionTests(unittest.TestCase):
    def test_components_and_shared_controls_keep_exact_workflow_ownership(self):
        from catalog import partition_sources
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            owners = {'mason/trial.mas': 'trial_card', 'mason/shared.mas': 'shared_ui_libraries',
                      'mason/crosses/panel.mas': 'crosses',
                      'js/source/legacy/CXGN/CrossPanel.js': 'crosses', 'mason/seedlot.mas': 'seedlots',
                      'js/source/legacy/solGS/plot.js': 'solgs'}
            sources = {'mason/trial.mas': '<& /crosses/panel.mas &>',
                       'mason/crosses/panel.mas': '<script>new CXGN.CrossPanel(); solGS.plot()</script>'}
            for path in owners:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_text(sources.get(path, ''))
            (root / 'locale').mkdir()
            (root / 'locale/sources.txt').write_text('\n'.join(owners) + '\n')
            manifest = {'schema': 1, 'source_workflows': owners,
                        'common_sources': ['mason/shared.mas'], 'common_context_prefixes': []}
            path = root / 'locale/workflows.json'
            path.write_text(json.dumps(manifest))
            messages = [dict(context=name, source=name, plural=None, references=[source + ':1'])
                        for name, source in [('common.save','mason/shared.mas'), ('trial.title','mason/trial.mas'),
                                             ('cross.panel','mason/crosses/panel.mas'),
                                             ('cross.client','js/source/legacy/CXGN/CrossPanel.js'),
                                             ('seedlot.title','mason/seedlot.mas'),
                                             ('solgs.client','js/source/legacy/solGS/plot.js')]]
            parts = partition_sources(root, messages)
            self.assertEqual([m['context'] for m in parts['common']], ['common.save'])
            self.assertEqual({m['context'] for m in parts['trial_card']},
                             {'trial.title', 'cross.panel', 'cross.client', 'solgs.client'})
            self.assertNotIn('solgs.client', {m['context'] for m in parts['seedlots']})
            self.assertEqual(parts['shared_ui_libraries'], [])
            del manifest['source_workflows']['mason/seedlot.mas']
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'exactly cover'):
                partition_sources(root, messages)

    def test_default_build_writes_indexed_sections_and_removes_stale_full_output(self):
        from catalog import init_po
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'locale/uk/LC_MESSAGES').mkdir(parents=True)
            (root / 'static/js').mkdir(parents=True)
            (root / 'static/js/sgn-i18n.js').symlink_to(PROJECT_ROOT / 'static/js/sgn-i18n.js')
            (root / 'common.js').write_text("SGN.i18n.p('common.save', 'Save');")
            (root / 'trial.js').write_text("SGN.i18n.p('trial.title', 'Trial');")
            (root / 'locale/sources.txt').write_text('common.js\ntrial.js\n')
            (root / 'locale/workflows.json').write_text(json.dumps({'schema':1,
                'common_sources':['common.js'], 'common_context_prefixes':[],
                'source_workflows':{'common.js':'global','trial.js':'trial_card'}}))
            messages = extract(root, ['common.js','trial.js'])
            (root / 'locale/sgn.pot').write_text(pot(messages))
            text = init_po(messages, 'uk', 'ltr', 'nplurals=2; plural=(n != 1);')
            text = text.replace('msgid "Save"\nmsgstr ""', 'msgid "Save"\nmsgstr "Зберегти"')
            text = text.replace('msgid "Trial"\nmsgstr ""', 'msgid "Trial"\nmsgstr "Дослід"')
            (root / 'locale/uk/LC_MESSAGES/sgn.po').write_text(text)
            output = root / 'output'
            (output / 'uk').mkdir(parents=True)
            (output / 'uk/sgn.json').write_text('old generated output')
            run = subprocess.run([sys.executable, str(SCRIPT_ROOT/'catalog.py'), '--root', str(root),
                                  'build', '--output', str(output)], capture_output=True, text=True, timeout=15)
            self.assertEqual(run.returncode, 0, run.stderr)
            index = json.loads((output / 'uk/sgn/index.json').read_text())
            self.assertEqual([p['name'] for p in index['partitions']], ['common','global','trial_card'])
            self.assertFalse((output / 'uk/sgn.json').exists())
            combined = {}
            for part in index['partitions']:
                file = output / 'uk/sgn' / (part['name'] + '.json')
                self.assertLessEqual(file.stat().st_size, MAX_BYTES)
                combined.update(json.loads(file.read_text())['messages'])
            self.assertEqual(set(combined), {'common.save\x04Save','trial.title\x04Trial'})

    def test_gettext_partition_preserves_forms_and_rejects_filled_orphans(self):
        from catalog import compile_partition, init_po
        messages = [dict(context='common.save', source='Save', plural=None, references=['common.js:1']),
                    dict(context='trial.title', source='Trial', plural=None, references=['trial.js:1'])]
        with tempfile.TemporaryDirectory() as directory:
            po = Path(directory) / 'uk/LC_MESSAGES/sgn.po'
            po.parent.mkdir(parents=True)
            text = init_po(messages, 'uk', 'ltr', 'nplurals=2; plural=(n != 1);')
            text = text.replace('msgid "Save"\nmsgstr ""', 'msgid "Save"\nmsgstr "Зберегти"')
            text = text.replace('msgid "Trial"\nmsgstr ""', 'msgid "Trial"\nmsgstr "Дослід"')
            po.write_text(text)
            selected = compile_partition(PROJECT_ROOT, po, messages[:1])
            self.assertEqual(set(selected['messages']), {'common.save\x04Save'})
            self.assertEqual(selected['messages']['common.save\x04Save']['forms'], ['Зберегти'])
            self.assertEqual(compile_partition(PROJECT_ROOT, po, messages, invert=True)['messages'], {})
            po.write_text(text + '\nmsgctxt "orphan"\nmsgid "Other"\nmsgstr "Інше"\n')
            with self.assertRaisesRegex(ValueError, 'unregistered'):
                compile_partition(PROJECT_ROOT, po, messages, invert=True)


if __name__ == '__main__':
    unittest.main()
