/*
 * Analysis Pipeline - front end for /tools/script_factory
 *
 * Builds an analysis "recipe" step by step (data, quality control, model,
 * selection index, environmental zones), runs it as a background job through
 * /ajax/script_factory/*, shows the results and lets the user store the
 * analysis, save accessions as a list and save / export the recipe as a
 * reusable script.
 *
 * Plots are drawn as plain SVG so no extra library is needed.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

import { openStoreDialog, storedNotice } from '../modules/script_factory_store.js';
import { analysisLogHtml, analysisLogSummaryHtml } from '../modules/script_factory_log.js';

const VERSION = '1.5';
const SVGNS = 'http://www.w3.org/2000/svg';
const ZONE_COLORS = ['#2b7a4b', '#2563eb', '#d97706', '#9333ea', '#dc2626', '#0891b2', '#65a30d', '#db2777', '#4b5563', '#b45309'];
const DESIGNS = {
    auto: 'Detected',
    rcbd: 'RCBD',
    alpha_lattice: 'Alpha-lattice',
    row_column: 'Row-column',
    augmented: 'Augmented',
    crd: 'CRD',
    unreplicated: 'Unreplicated'
};

let $;
let cfg = {};
const state = {
    step: 1,
    dataset: null,          // response of /prepare
    traits: [],             // selected full trait names
    plotData: null,         // response of /plot_data
    plotDataKey: '',
    exclusions: {},         // "unit|trait" -> {unit, trait, trial, accession, value, marked}; marked: 'dataset' | 'database' | 'both' for values marked in Breedbase
    madrFlags: {},          // "unit|trait" -> true (from a preview run)
    outlierRows: [],        // current full outlier list (rule + individual)
    outlierSel: {},         // "unit|trait" -> true, selected in the list
    outlierStatus: {},      // "unit|trait" -> {dataset, database} as stored in Breedbase
    outlierChecking: {},    // status requests in flight
    indexCfg: {},           // full trait -> {weight, direction}
    zoneTargets: { index: true },
    designOverrides: {},    // trial -> design
    singleCov: {},          // full trait -> true, covariates of the single-stage model
    trt: null,              // {use: {name: true}, gxt: {name: true}} treatments in the models; null = defaults of the dataset
    pendingRecipe: null,    // recipe loaded before a dataset
    script: { id: null, name: null, description: '', is_public: 0, is_owner: 1 },
    lastRun: null,          // {key, finishedAt, seconds} of the last successful run
    runFailed: false,
    scriptLoaded: false,    // a saved or imported script was applied (enables "Run whole script")
    missingTraits: [],      // script traits not found in the loaded dataset
    job: null,
    results: null,
    pollTimer: null,
    elapsedTimer: null
};

// ---------------------------------------------------------------------------
// small helpers
// ---------------------------------------------------------------------------

function esc(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function arr(x) {
    if (x === null || x === undefined) return [];
    return Array.isArray(x) ? x : [x];
}

function fmt(x, d) {
    if (d === undefined) d = 3;
    if (x === null || x === undefined || x === '' || !isFinite(Number(x))) return '&ndash;';
    const v = Number(x);
    if (Math.abs(v) >= 1000) return v.toFixed(0);
    if (Math.abs(v) >= 100) return v.toFixed(1);
    return v.toFixed(d);
}

function shortTrait(t) {
    return String(t).replace(/\|.*$/, '');
}

function alertBox(type, html) {
    return '<div class="alert alert-' + type + '" style="margin-top:12px">' + html + '</div>';
}

function post(url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, type: 'POST', data: data, dataType: 'json' })
            .done(r => {
                if (r && r.error) reject(new Error(r.error)); else resolve(r);
            })
            .fail((xhr, status, err) => reject(new Error('Server error: ' + (err || status))));
    });
}

function download(filename, content, type) {
    const blob = new Blob([content], { type: type || 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 100);
}

function svgEl(name, attrs, parent) {
    const el = document.createElementNS(SVGNS, name);
    Object.keys(attrs || {}).forEach(k => el.setAttribute(k, attrs[k]));
    if (parent) parent.appendChild(el);
    return el;
}

function quantile(sorted, p) {
    // R type 7
    if (!sorted.length) return NaN;
    const h = (sorted.length - 1) * p;
    const lo = Math.floor(h);
    const hi = Math.ceil(h);
    return sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo]);
}

function hash(s) {
    let h = 0;
    for (let i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0;
    return (Math.abs(h) % 1000) / 1000;
}

function niceTicks(min, max, n) {
    if (!isFinite(min) || !isFinite(max)) return [];
    if (min === max) { min -= 1; max += 1; }
    const span = max - min;
    const step0 = Math.pow(10, Math.floor(Math.log10(span / n)));
    const err = span / n / step0;
    const step = step0 * (err >= 7.5 ? 10 : err >= 3.5 ? 5 : err >= 1.5 ? 2 : 1);
    const ticks = [];
    for (let v = Math.ceil(min / step) * step; v <= max + 1e-9; v += step) ticks.push(Number(v.toPrecision(12)));
    return ticks;
}

function dataTable(selector, opts) {
    if ($.fn.DataTable) {
        $(selector).DataTable(Object.assign({ pageLength: 25, autoWidth: false }, opts || {}));
    }
}

// ---------------------------------------------------------------------------
// recipe
// ---------------------------------------------------------------------------

function radio(name) {
    return $('input[name=' + name + ']:checked').val();
}

function setRadio(name, value) {
    const el = $('input[name=' + name + '][value=' + value + ']');
    if (el.length) { el.prop('checked', true); }
    refreshOptionCards();
}

function buildRecipe() {
    const index = { enabled: $('#sf_index_enabled').is(':checked'), method: radio('sf_index_method'), selection_pct: Number($('#sf_selection_pct').val()), traits: {} };
    state.traits.forEach(t => {
        const c = state.indexCfg[t] || { weight: 0, direction: 'increase' };
        if (Number(c.weight) !== 0) index.traits[t] = { weight: Number(c.weight), direction: c.direction };
    });
    const overrides = {};
    Object.keys(state.designOverrides).forEach(k => { if (state.designOverrides[k] && state.designOverrides[k] !== 'auto') overrides[k] = state.designOverrides[k]; });
    const targets = [];
    if (state.zoneTargets.index) targets.push('index');
    state.traits.forEach(t => { if (state.zoneTargets[t]) targets.push(t); });

    return {
        script_factory_version: VERSION,
        name: state.script.name || '',
        traits: state.traits.slice(),
        outliers: {
            method: radio('sf_outlier_method'),
            group_by: $('#sf_iqr_group').val(),
            k: Number($('#sf_iqr_k').val()),
            alpha: Number($('#sf_madr_alpha').val())
        },
        strategy: radio('sf_strategy'),
        engine: radio('sf_engine') || 'lme4',
        genetic: { model: $('#sf_gen_model').val() || 'iid', check: $('#sf_check').val() || 'auto' },
        stage1: { model: radio('sf_stage1_model'), design_overrides: overrides },
        stage2: { genotype: $('#sf_stage2_genotype').val(), weighting: $('#sf_stage2_weighting').val() },
        single: singleRecipe(),
        treatments: treatmentRecipe(),
        index: index,
        zones: {
            enabled: $('#sf_zones_enabled').is(':checked'),
            unit: $('#sf_zones_unit').val(),
            method: radio('sf_zones_method'),
            threshold: Number($('#sf_zones_threshold').val()),
            alpha: Number($('#sf_zones_alpha').val()),
            top_n: Number($('#sf_zones_top').val()),
            targets: targets
        }
    };
}

// match a recipe trait to a dataset trait: full name first, then short name
function matchTrait(t) {
    if (!state.dataset) return null;
    const names = state.dataset.traits.map(x => x.name);
    if (names.indexOf(t) >= 0) return t;
    const s = shortTrait(t);
    const m = names.filter(n => shortTrait(n) === s);
    return m.length ? m[0] : null;
}

function applyRecipe(r) {
    if (!r) return;
    const o = r.outliers || {};
    setRadio('sf_outlier_method', o.method || 'none');
    if (o.group_by) $('#sf_iqr_group').val(o.group_by);
    if (o.k) $('#sf_iqr_k').val(o.k);
    if (o.alpha) $('#sf_madr_alpha').val(o.alpha);

    setRadio('sf_strategy', r.strategy || 'two_stage');
    setRadio('sf_engine', r.engine === 'blupf90' && cfg.blupf90_available ? 'blupf90' : 'lme4');
    const g = r.genetic || {};
    $('#sf_gen_model').val(g.model || 'iid');
    $('#sf_check').val(g.check || 'auto');
    const s1 = r.stage1 || {};
    setRadio('sf_stage1_model', s1.model || 'auto');
    state.designOverrides = Object.assign({}, s1.design_overrides || {});
    const s2 = r.stage2 || {};
    if (s2.genotype) $('#sf_stage2_genotype').val(s2.genotype);
    if (s2.weighting) $('#sf_stage2_weighting').val(s2.weighting);
    applySingle(r.single || {});
    const tr = r.treatments;
    state.trt = tr ? { use: toSet(tr.use), gxt: toSet(tr.gxt) } : null;
    renderTreatments();

    const ix = r.index || {};
    $('#sf_index_enabled').prop('checked', !!ix.enabled);
    setRadio('sf_index_method', ix.method || 'zscore');
    if (ix.selection_pct) { $('#sf_selection_pct').val(ix.selection_pct); $('#sf_selection_pct_label').text(ix.selection_pct); }

    const z = r.zones || {};
    $('#sf_zones_enabled').prop('checked', !!z.enabled);
    if (z.unit) $('#sf_zones_unit').val(z.unit);
    setRadio('sf_zones_method', z.method || 'correlation');
    if (z.threshold !== undefined) $('#sf_zones_threshold').val(z.threshold);
    if (z.alpha) $('#sf_zones_alpha').val(z.alpha);
    if (z.top_n) $('#sf_zones_top').val(z.top_n);

    if (state.dataset) {
        applyRecipeTraits(r);
    } else {
        state.pendingRecipe = r;
    }
    refreshAll();
}

function applyRecipeTraits(r) {
    const missing = [];
    const traits = [];
    arr(r.traits).forEach(t => {
        const m = matchTrait(t);
        if (m) traits.push(m); else missing.push(shortTrait(t));
    });
    if (arr(r.traits).length) state.traits = traits;

    state.indexCfg = {};
    const it = (r.index || {}).traits || {};
    Object.keys(it).forEach(t => {
        const m = matchTrait(t);
        if (m) state.indexCfg[m] = { weight: Number(it[t].weight), direction: it[t].direction || 'increase' };
    });

    state.zoneTargets = {};
    arr((r.zones || {}).targets).forEach(t => {
        if (t === 'index') state.zoneTargets.index = true;
        else { const m = matchTrait(t); if (m) state.zoneTargets[m] = true; }
    });

    state.missingTraits = missing;
    $('#sf_recipe_trait_warning').html(missing.length
        ? alertBox('warning', '<span class="glyphicon glyphicon-warning-sign"></span> The script uses trait(s) that are not in this dataset: <b>' + missing.map(esc).join(', ') + '</b>. They will be skipped.')
        : '');
    renderTraits();
    renderQuickRun();
}

// "Run whole script": shown when a saved script and a dataset are both loaded
function renderQuickRun() {
    const box = $('#sf_quick_run');
    if (!state.scriptLoaded || !state.dataset) { box.hide(); return; }
    const r = buildRecipe();
    const chip = (label, text, on) => '<span class="' + (on ? '' : 'off') + '"><b>' + label + '</b>' + text + '</span>';
    const o = r.outliers;
    $('#sf_quick_run_title').text(state.script.name || 'Loaded script');
    $('#sf_quick_run_text').html('Apply every step of this script to <b>' + esc(state.dataset.dataset_name) + '</b> (' +
        state.dataset.trials.length + ' trial(s), ' + r.traits.length + ' trait(s)) in one click, or review the steps first.');
    $('#sf_quick_run_steps').html(
        chip('Traits', r.traits.map(t => esc(shortTrait(t))).join(', ') || 'none', r.traits.length > 0) +
        chip('QC', o.method === 'iqr' ? 'IQR k = ' + o.k : o.method === 'madr' ? 'BH-MADR' : 'none', o.method !== 'none') +
        chip('Model', r.strategy === 'two_stage' ? 'two stages' : 'single stage', true) +
        (datasetTreatments().length ? chip('Treatments', [].concat(r.treatments.use, r.treatments.gxt.map(n => 'G&times;' + esc(n))).map(x => x.indexOf('G&times;') === 0 ? x : esc(x)).join(', ') || 'not used', r.treatments.use.length + r.treatments.gxt.length > 0) : '') +
        chip('Index', r.index.enabled ? (r.index.method === 'rank_sum' ? 'rank sum' : 'Z-score') + ', top ' + r.index.selection_pct + '%' : 'off', r.index.enabled) +
        chip('Zones', r.zones.enabled ? (r.zones.method === 'lin' ? 'Lin test' : 'correlation') : 'off', r.zones.enabled));
    const problems = validateRecipe(r);
    let warn = '';
    if (state.missingTraits.length) warn += 'Not in this dataset, skipped: <b>' + state.missingTraits.map(esc).join(', ') + '</b>. ';
    if (problems.length) warn += problems.map(esc).join(' ');
    $('#sf_quick_run_warning').html(warn ? alertBox(problems.length ? 'danger' : 'warning', warn) : '');
    const s = runState();
    $('#sf_quick_run_btn')
        .toggleClass('btn-success', s !== 'done').toggleClass('btn-primary', s === 'done')
        .html(s === 'done' ? '<span class="glyphicon glyphicon-ok-circle"></span> Completed: view results'
            : s === 'running' ? '<span class="glyphicon glyphicon-refresh sf-spin"></span> Running...'
            : '<span class="glyphicon glyphicon-play"></span> Run whole script')
        .prop('disabled', s === 'running' || (s !== 'done' && problems.length > 0));
    box.show();
}

// force: run even if the results already match the settings (explicit "Load & run")
function quickRun(force) {
    if (!force && runState() === 'done') { goTo(6); return; }
    goTo(6);
    if (state.step === 6 && !validateRecipe(buildRecipe()).length && !state.job) runAnalysis();
}

// ---------------------------------------------------------------------------
// navigation and generic UI
// ---------------------------------------------------------------------------

function goTo(step) {
    step = Number(step);
    if (step > 1 && !state.dataset) {
        $('#sf_dataset_message').html(alertBox('info', 'Please load a dataset first.'));
        step = 1;
    }
    if (step > 1 && !state.traits.length) {
        $('#sf_dataset_message').html(alertBox('warning', 'Please select at least one trait.'));
        step = 1;
    }
    state.step = step;
    $('.sf-step').hide();
    $('.sf-step[data-step=' + step + ']').show();
    $('#sf_stepper li').each(function() {
        const s = Number($(this).data('step'));
        $(this).toggleClass('active', s === step).toggleClass('done', s < step);
    });
    if (step === 2) renderExplorer();
    if (step === 3) { renderDesignTable(); renderModelPreview(); }
    if (step === 4) renderIndexTable();
    if (step === 5) renderZoneTargets();
    if (step === 6) renderRunReview();
    window.scrollTo({ top: $('#sf_stepper').offset().top - 70, behavior: 'smooth' });
}

function refreshOptionCards() {
    $('.sf-option').each(function() {
        $(this).toggleClass('on', $(this).find('input').is(':checked'));
    });
}

function refreshToggles() {
    const om = radio('sf_outlier_method');
    $('#sf_iqr_opts').toggle(om === 'iqr');
    $('#sf_madr_opts').toggle(om === 'madr');
    $('#sf_preview_madr').toggle(om === 'madr');

    const two = radio('sf_strategy') === 'two_stage';
    $('#sf_stage1_card, #sf_stage2_card').toggle(two);
    $('#sf_single_card').toggle(!two);
    const custom = radio('sf_single_mode') === 'custom';
    $('#sf_single_builder').toggle(!custom);
    $('#sf_single_custom').toggle(custom);
    $('input[name=sf_single_mode]').each(function() { $(this).closest('label').toggleClass('active', $(this).is(':checked')); });

    $('#sf_index_body').toggleClass('sf-disabled', !$('#sf_index_enabled').is(':checked'));
    $('#sf_zones_body').toggleClass('sf-disabled', !$('#sf_zones_enabled').is(':checked'));
    const lin = radio('sf_zones_method') === 'lin';
    $('#sf_zones_threshold_wrap').toggle(!lin);
    $('#sf_zones_alpha_wrap').toggle(lin);
    $('#sf_stepper li[data-step=4]').toggleClass('off', !$('#sf_index_enabled').is(':checked'));
    $('#sf_stepper li[data-step=5]').toggleClass('off', !$('#sf_zones_enabled').is(':checked'));
}

function refreshAll() {
    refreshOptionCards();
    refreshToggles();
    renderPipeline();
    if (state.step === 2) renderExplorer();
    if (state.step === 3) { renderDesignTable(); renderModelPreview(); }
    if (state.step === 4) renderIndexTable();
    if (state.step === 5) renderZoneTargets();
    if (state.step === 6) renderRunReview();
}

function setScriptName() {
    const s = state.script;
    $('#sf_script_name').text(s.name ? s.name + (s.is_owner ? '' : ' (shared, read only)') : 'New script (unsaved)');
}

// ---------------------------------------------------------------------------
// step 1 - dataset
// ---------------------------------------------------------------------------

function selectedDatasetId() {
    const checked = $('input[name=sf_dataset_checkbox]:checked');
    return checked.length ? checked.first().val() : null;
}

function loadDataset() {
    const id = selectedDatasetId();
    if (!id) {
        $('#sf_dataset_message').html(alertBox('warning', 'Please tick one dataset in the table above.'));
        return;
    }
    if ($('input[name=sf_dataset_checkbox]:checked').length > 1) {
        $('#sf_dataset_message').html(alertBox('warning', 'Please select only one dataset.'));
        return;
    }
    $('#sf_dataset_message').html('<div class="sf-help" style="margin-top:12px"><span class="glyphicon glyphicon-refresh sf-spin"></span> Retrieving phenotypes. Large datasets can take a minute...</div>');
    $('#sf_load_dataset').prop('disabled', true);
    // the dataset loads as soon as it is ticked: only the latest choice counts
    const seq = state.loadSeq = (state.loadSeq || 0) + 1;

    post('/ajax/script_factory/prepare', { dataset_id: id })
        .then(r => {
            if (seq !== state.loadSeq) return;
            const keepTraits = state.dataset ? state.traits.map(shortTrait) : null;
            state.dataset = r;
            state.plotData = null;
            state.plotDataKey = '';
            state.exclusions = {};
            state.madrFlags = {};
            state.madrPreviewDone = false;
            state.outlierSel = {};
            state.outlierStatus = {};
            excludeMarked(true);
            state.results = null;
            state.lastRun = null;
            state.runFailed = false;
            $('#sf_results').hide();
            if (state.pendingRecipe) {
                applyRecipeTraits(state.pendingRecipe);
                state.pendingRecipe = null;
            } else if (keepTraits && keepTraits.length) {
                state.traits = r.traits.map(t => t.name).filter(n => keepTraits.indexOf(shortTrait(n)) >= 0);
                $('#sf_recipe_trait_warning').html('');
            } else {
                state.traits = r.traits.map(t => t.name);
                $('#sf_recipe_trait_warning').html('');
            }
            state.traits.forEach(t => { if (!state.indexCfg[t]) state.indexCfg[t] = { weight: 0, direction: 'increase' }; });
            const nMarked = arr(r.marked_outliers).length;
            $('#sf_dataset_message').html(r.traits.length ? (nMarked ? alertBox('info', '<span class="glyphicon glyphicon-flag"></span> <b>' + nMarked + '</b> value(s) of this dataset are marked as outliers in Breedbase. ' +
                'They are excluded in step 2 (only those values, not the whole plots); you can bring them back there.') : '') : alertBox('warning', 'No numeric trait was found in this dataset.'));
            renderDatasetOverview();
            renderExclusions();
            renderPipeline();
            renderQuickRun();
        })
        .catch(e => { if (seq === state.loadSeq) $('#sf_dataset_message').html(alertBox('danger', esc(e.message))); })
        .finally(() => $('#sf_load_dataset').prop('disabled', false));
}

// factor support of a trial (rep, block, row, col), computed by the server with
// the same rules the R pipeline applies: {ok, why}
function sup(t, f) {
    const s = t.support && t.support[f];
    if (s) return s;
    const ok = f === 'rep' ? t.n_reps > 1 : f === 'block' ? t.n_blocks > 1 : t.has_rowcol;
    return { ok: !!ok, why: ok ? '' : 'not recorded' };
}
const FACTOR_NAMES = { rep: 'replicate', block: 'block', row: 'row', col: 'column' };
// factors a trial records but cannot support (a single replicate or block is not news)
function factorsOff(t) {
    return Object.keys(FACTOR_NAMES).filter(f => !sup(t, f).ok && !/^(one replicate|one block|no row|no column|not recorded|the blocks are the replicates)/.test(sup(t, f).why))
        .map(f => FACTOR_NAMES[f] + ' (' + sup(t, f).why + ')');
}

function detectDesign(t) {
    const txt = String(t.design || '').toLowerCase();
    const repOk = sup(t, 'rep').ok;
    const blockOk = sup(t, 'block').ok;
    const entriesRep = t.support ? !!t.support.entries_replicated : t.replicated;
    let d;
    if (/row.?col|rowcol|spatial|p-rep|prep/.test(txt)) d = 'row_column';
    else if (/augmented|madii|aug/.test(txt) || (!entriesRep && t.replicated && blockOk)) d = 'augmented';
    else if (/alpha|lattice|incomplete/.test(txt) || (repOk && blockOk && t.n_blocks > t.n_reps)) d = 'alpha_lattice';
    else if (/rcbd|randomi[sz]ed complete block/.test(txt) || repOk) d = 'rcbd';
    else if (/crd|completely random/.test(txt) || t.replicated) d = 'crd';
    else d = 'unreplicated';
    if (!t.replicated && d !== 'augmented') d = 'unreplicated';
    return d;
}

// count of a design factor, crossed out when the data cannot support it
function factorCell(t, f, n) {
    const s = sup(t, f);
    const shown = !s.ok && n > 1 && !/^(one |the blocks are the replicates)/.test(s.why);
    return '<td>' + (shown ? '<span class="sf-warn-text" title="Not used as a model factor: ' + esc(s.why) + '"><s>' + n + '</s> <span class="glyphicon glyphicon-ban-circle"></span></span>' : n) + '</td>';
}

function renderDatasetOverview() {
    const r = state.dataset;
    const stat = (v, l) => '<div class="sf-stat"><div class="v">' + esc(v) + '</div><div class="l">' + esc(l) + '</div></div>';
    $('#sf_dataset_stats').html(
        stat(r.trials.length, 'Trials') + stat(r.n_locations, 'Locations') + stat(r.n_years, 'Years') +
        stat(r.n_accessions, 'Accessions') + stat(r.n_plots, 'Plots') + stat(r.traits.length, 'Numeric traits'));

    let h = '<table class="table table-condensed table-hover"><thead><tr><th>Trial</th><th>Location</th><th>Year</th><th>Design</th><th>Plots</th><th>Accessions</th><th>Reps</th><th>Blocks</th><th>Layout</th></tr></thead><tbody>';
    r.trials.forEach(t => {
        const d = detectDesign(t);
        h += '<tr><td>' + (t.trial_id ? '<a href="/breeders/trial/' + esc(t.trial_id) + '" target="_blank">' + esc(t.trial) + '</a>' : esc(t.trial)) + '</td>' +
            '<td>' + esc(t.location) + '</td><td>' + esc(t.year) + '</td>' +
            '<td><span class="label label-default">' + esc(DESIGNS[d]) + '</span>' + (t.design ? ' <small class="sf-muted">(' + esc(t.design) + ')</small>' : '') + '</td>' +
            '<td>' + t.n_plots + '</td><td>' + t.n_accessions + '</td>' + factorCell(t, 'rep', t.n_reps) + factorCell(t, 'block', t.n_blocks) +
            '<td>' + (t.has_rowcol ? '<span class="glyphicon glyphicon-th" title="Row and column coordinates available"></span> ' + t.n_rows + '&times;' + t.n_cols : '<span class="sf-muted">no row/col</span>') + '</td></tr>';
    });
    h += '</tbody></table>';
    $('#sf_trials_table').html(h);
    renderTraits();
    renderTreatments();
    // covariates of a script loaded before the dataset: match them by name
    const cov = {};
    Object.keys(state.singleCov).forEach(t => { const m = matchTrait(t); if (m) cov[m] = true; });
    state.singleCov = cov;
    renderSingleCovariates();
    $('#sf_dataset_overview').show();
}

// ---------------------------------------------------------------------------
// treatments (management factors, treatment variables): not traits, but
// factors the models can adjust for
// ---------------------------------------------------------------------------
function toSet(a) { const o = {}; arr(a).forEach(x => { o[x] = true; }); return o; }

function datasetTreatments() { return (state.dataset && state.dataset.treatments) || []; }

// genotype x treatment needs a treatment applied to whole trials, with fewer
// levels than trials (else it is genotype x trial)
function gxtPossible(f) { return f.n_trial_levels > 1 && f.n_trial_levels < ((state.dataset && state.dataset.trials.length) || 0); }

// choices of the user or of a script; without them the defaults of the
// dataset: adjust for treatments that vary inside trials (whole-trial
// treatments are held by the trial effect)
function trtState() {
    if (state.trt) return state.trt;
    const d = { use: {}, gxt: {} };
    datasetTreatments().forEach(f => { if (f.varies_within_trials) d.use[f.name] = true; });
    return d;
}

function treatmentRecipe() {
    const t = trtState();
    const names = datasetTreatments().map(f => f.name);
    const keep = o => Object.keys(o).filter(n => o[n] && (!state.dataset || names.indexOf(n) >= 0));
    return { use: keep(t.use), gxt: keep(t.gxt), types: (state.dataset && state.dataset.treatment_types) || [] };
}

function renderTreatments() {
    const list = datasetTreatments();
    $('#sf_treatments_card').toggle(list.length > 0);
    if (!list.length) { $('#sf_treatments').html(''); return; }
    const t = trtState();
    const nT = state.dataset.trials.length;
    $('#sf_treatments').html(list.map(f => {
        const lv = f.levels.map(l => '<span class="sf-trt-level' + (l.level === 'none' ? ' none' : '') + '">' + esc(l.level) + ' <small>' + l.n_plots + '</small></span>').join(' ');
        const where = f.varies_within_trials ? '<span class="label label-info">varies within trials</span>'
            : '<span class="label label-default">whole trials</span> <small class="sf-muted">' + f.n_trials_with_levels + ' of ' + nT + ' trial(s) treated</small>';
        const useHelp = f.varies_within_trials ? 'Stage 1 / the single-stage model compare genotypes at the same treatment level.'
            : 'Applied to whole trials: with the trial as fixed effect this is already held by the trial effect (used when the trial is random or not modelled).';
        const gx = gxtPossible(f);
        return '<div class="sf-trt" data-name="' + esc(f.name) + '">' +
            '<div class="sf-trt-head"><b>' + esc(f.name) + '</b> <small class="sf-muted">' + esc(f.source) + ' &middot; <code>' + esc(f.variable) + '</code></small> ' + where + '</div>' +
            '<div class="sf-trt-levels">' + lv + '</div>' +
            '<label class="sf-check"><input type="checkbox" class="sf-trt-use"' + (t.use[f.name] ? ' checked' : '') + ' /> Adjust for ' + esc(f.name) + ' (fixed effect) <small class="sf-muted">' + esc(useHelp) + '</small></label>' +
            '<label class="sf-check' + (gx ? '' : ' dis') + '"><input type="checkbox" class="sf-trt-gxt"' + (t.gxt[f.name] && gx ? ' checked' : '') + (gx ? '' : ' disabled') + ' /> Genotype &times; ' + esc(f.name) +
            ' <small class="sf-muted">' + (gx ? 'random interaction: do the genotypes rank differently under each ' + esc(f.name) + ' level?' : 'needs ' + esc(f.name) + ' applied to whole trials, with more trials than levels') + '</small></label>' +
            '</div>';
    }).join(''));
}

function onTreatmentsChanged() {
    const t = state.trt = Object.assign({ use: {}, gxt: {} }, state.trt);
    $('#sf_treatments .sf-trt').each(function() {
        const name = $(this).data('name');
        t.use[name] = $(this).find('.sf-trt-use').is(':checked');
        t.gxt[name] = $(this).find('.sf-trt-gxt').is(':checked');
    });
    renderPipeline();
    renderModelPreview();
    renderSingleHints();
    renderQuickRun();
}

function treatmentVars() { return datasetTreatments().map(f => f.variable); }

function renderTraits() {
    if (!state.dataset) return;
    let h = '';
    state.dataset.traits.forEach(t => {
        const on = state.traits.indexOf(t.name) >= 0;
        h += '<label class="sf-trait' + (on ? ' on' : '') + '" title="' + esc(t.name) + '"><input type="checkbox" class="sf-trait-cb" value="' + esc(t.name) + '"' + (on ? ' checked' : '') + ' />' +
            '<span><b>' + esc(t.short) + '</b><small>n = ' + t.n + ' &middot; mean ' + fmt(t.mean) + ' &middot; ' + fmt(t.min) + ' to ' + fmt(t.max) + '</small></span></label>';
    });
    $('#sf_traits').html(h || '<p class="sf-muted">No numeric traits.</p>');
}

function onTraitsChanged() {
    const sel = [];
    $('.sf-trait-cb:checked').each(function() { sel.push($(this).val()); });
    // keep dataset order
    state.traits = state.dataset.traits.map(t => t.name).filter(n => sel.indexOf(n) >= 0);
    state.traits.forEach(t => { if (!state.indexCfg[t]) state.indexCfg[t] = { weight: 0, direction: 'increase' }; });
    $('.sf-trait').each(function() { $(this).toggleClass('on', $(this).find('input').is(':checked')); });
    renderPipeline();
    renderQuickRun();
}

// ---------------------------------------------------------------------------
// step 2 - outliers
// ---------------------------------------------------------------------------

function ensurePlotData() {
    const key = state.dataset.token + '|' + state.traits.join('\t');
    if (state.plotData && state.plotDataKey === key) return Promise.resolve(state.plotData);
    return post('/ajax/script_factory/plot_data', { token: state.dataset.token, traits: JSON.stringify(state.traits) })
        .then(r => { state.plotData = r; state.plotDataKey = key; return r; });
}

// client-side mirror of the IQR rule in the R pipeline
function iqrFlags(trait) {
    const pd = state.plotData;
    const ti = pd.columns.indexOf(trait);
    if (ti < 0) return {};
    const k = Number($('#sf_iqr_k').val()) || 1.5;
    const by = $('#sf_iqr_group').val();

    // effective replicate per trial: rep if it has >1 levels, else block
    const repLevels = {}, blockLevels = {};
    pd.rows.forEach(r => {
        (repLevels[r[1]] = repLevels[r[1]] || {})[r[3]] = 1;
        (blockLevels[r[1]] = blockLevels[r[1]] || {})[r[4]] = 1;
    });
    const effRep = r => Object.keys(repLevels[r[1]]).filter(x => x && x !== 'null').length > 1 ? r[3]
        : Object.keys(blockLevels[r[1]]).filter(x => x && x !== 'null').length > 1 ? r[4] : '1';

    const groups = {};
    pd.rows.forEach(r => {
        const v = r[ti];
        if (v === null || v === undefined) return;
        let g;
        if (by === 'trial_rep') g = r[1] + ' ' + effRep(r);
        else if (by === 'trial_accession') g = r[1] + ' ' + r[2];
        else if (by === 'all') g = 'all';
        else g = r[1];
        (groups[g] = groups[g] || []).push(r);
    });
    const flags = {};
    Object.keys(groups).forEach(g => {
        const rows = groups[g];
        if (rows.length < 4) return;
        const s = rows.map(r => r[ti]).sort((a, b) => a - b);
        const q1 = quantile(s, 0.25), q3 = quantile(s, 0.75), iqr = q3 - q1;
        rows.forEach(r => { if (r[ti] < q1 - k * iqr || r[ti] > q3 + k * iqr) flags[r[0]] = true; });
    });
    return flags;
}

function ruleFlags(trait) {
    const m = radio('sf_outlier_method');
    if (m === 'iqr') return iqrFlags(trait);
    if (m === 'madr') {
        const out = {};
        const s = shortTrait(trait);
        Object.keys(state.madrFlags).forEach(k => {
            const i = k.lastIndexOf('|');
            if (k.slice(i + 1) === s) out[k.slice(0, i)] = true;
        });
        return out;
    }
    return {};
}

function renderExplorer() {
    if (!state.dataset) return;
    const sel = $('#sf_explorer_trait');
    const cur = sel.val();
    sel.html(state.traits.map(t => '<option value="' + esc(t) + '">' + esc(shortTrait(t)) + '</option>').join(''));
    if (cur && state.traits.indexOf(cur) >= 0) sel.val(cur);
    $('#sf_explorer_plot').html('<div class="sf-help"><span class="glyphicon glyphicon-refresh sf-spin"></span> Loading observations...</div>');
    ensurePlotData()
        .then(() => drawExplorer())
        .catch(e => $('#sf_explorer_plot').html(alertBox('danger', esc(e.message))));
}

function drawExplorer() {
    const trait = $('#sf_explorer_trait').val();
    const pd = state.plotData;
    const box = document.getElementById('sf_explorer_plot');
    box.innerHTML = '';
    if (!trait || !pd) return;
    const ti = pd.columns.indexOf(trait);
    const flags = ruleFlags(trait);

    const byTrial = {};
    const all = [];
    pd.rows.forEach(r => {
        if (r[ti] === null || r[ti] === undefined) return;
        (byTrial[r[1]] = byTrial[r[1]] || []).push(r);
        all.push(r[ti]);
    });
    const trials = Object.keys(byTrial).sort();
    if (!trials.length) { box.innerHTML = '<p class="sf-muted">No observations for this trait.</p>'; return; }

    const minV = Math.min.apply(null, all), maxV = Math.max.apply(null, all);
    const pad = (maxV - minV) * 0.05 || 1;
    const y0 = minV - pad, y1 = maxV + pad;
    // layout from the space available and the label lengths, so that nothing
    // is cut: rotated trial names need room below and, for the first trial,
    // to the left; the boxes fill the card width (scroll only when crowded)
    const CH = 6.3;                                    // ~width of one 11px character
    const fmtLabel = tr => tr.length > 32 ? tr.slice(0, 31) + '…' : tr;
    const ticks = niceTicks(y0, y1, 6);
    const tickW = Math.max.apply(null, ticks.map(v => String(v).length)) * CH;
    const avail = Math.max(320, (box.clientWidth || 820) - 4);
    let bw = Math.max(22, Math.min(110, (avail - Math.max(60, tickW + 34) - 16) / trials.length));
    const ang = bw < 34 ? 70 : 40, rad = ang * Math.PI / 180;
    const labLen = trials.map(tr => fmtLabel(tr).length * CH);
    const M = { l: Math.max(60, tickW + 34, labLen[0] * Math.cos(rad) - bw / 2 + 8), r: 16, t: 14,
        b: 24 + Math.max.apply(null, labLen) * Math.sin(rad) };
    bw = Math.max(22, Math.min(110, (avail - M.l - M.r) / trials.length));
    const W = M.l + M.r + bw * trials.length;
    const H = M.t + 330 + M.b;
    const ys = v => M.t + (H - M.t - M.b) * (1 - (v - y0) / (y1 - y0));

    const svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, 'font-family': 'sans-serif', 'font-size': 11 }, box);
    ticks.forEach(v => {
        svgEl('line', { x1: M.l, x2: W - M.r, y1: ys(v), y2: ys(v), stroke: '#eef1f4' }, svg);
        const tx = svgEl('text', { x: M.l - 6, y: ys(v) + 4, 'text-anchor': 'end', fill: '#6b7280' }, svg);
        tx.textContent = v;
    });
    const yl = svgEl('text', { x: 14, y: (H - M.b + M.t) / 2, transform: 'rotate(-90 14 ' + ((H - M.b + M.t) / 2) + ')', 'text-anchor': 'middle', fill: '#374151', 'font-weight': 600 }, svg);
    yl.textContent = shortTrait(trait);

    let nFlag = 0, nExcl = 0, nMark = 0;
    trials.forEach((tr, i) => {
        const rows = byTrial[tr];
        const cx = M.l + bw * i + bw / 2;
        const kept = rows.filter(r => !flags[r[0]] && !state.exclusions[r[0] + '|' + trait]).map(r => r[ti]).sort((a, b) => a - b);
        if (kept.length) {
            const q1 = quantile(kept, 0.25), q2 = quantile(kept, 0.5), q3 = quantile(kept, 0.75);
            const w = bw * 0.55;
            svgEl('line', { x1: cx, x2: cx, y1: ys(kept[0]), y2: ys(kept[kept.length - 1]), stroke: '#94a3b8' }, svg);
            svgEl('rect', { x: cx - w / 2, y: ys(q3), width: w, height: Math.max(1, ys(q1) - ys(q3)), fill: '#e8f4ec', stroke: '#2b7a4b', rx: 3 }, svg);
            svgEl('line', { x1: cx - w / 2, x2: cx + w / 2, y1: ys(q2), y2: ys(q2), stroke: '#1f5f3a', 'stroke-width': 2 }, svg);
        }
        rows.forEach(r => {
            const key = r[0] + '|' + trait;
            const excl = !!state.exclusions[key];
            const mark = excl && !!state.exclusions[key].marked;
            const flag = !!flags[r[0]];
            if (excl && !mark) nExcl++;
            if (mark) nMark++;
            if (flag) nFlag++;
            const c = svgEl('circle', {
                cx: cx + (hash(r[0]) - 0.5) * bw * 0.6, cy: ys(r[ti]), r: (excl || flag) ? 4 : 2.6,
                fill: excl ? '#111' : flag ? '#e11d48' : '#2b7a4b', 'fill-opacity': (excl || flag) ? 0.95 : 0.45,
                stroke: excl ? '#fff' : 'none'
            }, svg);
            c.setAttribute('data-unit', r[0]);
            const title = svgEl('title', {}, c);
            title.textContent = r[0] + '\n' + r[2] + '\nvalue: ' + r[ti] + (r[3] ? '\nrep ' + r[3] : '') + (r[5] !== null && r[5] !== undefined ? '\nrow ' + r[5] + ', col ' + r[6] : '') + (flag ? '\nflagged by the rule' : '') + (mark ? '\nmarked as outlier in Breedbase: excluded (click to use it)' : excl ? '\nexcluded by you (click to restore)' : '\nclick to exclude');
            c.addEventListener('click', () => toggleExclusion(r, trait));
        });
        const lab = svgEl('text', { x: cx, y: H - M.b + 12, 'text-anchor': 'end', transform: 'rotate(-' + ang + ' ' + cx + ' ' + (H - M.b + 12) + ')', fill: '#374151' }, svg);
        lab.textContent = fmtLabel(tr);
        svgEl('title', {}, lab).textContent = tr;
    });

    const method = radio('sf_outlier_method');
    let msg = '<b>' + all.length + '</b> observations';
    if (method === 'iqr') msg += ', <b style="color:#e11d48">' + nFlag + '</b> flagged by the IQR rule';
    if (method === 'madr') msg += Object.keys(state.madrFlags).length || state.madrPreviewDone
        ? ', <b style="color:#e11d48">' + nFlag + '</b> flagged by BH-MADR'
        : ' &middot; BH-MADR needs a model fit: click <i>Flag with BH-MADR</i> to preview the flagged points (it is applied anyway when you run the analysis).';
    msg += ', <b>' + nExcl + '</b> excluded by you' + (nMark ? ', <b>' + nMark + '</b> excluded as marked in Breedbase' : '') + '.';
    $('#sf_explorer_summary').html('<p class="sf-help">' + msg + '</p>');
    renderExclusions();   // the full outlier list follows the rule and the exclusions
}

// values marked as outliers in Breedbase (dataset or database): exclude them
// (on = true) or use them again (on = false). Their status badges come along.
function excludeMarked(on) {
    arr(state.dataset && state.dataset.marked_outliers).forEach(m => {
        const key = m.unit + '|' + m.trait;
        state.outlierStatus[key] = { dataset: m.dataset ? 1 : 0, database: m.database ? 1 : 0 };
        if (!on) { if (state.exclusions[key] && state.exclusions[key].marked) delete state.exclusions[key]; return; }
        if (!state.exclusions[key]) {
            state.exclusions[key] = { unit: m.unit, trait: m.trait, trial: m.trial, accession: m.accession, value: Number(m.value),
                marked: m.dataset && m.database ? 'both' : m.dataset ? 'dataset' : 'database' };
        }
    });
}

function toggleExclusion(r, trait) {
    const key = r[0] + '|' + trait;
    if (state.exclusions[key]) delete state.exclusions[key];
    else state.exclusions[key] = { unit: r[0], trait: trait, trial: r[1], accession: r[2], value: r[state.plotData.columns.indexOf(trait)] };
    drawExplorer();
    renderPipeline();
}

// every outlier of every selected trait: flagged by the rule and/or excluded individually
function collectOutliers() {
    const pd = state.plotData;
    if (!pd) return [];
    const method = radio('sf_outlier_method');
    const ruleLabel = method === 'iqr' ? 'IQR rule' : method === 'madr' ? 'BH-MADR' : '';
    const out = [];
    state.traits.forEach(trait => {
        const ti = pd.columns.indexOf(trait);
        if (ti < 0) return;
        const flags = ruleFlags(trait);
        pd.rows.forEach(r => {
            if (r[ti] === null || r[ti] === undefined) return;
            const key = r[0] + '|' + trait;
            const rule = !!flags[r[0]];
            const ind = !!state.exclusions[key];
            const marked = ind && !!state.exclusions[key].marked;
            if (rule || ind) out.push({ key: key, unit: r[0], trial: r[1], accession: r[2], trait: trait, value: r[ti], rule: rule, ind: ind && !marked, marked: marked, ruleLabel: ruleLabel });
        });
    });
    return out;
}

function statusBadges(key) {
    const s = state.outlierStatus[key];
    if (!s) return '<span class="sf-muted">&hellip;</span>';
    return (s.dataset ? '<span class="label sf-badge-ds">dataset</span> ' : '') + (s.database ? '<span class="label sf-badge-db">database</span>' : '') +
        (!s.dataset && !s.database ? '<span class="sf-muted">&ndash;</span>' : '');
}

function renderExclusions() {
    $('#sf_exclusion_count').text(Object.keys(state.exclusions).length);
    const all = collectOutliers();
    state.outlierRows = all;

    // trait filter
    const filter = $('#sf_outlier_filter');
    const cur = filter.val() || '';
    const counts = {};
    all.forEach(o => { counts[o.trait] = (counts[o.trait] || 0) + 1; });
    filter.html('<option value="">All traits (' + all.length + ')</option>' + state.traits.map(t => '<option value="' + esc(t) + '">' + esc(shortTrait(t)) + ' (' + (counts[t] || 0) + ')</option>').join(''));
    filter.val(state.traits.indexOf(cur) >= 0 ? cur : '');
    const rows = all.filter(o => !filter.val() || o.trait === filter.val());
    state.outlierVisible = rows;

    const nRule = all.filter(o => o.rule).length, nInd = all.filter(o => o.ind).length, nMarked = all.filter(o => o.marked).length;
    const nMarkedAll = arr(state.dataset && state.dataset.marked_outliers).filter(m => state.traits.indexOf(m.trait) >= 0).length;
    $('#sf_outlier_count').text(all.length);
    const method = radio('sf_outlier_method');
    let bd = '<b>' + nRule + '</b> flagged by ' + (method === 'iqr' ? 'the IQR rule' : method === 'madr' ? 'BH-MADR' : 'no rule') +
        ' &middot; <b><span id="sf_exclusion_count">' + nInd + '</span></b> excluded by you' +
        (nMarkedAll ? ' &middot; <b>' + nMarked + '</b> of ' + nMarkedAll + ' marked in Breedbase excluded ' +
            (nMarked ? '<button class="btn btn-link btn-xs sf-marked-toggle" data-on="0">use them</button>' : '') +
            (nMarked < nMarkedAll ? '<button class="btn btn-link btn-xs sf-marked-toggle" data-on="1">exclude ' + (nMarked ? 'all of them' : 'them') + '</button>' : '') : '');
    if (method === 'madr' && !state.madrPreviewDone) bd += ' &middot; <i>click "Flag with BH-MADR" above to list the BH-MADR outliers</i>';
    if (state.dataset && state.dataset.dataset_n_outliers) bd += ' &middot; this dataset already has <b>' + state.dataset.dataset_n_outliers + '</b> dataset outlier(s)';
    $('#sf_outlier_breakdown').html(bd);

    // drop selections that are no longer listed
    const listed = {};
    all.forEach(o => { listed[o.key] = true; });
    Object.keys(state.outlierSel).forEach(k => { if (!listed[k]) delete state.outlierSel[k]; });

    if (!rows.length) {
        $('#sf_outlier_table').html('<p class="sf-muted" style="padding:10px">No outliers' + (all.length ? ' for this trait' : '') + '. Choose a rule above or click points in the plot to exclude them.</p>');
    } else {
        const allSel = rows.every(o => state.outlierSel[o.key]);
        let h = '<table class="table table-condensed table-hover"><thead><tr><th style="width:28px"><input type="checkbox" id="sf_outlier_all"' + (allSel ? ' checked' : '') + ' title="Select all listed" /></th>' +
            '<th>Plot</th><th>Trial</th><th>Accession</th><th>Trait</th><th>Value</th><th>Flagged by</th><th>Marked in Breedbase</th><th></th></tr></thead><tbody>';
        rows.forEach(o => {
            const sel = !!state.outlierSel[o.key];
            h += '<tr class="' + (sel ? 'sel' : '') + '"><td><input type="checkbox" class="sf-outlier-cb" data-key="' + esc(o.key) + '"' + (sel ? ' checked' : '') + ' /></td>' +
                '<td>' + esc(o.unit) + '</td><td>' + esc(o.trial) + '</td><td>' + esc(o.accession) + '</td><td>' + esc(shortTrait(o.trait)) + '</td><td>' + fmt(o.value) + '</td>' +
                '<td>' + (o.rule ? '<span class="sf-src sf-src-rule">' + esc(o.ruleLabel) + '</span>' : '') + (o.ind ? '<span class="sf-src sf-src-ind">you</span>' : '') + (o.marked ? '<span class="sf-src sf-src-mark" title="Marked as outlier in Breedbase: excluded when the dataset was loaded">Breedbase mark</span>' : '') + '</td>' +
                '<td class="sf-outlier-status" data-key="' + esc(o.key) + '">' + statusBadges(o.key) + '</td>' +
                '<td>' + (o.ind || o.marked ? '<button class="btn btn-link btn-xs sf-restore" data-key="' + esc(o.key) + '">restore</button>' : '') + '</td></tr>';
        });
        h += '</tbody></table>';
        $('#sf_outlier_table').html(h);
    }
    updateOutlierToolbar();
    checkOutlierStatus(all);
}

function selectedOutliers() {
    return (state.outlierRows || []).filter(o => state.outlierSel[o.key]);
}

// the values the mark buttons act on: the ticked rows, or every listed
// outlier (current trait filter) when none is ticked
function outlierTargets() {
    const sel = selectedOutliers();
    return sel.length ? sel : (state.outlierVisible || []);
}

function updateOutlierToolbar() {
    const nSel = selectedOutliers().length;
    const n = outlierTargets().length;
    const what = nSel ? nSel + ' selected' : (n === 1 ? 'the listed outlier' : 'all ' + n);
    const owner = !!(state.dataset && state.dataset.dataset_is_owner);
    const canDb = String(cfg.can_mark_database) === '1';
    const canUnmarkDb = String(cfg.can_unmark_database) === '1';
    $('#sf_outlier_selected').text(nSel ? nSel + ' selected' : (n ? 'None ticked: the buttons apply to all ' + n + ' listed' : ''));
    $('#sf_mark_dataset').prop('disabled', !n || !owner)
        .html('<span class="glyphicon glyphicon-flag"></span> Mark ' + (n ? what + ' ' : '') + 'as dataset outliers')
        .attr('title', owner ? 'Add these values to this dataset\'s outliers' : 'Only the owner of the dataset can change its outliers');
    $('#sf_mark_database').prop('disabled', !n || !canDb)
        .html('<span class="glyphicon glyphicon-hdd"></span> Mark ' + (n ? what + ' ' : '') + 'as database outliers')
        .attr('title', canDb ? 'Flag these values as outliers in the database, for all users' : 'Only curators and breeders can mark database outliers');
    $('#sf_unmark_menu').prop('disabled', !n || (!owner && !canUnmarkDb));
    // curators and breeders remove database outlier marks (the server checks it too)
    $('#sf_unmark_database_item').toggleClass('disabled', !canUnmarkDb)
        .attr('title', canUnmarkDb ? '' : 'Only curators and breeders can remove the database outlier mark');
    $('#sf_unmark_database_item').prev().toggleClass('disabled', !owner)
        .attr('title', owner ? '' : 'Only the owner of the dataset can change its outliers');
    const why = [];
    if (n && !owner) why.push('dataset outliers can only be marked by the owner of the dataset');
    if (n && !canDb) why.push('database outliers can only be marked by curators and breeders');
    $('#sf_outlier_permissions').html(why.length ? '<span class="glyphicon glyphicon-lock"></span> ' + esc(why.join('; ')) + '.' : '');
}

// ask the server which listed outliers are already dataset / database outliers
function checkOutlierStatus(rows) {
    if (!state.dataset) return;
    const todo = rows.filter(o => !state.outlierStatus[o.key] && !state.outlierChecking[o.key]);
    if (!todo.length) return;
    todo.forEach(o => { state.outlierChecking[o.key] = true; });
    post('/ajax/script_factory/outliers/mark', { dataset_id: state.dataset.dataset_id, action: 'check', items: JSON.stringify(todo.map(o => ({ unit: o.unit, trait: o.trait }))) })
        .then(r => applyOutlierStatus(todo.map(o => o.key), r))
        .catch(() => {})
        .finally(() => todo.forEach(o => { delete state.outlierChecking[o.key]; }));
}

function applyOutlierStatus(keys, r) {
    keys.forEach(k => { state.outlierStatus[k] = (r.status || {})[k] || { dataset: 0, database: 0, missing: 1 }; });
    if (r.dataset_n_outliers !== undefined && state.dataset) state.dataset.dataset_n_outliers = r.dataset_n_outliers;
    $('.sf-outlier-status').each(function() { $(this).html(statusBadges($(this).data('key'))); });
}

const MARK_TEXT = {
    dataset: ['marked as dataset outliers', 'dataset'],
    database: ['marked as database outliers', 'database'],
    unmark_dataset: ['removed from the dataset outliers', 'dataset'],
    unmark_database: ['removed from the database outliers', 'database']
};

// items: [{key, unit, trait}]; msgBox: where to report
function markOutliers(items, action, msgBox) {
    if (!items.length || !state.dataset) return Promise.resolve();
    if (action === 'database' && !confirm('Mark ' + items.length + ' value(s) as outliers in the database?\n\nThey will be excluded for ALL users, in every dataset, analysis and tool that excludes outliers.\n\nNote: when a dataset excludes database outliers, Breedbase leaves out the WHOLE plot (all its traits), not only the marked value. To drop only the value, use dataset outliers instead.\n\nOnly a curator or a breeder can remove the mark later.')) return Promise.resolve();
    if (action === 'unmark_database' && !confirm('Remove the database outlier mark from ' + items.length + ' value(s)? They will be used again by all tools.')) return Promise.resolve();
    $(msgBox).html('<p class="sf-help"><span class="glyphicon glyphicon-refresh sf-spin"></span> Saving...</p>');
    return post('/ajax/script_factory/outliers/mark', { dataset_id: state.dataset.dataset_id, action: action, items: JSON.stringify(items.map(o => ({ unit: o.unit, trait: o.trait }))) })
        .then(r => {
            const keys = items.map(o => o.key || (o.unit + '|' + o.trait));
            applyOutlierStatus(keys, r);
            const t = MARK_TEXT[action];
            let m = '<span class="glyphicon glyphicon-ok"></span> <b>' + r.changed + '</b> value(s) ' + t[0] + '.';
            if (items.length - r.not_found > r.changed) m += ' ' + (items.length - r.not_found - r.changed) + ' already were.';
            if (r.not_found) m += ' ' + r.not_found + ' could not be matched to a stored phenotype.';
            if (t[1] === 'dataset') m += ' The dataset now has <b>' + r.dataset_n_outliers + '</b> outlier(s).';
            $(msgBox).html(alertBox(r.not_found ? 'warning' : 'success', m));
            if (state.plotData) renderExclusions();
            renderPipeline();
        })
        .catch(e => $(msgBox).html(alertBox('danger', esc(e.message))));
}

function exclusionsPayload() {
    return Object.keys(state.exclusions).map(k => {
        const e = state.exclusions[k];
        return e.marked ? { unit: e.unit, trait: e.trait, source: e.marked } : { unit: e.unit, trait: e.trait };
    });
}

function previewMadr() {
    const btn = $('#sf_preview_madr');
    btn.prop('disabled', true).html('<span class="glyphicon glyphicon-refresh sf-spin"></span> Fitting models...');
    const recipe = buildRecipe();
    recipe.zones.enabled = false;
    recipe.index.enabled = false;
    post('/ajax/script_factory/run', { token: state.dataset.token, recipe: JSON.stringify(recipe), exclusions: '[]', mode: 'preview' })
        .then(job => pollJob(job, null))
        .then(res => {
            state.madrFlags = {};
            state.madrPreviewDone = true;
            arr(res.outliers).forEach(o => { state.madrFlags[o.unit + '|' + o.trait] = true; });
            drawExplorer();
        })
        .catch(e => $('#sf_explorer_summary').html(alertBox('danger', esc(e.message))))
        .finally(() => btn.prop('disabled', false).html('<span class="glyphicon glyphicon-flash"></span> Flag with BH-MADR'));
}

// ---------------------------------------------------------------------------
// step 3 - model
// ---------------------------------------------------------------------------

function trialModel(t) {
    const s1 = radio('sf_stage1_model');
    const override = state.designOverrides[t.trial];
    const design = override && override !== 'auto' ? override : detectDesign(t);
    if (t.has_rowcol && (s1 === 'spats' || s1 === 'auto')) {
        return { design: design, text: 'SpATS: y ~ accession' + (sup(t, 'rep').ok ? ' + rep' : '') + ' + PSANOVA(col, row)' + (sup(t, 'row').ok ? ' + (1|row)' : '') + (sup(t, 'col').ok ? ' + (1|col)' : ''), spats: true, off: factorsOff(t) };
    }
    const r = sup(t, 'rep').ok, b = sup(t, 'block').ok;
    let terms = [];
    if (design === 'rcbd' && r) terms = ['(1|rep)'];
    if (design === 'alpha_lattice') terms = (r ? ['(1|rep)'] : []).concat(b ? ['(1|rep:block)'] : []);
    if (design === 'augmented' && b) terms = ['(1|block)'];
    if (design === 'row_column') terms = (r ? ['(1|rep)'] : []).concat(sup(t, 'row').ok ? ['(1|rep:row)'] : [], sup(t, 'col').ok ? ['(1|rep:col)'] : []);
    if (design === 'unreplicated') return { design: design, text: 'raw values (no replication, no error estimate)', warn: true };
    return { design: design, text: 'y ~ accession' + (terms.length ? ' + ' + terms.join(' + ') : ''), note: s1 === 'spats' && !t.has_rowcol ? 'no row/col: design model used' : '', off: factorsOff(t) };
}

function renderDesignTable() {
    if (!state.dataset) return;
    let h = '<table class="table table-condensed"><thead><tr><th>Trial</th><th>Design</th><th>Stage 1 model</th></tr></thead><tbody>';
    state.dataset.trials.forEach(t => {
        const m = trialModel(t);
        const det = detectDesign(t);
        let opts = '';
        Object.keys(DESIGNS).forEach(k => {
            const label = k === 'auto' ? 'Breedbase: ' + DESIGNS[det] + ' (suggested)' : DESIGNS[k];
            opts += '<option value="' + k + '"' + ((state.designOverrides[t.trial] || 'auto') === k ? ' selected' : '') + '>' + label + '</option>';
        });
        h += '<tr><td>' + esc(t.trial) + '<br/><small class="sf-muted">' + esc(t.location) + ' ' + esc(t.year) + '</small></td>' +
            '<td><select class="form-control input-sm sf-design-override" data-trial="' + esc(t.trial) + '">' + opts + '</select></td>' +
            '<td><code>' + esc(m.text) + '</code>' + (m.spats ? ' <span class="label label-success">spatial</span>' : '') +
            (m.warn ? ' <span class="label label-warning">unreplicated</span>' : '') + (m.note ? ' <small class="sf-muted">' + esc(m.note) + '</small>' : '') +
            (m.off && m.off.length ? '<br/><small class="sf-warn-text"><span class="glyphicon glyphicon-ban-circle"></span> not used: ' + esc(m.off.join('; ')) + '</small>' : '') + '</td></tr>';
    });
    h += '</tbody></table>';
    $('#sf_design_table').html(h);
}

function renderModelPreview() {
    const two = radio('sf_strategy') === 'two_stage';
    let txt;
    if (two) {
        const random = $('#sf_stage2_genotype').val() === 'random';
        const w = $('#sf_stage2_weighting').val() === 'inverse_se2';
        txt = '# Stage 1 (per trial, per trait)\n' +
            (state.dataset ? state.dataset.trials.map(t => '  ' + t.trial + ':  ' + trialModel(t).text).join('\n') : '') +
            '\n\n# Stage 2 (across trials)\n  BLUE_ij ~ trial_j + ' + (random ? '(1|accession_i)' : 'accession_i') + stage2Extra(random) + ' + e_ij' + (w ? ',  weights = 1 / SE_ij^2' : '') +
            '\n  -> ' + valueText(random);
    } else {
        renderSingleHints();
        if (radio('sf_single_mode') === 'custom') {
            const chk = checkFormula($('#sf_single_formula').val());
            txt = chk.ok ? 'y ~ ' + chk.rhs + '\n  -> ' + valueText(chk.random) : '# ' + chk.msg;
        } else {
            const b = singleBuilderFormula();
            txt = 'y ~ ' + b.terms.join(' + ') + '\n  -> ' + valueText(b.random);
            if (b.dropped.length) txt += '\n# left out, not supported by this dataset: ' + b.dropped.join('; ');
            if (!state.dataset) txt += '\n# load a dataset to see which terms apply';
        }
    }
    const g = geneticRecipe();
    if (g.model === 'pedigree') txt += '\n# accession ~ N(0, A s2a): A = additive relationship from the pedigree (accessions and ancestors)';
    txt += '\n# engine: ' + (radio('sf_engine') === 'blupf90' ? 'BLUPF90+ (blupf90+, AI-REML)' + (two ? '; SpATS stage 1 models stay in R' : '') : 'R (lme4' + (two ? ' / SpATS' : '') + ')' + (g.model === 'pedigree' ? '; pedigree models: BLUPF90+' : ''));
    $('#sf_model_preview').html('<div class="sf-formula">' + esc(txt) + '</div>');
    renderGeneticInfo();
    renderSuggestion();
}

function geneticRecipe() {
    return { model: $('#sf_gen_model').val() || 'iid', check: $('#sf_check').val() || 'auto' };
}

function valueText(random) {
    if (!random) return 'BLUEs (genotype fixed)';
    return geneticRecipe().model === 'pedigree' ? 'EBVs: breeding values (genotype random, pedigree)' : 'BLUPs (genotype random)';
}

// genetic terms of stage 2, as shown in the preview
function stage2Extra(random) {
    if (!random) return '';
    const g = geneticRecipe();
    const D = singleData();
    let t = '';
    if (g.check === 'fixed' || (g.check === 'auto' && (!D || D.n_check_plots > 0))) t += ' + check';
    if (g.model === 'parents') t += ' + (1|mother) + (1|father)';
    return t;
}

function renderGeneticInfo() {
    const ds = state.dataset;
    if (!ds) { $('#sf_pedigree_info, #sf_check_info').html(''); return; }
    const p = ds.pedigree || {};
    const n = ds.n_accessions;
    const g = geneticRecipe();
    let h = p.n_with_parents ? '<b>' + p.n_with_parents + '</b> of ' + n + ' accessions have known parents (' + (p.n_with_both || 0) + ' with both), ' +
        (p.n_mothers || 0) + ' mothers, ' + (p.n_fathers || 0) + ' fathers, ' + (p.n_ancestors || 0) + ' further ancestors.' :
        '<span class="warn">No parents are recorded in Breedbase for these accessions</span>; the mother / father and pedigree models would fall back to unrelated accessions.';
    const random = radio('sf_strategy') === 'two_stage' ? $('#sf_stage2_genotype').val() === 'random' : $('#sf_single_genotype').val() !== 'fixed';
    if (g.model !== 'iid' && !random) h += '<br/><span class="warn">These models need the genotype as random effect.</span>';
    if (g.model === 'pedigree') h += '<br/>' + (cfg.blupf90_available
        ? 'The pedigree model is fitted with BLUPF90+, whichever engine is chosen.'
        : '<span class="warn">The pedigree model needs BLUPF90+, which is not installed on this server; the accessions would be treated as unrelated.</span>');
    $('#sf_pedigree_info').html(h);
    const D = singleData();
    $('#sf_check_info').html(D.n_check_plots ? D.n_check_plots + ' plot(s) of entries marked as check.' : '<span class="sf-muted">No entry is marked as check in this dataset.</span>');
}

// ---------------------------------------------------------------------------
// Breedbase suggestion: model choices derived from the trial designs stored in
// Breedbase, the field layouts, the checks and the pedigree
// ---------------------------------------------------------------------------

// traits that usually make good covariates (plant stand and the like)
const COV_HINT = /stand|plant.?count|number of plants|plants? per plot|emergence|germination|establishment|plot area|harvested area/i;

function suggestion() {
    const ds = state.dataset;
    if (!ds) return null;
    const trials = ds.trials.map(t => {
        const layout = [t.n_reps > 1 ? t.n_reps + ' reps' : '', t.n_blocks > 1 ? t.n_blocks + ' blocks' : '',
            t.has_rowcol ? t.n_rows + ' rows x ' + t.n_cols + ' cols' : '', t.n_check_plots ? t.n_check_plots + ' check plots' : '',
            t.replicated ? '' : 'no replicated entries'].filter(Boolean).join(', ') +
            (factorsOff(t).length ? '. Not used as factor: ' + factorsOff(t).join('; ') : '');
        return { t: t, design: detectDesign(t), stored: t.design || '', layout: layout || 'no replicates or blocks recorded' };
    });
    const nT = trials.length;
    const nRC = trials.filter(x => x.t.has_rowcol).length;
    const designs = {};
    trials.forEach(x => { designs[x.design] = (designs[x.design] || 0) + 1; });
    const dNames = Object.keys(designs);
    const S = { trials: trials, items: [] };
    const item = (key, label, value, text, why) => S.items.push({ key: key, label: label, value: value, text: text, why: why });

    let strategy, why;
    if (nT === 1) { strategy = 'single_stage'; why = 'One trial: a single model gives the genotype values directly.'; }
    else if (nRC > 0) { strategy = 'two_stage'; why = nRC + ' of ' + nT + ' trials have a row x column layout: in stage 1 each of them gets its own spatial (SpATS) model.'; }
    else if (dNames.length > 1) { strategy = 'two_stage'; why = 'The trials have different designs (' + dNames.map(d => DESIGNS[d]).join(', ') + '): each is analysed with its own model, then combined.'; }
    else if (nT > 30) { strategy = 'two_stage'; why = nT + ' trials: two stages keep the model small.'; }
    else { strategy = 'single_stage'; why = 'All ' + nT + ' trials share the ' + DESIGNS[dNames[0]] + ' design: one model on all plots uses all the information.'; }
    item('strategy', 'Strategy', strategy, strategy === 'two_stage' ? 'Two stages' : 'Single stage', why);
    S.strategy = strategy;
    if (strategy === 'two_stage') {
        S.stage1 = nRC ? 'auto' : 'design';
        item('stage1', 'Stage 1 model', S.stage1, nRC ? 'Automatic (SpATS where rows / columns exist)' : 'Design model',
            nRC ? 'Spatial correction for the ' + nRC + ' trial(s) with rows and columns, design model for the others.' : 'No trial has row and column numbers; each trial gets the model of its design (see the table).');
    }
    const avail = !!cfg.blupf90_available;
    S.engine = avail && ds.n_plots >= 10000 ? 'blupf90' : 'lme4';
    item('engine', 'Engine', S.engine, S.engine === 'blupf90' ? 'BLUPF90+' : 'R',
        Number(ds.n_plots).toLocaleString('en-US') + ' plots: ' + (S.engine === 'blupf90' ? 'BLUPF90+ is much faster on datasets of this size.' :
            'R is fast at this size' + (avail ? ' (BLUPF90+ pays off from about 10,000 plots or with large pedigrees).' : '; BLUPF90+ is not installed on this server.')));
    S.genotype = 'random';
    item('genotype', 'Genotype effect', 'random', 'Random (BLUPs)', 'Shrunken predictions are the best basis for selection. Choose fixed (BLUEs) to feed GWAS or genomic prediction.');
    const p = ds.pedigree || {};
    const frac = ds.n_accessions ? (p.n_with_parents || 0) / ds.n_accessions : 0;
    S.genetic = frac >= 0.5 ? 'pedigree' : 'iid';
    item('genetic', 'Genetic model', S.genetic, S.genetic === 'pedigree' ? 'Pedigree (A matrix)' : 'Unrelated accessions',
        !p.n_with_parents ? 'No parents are recorded in Breedbase for these accessions.' :
        p.n_with_parents + ' of ' + ds.n_accessions + ' accessions have known parents' + (S.genetic === 'pedigree' ? ': relatives share information and breeding values are estimated (ancestors included).' : ', too few for a pedigree model.'));
    const nChk = trials.reduce((a, x) => a + (x.t.n_check_plots || 0), 0);
    S.check = 'auto';
    item('check', 'Checks', 'auto', nChk ? 'Fixed check effect' : 'Not needed', nChk ? nChk + ' plots of checks: checks get their own fixed mean, so test entries are not shrunk toward it.' : 'No entry is marked as check.');
    S.covariates = (strategy === 'single_stage') ? ds.traits.filter(t => COV_HINT.test(t.short)).map(t => t.name) : [];
    if (S.covariates.length) item('covariates', 'Covariates', S.covariates.join('|'), S.covariates.map(shortTrait).join(', '), 'Plant stand and similar counts explain part of the plot-to-plot variation of yield-type traits.');
    S.gxe = nT > 1 ? ['trial'] : [];
    const trts = datasetTreatments();
    S.trt = { use: trts.filter(f => f.varies_within_trials).map(f => f.name), gxt: trts.filter(gxtPossible).map(f => f.name) };
    if (trts.length) {
        const txt = [].concat(S.trt.use.map(n => 'adjust for ' + n), S.trt.gxt.map(n => 'G\u00d7' + n)).join(', ') || 'not in the model';
        const why = trts.map(f => f.name + (f.varies_within_trials ? ' varies within trials: genotypes are compared at the same level'
            : gxtPossible(f) ? ' is applied to whole trials (' + f.n_trial_levels + ' levels over ' + nT + ' trials): its main effect is part of the trial effect; G\u00d7' + f.name + ' shows whether rankings change with it'
            : ' is applied to whole trials and cannot be separated from them')).join('. ') + '.';
        item('treatments', 'Treatments', [S.trt.use.slice().sort().join('|'), S.trt.gxt.slice().sort().join('|')].join(';'), txt, why);
    }
    return S;
}

function currentChoice(key) {
    const two = radio('sf_strategy') === 'two_stage';
    switch (key) {
        case 'strategy': return radio('sf_strategy');
        case 'stage1': return radio('sf_stage1_model');
        case 'engine': return radio('sf_engine');
        case 'genotype': return two ? $('#sf_stage2_genotype').val() : $('#sf_single_genotype').val();
        case 'genetic': return $('#sf_gen_model').val();
        case 'check': return $('#sf_check').val();
        case 'covariates': return Object.keys(state.singleCov).sort().join('|');
        case 'treatments': { const t = treatmentRecipe(); return [t.use.slice().sort().join('|'), t.gxt.slice().sort().join('|')].join(';'); }
    }
    return null;
}

function renderSuggestion() {
    const S = suggestion();
    $('.sf-option-title .sf-suggested').remove();
    if (!S) { $('#sf_suggest').html('<span class="sf-muted">Load a dataset to get a suggestion.</span>'); return; }
    let h = '<div class="table-responsive"><table class="table table-condensed"><thead><tr><th>Trial</th><th>Design</th><th>Based on</th><th>Layout</th></tr></thead><tbody>';
    S.trials.forEach(x => {
        h += '<tr><td>' + esc(x.t.trial) + '</td><td><span class="label label-default">' + esc(DESIGNS[x.design]) + '</span>' + (x.t.has_rowcol ? ' <span class="label label-success">spatial</span>' : '') + '</td>' +
            '<td><small>' + (x.stored ? 'design stored in Breedbase: <i>' + esc(x.stored) + '</i>' : 'field layout (no design stored)') + '</small></td><td><small class="sf-muted">' + esc(x.layout) + '</small></td></tr>';
    });
    h += '</tbody></table></div><ul class="sf-suggest-list">';
    S.items.forEach(i => {
        const cur = currentChoice(i.key);
        const same = String(cur) === String(i.key === 'covariates' ? i.value.split('|').sort().join('|') : i.value);
        h += '<li><b>' + esc(i.label) + '</b><span>' + esc(i.text) + '</span><span class="why">' + esc(i.why) + '</span>' +
            (same ? '<span class="st-ok"><span class="glyphicon glyphicon-ok"></span> in use</span>' : '<span class="st-diff"><span class="glyphicon glyphicon-transfer"></span> you chose otherwise</span>') + '</li>';
    });
    h += '</ul>';
    $('#sf_suggest').html(h);
    // mark the suggested options
    const mark = '<span class="sf-suggested">suggested</span>';
    $('input[name=sf_strategy][value=' + S.strategy + ']').closest('label').find('.sf-option-title').append(mark);
    if (S.stage1) $('input[name=sf_stage1_model][value=' + S.stage1 + ']').closest('label').find('.sf-option-title').append(mark);
    $('input[name=sf_engine][value=' + S.engine + ']').closest('label').find('.sf-option-title').append(mark);
    ['#sf_gen_model', '#sf_check', '#sf_stage2_genotype', '#sf_single_genotype'].forEach(id => {
        const want = { '#sf_gen_model': S.genetic, '#sf_check': S.check }[id] || S.genotype;
        $(id + ' option').each(function() {
            const o = $(this);
            if (o.data('orig') === undefined) o.data('orig', o.text());
            o.text(o.data('orig') + (o.val() === want ? '  \u2605 suggested' : ''));
        });
    });
}

function applySuggestion() {
    const S = suggestion();
    if (!S) return;
    setRadio('sf_strategy', S.strategy);
    if (S.stage1) setRadio('sf_stage1_model', S.stage1);
    setRadio('sf_engine', S.engine);
    $('#sf_stage2_genotype').val(S.genotype);
    $('#sf_single_genotype').val(S.genotype);
    $('#sf_gen_model').val(S.genetic);
    $('#sf_check').val(S.check);
    state.designOverrides = {};
    state.trt = { use: toSet(S.trt.use), gxt: toSet(S.trt.gxt) };
    renderTreatments();
    if (S.strategy === 'single_stage') {
        setRadio('sf_single_mode', 'builder');
        ['#sf_single_rep', '#sf_single_block', '#sf_single_rowcol'].forEach(id => $(id).val('auto'));
        $('#sf_single_env').val('fixed');
        $('.sf-single-gxe').each(function() { $(this).prop('checked', S.gxe.indexOf($(this).val()) >= 0); });
        S.covariates.forEach(t => { state.singleCov[t] = true; });
        renderSingleCovariates();
    }
    refreshAll();
    renderDesignTable();
    renderModelPreview();
}

// single-stage model ---------------------------------------------------------

// variables a written formula may use (kept in sync with FORMULA_VARS in the R pipeline)
const FORMULA_VARS = {
    accession: 'genotype', trial: 'trial (environment)', location: 'location', year: 'year',
    rep: 'replicate (nest it: trial:rep)', block: 'block (nest it: trial:rep:block)',
    row: 'row as factor (trial:row)', col: 'column as factor (trial:col)', rowN: 'row number (numeric trend)', colN: 'column number (numeric trend)',
    mother: 'female parent (random: (1|mother))', father: 'male parent (random: (1|father))', check: 'check vs test entry (fixed)'
};

function covName(t) { return 'cov_' + shortTrait(t).replace(/[^A-Za-z0-9]+/g, '_'); }

function singleRecipe() {
    const gxe = [];
    $('.sf-single-gxe:checked').each(function() { gxe.push($(this).val()); });
    return {
        mode: radio('sf_single_mode') || 'builder',
        genotype: $('#sf_single_genotype').val(),
        env: $('#sf_single_env').val(),
        rep: $('#sf_single_rep').val(),
        block: $('#sf_single_block').val(),
        rowcol: $('#sf_single_rowcol').val(),
        trend: $('#sf_single_trend').val(),
        gxe: gxe,
        include_gxe: gxe.indexOf('trial') >= 0,     // read by scripts made before version 1.1
        covariates: Object.keys(state.singleCov),
        formula: $.trim($('#sf_single_formula').val() || '')
    };
}

function applySingle(ss) {
    setRadio('sf_single_mode', ss.mode || 'builder');
    $('#sf_single_genotype').val(ss.genotype || 'random');
    $('#sf_single_env').val(ss.env || 'fixed');
    $('#sf_single_rep').val(ss.rep || 'auto');
    $('#sf_single_block').val(ss.block || 'auto');
    $('#sf_single_rowcol').val(ss.rowcol || 'auto');
    $('#sf_single_trend').val(ss.trend || 'none');
    const gxe = ss.gxe ? arr(ss.gxe) : (ss.include_gxe === false ? [] : ['trial']);
    $('.sf-single-gxe').each(function() { $(this).prop('checked', gxe.indexOf($(this).val()) >= 0); });
    $('#sf_single_formula').val(ss.formula || '');
    state.singleCov = {};
    arr(ss.covariates).forEach(t => { const m = matchTrait(t) || t; state.singleCov[m] = true; });
    renderSingleCovariates();
}

// what the dataset offers for each term of the single-stage builder
function singleData() {
    const ds = state.dataset;
    if (!ds) return null;
    const tr = ds.trials;
    const designs = tr.map(t => state.designOverrides[t.trial] && state.designOverrides[t.trial] !== 'auto' ? state.designOverrides[t.trial] : detectDesign(t));
    const uniq = k => { const o = {}; tr.forEach(t => { o[t[k] || ''] = 1; }); return Object.keys(o).length; };
    return {
        n_trials: tr.length,
        rep_trials: tr.filter(t => sup(t, 'rep').ok).length,
        block_trials: tr.filter(t => sup(t, 'block').ok).length,
        rc_trials: tr.filter(t => sup(t, 'row').ok || sup(t, 'col').ok).length,
        row_trials: tr.filter(t => sup(t, 'row').ok).length,
        col_trials: tr.filter(t => sup(t, 'col').ok).length,
        // why a factor is left out, per reason: {why: [trials]}
        why: f => { const o = {}; tr.filter(t => !sup(t, f).ok).forEach(t => { (o[sup(t, f).why] = o[sup(t, f).why] || []).push(t.trial); }); return o; },
        incomplete: designs.some(d => d === 'alpha_lattice' || d === 'augmented'),
        rowcol_design: designs.some(d => d === 'row_column'),
        n_locations: uniq('location'),
        n_years: uniq('year'),
        n_check_plots: tr.reduce((a, t) => a + (t.n_check_plots || 0), 0)
    };
}

// formula of the builder, written with the variables of the custom formula;
// "automatic" choices are resolved the same way as in the R pipeline
function singleBuilderFormula() {
    const r = singleRecipe();
    const D = singleData();
    const terms = [r.genotype === 'fixed' ? 'accession' : '(1|accession)'];
    const dropped = [];
    const add = (term, ok, why) => { if (ok) terms.push(term); else dropped.push(why); };
    const known = !!D;
    if (r.env !== 'none') add(r.env === 'random' ? '(1|trial)' : 'trial', !known || D.n_trials > 1, 'trial (one trial)');
    const repOn = r.rep === 'auto' ? (!known || D.rep_trials > 0) : r.rep !== 'none';
    if (repOn) add(r.rep === 'fixed' ? 'trial:rep' : '(1|trial:rep)', !known || D.rep_trials > 0, 'replicate (' + (known ? Object.keys(D.why('rep')).join(', ') : '') + ')');
    const blockOn = r.block === 'auto' ? (known ? D.incomplete && D.block_trials > 0 : true) : r.block !== 'none';
    if (blockOn) add(r.block === 'fixed' ? 'trial:rep:block' : '(1|trial:rep:block)', !known || D.block_trials > 0, 'block (' + (known ? Object.keys(D.why('block')).join(', ') : '') + ')');
    const rcOn = r.rowcol === 'auto' ? (known ? D.rowcol_design || (D.rc_trials === D.n_trials && D.n_trials > 0) : false) : r.rowcol !== 'none';
    if (rcOn) {
        add('(1|trial:row)', !known || D.row_trials > 0, 'row (' + (known ? Object.keys(D.why('row')).join(', ') : '') + ')');
        add('(1|trial:col)', !known || D.col_trials > 0, 'column (' + (known ? Object.keys(D.why('col')).join(', ') : '') + ')');
    }
    if (r.trend === 'linear') add(!known || D.n_trials > 1 ? 'trial:rowN + trial:colN' : 'rowN + colN', !known || D.rc_trials > 0, 'linear trend (no row and column numbers)');
    r.gxe.forEach(g => {
        const n = !known ? 2 : g === 'trial' ? D.n_trials : g === 'location' ? D.n_locations : D.n_years;
        if (known && g !== 'trial' && r.gxe.indexOf('trial') >= 0 && n > 1 && n === D.n_trials) {
            dropped.push('accession x ' + g + ' (each ' + g + ' has one trial: the same as accession x trial)');
            return;
        }
        add('(1|accession:' + g + ')', n > 1, 'accession x ' + g + ' (one ' + g + ')');
    });
    r.covariates.forEach(t => terms.push(covName(t)));
    const tr = treatmentRecipe();
    datasetTreatments().forEach(f => {
        const nLv = f.levels.length;
        if (tr.use.indexOf(f.name) >= 0) {
            if (nLv < 2) dropped.push(f.name + ' (one level)');
            else if (r.env === 'fixed' && D && D.n_trials > 1 && !f.varies_within_trials) dropped.push(f.name + ' main effect (constant within each trial: held by the trial effect)');
            else terms.push(f.variable);
        }
        if (tr.gxt.indexOf(f.name) >= 0) add('(1|accession:' + f.variable + ')', nLv > 1, 'accession x ' + f.name + ' (one level)');
    });
    const g = geneticRecipe();
    if (r.genotype !== 'fixed') {
        const nChk = known ? D.n_check_plots : 1;
        if (g.check === 'fixed' || (g.check === 'auto' && nChk > 0)) add('check', nChk > 0, 'check (no entry marked as check)');
        if (g.model === 'parents') terms.push('(1|mother)', '(1|father)');
    } else if (g.model !== 'iid') dropped.push((g.model === 'pedigree' ? 'pedigree' : 'mother / father') + ' (needs the genotype as random)');
    return { terms: terms, dropped: dropped, random: r.genotype !== 'fixed' };
}

// same checks as parse_custom_formula() in the R pipeline
function checkFormula(txt) {
    let rhs = String(txt || '').replace(/[\r\n\t]+/g, ' ').replace(/^\s*y\s*~/, '').trim();
    if (!rhs) return { ok: false, msg: 'write the formula of the model' };
    const allowed = Object.keys(FORMULA_VARS).concat(Object.keys(state.singleCov).map(covName), treatmentVars());
    const toks = rhs.match(/[A-Za-z_][A-Za-z0-9_.]*|[0-9]+(\.[0-9]+)?|\s+|./g) || [];
    let depth = 0;
    for (let i = 0; i < toks.length; i++) {
        const tk = toks[i];
        if (/^\s+$/.test(tk)) continue;
        if ('+-*/:|'.indexOf(tk) >= 0) continue;
        if (tk === '(') { depth++; continue; }
        if (tk === ')') { if (--depth < 0) return { ok: false, msg: 'unbalanced parentheses' }; continue; }
        if (/^[0-9]/.test(tk)) { if (tk === '0' || tk === '1') continue; return { ok: false, msg: 'only the numbers 0 and 1 are allowed (found "' + tk + '")' }; }
        if (/^[A-Za-z_]/.test(tk)) {
            const next = toks.slice(i + 1).filter(x => !/^\s+$/.test(x))[0];
            if (next === '(') return { ok: false, msg: 'functions are not allowed ("' + tk + '(")' };
            if (allowed.indexOf(tk) < 0) return { ok: false, msg: 'unknown variable "' + tk + '"' + (/^cov_/.test(tk) ? ' (select the covariate below first)' : '') };
            continue;
        }
        return { ok: false, msg: 'character "' + tk + '" is not allowed' };
    }
    if (depth !== 0) return { ok: false, msg: 'unbalanced parentheses' };
    const D = singleData();
    if (D) {
        const used = toks.filter(x => FACTOR_NAMES[x]);
        const off = Object.keys(FACTOR_NAMES).filter(f => used.indexOf(f) >= 0 && D[f + '_trials'] === 0);
        if (off.length) return { ok: false, msg: off.map(f => '"' + f + '" cannot be used: ' + Object.keys(D.why(f)).join(', ')).join('; ') };
    }
    const random = /\(\s*1\s*\|\s*accession\s*\)/.test(rhs);
    const fixedPart = rhs.replace(/\([^()]*\|[^()]*\)/g, '');
    const fixed = fixedPart.split('+').map(x => x.trim()).indexOf('accession') >= 0;
    if (random === fixed) return { ok: false, msg: 'include the genotype exactly once: "accession" (fixed) or "(1|accession)" (random)' };
    return { ok: true, rhs: rhs.replace(/\s+/g, ' '), random: random };
}

