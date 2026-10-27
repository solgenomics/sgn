# Translator and language-pack operator workflow

This guide covers the SGN interface localization layer. A translator owns an
external PO workspace; a site operator owns the language-pack store and site
configuration. Adding a language for already instrumented messages requires no
application source edit. The source allowlist defines the available messages;
it does not assert that every SGN page, calculation or report is translated.

Use the tools supplied with a frozen source release. The compiler needs Python
3, GNU gettext (`msgfmt`, `msgmerge`), Node and the qualified JavaScript parser,
and Perl/PPI/JSON::PP for registered Perl/Mason sources. Registered marked R
sources additionally need the qualified R helper. The [main guide](README.md)
describes the offline parser environment. Parser helpers must match the source
release; application code is parsed as data rather than executed during
extraction. No online translation service or global installation is required.

## Create and edit an external PO

Choose separate absolute paths outside the application checkout. Preserve the
original PO and use new build/pack output directories for each reviewed version.
The examples use French; its plural rule has two forms and treats zero as the
first form.

```sh
SGN_ROOT=/path/to/frozen-sgn-source
PO_WORKSPACE=/path/to/translator-workspace
PACK_STORE=/path/to/operator-owned-language-store
PO_FILE="$PO_WORKSPACE/fr/LC_MESSAGES/sgn.po"

python3 "$SGN_ROOT/script/i18n/catalog.py" --root "$SGN_ROOT" init \
  --locale fr --direction ltr --plural-forms 'nplurals=2; plural=(n > 1);' \
  --name 'Français' --output "$PO_FILE"
```

`init` refuses to overwrite existing translator work. `Language`, direction,
plural metadata and optional `X-SGN-Language-Name` describe the language. The
native name is display text, independent of identifiers, filenames and access
permissions. Locale identifiers remain safe ASCII tags such as `fr` or `fr-CA`;
native display names may contain Unicode.

Edit `msgstr` and every required `msgstr[n]` in a gettext editor. Preserve
`msgctxt`, exact English `msgid`/`msgid_plural` and named variables such as
`%{count}` or `%{name}`. Translate a complete sentence; variable order can change,
but variable names must remain identical in every form. Keep text plain: callers
escape it for their actual HTML/report sinks. Do not insert HTML entities to
pre-escape ordinary text.

Ordinary named values may repeat when the sentence needs them. The file-table
message `file_list.datatable.length_menu` / `Show %{menu} entries` is different:
`%{menu}` produces one interactive selector and must occur exactly once.
PO compilation and ready-JSON pack validation enforce this same requirement.
Create, install, activate and rollback reject a duplicated control even when
the catalog checksum is valid. An activation or rollback refusal preserves the
current language and history. Repair the translation and build/install/activate
a valid pack; previously installed files are retained for inspection.

Stock/accession names, identifiers, scientific codes, stored list types, machine
import headers, query/API field names, numerical values and measurements remain
application data. A translated sentence may include them through named variables;
their values are not translated. Leave a record empty or fuzzy when it still
needs review. The compiler omits the whole missing/fuzzy/incomplete record, so
the site retains its complete English fallback.

## Check and compile

There is no separate `catalog.py check` command. GNU gettext checks PO syntax and
headers; `build` additionally validates the source template, named-variable
parity, required plural forms and the bounded plural rule/AST contract.

```sh
msgfmt --check --output-file="$PO_WORKSPACE/fr-check.mo" "$PO_FILE"

python3 "$SGN_ROOT/script/i18n/catalog.py" --root "$SGN_ROOT" build \
  --po "$PO_FILE" --output "$PO_WORKSPACE/build-v1" --legacy-single-file
```

The MO above is a check artifact, not the deployed pack. The legacy runtime
output is `build-v1/fr/sgn.json`; `--legacy-single-file` selects this
data-only offline format. The default build uses the indexed common/workflow
layout when `locale/workflows.json` is present. `--po` is repeatable and compiles only the selected PO
files, including external files. Their `Language` header determines the locale;
directory names do not. Duplicate selected locale identifiers fail. The default
build without `--po` still discovers repository-local PO files.

The source release must provide a current `locale/sgn.pot`. A stale template
fails explicitly. A translator does not fix this by editing application code or
running `update` against other people's shipped PO files; obtain the current
source/POT from the release owner. The compiler validates all selected inputs
before writing runtime output and derives compiled provenance from its current
source-message set. `sourceRevision` is a semantic message-set SHA-256, not a Git
commit identifier.

## Create, install and activate a reviewed pack

```sh
python3 "$SGN_ROOT/script/i18n/pack.py" create \
  --catalog "$PO_WORKSPACE/build-v1/fr/sgn.json" \
  --output "$PO_WORKSPACE/pack-v1"

python3 "$SGN_ROOT/script/i18n/pack.py" install \
  --pack "$PO_WORKSPACE/pack-v1" --root "$PACK_STORE"
```

A pack contains only `manifest.json` and `catalog.json`. `create` prints the
catalog SHA-256; the manifest records that hash, locale, direction, domain,
schema/API and source revision. Preserve the exact output and use its hash for
activation. The hash establishes byte identity/integrity, not a publisher
signature; the operator still chooses the source of translations.

