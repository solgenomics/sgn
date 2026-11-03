# Translate a release

The builder prepares files, the translator edits them, and the administrator
installs the result. Each person can follow only their own step.
The translator needs a local editor; the application and source tools stay on
the builder's machine. Installing a ready bundle is covered in
[Install a language](README.md).

## 1. Builder: make the translation folder

Use the clean SGN source checkout for the release and install the
[source tools](DEVELOPER.md#source-tools). Open a terminal in that checkout.
This command uses its Git commit as the release version automatically:

```sh
python3 bin/i18n/sgn-i18n prepare \
  --application-version "$(git rev-parse HEAD)" \
  --output "$HOME/sgn-translation-v1"
```

The command reads source messages once, freezes the message list, copies the
translations and updates those copies from the release template. Original
source PO/POT files stay unchanged. It also includes matching tools and notices.

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

The PO files are the editable translations. `release.json` and `release.pot`
record the messages for this release. Keep the other files with the PO files.

**Already have a frozen release?** This alternative needs Python 3.9 or newer
and GNU gettext (`msgcat`, `msgfmt`, `msgmerge`), but no source checkout parsers,
Node, Perl or R. Replace the two input paths with the files you received:

```sh
python3 bin/i18n/sgn-i18n prepare --release /path/to/release.json \
  --po /path/to/uk.po --output "$HOME/sgn-translation-v1"
```

Repeat `--po` for more languages. Use trusted release files and accompanying
notices. A checksum identifies bytes; it is not a publisher signature.

## 2. Translator: open, edit and save

Install [Poedit](https://poedit.com/download/) on your computer once.
Open Poedit, choose **File → Open**, and open `translations/uk.po` from the
received folder. Spanish is `es.po`; Arabic is `ar.po`.
Editing needs no SGN, Python, Node or translation server.

1. Select a message. **Source text** shows the English; **Translation** is editable.
2. Change the translation. Keep values such as `%{name}` and `%{count}` unchanged.
3. Fill every plural form shown for the language.
4. Mark uncertain text **Needs Work**. SGN will use the whole English message for it.
5. Save. Return the whole folder to the builder, who completes step 3.

For example, in `Created trial %{name}.`, translate the words but keep `%{name}`
exactly as written. SGN inserts the real trial name later.
Keep context keys, English source, IDs, scientific names, units and headers
unchanged. Use plain text without HTML tags or pre-escaped entities.

Have a native speaker and a breeder review the wording. Filled text is not proof
of review. [Poedit checks files when saving](https://poedit.com/docs/get-started/translate-files/);
the SGN build also checks its own placeholder rules. `%{menu}` in
`file_list.datatable.length_menu` and `odk.table.length` must appear exactly
once and must not become `_MENU_`.

Saving changes the working copy only. It does not update the running site.
Use [small review batches](REVIEW.md) if a full catalog is too much to review.

## 3. Builder: make ready packages

Use a Linux/POSIX builder with Python 3.9 or newer and GNU gettext (`msgcat`,
`msgfmt`, `msgmerge`). After preparation, no application checkout or source
parsers are needed. Save the edited files before packaging.

Open a terminal and run:

```sh
cd "$HOME/sgn-translation-v1"
python3 tools/sgn-i18n package --workspace . --output "$HOME/sgn-ready-v1"
```

If the returned workspace is elsewhere, open that folder instead of using the
example `cd` path. The resulting `sgn-ready-v1` folder contains:

```text
operator-tools/
uk-pack/
es-pack/
ar-pack/
translations/
release.json
release.pot
notices/
README.md
```

Only the languages present in the workspace get a pack. The command checks the
saved translations, compiles them, and includes copies of the exact inputs used.
Another editor save cannot mix a later PO into the package's source record.
Invalid placeholders or malformed files stop the build before a ready folder
appears. Empty or Needs Work messages use whole English fallback.

Give the whole ready folder to the site administrator. The included `README.md` and
[installation guide](README.md) explain the one-command install and activation.
Preparing or packaging files never activates them on a site.

## Make a correction

Keep the workspace, edit its PO files in Poedit and save. Package again with a
new output name:

```sh
cd "$HOME/sgn-translation-v1"
python3 tools/sgn-i18n package --workspace . --output "$HOME/sgn-ready-v2"
```

Existing output folders are never overwritten. Use a new workspace name when
preparing another SGN release, such as `sgn-translation-v2`.
Ordinary code PRs do not require completed human translations in every language;
prepare updated catalogs when making a release.

## Additional tools

From the workspace folder, start French from its frozen template with:

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
`build --legacy-single-file`.
