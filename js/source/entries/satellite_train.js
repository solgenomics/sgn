/**
 * Train a yield model (/breeders/satellite/train), apart from the analysis of an area
 * (/breeders/satellite). The trained model is saved as a Breedbase analysis model and then
 * chosen in any analysis ("Use a trained model").
 *
 * Training data (they can be combined):
 *  - regional public statistics (IBGE PAM, Brazil): the yield of each municipality, year and
 *    crop season (maize: 1st crop = summer, 2nd crop = safrinha, table 839); the run finds the
 *    crop in a few squares inside each municipality with the stored maize curve and learns
 *    the municipality's yield from the season curve of that maize;
 *  - a Breedbase dataset of trials with the trait to train on: each trial's field comes from
 *    its plot coordinates or a field drawn for it; a trial without them is placed by its
 *    location's coordinates (often the town's: warned, checked by the run, and how to fix it).
 * Steps: 1 training data, 2 settings, 3 train and validate (background job, log, email,
 * models compared, observed vs predicted, save the model).
 */

const API = '/ajax/satellite';
const esc = s => String(s ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
const fmt = (v, d = 1) => (v === null || v === undefined || !isFinite(v) ? '–' : Number(v).toLocaleString(undefined, { maximumFractionDigits: d, minimumFractionDigits: d }));
const traitName = n => String(n || '').replace(/\|[^|]*$/, '');
const COMMON = { 'Zea mays': 'Maize', 'Nicotiana tabacum': 'Tobacco', 'Glycine max': 'Soybean', 'Manihot esculenta': 'Cassava', 'Oryza sativa': 'Rice', 'Triticum aestivum': 'Wheat', 'Sorghum bicolor': 'Sorghum' };
const SEASONS = { summer: 'Summer (1st crop)', safrinha: 'Safrinha (2nd crop)', year: 'Whole year' };
const MODEL_LABELS = { auto: 'Automatic (compare and choose)', linear1: 'Linear (NDVI area only)', linear: 'Linear regression', ridge: 'Ridge regression', pls: 'PLS (1 component)',
    elastic_net: 'Elastic net', lasso: 'Lasso', gam: 'GAM (smooth)', mixed: 'Mixed model (location-year effect)', mars: 'MARS', random_forest: 'Random forest', svm: 'SVM regression' };
const PREDICTOR_NAMES = { ndvi_auc: 'NDVI area under the season curve', ndvi_max: 'NDVI peak', ndre_max: 'NDRE (red-edge) peak', peak_day: 'Day of the NDVI peak' };
// setting: [ label, default, min, max, step, help ]
const SETTINGS = {
    samples_per_region: ['Sample squares per municipality', 3, 1, 10, 1, 'Where the maize of each municipality is looked for. More squares: closer to the municipality\'s average, longer run.'],
    sample_size_m: ['Sample square size (m)', 2000, 500, 5000, 100, 'Side of each square.'],
    min_crop_ha: ['Least maize found (ha)', 2, 0.5, 100, 0.5, 'A municipality-season with less maize in its squares is left out.'],
    location_field_m: ['Square at a location point (m)', 200, 50, 1000, 10, 'A trial with no field of its own is placed by a square of this size around its location\'s coordinates.'],
    location_min_peak: ['Crop at a location point: NDVI peak at least', 0.6, 0.3, 0.9, 0.05, 'Below it, the location\'s coordinates are taken as not on a field (town, water) and the trial is left out.'],
    season_days: ['Trial season without harvest date (days)', 150, 60, 365, 5, 'Planting date + this many days, when a trial has no harvest date.'],
    min_dates: ['Least clear dates in a season', 4, 1, 30, 1, ''],
    min_fields: ['Least items of known yield', 8, 5, 100, 1, 'Municipality-seasons and trials usable after the checks.'],
};

const T = {
    step: 1, crops: [], crop: '', useIbge: true, useDataset: false,
    states: [], ufs: new Set(), years: new Set(), regions: null, regionsKey: '', regionsLoading: false, regionsError: '', picked: new Set(), cropName: '',
    datasets: null, dsId: '', dsInfo: {}, dsTrait: '', outliers: '', settings: {}, model: 'auto', name: '',
    job: { runId: null, status: null }, runs: null,
};
const thisYear = new Date().getFullYear();
const YEARS = []; for (let y = thisYear - 1; y >= 2018; y--) YEARS.push(y);

async function getJSON(path, params) {
    const res = await fetch(`${API}/${path}?` + new URLSearchParams(params || {}).toString(), { credentials: 'same-origin', headers: { Accept: 'application/json' } });
    let data;
    try { data = await res.json(); } catch (e) { throw new Error(`The server answered ${res.status}`); }
    if (data.error) throw new Error(data.error);
    return data;
}

async function postJSON(path, params) {
    const res = await fetch(`${API}/${path}`, {
        method: 'POST', credentials: 'same-origin',
        headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(params || {}).toString(),
    });
    let data;
    try { data = await res.json(); } catch (e) { throw new Error(`The server answered ${res.status}`); }
    if (data.error) throw new Error(data.error);
    return data;
}

const isMaize = () => /^Zea mays\b/.test(T.crop);
const cropLabel = () => COMMON[T.crop] || T.crop || 'the crop';
const setting = k => (k in T.settings ? T.settings[k] : SETTINGS[k][1]);
const regionKey = r => `${r.mun_code}|${r.year}|${r.season}`;

/* ---------- steps ---------- */

function goStep(n) {
    T.step = n;
    $('.sat-pane').hide();
    $(`.sat-pane[data-step="${n}"]`).show();
    renderStepper();
    if (n === 3) renderReady();
    window.scrollTo(0, 0);
}

function renderStepper() {
    $('#tr_stepper li').each(function () {
        const n = +$(this).data('step');
        $(this).toggleClass('active', n === T.step).toggleClass('done', n < T.step || (n === 3 && T.job.status === 'done'));
    });
    $('#tr_badge').text(T.crop ? cropLabel() : 'no crop chosen');
}

/* ---------- 1 training data ---------- */

function renderCrops() {
    $('#tr_crop').html('<option value="">Choose the crop</option>' + T.crops.map(c => `<option value="${esc(c.species)}"${c.species === T.crop ? ' selected' : ''}>${esc(COMMON[c.species] ? `${COMMON[c.species]} (${c.species})` : c.species)}</option>`).join(''));
}

function renderSources() {
    if (!isMaize() && T.useIbge) T.useIbge = false;
    $('#tr_sources .sat-option').each(function () {
        const k = $(this).data('v');
        const on = k === 'ibge' ? T.useIbge : T.useDataset;
        const off = k === 'ibge' && !isMaize();
        $(this).toggleClass('on', on).toggleClass('disabled', off).find('input').prop('checked', on).prop('disabled', off);
    });
    $('#tr_ibge_text').html(isMaize()
        ? 'The yield of each municipality, year and crop season published by IBGE (PAM). The run finds the maize inside each municipality with the stored maize curve and learns the yield from its season curve. No trial needed.'
        : `Needs the crop's stored season curve to find it inside the municipalities: only maize has one${T.crop ? ` (not ${esc(cropLabel())})` : ''}.`);
    $('#tr_ibge_box').toggle(T.useIbge);
    $('#tr_ds_box').toggle(T.useDataset);
    if (T.useIbge) renderIbge();
    if (T.useDataset) renderDataset();
    renderStepper();
}

function renderIbge() {
    $('#tr_states').html(T.states.map(s => `<button type="button" class="sat-seg${T.ufs.has(s.code) ? ' on' : ''}" data-uf="${s.code}" title="${esc(s.name)}">${esc(s.uf)}</button>`).join(''));
    $('#tr_years').html(YEARS.map(y => `<button type="button" class="sat-seg${T.years.has(y) ? ' on' : ''}" data-year="${y}">${y}</button>`).join(''));
    const key = [[...T.ufs].sort().join(','), [...T.years].sort().join(','), T.crop].join('|');
    const stale = T.regions && T.regionsKey !== key;
    $('#tr_regions_load').prop('disabled', !T.ufs.size || !T.years.size || T.regionsLoading)
        .text(T.regionsLoading ? 'Reading IBGE…' : stale ? 'Show the municipalities again (changed)' : 'Show the municipalities');
    renderRegions();
}

async function loadRegions() {
    T.regionsLoading = true; T.regionsError = '';
    renderIbge();
    const key = [[...T.ufs].sort().join(','), [...T.years].sort().join(','), T.crop].join('|');
    try {
        const r = await getJSON('train_regions', { species: T.crop, ufs: [...T.ufs].join(','), years: [...T.years].join(',') });
        T.regions = r.rows; T.regionsKey = key; T.regionsMeta = r;
        const keep = new Set(T.regions.map(regionKey));
        T.picked = new Set([...T.picked].filter(k => keep.has(k)));
        if (!T.picked.size) T.regions.slice(0, 12).forEach(x => T.picked.add(regionKey(x)));
    } catch (err) { T.regionsError = err.message; }
    T.regionsLoading = false;
    renderIbge();
    renderReady();
}

function renderRegions() {
    const box = $('#tr_regions');
    if (T.regionsError) { box.html(`<div class="sat-small text-danger">${esc(T.regionsError)}</div>`); return; }
    if (!T.regions) { box.html('<div class="sat-small sat-muted">Choose states and years, then show their municipalities.</div>'); return; }
    if (!T.regions.length) { box.html(`<div class="sat-small sat-muted">IBGE has no ${esc(cropLabel())} yield for these states and years.</div>`); return; }
    const n = T.picked.size;
    const minutes = Math.round(n * setting('samples_per_region') * 1.6 * Math.pow(setting('sample_size_m') / 2000, 2));
    let h = `<div class="sat-inline-row" style="margin:6px 0"><span class="sat-small"><b>${n}</b> of ${T.regions.length} municipality-seasons chosen${n ? ` · about ${minutes < 60 ? `${minutes} min` : `${(minutes / 60).toFixed(1)} h`} of images to read` : ''}</span>`
        + '<span class="sat-segs">' + [[10, 'Top 10'], [20, 'Top 20'], [40, 'Top 40'], [0, 'None']].map(([k, l]) => `<button type="button" class="sat-seg tr-top" data-n="${k}">${l}</button>`).join('') + '</span></div>'
        + '<div class="sat-help">Sorted by how much of the municipality is planted with the crop: the maize of a municipality where it covers a large share is easy to find, and the published yield is mostly that maize.'
        + (T.regionsMeta && T.regionsMeta.seasons ? ' Maize is published per crop season (1st crop = summer, 2nd crop = safrinha), so each season is learnt with its own yield.' : '') + '</div>';
    h += '<div style="max-height:340px;overflow:auto;margin-top:6px"><table class="sat-mini-table"><thead><tr><th></th><th>Municipality</th><th>Season</th><th class="num">Year</th><th class="num">Planted ha</th><th class="num">Share of the area</th><th class="num">Yield kg/ha</th></tr></thead><tbody>'
        + T.regions.map(r => {
            const k = regionKey(r);
            return `<tr><td><input type="checkbox" class="tr-region" data-k="${esc(k)}"${T.picked.has(k) ? ' checked' : ''} aria-label="Use ${esc(r.name)} ${esc(r.season)} ${r.year}" /></td>`
                + `<td>${esc(r.name)}</td><td>${esc(SEASONS[r.season] || r.season)}</td><td class="num">${r.year}</td><td class="num">${fmt(r.planted_ha, 0)}</td>`
                + `<td class="num">${r.share !== null && r.share !== undefined ? `${fmt(100 * r.share, 1)}%` : ''}</td><td class="num">${fmt(r.yield, 0)}</td></tr>`;
        }).join('') + '</tbody></table></div>';
    if (T.regionsMeta) h += `<div class="sat-help" style="margin-top:4px">Source: <a href="${esc(T.regionsMeta.url)}" target="_blank" rel="noopener">${esc(T.regionsMeta.citation)}</a>. The yield is the municipality's average over all its fields of the crop.</div>`;
    box.html(h);
}

function renderDataset() {
    if (T.datasets === null) { T.datasets = []; getJSON('datasets').then(r => { T.datasets = r.datasets; renderDataset(); }).catch(() => {}); }
    const info = T.dsId ? T.dsInfo[T.dsId] : null;
    if (T.dsId && info === undefined) {
        T.dsInfo[T.dsId] = null;
        getJSON('dataset_info', { dataset_id: T.dsId, fields: 1 })
            .then(r => { T.dsInfo[T.dsId] = r; if (r.traits.length === 1) T.dsTrait = String(r.traits[0].id); renderDataset(); renderReady(); })
            .catch(err => { T.dsInfo[T.dsId] = { error: err.message }; renderDataset(); });
    }
    let h = '<div class="sat-inline-row" style="margin-top:0"><div><label class="sat-label" for="tr_ds" style="margin-top:0">Dataset</label>'
        + `<select id="tr_ds" class="form-control input-sm" style="min-width:300px"><option value="">Choose a dataset</option>`
        + (T.datasets || []).map(d => `<option value="${d.id}"${String(T.dsId) === String(d.id) ? ' selected' : ''}>${esc(d.name)}${d.mine ? '' : ` (${esc(d.owner || 'public')})`}</option>`).join('')
        + '</select></div><div class="sat-small" style="align-self:flex-end;padding-bottom:4px"><a href="/breeders/search" target="_blank" rel="noopener">Create a dataset in the Search Wizard</a> (trials of the crop + the trait; at least 8 trials)</div></div>';
    if (T.dsId) {
        if (!info) h += '<div class="sat-small sat-muted" style="margin-top:6px">Reading the dataset…</div>';
        else if (info.error) h += `<div class="sat-small text-danger" style="margin-top:6px">${esc(info.error)}</div>`;
        else {
            h += `<div class="sat-small" style="margin-top:6px">${info.trials.length} trial${info.trials.length === 1 ? '' : 's'}, ${info.traits.length} trait${info.traits.length === 1 ? '' : 's'}`
                + (info.ok ? ' <span class="text-success">· usable</span>' : ` <span class="text-danger">· not usable: ${esc(info.problems.join('; '))}</span>`) + '</div>';
            if (info.traits.length) {
                h += '<div style="margin-top:6px"><label class="sat-label" for="tr_ds_trait" style="margin-top:0">Trait to train on</label>'
                    + `<select id="tr_ds_trait" class="form-control input-sm" style="min-width:320px"><option value="">Choose the trait</option>${info.traits.map(t => `<option value="${t.id}"${String(T.dsTrait) === String(t.id) ? ' selected' : ''}>${esc(traitName(t.name))}</option>`).join('')}</select></div>`;
            }
            h += outlierBox(info);
            h += fieldWarning(info.fields || []);
        }
    }
    $('#tr_ds_box').html(h);
}

/** Trials of the dataset validated for the chosen trait (Phenotype Quality Control): { all, n, validated, notValidated } */
function validation(info) {
    const trait = traitName((info.traits.find(t => String(t.id) === String(T.dsTrait)) || {}).name);
    const fields = info.fields || [];
    const ok = fields.filter(f => (f.validated || []).includes(trait));
    return { trait, n: fields.length, validated: ok.length, notValidated: fields.filter(f => !(f.validated || []).includes(trait)) };
}

/** Outliers of the trait: nothing to ask when every trial is validated; otherwise remove them, or continue as they are. */
function outlierBox(info) {
    if (!T.dsTrait || !info.fields) return '';
    const v = validation(info);
    let h = '<div class="sat-label" style="margin-top:10px">Outliers</div>';
    if (v.n && !v.notValidated.length) {
        T.outliers = 'validated';
        return h + `<div class="sat-small text-success">✓ All ${v.n} trials are validated for ${esc(v.trait)} (Phenotype Quality Control): the values marked there as outliers are left out.</div>`;
    }
    if (T.outliers === 'validated') T.outliers = '';
    h += `<div class="sat-warn"><b>${v.notValidated.length} of ${v.n} trial${v.n === 1 ? '' : 's'} ${v.notValidated.length === 1 ? 'is' : 'are'} not validated for ${esc(v.trait)}</b>: ${v.notValidated.length === 1 ? 'its' : 'their'} values were not checked for outliers `
        + '(<a href="/tools/qualitycontrol" target="_blank" rel="noopener">Phenotype Quality Control</a>). One wrong plot value moves a trial\'s mean, and the model learns from those means.'
        + '<div style="margin-top:6px"><label class="sat-small" style="display:block;font-weight:normal"><input type="radio" name="tr_outliers" value="remove"' + (T.outliers === 'remove' ? ' checked' : '') + ' /> '
        + `<b>Remove outliers from the dataset</b>: ${info.outliers ? `the ${info.outliers} outlier${info.outliers === 1 ? '' : 's'} stored with the dataset, and ` : ''}in each trial not validated, plot values beyond 1.5 interquartile ranges from the quartiles (Tukey), before the trial means</label>`
        + '<label class="sat-small" style="display:block;font-weight:normal"><input type="radio" name="tr_outliers" value="keep"' + (T.outliers === 'keep' ? ' checked' : '') + ' /> '
        + '<b>Continue with the values as they are</b></label></div>'
        + '<div class="sat-small sat-muted">Values already marked as outliers in Phenotype Quality Control are always left out.</div></div>';
    return h;
}

/** Where each trial's field comes from, and the warning for trials placed only by their location's coordinates. */
function fieldWarning(fields) {
    if (!fields.length) return '';
    const by = k => fields.filter(f => f.field === k);
    const plots = by('plots'), drawn = by('drawn'), loc = by('location'), none = by('none');
    let h = '<div class="sat-label" style="margin-top:10px">Where the trials are</div><div class="sat-small">'
        + [[plots.length, 'with plot GPS coordinates'], [drawn.length, 'with a field drawn for them'], [loc.length, 'placed only by their location\'s coordinates'], [none.length, 'with no coordinates at all (left out)']]
            .filter(([n]) => n).map(([n, l]) => `<b>${n}</b> ${l}`).join(' · ') + '</div>';
    if (loc.length) {
        const locs = {};
        loc.forEach(f => { const l = f.location || {}; locs[l.id] = locs[l.id] || { ...l, n: 0 }; locs[l.id].n++; });
        const list = Object.values(locs).sort((a, b) => b.n - a.n);
        h += `<div class="sat-warn" style="margin-top:8px"><b>${loc.length} trial${loc.length === 1 ? ' has' : 's have'} no field of ${loc.length === 1 ? 'its' : 'their'} own</b> (no plot GPS coordinates, no field drawn), so ${loc.length === 1 ? 'it is' : 'they are'} placed by the coordinates of ${loc.length === 1 ? 'its' : 'their'} location. `
            + 'Locations often hold the coordinates of the <b>town</b>, not of the field where the trial was planted: the satellite then sees streets and roofs, not the trial, and the model would learn nothing (or the wrong thing). '
            + `The run checks each of them and leaves it out when no crop grows at that point in its season (NDVI peak below ${setting('location_min_peak')}).`
            + '<br><b>How to fix it:</b> put the coordinates of the field where the trial was planted on its location '
            + '(<a href="/breeders/locations" target="_blank" rel="noopener">Manage &rarr; Locations</a>, edit the location\'s latitude and longitude), '
            + 'or draw the trial\'s field on the <a href="/breeders/satellite" target="_blank" rel="noopener">satellite page</a> (step 2, A trial); then train again.'
            + '<table class="sat-mini-table" style="margin-top:6px;background:#fff"><thead><tr><th>Location</th><th class="num">Latitude</th><th class="num">Longitude</th><th class="num">Trials here</th><th class="num">All its trials</th></tr></thead><tbody>'
            + list.map(l => `<tr><td>${esc(l.name)}</td><td class="num">${fmt(l.lat, 5)}</td><td class="num">${fmt(l.lon, 5)}</td><td class="num">${l.n}</td><td class="num">${l.trials || ''}</td></tr>`).join('')
            + '</tbody></table>'
            + (list.some(l => l.trials > 5) ? '<div class="sat-small" style="margin-top:4px">A location shared by many trials of different years cannot be the field of all of them: those trials were planted in different fields around that place.</div>' : '')
            + '</div>';
    }
    return h;
}

/* ---------- 2 settings ---------- */

function renderSettings() {
    $('#tr_model').html(Object.entries(MODEL_LABELS).map(([k, l]) => `<option value="${k}"${k === T.model ? ' selected' : ''}>${esc(l)}</option>`).join(''));
    $('#tr_settings').html(Object.entries(SETTINGS).filter(([k]) => T.useIbge || !['samples_per_region', 'sample_size_m', 'min_crop_ha'].includes(k))
        .filter(([k]) => T.useDataset || !['location_field_m', 'location_min_peak', 'season_days'].includes(k))
        .map(([k, [label, def, min, max, step, help]]) => `<div><label class="sat-label" for="tr_set_${k}">${esc(label)}</label>`
            + `<input type="number" class="form-control input-sm tr-set" id="tr_set_${k}" data-k="${k}" value="${esc(setting(k))}" min="${min}" max="${max}" step="${step}" style="width:120px" />`
            + (help ? `<div class="sat-help">${esc(help)}</div>` : '') + '</div>').join(''));
}

/* ---------- 3 train ---------- */

function readiness() {
    const items = [];
    items.push({ ok: !!T.crop, text: T.crop ? `Crop: ${cropLabel()}` : 'Choose the crop (step 1)' });
    if (!T.useIbge && !T.useDataset) items.push({ ok: false, text: 'Choose the training data (step 1): regional statistics and/or a dataset' });
    if (T.useIbge) {
        items.push({ ok: T.picked.size > 0, text: T.picked.size ? `Regional statistics: ${T.picked.size} municipality-season${T.picked.size === 1 ? '' : 's'} (IBGE), ${setting('samples_per_region')} square${setting('samples_per_region') === 1 ? '' : 's'} of ${fmt(setting('sample_size_m') / 1000, 1)} km each` : 'Regional statistics: choose the municipalities (step 1)' });
    }
    if (T.useDataset) {
        const info = T.dsId ? T.dsInfo[T.dsId] : null;
        items.push({ ok: !!(info && info.ok), text: !T.dsId ? 'Dataset: choose one (step 1)' : !info ? 'Dataset: reading…' : info.error ? `Dataset: ${info.error}` : info.ok ? `Dataset "${info.name}": ${info.trials.length} trials` : `Dataset "${info.name}" is not usable: ${info.problems.join('; ')}` });
        if (info && info.ok) items.push({ ok: !!T.dsTrait, text: T.dsTrait ? `Trait to train on: ${traitName((info.traits.find(t => String(t.id) === String(T.dsTrait)) || {}).name)}` : 'Choose the trait to train on (step 1)' });
        if (info && info.ok && T.dsTrait && info.fields) {
            items.push({ ok: !!T.outliers, text: { validated: 'Outliers: every trial is validated for the trait', remove: 'Outliers: removed (dataset outliers + Tukey fences in trials not validated)',
                keep: 'Outliers: some trials not validated, continuing with the values as they are' }[T.outliers] || 'Outliers: some trials are not validated for the trait: remove the outliers, or continue as they are (step 1)' });
        }
        const loc = ((info && info.fields) || []).filter(f => f.field === 'location').length;
        if (loc) items.push({ ok: true, warn: true, text: `${loc} trial${loc === 1 ? '' : 's'} placed only by the location's coordinates: checked by the run, left out where no crop grows (see step 1 for the fix)` });
        if (T.useIbge && T.dsTrait) items.push({ ok: true, warn: true, text: 'Regional statistics are in kg/ha: the trait of the trials must be in kg/ha too' });
    }
    const n = (T.useIbge ? T.picked.size : 0) + (T.useDataset && T.dsInfo[T.dsId] && T.dsInfo[T.dsId].ok ? T.dsInfo[T.dsId].trials.length : 0);
    items.push({ ok: n >= setting('min_fields'), text: n >= setting('min_fields') ? `Up to ${n} items of known yield (at least ${setting('min_fields')} must pass the checks)` : `${n} items of known yield; at least ${setting('min_fields')} are needed` });
    items.push({ ok: true, text: `Models: ${MODEL_LABELS[T.model]}` });
    return items;
}

function renderReady() {
    const items = readiness();
    $('#tr_ready').html(items.map(r => `<li class="${r.ok ? (r.warn ? 'ok' : 'ok') : 'no'}">${r.warn ? '<span class="text-warning">⚠</span> ' : ''}${esc(r.text)}</li>`).join(''));
    $('#tr_run').prop('disabled', !items.every(r => r.ok) || T.job.status === 'running');
    $('#tr_name').attr('placeholder', suggestedName());
    renderStepper();
}

/** The model name: the one typed, or a suggestion from the crop and the training data. */
function suggestedName() {
    const src = [T.useIbge && T.picked.size ? 'IBGE regional' : '', T.useDataset && T.dsInfo[T.dsId] && T.dsInfo[T.dsId].name ? T.dsInfo[T.dsId].name : ''].filter(Boolean).join(' + ');
    return `${cropLabel()} yield - ${src || 'training'} - ${new Date().toISOString().slice(0, 10)}`;
}
const modelName = () => (T.name.trim() || suggestedName());

function payload() {
    return {
        name: modelName(), crop: T.crop, settings: { ...T.settings, yield_model: T.model },
        regions: T.useIbge ? { ufs: [...T.ufs], years: [...T.years], keys: [...T.picked] } : null,
        dataset_id: T.useDataset ? T.dsId : '', trait_id: T.useDataset ? T.dsTrait : '', outliers: T.useDataset ? T.outliers : '',
    };
}

async function startRun() {
    $('#tr_run').prop('disabled', true);
    $('#tr_run_error').empty();
    try {
        const r = await postJSON('train_run', { request: JSON.stringify(payload()), notify: $('#tr_notify').prop('checked') ? 1 : '' });
        T.job = { runId: r.run_id, status: 'running', skipped: r.skipped, notify: r.notify };
        history.replaceState(null, '', `?run=${encodeURIComponent(r.run_id)}`);
        renderJob();
        loadRuns();
    } catch (err) {
        $('#tr_run_error').html(`<div class="alert alert-danger" style="white-space:pre-wrap">${esc(err.message)}</div>`);
        renderReady();
    }
}

function openRun(id) {
    clearTimeout(T.job.timer);
    T.job = { runId: id, status: 'running' };
    goStep(3);
    renderJob();
}

const fileUrl = name => `${API}/file?` + new URLSearchParams({ run_id: T.job.runId, name }).toString();

function renderJob() {
    const j = T.job;
    $('#tr_job').toggle(!!j.runId);
    if (!j.runId) return;
    $('#tr_run_title').text(j.results && j.results.name ? j.results.name : 'Training');
    if (j.status === 'running') {
        $('#tr_results').hide();
        $('#tr_run_notes').html(j.skipped && j.skipped.length ? `<div class="sat-warn">Left out before the run: ${j.skipped.map(esc).join(' ')}</div>` : '');
        $('#tr_run_progress').show();
        $('#tr_run_info').html('Training on the server: you can close this page.' + (j.notify ? ` An email will be sent to <b>${esc(j.notify)}</b> when it is done.` : '') + ' It is also listed under <i>Earlier trainings</i>.');
        $('#tr_run_log_box').show();
        poll();
    } else if (j.status === 'failed') {
        $('#tr_run_progress').hide(); $('#tr_run_info').empty();
        $('#tr_run_logfile').attr('href', fileUrl('log')).show();
        $('#tr_run_error').html(`<div class="alert alert-danger" style="white-space:pre-wrap">${esc(j.error || 'The training failed.')}</div>`);
    } else if (j.results) {
        $('#tr_run_progress').hide(); $('#tr_run_info').empty(); $('#tr_run_log_box').hide();
        $('#tr_run_logfile').attr('href', fileUrl('log')).show();
        renderResults();
    }
    renderReady();
}

function poll() {
    const j = T.job;
    clearTimeout(j.timer);
    const tick = async () => {
        if (T.job !== j) return;
        let r;
        try { r = await getJSON('status', { run_id: j.runId }); } catch (err) { j.status = 'failed'; j.error = err.message; renderJob(); return; }
        const sec = r.seconds || 0;
        $('#tr_run_elapsed').text(sec < 60 ? `${sec} s` : sec < 3600 ? `${Math.floor(sec / 60)} min ${String(sec % 60).padStart(2, '0')} s` : `${Math.floor(sec / 3600)} h ${String(Math.floor(sec / 60) % 60).padStart(2, '0')} min`);
        $('#tr_run_text').text(r.progress ? `Working on the server: ${r.progress}` : 'Starting…');
        if (r.log) {
            const pre = document.getElementById('tr_run_log');
            const atEnd = pre && pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 8;
            $('#tr_run_log').text(r.log.join('\n'));
            $('#tr_run_log_n').text(`(${r.log_lines || r.log.length} steps)`);
            if (pre && atEnd) pre.scrollTop = pre.scrollHeight;
        }
        if (r.status === 'running') { j.timer = setTimeout(tick, 4000); return; }
        if (r.status === 'failed') { j.status = 'failed'; j.error = r.error; renderJob(); loadRuns(); return; }
        try { j.results = await getJSON('results', { run_id: j.runId }); j.status = 'done'; } catch (err) { j.status = 'failed'; j.error = err.message; }
        renderJob();
        loadRuns();
    };
    $('#tr_run_text').text('Starting…');
    tick();
}

function renderResults() {
    const R = T.job.results, Y = R.yield || {};
    const u = Y.unit ? ` (${esc(Y.unit)})` : '';
    const cal = Y.calibration || [];
    let h = '';
    if (!R.train) h += '<div class="sat-warn">This run is an analysis of an area, not a training: open it on the <a href="/breeders/satellite?run=' + esc(T.job.runId) + '">satellite page</a>.</div>';
    h += `<div class="sat-small sat-muted">${esc(traitName(Y.trait) || 'Yield')} · ${esc(R.crop || '')} · ${(Y.predictor_labels || []).map(esc).join(' + ')}${Y.metrics && Y.metrics.cv ? ` · validated ${esc(Y.metrics.cv)}` : ''}</div>`;
    if (Y.metrics) {
        const m = Y.metrics;
        h += `<div class="sat-stats" style="margin:10px 0"><div class="sat-stat"><div class="v">${fmt(m.r2, 2)}</div><div class="l">R² (${esc(m.cv || 'cross-validation')})</div></div>`
            + `<div class="sat-stat"><div class="v">${fmt(m.rmse, 0)}</div><div class="l">error RMSE${u}</div></div><div class="sat-stat"><div class="v">${fmt(m.mae, 0)}</div><div class="l">mean abs. error</div></div>`
            + `<div class="sat-stat"><div class="v">${m.n}</div><div class="l">items used</div></div><div class="sat-stat"><div class="v">${esc(MODEL_LABELS[Y.model] || Y.model)}</div><div class="l">model chosen</div></div></div>`;
        if (m.r2 < 0.3) h += `<div class="sat-warn">The season curve explains little of the yield differences in the training data (R² ${fmt(m.r2, 2)} when each location-year is left out): estimates made with this model will be rough.</div>`;
        if (Y.comparison && Y.comparison.length > 1) {
            h += '<h4>Models compared</h4><div class="sat-help">' + esc((Y.selection || {}).rule || '') + '</div><table class="sat-mini-table" style="margin-top:4px"><thead><tr><th>Model</th><th class="num">R²</th><th class="num">RMSE</th><th class="num">MAE</th><th class="num">Bias</th></tr></thead><tbody>'
                + Y.comparison.map(z => z.failed ? `<tr><td>${esc(z.label)}</td><td colspan="4" class="sat-muted sat-small">could not be fitted</td></tr>`
                    : `<tr${z.chosen ? ' style="background:var(--sat-accent-soft)"' : ''}><td>${z.chosen ? '<b>' : ''}${esc(z.label)}${z.chosen ? '</b> ✓' : ''}</td><td class="num">${fmt(z.r2, 2)}</td><td class="num">${fmt(z.rmse, 0)}</td><td class="num">${fmt(z.mae, 0)}</td><td class="num">${fmt(z.bias, 0)}</td></tr>`).join('')
                + '</tbody></table>';
        }
        h += '<div class="row" style="margin-top:10px"><div class="col-sm-6" id="tr_plot"></div><div class="col-sm-6">';
        if (Y.coefficients && Y.coefficients.length) h += '<table class="sat-mini-table"><thead><tr><th>Term</th><th class="num">Estimate</th><th class="num">SE</th></tr></thead><tbody>'
            + Y.coefficients.map(c => `<tr><td>${esc(PREDICTOR_NAMES[c.term] || c.term)}</td><td class="num">${fmt(c.estimate, 3)}</td><td class="num">${c.se !== undefined ? fmt(c.se, 3) : ''}</td></tr>`).join('') + '</tbody></table>';
        const groups = {};
        cal.filter(c => c.used && c.loo !== null && c.loo !== undefined).forEach(c => { const k = c.site || c.name; groups[k] = groups[k] || []; groups[k].push(c.loo - c.observed); });
        const rows = Object.entries(groups).map(([k, e]) => [k, e.length, e.reduce((a, x) => a + x, 0) / e.length, Math.sqrt(e.reduce((a, x) => a + x * x, 0) / e.length)]).sort((a, b) => b[3] - a[3]);
        if (rows.length > 1) h += '<div class="sat-label" style="margin-top:10px">Error by place</div><div style="max-height:220px;overflow:auto"><table class="sat-mini-table"><thead><tr><th>Place</th><th class="num">Items</th><th class="num">Bias</th><th class="num">RMSE</th></tr></thead><tbody>'
            + rows.map(([k, n, b, r]) => `<tr><td>${esc(k)}</td><td class="num">${n}</td><td class="num">${fmt(b, 0)}</td><td class="num">${fmt(r, 0)}</td></tr>`).join('') + '</tbody></table></div>';
        h += '</div></div>';
    } else {
        h += `<div class="sat-warn">No model: ${Y.n_used || 0} of ${Y.n_calibration || 0} items usable, at least ${Y.min_fields} needed. See why each item was left out below.</div>`;
    }
    const used = cal.filter(c => c.used).length;
    h += `<h4>Training data (${used} used of ${cal.length})</h4><div style="max-height:380px;overflow:auto"><table class="sat-mini-table"><thead><tr><th>Item</th><th>From</th><th>Season</th><th class="num">Observed${u}</th><th class="num">Predicted (left out)</th><th class="num">Crop found</th><th class="num">Clear dates</th><th class="num">NDVI peak</th><th></th></tr></thead><tbody>`
        + cal.map(c => `<tr${c.used ? '' : ' class="sat-muted"'}><td>${esc(c.name)}</td><td class="sat-small">${c.kind === 'region' ? 'IBGE' : c.field_from === 'location' ? `<span class="text-warning">trial, location point</span>` : c.field_from === 'plots' ? 'trial, plot GPS' : c.field_from === 'drawn' ? 'trial, drawn field' : esc(c.source)}</td>`
            + `<td class="sat-small">${c.kind === 'region' ? esc(SEASONS[c.season] || c.season) + ' ' + esc(c.year) : `${esc(c.start)} – ${esc(c.end)}`}</td><td class="num">${fmt(c.observed, 0)}${c.outliers_removed ? `<br><span class="sat-small sat-muted" title="Plot values left out as outliers">${c.outliers_removed} outlier${c.outliers_removed === 1 ? '' : 's'} out</span>` : ''}</td><td class="num">${c.loo !== null && c.loo !== undefined ? fmt(c.loo, 0) : ''}</td>`
            + `<td class="num">${c.crop_ha !== null && c.crop_ha !== undefined ? `${fmt(c.crop_ha, 1)} ha` : ''}</td><td class="num">${c.n_dates ?? ''}</td><td class="num">${fmt(c.ndvi_max, 2)}</td><td class="sat-small text-warning">${esc(c.reason || '')}</td></tr>`).join('')
        + '</tbody></table></div>';
    if ((R.calibration_skipped || []).length) h += `<details style="margin-top:6px"><summary class="sat-small">${R.calibration_skipped.length} left out before the run</summary><ul class="sat-small">${R.calibration_skipped.map(x => `<li>${esc(x)}</li>`).join('')}</ul></details>`;
    if ((R.notes || []).length) h += `<details style="margin-top:6px"${R.notes.some(n => /location/.test(n)) ? ' open' : ''}><summary class="sat-small"><b>Notes (${R.notes.length})</b></summary><ul class="sat-small">${R.notes.map(n => `<li>${esc(n)}</li>`).join('')}</ul></details>`;
    if (cal.some(c => c.kind === 'region')) h += '<div class="sat-help" style="margin-top:6px">Regional items: the observed yield is the municipality\'s published average (IBGE PAM) for that crop season; the satellite curve is the mean of the maize found in the sample squares. Fields better or worse than their municipality are not in the training data, so the model is regional: it ranks fields well when they differ like municipalities do.</div>';
    // save
    if (R.can_save_model) {
        h += R.saved_model_entry
            ? `<div class="alert alert-success" style="margin-top:10px">Saved as the model "<b>${esc(R.saved_model_entry.name)}</b>". Use it in an analysis: <a href="/breeders/satellite">satellite page</a> → Model → Yield → <i>Use a trained model</i>.</div>`
            : '<div class="sat-card" style="margin-top:12px;background:#f8fafc"><h4 style="margin-top:0">Save the model</h4><div class="sat-inline-row"><div><label class="sat-label" for="tr_save_name">Model name</label><input type="text" id="tr_save_name" class="form-control input-sm" maxlength="200" style="min-width:280px" /></div>'
                + '<div style="align-self:flex-end"><button type="button" class="btn btn-primary btn-sm" id="tr_save">Save the model</button></div></div>'
                + '<div class="sat-help">Stored as a Breedbase analysis model with its training data, accuracy, crop and unit; choose it in any analysis.</div><div id="tr_save_msg"></div></div>';
    }
    $('#tr_results').html(h).show();
    if (!R.saved_model_entry) {
        // the name given when the training started (the run's name)
        $('#tr_save_name').val(R.name || `${cropLabel()} yield - ${new Date().toISOString().slice(0, 10)}`);
    }
    if (Y.metrics) drawPlot(cal.filter(c => c.used && c.loo !== null && c.loo !== undefined), u);
}

function drawPlot(pts, unit) {
    if (!pts.length) return;
    const W = 380, H = 320, L0 = 56, B0 = 40, T0 = 12, R0 = 12;
    const all = pts.flatMap(p => [p.observed, p.loo]);
    let lo = Math.min(...all), hi = Math.max(...all);
    const pad = (hi - lo) * 0.08 || 1; lo -= pad; hi += pad;
    const X = v => L0 + (W - L0 - R0) * (v - lo) / (hi - lo), Y = v => H - B0 - (H - T0 - B0) * (v - lo) / (hi - lo);
    const col = { summer: '#d97706', safrinha: '#2563eb', year: '#2b7a4b' };
    let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Observed against predicted yield">`;
    for (let i = 0; i <= 4; i++) {
        const v = lo + (hi - lo) * i / 4;
        svg += `<line x1="${L0}" x2="${W - R0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#eef0f2" /><text x="${L0 - 6}" y="${Y(v) + 4}" font-size="10" text-anchor="end" fill="#6b7280">${fmt(v, 0)}</text>`
            + `<text x="${X(v)}" y="${H - B0 + 14}" font-size="10" text-anchor="middle" fill="#6b7280">${fmt(v, 0)}</text>`;
    }
    svg += `<line x1="${X(lo)}" y1="${Y(lo)}" x2="${X(hi)}" y2="${Y(hi)}" stroke="#9ca3af" stroke-dasharray="4 3" />`;
    pts.forEach(p => {
        const c = p.kind === 'region' ? (col[p.season] || '#2b7a4b') : '#111827';
        svg += `<circle cx="${X(p.observed)}" cy="${Y(p.loo)}" r="4.5" fill="${p.kind === 'region' ? c : '#fff'}" stroke="${c}" stroke-width="1.5"><title>${esc(p.name)}: observed ${fmt(p.observed, 0)}, predicted ${fmt(p.loo, 0)}</title></circle>`;
    });
    svg += `<text x="${(L0 + W - R0) / 2}" y="${H - 6}" font-size="11" text-anchor="middle" fill="#374151">observed${esc(unit.replace(/<[^>]+>/g, ''))}</text><text x="12" y="${(T0 + H - B0) / 2}" font-size="11" text-anchor="middle" fill="#374151" transform="rotate(-90 12 ${(T0 + H - B0) / 2})">predicted, its location-year left out</text></svg>`;
    const kinds = new Set(pts.map(p => (p.kind === 'region' ? p.season : 'trial')));
    const legend = [...kinds].map(k => k === 'trial' ? '<span><svg width="10" height="10"><circle cx="5" cy="5" r="4" fill="#fff" stroke="#111827" /></svg> trials</span>'
        : `<span><svg width="10" height="10"><circle cx="5" cy="5" r="4" fill="${col[k] || '#2b7a4b'}" /></svg> ${esc(SEASONS[k] || k)}</span>`).join(' &nbsp; ');
    $('#tr_plot').html(svg + `<div class="sat-help">${legend}. Each item predicted by a model fitted without its location-year. Dashed: perfect prediction.</div>`);
}

async function saveModel() {
    const name = $('#tr_save_name').val().trim();
    if (!name) { $('#tr_save_msg').html('<span class="text-danger sat-small">Give the model a name.</span>'); return; }
    $('#tr_save').prop('disabled', true).text('Saving…');
    try {
        const r = await postJSON('save_model', { run_id: T.job.runId, name, description: '' });
        T.job.results.saved_model_entry = { id: r.model_id, name: r.name };
        renderResults();
    } catch (err) {
        $('#tr_save').prop('disabled', false).text('Save the model');
        $('#tr_save_msg').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`);
    }
}

/* ---------- earlier trainings ---------- */

async function loadRuns() {
    try { T.runs = (await getJSON('runs')).runs.filter(r => r.kind === 'train'); } catch (e) { T.runs = []; }
    renderRuns();
}

function renderRuns() {
    const rs = T.runs || [];
    $('.tr-runs').html(!rs.length ? '<span class="sat-muted sat-small">No training yet.</span>' : '<table class="sat-mini-table"><tbody>'
        + rs.map(r => `<tr${r.run_id === T.job.runId ? ' style="background:var(--sat-accent-soft)"' : ''}><td><a href="#" class="tr-open" data-id="${esc(r.run_id)}">${esc(r.name || r.run_id)}</a>${r.model_saved && r.model_saved !== r.name ? ` <span class="sat-small">· saved as model <b>${esc(r.model_saved)}</b></span>` : ''}</td>`
            + `<td class="sat-small sat-muted">${new Date(r.created * 1000).toLocaleString()}</td><td class="sat-small">${r.status === 'done' ? '<span class="text-success">done</span>' : r.status === 'failed' ? '<span class="text-danger">failed</span>' : 'running…'}</td></tr>`).join('')
        + '</tbody></table>');
}

/* ---------- events ---------- */

function bind() {
    $('#tr_stepper').on('click', 'li', function () { goStep(+$(this).data('step')); });
    $(document).on('click', '.tr-next', function () { goStep(+$(this).data('to')); if (+$(this).data('to') === 2) renderSettings(); });
    $('#tr_crop').on('change', function () { T.crop = this.value; T.regions = null; T.picked = new Set(); if (isMaize()) T.useIbge = true; renderSources(); renderReady(); });
    $('#tr_sources').on('click', '.sat-option', function (e) {
        e.preventDefault();
        if ($(this).hasClass('disabled')) return;
        const k = $(this).data('v');
        if (k === 'ibge') T.useIbge = !T.useIbge; else T.useDataset = !T.useDataset;
        renderSources(); renderReady();
    });
    $('#tr_states').on('click', '.sat-seg', function () { const c = +$(this).data('uf'); if (T.ufs.has(c)) T.ufs.delete(c); else if (T.ufs.size < 6) T.ufs.add(c); renderIbge(); });
    $('#tr_years').on('click', '.sat-seg', function () { const y = +$(this).data('year'); if (T.years.has(y)) T.years.delete(y); else if (T.years.size < 8) T.years.add(y); renderIbge(); });
    $('#tr_regions_load').on('click', loadRegions);
    $('#tr_regions').on('change', '.tr-region', function () { const k = $(this).data('k'); if (this.checked) T.picked.add(k); else T.picked.delete(k); renderRegions(); renderReady(); });
    $('#tr_regions').on('click', '.tr-top', function () { const n = +$(this).data('n'); T.picked = new Set(T.regions.slice(0, n).map(regionKey)); renderRegions(); renderReady(); });
    $('#tr_ds_box').on('change', '#tr_ds', function () { T.dsId = this.value; T.dsTrait = ''; T.outliers = ''; renderDataset(); renderReady(); });
    $('#tr_ds_box').on('change', '#tr_ds_trait', function () { T.dsTrait = this.value; T.outliers = ''; renderDataset(); renderReady(); });
    $('#tr_ds_box').on('change', 'input[name=tr_outliers]', function () { T.outliers = this.value; renderReady(); });
    $('#tr_model').on('change', function () { T.model = this.value; renderReady(); });
    $('#tr_settings').on('change', '.tr-set', function () {
        const k = $(this).data('k'), [, def, min, max] = SETTINGS[k];
        let v = +this.value; if (!isFinite(v)) v = def; v = Math.min(max, Math.max(min, v));
        this.value = v; T.settings[k] = v;
        if (T.regions) renderRegions();
        renderReady();
    });
    $('#tr_settings_reset').on('click', () => { T.settings = {}; T.model = 'auto'; renderSettings(); renderReady(); });
    $('#tr_name').on('input', function () { T.name = this.value; });
    $('#tr_run').on('click', startRun);
    $(document).on('click', '#tr_save', saveModel);
    $(document).on('click', '.tr-open', function (e) { e.preventDefault(); history.replaceState(null, '', `?run=${encodeURIComponent($(this).data('id'))}`); openRun($(this).data('id')); });
    $(document).on('click', '.tr-runs-refresh', loadRuns);
}

async function init() {
    bind();
    try {
        const [c, st] = await Promise.all([getJSON('crops'), getJSON('train_regions')]);
        T.crops = c.crops; T.crop = c.preferred || (c.crops[0] || {}).species || '';
        T.states = st.states;
    } catch (err) { $('#tr_sources_msg').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`); }
    [thisYear - 1, thisYear - 2, thisYear - 3].forEach(y => T.years.add(y));
    T.useIbge = isMaize(); T.useDataset = !isMaize();
    renderCrops();
    renderSources();
    renderSettings();
    renderReady();
    loadRuns();
    const run = new URLSearchParams(location.search).get('run');
    if (run && /^sat_\d+_\d+$/.test(run)) openRun(run); else goStep(1);
}

$(init);
