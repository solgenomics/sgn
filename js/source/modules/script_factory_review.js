// Model review of the Analysis Pipeline (/tools/script_factory).
//
// When an analysis is run, the page looks at the model that was chosen, for
// the dataset it runs on, and lists what may be worth a second look:
// field-position (spatial) adjustments applied more than once, models with
// more terms than the data can carry, effects estimated from very few levels,
// covariates that nearly repeat the trait... After the run, the results are
// read for the usual signs of overfitting (heritability close to 1, almost no
// residual variance) or of terms the data could not support.
//
// Nothing here stops the analysis: it runs exactly as it was set up. Each
// finding may carry a fix; all fixes together make a "suggested" recipe that
// the researcher can run as well, compare side by side and keep or not.
//
// Pure functions: the page passes the recipe, the dataset facts and the
// results, and renders what comes back.

const clone = o => JSON.parse(JSON.stringify(o));
const arr = v => Array.isArray(v) ? v : [];
const num = v => (v === null || v === undefined || v === '' || isNaN(Number(v))) ? null : Number(v);

// trait names that suggest values already adjusted by a model (spatial
// correction, BLUEs / BLUPs, residuals). "adj" alone is left out: it usually
// means a moisture-adjusted yield.
const ADJUSTED_NAME = /spatial|corrected|\bblues?\b|\bblups?\b|_blues?\b|_blups?\b|lsmeans?|residual/i;

// ---------------------------------------------------------------------------
// before the run: the recipe and the dataset
// ---------------------------------------------------------------------------

