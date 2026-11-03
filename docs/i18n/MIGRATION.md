# Update an existing screen

Use this when adding translations to code that already works.
For site setup, use [Turn on translations](README.md).

1. Keep the existing conditions, URLs, IDs, field names and handlers.
2. Wrap complete English messages with the [normal helper](DEVELOPER.md#1-add-the-message).
3. Keep scientific data and machine values unchanged. Escape the translated
   plain text where it is displayed.
4. Add new source files to `locale/sources.txt` and `locale/workflows.json`.
5. Run that screen's native tests with translations off and in each supported
   language. Check asynchronous messages, small screens and Arabic layout.
6. At release time, [refresh the message list and build packs](TRANSLATOR.md).

When English wording changes, it is a new lookup key even if the context stays
the same. Review the changed entry. Until then, the site shows whole English
text. Do not reuse a similar old translation or restore old application logic
just to keep a translation.

Use synthetic fixtures to compare IDs, numbers, JSON types and import/export
fields. Do not use real mail, production writes or scientific jobs to test text.
Register only current first-party files; leave deleted screens and vendor code
out of the source list. Use SGN's normal test folders so CI runs the checks.

Check a pack update and rollback as part of release testing. Keep the 2 MiB
per-file limit. Translation coverage counts do not prove language quality or
coverage of every route. Manuals and terminology review can be checked
separately from a screen change.
