# Build the user manual

Use this guide to build English, Ukrainian, Spanish and Arabic web readers and
PDFs. Translated chapters are drafts; have a native speaker and a breeder review
them before publication. Editing chapters only needs a text editor.

## Before you start

Run commands from the SGN source folder, unless a step says otherwise.
The builder needs R with `bookdown`, `rmarkdown`, `knitr` and `yaml`, plus Pandoc.
Use the existing documentation build environment, separate from scientific R
jobs. [Bookdown's setup guide](https://bookdown.org/yihui/bookdown/get-started.html)
explains installation. RStudio is optional.

Check that the main build dependencies are available:

```sh
Rscript --vanilla -e 'library(bookdown); library(yaml); stopifnot(rmarkdown::pandoc_available())'
```

If this fails, fix the named missing dependency in the documentation build
environment before continuing. The English PDF also needs XeLaTeX. Translated
PDFs use Node, npm, Chromium and suitable fonts, as described below.

## Build the web pages

Choose a new output folder outside the source checkout. One command builds all
four readers:

```sh
Rscript --vanilla docs/r_markdown_docs/build.R all "$HOME/sgn-manual-v1"
```

Open `~/sgn-manual-v1/index.html` for English. The output layout is:

```text
sgn-manual-v1/
  index.html
  uk/index.html
  es/index.html
  ar/index.html
```

Keep the complete folders when publishing, including their other chapter pages
and assets. Language links preserve the matching chapter and section.

`all` refuses an existing output folder and makes the final folder available
only after all four builds succeed. After an edit, use a new name such as
`sgn-manual-v2`. To build Ukrainian alone instead:

```sh
Rscript --vanilla docs/r_markdown_docs/build.R uk "$HOME/sgn-manual-uk-v1"
```

Use `en`, `es` or `ar` for another single language. Output paths must be absolute
and outside the source directory. For help:

```sh
Rscript --vanilla docs/r_markdown_docs/build.R --help
```

With no arguments, `build.R` keeps the original English Bookdown build.

## Build an English PDF

Build the web pages above first. In a disposable documentation checkout with
XeLaTeX installed, run this block from the SGN source folder:

```sh
(
  cd docs/r_markdown_docs
  Rscript --vanilla -e 'bookdown::render_book("index.Rmd", "bookdown::pdf_book", output_dir = path.expand("~/sgn-manual-v1"))'
)
```

The PDF is `~/sgn-manual-v1/BreedbaseManual.pdf`, beside the English web pages.
The subshell returns the terminal to the SGN source folder. Bookdown may create
intermediate files in its source folder; do not commit those files. This uses
the same English PDF renderer as the documentation CI.

## Build a translated PDF

You need Node and npm, Chromium, and the fonts listed in `manual-locale.css`,
including Arabic and mathematical glyphs. Install the print tools outside the
checkout so publication cannot accidentally commit them:

```sh
PRINT_TOOLS="$HOME/sgn-manual-print-tools"
mkdir -p "$PRINT_TOOLS"
cp docs/r_markdown_docs/i18n/package.json docs/r_markdown_docs/i18n/package-lock.json "$PRINT_TOOLS/"
npm ci --prefix "$PRINT_TOOLS" --ignore-scripts
"$PRINT_TOOLS/node_modules/.bin/playwright" install chromium
export NODE_PATH="$PRINT_TOOLS/node_modules"
```

Build one full-book HTML file, then print it. This example creates Ukrainian
`~/sgn-manual-v1/uk/BreedbaseManual.pdf`:

```sh
Rscript --vanilla docs/r_markdown_docs/build.R uk "$HOME/sgn-manual-print-v1/uk" single
node docs/r_markdown_docs/i18n/print_manual.cjs \
  "$HOME/sgn-manual-print-v1/uk" "$HOME/sgn-manual-v1/uk/BreedbaseManual.pdf" uk
```

Repeat with `es` and `ar`. Put each PDF beside its web pages and keep the name
`BreedbaseManual.pdf`. If you used a different web output folder, replace
`sgn-manual-v1` in the PDF commands too.

The exporter checks missing images and browser errors. It reads local book
files, provides the pinned Fuse library locally, blocks other external requests
and uses four supplied static figures for print.

## Edit, check and preview

Use a regular text editor such as Visual Studio Code for `.Rmd` chapters. Poedit is for PO
interface files. Keep heading IDs, code blocks, formulas, numbers and file-field
examples unchanged in translations.

After editing paragraphs, run from the SGN source folder:

```sh
python3 bin/i18n/test_manual.py
Rscript --vanilla docs/r_markdown_docs/build.R all "$HOME/sgn-manual-v2"
```

The first command checks consistency with English; it does not build a preview.
The second builds the pages. Open `~/sgn-manual-v2/index.html` and check the
changed chapters and language links. Building does not publish the reader.

## Publish

Publish the English root and three language folders together. Set the site's
`i18n_manual_base_url` and list the published languages in `i18n_manual_locales`;
see [optional site settings](../../i18n/DEVELOPER.md#optional-site-settings).
The site's Manual link can then use the matching language.

The existing documentation CI checks English only. A maintainer publishes the
translated output separately. UI pack installation does not publish a manual.
Keep generated HTML, PDFs, caches and tools outside Git. The existing workflow
force-adds `docs/` during publication, so do not install tool dependencies there.

## Source files

English chapters and shared figures are in the parent folder. Each language
folder contains 29 translated chapters and Bookdown settings. Shared CSS/JS add
language navigation and Arabic layout without changing vendor code. The builder
copies sources and figures to a temporary folder and cleans it afterwards.

Web readers use native MathML and inherit Bookdown's optional Hypothesis and
external pinned Fuse services. The translated PDF exporter works offline.
Two English cross-references were repaired; translated references keep the same
anchors. The unimplemented external walkthrough remains a text note. Application
URLs refer to the reader's SGN site, not pages hosted by this manual.

Run navigation tests with `npm test --prefix docs/r_markdown_docs/i18n` after
installing that test package. Use an isolated checkout for tests; keep print
and publication dependencies outside the checkout.