// recipe: the recipe that runs (buildRecipe())
// ctx: {
//   trials: [{ trial, design, n_plots, n_accessions, has_rowcol, rep, block, row, col (bool: supported) }],
//   n_locations, n_years, short: trait -> short name,
//   rowcolAuto: rows / columns used by the single-stage "automatic" choice,
//   blockAuto: blocks used by the single-stage "automatic" choice,
//   engine: 'lme4' | 'blupf90',
//   corr: { trait: { covariate: r } } (plot-level correlations, when known),
//   genotyped: { n_genotyped, n_accessions } (genomic models, when known)
// }
// Returns { findings: [{ id, level: 'look' | 'note', title, text, fix, apply }], suggested }
export function reviewModel(recipe, ctx) {
    const f = [];
    const trials = arr(ctx.trials);
    const short = ctx.short || (t => t);
    const two = recipe.strategy === 'two_stage';
    const s = recipe.single || {};
    const custom = !two && s.mode === 'custom';
    const rcTrials = trials.filter(t => t.has_rowcol);
    const nTrials = trials.length;

    // what the field-position part of the model holds
    const stage1Spatial = two && rcTrials.length > 0 && (recipe.stage1 || {}).model !== 'design';
    const singleRowcol = !two && !custom && (s.rowcol === 'random' || (s.rowcol === 'auto' && ctx.rowcolAuto)) && trials.some(t => t.row || t.col);
    const singleTrend = !two && !custom && s.trend === 'linear' && trials.some(t => t.has_rowcol);
    const singleBlock = !two && !custom && (s.block === 'fixed' || s.block === 'random' || (s.block === 'auto' && ctx.blockAuto)) && trials.some(t => t.block);
    const formula = custom ? String(s.formula || '') : '';
    const fRow = /\brow\b/.test(formula) || /\bcol\b/.test(formula);
    const fTrend = /\browN\b|\bcolN\b/.test(formula);
    const fBlock = /\bblock\b/.test(formula);
    const anySpatial = stage1Spatial || singleRowcol || singleTrend || (custom && (fRow || fTrend));

    // 1. values that look already adjusted, adjusted again for field position
    const adjusted = arr(recipe.traits).filter(t => ADJUSTED_NAME.test(short(t)));
    if (adjusted.length && anySpatial) {
        f.push({
            id: 'adjusted_traits', level: 'look',
            title: 'These values may already be adjusted for field position',
            text: 'From their names, ' + adjusted.map(short).join(', ') + ' look like values that already went through a model (spatial correction, BLUEs or BLUPs). ' +
                'If so, adjusting them for rows, columns or a spatial surface again removes the same field effect twice, which can shrink real differences between genotypes. ' +
                'If they are raw measurements, this is fine as it is.',
            fix: two ? 'Use the design model in stage 1 (no spatial surface).' : 'Leave rows, columns and the linear trend out of the model.',
            apply: r => {
                if (r.strategy === 'two_stage') r.stage1.model = 'design';
                else if (r.single.mode !== 'custom') { r.single.rowcol = 'none'; r.single.trend = 'none'; }
            }
        });
    }

    // 2. several field-position adjustments at once (single stage)
    const layers = [singleRowcol && 'random rows and columns', singleTrend && 'a linear row and column trend', singleBlock && 'incomplete blocks'].filter(Boolean);
    if (layers.length === 3) {
        f.push({
            id: 'spatial_layers', level: 'look',
            title: 'Field position is adjusted in three ways at once',
            text: 'The model has ' + layers.join(', ') + '. Each of them describes where a plot sits in the field, so together they compete for the same variation, ' +
                'and the model can end up fitting noise. Rows and columns with a trend usually capture what the blocks would.',
            fix: 'Keep rows, columns and the trend; leave the incomplete blocks out.',
            apply: r => { r.single.block = 'none'; }
        });
    }
    if (custom && fRow && fTrend && fBlock) {
        f.push({
            id: 'spatial_layers_custom', level: 'look',
            title: 'Your formula adjusts field position in three ways at once',
            text: 'It has row or column effects, a row / column trend (rowN, colN) and blocks. They describe the same thing, where a plot sits in the field, ' +
                'and together they can fit noise. You may want to keep two of them.',
            fix: '', apply: null
        });
    }

    // 3. spatial or design terms with few plots left to estimate them (two stages)
    if (two) {
        const thin = trials.filter(t => {
            const df = (t.n_plots || 0) - (t.n_accessions || 0);
            return (t.has_rowcol && stage1Spatial) ? df < 15 : df < 5 && (t.rep || t.block);
        });
        if (thin.length) {
            f.push({
                id: 'thin_trials', level: 'look',
                title: 'Some trials have few plots left to estimate the field effects',
                text: thin.length + ' of ' + nTrials + ' trial(s) (' + thin.slice(0, 4).map(t => t.trial).join(', ') + (thin.length > 4 ? '...' : '') + ') have only a handful of plots ' +
                    'beyond one per accession. After the genotypes are estimated there is little information left for ' + (stage1Spatial ? 'a spatial surface with row and column effects' : 'replicate and block effects') +
                    ', so their estimates can follow the noise of a few plots.',
                fix: stage1Spatial ? 'Use the design model in stage 1 for a lighter model.' : '',
                apply: stage1Spatial ? (r => { r.stage1.model = 'design'; }) : null
            });
        }
    }

    // 4. variances or interactions from very few levels (single stage)
    if (!two && !custom) {
        if (s.env === 'random' && nTrials > 1 && nTrials < 5) {
            f.push({
                id: 'env_random_few', level: 'note',
                title: 'The trial variance comes from ' + nTrials + ' trials',
                text: 'With the trial as a random effect, its variance is estimated from only ' + nTrials + ' trial means, which is not much to go on. ' +
                    'As a fixed effect the trials are simply compared with each other, which is usually steadier with few trials.',
                fix: 'Use the trial as a fixed effect.',
                apply: r => { r.single.env = 'fixed'; }
            });
        }
        const nOf = { trial: nTrials, location: ctx.n_locations || 0, year: ctx.n_years || 0 };
        const fewGxe = arr(s.gxe).filter(g => nOf[g] > 1 && nOf[g] < 3);
        if (fewGxe.length) {
            f.push({
                id: 'gxe_few', level: 'look',
                title: 'Genotype x environment from ' + fewGxe.map(g => nOf[g] + ' ' + g + 's').join(' and '),
                text: 'An interaction variance needs several environments to be told apart from the genetic variance and the residual. ' +
                    'With ' + fewGxe.map(g => nOf[g] + ' ' + g + 's').join(' and ') + ' it is hard to estimate, and it can take part of the genetic variance with it.',
                fix: 'Leave accession x ' + fewGxe.join(' and accession x ') + ' out of the model.',
                apply: r => { r.single.gxe = arr(r.single.gxe).filter(g => fewGxe.indexOf(g) < 0); r.single.include_gxe = r.single.gxe.indexOf('trial') >= 0; }
            });
        }
    }

    // 5. covariates that nearly repeat the trait
    const covs = arr(recipe.covariates);
    const close = [];
    arr(recipe.traits).forEach(t => covs.forEach(c => {
        const r = ctx.corr && ctx.corr[t] && ctx.corr[t][c];
        if (c !== t && r !== undefined && r !== null && Math.abs(r) >= 0.9) close.push({ t: t, c: c, r: r });
    }));
    if (close.length) {
        const drop = close.map(x => x.c).filter((v, i, a) => a.indexOf(v) === i);
        f.push({
            id: 'covariate_close', level: 'look',
            title: 'A covariate almost repeats the trait',
            text: close.map(x => short(x.c) + ' and ' + short(x.t) + ' (r = ' + x.r.toFixed(2) + ')').join('; ') + ' move together on almost every plot. ' +
                'Used as a covariate, it can explain away part of the genetic differences you want to measure, not only the plot-to-plot noise.',
            fix: 'Leave ' + drop.map(short).join(', ') + ' out as covariate.',
            apply: r => { r.covariates = arr(r.covariates).filter(c => drop.indexOf(c) < 0); if (r.single) r.single.covariates = arr(r.single.covariates).filter(c => drop.indexOf(c) < 0); }
        });
    }

    // 6. every measurement modelled, plus spatial terms
    const repAll = Object.keys(((recipe.repeated || {}).traits) || {}).filter(t => recipe.repeated.traits[t] === 'all');
    if (repAll.length && !two && (singleRowcol || singleTrend)) {
        f.push({
            id: 'repeated_spatial', level: 'note',
            title: 'Repeated measurements and field position in one model',
            text: repAll.map(short).join(', ') + ' enter with every measurement, so each plot also gets its own effect. Together with the row and column terms this is a large model; ' +
                'it is worth checking in the results that the variances look reasonable.',
            fix: '', apply: null
        });
    }

    // 7. genomic models with few genotyped accessions
    const g = recipe.genetic || {};
    const gt = ctx.genotyped;
    if ((g.model === 'genomic' || g.model === 'single_step') && gt && gt.n_accessions && gt.n_genotyped / gt.n_accessions < 0.5) {
        f.push({
            id: 'few_genotyped', level: 'note',
            title: 'Fewer than half of the accessions are genotyped',
            text: gt.n_genotyped + ' of ' + gt.n_accessions + ' accessions have genotypes. ' + (g.model === 'genomic'
                ? 'In the genomic (G) model the others are treated as unrelated, so their values gain little from the markers.'
                : 'The single-step (H) model links the others through the pedigree, so the result depends a lot on how complete the pedigree is.'),
            fix: '', apply: null
        });
    }

    // 8. environmental zones from few trials
    if (recipe.zones && recipe.zones.enabled && nTrials > 1 && nTrials < 4) {
        f.push({
            id: 'zones_few', level: 'note',
            title: 'Environmental zones from ' + nTrials + ' trials',
            text: 'Grouping environments compares how genotypes rank in each of them; with ' + nTrials + ' trials the groups can change a lot with a single trial. ' +
                'Read them as a first hint rather than a final grouping.',
            fix: '', apply: null
        });
    }

    return { findings: f, suggested: suggestedRecipe(recipe, f) };
}

