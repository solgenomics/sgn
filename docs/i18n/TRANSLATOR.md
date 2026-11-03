# Build a language pack

A pack is a folder of translated messages ready for installation.
To install an existing pack, use [Turn on translations](README.md).
This example builds Ukrainian. Use a new output folder for each release.

## 1. Prepare the release

The person building the SGN release does this step.
Open a terminal in the SGN source folder for that release.
Install the [source tools](DEVELOPER.md#source-tools) first.

```sh
RELEASE_DIR="$HOME/sgn-release-v1"
python3 bin/i18n/sgn-i18n freeze \
  --application-version "$(git rev-parse HEAD)" \
  --output "$RELEASE_DIR/release.json"
mkdir -p "$RELEASE_DIR/tools"
cp bin/i18n/*.py bin/i18n/sgn-i18n "$RELEASE_DIR/tools/"
cp locale/uk/LC_MESSAGES/sgn.po "$RELEASE_DIR/uk.po"
```

You now have:

- `release.json`: the exact message list for this SGN release.
- `release.pot`: the same list for gettext editors.
- `uk.po`: a copy of the Ukrainian translations.
- `tools`: the Python files for the remaining steps.

Keep the printed release checksum with the release record. Get these files
through the project's trusted release channel; a checksum is not a signature.
The freeze command refuses to overwrite an existing release.
Give the whole `sgn-release-v1` folder to the translator. They should put it
in their Linux home folder before step 2.

## 2. Update the translation

The translator needs Python 3.9 or newer and GNU gettext: `msgmerge`, `msgcat`
and `msgfmt`. No application checkout, Node, Perl or R is needed from here on.

```sh
cd "$HOME/sgn-release-v1"
msgmerge --update --no-wrap --backup=numbered uk.po release.pot
```

This keeps a numbered backup of the PO file. Open `uk.po` in a gettext editor:

- Translate `msgstr` and every required `msgstr[n]`.
- Keep `msgctxt`, `msgid` and `msgid_plural` unchanged.
- Keep names such as `%{count}` and `%{name}` exactly as written.
- Write plain text, without HTML tags or pre-escaped entities.
- Leave uncertain text empty or marked fuzzy. The site will use whole English
  messages for those entries.

Have a native speaker and a breeder check the wording. A filled entry is not
proof that someone reviewed it. [Review small batches](REVIEW.md) if needed.
The `%{menu}` value in `file_list.datatable.length_menu` and `odk.table.length`
must appear exactly once; do not replace it with `_MENU_`.

## 3. Build the files

Run from the release folder used in step 2:

```sh
python3 tools/sgn-i18n build --release release.json --po uk.po --output build-v1
```

The result is `build-v1/uk/sgn/index.json` and its message files.
The output reports translated and English-fallback counts. A missing message,
changed source or invalid placeholder cannot silently reuse the wrong wording.

## 4. Make the installable pack

```sh
python3 tools/sgn-i18n create --catalog build-v1/uk/sgn/index.json --output uk-pack
```

The result is the **whole `uk-pack` folder**, including `manifest.json`.
Keep all files together. `create` already checks them.
Give the site operator this folder and these four files from `tools`:
`sgn-i18n`, `pack.py`, `catalog_format.py`, `plural.py`.
The operator can now follow [Turn on translations](README.md).

For a correction, keep the previous PO, choose new names such as `build-v2`
and `uk-pack-v2`, and repeat steps 3 and 4.

## Add a language that has no PO file

Run from the release folder. This example creates French:

```sh
python3 tools/sgn-i18n init --release release.json \
  --locale fr --direction ltr --plural-forms 'nplurals=2; plural=(n > 1);' \
  --name 'Français' --output fr.po
```

Use that language's real direction and plural rule. Do not guess them.
Then translate and build its PO as in steps 2–4. Change the PO filename and
language folder in the commands. The PO's `Language` field determines the tag.
The header also holds `X-SGN-Direction`, `Plural-Forms` and the optional
`X-SGN-Language-Name`. Keep these unless preparing another language.

## Package rules

- Keep the original PO, release files and license notices.
- Each JSON file in the installable pack has a 2 MiB limit. Large languages use separate message
  files; do not raise that limit.
- Installation checks file contents and checksums. Missing, extra, changed or
  symlinked pack members are rejected.
- `validate --pack uk-pack` checks without installing. Use it for diagnosis;
  it is not a required extra step after `create` or `install`.
- Small older catalogs can still use `build --legacy-single-file` and
  `create --catalog .../sgn.json`. Use indexed packs for the full corpus.
- `activate --expected-revision CODE` can require an exact message-list version.
  It is optional; the normal setup does not need it.

Ordinary code changes do not require finished human translations in every
language. Refresh the message list for a release, then review changed wording.
