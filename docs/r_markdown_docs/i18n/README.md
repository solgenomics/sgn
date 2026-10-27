# Manual language sources

Ukrainian, Spanish and Arabic chapter text is machine-translated and requires
native-language and breeding-terminology review before publication.

English chapter sources and shared reference figures remain in the parent directory. Each language directory contains translated chapter copies and standard Bookdown configuration. Explicit canonical English heading IDs preserve navigation between languages. Scientific code, examples, formulas, identifiers, units and file fields are not localized.

Use the existing builder from any directory:

```sh
Rscript --vanilla docs/r_markdown_docs/build.R uk /absolute/output/uk split
Rscript --vanilla docs/r_markdown_docs/build.R es /absolute/output/es split
Rscript --vanilla docs/r_markdown_docs/build.R ar /absolute/output/ar split
```

`en` builds an isolated English reference. `single` instead of `split` creates the full-book HTML used for PDF export. Without arguments the original English Bookdown command and its default output remain unchanged. The language builder stages independent copies of the shared figures so knitr writes portable relative URLs, cleans the temporary project, and writes only to the selected output directory. Do not bind-mount this source over a running SGN application.

`manual-locale.css`, `manual-locale.js`, and each `locale-header.html` provide RTL/code/table presentation, language navigation and captions for standard reader controls without editing vendor libraries. Mathematical notation uses native MathML. The standard optional Hypothesis integration and pinned external Fuse library remain inherited reader dependencies; a local preview can block services and supply the exact cached library.

The English corpus contains two invalid references and an external-walkthrough placeholder. Localized copies point the Field Book reference to its verified explicit heading ID and replace the numeric reference to an unnumbered email-alert section with a direct canonical anchor link. The unimplemented external walkthrough stays a translated text note with no invented URL. Application-root tool paths remain references to the reader's database, not files hosted by the manual. English chapter files remain original. Do not translate IDs or guess replacement anchors.

The web chapters retain the canonical `BreedbaseManual.pdf` link. Build the full-book
HTML and export it with the isolated print tool, then put the PDF beside that
language's web chapters. For example, with absolute output directories:

```sh
npm ci --prefix docs/r_markdown_docs/i18n --ignore-scripts
docs/r_markdown_docs/i18n/node_modules/.bin/playwright install chromium
Rscript --vanilla docs/r_markdown_docs/build.R uk /absolute/output/print/uk single
node docs/r_markdown_docs/i18n/print_manual.cjs \
  /absolute/output/print/uk /absolute/output/uk/BreedbaseManual.pdf uk
```

Repeat for `es` and `ar`. The browser needs the fonts used by `manual-locale.css`,
including Arabic and mathematical glyph coverage. The exporter serves only local
book resources, supplies the pinned Fuse dependency locally, blocks other external
requests, uses the four original static PNG alternatives to animated examples,
and fails on missing images or browser errors. It never starts the application.

The existing workflow force-adds `docs/`; publication builds must install print
dependencies outside the checkout and set `NODE_PATH` to that `node_modules`
directory, or remove those dependencies before staging generated documentation.
Generated HTML/PDF and tool dependencies are excluded from this contribution. Source and output directories are separate; generated HTML, PDFs, caches and reports do not belong in this source tree. Publication and application-menu integration are separate release actions.

The existing upstream documentation workflow still renders the English manual.
Run the explicit language commands above when publishing translated readers;
the fork-safe validation workflow does not publish them automatically.
Documentation-site publication remains a separate maintainer action.
