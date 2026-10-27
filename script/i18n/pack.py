#!/usr/bin/env python3
"""Create, install, activate and roll back data-only translation packs locally."""
import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

from catalog import API, SCHEMA, LOCALE, MAX_BYTES, json_bytes, placeholders, parse_plural, validate_language_name, validate_control_placeholders

HASH = re.compile(r'^[a-f0-9]{64}$')
PROJECT_ROOT = Path(__file__).resolve().parents[2]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    if path.is_symlink() or path.stat().st_size > MAX_BYTES:
        raise ValueError('unsafe input file')
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = value
        return result
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def validate_ast(node, depth=0, count=None):
    count = [0] if count is None else count
    count[0] += 1
    if depth > 24 or count[0] > 128 or not isinstance(node, dict):
        raise ValueError('plural AST exceeds limits')
    kind = node.get('type')
    fields = {'VAR': (), 'NUM': ('val',), 'GROUP': ('expr',),
              'TERNARY': ('expr', 'truthy', 'falsey'),
              **{op: ('left', 'right') for op in ('OR', 'AND', 'LT', 'GT', 'LTE', 'GTE', 'EQ', 'NEQ', 'MOD')}}
    if kind not in fields or set(node) != {'type', *fields[kind]}:
        raise ValueError('unsupported plural AST node')
    if kind == 'NUM':
        if type(node['val']) is not int or not 0 <= node['val'] <= 1000000:
            raise ValueError('invalid plural constant')
    else:
        for field in fields[kind]:
            validate_ast(node[field], depth + 1, count)


def validate_catalog(catalog):
    if not isinstance(catalog, dict) or type(catalog.get('schema')) is not int or type(catalog.get('api')) is not int or catalog.get('schema') != SCHEMA or catalog.get('api') != API:
        raise ValueError('unsupported catalog schema or API')
    if 'languageName' in catalog:
        validate_language_name(catalog['languageName'])
    locale = catalog.get('locale', '')
    if not isinstance(locale, str) or not LOCALE.fullmatch(locale) or locale == 'en':
        raise ValueError('invalid catalog locale')
    revision = catalog.get('sourceRevision')
    if catalog.get('direction') not in ('ltr', 'rtl') or not isinstance(revision, str) or not HASH.fullmatch(revision):
        raise ValueError('invalid direction or source revision')
    if type(catalog.get('nplurals')) is not int or not 1 <= catalog['nplurals'] <= 6:
        raise ValueError('invalid plural count')
    if not isinstance(catalog.get('pluralForms'), str) or len(catalog['pluralForms']) > 512:
        raise ValueError('invalid plural metadata')
    validate_ast(catalog.get('pluralAst'))
    rule = parse_plural(PROJECT_ROOT, catalog['pluralForms'])
    if catalog['nplurals'] != rule['nplurals'] or catalog['pluralAst'] != rule['ast']:
        raise ValueError('plural formula and AST mismatch')
    messages = catalog.get('messages')
    if not isinstance(messages, dict) or len(messages) > 20000:
        raise ValueError('invalid messages')
    for key, value in messages.items():
        if not isinstance(key, str) or key.count('\x04') != 1 or '\x00' in key or not key.split('\x04', 1)[1]:
            raise ValueError('invalid message key')
        if not isinstance(value, dict) or set(value) != {'plural', 'forms'}:
            raise ValueError('invalid message record')
        plural = value['plural']
        if plural is not None and (not isinstance(plural, str) or not plural.strip()):
            raise ValueError('invalid plural source')
        forms = value['forms']
        if not isinstance(forms, list) or len(forms) != (catalog['nplurals'] if plural else 1):
            raise ValueError('incomplete translation record')
        variables = placeholders(key.split('\x04', 1)[1])
        if plural and placeholders(plural) != variables:
            raise ValueError('plural placeholder mismatch')
        if any(not isinstance(text, str) or not text.strip() or '\x00' in text or placeholders(text) != variables for text in forms):
            raise ValueError('invalid translation or placeholder mismatch')
        context, source = key.split('\x04', 1)
        validate_control_placeholders(context, source, forms)
    return catalog