function renderSingleHints() {
    const D = singleData();
    const hint = (k, h) => $('.sf-term-hint[data-hint=' + k + ']').html(h);
    const trtTitle = {};
    datasetTreatments().forEach(f => { trtTitle[f.variable] = 'treatment ' + f.name + ' (' + f.levels.length + ' levels)'; });
    $('#sf_single_vars').html(Object.keys(FORMULA_VARS).concat(Object.keys(state.singleCov).map(covName), treatmentVars()).map(v =>
        '<span class="label label-default sf-var" data-v="' + esc(v) + '" title="' + esc(FORMULA_VARS[v] || trtTitle[v] || 'covariate') + '">' + esc(v) + '</span>').join(' '));
    const chk = checkFormula($('#sf_single_formula').val());
    $('#sf_single_formula_check').html($.trim($('#sf_single_formula').val()) ?
        (chk.ok ? '<small style="color:#2b7a4b"><span class="glyphicon glyphicon-ok"></span> Valid formula: genotype ' + (chk.random ? 'random (BLUPs)' : 'fixed (BLUEs)') + '</small>' :
            '<small style="color:#dc2626"><span class="glyphicon glyphicon-exclamation-sign"></span> ' + esc(chk.msg) + '</small>') : '');
    if (!D) {
        $('.sf-term-hint').html('<span class="sf-muted">load a dataset</span>');
        $('#sf_single_rep, #sf_single_block, #sf_single_rowcol').find('option').prop('disabled', false).removeAttr('title');
        return;
    }
    const of = (n, tot, what) => '<span' + (n ? '' : ' class="warn"') + '>' + n + ' of ' + tot + ' trial(s) ' + what + '</span>';
    hint('genotype', '');
    hint('env', D.n_trials > 1 ? D.n_trials + ' trials' : '<span class="warn">one trial: no environment effect</span>');
    const whyList = f => Object.entries(D.why(f)).map(([w, ts]) => '<br/><small class="sf-muted">left out in ' + esc(ts.length > 3 ? ts.length + ' trials' : ts.join(', ')) + ': ' + esc(w) + '</small>').join('');
    hint('rep', of(D.rep_trials, D.n_trials, 'where the entries are replicated') + (D.rep_trials < D.n_trials ? whyList('rep') : ''));
    hint('block', of(D.block_trials, D.n_trials, 'with usable blocks') + (D.block_trials < D.n_trials ? whyList('block') : '') + (D.incomplete ? '' : '<br/>automatic: only for alpha-lattice / augmented'));
    hint('rowcol', of(D.rc_trials, D.n_trials, 'with usable rows / columns') + (D.rc_trials < D.n_trials ? whyList('row') : ''));
    // the smart block: a factor no trial supports cannot be put in the model
    [['#sf_single_rep', D.rep_trials, 'rep'], ['#sf_single_block', D.block_trials, 'block'], ['#sf_single_rowcol', D.rc_trials, 'row']].forEach(([id, n, f]) => {
        const sel = $(id);
        const why = n ? '' : 'Not supported by this dataset: ' + Object.keys(D.why(f)).join(', ');
        sel.find('option[value=random], option[value=fixed]').prop('disabled', !n).attr('title', why);
        if (!n && ['random', 'fixed'].indexOf(sel.val()) >= 0) sel.val('auto');
    });
    hint('trend', of(D.rc_trials, D.n_trials, 'with row and column numbers'));
    hint('gxe', D.n_trials + ' trial(s), ' + D.n_locations + ' location(s), ' + D.n_years + ' year(s)');
}

