# Translator and language-pack operator workflow

Developers mark complete interface messages in application source. The release
builder freezes the message set and workflow assignments once per application
release. Translators edit standard gettext PO files in their own workspace;
operators install ready, data-only packages. Routine source PRs do not require
finished translations or a rewrite of every language's PO file.

Stored names, identifiers, ontology terms, measurements, units, scientific
formulas and machine import/export/API keys remain data. Keep complete English
fallbacks. A missing, fuzzy or incomplete translation retains its whole English
message; a filled obsolete source or changed plural identity is rejected.

## Release builder: freeze source once

Only the source-release builder needs the qualified Perl/PPI, JavaScript/Acorn
and R extractors described in [README.md](README.md). Run from the frozen
application source, using its exact application version or commit:

```sh
SGN_ROOT=/path/to/frozen-sgn-source
RELEASE_DIR=/path/to/release-output

python3 "$SGN_ROOT/bin/i18n/catalog.py" --root "$SGN_ROOT" freeze \
  --application-version APPLICATION_VERSION_OR_COMMIT \
  --output "$RELEASE_DIR/release.json"
```

This creates `release.json` and its adjacent `release.pot`. The validated JSON
contains the application version, semantic message-set revision, source
references and complete partition assignments. Preserve the printed SHA-256 and
ship both files with the matching `bin/i18n` tool directory. Refusing to overwrite
an existing snapshot protects previously released translator inputs. Generated
snapshots, packs and reports belong outside application source control.

The snapshot hash establishes byte identity, not a publisher signature. Obtain
the release inputs and tools through the project's normal trusted release path.
The compiler rejects malformed snapshots, duplicate identities, a wrong semantic
revision or invalid/incomplete partition references before writing outputs.

## Translator: initialize or merge an external PO

A translator building from the frozen snapshot needs Python 3 and GNU gettext
(`msgfmt`, `msgcat`, `msgmerge`), without Node, Acorn, PPI, R or an application
checkout. The copied Python tool modules parse source only for the explicit
source-extraction commands; `init/build --release` never invokes those parsers.

```sh
I18N_TOOLS=/path/to/release-tools/bin/i18n
RELEASE_JSON=/path/to/release-output/release.json
PO_WORKSPACE=/path/to/translator-workspace
PO_FILE="$PO_WORKSPACE/fr/LC_MESSAGES/sgn.po"

python3 "$I18N_TOOLS/catalog.py" init --release "$RELEASE_JSON" \
  --locale fr --direction ltr --plural-forms 'nplurals=2; plural=(n > 1);' \
  --name 'Français' --output "$PO_FILE"
```

`init` refuses to overwrite existing work. For an existing language, preserve
the original PO and use GNU gettext to merge the next release's template:

```sh
cp "$PO_FILE" "$PO_WORKSPACE/fr-before-release-update.po"
msgmerge --update --no-wrap --backup=none \
  "$PO_FILE" /path/to/new-release/release.pot
```

The PO's `Language`, `X-SGN-Direction`, `Plural-Forms` and optional
`X-SGN-Language-Name` describe its locale. `Language` determines the output tag,
independently of the input filename. Locale tags are safe ASCII identifiers;
the native name is Unicode display text. Translate `msgstr` and every required
`msgstr[n]` in a gettext editor, preserving exact `msgctxt`, `msgid`,
`msgid_plural` and named values such as `%{count}` or `%{name}`.

Translate a whole sentence, allowing word and variable order to change. Keep
text plain, without HTML markup or pre-escaped entities; application callers
escape it for their actual destination. Ordinary variables may repeat. The
interactive `%{menu}` placeholder in `file_list.datatable.length_menu` and
`odk.table.length` must occur exactly once and must not introduce `_MENU_`.
Compiler and ready-package validation enforce the same rule.

Review terminology in small breeding workflows, using a shared glossary for
accessions, trials, plots, seedlots, crosses and observation variables. Review
uncertain and machine-generated text with a native speaker and a breeder.
Leave a record empty or fuzzy until it is ready for use. Filled translation
counts measure coverage; they do not certify linguistic or scientific quality.

## Translator or release builder: compile and package

```sh
python3 "$I18N_TOOLS/catalog.py" build --release "$RELEASE_JSON" \
  --po "$PO_FILE" --output "$PO_WORKSPACE/build-v1"

python3 "$I18N_TOOLS/pack.py" create \
  --catalog "$PO_WORKSPACE/build-v1/fr/sgn/index.json" \
  --output "$PO_WORKSPACE/pack-v1"

```

