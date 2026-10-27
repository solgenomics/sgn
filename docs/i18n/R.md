# Bounded R presentation and extraction support

`R/lib/sgn_i18n.R` is an optional presentation library. Load it into the
caller/job environment and create a separate `sgn_i18n(locale, catalog_root,
domain)` or `sgn_i18n_from_payload(payload)` object for each presentation.
`$p(context, source, vars)` and `$np(context, singular, plural, count, vars)`
return UTF-8 plain text; the report or UI renderer must escape that text for its
output format. They do not alter numerical data, identifiers, machine output
headers, environment variables or the process locale.

Catalog and payload fields use exact names. R's partial list-field matching is
disabled by using exact `[[` reads. Required fields with a similar but different
name are rejected, and similar optional metadata names are ignored. Effective
catalog tags are normalized before fallback and duplicate-tag checks. Invalid
UTF-8 sources, catalog forms, names and substituted values are rejected.
Classed catalog scalars/form lists are rejected before R can dispatch a custom
coercion or selection method; language packs remain plain data.

Plural-expression metadata is informational text. The runtime validates and
interprets only the bounded schema/API 1 plural AST; it never evaluates that
text. Counts are nonnegative safe integers through 2^53-1, with exact integer
modulo in that range. Missing or stale messages retain whole English fallback.
Methods and private object state are locked; caller input and exported catalogs
are detached copies. Independent objects can present the same calculated
results in different languages within one R process.

`script/i18n/r_extract.R` parses application source as data using the qualified
R 4.5.1/jsonlite 1.8.7 parser. It does not source scripts, load their packages,
run their calculations or resolve application functions. Literal `$p`/`$np`
markers, including R's equivalent quoted and backtick member spelling, work on
unshadowed direct constructors and proven single-assignment aliases. Exact
named arguments are matched before positional arguments, following R's formal
argument order. Explicit missing arguments, extra positional arguments, partial
names, dynamic message text, computed access, reassignment, method aliases and
unsupported injected/imported bindings fail explicitly.

The minimal offline images are built with `Dockerfile.i18n-r-extractor` and
`Dockerfile.i18n-r-runtime-test`. The latter includes only the new library, the
owned runtime test and the shared message fixture. The extraction tests are in
`script/i18n/test_r_extract.py`. Configure `SGN_I18N_R_EXTRACT_COMMAND` with a
shell-free JSON argv pointing to the qualified helper when R is unavailable on
the developer host. Image source hashes must match the tested working files.

These checks qualify the library and explicit marker contract. The numerical
preservation check uses a tiny owned stock fixture and does not certify any
existing application calculation. No existing application R workflow is
instrumented by this support change. Migrating a calculation, asynchronous job,
export or rendered report still requires an identified integration point,
unchanged numerical/biological outputs, explicit human-text versus machine-data
ownership, and report checks for UTF-8 fonts, escaping, layout and direction.
Arbitrary R reflection and every template or R dialect remain outside this
bounded contract.
