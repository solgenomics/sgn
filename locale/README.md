# Interface translations

Translations live in the separate
[sgn-translations](https://github.com/Globgor/sgn-translations) repository, not in SGN. They are
standard GNU gettext files: `xgettext` reads the marked text from the SGN
code, translators edit PO files, and `make` there builds the `.mo` files that
SGN reads with libintl-perl.

The two files here describe the SGN code for those tools:
`sources.txt` lists the files with translatable text, and `workflows.json`
assigns each file to a message section (`common` is sent to every page).