`--po` is repeatable; all selected locales are validated before build output is
written. The build report counts translated and English-fallback identities per
locale without double-counting messages used by several workflows. Standard PO
and gettext remain the translator format. The bounded, non-executable plural
parser emits the same AST as the application's pinned browser runtime, proves
all-count form bounds and rejects unsafe or unsupported formulas.

The normal output is an indexed common/workflow bundle. The index and every
partition have independent 2 MiB limits. The pack binds all file checksums and
its source revision in one manifest; one missing, extra, symlinked, mismatched or
conflicting member rejects the package. Preserve `catalogSha256` printed by
`create`: for an indexed package it identifies the complete file-hash set.

A small existing single-file catalog remains supported through
`build --legacy-single-file`, followed by `pack.py create --catalog .../fr/sgn.json`.
The full multilingual corpus must use indexed packages rather than increasing
the single-file limit.

## Operator: install, activate and roll back

Operators need Python's standard library and three files: `pack.py`,
`catalog_format.py` and `plural.py`. The installer does not import the builder
or source extractors. Ready
package validation, installation, activation and rollback require no Node,
gettext, Perl, R or application source. Use a separate writable store, preserve
both the current and previous immutable package, and keep its absolute path
stable when mounting it into a container.

```sh
PACK_STORE=/path/to/operator-language-store
python3 "$I18N_TOOLS/pack.py" install \
  --pack "$PO_WORKSPACE/pack-v1" --root "$PACK_STORE"

CATALOG_SHA=64_HEX_DIGITS_PRINTED_BY_CREATE
python3 "$I18N_TOOLS/pack.py" activate \
  --locale fr --hash "$CATALOG_SHA" --root "$PACK_STORE"

python3 "$I18N_TOOLS/pack.py" rollback --locale fr --root "$PACK_STORE"
```

`create` and `install` already validate their inputs; use `pack.py validate`
only to inspect a package without installing it.

Installation validates and copies the complete immutable package to
`installed/fr/<catalogSha256>/`; it does not change the selected language.
Activation validates its exact locale and hash again. A validated recovery journal
restores or reconciles an interrupted first activation or legacy-store migration
on the next operator command; unrelated missing paths never authorize recovery. An optional
`--expected-revision` requires the approved semantic message-set revision.
An unrelated source change does not ordinarily invalidate exact matching
messages; a strict revision rollout gate is an operator choice.

Each activation prepares a generation containing runtime pointers and its
history, then atomically replaces the one `active/fr` selector under a store
lock. A failed generation write or selector replacement preserves the previous
selected generation and its history. Re-activating the selected hash is
idempotent. Rollback selects the previous complete package; rolling back the
first activation selects an empty generation and returns to English fallback.
Installed packages are retained.

`history/fr.json` is a compatibility view into the selected generation. A legacy
single-file store is imported on its first state change; its installed packages,
old active directory and original history are preserved under `installed/`,
`legacy-active/` and `legacy-history/`. Failed first-migration selector changes
restore the old active directory. After migration, use the new tools; old tools
do not understand generation selectors. Do not edit selector links or history
by hand. The tool rejects inconsistent state and malformed rollback targets.

## Site configuration and verification

Use the site's normal startup configuration to enable the requested tags and
point it at the store's active root:

```text
i18n_enabled 1
i18n_catalog_dir /absolute/operator-language-store/active
i18n_default_locale en
i18n_enabled_locales en,fr-CA
```

A parent `fr` package can serve enabled `fr-CA`, preserving the requested tag
separately from its effective language. Installing a language does not grant
access rights or automatically enable it. Mount the **whole store** read-only
at the same absolute host/container path: generation and installed-package
symlinks must resolve inside that mount. A single-file bind can retain an old
inode. Do not overlay application source with translation data.

A new page request/bootstrap reads the selected package; an existing page's
translator is not rewritten in place. For a correction, retain the previous PO,
build and create into new `build-v2`/`pack-v2` paths, install, activate its new
hash, and verify a normal new request. Keep the exact release snapshot, package
hash, coverage report and human terminology-review result with release evidence.

Before release, exercise actual anonymous and authenticated pages, selector
POST/cookie behavior, parent-locale fallback, asynchronous errors, counts
0/1/2/5, narrow and RTL layouts, and unchanged breeding identifiers and values.
Check active v1, active v2, rollback to v1 and rollback to English. Source/parser
unit tests alone do not establish HTTP, browser or translation-quality acceptance.
