# R translation support

This is a developer reference, not a site-setup step.
For setup, use [Turn on translations](README.md).
Existing scientific R jobs are not automatically translated.

## Use the library

Load `R/lib/sgn_i18n.R` in the caller's environment. Create a separate translator
for each report or presentation:

```r
source("R/lib/sgn_i18n.R")
translator <- sgn_i18n("uk", "/srv/sgn-languages/active", "sgn")
caption <- translator$p("trial.created", "Created trial %{name}.", list(name = trial_name))
```

`sgn_i18n_from_payload(payload)` also accepts a supplied catalog payload.
`$p(context, source, vars)` returns one message.
`$np(context, singular, plural, count, vars)` chooses a plural form.
Both return UTF-8 plain text; escape it in the report or UI that displays it.
They do not change numbers, IDs, output headers, environment variables or R's
process locale. A missing or changed message uses whole English fallback.

## Data rules

- Fields use exact names. Similar names do not count as required fields and
  similar optional metadata is ignored. R partial-field matching is disabled.
- Language tags are normalized before fallback and duplicate checks.
- Invalid UTF-8 and classed catalog values are rejected. Catalog loading cannot
  run custom coercion or selection methods.
- Counts are integers from 0 through 2^53-1, with exact modulo in that range.
- The runtime reads only the checked schema/API 1 plural tree. It does not
  evaluate the `pluralForms` text as R code.
- Methods and private state are locked. Inputs and exported catalogs are copies;
  changing one does not change another translator.

## Extract marked R messages

`bin/i18n/r_extract.R` parses source text without running scripts, loading their
packages or starting calculations. Tested R/jsonlite pairs are listed in
[Source tools](DEVELOPER.md#source-tools).

The extractor accepts literal `$p`/`$np` calls, including quoted/backtick method
names, on direct constructors and proven single-assignment aliases. Exact named
arguments come before positional arguments, following R's own call rules.
Missing/extra arguments, partial names, dynamic text, computed method access,
reassignment, method aliases and unknown injected bindings stop with an error.

`Dockerfile.i18n-r-extractor` and `Dockerfile.i18n-r-runtime-test` describe the
small offline test images. `bin/i18n/test_r_extract.py` checks extraction;
`t/unit/SGN/i18n-runtime.R` checks the runtime. A trusted
`SGN_I18N_R_EXTRACT_COMMAND` JSON argument array can select an external helper.
Test the exact source files used in an image.

## Before changing a scientific report

Identify the report's text and data fields. Prove numerical and biological
outputs stay the same. Check UTF-8 fonts, escaping, layout and text direction.
The library's small test fixture does not qualify a real scientific workflow.
Arbitrary reflection, every R dialect and every report template are not covered.