// the recipe with the fixes of the findings applied, or null when nothing changes
export function suggestedRecipe(recipe, findings) {
    const fixes = arr(findings).filter(x => typeof x.apply === 'function');
    if (!fixes.length) return null;
    const r = clone(recipe);
    fixes.forEach(x => x.apply(r));
    return JSON.stringify(r) === JSON.stringify(recipe) ? null : r;
}

// ---------------------------------------------------------------------------
// after the run: the results
// ---------------------------------------------------------------------------

// res: results of a run; recipe: the recipe that ran; hasRowcol: some trial
// has rows and columns. Returns findings, with a fix when a lighter model is
// worth comparing.
export function reviewResults(res, recipe, hasRowcol) {
    const f = [];
    const s2 = arr(res && res.stage2);
    const two = recipe && recipe.strategy === 'two_stage';

    const high = s2.filter(x => num(x.h2) !== null && num(x.h2) >= 0.95);
    const tinyE = s2.filter(x => {
        const ve = num(x.var_e), vg = num(x.var_g) || 0, vge = num(x.var_ge) || 0;
        return ve !== null && (ve + vg + vge) > 0 && ve / (ve + vg + vge) < 0.02;
    });
    const zeroG = s2.filter(x => num(x.var_g) !== null && num(x.var_g) <= 1e-8);
    // a lighter model: no spatial surface in stage 1; in a single stage, no
    // linear trend, or else no incomplete blocks next to rows and columns
    const ss = (recipe && recipe.single) || {};
    const singleLighter = !two && ss.mode !== 'custom' && (ss.trend === 'linear' || (ss.block !== 'none' && ss.rowcol !== 'none'));
    const canLighten = !!recipe && (two ? hasRowcol && (recipe.stage1 || {}).model !== 'design' : singleLighter);
    // decided once from the recipe that ran, so that several findings sharing
    // this fix change the same single thing
    const dropTrend = ss.trend === 'linear';
    const lighter = r => {
        if (r.strategy === 'two_stage') r.stage1.model = 'design';
        else if (dropTrend) r.single.trend = 'none';
        else r.single.block = 'none';
    };

    if (high.length) {
        f.push({
            id: 'h2_high', level: 'look',
            title: 'Heritability very close to 1 for ' + high.map(x => x.trait).join(', '),
            text: high.map(x => x.trait + ' H² = ' + Number(x.h2).toFixed(2)).join('; ') + '. This can be real for a highly heritable trait measured with many replicates. ' +
                'It also happens when the model is flexible enough to fit noise as if it were genetic. Running a lighter model and comparing the rankings is an easy way to tell.',
            fix: canLighten ? (two ? 'Compare with the design model in stage 1 (no spatial surface).' : ss.trend === 'linear' ? 'Compare without the linear trend.' : 'Compare without the incomplete blocks.') : '',
            apply: canLighten ? lighter : null
        });
    }
    if (tinyE.length) {
        f.push({
            id: 'resid_tiny', level: 'look',
            title: 'Almost no residual variance left for ' + tinyE.map(x => x.trait).join(', '),
            text: 'Less than 2% of the variance stayed in the residual. Real data nearly always keep some plot-to-plot noise, so this usually means the other terms took it over, ' +
                'which makes the genotype values look more certain than they are.',
            fix: canLighten ? 'Compare with a lighter model.' : '',
            apply: canLighten ? lighter : null
        });
    }
    if (zeroG.length) {
        f.push({
            id: 'var_g_zero', level: 'note',
            title: 'No genetic variance found for ' + zeroG.map(x => x.trait).join(', '),
            text: 'The genetic variance was estimated at zero, so the genotype values of these traits are all shrunk to the mean. ' +
                'It can be a real lack of differences, very noisy data, or a model where another term (an interaction, a covariate) took the genetic part.',
            fix: '', apply: null
        });
    }

    const s1 = arr(res && res.stage1);
    const lowCv = s1.filter(x => num(x.cv) !== null && num(x.cv) > 0 && num(x.cv) < 2);
    const hiH2 = s1.filter(x => num(x.h2) !== null && num(x.h2) >= 0.98);
    if (lowCv.length || hiH2.length) {
        const list = lowCv.concat(hiH2.filter(x => lowCv.indexOf(x) < 0));
        f.push({
            id: 'stage1_tight', level: 'note',
            title: 'Some trials look unusually precise',
            text: list.length + ' trial / trait fit(s) in stage 1 have ' + (lowCv.length ? 'a CV below 2%' : '') + (lowCv.length && hiH2.length ? ' or ' : '') + (hiH2.length ? 'a heritability of 0.98 or more' : '') +
                ' (for example ' + list.slice(0, 3).map(x => x.trial + ' / ' + x.trait).join(', ') + '). Field trials are rarely that precise; it is worth a look at the model of these trials.',
            fix: '', apply: null
        });
    }

    const approx = arr(res && res.warnings).map(String).filter(m => /still changing after a refit with/.test(m));
    if (approx.length) {
        f.push({
            id: 'convergence_approx', level: 'note',
            title: 'A few variance estimates are approximate',
            text: approx.length + ' fit(s) kept changing slightly even after a steadier refit (' + approx.slice(0, 3).map(m => m.split(':')[0]).join('; ') + (approx.length > 3 ? '...' : '') + '). ' +
                'This usually means a replicate, block or row effect is close to zero in those trials; the genotype values are then little affected, only that variance is imprecise. ' +
                'The details are under Convergence notes in the analysis log.',
            fix: '', apply: null
        });
    }

    const dropped = s2.filter(x => x.dropped_terms);
    if (dropped.length) {
        f.push({
            id: 'dropped_terms', level: 'note',
            title: 'A few terms were left out by the analysis',
            text: dropped.map(x => x.trait + ': ' + x.dropped_terms).join('; ') + '. The data could not support them, so the analysis kept the model that it could estimate. Nothing to do, just good to know.',
            fix: '', apply: null
        });
    }
    return f;
}

