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

## Start here

| Task | Instructions | Required tools |
| --- | --- | --- |
| Enable a ready language pack | Steps below | Python 3.9+ on Linux/POSIX, standard library only |
| Translate or update wording | [Translator workflow](TRANSLATOR.md) and [review batches](REVIEW.md) | Python 3.9+ and GNU gettext |
| Add translated messages to code | [Developer chapter](DEVELOPER.md) | Application tests and source extractors |
| Build or publish a user manual | [Manual instructions](../r_markdown_docs/i18n/README.md) | Bookdown; Chromium for PDF only |

Use `bin/i18n/sgn-i18n COMMAND [OPTIONS]` for language tools.
`--help` lists commands; `COMMAND --help` lists that command's options.
Run examples from the application root, or use an absolute tool path.
Source commands accept `--root /path/to/source` after the command.
Ready packs and frozen-release builds do not need source extractors.

## Enable a ready language pack

1. Obtain the package matching the application release and the supplied
   `bin/i18n` tools through the normal trusted release channel.
2. Install and activate it in a separate writable store:

   ```sh
   bin/i18n/sgn-i18n install --pack /release/uk-pack --root /srv/sgn-language-store
   bin/i18n/sgn-i18n activate --locale uk --hash CATALOG_SHA256 \
     --root /srv/sgn-language-store
   ```

   Replace `CATALOG_SHA256` with the `installed` value printed by `install`.
   Both commands validate the package; a separate `validate` is optional.
3. Add these settings to `sgn_local.conf`, then restart the application using
   the site's normal service procedure:

   ```text
   i18n_enabled 1
   i18n_enabled_locales en,uk
   i18n_catalog_dir /srv/sgn-language-store/active
   ```

   Install and activate each additional language, then add its tag to
   `i18n_enabled_locales`. Use the absolute store path visible **inside the
   application container**. Mount the whole store directory. New activations use
   relative internal links, so the host and container mount paths can differ.
