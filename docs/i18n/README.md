# Turn on translations

This guide adds Ukrainian to an existing SGN site. English stays available.
The language choice changes buttons and messages, not trial names or data.
Spanish uses `es`; Arabic uses `ar`.

## 1. Get the files

The SGN version with this feature must already be running on the server.
Have the administrator run steps 2 and 3 as the server account that runs SGN.
In Docker, the mounted files must belong to that account inside the container.
Here `~` means the home folder of that SGN account.

Ask the person who builds the site for these files on that server:

- A ready Ukrainian pack. Put its whole folder at `~/uk-pack`.
  It must contain `manifest.json` and the supplied JSON files.
  Unpack an archive first.
- These four tool files. Put them together in `~/sgn-i18n`:

  ```text
  sgn-i18n
  pack.py
  catalog_format.py
  plural.py
  ```

A PO file is an editable translation, not an installable pack.
If you only have PO files, use [Build a language pack](TRANSLATOR.md).
This PR does not publish a ready-pack download.

You need Python 3.9 or newer. That SGN account needs write access to
`/srv/sgn-languages`; ask the administrator to prepare it.
This folder holds the installed languages. Start with an empty folder for the
first installation. Keep its contents when updating.

## 2. Install the pack

```sh
python3 ~/sgn-i18n/sgn-i18n install --pack ~/uk-pack --root /srv/sgn-languages
```

The command prints `installed` followed by a long code. Copy that code without
its quotation marks. The site has not changed yet.

## 3. Select the pack

Replace `PASTE_CODE_HERE` with the code from step 2, then run:

```sh
python3 ~/sgn-i18n/sgn-i18n activate --locale uk --hash PASTE_CODE_HERE --root /srv/sgn-languages
```

## 4. Change the site settings

The site administrator does this step.
Edit the configuration file used by the running site, usually `sgn_local.conf`.
Add or update these three lines:

```text
i18n_enabled 1
i18n_enabled_locales en,uk
i18n_catalog_dir /srv/sgn-languages/active
```

For Docker, add this line to the SGN web service's existing `volumes` list in
your Compose file. Keep its other volumes:

```yaml
- /srv/sgn-languages:/srv/sgn-languages:ro
```

Recreate the SGN web container. From your usual Compose project folder, use:

```sh
docker compose up -d --no-deps YOUR_SGN_SERVICE
```

Replace `YOUR_SGN_SERVICE` with the SGN service name in your Compose file.
Keep the site's usual `-f` and `-p` options if it uses them.
A restart alone does not add a new volume;
see [Docker's restart documentation](https://docs.docker.com/reference/cli/docker/compose/restart/).
For a site without Docker, restart SGN using its normal service command.

## 5. Check the page

Open a new page. Choose **Українська** in the language list at the top.
Click the button beside the list.
Buttons and messages should change language. Trial and accession names should
stay the same. The supplied translations still need human review.

## Update or undo

For an update, repeat steps 2 and 3 with the new pack. You do not need a restart
when the settings and Docker volume are already in place. Open a new page.

To undo the last activation:

```sh
python3 ~/sgn-i18n/sgn-i18n rollback --locale uk --root /srv/sgn-languages
```

To turn translations off, set `i18n_enabled 0` in the site configuration and
restart SGN. Keep the language folder for later use.

## Add Spanish or Arabic

Use that language's own pack. Repeat steps 2 and 3 with `es` or `ar`.
Then add the tag to the settings, for example:
`i18n_enabled_locales en,uk,es,ar`. Apply the changed settings as in step 4.

## If it does not work

- **Cannot open the tool:** check that all four files are in `~/sgn-i18n`.
- **Permission denied:** ask the administrator to check the account and folder permissions.
- **No language list:** check `i18n_enabled 1`, then repeat step 4.
- **Only English is listed:** check that activation succeeded, the configuration
  lists `uk`, and the running site can read the whole language folder. Check the server log.
- **Some text stays English:** that message may not be translated yet.

## Other tasks

- [Build or translate a pack](TRANSLATOR.md).
- [Change text in the code, debug it, or change optional settings](DEVELOPER.md).
- [Review translations](REVIEW.md).
- [Build the user manual](../r_markdown_docs/i18n/README.md).
- [Test results and known limits](VALIDATION.md).
- [Translation sources and licenses](TRANSLATION_SOURCES.md).
