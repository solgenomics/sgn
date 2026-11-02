# Localization validation

## Review follow-up, 2026-11-02

The minimalism pass starts at `8d15183cd0399bc2d239d179be65638112b5dd69`.
It removes unused and repeated work while preserving the package format and
installation commands. Shared data rules no longer import build/extraction
code into operators. The browser selects validated forms directly; request
English fallback is memory-only. Manual navigation has an independent
Playwright suite and preserves updated section anchors.


The candidate includes upstream `master` at
`004e91f45dc8a36e826ddf705a62629a6e92dc69` and the original localization Draft
head `b98b862c8e83b8d712f2e829603cc7e3174f918d`. Validation used the existing
`codex-sgn-pr-refresh:20261025` dependency image; application source was supplied
from the isolated candidate checkout. No production service, data or account was
modified. Hosted checks from the earlier Draft do not certify this new candidate.

- The complete native unit suite passed: 59 files / 2,306 top-level checks.
  The source-path calendar dependency probe and opt-in POD-coverage check remain skipped locally. Four optional Chromium source
  tests were run separately with all four enabled and passed.
- All extraction/catalog/inventory/release/review/manual Python suites passed:
  125 checks. Release regressions cover builds after removal of application
  sources, Node-free operator commands, partitioned packs larger than 2 MiB in
  aggregate, malformed members, stale revisions, legacy migration, failed
  writes, interrupted first activation and recovery journals.
- The R presentation runtime passed 133 checks. Numerical stock values, process
  locale and environment remained unchanged. Perl and R loaders retain one
  physical package generation when activation happens between partition reads;
  the Perl regression reproduced a hash-mismatch failure before that correction.
- All 15,398 current message identities were extracted and frozen. Three current
  languages compiled into 29 independently bounded partitions plus an index per
  language. All three complete packages passed create/validate/install/activate,
  idempotent activation and rollback with `PATH` containing no Node. The actual
  Perl runtime loaded all three installed packages with the expected locale,
  direction and language label.
- A current upstream import explanation changed to mention blank values, `NA`
  and `.`. GNU gettext marked the old translation fuzzy: each language now has
  15,397 compiled translations and one complete English fallback pending review.
  Filled machine translations remain drafts, not human linguistic approval.
- Real Mason toolbar rendering and Chromium passed 20 layout/navigation cases:
  English, Ukrainian, Spanish and Arabic at 1440/768/360/320 pixels; selection
  without automatic navigation; form query/fragment transport; and manual
  chapter/anchor round trips through English and translated versions, including
  a changed fragment after load and correct document language metadata. Two
  standalone manual tests also cover native modified-click/new-tab navigation. Unrelated
  menu content and login transport were controlled. This is not a full logged-in
  application browser acceptance test.
- Four current Bookdown HTML builds passed. English now also has language
  navigation; two existing English cross references were repaired. Scientific
  examples, code, formulas and numerical tokens passed the manual source tests.
  Earlier full-book print inputs and translated PDFs remain unchanged and qualified: Ukrainian 249,
  Spanish 247 and Arabic 228 pages. Export from read-only HTML bundles used all
  four original static print figures with zero missing resources or browser
  errors. All-page character-bound checks and visual samples of 18 rendered
  pages found no clipping or replacement glyphs. The builder now stages the
  print alternatives so export does not need to modify its HTML inputs. This
  pass changes only explicit English language metadata and the navigation asset;
  all 120 reader-page bodies match the previous qualified output.
- PostgreSQL 12.7 fixture regressions `RemoveEmptyValues.t` and
  `RemoveParsedEmptyValues.t` passed 277 assertions after the upstream merge.
  The standard fixture bootstrap emitted an `AddCascadeDeletes` foreign-key
  diagnostic for absent `md_files.file_id=2` and continued; a clean full fixture
  bootstrap is not claimed. A separate real stock-property controller check
  passed 25 controlled-context assertions without database writes.
- JavaScript syntax passed for 114 changed files. Python Black/isort checks and
  pylint passed for all 20 tool files; local versions were Black 24.10.0,
  isort 5.13.2 and pylint 3.3.2. Official hosted lint remains a publication gate.

All 90 compiled JSON/index files and all three complete package hashes are
byte-identical to the previous qualified contribution. Review batches now select
exact context/source/plural identities and reject incomplete PO inputs before
creating output. Ready operator tools run using only `pack.py`,
`catalog_format.py` and `plural.py`.

The release snapshot's semantic source revision is
`284ba4ad5e457a3aecff6c33173351e9ed04dd9afe3815d304f101123e7866db`.
Generated snapshots, package stores, browser captures and logs stay outside Git.
The source registry defines coverage; these results do not establish translation
of every route, scientific analysis or background email.

## Reproduce

Use the qualified extraction dependencies in [README.md](README.md), the normal
application dependencies under `js/node_modules`, and an isolated source/fixture.

```sh
npm ci --prefix bin/i18n --ignore-scripts
for test in bin/i18n/test_*.py; do python3 "$test" || exit; done
prove -Ilib --recurse t/unit
Rscript --vanilla t/unit/SGN/i18n-runtime.R .

bin/i18n/sgn-i18n freeze --application-version APPLICATION_COMMIT \
  --output /release/release.json
bin/i18n/sgn-i18n build --release /release/release.json \
  --po /translations/uk/LC_MESSAGES/sgn.po --output /release/build
```

Follow [the operator workflow](TRANSLATOR.md) for the complete package cycle,
[the developer chapter](DEVELOPER.md) for request/browser diagnostics and
[workflow review](REVIEW.md) for terminology review batches. Preserve English
with localization disabled, scientific identifiers and measurements, ordinary
permission boundaries, request field names and import/export contracts.