function renderSingleCovariates() {
    if (!state.dataset) { $('#sf_single_covariates').html('<span class="sf-muted">load a dataset</span>'); return; }
    $('#sf_single_covariates').html(state.dataset.traits.map(t => {
        const on = !!state.singleCov[t.name];
        return '<label class="' + (on ? 'on' : '') + '" title="' + esc(t.name) + '"><input type="checkbox" value="' + esc(t.name) + '"' + (on ? ' checked' : '') + ' />' +
            (on ? '<span class="glyphicon glyphicon-ok"></span> ' : '') + esc(t.short) + (on ? ' <code>' + esc(covName(t.name)) + '</code>' : '') +
            (COV_HINT.test(t.short) ? '<span class="sf-suggested">suggested</span>' : '') + '</label>';
    }).join(''));
}

// ---------------------------------------------------------------------------
// step 4 - selection index
// ---------------------------------------------------------------------------

function renderIndexTable() {
    let h = '';
    state.traits.forEach(t => {
        const c = state.indexCfg[t] || (state.indexCfg[t] = { weight: 0, direction: 'increase' });
        h += '<tr><td title="' + esc(t) + '">' + esc(shortTrait(t)) + '</td>' +
            '<td><input type="number" step="0.1" class="form-control input-sm sf-index-weight" style="width:100px" data-trait="' + esc(t) + '" value="' + esc(c.weight) + '" /></td>' +
            '<td><div class="btn-group btn-group-sm" data-trait="' + esc(t) + '">' +
            '<button class="btn sf-index-dir ' + (c.direction !== 'decrease' ? 'btn-success' : 'btn-default') + '" data-dir="increase"><span class="glyphicon glyphicon-arrow-up"></span> Higher is better</button>' +
            '<button class="btn sf-index-dir ' + (c.direction === 'decrease' ? 'btn-success' : 'btn-default') + '" data-dir="decrease"><span class="glyphicon glyphicon-arrow-down"></span> Lower is better</button>' +
            '</div></td></tr>';
    });
    $('#sf_index_traits').html(h);
    renderIndexFormula();
}

