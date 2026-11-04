# Work on the user manual

The [published user manual](https://solgenomics.github.io/sgn/) explains how to
use Breedbase. This folder contains its 29 English chapters. Ukrainian, Spanish
and Arabic drafts are under `i18n/`.

## Edit a chapter

Open its `.Rmd` file in a text editor such as Visual Studio Code or RStudio. Edit the
paragraphs. Keep heading IDs, code, formulas, numbers, units and file-field
examples unchanged in translations. The chapter order is in `_bookdown.yml`.

Run the following commands from the SGN source folder in the
[manual build environment](i18n/README.md#before-you-start):

```sh
python3 bin/i18n/test_manual.py
Rscript --vanilla docs/r_markdown_docs/build.R all "$HOME/sgn-manual-v1"
```

The first command checks source consistency. The second builds all four web
readers. Open `~/sgn-manual-v1/index.html` to preview English; use the language
links for the other readers. Choose a new output name, such as `sgn-manual-v2`,
after the next edit. Generated files stay outside the checkout.

Use [the build guide](i18n/README.md) for prerequisites, single-language builds,
English and translated PDFs, and publication. It also explains where each
output file goes. Poedit edits interface PO files; manual chapters use a text
editor.

## Review and publish

Review the built pages before submitting chapter changes. Have a native speaker
and a breeder check translated wording. Commit the source changes; keep preview
HTML, PDFs, caches and installed tools outside Git.

[Documentation CI](../../.github/workflows/test_static.yml) checks English HTML
and PDF on relevant PRs. A maintainer publishes the output; building a preview
or installing a UI language pack does not publish manuals. The current workflow
writes generated documentation only when run manually on `master`.

For Markdown and R Markdown syntax, see the
[Bookdown guide](https://bookdown.org/yihui/bookdown/).
