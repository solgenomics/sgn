# Proposed issue classification and first triage batch

Status: proposal for maintainer discussion. The dated batch below is a review
snapshot, not an adopted policy or a live issue board. Merging this document
does not change issue metadata or organization settings.

## Decisions requested

1. Confirm whether the organization uses the native GitHub issue
   types Bug, Feature and Task, and which names are enabled.
2. Review the field mapping and classification criteria below.
3. Review the first 20 issue recommendations individually before
   applying any metadata changes.

The enabled issue-type catalog has not been verified. Proposed type names must
be matched to the organization's actual types before assignment. If native
types are not used, maintainers can retain the existing label-based process;
this proposal does not request creation, removal or renaming of organization
issue types.

## What goes where

| Information | Location | First-batch rule |
| --- | --- | --- |
| Main kind | Issue **Type** field | One confirmed type |
| Existing categories | Issue **Labels** | Preserve existing labels |
| Area | This review document | No new area labels |
| Priority | Existing `Priority:` labels | No changes |
| Missing detail | Existing `Status:` labels | Add only where listed |
| Fix or overlap | Linked issue/PR evidence | No automatic closure |

The native Type field is separate from labels whose names start with Type:.
Setting a native type does not replace a legacy Type: Bug or Type: Feature
Request label. Keeping those labels in the first batch preserves existing
searches and workflows. Type: User Interface and Type: Configuration remain
useful secondary categories; they are not renamed here.

## Classification criteria

### Bug

A report that existing behavior fails, produces inconsistent data, violates an
established interface contract, or makes existing content unusable. A proposed
new button or visual treatment can be the remedy for a Bug rather than a
separate Feature. Classification does not establish that the defect has been
reproduced on the current deployment.

### Feature

A request for a new supported operation, input, output or deliberate change to
supported behavior. An unsupported new scenario is not automatically a Bug
merely because the current interface rejects it. Existing behavior and the
requested contract still need to be checked.

### Task

Configuration, documentation, tests, curation, maintenance or internal
refactoring without a new supported user operation. Pure query optimization can
be a Task; a report that an existing operation stalls or fails can be a Bug.
Priority is independent of this choice.

### Mixed or unclear requests

Do not invent a Mixed or Needs clarification organization type. Separate
independently actionable Bug and Feature requirements, or leave Type unset
until the relevant contract is clear. Use Status: Discussion Required or
Status: Detail Required only when the issue needs that particular action.
Resolve ambiguity about scientific identity, units and data meaning with the
owner of the workflow rather than guessing.

## First batch: 2026-11-03

The batch covers 20 recent open issues selected on 2026-11-03. It deliberately
leaves the older deferred backlog outside the proposal. All 20 native Type
fields were unset in this snapshot. There are 19 proposed assignments (6 Bug,
12 Feature and 1 Task) and 1 hold.

The exact label plan adds 8 existing labels across 6 issues. There are no label
removals, new label names or priority changes. The current Critical priorities,
including the one on the ExpressionViewer feature request, are retained. Areas
below are review metadata only.

### Overview

