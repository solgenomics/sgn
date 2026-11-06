# Phenotype heritability design factors

Both `h2_rscript.R` (solGS) and `h2_blup_rscript.R` use `design_factors.R`.
The phenotype file must declare one supported `studyDesign` family and include
study/location metadata. Missing, mixed or unsupported design metadata produces
an explicit error rather than an inferred model.

- CRD: genotype random intercept; accession occurrence numbers are not blocks.
- RCBD/augmented: categorical actual `blockNumber` within each study/environment.
  At least two nonmissing blocks are required; replicate labels are not a fallback.
- Alpha/lattice/incomplete block: categorical replicate within environment and
  block within replicate/environment, with at least two replicates and at least
  two blocks in every replicate.

Design effects are fixed, matching the existing platform design-aware ANOVA and
the H2 consumers' fixed replicate/block intent. Standard sum-to-zero contrasts
over levels are constructed within each parent design group; they do not span
environment means. In an unbalanced table this is a level-based sum constraint,
not an observation-frequency weighted constraint. Blocks are scoped by exported
study, location and year fields. Genotype remains random. The BLUP consumer
retains its existing random location and fixed year terms when applicable; it
refuses a separately unidentifiable location component. The solGS consumer does
not add a location component that its original ratio did not contain.

The reported variance ratios remain `Vg / (Vg + Vres)` for solGS and
`Vg / (Vg + Ve + Vres)` for the BLUP consumer. Variances are selected by grouping
name, never by row order. solGS eligibility uses the number of observed records
per accession for each trait, rather than the largest replicate label. Output
column names and units are retained. No new scientific estimand is introduced.

## Other model output contracts

The lme4 mixed-model tool treats replicate and block labels as categorical.
Its BLUP file retains genotype random-intercept deviations. Adjusted genotype
means add the standard `emmeans` marginal fixed mean, replacing a conditional
intercept whose reference level changed when labels were renamed. Fixed-genotype
BLUE and adjusted-BLUE files use standard genotype marginal means. Schemas and
trait units are unchanged. A model without genotype effects, with genotype
random slopes, or with simultaneous fixed/random genotype terms is explicitly
refused because those outputs do not define the promised genotype means here.

`t/unit/R/ModelConsumers.t` invokes actual R entrypoints on small synthetic
fixtures, including legal agricolae Alpha/lattice books. It checks categorical
label invariance, hierarchical contrast rank and centering, identifiable known
location offsets, plot-ID alignment, output reference ordering and explicit
metadata failures. These are software regressions, not scientific, field, or
production acceptance. Existing field recommendations still need independent
scientific review.

The Sommer interfaces use public `mmes`/`predict` on current packages, with a
legacy public `mmer`/`predict.mmer` path only when both are available. Legacy
simple random-intercept and standard spatial row/column terms map to current
`vsm` structures; the removed `spl2Da` name maps to public `spl2Dc`. Unsupported
legacy random-slope structures fail explicitly. Marginal predictions use an
explicit prediction-term table: fixed terms are averaged and unrelated random
terms excluded. Genotype BLUPs use trait-unit `uList` values, not scaled internal
coefficients or an unavailable `randef` path. Both fixed and random genotype
outputs preserve the genotype-ID plus selected-trait schema. Package-version
compatibility is software acceptance, not qualification of a spatial field model.

The current package qualification targets Sommer 4.4.87 in the pinned test image.
The guarded legacy prediction branch is not acceptance of every older package
version; those environments require their own actual-fit qualification.
