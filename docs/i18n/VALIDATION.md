# Localization validation

Baseline: `solgenomics/sgn` master at
`4031ffe7503f0cbb2914f00b0f01d032c51a0dad` (2026-10-27).
The upstream head was checked again after the port. Tests used the candidate
SGN source first in the Perl include path and an offline dependency environment
derived from the pinned BreedBase v2.23 recipe. This is local source validation;
the full upstream fixture, hosted CI and full browser acceptance remain pending
for this branch.

## Results

- 19 native unit files: 771 top-level checks passed, including the native wrapper
  for 12 JavaScript suites. Four optional browser-dependent cases are explicitly
  unarmed; their source/DOM checks ran where available. No native HTTP, database
  write, outbound mail, image-processing job or scientific application run is
  implied by these unit results.
- Catalog/compiler/inventory tests: 99 passed (27 catalog, 8 inventory,
  19 JavaScript extraction, 23 Perl extraction, 12 R extraction, 10 R discovery).
- R presentation runtime: 130 checks passed; the numeric fixture, process locale
  and environment were unchanged.
- All 751 changed Mason components and 99 JavaScript/tool source files passed
  syntax checks. Mason was compiled to Perl and checked without executing
  request-only initialization blocks.
- 312 of 316 changed Perl modules compiled. Four failures reproduce in the
  unchanged baseline: three XLS validators refer to undeclared variables, and
  `solGS/combinedTrials.pm` requires `String::CRC32`, absent in this dependency
  environment. They are not counted as passing checks.
- All 15,399 active message identities from 1,759 registered sources compiled
  with filled Ukrainian, Spanish and Arabic translations, correct named
  placeholders and validated plural rules. Each language has 29 partitions;
  all 90 JSON/index files passed hash checks and remain within the per-pack
  2 MiB limit. Generated JSON is excluded from Git.
- A focused HTML-sink review escaped 501 translation returns and nine dynamic
  title suffixes while preserving caller markup. Ten section anchors now retain
  their canonical English names. Real Mason regression cases cover consent
  destinations, literal catalog/data text, section controls and legacy arrow
  entities in English, Ukrainian, Spanish and Arabic.

These checks do not establish complete UI coverage or native-language quality.
The source registry defines instrumented coverage. Dedicated retired sections,
translated manuals, vendor text, scientific data and background solGS emails
are outside this contribution. New or unsupported messages fall back to English.

## Reproduce

Install the isolated extraction dependency and the qualified parser dependencies
listed in [README.md](README.md). The application JavaScript dependencies belong
under `js/node_modules`, as in SGN's existing CI.

```sh
npm ci --prefix script/i18n --ignore-scripts
for test in script/i18n/test_*.py; do python3 "$test" || exit; done
python3 script/i18n/catalog.py update
python3 script/i18n/catalog.py build --output locale/build
Rscript --vanilla t/unit/SGN/i18n-runtime.R .
prove -Ilib -lv t/unit/SGN/I18N.t t/unit/SGN/AccountMessages.t \
  t/unit/SGN/CommonErrors.t t/unit/SGN/JavaScriptDependencies.t \
  t/unit/SGN/TrialSummary*.t t/unit/SGN/*iframe-json.t t/unit/SGN/i18n-*.t \
  t/unit/CXGN/Trial/TrialDesign/ROutput.t t/unit/CXGN/File/Parse/I18N.t
```

The normal upstream fixture and browser suites should also run before this
Draft is considered ready for integration. Review translations with breeders
and native speakers, especially terminology, long labels and RTL layouts.