| Issue | Proposed native Type | Decision |
| --- | --- | --- |
| [#6409][i6409] | Bug | Review assignment |
| [#6408][i6408] | Bug | Review assignment |
| [#6406][i6406] | Leave unset | Clarify scope |
| [#6399][i6399] | Feature | Review assignment |
| [#6396][i6396] | Feature | Review assignment |
| [#6395][i6395] | Feature | Review assignment |
| [#6394][i6394] | Feature | Review assignment |
| [#6387][i6387] | Feature | Review assignment |
| [#6383][i6383] | Feature | Review assignment |
| [#6382][i6382] | Feature | Review assignment |
| [#6381][i6381] | Bug | Review assignment |
| [#6379][i6379] | Bug | Review assignment |
| [#6377][i6377] | Bug | Review assignment |
| [#6375][i6375] | Feature | Review assignment |
| [#6371][i6371] | Feature | Review assignment |
| [#6370][i6370] | Feature | Review assignment |
| [#6369][i6369] | Feature | Review assignment |
| [#6368][i6368] | Bug | Review assignment |
| [#6360][i6360] | Feature | Review assignment |
| [#6358][i6358] | Task | Review assignment |

### Review and application order

1. Re-read the issue and latest replies before changing metadata.
2. Confirm the enabled organization type names and assignment rights.
3. Apply only the accepted per-issue Type and label changes below.
4. Preserve all priority labels and unlisted labels.
5. Check for an existing implementation before starting new work.
6. Re-read the saved Type and labels to confirm the accepted result.

Two directly linked implementation PRs are open in this snapshot: #6399 is
linked to [PR #6400][p6400], and #6395 to [PR #6397][p6397]. Neither is merged.
A PR, an approval or a maintainer's successful separate example does not by
itself prove that the original report is fixed or deployed.

No duplicate was confirmed by the targeted searches. The possible overlaps for
#6394 and #6383 are identified below; they should not be closed or combined
without confirming scope. Searches, linked PR descriptions, discussions,
reviews and inline threads were checked, but this is not an exhaustive proof
that no differently worded issue or unlinked fix exists. No application tests,
CI runs or deployment checks are claimed.

### Issue #6409: Trial upload treats traits as treatments

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels before:** none.
- **Add labels:** `Type: Bug`.
- **Labels after:** `Type: Bug`.
- **Priority:** unset (unchanged).
- **Area:** Trials & Design (review only).
- **Reason:** The existing trial upload rejects trait input as treatment data.
  The latest maintainer reply reports ontology re-indexing and asks the
  reporter to retry; that does not yet confirm that the original upload
  succeeds.
- **Existing or related work:** No directly linked closing PR was found. See
  the latest retry request in [the discussion][c6409].
- **Follow-up:** Retry the original file after re-indexing before deciding
  whether the report can be closed.

### Issue #6408: JPG upload from a plot page returns a server error

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels before:** none.
- **Add labels:** `Type: Bug`, `Status: Detail Required`.
- **Labels after:** `Type: Bug`, `Status: Detail Required`.
- **Priority:** unset (unchanged).
- **Area:** Images & Files (review only).
- **Reason:** This is a reported failure of an existing upload action. A
  maintainer successfully uploaded a different image on production and
  requested the particular plot and image.
- **Existing or related work:** [PR #6319][p6319] and [PR #6279][p6279] are
  related image/upload work, but neither is established as the fix for this
  plot-page error. See [the request for details][c6408].
- **Follow-up:** Obtain the plot URL, original JPG and error details. Keep the
  report open for diagnosis rather than treating the successful separate
  example as a fix.

### Issue #6406: Split trait creation defects from new features

- **Proposed Type:** Leave unset pending clarification.
- **Labels before:** `Priority: High`, `Type: User Interface`.
- **Add labels:** `Status: Discussion Required`.
- **Labels after:** `Priority: High`, `Type: User Interface`, `Status:
  Discussion Required`.
- **Priority:** High (unchanged).
- **Area:** Traits & Ontology (review only).
- **Reason:** The report combines an existing trait being overwritten without a
  warning, adding synonyms during creation, and creating new grouping terms.
  These need separate acceptance criteria.
- **Existing or related work:** No directly linked closing PR was found.
  Preserve the existing interface label while the scope is discussed.
- **Follow-up:** Separate the possible overwrite defect from the two creation
  features. Establish what is actually overwritten before assigning a single
  type.

### Issue #6399: Add deletion support for transformation stocks

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The request extends the stock deletion script to a stock type it
  does not currently support.
- **Existing or related work:** [PR #6400][p6400] directly references this
  issue. It is open and not merged in this snapshot; its presence does not
  establish acceptance or deployment.
- **Follow-up:** Review the existing implementation rather than starting
  another one.

### Issue #6396: Add an asynchronous list interface

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: Normal`.
- **Priority:** Normal (unchanged).
- **Area:** Search & Lists (review only).
- **Reason:** The title and existing feature label request a new asynchronous
  interface. There is no specific failing operation in the description.
- **Follow-up:** Define the list operations and refresh behavior before
  implementation.

### Issue #6395: Accept UTF-8 sample names in VCF uploads

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: Normal`.
- **Priority:** Normal (unchanged).
- **Area:** Genotyping (review only).
- **Reason:** The request adds an encoding/input-format capability to genotype
  uploads.
- **Existing or related work:** [PR #6397][p6397] directly references this
  issue. It is open and not merged in this snapshot.
- **Follow-up:** Continue the existing PR and verify the intended VCF format
  and encoding during acceptance.

### Issue #6394: Preserve negative raw NIRS measurements

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Phenotyping (review only).
- **Reason:** The requested change replaces rejection of negative raw
  measurements with a warning while preserving the original values.
- **Existing or related work:** Possible partial overlap with [#3293][i3293]
  and [#4165][i4165], which concern metabolomics/high-dimensional data. A
  shared NIRS validator and a duplicate relationship are not established.
- **Follow-up:** Compare the relevant validation paths before deciding whether
  the older requests cover this case.

### Issue #6387: Use seedlot lists as trial design inputs

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Trials & Design (review only).
- **Reason:** A seedlot list would become a new supported input for trial
  design.
- **Existing or related work:** [#5479][i5479] concerns creating seedlots from
  selected trial material, which is a different direction of the workflow.
- **Follow-up:** Define how seedlots map to accessions, including multiple
  seedlots for one accession.

### Issue #6383: Add semi-automatic selfing of transformed lines

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The requested workflow combines selfing with T-generation naming
  and incrementing in the transformation tool.
- **Existing or related work:** Possible partial overlap with [#6099][i6099] on
  T-generation tracking. [#6318][i6318] concerns serial numbering, which is
  related but distinct.
- **Follow-up:** Compare the generation-tracking requirement before creating a
  second implementation.

### Issue #6382: Add an FEC line property

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The request adds an FEC line property to transformation IDs and
  transgenic lines.
- **Existing or related work:** [#6201][i6201] requests an FEC batch field;
  that is not the same property.
- **Follow-up:** Define the property identity and multiplicity. Do not equate
  an FEC line with an FEC batch.

### Issue #6381: Trait tables fail with UTF-8 names or definitions

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels (keep):** `Priority: Critical`, `Type: Bug`.
- **Priority:** Critical (unchanged).
- **Area:** Traits & Ontology (review only).
- **Reason:** The title reports a crash in existing trial-page tables, rather
  than a request for another display feature.
- **Existing or related work:** [PR #6229][p6229] and [PR #6333][p6333] added
  related Unicode/indexing support. They are not confirmed fixes for this
  reported table failure.
- **Follow-up:** Obtain a trait example and the failing response. Earlier
  Unicode support does not establish that this table crash is fixed.

### Issue #6379: Diagnose slow Cassavabase responses

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels before:** none.
- **Add labels:** `Type: Bug`, `Status: Detail Required`.
- **Labels after:** `Type: Bug`, `Status: Detail Required`.
- **Priority:** unset (unchanged).
- **Area:** Infrastructure (review only).
- **Reason:** The report concerns degraded behavior of an existing service, but
  its body does not identify an operation, URL or response time.
- **Existing or related work:** [#6377][i6377] reports a more specific
  trial-page symptom. [PR #6393][p6393] addresses a separate browser-blocking
  script; it is not proof that all slow responses are fixed.
- **Follow-up:** Request specific URLs, operations and observed timings. Do not
  invent a priority or merge the report into another issue without matching
  symptoms.

### Issue #6377: Trial details fail to retrieve the management regime

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels before:** none.
- **Add labels:** `Type: Bug`.
- **Labels after:** `Type: Bug`.
- **Priority:** unset (unchanged).
- **Area:** Trials & Design (review only).
- **Reason:** An existing trial page loads incompletely and reports a
  management-regime error. The discussion also mentions slow seedlot/subplot
  sections and a query executed before its section is opened.
- **Existing or related work:** [PR #6393][p6393] is open and not merged. It
  removes a blocking external script, but is not established as a fix for the
  management-regime error.
- **Follow-up:** Distinguish server-side section delays from browser parsing
  delays and compare the symptom with [#6379][i6379].

### Issue #6375: Reuse existing accessions in the new transgenic upload

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels before:** none.
- **Add labels:** `Type: Feature Request`.
- **Labels after:** `Type: Feature Request`.
- **Priority:** unset (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The request extends the new upload to link existing accessions.
  The replies distinguish this ongoing-experiment workflow from historical
  upload, where reuse is already supported.
- **Existing or related work:** No directly linked closing PR was found.
  Existing support in the historical upload is described in [the
  discussion][c6375].
- **Follow-up:** Define how the new ongoing-experiment upload creates links to
  existing accessions. Use historical upload as a comparison rather than
  treating it as completion of the new workflow.

### Issue #6371: Add transformation metadata upload

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The title and existing feature label identify a new upload
  capability, although the fields and input format are not described.
- **Follow-up:** Record the fields, example file and intended transformation-ID
  relationships before implementation.

### Issue #6370: Reuse a transformation control across projects

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The request changes the reuse rule for one control across
  multiple projects.
- **Existing or related work:** [#6369][i6369] concerns several controls for
  one transformation ID, not reuse of one control across projects.
- **Follow-up:** Define the control's ownership and cross-project
  relationships.

### Issue #6369: Allow multiple controls per transformation ID

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Type: Feature Request`, `Priority: High`.
- **Priority:** High (unchanged).
- **Area:** Transformation (review only).
- **Reason:** The request expands the number of controls associated with a
  transformation ID.
- **Existing or related work:** Related to [#6370][i6370], but the requested
  relationship is different.
- **Follow-up:** Define the role of each control and preserve the distinction
  from cross-project reuse.

### Issue #6368: Registration fails with an invalid-placeholder error

- **Proposed Type:** `Bug` (subject to catalog confirmation).
- **Labels (keep):** `Priority: Critical`, `Type: Bug`.
- **Priority:** Critical (unchanged).
- **Area:** Users & Permissions (review only).
- **Reason:** An existing registration action hangs and returns a server error
  for some input. The report includes the endpoint and exception.
- **Existing or related work:** [PR #5895][p5895] added a registration bot
  check for another issue; it does not establish a fix for this placeholder
  error.
- **Follow-up:** Verify input handling and visible error recovery before
  calling the defect fixed.

### Issue #6360: Reorganize ExpressionViewer selectors

- **Proposed Type:** `Feature` (subject to catalog confirmation).
- **Labels (keep):** `Priority: Critical`, `Type: Feature Request`.
- **Priority:** Critical (unchanged).
- **Area:** Analysis & Statistics (review only).
- **Reason:** Moving selectors to the expression cube/sidebar and adding a
  sub-experiment selector changes available interface behavior.
- **Existing or related work:** [#6358][i6358] concerns the ordering of values,
  not the placement of selectors.
- **Follow-up:** Agree the selector placement and behavior. Preserve the
  existing priority even though the request concerns the interface.

### Issue #6358: Configure tissue and developmental-stage ordering

- **Proposed Type:** `Task` (subject to catalog confirmation).
- **Labels (keep):** `Priority: High`, `Type: Configuration`.
- **Priority:** High (unchanged).
- **Area:** Analysis & Statistics (review only).
- **Reason:** The author supplies a specific order for tissues and stages. This
  is configuration work rather than a reported failure or a new general-purpose
  tool.
- **Existing or related work:** Related to [#6360][i6360], but this ordering
  change is a separate requirement.
- **Follow-up:** Use the requested ordering without changing the scientific
  identifiers or names.

[i3293]: https://github.com/solgenomics/sgn/issues/3293
[i4165]: https://github.com/solgenomics/sgn/issues/4165
[i5479]: https://github.com/solgenomics/sgn/issues/5479
[i6099]: https://github.com/solgenomics/sgn/issues/6099
[i6201]: https://github.com/solgenomics/sgn/issues/6201
[i6318]: https://github.com/solgenomics/sgn/issues/6318
[i6358]: https://github.com/solgenomics/sgn/issues/6358
[i6360]: https://github.com/solgenomics/sgn/issues/6360
[i6368]: https://github.com/solgenomics/sgn/issues/6368
[i6369]: https://github.com/solgenomics/sgn/issues/6369
[i6370]: https://github.com/solgenomics/sgn/issues/6370
[i6371]: https://github.com/solgenomics/sgn/issues/6371
[i6375]: https://github.com/solgenomics/sgn/issues/6375
[i6377]: https://github.com/solgenomics/sgn/issues/6377
[i6379]: https://github.com/solgenomics/sgn/issues/6379
[i6381]: https://github.com/solgenomics/sgn/issues/6381
[i6382]: https://github.com/solgenomics/sgn/issues/6382
[i6383]: https://github.com/solgenomics/sgn/issues/6383
[i6387]: https://github.com/solgenomics/sgn/issues/6387
[i6394]: https://github.com/solgenomics/sgn/issues/6394
[i6395]: https://github.com/solgenomics/sgn/issues/6395
[i6396]: https://github.com/solgenomics/sgn/issues/6396
[i6399]: https://github.com/solgenomics/sgn/issues/6399
[i6406]: https://github.com/solgenomics/sgn/issues/6406
[i6408]: https://github.com/solgenomics/sgn/issues/6408
[i6409]: https://github.com/solgenomics/sgn/issues/6409
[p5895]: https://github.com/solgenomics/sgn/pull/5895
[p6229]: https://github.com/solgenomics/sgn/pull/6229
[p6279]: https://github.com/solgenomics/sgn/pull/6279
[p6319]: https://github.com/solgenomics/sgn/pull/6319
[p6333]: https://github.com/solgenomics/sgn/pull/6333
[p6393]: https://github.com/solgenomics/sgn/pull/6393
[p6397]: https://github.com/solgenomics/sgn/pull/6397
[p6400]: https://github.com/solgenomics/sgn/pull/6400
[c6408]: https://github.com/solgenomics/sgn/issues/6408#issuecomment-6608250787
[c6409]: https://github.com/solgenomics/sgn/issues/6409#issuecomment-6609231938
[c6375]: https://github.com/solgenomics/sgn/issues/6375#issuecomment-6378675647
