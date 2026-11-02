# Review translation terminology by breeding workflow

The supplied Ukrainian, Spanish and Arabic catalogs are machine-translation
drafts. A filled PO record or a successful build is not human linguistic approval.
Use a frozen release contract and a separate workspace to review one workflow:

```sh
bin/i18n/sgn-i18n review --release /release/release.json \
  --po /translations/uk/LC_MESSAGES/sgn.po --workflow seedlots \
  --output /review/uk-seedlots-v1
```

The command preserves the original PO, its attribution, complete message
contexts and required plural forms. `review.po` contains only that workflow;
`REVIEW.md` records the application/source versions and a terminology worksheet.
Exports default to 100 complete source messages; use `--offset 100 --limit 100`
for the next batch. The worksheet records the selected range and workflow total.
Keep each reviewed batch alongside its release and merge it into a copy of the master PO.
Unknown workflows, existing outputs and PO files missing selected messages are
rejected before creating a review folder. Merge the release POT before retrying.
Each batch selects exact context/source/plural identities, including shared contexts. Repeat for
accessions, trials or another name listed by the release snapshot.

Read messages beside their actual screen, including errors and successful
completion notices. Agree how accession, trial, plot, seedlot, cross and trait
are used in this installation. Record approved wording and reviewer in the
worksheet. Keep scientific names, ontology terms, identifiers, units and file
headers in their original data namespace. Preserve named values and every plural
form. Check long labels, zero counts, narrow screens and right-to-left text.

A release owner merges the reviewed subset back into a copy of the master PO
with the standard gettext editor/merge workflow, compiles it against the same
release snapshot and examines the changed messages before activation. Do not
replace the full language catalog with one workflow subset. Mark uncertain
messages fuzzy or empty so the compiler retains complete English fallback.
Maintain a separate review record; do not describe all filled entries as reviewed.
