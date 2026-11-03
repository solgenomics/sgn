# Build the translated user manual

Run these commands from the SGN source folder. You need the site's Bookdown
build environment. The translated chapters are drafts; have a native speaker
and a breeder review them before publication.

## Build the web pages

Choose a new output folder outside the source checkout. One command builds all four readers:

```sh
MANUAL_DIR="$HOME/sgn-manual-v1"
Rscript --vanilla docs/r_markdown_docs/build.R all "$MANUAL_DIR"
```

Open `~/sgn-manual-v1/index.html` to read English. The `uk`, `es` and `ar`
folders contain the other languages. Keep this layout when publishing, so
language links find the same chapter and section.

For help, run `Rscript --vanilla docs/r_markdown_docs/build.R --help`.
The language build requires an absolute output path and rejects source overlap.
`all` refuses an existing output folder and publishes it only after all four
builds succeed. Use `en`, `uk`, `es` or `ar` to build one language.
With no arguments, `build.R` keeps the original English Bookdown build.

## Build a PDF

Build the web pages above first. The PDF will go beside those pages.

You also need Node, Chromium and the fonts listed in `manual-locale.css`,
including Arabic and mathematical glyphs. Install the print tools outside the
checkout so documentation publication cannot accidentally commit them:

```sh
PRINT_TOOLS="$HOME/sgn-manual-print-tools"
mkdir -p "$PRINT_TOOLS"
cp docs/r_markdown_docs/i18n/package.json docs/r_markdown_docs/i18n/package-lock.json "$PRINT_TOOLS/"
npm ci --prefix "$PRINT_TOOLS" --ignore-scripts
"$PRINT_TOOLS/node_modules/.bin/playwright" install chromium
export NODE_PATH="$PRINT_TOOLS/node_modules"
```

Build one full-book HTML file, then print it. This example uses Ukrainian:

```sh
MANUAL_DIR="$HOME/sgn-manual-v1"
Rscript --vanilla docs/r_markdown_docs/build.R uk "$HOME/sgn-manual-print-v1/uk" single
node docs/r_markdown_docs/i18n/print_manual.cjs \
  "$HOME/sgn-manual-print-v1/uk" "$MANUAL_DIR/uk/BreedbaseManual.pdf" uk
```

Repeat with `es` and `ar`. Put each PDF beside its web pages, keeping the name
`BreedbaseManual.pdf`. English PDFs still use the original Bookdown build.
The exporter checks missing images and browser errors.
It reads local book files, provides the pinned Fuse library locally, blocks
other external requests and uses four supplied static figures for print.

## Publish

Publish the English root and three language folders together. Then set the
site's `i18n_manual_base_url` and list the published languages in
`i18n_manual_locales`; see [optional site settings](../../i18n/DEVELOPER.md#optional-site-settings).
The site's Manual link can then use the matching language.

The existing documentation CI publishes English only. Other languages need a
separate publication step by the maintainer. UI pack installation does not
publish a manual. Keep generated HTML, PDFs, caches and tools outside Git.
The existing workflow force-adds `docs/`, so do not install tool dependencies there.

## Edit chapter text

Use a regular text editor such as VS Code for `.Rmd` chapters. Poedit is for PO
interface files. Change paragraphs, then have the release builder run the source
checks and build the preview:

```sh
python3 bin/i18n/test_manual.py
```

Keep heading IDs, code blocks, formulas, numbers and file-field examples unchanged.
The checks compare these with English. Building the reader does not publish it.

## Source files

English chapters and shared figures are in the parent folder. Each language
folder contains 29 translated chapters and Bookdown settings. Shared CSS/JS add
language navigation and Arabic layout without changing vendor code. Heading IDs,
scientific code, examples, formulas, units and file fields stay unchanged.
The builder copies sources/figures to a temporary folder and cleans it afterwards.

Web readers use native MathML and inherit Bookdown's optional Hypothesis and
external pinned Fuse services. The PDF exporter works offline.
Two English cross-references were repaired; translated references keep the same
anchors. The unimplemented external walkthrough remains a text note. Application
URLs refer to the reader's SGN site, not pages hosted by this manual.

Run navigation tests with `npm test --prefix docs/r_markdown_docs/i18n` after
installing that test package. Use an isolated checkout for tests; keep print
and publication dependencies outside the checkout.