def validate_pack(directory):
    if directory.is_symlink() or {p.name for p in directory.iterdir()} != {'manifest.json', 'catalog.json'}:
        raise ValueError('pack must contain only manifest.json and catalog.json')
    manifest = read_json(directory / 'manifest.json')
    if not isinstance(manifest, dict) or type(manifest.get('schema')) is not int or type(manifest.get('api')) is not int:
        raise ValueError('manifest schema and API must be integer versions')
    catalog = validate_catalog(read_json(directory / 'catalog.json'))
    expected = {'schema': SCHEMA, 'api': API, 'locale': catalog['locale'], 'direction': catalog['direction'],
                'domain': 'sgn', 'sourceRevision': catalog['sourceRevision'],
                'catalogSha256': sha((directory / 'catalog.json').read_bytes())}
    if manifest != expected:
        raise ValueError('pack manifest or catalog checksum mismatch')
    return manifest, catalog


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.i18n-', delete=False) as handle:
        name = handle.name
        handle.write(json_bytes(value))
        handle.flush()
        os.fsync(handle.fileno())
    try:
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def atomic_link(path, target):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not path.is_symlink():
        raise ValueError('refusing to replace a non-symlink active catalog')
    temporary = path.parent / ('.i18n-link-' + str(os.getpid()))
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def target_of(link, root):
    if not link.is_symlink():
        return None
    target = link.resolve(strict=True)
    if not target.is_relative_to(root / 'installed'):
        raise ValueError('active catalog escapes task-local store')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('create')
    create.add_argument('--catalog', type=Path, required=True)
    create.add_argument('--output', type=Path, required=True)
    for name in ('install', 'activate', 'rollback'):
        command = commands.add_parser(name)
        command.add_argument('--root', type=Path, required=True, help='isolated writable pack store, never the SGN source tree')
        if name == 'install':
            command.add_argument('--pack', type=Path, required=True)
        else:
            command.add_argument('--locale', required=True)
            if name == 'activate':
                command.add_argument('--hash', required=True, help='installed catalog SHA-256')
                command.add_argument('--expected-revision', help='refuse activation for another source revision')
    args = parser.parse_args()
    if args.command == 'create':
        catalog = validate_catalog(read_json(args.catalog))
        if args.output.exists():
            raise ValueError('refusing to overwrite an existing pack')
        data = json_bytes(catalog)
        manifest = {'schema': SCHEMA, 'api': API, 'locale': catalog['locale'], 'direction': catalog['direction'],
                    'domain': 'sgn', 'sourceRevision': catalog['sourceRevision'], 'catalogSha256': sha(data)}
        args.output.mkdir(parents=True)
        (args.output / 'catalog.json').write_bytes(data)
        (args.output / 'manifest.json').write_bytes(json_bytes(manifest))
        print(json.dumps(manifest))
        return
    root = args.root.resolve()
    if root == Path('/') or len(root.parts) < 3:
        raise ValueError('use a task-local pack store')
    root.mkdir(parents=True, exist_ok=True)
    if not (root / '.sgn-i18n-store').exists():
        if any(root.iterdir()):
            raise ValueError('refusing to initialize a nonempty directory as a pack store')
        (root / '.sgn-i18n-store').write_text('schema=1\n')
    with (root / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.command == 'install':
            manifest, _ = validate_pack(args.pack)
            destination = root / 'installed' / manifest['locale'] / manifest['catalogSha256']
            if destination.exists():
                existing, _ = validate_pack(destination)
                if existing != manifest:
                    raise ValueError('installed pack collision')
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                temporary = Path(tempfile.mkdtemp(dir=destination.parent, prefix='.install-'))
                (temporary / 'catalog.json').write_bytes((args.pack / 'catalog.json').read_bytes())
                (temporary / 'manifest.json').write_bytes(json_bytes(manifest))
                os.replace(temporary, destination)
            print(json.dumps({'installed': manifest['catalogSha256'], 'locale': manifest['locale']}))
        else:
            if not LOCALE.fullmatch(args.locale) or args.locale == 'en':
                raise ValueError('invalid locale')
            active = root / 'active' / args.locale / 'sgn.json'
            current = target_of(active, root)
            history_path = root / 'history' / (args.locale + '.json')
            history = read_json(history_path) if history_path.exists() else []
            if args.command == 'activate':
                if not HASH.fullmatch(args.hash):
                    raise ValueError('invalid catalog hash')
                destination = root / 'installed' / args.locale / args.hash
                manifest, _ = validate_pack(destination)
                if args.expected_revision and manifest['sourceRevision'] != args.expected_revision:
                    raise ValueError('source revision mismatch; activation refused')
                target = destination / 'catalog.json'
                if current == target:
                    print(json.dumps({'active': args.hash, 'unchanged': True}))
                    return
                history.append({'before': str(current.relative_to(root)) if current else None,
                                'after': str(target.relative_to(root))})
                atomic_json(history_path, history)
                atomic_link(active, target)
                print(json.dumps({'active': args.hash, 'locale': args.locale, 'catalogRoot': str(root / 'active')}))
            else:
                if not history or current is None or str(current.relative_to(root)) != history[-1]['after']:
                    raise ValueError('no matching activation to roll back; active state changed')
                previous = history[-1]['before']
                if previous:
                    target = (root / previous).resolve(strict=True)
                    if not target.is_relative_to(root / 'installed'):
                        raise ValueError('rollback target escapes store')
                    validate_pack(target.parent)
                    atomic_link(active, target)
                else:
                    active.unlink()
                atomic_json(history_path, history[:-1])
                print(json.dumps({'rolledBack': True, 'locale': args.locale, 'englishFallback': previous is None}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        raise SystemExit(str(error))
