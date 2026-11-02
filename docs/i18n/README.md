# SGN interface internationalization

This optional presentation layer supplies request-scoped translations for the
current SGN interface. English remains the default and fallback. Ukrainian,
Spanish and Arabic PO catalogs include machine-generated translations and require
language and breeding-terminology review. Country display names also include
attributed iso-codes translations; see [translation sources](TRANSLATION_SOURCES.md). The source registry in `locale/sources.txt` defines
coverage; new or untranslated messages retain English.

Stored names, identifiers, ontology terms, numeric values, units, scientific
formulas, import/export headers and machine/API keys remain data. Translation
objects do not change process locale, authentication, permissions or schema.
Background solGS notification emails remain English. Translated user manuals are included in the same contribution; see
[manual sources and build commands](../r_markdown_docs/i18n/README.md).

Start with the [developer chapter](DEVELOPER.md) for short call examples and debugging.
Review machine-translated text in [small breeding workflows](REVIEW.md).

## Enable a language pack

Install a ready package matching the application release. Site operators need
Python and the supplied `bin/i18n` directory; they do not need extraction parsers,
Node, Perl, R or gettext for the ready-package lifecycle.

```sh
bin/i18n/sgn-i18n validate --pack /release/uk-pack
bin/i18n/sgn-i18n install --pack /release/uk-pack --root /srv/sgn-language-store
bin/i18n/sgn-i18n activate --locale uk --hash CATALOG_SHA256 \
  --root /srv/sgn-language-store
```

Use the exact hash printed by package creation. Set the site's local
configuration using an absolute path:

```text
i18n_enabled 1
i18n_default_locale en
i18n_enabled_locales en,uk,es,ar
i18n_catalog_dir /srv/sgn-language-store/active
```

Install each requested language before enabling it. Available languages appear
beside the login control; missing or corrupt packs do not block other languages.
Release builders freeze source messages once and translators build from that
snapshot; see [the complete release and operator procedure](TRANSLATOR.md).

`i18n_enabled 0` preserves the English interface. Locale choice is resolved for
one request from an explicit preference, the saved browser cookie, browser
language preferences, the configured default, then English. Only configured,
installed catalogs can supply translations. The selector remembers a preference;
it does not change a user's access rights or data.

For a closed-site reverse proxy, the login page also needs the exact UI-only
GET/HEAD `/i18n/runtime.js` and `/i18n/bootstrap.js` resources, and POST
`/i18n/language`. Preserve authentication for other paths. These handlers serve
trusted runtime code, message data and a validated preference cookie; they do
not expose breeding records. The prototype/test-only demonstration routes are
not part of this contribution.

## Catalog and rendering contract

Source catalogs use GNU gettext PO/POT: semantic `msgctxt`, exact English
`msgid`, optional English plural source, and named `%{name}` values. Server calls are `p(context, English, variables)` and
`np(context, singular, plural, count, variables)`. Keep complete messages and
preserve every named variable. Callers escape returned plain text for their
HTML, JavaScript, JSON or report sink; catalog text must never become code.

The compiler emits UTF-8, data-only JSON with schema/API version 1. Indexed
common/workflow partitions have an independent 2 MiB limit, source-message
provenance and checksums. Plural formulas are compiled to a bounded validated
AST; the runtime interprets the data without evaluating catalog code.
Empty, fuzzy, incomplete or source-mismatched records fall back as whole
messages to English. Unrelated source revisions do not invalidate an exact
compatible message. Optional `X-SGN-Language-Name` PO metadata supplies the
escaped native name shown in the language selector.

The Perl helper `SGN::I18N::translate` supports nullable translators and keeps
`$_`, `$@` and `$!` intact. Browser objects have independent locale/catalog
state. `R/lib/sgn_i18n.R` provides the same plain-text API without altering R's
process locale; see [the R contract](R.md). It does not translate identifiers or
numerical output, or automatically qualify an application calculation.

## Developer extraction tools

Extraction parses application source as data and never loads it as executable
application code. It requires Python 3, GNU gettext (`msgfmt`, `msgmerge`), Perl
with PPI 1.272/JSON::PP and Node with the qualified Acorn 8.18.0 parser. Install
the isolated JavaScript tool dependency with:

```sh
npm ci --prefix bin/i18n --ignore-scripts
```

Marked R extraction additionally uses a qualified R/jsonlite pair: 4.5.0/2.0.0 or 4.5.1/1.8.7.
Use a separate developer environment if the application uses another R version;
this feature does not require changing the scientific runtime. Trusted helper
argv overrides are `SGN_I18N_PERL_COMMAND`,
`SGN_I18N_JAVASCRIPT_COMMAND`, `SGN_I18N_R_EXTRACT_COMMAND` and
`SGN_I18N_R_DISCOVERY_COMMAND`. They are JSON argument arrays executed without a
shell. Parser failures or unsupported marked syntax fail explicitly rather than
silently producing an empty catalog.

Supported registered formats are Perl, standard JavaScript, marked R, Mason
`.mas` files and reviewed Mason `autohandler`/`dhandler` components. JSX,
TypeScript and additional translator-binding patterns need explicit adapters.

```sh
python3 bin/i18n/test_catalog.py
python3 bin/i18n/test_perl_extract.py
python3 bin/i18n/test_javascript_extract.py
python3 bin/i18n/test_r_extract.py
prove -Ilib -v t/unit/SGN/I18N.t t/unit/SGN/i18n-javascript.t
```

Use SGN's normal unit/fixture/mechanized test layout for application regressions.
Run the affected native request and data workflows in each supported locale,
plus English with the feature disabled. Browser qualification should include
asynchronous messages, long labels, narrow layouts, RTL and unchanged controls.
Never use real outbound email or scientific jobs merely to test wording.

## Add or update a language

A new language needs a PO file, native name, text direction and supported plural
rule. Already instrumented pages do not need to be rewritten. For example:

```sh
python3 bin/i18n/catalog.py init --locale fr --direction ltr \
  --plural-forms 'nplurals=2; plural=(n > 1);' --name 'Français' \
  --output locale/fr/LC_MESSAGES/sgn.po
```

Translate all required forms, preserve variables, build and test the pack, then
add its tag to `i18n_enabled_locales`. When source English changes, merge and
review new/fuzzy entries before rebuilding. Runtime JSON is generated output,
not translator-authored code. See [the translator/operator procedure](TRANSLATOR.md)
for external workspaces, validation, installation and activation/rollback.
