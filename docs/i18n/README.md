# Install a language

This guide adds Ukrainian to a working SGN site. English stays available.
Buttons and messages change language; trial names, IDs and data stay the same.

## 1. Get the ready folder

Ask the release builder for the ready language bundle. It contains:

```text
operator-tools/
uk-pack/
es-pack/
ar-pack/
README.md
```

Keep each pack folder whole. Unpack an archive first.
The SGN version with this feature must already be running.

The administrator runs the commands as the server account used by SGN.
In Docker, that same account must own the mounted files inside the container.
Give it write access to `/srv/sgn-languages`. Start with an empty folder on the
first installation; keep the existing folder on later updates.

## 2. Install and select Ukrainian

Open a terminal in the ready folder and run:

```sh
python3 operator-tools/sgn-i18n install --activate --pack uk-pack --root /srv/sgn-languages
```

The tool reads the language and checksums itself. No long code needs to be copied.
An error stops the command; the old selected pack stays available.
Installing files does not yet apply the site's configuration.

## 3. Apply the site settings once

The site administrator edits the configuration used by the running site,
usually `sgn_local.conf`:

```text
i18n_enabled 1
i18n_enabled_locales en,uk
i18n_catalog_dir /srv/sgn-languages/active
```

For Docker, add this line to the SGN web service's existing `volumes` list.
Keep its other volumes:

```yaml
- /srv/sgn-languages:/srv/sgn-languages:ro
```

Recreate that web container from the usual Compose project folder:

```sh
docker compose up -d --no-deps YOUR_SGN_SERVICE
```

Replace `YOUR_SGN_SERVICE` with the real service name. Keep the site's usual
`-f` and `-p` options. [Restart alone does not apply a new volume](https://docs.docker.com/reference/cli/docker/compose/restart/).
Without Docker, use the site's normal SGN restart command.

## 4. Check the result

Replace `YOUR_SITE_URL` with the site's root URL, such as `https://example.org`:

```sh
python3 operator-tools/sgn-i18n doctor --root /srv/sgn-languages --locale uk --site YOUR_SITE_URL
```

The check reads the selected and previous packs. It also checks the two language
resources and the site's language response. It does not change files, permissions
or settings. It does not prove every screen, calculation or exact remote pack version.

Open a new page, choose **Українська** at the top and click the button beside it.
Check that messages change and trial/accession names stay the same.
Translations are drafts and still need a native speaker and a breeder to review them.

## Update, add a language or undo

For an update, repeat step 2 with the new pack. Open a new page; no restart is
needed when the settings and Docker mount already exist.
For Spanish or Arabic, use `es-pack`/`ar-pack` and add `es`/`ar` to
`i18n_enabled_locales`, then apply the changed settings as in step 3.

To undo the last activation:

```sh
python3 operator-tools/sgn-i18n rollback --root /srv/sgn-languages --locale uk
```

To turn translations off, set `i18n_enabled 0` and restart SGN.

## If it does not work

- **Permission denied:** the administrator should check the SGN account and folder ownership.
- **No language list:** check `i18n_enabled 1`, then repeat step 3.
- **English instead of Ukrainian:** run the check in step 4 and read its error.
- **Only some text stays English:** those messages may not be translated yet.
- **Another operation is running:** wait for it to finish, then check again.

## Other tasks

- [Prepare translations and ready packs](TRANSLATOR.md).
- [Change text in code or adjust optional settings](DEVELOPER.md).
- [Review small batches](REVIEW.md).
- [Build the user manual](../r_markdown_docs/i18n/README.md).
- [Test results and limits](VALIDATION.md).
- [Translation sources and licenses](TRANSLATION_SOURCES.md).