4. Open a new page and choose the language immediately left of Login. Check
   a translated caption and the page's `Content-Language` and HTML `lang`/`dir`.
   A missing or corrupt pack is omitted from the selector; other installed
   languages remain available. See [debugging](DEVELOPER.md#diagnose-english-text-or-an-unexpected-language).

The default remains English. Preference order is query `lang`,
`X-SGN-Locale`, saved browser cookie, browser language, site default, then
English. The selector saves a preference and removes an old query override;
it does not change access rights or data.

For a catalog update, repeat `install` and `activate`. Subsequent requests use
it without an application restart. To undo the latest activation:

```sh
bin/i18n/sgn-i18n rollback --locale uk --root /srv/sgn-language-store
```

To disable the feature, set `i18n_enabled 0` and restart the application.
English then needs no catalog files. Keep the store for later reuse or rollback.

## Optional site settings

The three settings above are sufficient. Change these only when needed:

| Setting | Default | When to change it |
| --- | --- | --- |
| `i18n_default_locale` | `en` | Set a different fallback when no browser preference matches; it does not force every user into one language. |
| `i18n_manual_base_url` | `https://solgenomics.github.io/sgn` | Point to a separately published multilingual manual root. |
| `i18n_manual_locales` | `en` | List only manual languages actually published at that root. Interface packs do not publish manuals. |

For a closed-site reverse proxy, allow the exact UI-only GET/HEAD
`/i18n/runtime.js` and `/i18n/bootstrap.js` resources, and POST `/i18n/language`
on the login page. Preserve authentication for other paths. These handlers
serve trusted runtime code, message data and a validated preference cookie;
they do not expose breeding records. Prototype/test-only demonstration routes
are not part of this contribution.

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
application code. It requires Python 3.9+, GNU gettext (`msgfmt`, `msgmerge`), Perl
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
bin/i18n/sgn-i18n init --locale fr --direction ltr \
  --plural-forms 'nplurals=2; plural=(n > 1);' --name 'Français' \
  --output locale/fr/LC_MESSAGES/sgn.po
```

Translate all required forms, preserve variables, build and test the pack, then
add its tag to `i18n_enabled_locales`. When source English changes, merge and
review new/fuzzy entries before rebuilding. Runtime JSON is generated output,
not translator-authored code. See [the translator/operator procedure](TRANSLATOR.md)
for external workspaces, validation, installation and activation/rollback.

## Design and review changes

This contribution includes the interface, Ukrainian/Spanish/Arabic gettext
catalogs and all 29 user-manual chapters per language. It is related to
[translation issue #5915](https://github.com/solgenomics/sgn/issues/5915).
The following changes address the review and simplify setup and maintenance:

- **One browser API:** `SGN.t` and `SGN.tn` provide short calls and complete
  English fallback through the ordinary shared script. Trial uses those helpers
  instead of publishing a second, incomplete global translator. Its native save
  payload and locale header remain intact. Catalogs remain one validated
  dictionary rather than another executable translation backend.
- **Release-based catalogs:** the source builder freezes messages and workflow
  assignments once per application release. Translators work with external PO
  files and the frozen release, without parsing application source. Operators
  use the common launcher and three standard-library modules; ready-pack
  installation needs no Node, Acorn, gettext, Perl or R. Installation is
  `install`, then `activate`, using the hash from the install receipt.
- **Explicit settings and commands:** the quickstart requires only the enabled
  flag, language allow-list and active catalog path. Optional defaults and
  published-manual settings are separate. Task-specific help and
  `COMMAND --root PATH` use one entry point; earlier direct tool syntax remains
  compatible. Configuration changes require the normal application restart;
  data-only catalog activation affects subsequent requests.
- **Portable, recoverable packages:** new runtime and selector pointers are
  relative within the whole store, so its container mount path can differ from
  the operator's path. Re-activating an older selected hash updates absolute
  pointers without adding an activation-history event. Validate, activate and
  roll back through the supplied tools; checksums, immutable request snapshots
  and atomic generation/history changes protect the working site. Interrupted
  first activation and legacy-store migration have explicit recovery journals.
- **Predictable language selection:** the selector sits immediately left of
  Login. Applying a choice preserves the query and section anchor and removes
  a stale language override. Disabled pages omit both optional locale-resource
  requests. Missing or corrupt configured packs log their locale, store and
  reason once per request; an unavailable regional pack does not hide an
  installed, configured parent language.
- **Standard development workflow:** tools live under `bin/i18n`; the
  [developer chapter](DEVELOPER.md) covers complete messages, escaping and
  debugging. Shared format rules, standard argparse and bounded terminology
  review batches avoid extra configuration and repeated manual catalog work.
  The official developer wiki has not been edited by this contribution.
- **Independent manuals:** language builds and tests do not start the
  application. Explicit language builds require an absolute output outside the
  manual sources; help and path checks prevent accidental overwrites. The
  original no-argument English build remains supported. Language navigation
  preserves chapter/section and new-tab actions; explicit English metadata,
  Arabic RTL layout and static print figures are included.

Interface and manual sources are delivered together. The release contract also
supports separate catalog/manual repositories, but repository ownership and
hosting remain maintainer decisions. No separate repository is required or
created by this contribution. Existing documentation CI retains its English
publication path; multilingual documentation publication is a separate
maintainer action. Interface pack activation does not publish a manual.

## Validation and current limits

The 2026-11-03 local qualification passed 60 native files / 2,311 top-level checks,
128 Python tool checks, 133 R checks and four armed Chromium source checks.
Mason header/request tests cover enabled and disabled behavior, missing packs
and regional fallback. A whole-source Trial regression exercises the actual
edit/save callback, canonical field keys, literal Unicode/markup, zero and
empty-date behavior, locale headers, plain messages and plural fallback in
three runtime modes. Store tests cover earlier absolute selectors, relative
selectors, changed mount paths, unchanged activation history and rollback;
the actual Perl and R APIs loaded all three packs at a different container path.

All 15,398 message identities, 90 compiled JSON/index files and three package
hashes matched the previous qualified version after the simplification; PO/POT
changes contain source references only. Black 26.1.0, Ruff 0.14.14, isort and
pylint passed all 20 Python tool files; root README Markdown, formatting and
terminology checks passed. The [validation record](VALIDATION.md) maps each
requirement to its evidence and gives reproduction commands.

Four HTML readers and three translated PDFs were built and reviewed during the
earlier qualification. Scientific examples and chapter text are preserved;
English, Arabic and the original no-argument English HTML builds passed again.
Generated HTML, PDFs, catalogs, package stores and reports remain outside Git.
Earlier PostgreSQL phenotype regressions passed 277 assertions and controlled
stock-property checks passed 25; these are separate from the current local
request and tool checks.

The catalogs and manuals are machine-generated drafts requiring native-speaker
and breeder review. Each current language has 15,397 translated identities and
one whole English fallback for the updated blank/`NA`/`.` import explanation.
Filled coverage is not linguistic or scientific approval. Country-name sources
and licensing are retained in [translation sources](TRANSLATION_SOURCES.md).

Two optional local probes remain skipped: the source-path calendar dependency
probe and opt-in POD coverage. The earlier fixture bootstrap emitted an
`AddCascadeDeletes` foreign-key diagnostic for absent `md_files.file_id=2` and
continued. A clean full fixture bootstrap and full authenticated application
browser acceptance are not claimed. Each newly published revision must receive
its own hosted CI results. R support is an explicit presentation API; existing
scientific R calculations are not newly instrumented or qualified by it.

Rollback uses the previous immutable package without restarting the application,
or `i18n_enabled 0` with the normal restart. Documentation can return to its
previous published artifact. Stored scientific data, IDs, units, import/export
fields, permissions and schema remain unchanged.