Installation copies a validated immutable version to
`installed/fr/<catalog-sha256>/`. It does not activate it. A new store is
initialized only in an empty directory and receives `.sgn-i18n-store`.

```sh
CATALOG_SHA=64_HEX_DIGITS_PRINTED_BY_CREATE
python3 "$SGN_ROOT/script/i18n/pack.py" activate \
  --locale fr --hash "$CATALOG_SHA" --root "$PACK_STORE"
```

Activation switches `active/fr/sgn.json` atomically under an advisory store lock
and records the previous target in `history/fr.json`. Re-activating the already
active hash is idempotent. An operator can add `--expected-revision` with an
approved semantic source revision for a strict rollout gate. That option is
deliberately stricter than ordinary runtime compatibility: unrelated source
changes do not invalidate otherwise matching messages, while changed English
source/plural identities retain English fallback.

## Enable the language and preserve the data namespace

The operator's site configuration must enable localization, point at the active
data root, and include the requested language tags. For a controlled parent-pack
example:

```text
i18n_enabled 1
i18n_catalog_dir /absolute/operator-store/active
i18n_default_locale en
i18n_enabled_locales en,fr-CA
```

Here the enabled request/selector tag is `fr-CA`, while the installed parent pack
is `fr`. The runtime loads that parent and retains requested `fr-CA` separately
from effective `fr`. The selector reads `Français` from pack metadata. When no
compatible active catalog exists, whole English fallback remains available and
the enabled selector entry displays its tag. A site may instead enable `fr`
directly. A tag that is not enabled does not become a valid preference merely
because its pack is installed.

The operator applies initial configuration through the site's normal startup
process. Pack activation then changes JSON data only; it does not require an
application source rebuild. A new HTTP request/bootstrap or ordinary page reload
reads the active version. An already loaded page's translator is not rewritten
in place.

Active targets are absolute symlinks into the store's `installed` directory.
A container must resolve that same absolute namespace. Mount the **whole store**
read-only at the same absolute host/container path and configure its `active`
child. An alias-only mount can leave absolute targets unresolved; a single-file
bind can retain an old inode instead of following an atomic activation. Do not
overlay application source with a language store or perform container source
hot patches.


## Update and roll back

For a translation-only correction, preserve the PO, edit the reviewed forms,
check it again, and build/create into new `build-v2`/`pack-v2` directories. Install
the new pack, confirm that installation alone left the old active target intact,
and activate its new hash. Keep both immutable versions available.

```sh
python3 "$SGN_ROOT/script/i18n/catalog.py" --root "$SGN_ROOT" build \
  --po "$PO_FILE" --output "$PO_WORKSPACE/build-v2" --legacy-single-file
python3 "$SGN_ROOT/script/i18n/pack.py" create \
  --catalog "$PO_WORKSPACE/build-v2/fr/sgn.json" \
  --output "$PO_WORKSPACE/pack-v2"
python3 "$SGN_ROOT/script/i18n/pack.py" install \
  --pack "$PO_WORKSPACE/pack-v2" --root "$PACK_STORE"

NEW_CATALOG_SHA=64_HEX_DIGITS_PRINTED_BY_CREATE
python3 "$SGN_ROOT/script/i18n/pack.py" activate \
  --locale fr --hash "$NEW_CATALOG_SHA" --root "$PACK_STORE"

python3 "$SGN_ROOT/script/i18n/pack.py" rollback \
  --locale fr --root "$PACK_STORE"
```

Rollback restores the previous target and exact bytes. Rolling back the first
activation removes its active link and returns to English fallback; installed
versions remain intact. The tool refuses rollback if the active target no longer
matches its recorded last activation. Inspect that state rather than deleting
catalogs or altering history by hand.

For an application source-release update, obtain its frozen source/POT and merge
into the external translator workspace after retaining the previous PO:

```sh
cp "$PO_FILE" "$PO_WORKSPACE/fr-before-source-update.po"
msgmerge --update --no-wrap --backup=none \
  "$PO_FILE" "$SGN_ROOT/locale/sgn.pot"
```

Review new/fuzzy forms, then repeat check/build/pack/install/activation using the
new source release's tools. A production source-release merge is distinct from
a translation-only pack change and requires its own site acceptance.

## Acceptance boundary

The controlled French fixture intentionally translates seven records. The
actual external-PO CLI lifecycle and real independent Perl, JavaScript and R
objects have passed all five states: installed/unactivated, active v1, active v2,
rollback to v1 and first-activation rollback to English. They verify parent
`fr-CA` fallback, counts 0/1/2/5, missing/stale whole-source fallback, Unicode
named values and independent English objects. R environment/process locale
invariance is part of that object-level gate.

A clean native HTTP/browser gate has also passed all five states using one
frozen committed image and container with the whole store mounted readonly at
its unchanged absolute path. Anonymous and authenticated users exercised actual
selector POST/cookies, preserved authentication sessions, requested/effective
locale tags, `fr-CA` parent fallback, native stock-search/AJAX scientific values,
and server/browser plurals at 0/1/2/5. Activation updates normal new requests;
rollback restores the exact old pack or whole English fallback. Nine application
source hashes and both installed pack byte sets remained unchanged. No unknown
browser, HTTP or first-party request failure was admitted.

Run the native SGN unit/fixture tests and affected browser workflows against the exact installed pack before release.