function renderIndexFormula() {
    const parts = state.traits.filter(t => Number((state.indexCfg[t] || {}).weight) !== 0).map(t => {
        const c = state.indexCfg[t];
        const sign = (c.direction === 'decrease' ? -1 : 1) * Number(c.weight);
        // rank sum: the direction is inside the rank (rank 1 = lowest value when lower is better)
        return (sign < 0 ? '- ' : '+ ') + Math.abs(sign) + ' * ' + (radio('sf_index_method') === 'rank_sum'
            ? 'rank(' + shortTrait(t) + ', ' + (c.direction === 'decrease' ? 'lowest' : 'highest') + ' = 1)'
            : 'z(' + shortTrait(t) + ')');
    });
    let f;
    if (!parts.length) f = '# give a non-zero weight to at least one trait';
    else if (radio('sf_index_method') === 'rank_sum') f = 'I = -(' + parts.map(p => p.replace(/^[+-] /, '')).join(' + ') + ')    # rank 1 = best value in the chosen direction; lower rank sum = better';
    else f = 'I = ' + parts.join(' ').replace(/^\+ /, '');
    $('#sf_index_formula').text(f + '\nselect the top ' + $('#sf_selection_pct').val() + '% of accessions');
}

// ---------------------------------------------------------------------------
// step 5 - zones
// ---------------------------------------------------------------------------

