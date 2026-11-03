# Review a translation

The supplied translations are machine-generated drafts. Ask a native speaker
and a breeder to check the text before treating it as approved.

## 1. Make a small review file

Run this from the prepared translation folder. This example exports the first 100 seedlot messages:

```sh
python3 tools/sgn-i18n review --release release.json \
  --po translations/uk.po --workflow seedlots --output "$HOME/uk-seedlots-review-1"
```

The result has two files: `review.po` for editing and `REVIEW.md` for notes.
The original PO is unchanged. The tool keeps complete messages, plural forms
and license notices. An existing output folder is never overwritten.

## 2. Check the wording

Read each message next to its screen, including error and success messages.
Agree on words such as accession, trial, plot, seedlot, cross and trait.
Write the approved wording and reviewer's name in the notes.

Keep context keys, original sources, named values such as `%{name}`, all plural
forms, scientific names, IDs, units and file headers unchanged. Check long text,
small screens, Arabic layout and counts 0/1/2/5/21.

## 3. Save the result

Have the release builder merge reviewed entries into a **copy of the full PO**
using a gettext editor. A 100-message review file cannot replace a whole language.
Keep uncertain entries empty or fuzzy. Keep the review notes with the release.
Then [build and check the new pack](TRANSLATOR.md#3-builder-make-ready-packages).

For the next batch, use a new output folder and add `--offset 100 --limit 100`.
The output tells you the next offset. Other group names are in `release.json`.
If the tool reports missing messages, merge the release POT into the full PO
before exporting again. Unknown groups and invalid ranges stop without making
an output folder.
