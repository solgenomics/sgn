# Internationalization: development and debugging

This chapter belongs in the [Breedbase developer guide](https://github.com/solgenomics/sgn/wiki).
The site uses GNU gettext PO/POT files and the existing Perl/Mason, JavaScript and
R presentation paths. Translate complete messages; keep scientific data, stored
names, ontology terms, IDs, units, import headers and API keys unchanged.

## Keep changes simple

Follow [PEP 20](https://peps.python.org/pep-0020/): make behavior explicit and
readable, use existing platform features and give each function one clear job.
Keep data-format rules in `catalog_format.py`, build work in `catalog.py`, and
installation in `pack.py`. Do not add flags, backends or compatibility paths
without a real caller. State errors clearly and preserve input data. Simplify
only when runtime checks confirm the intended behavior; retain necessary
validation, package integrity and rollback boundaries.

## Change a message

Keep a descriptive context and the exact English fallback beside the call.
Use named values instead of joining sentence fragments. Context distinguishes
similar wording with different biological or workflow meanings.

```perl
my $caption = $c->i18n->p('trial.created', 'Created trial %{name}.', {name => $name});
```

```mason
<% $c->i18n->p('trial.created', 'Created trial %{name}.', {name => $name}) |h %>
```

```javascript
alert(SGN.t('trial.created', 'Created trial %{name}.', {name}));
const caption = SGN.tn('trials.count', '%{count} trial', '%{count} trials', count, {count});
element.textContent = caption;
```

```r
caption <- translator$p('trial.created', 'Created trial %{name}.', list(name = trial_name))
```

`SGN.t` and `SGN.tn` use the current page translator, including a catalog installed
by bootstrap after the helper. Without a catalog they provide complete English
messages and named values. They return plain text. Use `textContent`, `.text()` or
sink-specific escaping; never insert a translation into executable JavaScript or
unescaped HTML. Extraction recognizes `SGN.t`, `SGN.tn`, `window.SGN` and
`globalThis.SGN`; a local variable named SGN is not the shared translator. Do not
alias methods into local functions or construct message sources dynamically.

Register a new source in `locale/sources.txt` and assign it to an existing
workflow in `locale/workflows.json`. Existing source edits need no manual PO
rewrite. During development run the affected native tests and extraction check.
A release builder freezes the messages once, merges PO updates, checks pending
translations and builds the language packs. See [operator workflow](TRANSLATOR.md).
An ordinary code PR does not require completed human translations in every language.

## Diagnose English text or an unexpected language

1. Confirm `i18n_enabled`, configured languages and the active catalog directory.
2. Check `Content-Language`, HTML `lang`/`dir` and `data-sgn-locale`. Requested
   regional tags and the installed effective language can differ.
3. Locale preference order is query `lang`, explicit `X-SGN-Locale`, saved
   browser cookie, browser language preferences, site default, then English.
   The language selector removes an old query override when saving a new choice.
4. Inspect `/i18n/bootstrap.js` for the selected workflow. Browser messages require
   the common catalog and that page's workflow partition. The runtime endpoints
   must be reachable on login pages of closed sites.
5. Match context, exact English source and plural source. Empty, fuzzy, incomplete
   or changed sources retain whole English fallback. Filled machine translations
   are drafts, not evidence of linguistic approval.
6. Check the release version, package hash and index/partition hashes. Missing or
   damaged configured languages are omitted from selection and logged per request;
   they cannot prevent another installed language from serving the page. The
   underlying loader still rejects corrupt catalogs explicitly.
7. Reproduce with a fresh request. Requests own immutable catalog snapshots;
   activating a new package changes subsequent requests. Operator activation and
   rollback switch the complete catalog and its history together.

Do not debug wording by sending real mail or launching scientific calculations.
Use synthetic fixture names, including non-Latin text, ampersands, literal HTML,
zero counts and plural counts 1/2/5/21. Check narrow screens, long labels and Arabic
right-to-left text. Confirm the same IDs, scientific values and request fields
reach the ordinary application workflows.

## Publish matching user documentation

Set `i18n_manual_base_url` to the published manual root and
`i18n_manual_locales en,uk,es,ar` only after publishing those language directories.
The Manual menu uses a published version matching the effective UI language,
with English fallback. Manual publication and interface pack activation are
separate release operations.