function renderZoneTargets() {
    const item = (value, label, sub, disabled) => {
        const on = !!state.zoneTargets[value] && !disabled;
        return '<label class="sf-trait' + (on ? ' on' : '') + '"' + (disabled ? ' style="opacity:.5"' : '') + '><input type="checkbox" class="sf-zone-target" value="' + esc(value) + '"' + (on ? ' checked' : '') + (disabled ? ' disabled' : '') + ' />' +
            '<span><b>' + esc(label) + '</b><small>' + sub + '</small></span></label>';
    };
    const indexOn = $('#sf_index_enabled').is(':checked');
    let h = item('index', 'Selection index', indexOn ? 'index computed in each environment' : 'enable the selection index first', !indexOn);
    state.traits.forEach(t => { h += item(t, shortTrait(t), 'genotype means per environment'); });
    $('#sf_zones_targets').html(h);
}

// ---------------------------------------------------------------------------
// pipeline summary
// ---------------------------------------------------------------------------

function geneticChip(r) {
    return '<br/>' + (r.engine === 'blupf90' ? 'BLUPF90+' : 'R') + (r.genetic.model === 'pedigree' ? ', pedigree (A)' : r.genetic.model === 'parents' ? ', mother + father' : '');
}

function renderPipeline() {
    const r = buildRecipe();
    const items = [];
    items.push({ t: 'Data', d: state.dataset ? esc(state.dataset.dataset_name) + '<br/>' + state.traits.length + ' trait(s), ' + state.dataset.trials.length + ' trial(s)' : 'no dataset loaded', off: !state.dataset });
    const o = r.outliers;
    const exKeys = Object.keys(state.exclusions).filter(k => state.traits.indexOf(state.exclusions[k].trait) >= 0);
    const nMk = exKeys.filter(k => state.exclusions[k].marked).length;
    const nEx = exKeys.length - nMk;
    items.push({ t: 'Quality control', d: (o.method === 'iqr' ? 'IQR k = ' + o.k + ' by ' + o.group_by.replace('_', ' &times; ') : o.method === 'madr' ? 'BH-MADR, &alpha; = ' + o.alpha : 'no automatic rule') +
        (nEx ? '<br/>' + nEx + ' individual exclusion(s)' : '') + (nMk ? '<br/>' + nMk + ' value(s) marked as outliers in Breedbase' : ''), off: o.method === 'none' && !nEx && !nMk });
    if (r.strategy === 'two_stage') {
        items.push({ t: 'Stage 1', d: { auto: 'SpATS when possible, else design model', spats: 'SpATS spatial', design: 'design model' }[r.stage1.model] + trtChip(r.treatments.use, 'adjusted for ') });
        items.push({ t: 'Stage 2', d: (r.stage2.genotype === 'random' ? (r.genetic.model === 'pedigree' ? 'EBVs' : 'BLUPs') : 'BLUEs') + (r.stage2.weighting === 'inverse_se2' ? ', weighted 1/SE&sup2;' : ', unweighted') + trtChip(r.treatments.gxt, 'G&times;') + geneticChip(r) });
    } else {
        let d;
        if (r.single.mode === 'custom') {
            const chk = checkFormula(r.single.formula);
            d = 'custom formula' + (chk.ok ? ', ' + (chk.random ? 'BLUPs' : 'BLUEs') : ' (invalid)');
        } else {
            d = (r.single.genotype === 'random' ? 'BLUPs' : 'BLUEs') + ', trial ' + (r.single.env === 'none' ? 'not modelled' : r.single.env) +
                (r.single.gxe.length ? '<br/>G&times;' + r.single.gxe.join(', G&times;') : '<br/>no G&times;E') +
                (r.single.trend === 'linear' ? ', linear trend' : '') + (r.single.covariates.length ? ', ' + r.single.covariates.length + ' covariate(s)' : '');
        }
        if (r.single.mode !== 'custom') d += trtChip(r.treatments.use, 'adjusted for ') + trtChip(r.treatments.gxt, 'G&times;');
        items.push({ t: 'Single stage', d: d + geneticChip(r) });
    }
    const nIdx = Object.keys(r.index.traits).length;
    items.push({ t: 'Selection index', d: r.index.enabled ? (r.index.method === 'rank_sum' ? 'rank sum' : 'weighted Z-score') + ', ' + nIdx + ' trait(s), top ' + r.index.selection_pct + '%' : 'off', off: !r.index.enabled });
    items.push({ t: 'Environmental zones', d: r.zones.enabled ? (r.zones.method === 'lin' ? 'Lin G&times;E test' : 'correlation clustering') + ' by ' + r.zones.unit.replace('_', ' &times; ') + '<br/>' + r.zones.targets.map(x => x === 'index' ? 'index' : esc(shortTrait(x))).join(', ') : 'off', off: !r.zones.enabled });

    $('#sf_pipeline').html('<ul class="sf-flow">' + items.map(i => '<li class="' + (i.off ? 'off' : '') + '"><b>' + i.t + '</b>' + i.d + '</li>').join('') + '</ul>');
    updateRunButton();   // any change to the pipeline may make the last results stale
}