// ---------------------------------------------------------------------------
// the two runs side by side
// ---------------------------------------------------------------------------

function pearson(x, y) {
    const n = x.length;
    if (n < 3) return null;
    const mx = x.reduce((a, b) => a + b, 0) / n, my = y.reduce((a, b) => a + b, 0) / n;
    let sxy = 0, sxx = 0, syy = 0;
    for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
    return sxx > 0 && syy > 0 ? sxy / Math.sqrt(sxx * syy) : null;
}

// selection accuracy of a trait in a run's results: the pipeline's value (index
// gains), else computed as it does: mean sqrt(1 - SE^2 / var_g) over the
// accessions (genotype random), sqrt(H2) without standard errors
export function traitAccuracy(res, trait) {
    const g = arr(res && res.index && res.index.gains).find(x => x.trait === trait);
    if (g && num(g.accuracy) !== null) return num(g.accuracy);
    const s2 = arr(res && res.stage2).find(x => x.trait === trait) || {};
    const vg = num(s2.var_g), h2 = num(s2.h2);
    const random = !res || res.genotype_effect !== 'fixed';
    const se = arr(res && res.genotype_values_long).filter(x => x.trait === trait).map(x => num(x.se)).filter(x => x !== null);
    if (random && vg !== null && vg > 0 && se.length) return se.reduce((a, x) => a + Math.sqrt(Math.max(0, 1 - x * x / vg)), 0) / se.length;
    return h2 !== null && random ? Math.sqrt(Math.max(0, h2)) : null;
}

