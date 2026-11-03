# Install a language

This guide adds Ukrainian to an existing SGN site. Users can change the language
of buttons and messages; trial names, accession names, IDs and data stay the same.
English stays available and is used when a translation is missing.

Choose the guide for your job:

| Job | Start here |
| --- | --- |
| Install or update a ready language pack | Follow the steps below. |
| Edit translations on your computer | [Open the prepared files in Poedit](TRANSLATOR.md#2-translator-open-edit-and-save). |
| Prepare a release or build ready packs | [Builder instructions](TRANSLATOR.md). |
| Change English text in the application | [Developer instructions](DEVELOPER.md). |
| Edit or build the user manual | [Manual instructions](../r_markdown_docs/i18n/README.md). |

## Before you start

The matching SGN application must already be running. This installs language
files; it does not install or upgrade SGN itself.

The administrator needs a Linux/POSIX server and Python 3.9 or newer. Ready packs
need no Node, Perl, R or GNU gettext. Check Python with `python3 --version`.
Ask the release builder for the whole ready folder, then unpack it:

```text
operator-tools/
uk-pack/
es-pack/
ar-pack/
README.md
```

Keep each pack folder whole. Use files from a release builder you trust.
Run the commands as the server account used by SGN. In Docker, the mounted
files must be readable by that account's user ID inside the container.
The administrator gives the account write access to `/srv/sgn-languages`.
Start with an empty folder on the first installation; keep it for later updates.

## 1. Install and select Ukrainian

Open a terminal in the unpacked ready folder. Run both commands:

```sh
READY_DIR="$PWD"
python3 "$READY_DIR/operator-tools/sgn-i18n" install --activate \
  --pack "$READY_DIR/uk-pack" --root /srv/sgn-languages
```

`READY_DIR` remembers this folder, so later commands still work after you open
the Compose project folder. Use the same terminal for the remaining steps.

The tool checks the files, reads the language and selects the pack. No long hash
needs to be copied. Its receipt describes the local installation; it does not
mean the running site has applied the settings yet. If the command fails, read
the error before continuing. The previously selected pack stays available.

## 2. Apply the site settings once

Edit the configuration used by the running site, usually `sgn_local.conf`:

```text
i18n_enabled 1
i18n_enabled_locales en,uk
i18n_catalog_dir /srv/sgn-languages/active
```

These settings turn translations on, allow English and Ukrainian, and tell SGN
where to read the selected packs. The final `/active` is required.

For Docker, add this line to the web service's existing `volumes` list:

```yaml
- /srv/sgn-languages:/srv/sgn-languages:ro
```

Keep the other volumes. Open the site's usual Compose project folder. If you
need the service name, list the services:

```sh
docker compose config --services
```

Replace `YOUR_SGN_SERVICE` below with the web service name from that list:

```sh
docker compose up -d --no-deps YOUR_SGN_SERVICE
```

Keep the site's usual `-f` and `-p` options on both Compose commands.
[Restart alone does not apply a new volume](https://docs.docker.com/reference/cli/docker/compose/restart/).
Without Docker, use the site's normal SGN restart command.

## 3. Check the files and the site

In the same terminal, check the installed files:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" doctor \
  --root /srv/sgn-languages --locale uk
```

To check the site's language resources too, replace `YOUR_SITE_URL` with the
site's root URL, such as `https://example.org`:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" doctor \
  --root /srv/sgn-languages --locale uk --site YOUR_SITE_URL
```

`doctor` reads the selected and previous packs. The optional site check reads
two resource response headers. It does not change files, permissions or settings.
It does not prove every screen, calculation or the exact remote pack version.

Open a new page. Choose **Українська** in the header, to the left of **Login**,
then click the button beside the language list. Check that messages change and
trial/accession names stay the same. Changing the list alone does not navigate.
Translations are drafts and need a native speaker and a breeder to review them.

## Update, add a language or undo

For an update, get the new ready folder and repeat step 1 from that folder,
including `READY_DIR="$PWD"`. Open a new page afterwards. No restart is needed
when the configuration and whole-folder Docker mount already exist.

| Language | Pack folder | Value in `i18n_enabled_locales` |
| --- | --- | --- |
| English | Included with SGN | `en` |
| Ukrainian | `uk-pack` | `uk` |
| Spanish | `es-pack` | `es` |
| Arabic | `ar-pack` | `ar` |

For example, to install Spanish from the same ready folder:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" install --activate \
  --pack "$READY_DIR/es-pack" --root /srv/sgn-languages
```

Add `es` to the setting (`i18n_enabled_locales en,uk,es`) and apply the changed
settings as in step 2. Arabic works the same way with `ar-pack` and `ar`.

To undo the last Ukrainian activation:

```sh
python3 "$READY_DIR/operator-tools/sgn-i18n" rollback \
  --root /srv/sgn-languages --locale uk
```

This selects the previous version. After the first activation, rollback removes
that selection and Ukrainian requests fall back to English. To turn translations
off for the whole site, set `i18n_enabled 0` and restart SGN.

## If it does not work

- **Permission denied:** check the SGN account and folder ownership.
- **No language list:** check `i18n_enabled 1`, then repeat step 2.
- **English instead of Ukrainian:** run `doctor` and read its error.
- **Only some text stays English:** those messages may not be translated yet.
- **Another operation is running:** wait for it to finish, then check again.
- **New terminal:** open the ready folder and set `READY_DIR="$PWD"` again.

For small review batches, use [Review translations](REVIEW.md).
[Test results and limits](VALIDATION.md) and
[translation sources and licenses](TRANSLATION_SOURCES.md) describe the checks
and remaining review work.