function trtChip(names, prefix) { return names.length ? '<br/>' + prefix + names.map(esc).join(', ' + prefix) : ''; }

// ---------------------------------------------------------------------------
// step 6 - run
// ---------------------------------------------------------------------------

function validateRecipe(r) {
    const problems = [];
    if (!r.traits.length) problems.push('Select at least one trait (step 1).');
    if (r.index.enabled && !Object.keys(r.index.traits).length) problems.push('The selection index is on but no trait has a non-zero weight (step 4).');
    if (r.strategy === 'single_stage' && r.single.mode === 'custom') {
        const chk = checkFormula(r.single.formula);
        if (!chk.ok) problems.push('Single-stage formula: ' + chk.msg + ' (step 3).');
    }
    if (r.zones.enabled && !r.zones.targets.length) problems.push('Choose what to group environments on (step 5).');
    if (r.zones.enabled && r.zones.targets.indexOf('index') >= 0 && !r.index.enabled) problems.push('Zoning on the index requires the selection index (step 4).');
    if (r.zones.enabled && state.dataset && state.dataset.trials.length < 2) problems.push('Environmental zoning needs at least two trials.');
    return problems;
}

function renderRunReview() {
    const r = buildRecipe();
    const problems = validateRecipe(r);
    const cell = (l, v) => '<div><b>' + l + '</b>' + v + '</div>';
    let h = '<div class="sf-review">' +
        cell('Dataset', state.dataset ? esc(state.dataset.dataset_name) : '&ndash;') +
        cell('Traits', r.traits.map(t => esc(shortTrait(t))).join(', ')) +
        cell('Outliers', r.outliers.method === 'none' ? 'none' : r.outliers.method.toUpperCase()) +
        cell('Model', (r.strategy === 'two_stage' ? 'Two stages' : 'Single stage' + (r.single.mode === 'custom' ? ' (custom formula)' : '')) +
            ' &middot; ' + (r.engine === 'blupf90' ? 'BLUPF90+' : 'R') + (r.genetic.model === 'pedigree' ? ' &middot; pedigree' : r.genetic.model === 'parents' ? ' &middot; mother + father' : '')) +
        cell('Index', r.index.enabled ? 'on' : 'off') +
        cell('Zones', r.zones.enabled ? 'on' : 'off') + '</div>';
    if (problems.length) h += alertBox('warning', problems.map(esc).join('<br/>'));
    $('#sf_run_review').html(h);
    updateRunButton();
}

// identifies what a run was computed from: dataset, every setting and the exclusions
function runKey() {
    const r = buildRecipe();
    delete r.name;
    return JSON.stringify([state.dataset ? state.dataset.token : null, r, Object.keys(state.exclusions).sort()]);
}

// ready | running | done (results match the current settings) | changed | failed
function runState() {
    if (state.job) return 'running';
    if (state.lastRun && state.results) return state.lastRun.key === runKey() ? 'done' : 'changed';
    if (state.runFailed) return 'failed';
    return 'ready';
}

function updateRunButton() {
    const s = runState();
    const problems = validateRecipe(buildRecipe());
    const look = {
        ready: ['btn-success', 'play', 'Run analysis'],
        running: ['btn-default', 'refresh sf-spin', 'Running...'],
        done: ['sf-run-done', 'ok-circle', 'Analysis completed'],
        changed: ['btn-warning', 'repeat', 'Re-run with changes'],
        failed: ['btn-danger', 'repeat', 'Retry analysis']
    }[s];
    $('#sf_run').removeClass('btn-success btn-default btn-warning btn-danger sf-run-done').addClass(look[0])
        .html('<span class="glyphicon glyphicon-' + look[1] + '"></span> ' + look[2])
        .prop('disabled', s === 'running' || s === 'done' || problems.length > 0);
    $('#sf_run_again').toggle(s === 'done');
    $('.sf-run-card').toggleClass('sf-run-is-done', s === 'done');
    let note = '';
    if (s === 'done') {
        const t = state.lastRun.finishedAt;
        const sec = state.lastRun.seconds;
        note = 'Finished at ' + String(t.getHours()).padStart(2, '0') + ':' + String(t.getMinutes()).padStart(2, '0') +
            ' in ' + (sec >= 60 ? Math.floor(sec / 60) + ' min ' : '') + (sec % 60) + ' s';
    } else if (s === 'changed') {
        note = 'Settings changed since the last run: the results below are from the previous settings.';
    }
    $('#sf_run_note').toggleClass('changed', s === 'changed').text(note);
}

function pollJob(job, onProgress) {
    return new Promise((resolve, reject) => {
        const tick = () => {
            $.ajax({ url: '/ajax/script_factory/status', data: { job_id: job.job_id, run_id: job.run_id }, dataType: 'json' })
                .done(r => {
                    if (r.error) { reject(new Error(r.error)); return; }
                    if (r.status === 'finished') { resolve(r.results); return; }
                    if (onProgress && r.progress) onProgress(r.progress);
                    state.pollTimer = setTimeout(tick, 3000);
                })
                .fail(() => { state.pollTimer = setTimeout(tick, 6000); });
        };
        state.pollTimer = setTimeout(tick, 1500);
    });
}

function runAnalysis() {
    const recipe = buildRecipe();
    if (validateRecipe(recipe).length || state.job) return;
    const key = runKey();
    state.job = { pending: true };
    state.runFailed = false;
    updateRunButton();
    renderQuickRun();
    $('#sf_results').hide();
    $('#sf_run_status').show();
    $('#sf_run_progress_text').text('Submitting...');
    const t0 = Date.now();
    state.elapsedTimer = setInterval(() => {
        const s = Math.round((Date.now() - t0) / 1000);
        $('#sf_run_elapsed').text('(' + Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0') + ')');
    }, 1000);

    const notify = $('#sf_notify').is(':checked') && !!cfg.user_email;
    post('/ajax/script_factory/run', { token: state.dataset.token, recipe: JSON.stringify(recipe), exclusions: JSON.stringify(exclusionsPayload()), mode: 'full', dataset_id: state.dataset.dataset_id, dataset_name: state.dataset.dataset_name, notify: notify ? 1 : 0 })
        .then(job => {
            state.job = job;
            $('#sf_run_progress_text').text('Queued. The analysis runs in the background; you can follow it in your jobs list too.' +
                (notify ? ' You will get an email at ' + cfg.user_email + ' when it finishes, so you can close this page.' : ''));
            return pollJob(job, p => $('#sf_run_progress_text').text(p));
        })
        .then(res => {
            state.results = res;
            state.results.run_id = state.job.run_id;
            state.resultsRecipe = recipe;
            state.lastRun = { key: key, finishedAt: new Date(), seconds: Math.round((Date.now() - t0) / 1000) };
            renderResults();
        })
        .catch(e => {
            state.results = null;
            state.lastRun = null;
            state.runFailed = true;
            $('#sf_run_review').append(alertBox('danger', '<b>The analysis failed.</b><pre style="white-space:pre-wrap;margin-top:6px">' + esc(e.message) + '</pre>'));
        })
        .finally(() => {
            clearInterval(state.elapsedTimer);
            state.job = null;
            $('#sf_run_status').hide();
            updateRunButton();
            renderQuickRun();
        });
}

// ---------------------------------------------------------------------------
// results
// ---------------------------------------------------------------------------

function simpleTable(rows, cols, opts) {
    opts = opts || {};
    rows = arr(rows);
    if (!rows.length) return '<p class="sf-muted">' + (opts.empty || 'Nothing to show.') + '</p>';
    let h = '<table class="table table-condensed table-hover sf-dt"' + (opts.id ? ' id="' + opts.id + '"' : '') + ' style="width:100%"><thead><tr>' +
        cols.map(c => '<th>' + c.l + '</th>').join('') + '</tr></thead><tbody>';
    rows.forEach(r => {
        h += '<tr' + (opts.rowClass ? ' class="' + opts.rowClass(r) + '"' : '') + '>' + cols.map(c => {
            const v = r[c.k];
            return '<td>' + (c.f ? c.f(v, r) : typeof v === 'number' ? fmt(v) : esc(v)) + '</td>';
        }).join('') + '</tr>';
    });
    return h + '</tbody></table>';
}

