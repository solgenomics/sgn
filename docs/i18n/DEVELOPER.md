# Change interface text

For site setup, use [Turn on translations](README.md).
This guide is for developers. It is also the proposed internationalization
chapter for the [developer guide](https://github.com/solgenomics/sgn/wiki).

## 1. Add the message

Put the exact English text next to a descriptive context key.
Use a whole sentence and named values instead of joining sentence fragments.

```perl
my $caption = $c->i18n->p('trial.created', 'Created trial %{name}.', {name => $name});
```

```mason
<% $c->i18n->p('trial.created', 'Created trial %{name}.', {name => $name}) |h %>
```

```javascript
const caption = SGN.t('trial.created', 'Created trial %{name}.', {name});
element.textContent = caption;
const countText = SGN.tn('trials.count', '%{count} trial', '%{count} trials', count, {count});
```

```r
caption <- translator$p('trial.created', 'Created trial %{name}.', list(name = trial_name))
```

The result is plain text. Use `textContent`, `.text()` or the right escaping for
the output. Do not insert a translation into executable code or raw HTML.
Keep stored names, IDs, units, formulas, import/export headers and API keys as data.

## 2. Register a new source file

Add its path to `locale/sources.txt` and assign it to an existing group in
`locale/workflows.json`. An already registered file needs no new registration.
Register current first-party files, not deleted screens or vendor libraries.

Keep source text constant. Do not alias `SGN.t` or `SGN.tn` into local functions.
The extractor also accepts `window.SGN` and `globalThis.SGN`; a local variable
named `SGN` is not the shared translator.

## 3. Check the change

Run the affected native tests in `t/unit`, `t/unit_fixture` or `t/unit_mech`.
Check English with translations off and the supported languages with them on.
Use synthetic data, including Unicode names, `&`, literal HTML, zero and counts
1/2/5/21. Check narrow screens and Arabic layout. IDs, submitted fields and
scientific values must stay the same. Do not send real mail or start real
scientific jobs to check wording.

[Build a language pack](TRANSLATOR.md) for a release. A normal code PR does not
need completed translations for every language.

## If text stays English

1. Check the three [site settings](README.md#4-change-the-site-settings).
2. Check that the requested language is installed and activated. Read the server
   log for a missing or corrupt pack and its path.
3. Open a new page. Existing pages keep their original translator.
4. Check that context, English source and plural source match the PO exactly.
   Empty, fuzzy, incomplete or changed messages use whole English fallback.
5. For browser-only text, check that `/i18n/runtime.js` and
   `/i18n/bootstrap.js` load and include the page's message group.

For deeper checks, inspect `Content-Language`, HTML `lang`/`dir` and
`data-sgn-locale`. Language preference order is query `lang`, `X-SGN-Locale`,
cookie, browser preference, site default, then English. A regional request can
use an installed parent language.

## Optional site settings

These are not needed for the normal setup:

| Setting | Default | Purpose |
| --- | --- | --- |
| `i18n_default_locale` | `en` | Language used when no user or browser preference matches. It does not force all users into one language. |
| `i18n_manual_base_url` | `https://solgenomics.github.io/sgn` | Root URL of the published manual. |
| `i18n_manual_locales` | `en` | Languages already published at that URL. |

For example, set `i18n_manual_locales en,uk,es,ar` only after publishing all four
manuals. UI packs do not publish manuals. Ownership and hosting of separate
catalog/manual repositories remain maintainer decisions.

On a closed site, make the exact GET/HEAD `/i18n/runtime.js` and
`/i18n/bootstrap.js`, and POST `/i18n/language` reachable on the login page.
Keep authentication on breeding-data routes.

## Source tools

Only the source-release builder needs these tools:

- Python 3.9 or newer and GNU gettext (`msgfmt`, `msgcat`, `msgmerge`).
- Perl with PPI 1.272 and JSON::PP.
- Node with Acorn 8.18.0. Install the pinned dependency from the SGN root:

  ```sh
  npm ci --prefix bin/i18n --ignore-scripts
  ```

- For marked R files, a tested R/jsonlite pair: 4.5.0/2.0.0 or 4.5.1/1.8.7.
  Use a separate build environment if the scientific application uses another R.

Run extractor checks from the SGN root:

```sh
python3 bin/i18n/test_catalog.py
python3 bin/i18n/test_perl_extract.py
python3 bin/i18n/test_javascript_extract.py
python3 bin/i18n/test_r_extract.py
```

Source commands also accept `--root /path/to/sgn`. Supported files are Perl,
standard JavaScript, marked R, Mason `.mas` and reviewed `autohandler`/`dhandler`
files. JSX, TypeScript and other binding patterns need an explicit adapter.
Parser errors stop the build; they do not produce an empty catalog.

Custom helper commands use JSON argument arrays, without a shell:
`SGN_I18N_PERL_COMMAND`, `SGN_I18N_JAVASCRIPT_COMMAND`,
`SGN_I18N_R_EXTRACT_COMMAND`, `SGN_I18N_R_DISCOVERY_COMMAND`.

## How it works

- `SGN::Role::Site::I18N` chooses one language per request. The header selector
  keeps the current query and section, removes an old `lang` override and saves
  the choice. Disabled pages do not load the two optional locale resources.
- `SGN::I18N` reads the installed messages. Missing or corrupt configured packs
  are logged and omitted; a usable configured parent can serve a regional tag.
- `SGN.t` and `SGN.tn` use the page translator, or plain English if optional
  resources fail. Trial uses these shared helpers, not a second global object.
- Perl and R keep one physical package version during a request or presentation.
  Installing or activating another version cannot mix its message files into
  an existing object.
- The installer changes the selected package and its history together. New links
  stay inside the store and can be mounted at another path. To move an older
  store, activate its selected hash with the new tools before moving it.
  This updates absolute links without adding a history event.
- Recovery journals cover interrupted first activation and legacy-store imports.
  Old installed packages, active folders and history are retained. After an
  import, use the new tools; do not edit pointers or history by hand.

PO/POT files contain context, exact English source, optional plural source and
`%{name}` values. The compiler writes UTF-8 JSON, schema/API version 1.
Each message file has a 2 MiB limit and a checksum. Plural rules are stored as a
small checked syntax tree, not evaluated as catalog code. Unsafe formulas,
wrong variables and malformed package members are rejected. An unrelated source
change does not invalidate an otherwise exact message match.

Optional `X-SGN-Language-Name` metadata supplies the display name.
`SGN::I18N::translate` accepts a missing translator and preserves Perl's `$_`,
`$@` and `$!`. Browser objects keep separate state. See [R support](R.md) for its
explicit API; existing scientific R jobs are not automatically translated.

Keep code readable and use one clear contract, following [PEP 20](https://peps.python.org/pep-0020/).
Keep format rules in `catalog_format.py`, building in `catalog.py` and installing
in `pack.py`. Add options only for real callers. Preserve integrity checks and
rollback while removing duplicate work. See [test results and limits](VALIDATION.md).
