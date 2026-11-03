# Translate a release

There are three jobs: the builder prepares files, the translator edits them,
and the administrator installs the result. Installing a ready bundle is covered
in [Install a language](README.md).

## 1. Builder: make the translation folder

Open the SGN source folder for the release. Install the [source tools](DEVELOPER.md#source-tools).
Replace `RELEASE_VERSION` with the actual SGN version or commit, then run:

```sh
python3 bin/i18n/sgn-i18n prepare --application-version RELEASE_VERSION --output "$HOME/sgn-translation-v1"
```

This one command reads source messages once, copies the PO files, updates those
copies from the release template, and includes the matching tools and notices.
It keeps the original source PO/POT files unchanged. Existing output folders
are never overwritten.

Give the whole `sgn-translation-v1` folder to the translator. It contains:

```text
translations/uk.po
translations/es.po
translations/ar.po
release.json
release.pot
tools/
notices/
README.md
```

If a release was already frozen, prepare from it instead. No source parsers,
Node, Perl or R are needed for this mode:

```sh
python3 bin/i18n/sgn-i18n prepare --release /path/to/release.json \
  --po /path/to/uk.po --output "$HOME/sgn-translation-v1"
```

Repeat `--po` for more languages. Use the trusted release files and accompanying
notices. A checksum identifies bytes; it is not a publisher signature.

## 2. Translator: open, edit and save

Install [Poedit](https://poedit.com/download/) on your computer once.
Open Poedit, choose **File → Open**, and open `translations/uk.po` from the
received folder. Spanish is `es.po`; Arabic is `ar.po`.
Editing in Poedit does not require SGN, Python, Node or a translation server.

1. Select a message. **Source text** shows the English; **Translation** is editable.
2. Change the translation. Keep values such as `%{name}` and `%{count}` unchanged.
3. Fill every plural form shown for the language.
4. Mark uncertain text **Needs Work**. It will use whole English fallback on the site.
5. Save, then return the whole folder to the release builder.

Keep context keys, English source, IDs, scientific names, units and file headers
unchanged. Write plain text without HTML tags or pre-escaped entities.
Have a native speaker and a breeder review the wording. Filled text is not proof
of review. Poedit's normal checks are useful; the SGN build also checks its own
placeholder rules. `%{menu}` in `file_list.datatable.length_menu` and
`odk.table.length` must appear exactly once and must not become `_MENU_`.

Saving a PO changes the working copy only. It never updates the running site.
See [small review batches](REVIEW.md) if a full catalog is too much to review.

## 3. Builder: make ready packages

On the Linux/POSIX release builder, use Python 3.9 or newer and GNU gettext
(`msgcat`, `msgfmt`, `msgmerge`). No application checkout or source parsers are
needed after preparation. Run from the received folder:

```sh
python3 tools/sgn-i18n package --workspace . --output "$HOME/sgn-ready-v1"
```

The result contains `<language>-pack` folders, the four operator tools,
a short installation guide and copies of the exact release/PO inputs used.
The build takes its own input copies, so another editor save cannot mix a
later PO into the package's source record. Invalid placeholders or incomplete
files stop the build before a ready folder appears.

Give the whole ready folder to the site administrator. They can follow
[Install a language](README.md) with one install-and-activate command.
For a correction, keep the workspace and choose a new output name, such as
`sgn-ready-v2`. Never overwrite an earlier ready bundle.

## Additional tools

To start French from a frozen template, use the existing init command:

```sh
python3 tools/sgn-i18n init --release release.json --locale fr --direction ltr \
  --plural-forms 'nplurals=2; plural=(n > 1);' --name 'Français' \
  --output translations/fr.po
```

Use the language's real direction and plural rule; do not guess them.
The PO header contains `Language`, `X-SGN-Direction`, `Plural-Forms` and the
optional native name `X-SGN-Language-Name`.

Advanced `build`, `create`, `validate`, plain `install` and explicit `activate`
remain available. `create` and `install` already validate packages; a separate
`validate` is not a required extra step. `--expected-revision` can require an
exact message-list version when activating. It is optional and rejects blank
or malformed values.

Each JSON file in a pack has a 2 MiB limit. Large languages use indexed message
files, not a raised limit. Small older catalogs still support
`build --legacy-single-file`. Ordinary code PRs do not require finished human
translations for every language; prepare updated catalogs when making a release.