function renderResults() {
    const res = state.results;
    const s = res.summary || {};
    const label = res.value_label || 'BLUP';
    $('#sf_results').show();
    // a new run can be stored; a run stored before shows its analysis
    $('#sf_store_result').html('');
    $('#sf_save_analysis').prop('disabled', false).html('<span class="glyphicon glyphicon-save"></span> Store analysis');
    if (res.stored && res.stored.analysis_id) showStored(res.stored.analysis_id, res.stored.name);
    $('#sf_open_dashboard').attr('href', '/tools/script_factory/results/' + encodeURIComponent(res.run_id || '')).toggle(!!res.run_id);

    // downloads
    const dl = { genotype_values: 'Genotype values (' + label + 's)', stage1_means: 'Stage 1 means per trial', outliers: 'Removed outliers', index: 'Selection index ranking', zones: 'Environmental zones',
        ancestors: 'Breeding values of ancestors', blupf90: 'BLUPF90+ parameter and data files' };
    $('#sf_downloads').html(Object.keys(res.files || {}).map(k => '<li><a href="' + esc(res.files[k]) + '" download>' + esc(dl[k] || k) + (/\.tar\.gz$/.test(res.files[k]) ? ' (.tar.gz)' : ' (.csv)') + '</a></li>').join('') || '<li class="disabled"><a>No files</a></li>');
    // notes of the run: only what needs attention is shown here, the rest goes to the "Analysis log" tab
    $('#sf_warnings').html(analysisLogSummaryHtml(res.warnings));
    $('#sf_tab_log').html(analysisLogHtml(res.warnings, 'sf'));
    $('#sf_log_n').text(arr(res.warnings).length || '');
    $('#sf_save_list').prop('disabled', !res.index);

    // overview
    const stat = (v, l) => '<div class="sf-stat"><div class="v">' + v + '</div><div class="l">' + l + '</div></div>';
    let ov = '<div class="sf-stats">' + stat(s.n_trials, 'Trials') + stat(s.n_environments, 'Environments') + stat(s.n_accessions, 'Accessions') +
        stat(s.n_plots, 'Plots') + stat(arr(res.outliers).length, 'Values removed') + stat(label + 's', 'Genotype values') + '</div>';
    ov += '<h4>Heritability and variance components</h4>' + simpleTable(res.stage2, [
        { k: 'trait', l: 'Trait' }, { k: 'n_trials', l: 'Trials' }, { k: 'n_accessions', l: 'Accessions' }, { k: 'mean', l: 'Mean' },
        { k: 'var_g', l: '&sigma;&sup2;<sub>G</sub>' }, { k: 'var_ge', l: res.strategy === 'two_stage' ? '&sigma;&sup2;<sub>GE+e</sub>' : '&sigma;&sup2;<sub>GE</sub>' },
        { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) }, { k: 'message', l: 'Status', f: v => v === 'OK' ? '<span class="glyphicon glyphicon-ok" style="color:#2b7a4b"></span>' : '<small>' + esc(v) + '</small>' }
    ]);
    $('#sf_tab_overview').html(ov);

    // outliers
    const nRemoved = arr(res.outliers).length;
    const canDs = !!(state.dataset && state.dataset.dataset_is_owner);
    const canDb = String(cfg.can_mark_database) === '1';
    const markBar = nRemoved ? '<div class="sf-outlier-toolbar" style="margin-top:12px"><span style="margin-right:auto">Mark all <b>' + nRemoved + '</b> removed value(s) in Breedbase:</span>' +
        '<button class="btn btn-default btn-sm sf-mark-removed" data-action="dataset"' + (canDs ? '' : ' disabled title="Only the owner of the dataset can change its outliers"') + '><span class="glyphicon glyphicon-flag"></span> As dataset outliers</button>' +
        '<button class="btn btn-default btn-sm sf-mark-removed" data-action="database"' + (canDb ? '' : ' disabled title="Only curators and breeders can mark database outliers"') + '><span class="glyphicon glyphicon-hdd"></span> As database outliers</button></div>' +
        '<div id="sf_removed_message"></div>' : '';
    $('#sf_tab_outliers').html('<h4>Summary</h4>' + simpleTable(res.outlier_summary, [
        { k: 'trait', l: 'Trait' }, { k: 'n_observations', l: 'Observations', f: v => v }, { k: 'n_removed', l: 'Removed', f: v => v }, { k: 'pct_removed', l: '% removed', f: v => fmt(v, 2) + '%' }
    ]) + markBar + '<h4>Removed values</h4>' + simpleTable(res.outliers, [
        { k: 'unit', l: 'Plot' }, { k: 'trial', l: 'Trial' }, { k: 'accession', l: 'Accession' }, { k: 'trait', l: 'Trait' }, { k: 'value', l: 'Value' }, { k: 'reason', l: 'Reason' }
    ], { id: 'sf_dt_outliers', empty: 'No values were removed.' }));
    dataTable('#sf_dt_outliers');

    // stage 1
    $('#sf_tab_stage1_li').toggle(res.strategy === 'two_stage');
    $('#sf_tab_model_link').text(res.strategy === 'two_stage' ? 'Stage 2' : 'Model');
    $('#sf_tab_stage1').html(simpleTable(res.stage1, [
        { k: 'trial', l: 'Trial' }, { k: 'trait', l: 'Trait' }, { k: 'design', l: 'Design' }, { k: 'n', l: 'n', f: v => v },
        { k: 'mean', l: 'Mean' }, { k: 'cv', l: 'CV %', f: v => fmt(v, 1) }, { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) },
        { k: 'model', l: 'Model', f: v => '<code style="font-size:11px">' + esc(v) + '</code>' }, { k: 'message', l: 'Status', f: v => v === 'OK' ? '' : '<small>' + esc(v) + '</small>' }
    ], { id: 'sf_dt_stage1' }));
    dataTable('#sf_dt_stage1');

    // stage 2 / model
    $('#sf_tab_model').html(simpleTable(res.stage2, [
        { k: 'trait', l: 'Trait' }, { k: 'model', l: 'Model', f: v => '<code style="font-size:11px">' + esc(v) + '</code>' },
        { k: 'var_g', l: '&sigma;&sup2;<sub>G</sub>' }, { k: 'var_ge', l: '&sigma;&sup2;<sub>GE</sub>' }, { k: 'var_e', l: '&sigma;&sup2;<sub>e</sub>' },
        { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) }, { k: 'message', l: 'Status', f: (v, r) => esc(v) + (r.dropped_terms ? '<br/><small class="sf-muted" title="Terms the data could not support">left out: ' + esc(r.dropped_terms) + '</small>' : '') }
    ]) + '<p class="sf-help">Heritability is computed on an entry-mean basis (Cullis-type approximations using the harmonic mean number of replicates and environments).</p>');

    // genotype values
    const gv = arr(res.genotype_values);
    const pedCols = gv.length ? ['mother', 'father'].filter(k => k in gv[0]) : [];
    const traitCols = gv.length ? Object.keys(gv[0]).filter(k => k !== 'accession' && pedCols.indexOf(k) < 0) : [];
    $('#sf_tab_values').html('<p class="sf-help">' + label + 's of each accession for each trait.</p>' + simpleTable(gv,
        [{ k: 'accession', l: 'Accession', f: v => '<a href="/stock/' + encodeURIComponent(v) + '/view" target="_blank">' + esc(v) + '</a>' }]
            .concat(pedCols.map(k => ({ k: k, l: k === 'mother' ? 'Mother' : 'Father', f: v => v ? esc(v) : '<span class="sf-muted">&ndash;</span>' })))
            .concat(traitCols.map(t => ({ k: t, l: esc(t) }))),
        { id: 'sf_dt_values' }));
    dataTable('#sf_dt_values');

    // index
    $('#sf_tab_index_li').toggle(!!res.index);
    if (res.index) renderIndexResults(res.index, label);
    // zones
    $('#sf_tab_zones_li').toggle(arr(res.zones).length > 0);
    if (arr(res.zones).length) renderZoneResults(arr(res.zones));

    $('#sf_result_tabs a[href="#sf_tab_overview"]').tab('show');
    $('html, body').animate({ scrollTop: $('#sf_results').offset().top - 70 }, 300);
}

function h2Badge(v) {
    if (v === null || v === undefined || !isFinite(Number(v))) return '&ndash;';
    const x = Number(v);
    const c = x >= 0.6 ? '#2b7a4b' : x >= 0.3 ? '#d97706' : '#dc2626';
    return '<span style="display:inline-block;min-width:44px;padding:1px 6px;border-radius:10px;color:#fff;background:' + c + ';text-align:center">' + x.toFixed(2) + '</span>';
}

function renderIndexResults(ix, label) {
    const table = arr(ix.table);
    const traitCols = table.length ? Object.keys(table[0]).filter(k => ['accession', 'index', 'rank', 'selected'].indexOf(k) < 0) : [];
    let h = '<div class="sf-stats">' +
        '<div class="sf-stat"><div class="v">' + ix.n_selected + ' / ' + ix.n_ranked + '</div><div class="l">Selected accessions</div></div>' +
        '<div class="sf-stat"><div class="v">' + ix.selection_pct + '%</div><div class="l">Selection intensity</div></div>' +
        '<div class="sf-stat"><div class="v">' + (ix.method === 'rank_sum' ? 'Rank sum' : 'Z-score') + '</div><div class="l">Method</div></div></div>';
    h += '<h4>Expected response to selection</h4>' + simpleTable(ix.gains, [
        { k: 'trait', l: 'Trait' }, { k: 'in_index', l: 'In index', f: v => v ? '<span class="glyphicon glyphicon-ok" style="color:#2b7a4b"></span>' : '' },
        { k: 'weight', l: 'Weight', f: (v, r) => r.in_index ? fmt(v, 2) + (r.direction === 'decrease' ? ' &darr;' : ' &uarr;') : '' },
        { k: 'mean_population', l: 'Population mean' }, { k: 'mean_selected', l: 'Selected mean' },
        { k: 'selection_differential', l: 'Selection differential' },
        { k: 'selection_differential_pct', l: 'S %', f: v => '<b style="color:' + (Number(v) >= 0 ? '#2b7a4b' : '#dc2626') + '">' + fmt(v, 1) + '%</b>' },
        { k: 'expected_gain', l: 'Expected gain' }
    ]) + '<p class="sf-help">' + esc(ix.note) + '</p>';
    h += '<h4>Top accessions</h4><div id="sf_index_chart" class="sf-plot"></div>';
    h += '<h4>Ranking</h4>' + simpleTable(table, [
        { k: 'rank', l: 'Rank', f: v => v }, { k: 'accession', l: 'Accession', f: v => '<a href="/stock/' + encodeURIComponent(v) + '/view" target="_blank">' + esc(v) + '</a>' },
        { k: 'index', l: 'Index' }].concat(traitCols.map(t => ({ k: t, l: esc(t) + ' (' + label + ')' })))
        .concat([{ k: 'selected', l: 'Selected', f: v => v ? '<span class="label label-success">selected</span>' : '' }]),
        { id: 'sf_dt_index', rowClass: r => r.selected ? 'sf-selected' : '' });
    $('#sf_tab_index').html(h);
    dataTable('#sf_dt_index', { order: [[0, 'asc']] });
    drawIndexChart(table.slice(0, Math.min(30, Math.max(ix.n_selected, 15))));
}

function drawIndexChart(rows) {
    const box = document.getElementById('sf_index_chart');
    if (!box || !rows.length) return;
    const vals = rows.map(r => Number(r.index));
    const mn = Math.min(0, Math.min.apply(null, vals)), mx = Math.max(0, Math.max.apply(null, vals));
    const M = { l: 170, r: 60, t: 6, b: 6 }, bh = 18, W = 760, H = M.t + M.b + rows.length * bh;
    const xs = v => M.l + (W - M.l - M.r) * (v - mn) / ((mx - mn) || 1);
    const svg = svgEl('svg', { width: W, height: H, viewBox: '0 0 ' + W + ' ' + H, 'font-family': 'sans-serif', 'font-size': 11 }, box);
    svgEl('line', { x1: xs(0), x2: xs(0), y1: M.t, y2: H - M.b, stroke: '#94a3b8' }, svg);
    rows.forEach((r, i) => {
        const y = M.t + i * bh;
        const v = Number(r.index);
        svgEl('rect', { x: Math.min(xs(0), xs(v)), y: y + 3, width: Math.max(1, Math.abs(xs(v) - xs(0))), height: bh - 6, rx: 2, fill: r.selected ? '#2b7a4b' : '#9cc9ac' }, svg);
        const t = svgEl('text', { x: M.l - 8, y: y + bh / 2 + 4, 'text-anchor': 'end', fill: '#111' }, svg);
        t.textContent = r.rank + '. ' + (r.accession.length > 24 ? r.accession.slice(0, 23) + '…' : r.accession);
        const tv = svgEl('text', { x: Math.max(xs(0), xs(v)) + 4, y: y + bh / 2 + 4, fill: '#6b7280' }, svg);
        tv.textContent = v.toFixed(2);
    });
}

function corColor(r) {
    if (r === null || r === undefined || !isFinite(r)) return '#f3f4f6';
    const a = Math.min(1, Math.abs(r));
    return r >= 0 ? 'rgba(43,122,75,' + (0.1 + 0.85 * a) + ')' : 'rgba(217,119,6,' + (0.1 + 0.85 * a) + ')';
}

function renderZoneResults(zones) {
    let h = '';
    if (zones.length > 1) {
        h += '<ul class="nav nav-pills" style="margin-bottom:12px">' + zones.map((z, i) => '<li' + (i === 0 ? ' class="active"' : '') + '><a data-toggle="pill" href="#sf_zone_' + i + '">' + esc(z.target) + '</a></li>').join('') + '</ul>';
    }
    h += '<div class="tab-content">';
    zones.forEach((z, i) => {
        const zoneNames = [];
        arr(z.membership).forEach(m => { if (zoneNames.indexOf(m.zone) < 0) zoneNames.push(m.zone); });
        const color = zn => ZONE_COLORS[(zoneNames.indexOf(zn)) % ZONE_COLORS.length];
        h += '<div class="tab-pane' + (i === 0 ? ' active' : '') + '" id="sf_zone_' + i + '">';
        h += '<p><b>' + esc(z.target) + '</b>: <b>' + z.n_zones + '</b> zone(s) using ' + (z.method === 'lin' ? 'the Lin (1982) G&times;E test' : 'genetic correlation clustering') + '.</p>';

        h += '<div class="row">';
        zoneNames.forEach(zn => {
            const envs = arr(z.membership).filter(m => m.zone === zn);
            const top = arr(z.top).filter(t => t.zone === zn);
            h += '<div class="col-md-6"><div class="sf-card" style="border-top:4px solid ' + color(zn) + '">' +
                '<h4 style="margin-top:0"><span class="sf-zone-chip" style="background:' + color(zn) + '">' + esc(zn) + '</span> ' + envs.length + ' environment(s)</h4>' +
                '<p class="sf-help">' + envs.map(e => esc(e.env) + (e.location && e.location !== e.env ? ' <small>(' + esc(e.location) + ')</small>' : '')).join(', ') + '</p>' +
                simpleTable(top, [{ k: 'rank', l: '#', f: v => v }, { k: 'accession', l: 'Best accessions' }, { k: 'value', l: 'Mean' }, { k: 'n_env', l: 'Envs', f: v => v }], { empty: 'No accession tested in all environments of this zone.' }) +
                '</div></div>';
        });
        h += '</div>';

        if (z.correlation && arr(z.correlation.environments).length) {
            const envs = arr(z.correlation.environments);
            const mat = arr(z.correlation.matrix);
            const zoneOf = {};
            arr(z.membership).forEach(m => { zoneOf[m.env] = m.zone; });
            h += '<h4>Genetic correlation between environments</h4><div class="table-responsive"><table class="table table-bordered sf-heat"><thead><tr><th></th>' +
                envs.map(e => '<th title="' + esc(e) + '" style="border-bottom:3px solid ' + color(zoneOf[e]) + '">' + esc(e.length > 12 ? e.slice(0, 11) + '…' : e) + '</th>').join('') + '</tr></thead><tbody>';
            envs.forEach((e, a) => {
                const row = arr(mat[a]);
                h += '<tr><th style="text-align:left;border-left:3px solid ' + color(zoneOf[e]) + '">' + esc(e) + '</th>' +
                    envs.map((e2, b) => { const v = row[b]; return '<td style="background:' + corColor(v) + ';color:' + (v !== null && Math.abs(v) > 0.55 ? '#fff' : '#111') + '">' + (v === null || v === undefined ? '' : Number(v).toFixed(2)) + '</td>'; }).join('') + '</tr>';
            });
            h += '</tbody></table></div>';
        }
        if (arr(z.pairwise).length) {
            h += '<h4>Pairwise G&times;E tests</h4>' + simpleTable(z.pairwise, [
                { k: 'env1', l: 'Environment 1' }, { k: 'env2', l: 'Environment 2' }, { k: 'n_genotypes', l: 'Common accessions', f: v => v },
                { k: 'f', l: 'F' }, { k: 'p_value', l: 'p', f: v => fmt(v, 4) },
                { k: 'compatible', l: 'Same zone?', f: v => v ? '<span class="glyphicon glyphicon-ok" style="color:#2b7a4b"></span>' : '<span class="glyphicon glyphicon-remove" style="color:#dc2626"></span>' }
            ]);
        }
        h += '</div>';
    });
    h += '</div>';
    $('#sf_tab_zones').html(h);
}

// ---------------------------------------------------------------------------
// store analysis / list
// ---------------------------------------------------------------------------

// Store the analysis: shared form (modules/script_factory_store.js)
function openStoreAnalysis() {
    const res = state.results;
    if (!res || !res.store) { alert('There are no genotype values to store.'); return; }
    const recipe = state.resultsRecipe || buildRecipe();
    openStoreDialog({
        runId: res.run_id,
        res: res,
        ctx: { scriptName: state.script.name, datasetName: state.dataset && state.dataset.dataset_name, outlierMethod: recipe.outliers && recipe.outliers.method },
        programs: arr(state.dataset && state.dataset.programs),
        onStored: (id, name) => showStored(id, name)
    });
}

function showStored(id, name) {
    $('#sf_store_result').html(storedNotice(id, name));
    $('#sf_save_analysis').prop('disabled', true).html('<span class="glyphicon glyphicon-ok"></span> Stored');
}

function openSaveList() {
    const ix = state.results && state.results.index;
    if (!ix) return;
    const sel = arr(ix.table).filter(r => r.selected).map(r => r.accession);
    const d = new Date();
    $('#sf_list_name').val('Selected ' + (state.dataset.dataset_name || 'accessions') + ' ' + d.toISOString().slice(0, 10));
    $('#sf_list_info').text(sel.length + ' accession(s): the top ' + ix.selection_pct + '% of the selection index.');
    $('#sf_list_modal').data('items', sel).modal('show');
}

function createList() {
    const name = $('#sf_list_name').val().trim();
    const items = $('#sf_list_modal').data('items') || [];
    if (!name) { alert('Please enter a list name.'); return; }
    if (typeof CXGN === 'undefined' || !CXGN.List) { alert('The list tools are not available on this page.'); return; }
    const lo = new CXGN.List();
    const id = lo.newList(name, 'Selected with the Analysis Pipeline');
    if (!id) return;   // newList already alerts when the name exists
    lo.addBulk(id, items);
    lo.setListType(id, 'accessions');
    $('#sf_list_modal').modal('hide');
    alert('List "' + name + '" created with ' + items.length + ' accessions.');
}

// ---------------------------------------------------------------------------
// saved scripts
// ---------------------------------------------------------------------------

function openLibrary() {
    $('#sf_library_modal').modal('show');
    $('#sf_library_list').html('<p class="sf-help"><span class="glyphicon glyphicon-refresh sf-spin"></span> Loading...</p>');
    post('/ajax/script_factory/recipes', {})
        .then(r => {
            const list = arr(r.recipes);
            if (!list.length) { $('#sf_library_list').html('<p class="sf-muted">You have no saved scripts yet. Build a pipeline and click <b>Save script</b>.</p>'); return; }
            $('#sf_library_list').html(simpleTable(list, [
                { k: 'name', l: 'Name', f: (v, x) => '<b>' + esc(v) + '</b>' + (x.description ? '<br/><small class="sf-muted">' + esc(x.description) + '</small>' : '') },
                { k: 'strategy', l: 'Steps', f: (v, x) => '<small>' + (v === 'single_stage' ? 'single stage' : 'two stages') + ', ' + x.n_traits + ' trait(s)' + (x.index ? ', index' : '') + (x.zones ? ', zones' : '') + '</small>' },
                { k: 'owner', l: 'Owner', f: (v, x) => esc(v) + (x.is_public ? ' <span class="label label-info">shared</span>' : '') },
                { k: 'modified', l: 'Modified' },
                { k: 'recipe_id', l: '', f: (v, x) => '<span style="white-space:nowrap">' + (state.dataset ? '<button class="btn btn-success btn-xs sf-lib-run" data-id="' + v + '" title="Apply to ' + esc(state.dataset.dataset_name) + ' and run every step"><span class="glyphicon glyphicon-play"></span> Load &amp; run</button> ' : '') +
                    '<button class="btn btn-primary btn-xs sf-lib-load" data-id="' + v + '">Load</button> ' + (x.is_owner ? '<button class="btn btn-default btn-xs sf-lib-delete" data-id="' + v + '" data-name="' + esc(x.name) + '"><span class="glyphicon glyphicon-trash"></span></button>' : '') + '</span>' }
            ]));
        })
        .catch(e => $('#sf_library_list').html(alertBox('warning', esc(e.message))));
}