// a, b: results of the two runs; decrease(trait): true when lower values are
// better (selection index direction). Returns one row per trait:
// { trait, a: {h2, var_g, var_e, model}, b: {...}, r, top: {n, same} }
export function compareRuns(a, b, decrease) {
    const byTrait = res => { const o = {}; arr(res && res.stage2).forEach(x => { o[x.trait] = x; }); return o; };
    const A = byTrait(a), B = byTrait(b);
    const gv = res => {
        const o = {};
        arr(res && res.genotype_values).forEach(row => { o[row.accession] = row; });
        return o;
    };
    const GA = gv(a), GB = gv(b);
    const shared = Object.keys(GA).filter(k => GB[k]);
    return Object.keys(A).filter(t => B[t]).map(t => {
        const pairs = shared.map(acc => [num(GA[acc][t]), num(GB[acc][t]), acc]).filter(p => p[0] !== null && p[1] !== null);
        const r = pearson(pairs.map(p => p[0]), pairs.map(p => p[1]));
        let top = null;
        if (pairs.length >= 10) {
            const k = Math.max(1, Math.round(pairs.length * 0.1));
            const sign = decrease && decrease(t) ? 1 : -1;
            const best = i => pairs.slice().sort((p, q) => sign * (p[i] - q[i])).slice(0, k).map(p => p[2]);
            const ta = best(0), tb = best(1);
            top = { n: k, same: ta.filter(x => tb.indexOf(x) >= 0).length };
        }
        const pick = (x, res) => ({ h2: num(x.h2), var_g: num(x.var_g), var_e: num(x.var_e), model: x.model || '', acc: traitAccuracy(res, t) });
        return { trait: t, a: pick(A[t], a), b: pick(B[t], b), r: r, top: top };
    });
}
