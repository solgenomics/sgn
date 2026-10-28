# Maintaining translated interface messages

Keep the source registry and workflow assignments aligned. Register only current
first-party presentation/support files; do not resurrect deleted upstream files,
retired screens or archived wording. Catalog extraction is source analysis,
not an application calculation or a source rewriter.

For an existing component:

1. Keep current upstream conditions, field names, handlers, IDs and URLs.
2. Mark complete constant messages with a semantic context and named values.
3. Escape the resulting plain text at its actual output sink. Preserve raw
   scientific names, identifiers, units, numbers, protocol keys and file headers.
4. Update the source template, merge and review the PO entries, then build.
5. Run the component's native tests with English/default-disabled behavior and
   the supported locales, including asynchronous text and RTL/narrow layouts.

A changed English source is a new lookup key even when its context is retained.
Missing/fuzzy/incomplete entries fall back to whole English messages. Never use
an old translation by approximate matching. Update new upstream captions rather
than restoring old control flow just because its previous caption is translated.

Keep scientific inputs/outputs and machine status values independent of UI
language. Encoding-boundary tests should compare original identifiers and
numeric/ASCII JSON types. Do not execute real analysis jobs, email or production
writes merely to validate human wording.

Large sites should test common/workflow partition loading and unchanged existing
pack activation before release. Limits remain independent per catalog; do not
silently raise them to accommodate a new group. Translation counts describe the
registered message set, not linguistic certification or proof of every route.

Translated manuals, domain terminology review and additional languages can be
reviewed independently from runtime/caption maintenance. Use the standard SGN
unit/fixture test locations so the repository's CI actually runs regressions.