// Show the pipeline of a stored analysis or of a run: its recipe is applied to
// every step and its dataset is loaded (see init).
function openPipeline(p) {
    state.script = { id: null, name: p.name ? 'Pipeline of ' + p.name : 'Pipeline of a previous run', description: p.description || '', is_public: 0, is_owner: 1 };
    state.scriptLoaded = true;
    applyRecipe(p.recipe);
    setScriptName();
    const links = [
        p.results_url ? '<a href="' + esc(p.results_url) + '"><span class="glyphicon glyphicon-stats"></span> Results dashboard</a>' : '',
        p.analysis_id ? '<a href="/analyses/' + encodeURIComponent(p.analysis_id) + '"><span class="glyphicon glyphicon-list-alt"></span> Stored analysis</a>' : ''
    ].filter(Boolean).join(' &nbsp;&middot;&nbsp; ');
    $('#sf_pipeline_banner').html(alertBox('info', '<span class="glyphicon glyphicon-random"></span> This is the pipeline of ' +
        (p.source === 'analysis' ? 'the stored analysis <b>' + esc(p.name) + '</b>' : 'a previous run') +
        ': every step below shows the settings that were used. Load the dataset to see each step, change anything and run again; save it as a script to reuse it.' +
        (links ? '<br/>' + links : '')));
    goTo(1);
    return p;
}

function loadScript(id, andRun) {
    return post('/ajax/script_factory/recipe/get', { recipe_id: id })
        .then(r => {
            state.script = { id: r.is_owner ? r.recipe_id : null, name: r.name, description: r.description, is_public: r.is_public, is_owner: r.is_owner };
            state.scriptLoaded = true;
            applyRecipe(r.recipe);
            setScriptName();
            $('#sf_library_modal').modal('hide');
            if (!state.dataset) {
                $('#sf_dataset_message').html(alertBox('success', 'Script <b>' + esc(r.name) + '</b> loaded. Choose a dataset and click <b>Load dataset</b>: you can then run the whole script in one click.'));
                goTo(1);
            } else {
                $('#sf_dataset_message').html('');
                renderQuickRun();
                if (andRun) quickRun(true); else goTo(1);
            }
        })
        .catch(e => alert(e.message));
}

function saveScript(asNew) {
    const name = $('#sf_save_name').val().trim();
    if (!name) { alert('Please give the script a name.'); return; }
    state.script.name = name;
    const data = {
        name: name,
        description: $('#sf_save_description').val(),
        is_public: $('#sf_save_public').is(':checked') ? 1 : 0,
        recipe: JSON.stringify(buildRecipe())
    };
    if (!asNew && state.script.id && state.script.is_owner) data.recipe_id = state.script.id;
    post('/ajax/script_factory/recipe/save', data)
        .then(r => {
            state.script = { id: r.recipe_id, name: name, description: data.description, is_public: data.is_public, is_owner: 1 };
            setScriptName();
            $('#sf_save_modal').modal('hide');
        })
        .catch(e => alert(e.message));
}

function exportR() {
    const name = state.script.name || 'script_factory_analysis';
    post('/ajax/script_factory/export_r', { recipe: JSON.stringify(buildRecipe()), name: name })
        .then(r => download(r.filename, r.script, 'text/x-r'))
        .catch(e => alert(e.message));
}

function exportJSON() {
    const name = state.script.name || 'script_factory_analysis';
    const obj = { script_factory: VERSION, name: name, description: state.script.description || '', recipe: buildRecipe() };
    download(name.replace(/[^A-Za-z0-9_-]+/g, '_') + '.json', JSON.stringify(obj, null, 2), 'application/json');
}

function importJSON(file) {
    const reader = new FileReader();
    reader.onload = () => {
        try {
            const obj = JSON.parse(reader.result);
            const recipe = obj.recipe || obj;
            if (!recipe.strategy && !recipe.traits) throw new Error('This file is not an Analysis Pipeline script.');
            state.script = { id: null, name: obj.name || recipe.name || file.name.replace(/\.json$/, ''), description: obj.description || '', is_public: 0, is_owner: 1 };
            state.scriptLoaded = true;
            applyRecipe(recipe);
            setScriptName();
            renderQuickRun();
            $('#sf_library_modal').modal('hide');
            goTo(1);
        } catch (e) {
            alert('Could not read the script: ' + e.message);
        }
    };
    reader.readAsText(file);
}

function newScript() {
    if (!confirm('Start a new script? Your current settings will be reset (the loaded dataset is kept).')) return;
    state.script = { id: null, name: null, description: '', is_public: 0, is_owner: 1 };
    state.scriptLoaded = false;
    state.missingTraits = [];
    $('#sf_pipeline_banner').html('');
    $('#sf_recipe_trait_warning').html('');
    renderQuickRun();
    state.exclusions = {};
    state.madrFlags = {};
    state.designOverrides = {};
    state.indexCfg = {};
    state.zoneTargets = { index: true };
    applyRecipe({ strategy: 'two_stage', engine: 'lme4', genetic: { model: 'iid', check: 'auto' }, outliers: { method: 'none', group_by: 'trial', k: 1.5, alpha: 0.05 }, stage1: { model: 'auto' }, stage2: { genotype: 'random', weighting: 'inverse_se2' }, single: { mode: 'builder', genotype: 'random', env: 'fixed', rep: 'auto', block: 'auto', rowcol: 'auto', trend: 'none', gxe: ['trial'], covariates: [], formula: '' }, index: { enabled: false, method: 'zscore', selection_pct: 10 }, zones: { enabled: false, unit: 'trial', method: 'correlation', threshold: 0.5, alpha: 0.05, top_n: 10, targets: ['index'] } });
    if (state.dataset) { state.traits = state.dataset.traits.map(t => t.name); renderTraits(); }
    renderExclusions();
    setScriptName();
    refreshAll();
    goTo(1);
}

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

export function init(options) {
    $ = window.jQuery;
    cfg = options || {};


    // pipeline of a stored analysis or of a run (Manage > Analyses, job list, dashboard)
    const pipelineP = (cfg.analysis_id || cfg.run_id)
        ? post('/ajax/script_factory/pipeline', cfg.analysis_id ? { analysis_id: cfg.analysis_id } : { run_id: cfg.run_id })
            .then(openPipeline)
            .catch(e => { $('#sf_dataset_message').html(alertBox('danger', esc(e.message))); return null; })
        : Promise.resolve(null);

    get_select_box('datasets', 'sf_dataset_select', {
        checkbox_name: 'sf_dataset_checkbox',
        after_load: () => pipelineP.then(p => {
            const id = (p && p.dataset_id) || cfg.dataset_id;
            if (!id) return;
            const box = $('input[name=sf_dataset_checkbox][value=' + id + ']');
            if (!box.length) {
                if (p) $('#sf_dataset_message').append(alertBox('warning', 'The dataset of this analysis is not in your list of datasets (it may be private or deleted). Choose a dataset to run the pipeline on.'));
                return;
            }
            box.prop('checked', true);
            loadDataset();
        })
    });

    // navigation
    $(document).on('click', '.sf-next', function() { goTo($(this).data('goto')); });
    $('#sf_stepper').on('click', 'li', function() { goTo($(this).data('step')); });

    // step 1
    $('#sf_load_dataset').on('click', loadDataset);
    // ticking a dataset loads it (one dataset at a time)
    $('#sf_dataset_select').on('change', 'input[name=sf_dataset_checkbox]', function() {
        if (!$(this).is(':checked')) return;
        $('input[name=sf_dataset_checkbox]').not(this).prop('checked', false);
        loadDataset();
    });
    $('#sf_traits').on('change', '.sf-trait-cb', onTraitsChanged);
    $('#sf_treatments').on('change', 'input', onTreatmentsChanged);
    $('#sf_traits_all').on('click', () => { $('.sf-trait-cb').prop('checked', true); onTraitsChanged(); });
    $('#sf_traits_none').on('click', () => { $('.sf-trait-cb').prop('checked', false); onTraitsChanged(); });

    // generic option cards
    $(document).on('change', '.sf-app input[type=radio], .sf-app input[type=checkbox], .sf-app select, .sf-app input[type=number]', () => {
        refreshOptionCards();
        refreshToggles();
        renderPipeline();
        renderQuickRun();
    });

    // step 2
    $('input[name=sf_outlier_method], #sf_iqr_k, #sf_iqr_group').on('change', () => { if (state.plotData) drawExplorer(); });
    $('#sf_explorer_trait').on('change', drawExplorer);
    $('#sf_preview_madr').on('click', previewMadr);
    $('#sf_madr_alpha').on('change', () => { state.madrFlags = {}; state.madrPreviewDone = false; if (state.plotData) drawExplorer(); });
    // values marked in Breedbase: use them all again / exclude them all
    $('#sf_outlier_breakdown').on('click', '.sf-marked-toggle', function() {
        excludeMarked(String($(this).data('on')) === '1');
        drawExplorer(); renderPipeline();
    });
    $('#sf_outlier_table').on('click', '.sf-restore', function() {
        delete state.exclusions[$(this).data('key')];
        drawExplorer(); renderPipeline();
    });
    $('#sf_outlier_filter').on('change', renderExclusions);
    $('#sf_outlier_table').on('change', '.sf-outlier-cb', function() {
        const k = $(this).data('key');
        if ($(this).is(':checked')) state.outlierSel[k] = true; else delete state.outlierSel[k];
        $(this).closest('tr').toggleClass('sel', $(this).is(':checked'));
        updateOutlierToolbar();
    });
    $('#sf_outlier_table').on('change', '#sf_outlier_all', function() {
        const on = $(this).is(':checked');
        $('#sf_outlier_table .sf-outlier-cb').each(function() {
            const k = $(this).data('key');
            if (on) state.outlierSel[k] = true; else delete state.outlierSel[k];
            $(this).prop('checked', on).closest('tr').toggleClass('sel', on);
        });
        updateOutlierToolbar();
    });
    $(document).on('click', '.sf-outlier-toolbar .sf-mark', function(e) {
        e.preventDefault();
        if ($(this).prop('disabled') || $(this).closest('li').hasClass('disabled')) return;
        markOutliers(outlierTargets(), $(this).data('action'), '#sf_outlier_message');
    });
    // results tab: mark everything the run removed
    $('#sf_warnings').on('click', '.sf-open-log', function(e) { e.preventDefault(); $('#sf_result_tabs a[href="#sf_tab_log"]').tab('show'); });
    $('#sf_tab_outliers').on('click', '.sf-mark-removed', function() {
        const full = {};
        arr((state.results.summary || {}).traits_full).forEach(t => { full[shortTrait(t)] = t; });
        const items = arr(state.results.outliers).filter(o => full[o.trait]).map(o => ({ key: o.unit + '|' + full[o.trait], unit: o.unit, trait: full[o.trait] }));
        markOutliers(items, $(this).data('action'), '#sf_removed_message');
    });

    // step 3
    $('input[name=sf_strategy], input[name=sf_stage1_model], #sf_stage2_genotype, #sf_stage2_weighting, input[name=sf_engine], #sf_gen_model, #sf_check').on('change', () => { renderDesignTable(); renderModelPreview(); });
    $('#sf_apply_suggestion').on('click', e => { e.preventDefault(); applySuggestion(); });
    if (cfg.user_email) {
        $('#sf_notify_to').text('at ' + cfg.user_email);
    } else {
        $('#sf_notify').prop({ checked: false, disabled: true });
        $('#sf_notify_help').html('Your account has no email address. Add one to your user profile to be notified when an analysis finishes.');
    }
    if (!cfg.blupf90_available) {
        $('#sf_engine_f90').addClass('disabled').find('input').prop('disabled', true);
        $('#sf_engine_note').html('<small class="sf-muted">BLUPF90+ is not installed on this server (ask the site administrator to install blupf90+ or set <code>blupf90_bin_dir</code>).</small>');
    }
    $('#sf_single_card').on('change', '.sf-single-opt, .sf-single-gxe, input[name=sf_single_mode]', renderModelPreview);
    $('#sf_single_card').on('click', '.sf-mode-toggle label', function(e) {
        // plain handling of the two-button toggle (keeps radio, label and preview in sync)
        e.preventDefault();
        setRadio('sf_single_mode', $(this).find('input').val());
        if (radio('sf_single_mode') === 'custom' && !$.trim($('#sf_single_formula').val())) $('#sf_single_formula').val(singleBuilderFormula().terms.join(' + '));
        $('input[name=sf_single_mode]').trigger('change');
    });
    $('#sf_single_formula').on('input', () => { renderModelPreview(); renderPipeline(); });
    $('#sf_single_from_builder').on('click', e => {
        e.preventDefault();
        $('#sf_single_formula').val(singleBuilderFormula().terms.join(' + ')).trigger('input');
    });
    $('#sf_single_vars').on('click', '.sf-var', function() {
        const ta = $('#sf_single_formula')[0];
        const v = String($(this).data('v'));
        const a = ta.selectionStart || ta.value.length, b = ta.selectionEnd || ta.value.length;
        ta.value = ta.value.slice(0, a) + v + ta.value.slice(b);
        ta.focus(); ta.selectionStart = ta.selectionEnd = a + v.length;
        $(ta).trigger('input');
    });
    $('#sf_single_covariates').on('change', 'input', function() {
        const t = $(this).val();
        if ($(this).is(':checked')) state.singleCov[t] = true; else delete state.singleCov[t];
        renderSingleCovariates();
        renderModelPreview();
    });
    $('#sf_design_table').on('change', '.sf-design-override', function() {
        state.designOverrides[$(this).data('trial')] = $(this).val();
        renderDesignTable(); renderModelPreview();
    });

    // step 4
    $('#sf_index_traits').on('input change', '.sf-index-weight', function() {
        const t = $(this).data('trait');
        (state.indexCfg[t] = state.indexCfg[t] || { direction: 'increase' }).weight = Number($(this).val()) || 0;
        renderIndexFormula(); renderPipeline();
    });
    $('#sf_index_traits').on('click', '.sf-index-dir', function() {
        const t = $(this).closest('.btn-group').data('trait');
        (state.indexCfg[t] = state.indexCfg[t] || { weight: 0 }).direction = $(this).data('dir');
        renderIndexTable(); renderPipeline();
    });
    $('input[name=sf_index_method]').on('change', renderIndexFormula);
    $('#sf_selection_pct').on('input change', function() { $('#sf_selection_pct_label').text($(this).val()); renderIndexFormula(); renderPipeline(); });
    $('#sf_index_enabled').on('change', () => {
        // a sensible start: equal weights on all traits when nothing was set
        if ($('#sf_index_enabled').is(':checked') && !state.traits.some(t => Number((state.indexCfg[t] || {}).weight) !== 0)) {
            state.traits.forEach(t => { state.indexCfg[t] = Object.assign({ direction: 'increase' }, state.indexCfg[t], { weight: 1 }); });
            renderIndexTable();
        }
    });

    // step 5
    $('#sf_zones_targets').on('change', '.sf-zone-target', function() {
        state.zoneTargets[$(this).val()] = $(this).is(':checked');
        $(this).closest('.sf-trait').toggleClass('on', $(this).is(':checked'));
        renderPipeline();
    });

    // step 6
    $('#sf_run').on('click', runAnalysis);
    $('#sf_save_analysis').on('click', openStoreAnalysis);
    // the trait explorer fills the card width: redraw it when the window is resized
    let resizeTimer = null;
    $(window).on('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => { if ($('#sf_explorer_plot').is(':visible')) drawExplorer(); }, 200);
    });
    $('#sf_save_list').on('click', openSaveList);
    $('#sf_list_submit').on('click', createList);
    $('#sf_export_r').on('click', e => { e.preventDefault(); exportR(); });
    $('#sf_export_json').on('click', e => { e.preventDefault(); exportJSON(); });

    // scripts
    $('#sf_new_script').on('click', newScript);
    $('#sf_open_library').on('click', openLibrary);
    $('#sf_library_list').on('click', '.sf-lib-load', function() { loadScript($(this).data('id'), false); });
    $('#sf_library_list').on('click', '.sf-lib-run', function() { loadScript($(this).data('id'), true); });
    $('#sf_quick_run_btn').on('click', () => quickRun(false));
    $('#sf_run_again').on('click', runAnalysis);
    $('#sf_quick_review').on('click', () => goTo(2));
    $('#sf_library_list').on('click', '.sf-lib-delete', function() {
        if (!confirm('Delete the script "' + $(this).data('name') + '"?')) return;
        post('/ajax/script_factory/recipe/delete', { recipe_id: $(this).data('id') })
            .then(() => {
                if (state.script.id === $(this).data('id')) { state.script.id = null; setScriptName(); }
                openLibrary();
            })
            .catch(e => alert(e.message));
    });
    $('#sf_import_json').on('change', function() { if (this.files && this.files[0]) importJSON(this.files[0]); this.value = ''; });
    $('#sf_open_save_script').on('click', () => {
        $('#sf_save_name').val(state.script.name || '');
        $('#sf_save_description').val(state.script.description || '');
        $('#sf_save_public').prop('checked', !!state.script.is_public);
        $('#sf_save_update').text(state.script.id && state.script.is_owner ? 'Save changes' : 'Save');
        $('#sf_save_as_new').toggle(!!(state.script.id && state.script.is_owner));
        $('#sf_save_modal').modal('show');
    });
    $('#sf_save_update').on('click', () => saveScript(false));
    $('#sf_save_as_new').on('click', () => saveScript(true));

    window.addEventListener('beforeunload', () => { if (state.pollTimer) clearTimeout(state.pollTimer); });

    refreshAll();
    setScriptName();
    if (cfg.recipe_id) loadScript(cfg.recipe_id);
}
