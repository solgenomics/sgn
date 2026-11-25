/**
 * Satellite page (/breeders/satellite): Sentinel-2 (10 m) and Landsat 8/9 (30 m) images of
 * the field of a research station (Breedbase location) or of a trial for a date range.
 *
 * Flow: location (left) -> field (a trial with plot GPS coordinates, or a square around a
 * point picked on the map) -> dates (presets, trial season) -> view (true colour / NDVI).
 * The server lists the scenes (/ajax/satellite/scenes: Earth Search for Sentinel-2, Planetary
 * Computer for Landsat, whose images need a free read token appended to the url); the browser
 * reads only the window around the field from the Cloud-Optimized GeoTIFFs
 * (modules/cog_reader.js): first the cloud mask (Sentinel-2 SCL or Landsat QA_PIXEL, a few KB
 * to ~100 KB a date) to measure cloud over the field itself, then the true-colour image or
 * red + NIR (NDVI) of the dates that are clear enough.
 */

import '../legacy/leaflet.js';
import { openCog, readWindow, windowFor, latLonToUtm, utmOfEpsg } from '../modules/cog_reader.js';

const API = '/ajax/satellite';
const SIZES = [[500, '500 m'], [1000, '1 km'], [2000, '2 km'], [5000, '5 km']];
const CLEAR_MIN = 80;            // % of the field without cloud / shadow to count a date as clear
const VALID_MIN = 50;            // % of the field inside the image (edge of the satellite path)
const FIELD_MARGIN = 150;        // metres around the trial plots
// Cloud mask of both satellites as one code per pixel
const M_NODATA = 0, M_CLEAR = 1, M_CLOUD = 2, M_OTHER = 3;   // other: saturated / snow, no NDVI
const SCL_CLOUD = new Set([3, 8, 9, 10]);      // SCL: cloud shadow, cloud medium / high, cirrus
const SCL_OTHER = new Set([1, 11]);            // SCL: saturated, snow
// Landsat QA_PIXEL bits: 0 fill, 1 dilated cloud, 2 cirrus, 3 cloud, 4 cloud shadow, 5 snow
const QA_CLOUD = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4);
const sclCode = v => (v === 0 ? M_NODATA : SCL_CLOUD.has(v) ? M_CLOUD : SCL_OTHER.has(v) ? M_OTHER : M_CLEAR);
const qaCode = v => (v & 1 ? M_NODATA : v & QA_CLOUD ? M_CLOUD : v & (1 << 5) ? M_OTHER : M_CLEAR);
// What the page knows of each satellite; which ones are offered comes from /ajax/satellite/sources
const SOURCES = {
    sentinel2: { name: 'Sentinel-2', res: 10, mb: { rgb: 1, ndvi: 2.7 }, text: 'The sharper free view of the field.' },
    landsat: { name: 'Landsat 8/9', res: 30, mb: { rgb: 0.5, ndvi: 0.4 }, text: 'Coarser, but more dates: fills the gaps when Sentinel-2 was cloudy.' },
    planet: { name: 'PlanetScope', res: 3, mb: { rgb: 1, ndvi: 1 }, text: "Paid: each image uses your organisation's Planet quota." },
};
const LANDSAT_TRUE_COLOUR_MAX = 0.25;   // reflectance shown as full brightness
const NDVI_STOPS = [[-0.2, [120, 72, 36]], [0.1, [196, 160, 98]], [0.3, [236, 220, 120]], [0.5, [150, 196, 82]], [0.7, [62, 150, 60]], [0.9, [16, 84, 34]]];

const MAX_AREA = 10000;           // metres: largest square read around plots / fields
const LOC_TYPES = [['all', 'All'], ['Farm', 'Farms'], ['Field', 'Field stations'], ['other', 'Other']];

/*
 * Several locations (farms, research stations) can be analysed together: each is a "site" with its own
 * field, trials, images and cloud measures. The site shown is copied into S (SITE_KEYS) so the code
 * below works on S as for one location; useSite() swaps sites.
 */
const SITE_KEYS = ['loc', 'trials', 'trial', 'trialPlots', 'trialDrawn', 'trialCanEdit', 'trialDirty', 'field', 'point', 'size', 'mode',
    'farmFields', 'farmCanEdit', 'fieldsDirty', 'scenes', 'info', 'visible', 'area', 'warnings', 'runKey', 'labels', 'targets', 'hidden', 'useStep2'];
const S = {
    locations: [], sites: [], cur: -1, typeFilter: 'all',
    loc: null, trials: [], trial: null, trialPlots: null, trialDrawn: null, trialCanEdit: 0, trialDirty: false,
    field: null, point: null, size: 1000, mode: 'point', farmFields: [], farmCanEdit: 0, fieldsDirty: false,
    start: null, end: null, preset: '3m', view: 'rgb', showCloudy: false,
    offered: [], sources: {}, landsatToken: null, tokenFetch: null, warnings: [],
    scenes: [], info: {}, run: 0, abort: null, running: false, visible: [], bigIndex: -1, runKey: null,
    map: null, layers: null, step: 1, draw: { active: false, pts: [], target: null, where: 'field' },
    labels: [], targets: [], hidden: [], useStep2: true, useStep2Labels: true, showHidden: false,
    // step 5: model, step 6: results
    models: { crop_map: true, yield: false, indices: false }, crops: [], crop: '', cropOther: '', season: { start: null, end: null },
    seasonMode: 'detected', seasonNames: [], savedModels: null, savedModelId: null, ana: { start: null, end: null }, anaPreset: 'images', runsList: null, mapMethod: null, mapAreas: null, yieldMode: null, useReference: true, refs: {}, classes: [], calib: [], trialInfo: {}, trialInfoLoading: false, yieldUnit: '', perHa: true,
    settings: {}, mmap: null, mlayers: null, job: { runId: null, timer: null, results: null, site: 0, status: null },
};

const esc = s => String(s ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
const iso = d => d.toISOString().slice(0, 10);
const addDays = (s, n) => { const d = new Date(s + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return iso(d); };
const today = () => iso(new Date());
const fmtDate = s => new Date(s + 'T12:00:00Z').toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' });
const chosenSources = () => S.offered.map(o => o.id).filter(k => S.sources[k]);
/** 'Sentinel-2B', 'Landsat 9' */
const satName = sc => {
    const m = /^(sentinel-2|landsat-)(\w+)$/.exec(sc.platform || '');
    if (!m) return SOURCES[sc.source] ? SOURCES[sc.source].name : 'Satellite';
    return m[1] === 'sentinel-2' ? `Sentinel-2${m[2].toUpperCase()}` : `Landsat ${m[2]}`;
};

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

async function getJSON(path, params) {
    const url = `${API}/${path}?` + new URLSearchParams(params || {}).toString();
    const res = await fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } });
    let data;
    try { data = await res.json(); } catch (e) { throw new Error(`The server answered ${res.status}`); }
    if (data.error) throw new Error(data.error);
    return data;
}

/* ---------- steps and summary ---------- */

function stepAllowed(n) {
    if (n <= 1) return true;
    if (!S.sites.length) return false;
    if (n === 2) return true;
    if (n === 3) return sitesReady();
    if (n === 4) return sitesReady() && !!(S.start && S.end) && chosenSources().length > 0;
    if (n === 5) return sitesReady() && !!(S.start && S.end);
    return false;
}

function goStep(n) {
    if (n === 6 ? !S.job.runId : !stepAllowed(n)) return;
    if (S.map && $('#sat_map').hasClass('sat-map-full')) toggleFullscreen(S.map, '#sat_map', null, true);
    if (S.mmap && $('#sat_model_map').hasClass('sat-map-full')) toggleFullscreen(S.mmap, '#sat_model_map', null, true);
    S.step = n;
    $('.sat-pane').hide();
    $(`.sat-pane[data-step="${n}"]`).show();
    renderStepper();
    if (S.draw.active && n !== (S.draw.where === 'model' ? 5 : 2)) endDraw();
    renderSiteTabs();
    if (n === 2) drawMap(true);
    if (n === 4) showSiteImages();
    if (n === 5) enterModel();
    if (n === 6) { renderJob(); if (S.runsList === null) loadRuns(); else renderRuns(); }
    window.scrollTo && window.scrollTo(0, 0);
}

function renderStepper() {
    $('#sat_stepper li').each(function () {
        const n = +$(this).data('step');
        const ok = n === 6 ? !!S.job.runId : stepAllowed(n);
        $(this).toggleClass('active', n === S.step).toggleClass('done', n < S.step && ok).toggleClass('off', !ok);
    });
    $('.sat-pane[data-step="1"] .sat-next').prop('disabled', !S.sites.length);
    $('#sat_to3').prop('disabled', !sitesReady());
    renderFlow();
}

/** One line describing a site's area (for the summary and the site tabs). */
function fieldText(st) {
    const f = st.field, a = siteArea(st);
    const km = a ? `${(a.sizeM / 1000).toFixed(1)} km square` : '';
    if (f && f.kind === 'plots') return `${esc(st.trial.name)}: ${f.count} plots`;
    if (f && f.kind === 'drawn') return `${esc(st.trial.name)}: drawn field${st.trialDirty ? ' (not saved)' : ''}`;
    if (f && f.kind === 'farm') return `${f.count} field${f.count === 1 ? '' : 's'}, ${f.ha.toFixed(1)} ha`;
    if (st.mode === 'trial' && !st.trial) return 'choose a trial';
    if (st.mode === 'trial') return `${esc(st.trial.name)}: ${km} around the point`;
    return a ? km : 'no coordinates: click the map';
}

function renderFlow() {
    saveSite();
    const items = [];
    const n = S.sites.length;
    items.push([n > 0, n > 1 ? `Locations (${n})` : 'Location', n
        ? S.sites.map(st => esc(st.loc.name) + (st.loc.country ? ` <span class="sat-muted">(${esc(st.loc.country)})</span>` : '')).join('<br>')
        : 'not chosen']);
    items.push([n > 0 && sitesReady(), 'Field', n
        ? S.sites.map(st => (n > 1 ? `<b style="display:inline;font-weight:600">${esc(st.loc.name)}:</b> ` : '') + `<span class="${siteArea(st) ? '' : 'text-danger'}">${fieldText(st)}</span>`).join('<br>')
        : 'not chosen']);
    items.push([!!(S.start && S.end), 'Dates', S.start && S.end ? `${fmtDate(S.start)} – ${fmtDate(S.end)}` : 'not chosen']);
    items.push([chosenSources().length > 0, 'Satellites', chosenSources().map(k => SOURCES[k].name).join(' + ') || 'none chosen']);
    items.push([true, 'View', `${S.view === 'ndvi' ? 'NDVI' : 'True colour'}${S.showCloudy ? ', cloudy dates too' : ''}`]);
    items.push([S.scenes.length > 0, 'Images', S.scenes.length ? `${S.scenes.length} dates, ${S.scenes.filter(sc => isClear(S.info[sc.id])).length} clear` : 'not shown yet']);
    const mods = MODEL_NAMES.filter(([k]) => S.models[k]).map(([, l]) => l);
    items.push([mods.length > 0 && S.step >= 5, 'Model', mods.length ? esc(mods.join(', ')) + (S.models.yield || S.models.crop_map ? `<br><span class="sat-muted">${esc(cropLabel())}</span>` : '') : 'none']);
    items.push([!!S.job.runId, 'Results', S.job.status === 'done' ? 'ready' : S.job.status === 'failed' ? 'the run failed' : S.job.runId ? 'running…' : 'not run yet']);
    $('#sat_flow').html(items.map(([on, title, text]) => `<li class="${on ? '' : 'off'}"><b>${title}</b>${text}</li>`).join(''));
    $('#sat_badge').text(n === 0 ? 'none chosen' : n === 1 ? S.sites[0].loc.name : `${n} locations`);
}

/* ---------- locations ---------- */

const hasXY = l => l && l.lat !== null && l.lat !== undefined && l.lat !== '' && isFinite(parseFloat(l.lat)) && isFinite(parseFloat(l.lon));
const typeOf = l => (l.type === 'Farm' || l.type === 'Field') ? l.type : 'other';

/* ---------- sites (the selected locations) ---------- */

function newSite(loc) {
    return {
        loc, trials: null, trial: null, trialPlots: null, trialDrawn: null, trialCanEdit: 0, trialDirty: false,
        field: null, point: hasXY(loc) ? { lat: parseFloat(loc.lat), lon: parseFloat(loc.lon) } : null,
        size: 1000, mode: 'point', farmFields: [], farmCanEdit: 0, fieldsDirty: false,
        scenes: [], info: {}, visible: [], area: null, warnings: [], runKey: null, labels: [], targets: [], hidden: [], useStep2: true,
    };
}

/** Copy S (the site shown) back into its site object. */
function saveSite() {
    if (S.cur < 0 || !S.sites[S.cur]) return;
    const st = S.sites[S.cur];
    SITE_KEYS.forEach(k => { st[k] = S[k]; });
}

function loadSite(i) {
    S.cur = i;
    const st = S.sites[i];
    if (st) SITE_KEYS.forEach(k => { S[k] = st[k]; });
}

/** Set values of a site, also when it is the one shown (async answers arriving later). */
function siteSet(st, values) {
    Object.assign(st, values);
    if (S.sites[S.cur] === st) Object.assign(S, values);
}

/** Show another site: a running image search of the current one stops (it runs again when shown). */
function useSite(i) {
    if (i === S.cur || !S.sites[i]) return;
    if (S.draw.active) endDraw();
    if (S.running) { if (S.abort) S.abort.abort(); S.run++; S.running = false; S.runKey = null; busyEnd(P.token); }
    saveSite();
    loadSite(i);
    S.fieldMsg = '';
    renderTrialSelect();
    renderControls();
    renderSiteTabs();
    if (S.step === 2) drawMap(true);
    if (S.step === 4) showSiteImages();
    if (S.step === 5) { renderModel(); drawModelMap(true); }
}

function siteArea(st) {
    if (S.sites[S.cur] === st) return area();
    return areaOf(st);
}

function sitesReady() {
    saveSite();
    return S.sites.length > 0 && S.sites.every(st => !!areaOf(st));
}

function renderSiteTabs() {
    saveSite();
    const html = S.sites.length > 1 ? S.sites.map((st, i) => {
        const ok = !!areaOf(st);
        return `<button type="button" class="sat-site${i === S.cur ? ' on' : ''}${ok ? '' : ' bad'}" data-i="${i}" title="${esc(st.loc.name)}: ${esc(fieldText(st).replace(/<[^>]+>/g, ''))}">`
            + `${esc(st.loc.name)}${ok ? '' : ' <span aria-label="not ready">!</span>'}</button>`;
    }).join('') : '';
    $('.sat-site-tabs').html(html).toggle(S.sites.length > 1);
}

/* ---------- locations ---------- */

function renderLocations() {
    const q = ($('#sat_loc_search').val() || '').toLowerCase();
    const counts = {};
    S.locations.forEach(l => { counts[typeOf(l)] = (counts[typeOf(l)] || 0) + 1; });
    segs('#sat_loc_types', LOC_TYPES.map(([v, l]) => [v, v === 'all' ? `${l} (${S.locations.length})` : `${l} (${counts[v] || 0})`, v !== 'all' && !counts[v]]),
        S.typeFilter, v => { S.typeFilter = v; renderLocations(); });
    const chosen = new Set(S.sites.map(st => String(st.loc.id)));
    const list = S.locations.filter(l => (S.typeFilter === 'all' || typeOf(l) === S.typeFilter)
        && (!q || [l.name, l.abbreviation, l.country, l.program, l.type].join(' ').toLowerCase().includes(q)));
    $('#sat_locations').html(list.length ? list.map(l => {
        const meta = [l.type, l.country, l.trials ? `${l.trials} trial${l.trials === 1 ? '' : 's'}` : '', hasXY(l) ? '' : 'no coordinates'].filter(Boolean).join(' · ');
        const on = chosen.has(String(l.id));
        return `<a class="sat-loc${on ? ' on' : ''}${hasXY(l) ? '' : ' dis'}" data-id="${esc(l.id)}" role="checkbox" aria-checked="${on}">`
            + `<span class="sat-loc-check">${on ? '&#10003;' : ''}</span>${esc(l.name)}<small>${esc(meta)}</small></a>`;
    }).join('') : '<span class="sat-muted sat-small">No location found.</span>');
    $('#sat_selected').html(S.sites.length
        ? `<span class="sat-label" style="margin:0 6px 0 0;display:inline">Selected (${S.sites.length}):</span>` + S.sites.map((st, i) =>
            `<span class="sat-chip">${esc(st.loc.name)}<button type="button" class="sat-chip-x" data-i="${i}" aria-label="Remove ${esc(st.loc.name)}">&times;</button></span>`).join('')
            + (S.sites.length > 1 ? ' <button type="button" class="btn btn-link btn-xs" id="sat_clear_sites">remove all</button>' : '')
        : '<span class="sat-muted sat-small">Click the locations to analyse: one, or keep adding farms and stations.</span>');
}

function toggleLocation(id) {
    const i = S.sites.findIndex(st => String(st.loc.id) === String(id));
    if (i >= 0) { removeSite(i); return; }
    const loc = S.locations.find(l => String(l.id) === String(id));
    if (!loc) return;
    saveSite();
    const st = newSite(loc);
    S.sites.push(st);
    loadSite(S.sites.length - 1);
    renderLocations();
    renderTrialSelect();
    renderControls();
    loadSiteData(st);
}

function removeSite(i) {
    const st = S.sites[i];
    if (!st) return;
    if (st.trialDirty && !confirm(`${st.loc.name} has a trial field drawn but not saved. Remove it anyway?`)) return;
    if (i === S.cur && S.running) { if (S.abort) S.abort.abort(); S.run++; S.running = false; busyEnd(P.token); }
    saveSite();
    S.sites.splice(i, 1);
    if (!S.sites.length) { S.cur = -1; Object.assign(S, newSite({ id: null, name: '' }), { loc: null, point: null }); }
    else loadSite(Math.min(i <= S.cur ? Math.max(S.cur - 1, 0) : S.cur, S.sites.length - 1));
    renderLocations();
    renderTrialSelect();
    renderControls();
    renderSiteTabs();
}

/** Trials and saved farm fields of a new site. */
async function loadSiteData(st) {
    // farm fields are drawn for each analysis (not kept with the location)
    const trials = await getJSON('trials', { location_id: st.loc.id }).then(r => r.trials).catch(() => []);
    if (!S.sites.includes(st)) return;
    siteSet(st, { trials });
    refreshField(st);
    if (S.sites[S.cur] === st) { renderTrialSelect(); if (S.step === 2) drawMap(true); }
    renderControls();
    renderSiteTabs();
}

function renderTrialSelect() {
    const t = S.trials;
    if (!S.loc) { $('#sat_trial').html('').prop('disabled', true); return; }
    if (t === null) { $('#sat_trial').html('<option value="">Loading trials…</option>').prop('disabled', true); return; }
    $('#sat_trial').html(t.length
        ? '<option value="">Choose a trial</option>' + t.map(x => `<option value="${esc(x.id)}"${S.trial && S.trial.id == x.id ? ' selected' : ''}>${esc(x.name)}${x.year ? ` (${esc(x.year)})` : ''}</option>`).join('')
        : '<option value="">No trial at this location</option>').prop('disabled', !t.length);
}

async function chooseTrial(id) {
    const st = S.sites[S.cur];
    if (S.trialDirty && !confirm('The field drawn for this trial is not saved. Choose another trial anyway?')) { renderTrialSelect(); return; }
    const t = (S.trials || []).find(x => x.id == id) || null;
    siteSet(st, { trial: t, trialPlots: null, trialDrawn: null, trialCanEdit: 0, trialDirty: false });
    refreshField(st);
    if (t) {
        try {
            const f = await getJSON('field', { trial_id: t.id });
            if (st.trial !== t && S.trial !== t) return;
            siteSet(st, { trialPlots: f.count ? f : null, trialDrawn: f.drawn ? f.drawn.slice(0, -1) : null, trialCanEdit: f.can_edit ? 1 : 0 });
        } catch (e) { /* no coordinates */ }
        refreshField(st);
        // the trial's season fills the dates only while they are still the default (never over dates the user chose)
        if (t.planting && !S.datesTouched) setPreset('trial');
    }
    renderControls();
    if (S.sites[S.cur] === st) drawMap(true);
}

function setMode(m) {
    if (m === 'trial' && !(S.trials || []).length) return;
    if (S.draw.active) endDraw();
    S.mode = m;
    if (m !== 'trial') { S.trial = null; S.trialPlots = null; S.trialDrawn = null; S.trialDirty = false; $('#sat_trial').val(''); }
    refreshField();
    renderControls();
    drawMap(true);
}

/* ---------- fields: trial plots, a drawn trial field, the farm's fields ---------- */

function ringsBox(rings) {
    const pts = rings.flat();
    return [Math.min(...pts.map(p => p[0])), Math.min(...pts.map(p => p[1])), Math.max(...pts.map(p => p[0])), Math.max(...pts.map(p => p[1]))];
}

function ringHa(ring) {
    if (ring.length < 3) return 0;
    const lat0 = ring.reduce((t, p) => t + p[1], 0) / ring.length;
    const kx = 111320 * Math.cos(lat0 * Math.PI / 180), ky = 110574;
    let a = 0;
    ring.forEach((p, i) => { const q = ring[(i + 1) % ring.length]; a += p[0] * kx * q[1] * ky - q[0] * kx * p[1] * ky; });
    return Math.abs(a) / 2 / 10000;
}

/** The field of a site from its mode: { kind: plots | drawn | farm, plots (rings), bbox, count, ha } or null. */
function fieldOf(st) {
    if (st.mode === 'trial' && st.trialPlots) return { kind: 'plots', plots: st.trialPlots.plots, bbox: st.trialPlots.bbox, count: st.trialPlots.count };
    if (st.mode === 'trial' && st.trial && st.trialDrawn) return { kind: 'drawn', plots: [st.trialDrawn], bbox: ringsBox([st.trialDrawn]), count: 1, ha: ringHa(st.trialDrawn) };
    if (st.mode === 'fields' && st.farmFields.length) {
        const rings = st.farmFields.map(f => f.ring);
        return { kind: 'farm', plots: rings, bbox: ringsBox(rings), count: rings.length, ha: rings.reduce((t, r) => t + ringHa(r), 0) };
    }
    return null;
}

function refreshField(st) {
    st = st || S.sites[S.cur];
    if (!st) return;
    if (S.sites[S.cur] === st) saveSite();
    siteSet(st, { field: fieldOf(st) });
}

/* ---------- drawing on the map ---------- */

/** Drawing on the step-2 map (where 'field': farm / trial fields) or the step-5 map ('model': examples, fields). */
function drawMapOf(where) { return where === 'model' ? [S.mmap, '#sat_model_map'] : [S.map, '#sat_map']; }

function redrawAfterDraw(where) {
    if (where === 'model') { renderModel(); drawModelMap(false); } else { renderControls(); drawMap(false); }
}

/** Leaving a drawing (other step, location, mode, new drawing): kept as finished when it has 3 corners or more, else dropped. */
function endDraw() {
    if (S.draw.active && S.draw.pts.length >= 3 && ringHa(S.draw.pts) >= 0.01) finishDraw();
    else cancelDraw();
}

function startDraw(target, where) {
    where = where || 'field';
    if (S.draw.active) endDraw();
    S.fieldMsg = '';
    S.draw = { active: true, pts: [], target, where };
    const [m, el] = drawMapOf(where);
    if (m) { m.doubleClickZoom.disable(); $(el).addClass('sat-drawing'); }
    redrawAfterDraw(where);
}

function cancelDraw() {
    const where = S.draw.where;
    S.draw = { active: false, pts: [], target: null, where: 'field' };
    const [m, el] = drawMapOf(where);
    if (m) { m.doubleClickZoom.enable(); $(el).removeClass('sat-drawing'); }
    redrawAfterDraw(where);
}

function finishDraw() {
    const pts = S.draw.pts, where = S.draw.where, target = S.draw.target;
    if (pts.length < 3) { alert('An area needs at least 3 corners.'); return; }
    if (ringHa(pts) < 0.01) { alert('This area is smaller than 0.01 ha.'); return; }
    if (where === 'model') {
        finishModelDraw(target, pts.slice());
        S.draw = { active: false, pts: [], target: null, where: 'field' };
        const [m, el] = drawMapOf('model');
        if (m) { m.doubleClickZoom.enable(); $(el).removeClass('sat-drawing'); }
        redrawAfterDraw('model');
        return;
    }
    if (target === 'trial') {
        S.trialDrawn = pts.slice(); S.trialDirty = true;
    } else {
        const used = new Set(S.farmFields.map(f => f.name.toLowerCase()));
        let k = S.farmFields.length + 1;
        while (used.has(`field ${k}`)) k++;
        S.farmFields = S.farmFields.concat([{ name: `Field ${k}`, ring: pts.slice() }]);
        S.fieldsDirty = true;
    }
    S.draw = { active: false, pts: [], target: null, where: 'field' };
    if (S.map) { S.map.doubleClickZoom.enable(); $('#sat_map').removeClass('sat-drawing'); }
    refreshField();
    renderControls();
    drawMap(false);
}

async function saveTrialField(remove) {
    const st = S.sites[S.cur], t = S.trial;
    try {
        await postJSON('trial_field', { trial_id: t.id, ring: remove ? '' : JSON.stringify(S.trialDrawn) });
        siteSet(st, { trialDirty: false, trialDrawn: remove ? null : S.trialDrawn });
        refreshField(st);
        fieldMsg(remove ? `The field of ${esc(t.name)} was removed.` : `The field was saved with the trial ${esc(t.name)}.`);
    } catch (err) { fieldMsg(esc(err.message), true); }
    renderControls();
    drawMap(false);
}

/** A message under the field tools; kept until the next field action or site change (the box is redrawn often). */
function fieldMsg(html, isError) {
    S.fieldMsg = html ? `<span class="${isError ? 'text-danger' : 'text-success'}">${html}</span>` : '';
    $('#sat_field_msg').html(S.fieldMsg);
}

/** The drawing tools and the list of fields of the current site (step 2). */
function renderDrawBox() {
    const box = $('#sat_draw_box');
    const drawing = S.draw.active && S.draw.where === 'field';
    let html = '';
    if (S.mode === 'fields') {
        html += `<div class="sat-draw-head"><b>Production fields of ${esc(S.loc ? S.loc.name : '')}</b>`
            + (drawing ? '' : ' <button type="button" class="btn btn-default btn-xs" id="sat_draw_farm">+ Draw a field</button>') + '</div>';
        if (S.farmFields.length) {
            html += '<table class="table table-condensed sat-fields-table"><tbody>' + S.farmFields.map((f, i) =>
                `<tr><td><input type="text" class="form-control input-sm sat-field-name" data-i="${i}" value="${esc(f.name)}" maxlength="100" aria-label="Field name" /></td>`
                + `<td class="sat-muted">${ringHa(f.ring).toFixed(2)} ha</td>`
                + `<td><button type="button" class="btn btn-link btn-xs sat-field-del" data-i="${i}" aria-label="Delete ${esc(f.name)}">delete</button></td></tr>`).join('')
                + '</tbody></table>';
        } else if (!drawing) {
            html += '<div class="sat-muted sat-small">No field drawn yet: the analysis uses the square around the location. Draw the fields to analyse exactly them (for this analysis).</div>';
        }
    } else if (S.mode === 'trial' && S.trial && !S.trialPlots) {
        html += `<div class="sat-draw-head"><b>Field of ${esc(S.trial.name)}</b>`;
        if (!drawing) html += S.trialDrawn
            ? ' <button type="button" class="btn btn-default btn-xs" id="sat_draw_trial">Draw again</button>'
            : ' <button type="button" class="btn btn-default btn-xs" id="sat_draw_trial">Draw the trial field</button>';
        html += '</div>';
        if (S.trialDrawn) html += `<div class="sat-small">${ringHa(S.trialDrawn).toFixed(2)} ha${S.trialDirty ? ' · <span class="text-warning">not saved yet</span>' : ' · saved with the trial'}</div>`;
        else if (!drawing) html += '<div class="sat-muted sat-small">This trial has no plot GPS coordinates. Draw its field once (it is saved with the trial), or click the map to centre a square on it.</div>';
        if (S.trialCanEdit && S.trialDrawn) {
            html += '<div class="sat-draw-save">'
                + (S.trialDirty ? '<button type="button" class="btn btn-primary btn-xs" id="sat_trial_save">Save field with the trial</button> ' : '')
                + (!S.trialDirty ? '<button type="button" class="btn btn-link btn-xs" id="sat_trial_remove">remove saved field</button>' : '') + '</div>';
        } else if (S.trialDirty) {
            html += '<div class="sat-small text-warning">Used in this analysis; saving it with the trial needs the curator role or the submitter role in its breeding program.</div>';
        }
    }
    if (drawing) {
        html += `<div class="sat-draw-active"><b>Drawing:</b> click the corners of the field on the map (${S.draw.pts.length} so far); double-click the last corner or press Finish.`
            + ` <button type="button" class="btn btn-primary btn-xs" id="sat_draw_finish"${S.draw.pts.length < 3 ? ' disabled' : ''}>Finish</button>`
            + ' <button type="button" class="btn btn-default btn-xs" id="sat_draw_undo"' + (S.draw.pts.length ? '' : ' disabled') + '>Undo corner</button>'
            + ' <button type="button" class="btn btn-link btn-xs" id="sat_draw_cancel">Cancel</button></div>';
    }
    html += `<div id="sat_field_msg" class="sat-small" style="margin-top:4px">${S.fieldMsg || ''}</div>`;
    box.html(html).toggle(!!html && (S.mode === 'fields' || (S.mode === 'trial' && !!S.trial && !S.trialPlots)));
}

/* ---------- area, dates, view ---------- */

/** The square shown: { lat, lon, sizeM, fromPlots } or null. */
function area() { return areaOf(S); }

function areaOf(st) {
    if (!st || !st.loc) return null;
    if (st.field) {
        const [w, s, e, n] = st.field.bbox;
        const lat = (s + n) / 2, lon = (w + e) / 2;
        const mx = (e - w) * 111320 * Math.cos(lat * Math.PI / 180), my = (n - s) * 110574;
        const size = Math.min(MAX_AREA, Math.max(500, Math.ceil((Math.max(mx, my) + 2 * FIELD_MARGIN) / 100) * 100));
        return { lat, lon, sizeM: size, fromPlots: true, kind: st.field.kind };
    }
    if (st.mode === 'trial' && !st.trial) return null;
    if (!st.point) return null;
    return { lat: st.point.lat, lon: st.point.lon, sizeM: st.size, fromPlots: false };
}

function trialSeason() {
    const t = S.trial;
    if (!t || !t.planting) return null;
    const start = addDays(t.planting, -15);
    let end = t.harvest ? addDays(t.harvest, 15) : addDays(t.planting, 240);
    if (end > today()) end = today();
    return start <= end ? [start, end] : null;
}

function setPreset(p) {
    const end = today();
    let range;
    if (p === '3m') range = [addDays(end, -91), end];
    else if (p === '6m') range = [addDays(end, -182), end];
    else if (p === '12m') range = [addDays(end, -365), end];
    else if (p === 'year') range = [end.slice(0, 4) + '-01-01', end];
    else if (p === 'trial') range = trialSeason();
    if (!range) return;
    S.preset = p;
    [S.start, S.end] = range;
    $('#sat_start').val(S.start); $('#sat_end').val(S.end);
    renderControls();
}

function segs(sel, items, current, onClick) {
    $(sel).html(items.map(([v, label, disabled, title]) =>
        `<button type="button" class="sat-seg${v === current ? ' on' : ''}" data-v="${esc(v)}"${disabled ? ' disabled' : ''}${title ? ` title="${esc(title)}"` : ''}>${esc(label)}</button>`).join(''));
    $(sel).off('click').on('click', '.sat-seg:not([disabled])', function () { onClick($(this).data('v')); });
}

function options(sel, current, disabled) {
    $(`${sel} .sat-option`).each(function () {
        const v = $(this).data('v');
        $(this).toggleClass('on', v === current).toggleClass('disabled', !!(disabled && disabled[v]));
        $(this).find('input').prop('checked', v === current).prop('disabled', !!(disabled && disabled[v]));
    });
}

function renderControls() {
    const a = area();
    options('#sat_field_mode', S.mode, { trial: !(S.trials || []).length });
    $('#sat_field_mode .sat-option[data-v="fields"] .sat-option-text').text(S.farmFields.length
        ? `${S.farmFields.length} field${S.farmFields.length === 1 ? '' : 's'} drawn (${S.farmFields.reduce((t, f) => t + ringHa(f.ring), 0).toFixed(1)} ha). Draw, rename or delete fields.`
        : 'Draw the fields of the farm on the map, for this analysis.');
    $('#sat_field_loc').text(S.loc ? S.loc.name : '');
    $('#sat_trial_box').toggle(S.mode === 'trial');
    $('#sat_size_box').toggle(!S.field);
    renderDrawBox();
    segs('#sat_size', SIZES.map(([v, l]) => [v, l]), S.size, v => { S.size = +v; renderControls(); drawMap(false); });
    const season = trialSeason();
    segs('#sat_presets', [['3m', 'Last 3 months'], ['6m', 'Last 6 months'], ['year', 'This year (YTD)'], ['12m', 'Last 12 months'],
        ['trial', 'Trial season', !season, season ? `${season[0]} to ${season[1]} (planting − 15 days to harvest + 15 days)` : 'Choose a trial with a planting date in step 2']], S.preset, p => { S.datesTouched = true; setPreset(p); datesChanged(true); });
    options('#sat_view', S.view);
    $('#sat_sources').html(S.offered.length ? S.offered.map(o => {
        const on = !!S.sources[o.id];
        const every = o.revisit === 1 ? 'about every day' : `about every ${o.revisit} days`;
        return `<label class="sat-option${on ? ' on' : ''}" data-v="${esc(o.id)}"><input type="checkbox"${on ? ' checked' : ''} />`
            + `<span class="sat-option-title">${esc(o.name)}</span><span class="sat-option-text">${esc(o.res)} m pixels, a new image ${every}, since ${esc(o.since)}. ${esc((SOURCES[o.id] || {}).text || '')}</span></label>`;
    }).join('') : '<span class="sat-muted sat-small">Loading…</span>');
    $('#sat_go').prop('disabled', !chosenSources().length);
    $('#sat_cloudy, #sat_cloudy4').prop('checked', S.showCloudy);
    let hint = '';
    if (S.draw.active) hint = '<b>Click the corners of the field</b> on the map.';
    else if (S.field && S.field.kind === 'plots') hint = `Yellow: the ${S.field.count} plots of this trial (from their GPS coordinates). Only the area of the plots is analysed; cloud is measured there.`;
    else if (S.field) hint = `Yellow: the field${S.field.count === 1 ? '' : 's'}. Only ${S.field.count === 1 ? 'it is' : 'they are'} analysed; cloud is measured over ${S.field.count === 1 ? 'it' : 'them'} only.`;
    else if (S.mode === 'trial' && !S.trial) hint = 'Choose a trial.';
    else if (S.mode === 'trial') hint = 'No plot coordinates and no field drawn: <b>click the map on the field</b> to centre the square on it, or draw the field. Cloud is measured over the whole square.';
    else if (a) hint = 'Red: the location. Blue square: the area analysed. <b>Click the map on the field</b> to move it, or draw the field to analyse exactly it. Cloud is measured over the whole square.';
    else if (S.loc) hint = '<b>This location has no latitude/longitude.</b> Click the map on the field, or add them in Manage &gt; Locations.';
    $('#sat_map_hint').html(hint);
    renderStepper();
}

/* ---------- map ---------- */

function squareBounds(a) {
    const half = a.sizeM / 2;
    const dLat = half / 110574, dLon = half / (111320 * Math.cos(a.lat * Math.PI / 180));
    return [[a.lat - dLat, a.lon - dLon], [a.lat + dLat, a.lon + dLon]];
}

/** A "Full screen" button on a Leaflet map: the map fills the window (drawing fields is easier); Esc or the button returns. */
function addFullscreen(map, el) {
    const Ctl = L.Control.extend({
        options: { position: 'topright' },
        onAdd() {
            const b = L.DomUtil.create('button', 'sat-full-btn');
            b.type = 'button';
            b.textContent = '⤢ Full screen';
            b.title = 'Show the map on the whole screen (Esc returns)';
            L.DomEvent.disableClickPropagation(b);
            L.DomEvent.on(b, 'click', () => toggleFullscreen(map, el, b));
            return b;
        },
    });
    map.addControl(new Ctl());
}

function toggleFullscreen(map, el, btn, off) {
    const $el = $(el);
    const full = off ? false : !$el.hasClass('sat-map-full');
    $el.toggleClass('sat-map-full', full);
    $('body').css('overflow', full ? 'hidden' : '');
    const b = btn || $el.find('.sat-full-btn')[0];
    if (b) b.textContent = full ? '⤡ Exit full screen' : '⤢ Full screen';
    // fit the area to the new size (not while drawing: the view must not jump)
    setTimeout(() => { map.invalidateSize(); if (map === S.map) drawMap(true); else if (map === S.mmap) drawModelMap(true); }, 50);
}

function drawMap(fit) {
    // only on the visible step-2 map: Leaflet measures its box when drawing, and a hidden
    // box (size 0) would zoom out to the whole world
    if (!$('#sat_map').is(':visible')) return;
    if (!S.map) {
        // quarter zoom steps: the area fills the map instead of stopping one whole step out
        S.map = L.map('sat_map', { scrollWheelZoom: false, zoomSnap: 0.25, zoomDelta: 0.5 }).setView([0, 0], 2);
        addFullscreen(S.map, '#sat_map');
        L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 19, attribution: 'Imagery &copy; Esri, Maxar, Earthstar Geographics',
        }).addTo(S.map);
        S.layers = L.layerGroup().addTo(S.map);
        S.map.on('click', ev => {
            if (S.draw.active && S.draw.where === 'field') {
                S.draw.pts.push([ev.latlng.lng, ev.latlng.lat]);
                renderDrawBox();
                drawMap(false);
                return;
            }
            if (!S.loc || S.field) return;   // the area is set by the plots / fields
            S.point = { lat: ev.latlng.lat, lon: ev.latlng.lng };
            renderControls();
            drawMap(false);
        });
        S.map.on('dblclick', () => { if (S.draw.active && S.draw.where === 'field' && S.draw.pts.length >= 3) finishDraw(); });
    }
    S.map.invalidateSize();
    S.layers.clearLayers();
    const loc = S.loc;
    if (loc && isFinite(parseFloat(loc.lat))) {
        L.circleMarker([parseFloat(loc.lat), parseFloat(loc.lon)], { radius: 6, color: '#fff', weight: 2, fillColor: '#dc2626', fillOpacity: 1 })
            .bindTooltip(esc(loc.name)).addTo(S.layers);
    }
    if (S.field) {
        const names = S.field.kind === 'farm' ? S.farmFields.map(f => f.name) : [];
        S.field.plots.forEach((r, i) => {
            if (r.length === 1) L.circleMarker([r[0][1], r[0][0]], { radius: 2, color: '#facc15', weight: 1 }).addTo(S.layers);
            else {
                const pg = L.polygon(r.map(p => [p[1], p[0]]), { color: '#facc15', weight: S.field.kind === 'plots' ? 1 : 2, fillOpacity: 0.15 }).addTo(S.layers);
                if (names[i]) pg.bindTooltip(esc(names[i]));
            }
        });
    }
    // other selected locations, for orientation
    S.sites.forEach((st, i) => {
        if (i === S.cur || !hasXY(st.loc)) return;
        L.circleMarker([parseFloat(st.loc.lat), parseFloat(st.loc.lon)], { radius: 5, color: '#fff', weight: 2, fillColor: '#6b7280', fillOpacity: 1 })
            .bindTooltip(esc(st.loc.name)).addTo(S.layers);
    });
    if (S.draw.active && S.draw.where === 'field' && S.draw.pts.length) {
        const ll = S.draw.pts.map(p => [p[1], p[0]]);
        if (ll.length > 1) L.polyline(ll.concat(ll.length > 2 ? [ll[0]] : []), { color: '#f97316', weight: 2, dashArray: ll.length > 2 ? null : '4 3' }).addTo(S.layers);
        ll.forEach(p => L.circleMarker(p, { radius: 4, color: '#fff', weight: 1, fillColor: '#f97316', fillOpacity: 1 }).addTo(S.layers));
    }
    const a = area();
    if (a) {
        const b = squareBounds(a);
        // the square is the selected area only when no field is delimited
        if (!S.field) L.rectangle(b, { color: '#22d3ee', weight: 2, fill: false, interactive: false }).addTo(S.layers);
        if (fit && !S.draw.active) S.map.fitBounds(L.latLngBounds(b).pad(0.15));
    } else if (fit) {
        S.map.setView([0, 0], 2);
    }
    setTimeout(() => S.map.invalidateSize(), 0);
}

/* ---------- scenes ---------- */

function queue(items, limit, fn) {
    let i = 0;
    const worker = async () => { while (i < items.length) { const it = items[i++]; await fn(it); } };
    return Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
}

/** Geometry of the area in a scene's UTM grid. */
function sceneGeom(scene, a) {
    const utm = utmOfEpsg(scene.epsg);
    if (!utm) throw new Error(`Unexpected projection EPSG:${scene.epsg}`);
    const [e, n] = latLonToUtm(a.lat, a.lon, utm.zone, utm.south);
    let plots = null, box = null, polys = null;
    if (S.field) {
        plots = S.field.plots.map(r => r.map(p => latLonToUtm(p[1], p[0], utm.zone, utm.south)));
        const all = plots.flat();
        box = [Math.min(...all.map(p => p[0])), Math.min(...all.map(p => p[1])), Math.max(...all.map(p => p[0])), Math.max(...all.map(p => p[1]))];
        // the outlines clouds are measured in: each field, or the area around all the trial plots
        polys = S.field.kind === 'plots' ? [hull(all)] : plots;
        polys = polys.filter(r => r.length >= 3);
    }
    return { e, n, utm, plots, box, polys };
}

/** True when the point (UTM) is inside one of the outlines (ray casting). */
function insidePolys(polys, px, py) {
    return polys.some(r => {
        let c = false;
        for (let i = 0, j = r.length - 1; i < r.length; j = i++) {
            if ((r[i][1] > py) !== (r[j][1] > py) && px < (r[j][0] - r[i][0]) * (py - r[i][1]) / ((r[j][1] - r[i][1]) || 1e-12) + r[i][0]) c = !c;
        }
        return c;
    });
}

/** Pixel rectangle of the field (plots bounding box or the whole window) in a window. */
function fieldRect(win, g) {
    if (!g.box) return [0, 0, win.w, win.h];
    const x0 = Math.max(0, Math.floor((g.box[0] - win.left) / win.res)), x1 = Math.min(win.w, Math.ceil((g.box[2] - win.left) / win.res));
    const y0 = Math.max(0, Math.floor((win.top - g.box[3]) / win.res)), y1 = Math.min(win.h, Math.ceil((win.top - g.box[1]) / win.res));
    return [x0, y0, Math.max(x1, x0 + 1), Math.max(y1, y0 + 1)];
}

/* ---------- Landsat read token ---------- */

/** A Landsat token valid for at least 5 more minutes (the server's, or a fresh one). */
async function landsatToken() {
    const t = S.landsatToken;
    if (t && Date.parse(t.expiry) - Date.now() > 5 * 60 * 1000) return t.token;
    if (!S.tokenFetch) {
        S.tokenFetch = getJSON('landsat_token').then(r => { S.landsatToken = r; return r.token; })
            .finally(() => { S.tokenFetch = null; });
    }
    return S.tokenFetch;
}

/** Url of a scene's image (asset name: visual, red, green, blue, nir, scl, qa). */
async function imageUrl(sc, key) {
    if (sc.source !== 'landsat') return sc[key];
    return `${sc[key]}?${await landsatToken()}`;
}

async function openImage(sc, key, signal) {
    return openCog(await imageUrl(sc, key), signal);
}

async function analyse(scene, a, signal) {
    const g = sceneGeom(scene, a);
    const isLandsat = scene.source === 'landsat';
    const cog = await openImage(scene, isLandsat ? 'qa' : 'scl', signal);
    const win = windowFor(cog, g.e, g.n, a.sizeM);
    const r = await readWindow(cog, win.x0, win.y0, win.w, win.h, signal);
    const toCode = isLandsat ? qaCode : sclCode;
    const mask = new Uint8Array(win.w * win.h);
    for (let i = 0; i < mask.length; i++) mask[i] = toCode(r.data[i]);
    const [x0, y0, x1, y1] = fieldRect(win, g);
    // only the pixels inside the fields count (clouds outside them are ignored); a field
    // smaller than one pixel falls back to the pixels under its box
    const polys = g.polys && g.polys.length ? g.polys : null;
    const inPoly = (px, py) => insidePolys(polys, px, py);
    let total = 0, valid = 0, cloud = 0, usedPolys = false;
    for (let pass = 0; pass < 2 && !total; pass++) {
      usedPolys = pass === 0 && !!polys;
      for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
            if (pass === 0 && polys && !inPoly(win.left + (x + 0.5) * win.res, win.top - (y + 0.5) * win.res)) continue;
            const m = mask[y * win.w + x];
            total++;
            if (m === M_NODATA) continue;
            valid++;
            if (m === M_CLOUD) cloud++;
        }
      }
    }
    return {
        g, mask, maskWin: win, usedPolys,
        validPct: total ? Math.round(100 * valid / total) : 0,
        clearPct: valid ? Math.round(100 * (valid - cloud) / valid) : 0,
    };
}

function isClear(info) { return info && !info.error && info.validPct >= VALID_MIN && info.clearPct >= CLEAR_MIN; }
function isShown(info) { return info && !info.error && info.validPct >= VALID_MIN && (S.showCloudy || info.clearPct >= CLEAR_MIN); }

/** What the images of the shown site depend on: they are searched again when it changes. */
function runKey() {
    return JSON.stringify([area(), S.field ? S.field.plots : null, S.start, S.end, chosenSources()]);
}

/**
 * Step 4 for the site shown: the images already loaded for the current choices, or (load) a new
 * search. Images are only searched on a quick choice or the Load images button, never on opening the step.
 */
function showSiteImages(load) {
    renderSiteTabs();
    renderAna();
    $('#sat_site_name').text(S.sites.length > 1 && S.loc ? S.loc.name : '');
    $('#sat_load').removeClass('btn-primary').addClass('btn-default');
    if (S.runKey === runKey() && S.scenes.length) {
        busyEnd(P.token);
        drawTimeline();
        renderStats();
        renderImages();
        return;
    }
    if (load) { run(); return; }
    // nothing loaded for these choices yet: ask
    if (S.running) { if (S.abort) S.abort.abort(); S.run++; S.running = false; busyEnd(P.token); }
    S.scenes = []; S.info = {}; S.visible = [];
    $('#sat_grid').empty(); $('#sat_timeline').empty(); $('#sat_tl_labels').empty(); $('#sat_legend').empty(); $('#sat_ndvi_block').hide(); $('#sat_stats').empty();
    status(`Choose a quick choice above, or set the dates and press <b>Load images</b>${S.start && S.end ? ` (now ${fmtDate(S.start)} – ${fmtDate(S.end)})` : ''}.`);
    $('#sat_load').removeClass('btn-default').addClass('btn-primary');
}

async function run() {
    const a = area();
    if (!a) return;
    S.start = $('#sat_start').val(); S.end = $('#sat_end').val();
    if (!S.start || !S.end || S.start > S.end) { alert('Choose a start date before the end date.'); return; }
    if (S.abort) S.abort.abort();
    const ctrl = new AbortController();
    S.abort = ctrl;
    const runId = ++S.run;
    S.running = true;
    S.runKey = runKey();
    S.scenes = []; S.info = {}; S.visible = []; S.area = a;
    if (S.step !== 4) { S.step = 4; $('.sat-pane').hide(); $('.sat-pane[data-step="4"]').show(); renderStepper(); renderSiteTabs(); }
    $('#sat_grid').empty(); $('#sat_timeline').empty(); $('#sat_tl_labels').empty(); renderStats();
    $('#sat_ndvi_block').hide(); $('#sat_legend').empty();
    const names = chosenSources().map(k => SOURCES[k].name).join(' and ');
    S.warnings = [];
    const tok = busyStart();
    status('');
    busyStep(tok, `Searching the ${names} archive${chosenSources().length > 1 ? 's' : ''}…`);
    const [[s, w], [n, e]] = squareBounds(a);
    let res;
    try {
        res = await getJSON('scenes', { west: w.toFixed(6), south: s.toFixed(6), east: e.toFixed(6), north: n.toFixed(6), start: S.start, end: S.end, sources: chosenSources().join(',') });
    } catch (err) { if (runId === S.run) { S.running = false; S.runKey = null; busyEnd(tok); status(esc(err.message), true); } return; }
    if (runId !== S.run) return;
    const scenes = res.scenes;
    S.scenes = scenes;
    S.warnings = res.warnings || [];
    if (res.landsat_token) S.landsatToken = res.landsat_token;
    if (!scenes.length) { S.running = false; busyEnd(tok); status(`No ${names} image in this date range.${warningText()}`); renderStats(); return; }
    drawTimeline();
    let done = 0;
    status(`${scenes.length} dates found.${warningText()}`);
    busyStep(tok, 'Measuring cloud over the field…', 0, scenes.length);
    await queue(scenes, 6, async sc => {
        if (runId !== S.run) return;
        try { S.info[sc.id] = await analyse(sc, a, ctrl.signal); }
        catch (err) { if (err.name !== 'AbortError') S.info[sc.id] = { error: err.message }; }
        if (runId !== S.run) return;
        done++;
        busyStep(tok, 'Measuring cloud over the field…', done, scenes.length);
        drawTimeline();
        renderStats();
    });
    if (runId !== S.run) return;
    await renderImages();
    if (runId === S.run) S.running = false;
}

function renderStats() {
    const a = S.area;
    const measured = S.scenes.filter(sc => S.info[sc.id]).length;
    const clear = S.scenes.filter(sc => isClear(S.info[sc.id])).length;
    const peaks = S.visible.map(sc => ((S.info[sc.id] || {}).images || {}).ndvi).filter(b => b && b.ndvi !== null).map(b => b.ndvi);
    const tiles = [
        [S.scenes.length, 'dates found'],
        [measured < S.scenes.length ? `${clear}<small style="font-size:13px"> …</small>` : clear, 'clear over the field'],
        [a ? `${(a.sizeM / 1000).toFixed(1)}<small style="font-size:13px"> km</small>` : '–', !a || !a.fromPlots ? 'square shown' : a.kind === 'plots' ? 'square around the plots' : 'square around the fields'],
    ];
    if (S.view === 'ndvi' && S.scenes.length) tiles.push([peaks.length ? Math.max(...peaks).toFixed(2) : '–', 'highest NDVI']);
    $('#sat_stats').html(tiles.map(([v, l]) => `<div class="sat-stat"><div class="v">${v}</div><div class="l">${l}</div></div>`).join(''));
    renderFlow();
}

/* ---------- progress: spinner, phase, bar and elapsed time while the page works ---------- */

const P = { token: 0, t0: 0, timer: null };

function elapsedText() {
    const sec = Math.round((Date.now() - P.t0) / 1000);
    return sec < 60 ? `${sec} s` : `${Math.floor(sec / 60)} min ${String(sec % 60).padStart(2, '0')} s`;
}

/** Show the progress row; keepClock: same job going on (search -> images), the clock goes on. Returns a token. */
function busyStart(keepClock) {
    P.token++;
    if (!keepClock || !P.timer) P.t0 = Date.now();
    clearInterval(P.timer);
    P.timer = setInterval(() => $('#sat_elapsed').text(elapsedText()), 1000);
    $('#sat_elapsed').text(elapsedText());
    $('#sat_progress').show();
    return P.token;
}

/** Phase text and, with a total, how far (no total: moving bar). Ignored for an older job. */
function busyStep(token, text, done, total) {
    if (token !== P.token) return;
    $('#sat_progress_text').html(text);
    const bar = $('#sat_progress .sat-bar');
    if (total) {
        bar.removeClass('indet').children().css('width', `${Math.round(100 * done / total)}%`);
        $('#sat_progress_count').text(`${done}/${total}`);
    } else {
        bar.addClass('indet').children().css('width', '');
        $('#sat_progress_count').text('');
    }
}

/** Hide the progress row; returns the time taken ('' for an older job). */
function busyEnd(token) {
    if (token !== P.token) return '';
    clearInterval(P.timer);
    P.timer = null;
    $('#sat_progress').hide();
    return elapsedText();
}

function warningText() {
    return S.warnings.map(w => ` <span class="text-warning">${esc(w)}</span>`).join('');
}

function status(html, isError) {
    $('#sat_status').html(isError ? `<span class="text-danger">${html}</span>` : html);
}

function summary() {
    const n = S.scenes.length;
    const clear = S.scenes.filter(sc => isClear(S.info[sc.id])).length;
    const out = S.scenes.filter(sc => S.info[sc.id] && !S.info[sc.id].error && S.info[sc.id].validPct < VALID_MIN).length;
    const err = S.scenes.filter(sc => S.info[sc.id] && S.info[sc.id].error).length;
    const parts = [`<b>${n}</b> dates from ${fmtDate(S.start)} to ${fmtDate(S.end)}`];
    const bySource = Object.keys(SOURCES).map(k => [k, S.scenes.filter(sc => sc.source === k).length]).filter(([, c]) => c);
    if (bySource.length > 1) parts[0] += ` (${bySource.map(([k, c]) => `${c} ${SOURCES[k].name}`).join(', ')})`;
    parts.push(`<b>${clear}</b> clear over the field (≥ ${CLEAR_MIN}% without cloud)`);
    if (out) parts.push(`${out} with the field outside the image`);
    if (err) parts.push(`<span class="text-danger">${err} could not be read</span>`);
    const hid = S.scenes.filter(isHidden).length;
    if (hid) parts.push(`${hid} hidden by you`);
    return parts.join(' · ') + warningText();
}

function drawTimeline() {
    const t0 = Date.parse(S.start + 'T00:00:00Z'), t1 = Date.parse(S.end + 'T23:59:59Z');
    const span = Math.max(1, t1 - t0);
    $('#sat_timeline').html(S.scenes.map(sc => {
        const info = S.info[sc.id];
        const x = 100 * (Date.parse(sc.datetime) - t0) / span;
        const label = `${fmtDate(sc.date)}, ${satName(sc)}`;
        let color = '#d1d5db', h = 8, title = `${label}: measuring…`;
        if (info && info.error) { color = '#f87171'; h = 8; title = `${label}: could not be read (${info.error})`; }
        else if (info && info.validPct < VALID_MIN) { color = '#e5e7eb'; h = 6; title = `${label}: field outside the image`; }
        else if (info) {
            color = info.clearPct >= CLEAR_MIN ? '#2f6b3a' : info.clearPct >= 40 ? '#a3b18a' : '#9ca3af';
            h = 6 + Math.round(info.clearPct / 100 * 26);
            title = `${label}: ${info.clearPct}% of the field without cloud`;
        }
        if (isHidden(sc)) { color = '#fca5a5'; h = 6; title = `${label}: hidden by you (still cloudy)`; }
        return `<div class="sat-tick${sc.source === 'landsat' ? ' ls' : ''}" data-id="${esc(sc.id)}" title="${esc(title)}" style="left:${x.toFixed(2)}%;height:${h}px;background:${color}"></div>`;
    }).join(''));
    const both = S.scenes.some(sc => sc.source === 'landsat') && S.scenes.some(sc => sc.source !== 'landsat');
    $('#sat_tl_labels').html(`<span>${fmtDate(S.start)}</span><span>${S.scenes.length ? `taller = clearer over the field${both ? ' · narrow = Landsat' : ''}` : ''}</span><span>${fmtDate(S.end)}</span>`);
}

/* ---------- images ---------- */

function ndviColor(v) {
    if (v <= NDVI_STOPS[0][0]) return NDVI_STOPS[0][1];
    for (let i = 1; i < NDVI_STOPS.length; i++) {
        const [b, cb] = NDVI_STOPS[i], [a, ca] = NDVI_STOPS[i - 1];
        if (v <= b) { const t = (v - a) / (b - a); return ca.map((c, k) => Math.round(c + t * (cb[k] - c))); }
    }
    return NDVI_STOPS[NDVI_STOPS.length - 1][1];
}

/** Build the image of a scene in the current view: { canvas (1 px = 10 or 30 m), win, ndvi (mean over field) }. */
async function buildImage(sc, signal) {
    const info = S.info[sc.id];
    const key = S.view;
    info.images = info.images || {};
    if (info.images[key]) return info.images[key];
    const a = S.area, g = info.g;
    let win, img;
    let ndviMean = null, ndviN = 0;
    if (key === 'rgb' && sc.source === 'landsat') {
        const cogs = await Promise.all(['red', 'green', 'blue'].map(k => openImage(sc, k, signal)));
        win = windowFor(cogs[0], g.e, g.n, a.sizeM);
        const bands = await Promise.all(cogs.map(c => readWindow(c, win.x0, win.y0, win.w, win.h, signal)));
        const scale = sc.red_scale || 0.0000275, offset = sc.red_offset ?? -0.2;
        const k = 255 / LANDSAT_TRUE_COLOUR_MAX;
        img = new ImageData(win.w, win.h);
        for (let i = 0; i < win.w * win.h; i++) {
            const dn = [bands[0].data[i], bands[1].data[i], bands[2].data[i]];
            if (!dn[0] && !dn[1] && !dn[2]) continue;   // nodata: transparent
            for (let b = 0; b < 3; b++) img.data[i * 4 + b] = Math.max(0, Math.min(255, Math.round((dn[b] * scale + offset) * k)));
            img.data[i * 4 + 3] = 255;
        }
    } else if (key === 'rgb') {
        const cog = await openImage(sc, 'visual', signal);
        win = windowFor(cog, g.e, g.n, a.sizeM);
        const r = await readWindow(cog, win.x0, win.y0, win.w, win.h, signal);
        img = new ImageData(win.w, win.h);
        for (let i = 0, p = 0; i < win.w * win.h; i++, p += 3) {
            const R = r.data[p], G = r.data[p + 1], B = r.data[p + 2];
            img.data[i * 4] = R; img.data[i * 4 + 1] = G; img.data[i * 4 + 2] = B;
            img.data[i * 4 + 3] = (R || G || B) ? 255 : 0;
        }
    } else {
        const [red, nir] = await Promise.all([openImage(sc, 'red', signal), openImage(sc, 'nir', signal)]);
        win = windowFor(red, g.e, g.n, a.sizeM);
        const [rr, nn] = await Promise.all([readWindow(red, win.x0, win.y0, win.w, win.h, signal), readWindow(nir, win.x0, win.y0, win.w, win.h, signal)]);
        img = new ImageData(win.w, win.h);
        const scale = sc.red_scale || 0.0001, offset = sc.red_offset || 0;
        const sw = info.maskWin;
        const [fx0, fy0, fx1, fy1] = fieldRect(win, g);
        let sum = 0, fieldPix = 0;
        for (let y = 0; y < win.h; y++) {
            for (let x = 0; x < win.w; x++) {
                const i = y * win.w + x;
                const dr = rr.data[i], dn = nn.data[i];
                // cloud-mask pixel holding this pixel (Sentinel-2: 20 m mask, 10 m image; Landsat: both 30 m)
                const ux = win.left + (x + 0.5) * win.res, uy = win.top - (y + 0.5) * win.res;
                const sx = Math.floor((ux - sw.left) / sw.res), sy = Math.floor((sw.top - uy) / sw.res);
                const m = (sx >= 0 && sy >= 0 && sx < sw.w && sy < sw.h) ? info.mask[sy * sw.w + sx] : M_NODATA;
                // the field's NDVI: only the pixels inside the field(s), as the cloud cover
                const inField = x >= fx0 && x < fx1 && y >= fy0 && y < fy1 && (!info.usedPolys || insidePolys(g.polys, ux, uy));
                if (inField) fieldPix++;
                if (!dr || !dn) continue;   // nodata
                if (m !== M_CLEAR) {
                    img.data[i * 4] = 205; img.data[i * 4 + 1] = 208; img.data[i * 4 + 2] = 214; img.data[i * 4 + 3] = 255;
                    continue;
                }
                const R = Math.max(0, dr * scale + offset), N = Math.max(0, dn * scale + offset);
                const v = (N + R) > 0 ? (N - R) / (N + R) : 0;
                const c = ndviColor(v);
                img.data[i * 4] = c[0]; img.data[i * 4 + 1] = c[1]; img.data[i * 4 + 2] = c[2]; img.data[i * 4 + 3] = 255;
                if (inField) { sum += v; ndviN++; }
            }
        }
        if (fieldPix && ndviN / fieldPix >= 0.5) ndviMean = sum / ndviN;
    }
    const canvas = document.createElement('canvas');
    canvas.width = win.w; canvas.height = win.h;
    canvas.getContext('2d').putImageData(img, 0, 0);
    info.images[key] = { canvas, win, ndvi: ndviMean, ndviPixels: ndviN };
    return info.images[key];
}

/** Draw a built image scaled to a display canvas, with the plots (or the centre point). */
function paint(target, sc, built, px) {
    const { canvas, win } = built;
    const k = px / win.w;
    target.width = px; target.height = Math.round(win.h * k);
    const ctx = target.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    ctx.clearRect(0, 0, target.width, target.height);
    ctx.drawImage(canvas, 0, 0, target.width, target.height);
    const g = S.info[sc.id].g;
    const toPx = p => [(p[0] - win.left) / win.res * k, (win.top - p[1]) / win.res * k];
    // the field / plots: yellow over a dark edge, visible on green and on bare soil
    const many = g.plots && g.plots.length > 30;   // trial plots: thinner, no fill
    const w = many ? Math.max(1.2, px / 350) : Math.max(2.5, px / 190);
    const shape = r => {
        ctx.beginPath();
        if (r.length === 1) { const [x, y] = toPx(r[0]); ctx.arc(x, y, Math.max(2.5, w * 1.3), 0, 2 * Math.PI); }
        else { r.forEach((p, i) => { const [x, y] = toPx(p); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }); ctx.closePath(); }
    };
    ctx.lineJoin = 'round';
    if (g.plots) {
        g.plots.forEach(r => {
            shape(r);
            if (!many && r.length > 2) { ctx.fillStyle = 'rgba(250, 204, 21, 0.12)'; ctx.fill(); }
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.65)'; ctx.lineWidth = w + 2; ctx.stroke();
            ctx.strokeStyle = '#facc15'; ctx.lineWidth = w; ctx.stroke();
        });
    } else {
        const [x, y] = toPx([g.e, g.n]);
        const r = Math.max(9, px / 35);
        const cross = () => { ctx.beginPath(); ctx.moveTo(x - r, y); ctx.lineTo(x + r, y); ctx.moveTo(x, y - r); ctx.lineTo(x, y + r); };
        cross(); ctx.strokeStyle = 'rgba(0, 0, 0, 0.65)'; ctx.lineWidth = w + 2; ctx.stroke();
        cross(); ctx.strokeStyle = '#facc15'; ctx.lineWidth = w; ctx.stroke();
    }
    // scale bar
    const barM = S.area.sizeM >= 2000 ? 500 : 100;
    const barPx = barM / win.res * k;
    ctx.fillStyle = 'rgba(0,0,0,.55)';
    ctx.fillRect(6, target.height - 22, barPx + 12, 16);
    ctx.fillStyle = '#fff';
    ctx.fillRect(12, target.height - 12, barPx, 3);
    ctx.font = `${Math.max(9, Math.round(px / 40))}px sans-serif`;
    ctx.fillText(`${barM} m`, 12, target.height - 14);
}

/* images hidden by hand (cloud or haze the scene classification missed): not shown, not used by the models */
const isHidden = sc => S.hidden.includes(sc.id);

function setHidden(sc, hide) {
    S.hidden = hide ? S.hidden.concat([sc.id]) : S.hidden.filter(id => id !== sc.id);
    drawTimeline();
    renderStats();
    renderImages();
}

async function renderImages() {
    const runId = S.run;
    const signal = S.abort ? S.abort.signal : undefined;
    S.visible = S.scenes.filter(sc => isShown(S.info[sc.id]) && (S.showHidden || !isHidden(sc)));
    const nHidden = S.scenes.filter(isHidden).length;
    $('#sat_hidden_box').html(nHidden ? `<label class="sat-switch sat-small"><input type="checkbox" id="sat_show_hidden"${S.showHidden ? ' checked' : ''} /><span class="sat-slider"></span>Show the ${nHidden} hidden image${nHidden === 1 ? '' : 's'}</label>` : '');
    $('#sat_legend').html(S.view === 'ndvi'
        ? `NDVI <canvas class="sat-ramp" id="sat_ramp" width="180" height="10"></canvas> −0.2 bare soil … 0.9 dense green canopy · grey = cloud / shadow`
        : (!S.area.fromPlots ? 'Yellow cross: the centre point.' : S.area.kind === 'plots' ? 'Yellow: trial plots.' : S.area.kind === 'farm' ? "Yellow: the farm's fields." : "Yellow: the trial's field.") + ' Click an image to enlarge; &times; hides an image that is still cloudy (it is not used by the models).');
    if (S.view === 'ndvi') {
        const c = document.getElementById('sat_ramp').getContext('2d');
        for (let x = 0; x < 180; x++) { const col = ndviColor(-0.2 + 1.1 * x / 179); c.fillStyle = `rgb(${col.join(',')})`; c.fillRect(x, 0, 1, 10); }
    }
    const mb = S.visible.reduce((t, sc) => t + (SOURCES[sc.source] || SOURCES.sentinel2).mb[S.view], 0);
    const tok = busyStart(true);
    const loading = `Loading the ${S.view === 'ndvi' ? 'NDVI' : 'true-colour'} images (about ${Math.max(1, Math.round(mb))} MB)…`;
    busyStep(tok, loading, 0, S.visible.length);
    status(summary());
    if (!S.visible.length) {
        busyEnd(tok);
        $('#sat_grid').html(`<div class="sat-muted">No date with the field clear of cloud. ${S.scenes.length ? 'Turn on <b>Show cloudy dates</b> to see them anyway, or a longer date range.' : ''}</div>`);
        $('#sat_ndvi_block').hide();
        renderStats();
        return;
    }
    $('#sat_grid').html(S.visible.map((sc, i) => {
        const info = S.info[sc.id];
        const hid = isHidden(sc);
        return `<div class="sat-tile${hid ? ' hid' : ''}" data-i="${i}">`
            + (hid ? `<button type="button" class="sat-unhide btn btn-default btn-xs" data-i="${i}">Use again</button>`
                : `<button type="button" class="sat-hide" data-i="${i}" title="Hide: still cloudy (not used by the models)" aria-label="Hide the image of ${esc(fmtDate(sc.date))}">&times;</button>`)
            + `<canvas width="10" height="10"></canvas><div class="sat-tile-cap"><span><b>${esc(fmtDate(sc.date))}</b><br><span class="sat-sat${sc.source === 'landsat' ? ' ls' : ''}">${esc(satName(sc))} · ${sc.res || 10} m</span></span><span class="sat-muted">${info.clearPct}% clear${S.view === 'ndvi' ? '<br><span class="sat-ndvi">…</span>' : ''}</span></div></div>`;
    }).join(''));
    if (S.view === 'ndvi') { $('#sat_ndvi_block').show(); drawChart(); } else { $('#sat_ndvi_block').hide(); }
    let done = 0;
    await queue(S.visible.map((sc, i) => [sc, i]), 4, async ([sc, i]) => {
        if (runId !== S.run) return;
        const tile = $(`#sat_grid .sat-tile[data-i="${i}"]`);
        try {
            const built = await buildImage(sc, signal);
            if (runId !== S.run) return;
            paint(tile.find('canvas')[0], sc, built, 420);
            if (S.view === 'ndvi') tile.find('.sat-ndvi').text(built.ndvi === null ? 'NDVI –' : `NDVI ${built.ndvi.toFixed(2)}`);
        } catch (err) {
            if (err.name === 'AbortError') return;
            tile.find('.sat-tile-cap span').html('<span class="text-danger">could not be read</span>');
        }
        done++;
        if (S.view === 'ndvi') drawChart();
        renderStats();
        busyStep(tok, loading, done, S.visible.length);
        status(summary());
    });
    if (runId !== S.run) return;
    const took = busyEnd(tok);
    if (took) status(`${summary()} · done in ${took}`);
}

function drawChart() {
    const pts = S.visible.filter(sc => !isHidden(sc)).map(sc => ({ sc, b: (S.info[sc.id].images || {}).ndvi })).filter(p => p.b && p.b.ndvi !== null)
        .sort((p, q) => Date.parse(p.sc.datetime) - Date.parse(q.sc.datetime))
        .map(p => ({ t: Date.parse(p.sc.datetime), v: p.b.ndvi, sc: p.sc }));
    const W = 800, H = 190, L0 = 40, R0 = 10, T0 = 10, B0 = 26;
    const t0 = Date.parse(S.start + 'T00:00:00Z'), t1 = Date.parse(S.end + 'T23:59:59Z');
    const X = t => L0 + (W - L0 - R0) * (t - t0) / Math.max(1, t1 - t0);
    const Y = v => T0 + (H - T0 - B0) * (1 - (v + 0.2) / 1.2);
    let svg = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" role="img" aria-label="NDVI over time">`;
    [0, 0.2, 0.4, 0.6, 0.8, 1].forEach(v => {
        svg += `<line x1="${L0}" x2="${W - R0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#e5e7eb" /><text x="${L0 - 6}" y="${Y(v) + 4}" font-size="10" text-anchor="end" fill="#6b7280">${v.toFixed(1)}</text>`;
    });
    const months = [];
    for (let d = new Date(t0); d.getTime() <= t1; d.setUTCMonth(d.getUTCMonth() + 1, 1)) months.push(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)));
    const every = Math.ceil(months.length / 12);
    months.forEach((m, i) => {
        if (m.getTime() < t0 || i % every) return;
        svg += `<text x="${X(m.getTime())}" y="${H - 8}" font-size="10" fill="#6b7280">${m.toLocaleDateString(undefined, { month: 'short', year: '2-digit', timeZone: 'UTC' })}</text>`;
    });
    if (S.trial) {
        [[S.trial.planting, 'planting'], [S.trial.harvest, 'harvest']].forEach(([d, label]) => {
            if (!d) return;
            const t = Date.parse(d + 'T12:00:00Z');
            if (t < t0 || t > t1) return;
            svg += `<line x1="${X(t)}" x2="${X(t)}" y1="${T0}" y2="${H - B0}" stroke="#b45309" stroke-dasharray="4 3" /><text x="${X(t) + 3}" y="${T0 + 10}" font-size="10" fill="#b45309">${label}</text>`;
        });
    }
    if (pts.length > 1) svg += `<polyline fill="none" stroke="#2f6b3a" stroke-width="2" points="${pts.map(p => `${X(p.t).toFixed(1)},${Y(p.v).toFixed(1)}`).join(' ')}" />`;
    pts.forEach(p => {
        const ls = p.sc.source === 'landsat';
        svg += `<circle cx="${X(p.t).toFixed(1)}" cy="${Y(p.v).toFixed(1)}" r="4" fill="${ls ? '#fff' : '#2f6b3a'}" stroke="${ls ? '#2f6b3a' : '#fff'}" stroke-width="${ls ? 2 : 1.5}"><title>${esc(fmtDate(p.sc.date))}, ${esc(satName(p.sc))}: NDVI ${p.v.toFixed(2)}</title></circle>`;
    });
    svg += '</svg>';
    $('#sat_chart').html(svg);
    const mixed = pts.some(p => p.sc.source === 'landsat') && pts.some(p => p.sc.source !== 'landsat');
    $('#sat_chart_note').html(`Mean NDVI of the cloud-free pixels over ${!S.area.fromPlots ? 'the whole square' : S.area.kind === 'plots' ? 'the area of the trial plots' : S.area.kind === 'farm' ? "the farm's fields" : "the trial's field"} (nothing outside it); a date counts when at least half of them are clear. ${pts.length} point${pts.length === 1 ? '' : 's'}.`
        + (mixed ? ' Filled dots: Sentinel-2 (10 m); open dots: Landsat (30 m). The two sensors give close but not identical NDVI, and a 30 m pixel mixes more of the field edges.' : ''));
}

/* ---------- enlarged view ---------- */

async function showBig(i) {
    if (i < 0 || i >= S.visible.length) return;
    S.bigIndex = i;
    const sc = S.visible[i], info = S.info[sc.id];
    $('#sat_big_title').text(`${fmtDate(sc.date)} — ${S.view === 'ndvi' ? 'NDVI' : 'true colour'}`);
    $('#sat_big_info').text(`${satName(sc)} · ${sc.res || 10} m pixels · ${sc.source === 'landsat' ? 'path/row' : 'tile'} ${sc.tile || ''} · ${info.clearPct}% of the field without cloud`);
    $('#sat_prev').prop('disabled', i === 0); $('#sat_next').prop('disabled', i === S.visible.length - 1);
    $('#sat_big_hide').text(isHidden(sc) ? 'Use this image again' : 'Hide this image (still cloudy)');
    $('#sat_big_modal').modal('show');
    try {
        const built = await buildImage(sc, S.abort ? S.abort.signal : undefined);
        if (S.bigIndex === i) paint($('#sat_big canvas')[0], sc, built, 860);
    } catch (err) { if (err.name !== 'AbortError') $('#sat_big_info').text('This image could not be read.'); }
}

/* ---------- step 5: model ---------- */

const MODEL_NAMES = [['crop_map', 'crop map'], ['yield', 'yield'], ['indices', 'plot indices']];
const COMMON = { 'Zea mays': 'Maize', 'Zea mays subsp. mays': 'Maize', 'Nicotiana tabacum': 'Tobacco', 'Glycine max': 'Soybean', 'Manihot esculenta': 'Cassava',
    'Oryza sativa': 'Rice', 'Triticum aestivum': 'Wheat', 'Sorghum bicolor': 'Sorghum', 'Saccharum officinarum': 'Sugarcane', 'Phaseolus vulgaris': 'Common bean',
    'Coffea arabica': 'Coffee', 'Gossypium hirsutum': 'Cotton', 'Solanum tuberosum': 'Potato', 'Ipomoea batatas': 'Sweet potato', 'Musa': 'Banana', 'Dioscorea': 'Yam' };
const CLASS_PRESETS = [['Other crops', '#f97316'], ['Pasture / grass', '#a3e635'], ['Forest', '#15803d'], ['Bare soil', '#a16207'], ['Water', '#2563eb'], ['Urban / roads', '#dc2626']];
const CLASS_COLORS = ['#eab308', '#15803d', '#a3e635', '#f97316', '#a16207', '#2563eb', '#dc2626', '#9333ea', '#0891b2', '#db2777', '#4b5563', '#65a30d'];
const UNCERTAIN_COLOR = '#9ca3af';
const MIN_CALIB_DEFAULT = 8;
const PREDICTOR_NAMES = { ndvi_auc: 'NDVI area under the season curve', ndvi_max: 'NDVI peak', ndre_max: 'NDRE (red-edge) peak', peak_day: 'Day of the NDVI peak' };
// advanced settings: key, label, default, min, max, step, help
const YIELD_MODEL_LABELS = { auto: 'Automatic (compare and choose)', linear1: 'Linear (NDVI area only)', linear: 'Linear regression', ridge: 'Ridge regression', pls: 'PLS (1 component)',
    elastic_net: 'Elastic net', lasso: 'Lasso', gam: 'GAM (smooth)', mixed: 'Mixed model (location-year effect)', mars: 'MARS', random_forest: 'Random forest', svm: 'SVM regression' };
const MAP_MODEL_LABELS = { auto: 'Automatic (compare and choose)', random_forest: 'Random forest', svm: 'SVM (radial)', nnet: 'Neural network', tree: 'Decision tree' };
const ADVANCED = [
    ['Images', [
        ['min_scene_clear', 'Skip a date with less of the area clear than (%)', 10, 0, 90, 5, 'Mostly cloudy dates are not read at all.'],
        ['min_field_clear', 'A field / plot value needs this much of it clear (%)', 50, 10, 100, 5, 'Otherwise that date is left out for the field.'],
    ]],
    ['Crop map', [
        ['period_days', 'Period length (days)', 30, 7, 120, 1, 'Images are averaged per period; each period gives features. Shorter = more detail, more gaps from clouds.'],
        ['ntree', 'Trees in the random forest', 300, 50, 1000, 50, ''],
        ['pixels_per_area', 'Pixels used per drawn area (at most)', 300, 20, 2000, 10, 'So that a large area does not outweigh the small ones.'],
        ['cv_folds', 'Cross-validation folds (by drawn area)', 5, 2, 10, 1, 'Limited by the class with the fewest areas.'],
        ['min_confidence', 'Uncertain below this share of the votes (%)', 50, 0, 95, 5, '0 = every pixel gets a class.'],
        ['min_patch_ha', 'Smallest area of the crop estimated as a field (ha)', 0.5, 0.05, 100, 0.05, ''],
        ['map_model', 'Classifier', 'auto', Object.keys(MAP_MODEL_LABELS), 'Automatic: random forest, SVM, neural network and decision tree are compared by cross-validation by drawn area; the best kappa is used.'],
        ['smooth', 'Smooth the map (3 x 3 majority)', true],
        ['balance', 'Balance the classes in training', true],
    ]],
    ['Yield', [
        ['yield_model', 'Model', 'auto', Object.keys(YIELD_MODEL_LABELS), 'Automatic: every model suited to the number of fields is compared by cross-validation; the simplest one within one standard error of the best is used (complex models overfit few fields).'],
        ['predictors', 'Predictors', ['ndvi_auc', 'ndre_max'], Object.keys(PREDICTOR_NAMES), 'Fewer predictors are safer with few calibration fields.'],
        ['min_fields', 'Calibration fields needed (at least)', MIN_CALIB_DEFAULT, 5, 100, 1, ''],
        ['min_dates', 'Clear dates needed per field', 4, 1, 30, 1, ''],
        ['season_days', 'Season length when a trial has no harvest date (days)', 150, 60, 365, 5, 'From the planting date.'],
        ['level', 'Prediction interval (%)', 90, 50, 99, 1, ''],
    ]],
];

const setting = k => {
    if (S.settings[k] !== undefined) return S.settings[k];
    for (const [, items] of ADVANCED) for (const it of items) if (it[0] === k) return it[2];
    return undefined;
};

function cropLabel() {
    const c = S.crop === '__other' ? S.cropOther.trim() : S.crop;
    return COMMON[c] || c || 'the crop';
}

function cropClassName() { return cropLabel() === 'the crop' ? 'Crop' : cropLabel(); }

function ensureClasses() {
    if (!S.classes.length) {
        S.classes = [{ id: 'crop', name: cropClassName(), color: CLASS_COLORS[0] },
            { id: 'c_forest', name: 'Forest', color: '#15803d' }, { id: 'c_pasture', name: 'Pasture / grass', color: '#a3e635' }];
    }
    S.classes[0].name = cropClassName();
}

/** New dates in step 4 (load: a quick choice or the Load images button); the analysis period follows them. */
function datesChanged(load) {
    S.ana = { start: null, end: null };
    S.anaPreset = 'images';
    if (S.step === 4) showSiteImages(load);
}

/* ---------- analysis period (models): the images' dates, adjustable in step 5 ---------- */

const anaDates = () => ({ start: S.ana.start || S.start, end: S.ana.end || S.end });

function renderAna() {
    const a = anaDates();
    $('#sat_ana_start5').val(a.start || '');
    $('#sat_ana_end5').val(a.end || '');
    if (S.step === 5) renderModel();
}

/* ---------- earlier analyses ---------- */

async function loadRuns() {
    try { S.runsList = (await getJSON('runs')).runs; } catch (err) { S.runsList = []; $('.sat-runs').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`); return; }
    renderRuns();
}

function renderRuns() {
    // trainings are opened on their own page
    const l = S.runsList && S.runsList.filter(r => r.kind !== 'train');
    if (!l) { $('.sat-runs').html('<span class="sat-muted sat-small">Loading…</span>'); return; }
    $('.sat-runs').html(l.length ? '<table class="sat-mini-table"><tbody>' + l.map(r => {
        const when = r.created ? new Date(r.created * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' }) : '';
        const st = { done: '<span class="text-success">ready</span>', failed: '<span class="text-danger">failed</span>', running: '<span class="text-warning">running…</span>' }[r.status] || '';
        return `<tr${r.run_id === S.job.runId ? ' style="background:var(--sat-accent-soft)"' : ''}><td>${esc(r.name || r.run_id)}${r.model_used ? ` <span class="sat-small">· model: <b>${esc(r.model_used)}</b></span>` : ''}${r.model_saved && r.model_saved !== r.model_used ? ` <span class="sat-small">· saved as model <b>${esc(r.model_saved)}</b></span>` : ''}<br><span class="sat-muted sat-small">${esc(when)}${r.dates ? ` · images ${esc(r.dates.start)} – ${esc(r.dates.end)}` : ''}</span></td><td>${st}</td>`
            + `<td><button type="button" class="btn btn-default btn-xs sat-run-open" data-id="${esc(r.run_id)}">Open</button></td></tr>`;
    }).join('') + '</tbody></table>' : '<span class="sat-muted sat-small">No analysis yet.</span>');
}

function openRun(id) {
    const r = (S.runsList || []).find(x => x.run_id === id);
    if (r && r.kind === 'train') { location.href = `/breeders/satellite/train?run=${encodeURIComponent(id)}`; return; }
    S.job = { runId: id, timer: null, results: null, site: 0, status: 'running', skipped: [] };
    goStep(6);
}

const isMaize = () => /^Zea mays\b/.test(cropSpecies() || '');
/** The crop map method: the stored maize curve (maize only) or drawn examples. */
function mapMethod() {
    if (!isMaize()) return 'examples';
    if (!S.mapMethod) S.mapMethod = 'standard';
    return S.mapMethod;
}
const daysBetween = (a, b) => (Date.parse(b + 'T12:00:00Z') - Date.parse(a + 'T12:00:00Z')) / 86400000;
// the maize standard (R/satellite/standards/maize.json), for the preview chart
const MAIZE_STD = { das: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190],
    ndvi: [0.2, 0.245, 0.384, 0.543, 0.722, 0.866, 0.899, 0.901, 0.889, 0.876, 0.878, 0.87, 0.827, 0.768, 0.671, 0.563, 0.441, 0.327, 0.239, 0.2] };

function standardPreview() {
    const W = 360, H = 120, L0 = 30, B0 = 22, T0 = 8, R0 = 8;
    const X = d => L0 + (W - L0 - R0) * d / 190, Y = v => H - B0 - (H - T0 - B0) * v;
    let svg = `<svg viewBox="0 0 ${W} ${H}" style="width:100%;max-width:380px;height:auto" role="img" aria-label="Maize standard NDVI curve">`;
    [0, 0.5, 1].forEach(v => { svg += `<line x1="${L0}" x2="${W - R0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#eef0f2" /><text x="${L0 - 4}" y="${Y(v) + 3}" font-size="9" text-anchor="end" fill="#6b7280">${v}</text>`; });
    [0, 50, 100, 150].forEach(d => { svg += `<text x="${X(d)}" y="${H - 8}" font-size="9" text-anchor="middle" fill="#6b7280">${d}</text>`; });
    svg += `<polyline fill="none" stroke="#2b7a4b" stroke-width="2.5" points="${MAIZE_STD.das.map((d, i) => `${X(d).toFixed(1)},${Y(MAIZE_STD.ndvi[i]).toFixed(1)}`).join(' ')}" />`;
    svg += `<text x="${(L0 + W - R0) / 2}" y="${H - 0.5}" font-size="9" text-anchor="middle" fill="#374151">days after sowing</text></svg>`;
    return svg;
}

/** All labels / targets of all sites (S holds the current site's copies). */
function allSites() { saveSite(); return S.sites; }

async function enterModel() {
    if (!S.season.start) { S.season = { ...anaDates() }; }
    renderAna();
    if (S.runsList === null) loadRuns(); else renderRuns();
    defaultYieldMode();
    ensureClasses();
    renderModel();
    drawModelMap(true);
    loadTrialInfo();
}

async function loadTrialInfo() {
    const ids = [...new Set(allSites().flatMap(st => (st.trials || []).map(t => t.id)))].filter(id => !(id in S.trialInfo));
    if (!ids.length || S.trialInfoLoading) return;
    S.trialInfoLoading = true;
    renderModel();
    try {
        for (let i = 0; i < ids.length; i += 200) {
            const { trials } = await getJSON('trial_info', { trial_ids: ids.slice(i, i + 200).join(',') });
            trials.forEach(t => { S.trialInfo[t.trial_id] = t; });
        }
    } catch (err) { console.warn('trial_info', err); }   // only the species of the step-2 trial is checked with it
    S.trialInfoLoading = false;
    defaultYieldMode();
    if (S.step === 5) renderModel();
}

/** A trained model when the user has saved one, otherwise the index (no model). */
function defaultYieldMode() {
    if (S.yieldMode && !S.yieldModeAuto) return;
    if (S.savedModels === null) {
        S.savedModels = [];
        getJSON('models').then(r => {
            S.savedModels = r.models;
            if (S.yieldModeAuto && r.models.length) S.yieldMode = 'saved';
            if (S.step === 5) renderModel();
        }).catch(() => {});
    }
    S.yieldMode = (S.savedModels || []).length ? 'saved' : S.calib.length ? 'calibrated' : 'index';
    S.yieldModeAuto = true;
}

const cropSpecies = () => (S.crop === '__other' ? S.cropOther.trim() : S.crop);
const sameCrop = sp => !!sp && !!cropSpecies() && (sp === cropSpecies() || sp.startsWith(cropSpecies() + ' ') || cropSpecies().startsWith(sp + ' '));


/** Convex hull of [lon, lat] points (monotone chain). */
function hull(pts) {
    const p = [...new Map(pts.map(q => [q.join(','), q])).values()].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    if (p.length < 3) return p;
    const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
    const lo = [], up = [];
    p.forEach(q => { while (lo.length >= 2 && cross(lo[lo.length - 2], lo[lo.length - 1], q) <= 0) lo.pop(); lo.push(q); });
    [...p].reverse().forEach(q => { while (up.length >= 2 && cross(up[up.length - 2], up[up.length - 1], q) <= 0) up.pop(); up.push(q); });
    return lo.slice(0, -1).concat(up.slice(0, -1));
}

/** The field(s) delimited in step 2, as fields to estimate: farm fields, a trial's drawn field, the area of a trial's plots. */
function step2Targets(st) {
    const f = st.field;
    if (!f) return [];
    if (f.kind === 'farm') return st.farmFields.map(x => ({ name: x.name, ring: x.ring, step2: true }));
    if (f.kind === 'drawn') return [{ name: st.trial ? st.trial.name : 'Trial field', ring: f.plots[0], step2: true }];
    if (f.kind === 'plots') {
        const h = hull(f.plots.flat());
        return h.length >= 3 && ringHa(h) >= 0.01 ? [{ name: `${st.trial ? st.trial.name : 'Trial'} (area of the plots)`, ring: h, step2: true }] : [];
    }
    return [];
}

/** Crop-map examples from step 2: the site's field(s), as examples of the crop (a trial of another species is not). */
function step2Labels(st) {
    if (!S.useStep2Labels || !S.models.crop_map) return [];
    const f = st.field;
    if (!f) return [];
    if (f.kind !== 'farm' && st.trial) {
        const info = S.trialInfo[st.trial.id];
        if (info && info.species && !sameCrop(info.species)) return [];
    }
    return step2Targets(st).map(t => ({ class: 'crop', ring: t.ring, name: t.name, auto: true }));
}

function siteLabels(st) { return (st.labels || []).concat(step2Labels(st)); }

/** Fields to estimate of a site: the step-2 field(s) (unless turned off) and those drawn in step 5. */
function siteTargets(st) {
    const own = st.targets || [];
    const auto = st.useStep2 === false ? [] : step2Targets(st);
    const seen = new Set(own.map(t => JSON.stringify(t.ring)));
    return auto.filter(t => !seen.has(JSON.stringify(t.ring))).concat(own);
}

/** Estimate the crop areas found by the crop map too? Off when fields were delimited (unless asked), on otherwise. */
function mapAreasOn() {
    if (!S.models.crop_map) return false;
    if (S.mapAreas !== null) return S.mapAreas;
    return !allSites().some(st => siteTargets(st).length);
}

function calibCount() {
    return S.calib.filter(c => c.yield !== '' && isFinite(+c.yield) && c.start && c.end && c.start <= c.end).length;
}

/** Everything the run needs, as a checklist: [ { ok, text } ]. */
function readiness() {
    const items = [];
    const any = MODEL_NAMES.some(([k]) => S.models[k]);
    items.push({ ok: any, text: any ? `Models: ${MODEL_NAMES.filter(([k]) => S.models[k]).map(([, l]) => l).join(', ')}` : 'Choose at least one model' });
    const sites = allSites();
    const nHid = sites.reduce((t, st) => t + (st.hidden || []).length, 0);
    const ad0 = anaDates();
    const okAna = ad0.start && ad0.end && ad0.start <= ad0.end;
    items.push({ ok: !!okAna, text: okAna ? `Period analysed: ${fmtDate(ad0.start)} – ${fmtDate(ad0.end)}, ${S.sites.length} location${S.sites.length === 1 ? '' : 's'}${nHid ? `; ${nHid} image${nHid === 1 ? '' : 's'} you hid in step 4 left out` : ''}` : 'Choose the analysis period (step 4, or at the top of this step)' });
    if (S.models.crop_map && mapMethod() === 'standard') {
        const ad = anaDates();
        const len = ad.start && ad.end ? daysBetween(ad.start, ad.end) : 0;
        items.push({ ok: len >= 120, text: len >= 120
            ? `Crop map: maize standard over ${Math.round(len)} days of images${len < 300 ? ' (a whole year finds summer and off-season maize)' : ''}`
            : `Crop map: the maize standard needs an analysis period covering a whole season, at least 4 months (now ${Math.round(len)} days, ${fmtDate(ad.start)} – ${fmtDate(ad.end)})`,
            go: len >= 120 ? null : 'year', goText: 'Use the last 12 months' });
    } else if (S.models.crop_map) {
        const per = {};
        sites.forEach(st => siteLabels(st).forEach(l => { per[l.class] = (per[l.class] || 0) + 1; }));
        const missing = S.classes.filter(k => !per[k.id]);
        const few = S.classes.filter(k => per[k.id] === 1);
        items.push({ ok: S.classes.length >= 2 && !missing.length, text: missing.length
            ? `Crop map: draw examples of ${missing.map(k => k.name).join(', ')}${per.crop ? ` (${cropClassName()} already has ${per.crop}${step2Labels.length !== undefined && sites.some(st => step2Labels(st).length) ? ', from step 2' : ''}; the other classes teach the map what is not ${cropClassName()})` : ''}`
            : `Crop map: ${S.classes.length} classes with examples` + (few.length ? ` (only 1 area of ${few.map(k => k.name).join(', ')}: the accuracy cannot be measured, draw 2)` : '') });
    }
    if (S.models.yield) {
        const crop = cropSpecies();
        items.push({ ok: !!crop, text: crop ? `Crop: ${cropLabel()}` : 'Choose the crop' });
        if (S.seasonMode === 'dates') {
            const okSeason = S.season.start && S.season.end && S.season.start <= S.season.end;
            items.push({ ok: !!okSeason, text: okSeason ? `Season of the crop: ${fmtDate(S.season.start)} – ${fmtDate(S.season.end)}` : 'Give the season of the crop' });
        } else {
            items.push({ ok: true, text: `Season: ${{ detected: 'every season found in each field\'s curve (sowing → harvest)', main: 'the main season of each field', second: 'the second crop (safrinha) of each field' }[S.seasonMode]}` });
        }
        if (S.yieldMode === 'saved') {
            const m = (S.savedModels || []).find(x => String(x.id) === String(S.savedModelId));
            items.push({ ok: !!m, text: m ? `Yield: trained model "${m.name}"` : (S.savedModels || []).length ? 'Choose the trained model' : 'No trained model yet: train one (link above), or use the relative index' });
            const crop = m && (m.properties || {}).crop;
            if (m && crop && cropSpecies() && !sameCrop(crop)) items.push({ ok: true, text: `⚠ The model was trained on ${crop}, this analysis is ${cropSpecies()}` });
        } else if (S.yieldMode === 'index') {
            items.push({ ok: true, text: S.useReference
                ? 'Yield: relative index scaled to approximate kg/ha by the regional average yield (public statistics; no field of known yield)'
                : 'Yield: relative index, no known yields (fields compared with each other, 100 = average; no kg/ha)' });
        } else {
            const c = calibCount(), need = +setting('min_fields');
            items.push({ ok: c >= need, go: c < need ? 'calib' : null, text: c >= need
                ? `Calibration: ${c} fields you drew with a known yield`
                : `Calibration: ${c} of the ${need} drawn fields with a known yield needed. Draw them, use a trained model, or the relative index.` });
        }
        const targets = sites.reduce((t, st) => t + siteTargets(st).length, 0);
        const fromStep2 = sites.reduce((t, st) => t + (st.useStep2 === false ? 0 : step2Targets(st).length), 0);
        const withMap = mapAreasOn();
        items.push({ ok: targets > 0 || withMap, text: targets || withMap
            ? `Fields to estimate: ${targets ? `${targets}${fromStep2 ? ` (${fromStep2} from step 2)` : ''}` : 'none delimited'}${withMap ? ` + the ${cropLabel()} areas the crop map finds` : ''}`
            : 'Fields to estimate: none. Delimit the field in step 2 (farm fields or a trial), draw one on the map below, or add the crop map' });
    }
    if (S.models.indices) {
        const withPlots = sites.filter(st => st.field && st.field.kind === 'plots');
        items.push({ ok: withPlots.length > 0, text: withPlots.length ? `Plot indices: ${withPlots.map(st => `${st.trial.name} (${st.field.count} plots)`).join(', ')}` : 'Plot indices need a location whose field (step 2) is a trial with plot coordinates' });
    }
    return items;
}

function renderModel() {
    if (!$('.sat-pane[data-step="5"]').length) return;
    ensureClasses();
    const plotsSites = allSites().filter(st => st.field && st.field.kind === 'plots');
    $('#sat_models .sat-option').each(function () {
        const k = $(this).data('v');
        const off = k === 'indices' && !plotsSites.length;
        if (off && S.models.indices) S.models.indices = false;
        $(this).toggleClass('on', !!S.models[k]).toggleClass('disabled', off).find('input').prop('checked', !!S.models[k]).prop('disabled', off);
    });
    $('#sat_indices_text').text(plotsSites.length
        ? `NDVI, NDRE and EVI of every plot on every clear date, stored as phenotypes of ${plotsSites.map(st => st.trial.name).join(', ')}. A 10 m pixel mixes neighbouring plots.`
        : 'Needs a location whose field (step 2) is a trial with plot GPS coordinates.');
    // crop
    const crops = S.crops.map(c => [c.species, `${COMMON[c.species] ? `${COMMON[c.species]} (${c.species})` : c.species}`]);
    $('#sat_crop').html('<option value="">Choose the crop</option>' + crops.map(([v, l]) => `<option value="${esc(v)}"${v === S.crop ? ' selected' : ''}>${esc(l)}</option>`).join('')
        + `<option value="__other"${S.crop === '__other' ? ' selected' : ''}>Other…</option>`);
    $('#sat_crop_other_box').toggle(S.crop === '__other');
    $('#sat_crop_card').toggle(S.models.yield || S.models.crop_map);
    $('#sat_season_box, #sat_season_help').toggle(!!S.models.yield);
    $('#sat_season_start').val(S.season.start || ''); $('#sat_season_end').val(S.season.end || '');
    const cap = x => x.charAt(0).toUpperCase() + x.slice(1);
    // named seasons (summer, safrinha…) only for locations of a country with season windows (Brazil)
    const inCountry = allSites().filter(st => (S.seasonCountries || []).some(c => c.toLowerCase() === String(st.loc.country || '').toLowerCase()));
    const named = inCountry.length ? S.seasonNames.map(n => [n, cap(n)]) : [];
    if (!['detected', 'dates'].includes(S.seasonMode) && !named.some(([v]) => v === S.seasonMode)) S.seasonMode = 'detected';
    segs('#sat_season_mode', [['detected', 'Every season found']].concat(named, [['dates', 'Dates I give']]), S.seasonMode,
        v => { S.seasonMode = v; renderModel(); });
    $('#sat_season_dates').toggle(S.seasonMode === 'dates');
    const ad1 = anaDates();
    const long = ad1.start && ad1.end && daysBetween(ad1.start, ad1.end) >= 300;
    $('#sat_season_help').html(({
        detected: 'Each field\'s seasons are found in its curve: green-up from bare soil, peak, and back to bare soil (harvest). A field with two crops in the period gets one row per season.',
        dates: 'From sowing / transplanting to harvest of the fields to estimate, the same for every field.',
        main: 'Only the main season (sown Aug–Dec in the southern hemisphere), found in each field\'s curve.',
        second: 'Only the second crop / safrinha (sown Jan–Apr), found in each field\'s curve.',
    }[S.seasonMode] || `Only the ${esc(cap(S.seasonMode))} season of each field, found in its curve (by its sowing window).`)
        + (S.seasonNames.length && named.length
            ? ` ${S.seasonNames.map(cap).join(' / ')} apply only to locations in ${(S.seasonCountries || []).join(', ')}${inCountry.length < allSites().length ? ` (here: ${inCountry.map(st => esc(st.loc.name)).join(', ')})` : ''}.`
                + (long ? ` With ${Math.round(daysBetween(ad1.start, ad1.end))} days, their results are also split by season.` : ' Choose a period of a year or more to also split the map by season.')
            : S.seasonNames.length ? ` Named seasons (${S.seasonNames.map(cap).join(', ')}) apply only to locations in ${(S.seasonCountries || []).join(', ') || 'the listed countries'}; here the seasons found are only numbered.` : ''));
    // classes
    $('#sat_classes_box').toggle(!!S.models.crop_map);
    const method = mapMethod();
    $('#sat_map_method').toggle(isMaize());
    options('#sat_map_method', method);
    $('#sat_examples_box').toggle(method === 'examples');
    $('#sat_standard_box').toggle(method === 'standard').html(method !== 'standard' ? '' : '<div class="row"><div class="col-sm-6">' + standardPreview() + '</div><div class="col-sm-6 sat-small">'
        + '<b>Stored maize curve</b> (NDVI by days after sowing), measured with Sentinel-2 on the Breedbase maize trial SB22CMR1PR_Y2M_NZNA02 (Paraná, sown 25 Feb 2022). '
        + 'Each pixel is compared with it for every sowing date in your dates, the cycle shortened or stretched (about 120 to 200 days); maize when it follows the curve closely. '
        + '<br><span class="text-warning">Proof of concept: crops with a similar season (soybean, sorghum) can be taken for maize. The dates of step 3 must cover a whole season.</span>'
        + (allSites().some(st => step2Labels(st).length) ? '<br>Your step-2 field is used to <b>check</b> the map (how much of it is found as maize).' : '') + '</div></div>');
    const sites = allSites();
    const count = id => sites.reduce((t, st) => t + siteLabels(st).filter(l => l.class === id).length, 0);
    const autoN = sites.reduce((t, st) => t + step2Labels(st).length, 0);
    const here = id => (S.labels || []).filter(l => l.class === id).length;
    const can2 = sites.some(st => step2Targets(st).length && (st.field.kind === 'farm' || !st.trial || !S.trialInfo[st.trial.id] || !S.trialInfo[st.trial.id].species || sameCrop(S.trialInfo[st.trial.id].species)));
    $('#sat_step2_labels').html(can2 ? `<label class="sat-switch sat-small"><input type="checkbox" id="sat_use_step2_labels"${S.useStep2Labels ? ' checked' : ''} /><span class="sat-slider"></span>Use the step-2 field(s) as examples of ${esc(cropClassName())}</label>` : '');
    $('#sat_classes').html(S.classes.map((k, i) => {
        const n = count(k.id);
        return `<div class="sat-class-row"><span class="sat-swatch" style="background:${k.color}"></span>`
            + `<input type="text" class="form-control input-sm sat-class-name" data-i="${i}" value="${esc(k.name)}" maxlength="60" aria-label="Class name"${k.id === 'crop' ? ' disabled title="The crop chosen above"' : ''} />`
            + `<span class="sat-count${n < 2 ? ' bad' : ''}">${n} area${n === 1 ? '' : 's'}${k.id === 'crop' && autoN ? ` (${autoN} from step 2)` : ''}${S.sites.length > 1 ? ` (${here(k.id)} drawn here)` : ''}</span>`
            + `<button type="button" class="btn btn-default btn-xs sat-class-draw" data-i="${i}">+ Draw an example</button>`
            + (k.id === 'crop' ? '' : ` <button type="button" class="btn btn-link btn-xs sat-class-del" data-i="${i}" aria-label="Remove ${esc(k.name)}">remove</button>`) + '</div>';
    }).join(''));
    const names = new Set(S.classes.map(k => k.name.toLowerCase()));
    segs('#sat_class_presets', CLASS_PRESETS.filter(([n]) => !names.has(n.toLowerCase())).map(([n]) => [n, n]).concat([['__custom', 'Other…']]), null, addClass);
    // yield
    $('#sat_yield_box').toggle(!!S.models.yield);
    if (S.models.yield) renderYieldSetup();
    // site name, draw status, readiness
    $('#sat_model_site').text(S.loc ? (S.sites.length > 1 ? S.loc.name : '') : '');
    renderModelDraw();
    renderReady();
}

/** The checklist, run button and summary only (typing in a table must not redraw it: the focus would be lost). */
function renderReady() {
    const ready = readiness();
    $('#sat_ready').html(ready.map(r => `<li class="${r.ok ? 'ok' : 'no'}">${esc(r.text)}${r.go ? ` <a href="#" class="sat-go" data-go="${r.go}">${esc(r.goText || 'Go there')}</a>` : ''}</li>`).join(''));
    $('#sat_run').prop('disabled', !ready.every(r => r.ok) || (S.job.runId && S.job.status === 'running'));
    const changed = Object.keys(S.settings).filter(k => JSON.stringify(S.settings[k]) !== JSON.stringify(defaultSetting(k)));
    $('#sat_adv_summary').text(changed.length ? `Advanced settings changed: ${changed.map(advLabel).join(', ')}.` : 'Advanced settings: defaults.');
    renderFlow();
}

function renderSavedBox() {
    if (S.savedModels === null) { S.savedModels = []; getJSON('models').then(r => { S.savedModels = r.models; renderModel(); }).catch(() => {}); }
    // models of the analysis' crop first; the newest of them chosen by default
    const ms = (S.savedModels || []).slice().sort((a, b) => sameCrop((b.properties || {}).crop) - sameCrop((a.properties || {}).crop));
    if (!S.savedModelId && ms.length && sameCrop((ms[0].properties || {}).crop)) S.savedModelId = String(ms[0].id);
    let h = ms.length
        ? '<label class="sat-label" for="sat_saved" style="margin-top:0">Trained model</label>' + `<select id="sat_saved" class="form-control input-sm" style="min-width:320px"><option value="">Choose a model</option>`
            + ms.map(m => `<option value="${m.id}"${String(S.savedModelId) === String(m.id) ? ' selected' : ''}>${esc(m.name)}</option>`).join('') + '</select>'
        : '<span class="sat-muted sat-small">No trained model yet: <a href="/breeders/satellite/train" target="_blank" rel="noopener">train one</a> (regional statistics or trials), save it, then come back (the list reloads when you choose this option again).</span>';
    const m = ms.find(x => String(x.id) === String(S.savedModelId));
    if (m) {
        const p = m.properties || {}, mt = p.metrics || {};
        h += `<div class="sat-small" style="margin-top:6px">${esc(p.crop || '')} · ${esc(String(p.trait || '').replace(/\|[^|]*$/, ''))}${p.unit ? ` (${esc(p.unit)})` : ''} · ${esc(YIELD_MODEL_LABELS[p.model] || p.model || '')}`
            + ` · R² ${fmt(mt.r2, 2)}, error ${fmt(mt.rmse, 1)} on ${mt.n || p.calibration_fields || '?'} fields</div>`;
    }
    $('#sat_saved_box').html(h);
}

function renderYieldSetup() {
    defaultYieldMode();
    options('#sat_yield_mode', S.yieldMode);
    $('#sat_saved_box').toggle(S.yieldMode === 'saved');
    if (S.yieldMode === 'saved') renderSavedBox();
    $('.sat-min-fields').text(setting('min_fields'));
    $('#sat_calib_box').toggle(S.yieldMode === 'calibrated');
    $('#sat_ref_box').toggle(S.yieldMode === 'index');
    $('#sat_ref_on').prop('checked', S.useReference);
    if (S.yieldMode === 'index') renderReferences();
    $('#sat_yield_unit').val(S.yieldUnit);
    $('#sat_yield_perha').prop('checked', S.perHa);
    // drawn calibration fields
    let c = `<div class="sat-label" style="margin-top:10px">Fields you know the yield of <button type="button" class="btn btn-default btn-xs" id="sat_draw_calib" style="margin-left:6px">+ Draw a field</button></div>`;
    if (S.calib.length) {
        c += '<table class="sat-mini-table"><thead><tr><th>Name</th><th>Location</th><th class="num">ha</th><th>Yield</th><th>Season start</th><th>Season end</th><th></th></tr></thead><tbody>'
            + S.calib.map((f, i) => `<tr><td><input type="text" class="form-control input-sm sat-calib-in" data-i="${i}" data-k="name" value="${esc(f.name)}" maxlength="100" aria-label="Name" /></td>`
                + `<td class="sat-muted">${esc(f.site)}</td><td class="num">${ringHa(f.ring).toFixed(2)}</td>`
                + `<td><input type="number" step="any" class="form-control input-sm sat-calib-in" data-i="${i}" data-k="yield" value="${esc(f.yield)}" aria-label="Yield" placeholder="${esc(S.yieldUnit || 'yield')}" /></td>`
                + `<td><input type="date" class="form-control input-sm sat-calib-in" data-i="${i}" data-k="start" value="${esc(f.start)}" aria-label="Season start" /></td>`
                + `<td><input type="date" class="form-control input-sm sat-calib-in" data-i="${i}" data-k="end" value="${esc(f.end)}" aria-label="Season end" /></td>`
                + `<td><button type="button" class="btn btn-link btn-xs sat-calib-del" data-i="${i}">delete</button></td></tr>`).join('') + '</tbody></table>';
    } else {
        c += '<div class="sat-muted sat-small">Draw fields whose harvested yield you know and type it, with the season of that harvest (any year since 2017).</div>';
    }
    $('#sat_calib_fields').html(c);
    // targets of this site
    let t = '';
    saveSite();
    const st2 = step2Targets(S.sites[S.cur] || S);
    if (st2.length) {
        t += `<label class="sat-switch sat-small" style="margin-bottom:6px"><input type="checkbox" id="sat_use_step2"${S.useStep2 !== false ? ' checked' : ''} /><span class="sat-slider"></span>`
            + `Estimate the field${st2.length === 1 ? '' : 's'} from step 2: ${st2.map(x => esc(x.name)).join(', ')} (${st2.reduce((a, x) => a + ringHa(x.ring), 0).toFixed(1)} ha)</label><br>`;
    }
    t += `<button type="button" class="btn btn-default btn-xs" id="sat_draw_target">+ Draw ${st2.length ? 'another' : 'a'} field to estimate</button>`;
    if (S.targets.length) {
        t += '<table class="sat-mini-table" style="margin-top:6px"><tbody>' + S.targets.map((f, i) =>
            `<tr><td><input type="text" class="form-control input-sm sat-target-name" data-i="${i}" value="${esc(f.name)}" maxlength="100" aria-label="Field name" /></td><td class="num sat-muted">${ringHa(f.ring).toFixed(2)} ha</td>`
            + `<td><button type="button" class="btn btn-link btn-xs sat-target-del" data-i="${i}">delete</button></td></tr>`).join('') + '</tbody></table>';
    }
    if (S.models.crop_map) {
        t += `<div style="margin-top:6px"><label class="sat-switch sat-small"><input type="checkbox" id="sat_map_areas"${mapAreasOn() ? ' checked' : ''} /><span class="sat-slider"></span>`
            + `Also estimate the ${esc(cropLabel())} areas the crop map finds in the selected area (at least ${setting('min_patch_ha')} ha)</label></div>`;
    } else {
        t += '<div class="sat-small sat-muted" style="margin-top:4px">Only the fields above are estimated.</div>';
    }
    $('#sat_targets').html(t);
}

/* public average yield of the region, per location (preview of what the run will use) */
function refKey(st) { return [st.loc.id, cropSpecies(), (S.season.end || '').slice(0, 4)].join('|'); }

function renderReferences() {
    if (!S.useReference) { $('#sat_ref_list').html('<span class="sat-muted">Off: the fields get the index only (100 = average), no kg/ha.</span>'); return; }
    if (!cropSpecies()) { $('#sat_ref_list').html('<span class="sat-muted">Choose the crop first.</span>'); return; }
    const rows = allSites().map(st => {
        const k = refKey(st), r = S.refs[k];
        if (r === undefined) fetchReference(st, k);
        if (!r) return `<div>${esc(st.loc.name)}: <span class="sat-muted">looking up the regional average yield…</span></div>`;
        if (r.error) return `<div>${esc(st.loc.name)}: <span class="text-warning">${esc(r.error)}</span> <span class="sat-muted">(its fields keep the index only)</span></div>`;
        if (r.pending) return `<div>${esc(st.loc.name)}: ${esc(r.crop)}, national average from FAOSTAT <span class="sat-muted">(downloaded when the run starts)</span></div>`;
        return `<div>${esc(st.loc.name)}: <b>${esc(r.crop)}, ${esc(r.area)}</b> (${esc(r.level)}): <b>${fmt(r.value, 0)} ${esc(r.unit)}</b> · ${esc(r.source)}, ${esc(r.basis)} · <a href="${esc(r.url)}" target="_blank" rel="noopener">source</a></div>`;
    });
    $('#sat_ref_list').html(rows.join('') + '<div class="sat-warn" style="margin:6px 0 0">Approximate: it assumes your fields average like the region. Good, irrigated or trial fields can be far above the regional average; the error is unknown. Only fields with a known yield give a real calibration.</div>');
}

async function fetchReference(st, k) {
    S.refs[k] = null;   // in progress
    const a = areaOf(st);
    let r;
    try {
        r = await getJSON('reference', { lon: a ? a.lon : st.loc.lon, lat: a ? a.lat : st.loc.lat, species: cropSpecies(), country: st.loc.country || '', year: (S.season.end || '').slice(0, 4) });
    } catch (err) { r = { error: err.message }; }
    S.refs[k] = r;
    if (S.step === 5 && S.yieldMode === 'index') renderReferences();
}

function addClass(v) {
    let name = v, color;
    if (v === '__custom') {
        name = (prompt('Name of the class (e.g. Sugarcane, Eucalyptus):') || '').trim();
        if (!name) return;
    }
    if (S.classes.some(k => k.name.toLowerCase() === name.toLowerCase())) { alert(`There is already a class ${name}.`); return; }
    if (S.classes.length >= 12) { alert('At most 12 classes.'); return; }
    const preset = CLASS_PRESETS.find(([n]) => n === name);
    const used = new Set(S.classes.map(k => k.color));
    color = preset && !used.has(preset[1]) ? preset[1] : (CLASS_COLORS.find(c => !used.has(c)) || '#6b7280');
    let id = 'c_' + name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 30);
    while (S.classes.some(k => k.id === id)) id += '_';
    S.classes.push({ id, name, color });
    renderModel();
}

/** True when every corner is inside the square read for the shown location. */
function insideArea(ring) {
    const a = area();
    if (!a) return false;
    const [[s, w], [n, e]] = squareBounds(a);
    return ring.every(([lon, lat]) => lon >= w && lon <= e && lat >= s && lat <= n);
}

function finishModelDraw(target, ring) {
    if ((target.startsWith('label:') || target === 'target') && !insideArea(ring)) {
        alert('Draw it near the location: only the images around it are read. (Fields with a known yield can be anywhere.)');
        return;
    }
    if (target.startsWith('label:')) {
        S.labels = S.labels.concat([{ class: target.slice(6), ring }]);
    } else if (target === 'calib') {
        S.calib.push({ name: `Calibration ${S.calib.length + 1}`, site: S.loc ? S.loc.name : '', ring, yield: '', start: S.season.start || anaDates().start, end: S.season.end || anaDates().end });
    } else if (target === 'target') {
        const used = new Set(S.targets.map(f => f.name.toLowerCase()));
        let k = S.targets.length + 1;
        while (used.has(`field ${k}`)) k++;
        S.targets = S.targets.concat([{ name: `Field ${k}`, ring }]);
    }
}

function renderModelDraw() {
    const d = S.draw;
    if (!(d.active && d.where === 'model')) { $('#sat_model_draw').hide(); renderModelHint(); return; }
    let what = 'an area';
    if (d.target.startsWith('label:')) { const k = S.classes.find(c => c.id === d.target.slice(6)); what = `an example of <b>${esc(k ? k.name : '')}</b>`; }
    else if (d.target === 'calib') what = 'a field with a known yield';
    else if (d.target === 'target') what = 'a field to estimate';
    $('#sat_model_draw').html(`<div class="sat-draw-active" style="margin:0"><b>Drawing ${what}:</b> click its corners on the map (${d.pts.length} so far); double-click the last corner or press Finish.`
        + ` <button type="button" class="btn btn-primary btn-xs" id="sat_mdraw_finish"${d.pts.length < 3 ? ' disabled' : ''}>Finish</button>`
        + ` <button type="button" class="btn btn-default btn-xs" id="sat_mdraw_undo"${d.pts.length ? '' : ' disabled'}>Undo corner</button>`
        + ' <button type="button" class="btn btn-link btn-xs" id="sat_mdraw_cancel">Cancel</button></div>').show();
    renderModelHint();
}

function renderModelHint() {
    $('#sat_model_hint').html(S.draw.active && S.draw.where === 'model' ? 'Click the corners on the map. Esc cancels, Enter finishes.'
        : (S.field ? 'Dashed cyan: the fields analysed. Click a drawn area to delete it.' : 'Blue square: the area analysed. Click a drawn area to delete it.'));
}

function drawModelMap(fit) {
    if (!$('#sat_model_map').is(':visible')) return;
    if (!S.mmap) {
        S.mmap = L.map('sat_model_map', { scrollWheelZoom: false, zoomSnap: 0.25, zoomDelta: 0.5 }).setView([0, 0], 2);
        addFullscreen(S.mmap, '#sat_model_map');
        L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 19, attribution: 'Imagery &copy; Esri, Maxar, Earthstar Geographics',
        }).addTo(S.mmap);
        S.mlayers = L.layerGroup().addTo(S.mmap);
        S.mmap.on('click', ev => {
            if (!(S.draw.active && S.draw.where === 'model')) return;
            S.draw.pts.push([ev.latlng.lng, ev.latlng.lat]);
            renderModelDraw();
            drawModelMap(false);
        });
        S.mmap.on('dblclick', () => { if (S.draw.active && S.draw.where === 'model' && S.draw.pts.length >= 3) finishDraw(); });
    }
    S.mmap.invalidateSize();
    S.mlayers.clearLayers();
    const poly = (ring, opt, tip, onDelete) => {
        const pg = L.polygon(ring.map(p => [p[1], p[0]]), opt).addTo(S.mlayers);
        if (tip) pg.bindTooltip(tip);
        if (onDelete) pg.on('click', ev => { if (S.draw.active) return; L.DomEvent.stopPropagation(ev); if (confirm(`Delete ${tip.replace(/<[^>]+>/g, '')}?`)) { onDelete(); renderModel(); drawModelMap(false); } });
        return pg;
    };
    if (S.field && S.field.kind !== 'plots') S.field.plots.forEach(r => { if (r.length > 2) poly(r, { color: '#facc15', weight: 1, fill: false, interactive: false }); });
    if (S.models.crop_map) {
        const kc = S.classes.find(c => c.id === 'crop');
        step2Labels(S).forEach(l => poly(l.ring, { color: kc ? kc.color : '#eab308', weight: 2, dashArray: '6 4', fillColor: kc ? kc.color : '#eab308', fillOpacity: 0.35 }, `Example: ${esc(kc ? kc.name : 'crop')} (from step 2)`));
        if (mapMethod() === 'examples') S.labels.forEach((l, i) => {
            const k = S.classes.find(c => c.id === l.class) || { name: '?', color: '#999' };
            poly(l.ring, { color: '#fff', weight: 1, fillColor: k.color, fillOpacity: 0.65 }, `Example: ${esc(k.name)}`, () => { S.labels = S.labels.filter((x, j) => j !== i); });
        });
    }
    if (S.models.yield) {
        if (S.yieldMode !== 'index') S.calib.forEach((f, i) => { if (f.site === (S.loc && S.loc.name)) poly(f.ring, { color: '#fff', weight: 2, dashArray: '5 4', fillOpacity: 0.1 }, `Calibration: ${esc(f.name)}`, () => { S.calib.splice(i, 1); }); });
        if (S.useStep2 !== false) step2Targets(S).forEach(f => poly(f.ring, { color: '#22d3ee', weight: 2, dashArray: '6 4', fillOpacity: 0.08 }, `To estimate (step 2): ${esc(f.name)}`));
        S.targets.forEach((f, i) => poly(f.ring, { color: '#22d3ee', weight: 2, fillOpacity: 0.12 }, `To estimate: ${esc(f.name)}`, () => { S.targets = S.targets.filter((x, j) => j !== i); }));
    }
    if (S.draw.active && S.draw.where === 'model' && S.draw.pts.length) {
        const ll = S.draw.pts.map(p => [p[1], p[0]]);
        if (ll.length > 1) L.polyline(ll.concat(ll.length > 2 ? [ll[0]] : []), { color: '#f97316', weight: 2, interactive: false }).addTo(S.mlayers);
        ll.forEach(p => L.circleMarker(p, { radius: 4, color: '#fff', weight: 1, fillColor: '#f97316', fillOpacity: 1, interactive: false }).addTo(S.mlayers));
    }
    const a = area();
    if (a) {
        const b = squareBounds(a);
        if (!S.field) L.rectangle(b, { color: '#22d3ee', weight: 2, fill: false, interactive: false }).addTo(S.mlayers);
        if (fit && !S.draw.active) S.mmap.fitBounds(L.latLngBounds(b).pad(0.15));
    }
}

/* advanced settings dialog */

function defaultSetting(k) {
    for (const [, items] of ADVANCED) for (const it of items) if (it[0] === k) return it[2];
    return undefined;
}
function advLabel(k) {
    for (const [, items] of ADVANCED) for (const it of items) if (it[0] === k) return it[1].replace(/ \(.*\)$/, '').toLowerCase();
    return k;
}

function renderAdvanced() {
    const show = { Images: true, 'Crop map': S.models.crop_map, Yield: S.models.yield };
    $('#sat_adv_body').html(ADVANCED.filter(([g]) => show[g]).map(([group, items]) => `<h4 style="margin-top:6px">${esc(group)}</h4><div class="sat-adv-grid">` + items.map(it => {
        const [k, label] = it;
        const v = setting(k);
        if (typeof it[2] === 'boolean') {
            return `<div><label class="sat-switch"><input type="checkbox" class="sat-adv" data-k="${k}"${v ? ' checked' : ''} /><span class="sat-slider"></span>${esc(label)}</label></div>`;
        }
        if (k === 'yield_model' || k === 'map_model') {
            const labels = k === 'yield_model' ? YIELD_MODEL_LABELS : MAP_MODEL_LABELS;
            return `<div><label for="sat_adv_${k}">${esc(label)}</label><select id="sat_adv_${k}" class="form-control input-sm sat-adv" data-k="${k}">`
                + it[3].map(o => `<option value="${o}"${o === v ? ' selected' : ''}>${esc(labels[o] || o)}</option>`).join('')
                + `</select><div class="sat-help">${esc(it[4])}</div></div>`;
        }
        if (k === 'predictors') {
            return `<div><label>${esc(label)}</label>` + it[3].map(o => `<div class="checkbox" style="margin:2px 0"><label style="font-weight:normal"><input type="checkbox" class="sat-adv-pred" value="${o}"${v.includes(o) ? ' checked' : ''} /> ${esc(PREDICTOR_NAMES[o])}</label></div>`).join('')
                + `<div class="sat-help">${esc(it[4])}</div></div>`;
        }
        const [, , , min, max, step, help] = it;
        return `<div><label for="sat_adv_${k}">${esc(label)}</label><input type="number" id="sat_adv_${k}" class="form-control input-sm sat-adv" data-k="${k}" value="${v}" min="${min}" max="${max}" step="${step}" />`
            + (help ? `<div class="sat-help">${esc(help)}</div>` : '') + '</div>';
    }).join('') + '</div>').join(''));
}

function readAdvanced(el) {
    const k = $(el).data('k');
    if ($(el).is(':checkbox')) { S.settings[k] = $(el).prop('checked'); return; }
    if (k === 'yield_model' || k === 'map_model') { S.settings[k] = $(el).val(); return; }
    const spec = ADVANCED.flatMap(([, items]) => items).find(it => it[0] === k);
    let v = parseFloat($(el).val());
    if (!isFinite(v)) v = spec[2];
    v = Math.min(spec[4], Math.max(spec[3], v));
    $(el).val(v);
    S.settings[k] = v;
}

/* run */

function runPayload() {
    const sites = allSites();
    const settings = {};
    ADVANCED.forEach(([, items]) => items.forEach(it => { settings[it[0]] = setting(it[0]); }));
    return {
        dates: { ...anaDates() }, crop: cropSpecies(), crop_class: S.models.crop_map ? 'crop' : '',
        crop_map_method: S.models.crop_map ? mapMethod() : 'examples',
        models: { ...S.models }, settings,
        classes: S.models.crop_map && mapMethod() === 'examples' ? S.classes.map(k => ({ id: k.id, name: k.name })) : [],
        sites: sites.map(st => {
            const a = areaOf(st);
            return {
                id: st.loc.id, name: st.loc.name, center: [a.lon, a.lat], size_m: a.sizeM,
                labels: !S.models.crop_map ? [] : (mapMethod() === 'standard' ? step2Labels(st) : siteLabels(st)).map(l => ({ class: l.class, ring: l.ring })), targets: S.models.yield ? siteTargets(st).map(x => ({ name: x.name, ring: x.ring })) : [],
                plots_trial_id: S.models.indices && st.field && st.field.kind === 'plots' ? st.trial.id : null,
                // the selected area: the field(s) of step 2 and those drawn to estimate (none: the whole square)
                area: step2Targets(st).concat(st.targets || []).map(x => x.ring).filter(r => r && r.length >= 3),
                exclude_scenes: (st.hidden || []).filter(id => /^[A-Za-z0-9_]+$/.test(id)),
            };
        }),
        yield: S.models.yield ? { mode: ['index', 'saved'].includes(S.yieldMode) ? S.yieldMode : 'calibrated', saved_model_id: S.yieldMode === 'saved' ? S.savedModelId : null,
            reference: S.yieldMode === 'index' && S.useReference, map_areas: mapAreasOn(), season_mode: S.seasonMode, trait_name: S.yieldMode === 'calibrated' ? 'Yield of the fields drawn' : '', unit: S.yieldUnit, per_ha: S.perHa, season: { ...S.season } } : {},
        calibration: S.models.yield && S.yieldMode === 'calibrated' ? S.calib.filter(c => c.yield !== '' && isFinite(+c.yield)).map(c => ({ name: c.name, site: c.site, ring: c.ring, yield: +c.yield, start: c.start, end: c.end })) : [],
    };
}

async function startRun() {
    $('#sat_run').prop('disabled', true);
    try {
        const r = await postJSON('run', { request: JSON.stringify(runPayload()), notify: $('#sat_notify').prop('checked') ? 1 : '' });
        S.job = { runId: r.run_id, timer: null, results: null, site: 0, status: 'running', t0: Date.now(), skipped: r.skipped || [], progress: '', notify: r.notify || '' };
        try { localStorage.setItem('sat_last_run', r.run_id); } catch (e) { /* private mode */ }
        S.runsList = null; loadRuns();
        goStep(6);
    } catch (err) {
        alert(err.message);
        renderModel();
    }
}

/* ---------- step 6: results ---------- */

function renderJob() {
    const j = S.job;
    $('#sat_run_title').text(j.results && j.results.name ? j.results.name : 'Results');
    if (j.status === 'running') {
        $('#sat_results').hide();
        $('#sat_run_error').empty();
        $('#sat_run_notes').html(j.skipped && j.skipped.length ? `<div class="sat-warn">Calibration trials left out: ${j.skipped.map(esc).join(' ')}</div>` : '');
        $('#sat_run_progress').show();
        $('#sat_run_info').html('Running on the server: you can close this page or keep working.'
            + (S.job.notify ? ` An email with the link to the results will be sent to <b>${esc(S.job.notify)}</b>.` : '')
            + ' It is also listed in your profile (Jobs), and in <i>Earlier analyses</i> on this page.');
        $('#sat_run_log_box').show();
        pollJob();
    } else if (j.status === 'failed') {
        $('#sat_run_progress').hide();
        $('#sat_run_info').empty();
        $('#sat_run_logfile').attr('href', fileUrl('log')).show();
        $('#sat_results').hide();
        $('#sat_run_error').html(`<div class="alert alert-danger" style="white-space:pre-wrap">${esc(j.error || 'The run failed.')}</div>`);
    } else if (j.results) {
        $('#sat_run_progress').hide();
        $('#sat_run_info').empty();
        $('#sat_run_log_box').hide();
        $('#sat_run_logfile').attr('href', fileUrl('log')).attr('title', 'Everything the server did in this run').show();
        renderResults();
    } else if (j.runId) {
        j.status = 'running';
        renderJob();
    }
    renderStepper();
}

function pollJob() {
    const j = S.job;
    clearTimeout(j.timer);
    const tick = async () => {
        if (S.job !== j) return;
        let r;
        try { r = await getJSON('status', { run_id: j.runId }); }
        catch (err) { j.status = 'failed'; j.error = err.message; renderJob(); return; }
        const sec = r.seconds || 0;
        $('#sat_run_elapsed').text(sec < 60 ? `${sec} s` : `${Math.floor(sec / 60)} min ${String(sec % 60).padStart(2, '0')} s`);
        $('#sat_run_text').text(r.progress ? `Working on the server: ${r.progress}` : 'Starting…');
        if (r.log) {
            const pre = document.getElementById('sat_run_log');
            const atEnd = pre && pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 8;
            $('#sat_run_log').text(r.log.join('\n'));
            $('#sat_run_log_n').text(`(${r.log_lines || r.log.length} steps)`);
            if (pre && atEnd) pre.scrollTop = pre.scrollHeight;
        }
        if (r.status === 'running') { j.timer = setTimeout(tick, 3000); return; }
        if (r.status === 'failed') { j.status = 'failed'; j.error = r.error; renderJob(); loadRuns(); return; }
        try { j.results = await getJSON('results', { run_id: j.runId }); j.status = 'done'; }
        catch (err) { j.status = 'failed'; j.error = err.message; }
        renderJob();
        loadRuns();   // the Earlier analyses list showed it as running
    };
    $('#sat_run_text').text('Starting…');
    tick();
}

const resSite = () => (S.job.results.sites || [])[S.job.site] || {};
const fmt = (v, d = 1) => (v === null || v === undefined || !isFinite(v) ? '–' : Number(v).toLocaleString(undefined, { maximumFractionDigits: d, minimumFractionDigits: d }));
const fileUrl = name => `${API}/file?` + new URLSearchParams({ run_id: S.job.runId, name }).toString();

/* ---------- the report: everything about the area and the period ---------- */

const FIELD_COLORS = ['#2563eb', '#d97706', '#9333ea', '#dc2626', '#0891b2', '#65a30d', '#db2777', '#4b5563'];

function reportCalendar(R, s) {
    const imgs = s.images || [];
    if (!imgs.length) return '';
    const t0 = Date.parse(R.dates.start + 'T00:00:00Z'), t1 = Date.parse(R.dates.end + 'T23:59:59Z');
    const W = 820, H = 70, L0 = 10, R0 = 10;
    const X = d => L0 + (W - L0 - R0) * (Date.parse(d + 'T12:00:00Z') - t0) / Math.max(1, t1 - t0);
    let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Image calendar">`;
    svg += `<line x1="${L0}" x2="${W - R0}" y1="${H - 20}" y2="${H - 20}" stroke="#d1d5db" />`;
    imgs.forEach(e => {
        const x = X(e.date);
        const col = { used: '#2f6b3a', cloudy: '#9ca3af', failed: '#dc2626', outside: '#e5e7eb' }[e.status] || '#9ca3af';
        const h = e.status === 'used' ? 8 + 32 * (e.clear || 0) / 100 : 8;
        svg += `<rect x="${(x - 2).toFixed(1)}" y="${(H - 20 - h).toFixed(1)}" width="4" height="${h.toFixed(1)}" fill="${col}"><title>${esc(fmtDate(e.date))}: ${esc(e.status)}${e.clear !== undefined ? `, ${e.clear}% of the area clear` : ''}</title></rect>`;
    });
    const months = [];
    for (let d = new Date(t0); d.getTime() <= t1; d.setUTCMonth(d.getUTCMonth() + 1, 1)) months.push(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)));
    const every = Math.ceil(months.length / 12);
    months.forEach((m, i) => { if (m.getTime() >= t0 && !(i % every)) svg += `<text x="${X(m.toISOString().slice(0, 10))}" y="${H - 6}" font-size="10" fill="#6b7280">${m.toLocaleDateString(undefined, { month: 'short', year: '2-digit', timeZone: 'UTC' })}</text>`; });
    return svg + '</svg><div class="sat-report-legend"><span><i style="background:#2f6b3a;height:10px;width:4px"></i>used (taller = clearer)</span><span><i style="background:#9ca3af;height:8px;width:4px"></i>too cloudy</span><span><i style="background:#dc2626;height:8px;width:4px"></i>could not be read</span></div>';
}

function reportChart(R, s, fields) {
    const area = s.area_series || [];
    const t0 = Date.parse(R.dates.start + 'T00:00:00Z'), t1 = Date.parse(R.dates.end + 'T23:59:59Z');
    const W = 820, H = 260, L0 = 38, R0 = 10, T0 = 10, B0 = 26;
    const X = d => L0 + (W - L0 - R0) * (Date.parse(d + 'T12:00:00Z') - t0) / Math.max(1, t1 - t0);
    const Y = v => T0 + (H - T0 - B0) * (1 - (v + 0.1) / 1.1);
    let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="NDVI over the period">`;
    [0, 0.2, 0.4, 0.6, 0.8, 1].forEach(v => { svg += `<line x1="${L0}" x2="${W - R0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#eef0f2" /><text x="${L0 - 5}" y="${Y(v) + 3}" font-size="10" text-anchor="end" fill="#6b7280">${v.toFixed(1)}</text>`; });
    const months = [];
    for (let d = new Date(t0); d.getTime() <= t1; d.setUTCMonth(d.getUTCMonth() + 1, 1)) months.push(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)));
    const every = Math.ceil(months.length / 12);
    months.forEach((m, i) => { if (m.getTime() >= t0 && !(i % every)) svg += `<text x="${X(m.toISOString().slice(0, 10))}" y="${H - 8}" font-size="10" fill="#6b7280">${m.toLocaleDateString(undefined, { month: 'short', year: '2-digit', timeZone: 'UTC' })}</text>`; });
    const line = (pts, col, w, dash) => pts.length > 1 ? `<polyline fill="none" stroke="${col}" stroke-width="${w}"${dash ? ` stroke-dasharray="${dash}"` : ''} points="${pts.map(p => `${X(p[0]).toFixed(1)},${Y(p[1]).toFixed(1)}`).join(' ')}" />` : '';
    const ap = area.filter(e => e.ndvi !== null && e.clear >= 30).map(e => [e.date, e.ndvi]);
    svg += line(ap, '#9ca3af', 1.5, '4 3');
    fields.slice(0, FIELD_COLORS.length).forEach((f, i) => {
        const sr = f.series || { date: [], ndvi: [] };
        const pts = (sr.date || []).map((d, k) => [d, sr.ndvi[k]]).filter(p => p[1] !== null && p[1] !== undefined);
        const col = FIELD_COLORS[i];
        svg += line(pts, col, 2.2);
        pts.forEach(p => { svg += `<circle cx="${X(p[0]).toFixed(1)}" cy="${Y(p[1]).toFixed(1)}" r="2.4" fill="${col}"><title>${esc(f.field)}, ${esc(fmtDate(p[0]))}: NDVI ${fmt(p[1], 2)}</title></circle>`; });
        (f.seasons || []).forEach(z => {
            const mk = (d, sym, tip) => { if (!d) return; svg += `<text x="${X(d).toFixed(1)}" y="${(H - B0 - 4).toFixed(1)}" font-size="12" text-anchor="middle" fill="${col}"><title>${esc(f.field)}: ${esc(tip)} ${esc(fmtDate(d))}</title>${sym}</text>`; };
            mk(z.bare_until, '▲', 'bare until (sowing)');
            if (z.peak_date) svg += `<circle cx="${X(z.peak_date).toFixed(1)}" cy="${Y(z.peak).toFixed(1)}" r="5" fill="none" stroke="${col}" stroke-width="2"><title>${esc(f.field)}: peak ${esc(fmtDate(z.peak_date))} (${fmt(z.peak, 2)})</title></circle>`;
            if (z.harvested) mk(z.bare_again, z.end_type === 'dry-down' ? '▽' : '▼', z.end_type === 'dry-down' ? 'dried down by' : 'harvested by');
        });
    });
    svg += '</svg>';
    const leg = `<div class="sat-report-legend"><span><i style="background:#9ca3af"></i>whole area (mean)</span>`
        + fields.slice(0, FIELD_COLORS.length).map((f, i) => `<span><i style="background:${FIELD_COLORS[i]}"></i>${esc(f.field)}</span>`).join('')
        + '<span>▲ bare soil until (sowing) · ○ peak · ▼ harvested by · ▽ dried down by</span></div>';
    return svg + leg;
}

function renderReport(R, s) {
    const Y = R.yield, cm = R.crop_map;
    const crop = cropLabelOf(R);
    const imgs = s.images || [];
    const n = k => imgs.filter(e => e.status === k).length;
    const used = imgs.filter(e => e.status === 'used').map(e => e.date).sort();
    let gap = 0, gapFrom = null, gapTo = null;
    for (let i = 1; i < used.length; i++) { const g = daysBetween(used[i - 1], used[i]); if (g > gap) { gap = g; gapFrom = used[i - 1]; gapTo = used[i]; } }
    const km = s.size_m ? (s.size_m / 1000).toFixed(1) : '?';
    const [lon, lat] = s.center || [];
    const p = [];
    p.push(`<p><b>${esc(s.name)}</b>${lat !== undefined ? ` (${fmt(lat, 4)}, ${fmt(lon, 4)})` : ''}: a ${km} × ${km} km area, from <b>${fmtDate(R.dates.start)}</b> to <b>${fmtDate(R.dates.end)}</b> (${Math.round(daysBetween(R.dates.start, R.dates.end))} days), Sentinel-2 Level-2A images (10 m pixels).</p>`);
    p.push(`<p><b>Images:</b> ${s.dates_found ?? imgs.length} dates found${s.dates_hidden ? ` (${s.dates_hidden} more hidden by you)` : ''}; <b>${s.dates_used ?? n('used')}</b> clear enough to use, ${n('cloudy')} too cloudy${n('failed') ? `, ${n('failed')} could not be read` : ''}.`
        + (gap ? ` The longest stretch without a usable image was <b>${Math.round(gap)} days</b> (${fmtDate(gapFrom)} – ${fmtDate(gapTo)}).` : '') + '</p>');
    if (cm && s.classes) {
        const total = s.classes.reduce((t, k) => t + k.ha, 0) + (s.uncertain_ha || 0);
        const c = s.classes.find(k => k.id === R.crop_class);
        let t = `<p><b>Land cover:</b> ${c ? `<b>${fmt(c.ha)} ha of ${esc(c.name)}</b> (${fmt(total ? 100 * c.ha / total : 0, 0)}% of the area)` : ''}`;
        if (cm.method !== 'standard') t += `; ${s.classes.filter(k => k.id !== R.crop_class).map(k => `${esc(k.name)} ${fmt(k.ha)} ha`).join(', ')}`;
        if (s.uncertain_ha) t += `; ${fmt(s.uncertain_ha)} ha uncertain`;
        t += cm.method === 'standard' ? `, found by the stored ${esc(cm.standard.crop)} season curve (no examples).` : cm.accuracy ? `, from your examples (cross-validated accuracy ${fmt(100 * cm.accuracy.overall, 0)}%).` : ', from your examples.';
        if (s.sowing) t += ` ${esc(crop)} sowing estimated around <b>${fmtDate(s.sowing.median)}</b> (most between ${fmtDate(s.sowing.q10)} and ${fmtDate(s.sowing.q90)}).`;
        const chk = (s.check || []).filter(x => x.pixels > 0);
        if (chk.length) { const px = chk.reduce((a, x) => a + x.pixels, 0), ok = chk.reduce((a, x) => a + x.as_crop, 0); t += ` Check: ${fmt(100 * ok / px, 0)}% of your step-2 field was found as ${esc(crop)}.`; }
        p.push(t + '</p>');
    }
    // fields of this location, one entry per field (all its rows / seasons)
    const rows = (Y && Y.targets ? Y.targets : []).filter(t => String(t.site_id) === String(s.id));
    const byField = [];
    rows.forEach(t => {
        const key = t.field || t.name;
        let f = byField.find(x => x.field === key);
        if (!f) { f = { field: key, area_ha: t.area_ha, source: t.source, series: t.series, seasons: t.seasons || [], rows: [], share: t.map_crop_share }; byField.push(f); }
        f.rows.push(t);
    });
    byField.forEach(f => {
        let t = `<p><b>${esc(f.field)}</b> (${fmt(f.area_ha, 1)} ha${f.source === 'map' ? `, ${esc(crop)} area found by the map` : ''}${f.share !== undefined && f.share !== null ? `, ${fmt(100 * f.share, 0)}% ${esc(crop)} on the map` : ''}): `;
        t += f.seasons.length ? `${f.seasons.length === 1 ? 'one season' : `${f.seasons.length} seasons`} — ${f.seasons.map(z => esc(seasonText(z))).join('; ')}.` : 'no crop season (green-up from bare soil) found in the period.';
        f.rows.filter(r => r.index !== undefined && r.index !== null || r.estimate !== undefined).forEach(r => {
            const est = r.estimate !== undefined && r.estimate !== null;
            t += ` ${r.season ? esc(SEASON_LABEL[r.season.label] || 'season') + ': ' : ''}${r.index !== undefined && r.index !== null ? `index <b>${fmt(r.index, 0)}</b>` : ''}${est ? `${r.index !== undefined && r.index !== null ? ', ' : ''}${Y.mode === 'index' ? '≈ ' : ''}<b>${fmt(r.estimate, 0)}</b> ${esc(Y.unit || 'kg/ha')}${r.lower !== undefined ? ` (${fmt(r.lower, 0)} – ${fmt(r.upper, 0)})` : ''}` : ''}.`;
        });
        p.push(t + '</p>');
    });
    if (Y && Y.mode === 'index' && Y.references && Y.references.length) p.push(`<p><b>Yield reference:</b> ${Y.references.map(r => `${esc(r.source)} ${esc(r.crop)}, ${esc(r.area)}: ${fmt(r.value, 0)} kg/ha (${esc(r.basis)})`).join('; ')}. Approximate: assumes the fields average like the region.</p>`);
    if (Y && Y.metrics) p.push(`<p><b>Yield model:</b> calibrated on ${Y.metrics.n} fields of known ${esc(Y.trait || 'yield')} — R² ${fmt(Y.metrics.r2, 2)}, error ${fmt(Y.metrics.rmse, 1)} (leave one field out).</p>`);
    let html = p.join('');
    // by season (the site's seasons, e.g. summer and safrinha)
    const sm = s.season_maps || [];
    const tbs = ((Y && Y.totals_by_season) || []).filter(t => String(t.site_id) === String(s.id));
    const seasonIds = [...new Set(sm.map(z => z.season).concat(tbs.map(t => t.season)))];
    if (seasonIds.length) {
        html += '<h4>By season</h4><table class="sat-mini-table"><thead><tr><th>Season</th><th class="num">' + esc(crop) + ' on the map (ha)</th><th>Sowing (map)</th><th class="num">Fields</th><th class="num">ha</th><th class="num">Mean index</th>'
            + (tbs.some(t => t.production !== null && t.production !== undefined) ? '<th class="num">≈ kg/ha</th><th class="num">≈ production (t)</th>' : '') + '</tr></thead><tbody>'
            + seasonIds.map(id => {
                const z = sm.find(x => x.season === id), t = tbs.find(x => x.season === id);
                const prod = tbs.some(x => x.production !== null && x.production !== undefined);
                return `<tr><td>${esc(SEASON_LABEL[id] || id)}</td><td class="num">${z ? fmt(z.crop_ha) : '–'}</td><td>${z && z.sowing ? `~${fmtDate(z.sowing.median)} (${fmtDate(z.sowing.q10)} – ${fmtDate(z.sowing.q90)})` : '–'}</td>`
                    + `<td class="num">${t ? t.fields : 0}</td><td class="num">${t ? fmt(t.area_ha) : '–'}</td><td class="num">${t && t.mean_index !== null && t.mean_index !== undefined ? fmt(t.mean_index, 0) : '–'}</td>`
                    + (prod ? `<td class="num">${t && t.mean_yield !== null && t.mean_yield !== undefined ? `≈ ${fmt(t.mean_yield, 0)}` : '–'}</td><td class="num">${t && t.production !== null && t.production !== undefined ? `≈ ${fmt(t.production / 1000, 1)}` : '–'}</td>` : '') + '</tr>';
            }).join('') + '</tbody></table>';
        if (cm && cm.split && cm.seasons_source) html += `<div class="sat-small sat-muted" style="margin-top:4px">Season windows (sowing): ${(cm.seasons || []).map(z => `${esc(z.label)} ${esc(z.sow[0])} – ${esc(z.sow[1])}`).join('; ')}. ${esc(cm.seasons_source)}</div>`;
    }
    html += '<h4>Images over the period</h4>' + reportCalendar(R, s);
    html += '<h4>Vegetation (NDVI) over the period</h4>' + reportChart(R, s, byField);
    if (byField.length) {
        html += '<h4>Fields and seasons</h4><table class="sat-mini-table"><thead><tr><th>Field</th><th class="num">ha</th><th>Season</th><th>Bare until (sowing)</th><th>Peak</th><th>Harvest</th></tr></thead><tbody>'
            + byField.map(f => (f.seasons.length ? f.seasons : [null]).map((z, k) => `<tr><td>${k ? '' : esc(f.field)}</td><td class="num">${k ? '' : fmt(f.area_ha, 1)}</td>`
                + (z ? `<td>${esc(SEASON_LABEL[z.label] || 'season')} ${esc(z.year || '')}</td><td>${z.started_before_period ? `green from ${fmtDate(z.green_from)}` : fmtDate(z.bare_until)}</td><td>${fmtDate(z.peak_date)} (${fmt(z.peak, 2)})</td><td>${!z.harvested ? `still green on ${fmtDate(z.last_green)}` : z.end_type === 'dry-down' ? `no sharp harvest (dried down by ${fmtDate(z.bare_again)})` : `${fmtDate(z.last_green)} – ${fmtDate(z.bare_again)}`}</td>`
                    : '<td colspan="4" class="sat-muted">no season found</td>') + '</tr>').join('')).join('') + '</tbody></table>';
    }
    // method and sources
    const src = [];
    src.push('Images: Copernicus Sentinel-2 Level-2A (ESA), 10 m, from the Earth Search catalogue (Element 84 / AWS open data); clouds from the Sentinel-2 scene classification' + (s.dates_hidden ? '; images hidden by hand left out' : '') + '.');
    if (cm) src.push(cm.method === 'standard' ? `Crop map: each pixel's NDVI season compared with a stored ${esc(cm.standard.crop)} curve (${esc(cm.standard.source || '')}).`
        : `Crop map: ${esc(cm.model_label || 'random forest')}${cm.comparison && cm.comparison.length > 1 ? ` (chosen among ${cm.comparison.map(z => esc(z.label)).join(', ')} by cross-validation by drawn area)` : ''} on period means of 6 bands + NDVI / NDRE / EVI, trained on your drawn examples.`);
    if (Y) src.push(Y.mode === 'index' ? 'Yield: relative index = NDVI area under the season curve, 100 = average field of the same kind of season' + (Y.references && Y.references.length ? `; approximate kg/ha from ${Y.references.map(r => esc(r.citation || r.source)).join('; ')}` : '') + '.'
        : `Yield: ${esc(YIELD_MODEL_LABELS[Y.model] || Y.model)} on ${(Y.predictor_labels || []).map(esc).join(' + ')}${Y.comparison && Y.comparison.length > 1 ? ` (chosen among ${Y.comparison.length} models, ${esc((Y.selection || {}).rule || '')}; validated ${esc((Y.metrics || {}).cv || '')})` : ''}, calibrated on fields of known ${esc(String(Y.trait || 'yield').replace(/\|[^|]*$/, ''))}.`);
    src.push('Seasons: green-up to NDVI ≥ 0.6 from bare soil (≤ 0.35) and back, from each field\'s curve; a harvest when NDVI falls by 0.2 or more within 30 days, otherwise a slow dry-down.');
    if (R.software) src.push(`Software: ${esc(R.software.R || 'R')}, terra ${esc(R.software.terra || '')}${R.software.randomForest ? `, randomForest ${esc(R.software.randomForest)}` : ''}, GDAL ${esc(R.software.GDAL || '')}.`);
    html += '<h4>Method and sources</h4><ul class="sat-small" style="padding-left:18px">' + src.map(x => `<li>${x}</li>`).join('') + '</ul>';
    html += `<div class="sat-small sat-muted">Breedbase satellite report · run ${esc(R.run_id || '')} · computed ${esc((R.created || '').replace('T', ' '))}</div>`;
    $('#sat_report_body').html(html);
}

const cropLabelOf = R => { const c = R.crop || ''; return COMMON[c] || c || 'the crop'; };

/** A standalone copy of the report and results (map as an image), to keep or send. */
function downloadReport() {
    const R = S.job.results;
    const node = document.getElementById('sat_results').cloneNode(true);
    const live = document.getElementById('sat_results').querySelectorAll('canvas');
    node.querySelectorAll('canvas').forEach((c, i) => { const img = document.createElement('img'); try { img.src = live[i].toDataURL('image/png'); } catch (e) { /* tainted */ } img.style.width = '100%'; img.style.imageRendering = 'pixelated'; c.replaceWith(img); });
    node.querySelectorAll('button, .sat-res-tabs, .sat-report-buttons, a.btn').forEach(e => e.remove());
    const css = [...document.querySelectorAll('style')].map(x => x.textContent).filter(t => t.includes('.sat-')).join('\n');
    const doc = `<!doctype html><html><head><meta charset="utf-8"><title>${esc(R.name || 'Satellite report')}</title><style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:1000px;margin:20px auto;padding:0 16px;color:#111827}`
        + 'table{border-collapse:collapse}.row{display:flex;flex-wrap:wrap;gap:16px}.col-sm-5,.col-sm-6,.col-sm-7{flex:1 1 300px}' + css + `</style></head><body class="sat-app"><h2>${esc(R.name || 'Satellite report')}</h2>${node.innerHTML}</body></html>`;
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([doc], { type: 'text/html' }));
    a.download = `${R.run_id || 'satellite'}_report.html`;
    document.body.appendChild(a); a.click(); a.remove();
}

function renderResults() {
    const R = S.job.results;
    learnSeasonLabels(R);
    $('#sat_results').show();
    $('#sat_run_meta').text(`${fmtDate(R.dates.start)} – ${fmtDate(R.dates.end)} · computed in ${Math.round(R.seconds)} s`);
    $('#sat_run_notes').html(R.notes && R.notes.length ? `<div class="sat-warn"><b>Notes</b><ul style="margin:4px 0 0 18px;padding:0">${R.notes.map(n => `<li>${esc(n)}</li>`).join('')}</ul></div>` : '');
    const sites = R.sites || [];
    $('.sat-res-tabs').html(sites.length > 1 ? sites.map((s, i) => `<button type="button" class="sat-site${i === S.job.site ? ' on' : ''}" data-i="${i}">${esc(s.name)}</button>`).join('') : '');
    const s = resSite();
    // tiles
    const tiles = [[`${s.dates_used ?? '–'}<small style="font-size:13px"> / ${s.dates_found ?? '–'}</small>`, 'dates used / found']];
    const crop = R.crop_map && s.classes ? s.classes.find(k => k.id === R.crop_class) : null;
    if (crop) tiles.push([`${fmt(crop.ha)}<small style="font-size:13px"> ha</small>`, `${esc(crop.name)} on the map`]);
    if (R.crop_map && R.crop_map.accuracy) tiles.push([`${fmt(100 * R.crop_map.accuracy.overall)}<small style="font-size:13px">%</small>`, 'map accuracy']);
    const tot = R.yield && R.yield.totals ? R.yield.totals.find(t => String(t.site_id) === String(s.id)) : null;
    const rough = R.yield && R.yield.metrics && R.yield.metrics.r2 < 0.3 ? ', rough' : '';
    if (R.yield && R.yield.mode === 'index' && tot) {
        tiles.push([String(tot.fields), 'fields compared (index)']);
        if (tot.production !== null && tot.production !== undefined) tiles.push([`≈ ${fmt(tot.production / 1000, 1)}<small style="font-size:13px"> t</small>`, 'production, approximate (regional average)']);
    }
    if (R.yield && R.yield.mode === 'index') { /* no yield value */ } else if (tot && R.yield.per_ha && tot.production !== null) tiles.push([fmt(tot.production, 0), `production (${esc(R.yield.unit || 'yield')} × ha${rough})`]);
    else if (tot && tot.mean_yield !== null) tiles.push([fmt(tot.mean_yield), `mean yield${R.yield.unit ? ` (${esc(R.yield.unit)}${rough})` : rough ? ' (rough)' : ''}`]);
    $('#sat_res_stats').html(tiles.map(([v, l]) => `<div class="sat-stat"><div class="v">${v}</div><div class="l">${l}</div></div>`).join(''));
    renderReport(R, s);
    // map
    $('#sat_res_map_card').toggle(!!R.crop_map);
    if (R.crop_map) renderResultMap(R, s);
    // yield
    $('#sat_res_yield_card').toggle(!!R.yield);
    if (R.yield) renderResultYield(R, s);
    // indices
    const withInd = sites.filter(x => x.indices);
    $('#sat_res_indices_card').toggle(!!(R.models && R.models.indices));
    $('#sat_res_ind_csv').attr('href', R.indices ? fileUrl('indices.csv') : '#').toggle(!!R.indices);
    $('#sat_res_indices').html(withInd.length ? withInd.map(x => {
        const saved = (R.saved_indices || {})[x.indices.trial_id];
        return `<div style="margin-bottom:8px"><b>${esc(x.indices.trial_name)}</b>: ${x.indices.values} values (${x.indices.plots} plots × up to ${x.indices.dates} dates; NDVI, NDRE, EVI per plot and date) `
            + (saved ? `<span class="text-success">· stored as phenotypes (${saved.values} values).</span>`
                : `<button type="button" class="btn btn-primary btn-xs sat-save-ind" data-trial="${x.indices.trial_id}">Store as phenotypes of the trial</button>`)
            + '<div class="sat-small sat-muted">Traits satellite NDVI / NDRE / EVI (time series, one value per image date). A 10 m pixel is larger than most plots: neighbouring plots share pixels.</div></div>';
    }).join('') : '<span class="sat-muted">No plot had a clear date.</span>');
}

function renderResultMap(R, s) {
    const cm = R.crop_map, classes = cm.classes || [];
    $('#sat_res_site').text(R.sites.length > 1 ? s.name : '');
    $('#sat_res_tif').attr('href', s.map_file ? fileUrl(s.map_file.replace(/^.*?\.(site\d+\.map\.tif)$/, '$1')) : '#').toggle(!!s.map_file);
    const colorOf = {};
    const std = cm.method === 'standard';
    classes.forEach((k, i) => { const own = !std && S.classes.find(c => c.id === k.id); colorOf[i + 1] = own ? own.color : std ? (k.id === 'crop' ? '#eab308' : '#475569') : CLASS_COLORS[i % CLASS_COLORS.length]; });
    colorOf[classes.length + 1] = UNCERTAIN_COLOR;
    // a map per season (long periods): selector above the map
    const sm = s.season_maps || [];
    if (S.job.mapSeason && !sm.some(z => z.season === S.job.mapSeason)) S.job.mapSeason = null;
    $('#sat_res_season').remove();
    if (sm.length) {
        $('#sat_res_canvas').closest('.sat-result-map').before(`<div class="sat-segs" id="sat_res_season" style="margin-bottom:8px"><button type="button" class="sat-seg${!S.job.mapSeason ? ' on' : ''}" data-v="">Whole period</button>`
            + sm.map(z => `<button type="button" class="sat-seg${S.job.mapSeason === z.season ? ' on' : ''}" data-v="${esc(z.season)}">${esc(z.label)}: ${fmt(z.crop_ha)} ha</button>`).join('') + '</div>');
    }
    const sel = sm.find(z => z.season === S.job.mapSeason);
    const m = sel ? { ...s.map, rle: sel.rle } : s.map;
    const cv = document.getElementById('sat_res_canvas');
    if (m && cv) {
        cv.width = m.ncol; cv.height = m.nrow;
        const ctx = cv.getContext('2d'), img = ctx.createImageData(m.ncol, m.nrow);
        let p = 0;
        for (let i = 0; i < m.rle.length; i += 2) {
            const v = m.rle[i], n = m.rle[i + 1];
            const col = v ? colorOf[v] || '#000000' : null;
            const rgb = col ? [parseInt(col.slice(1, 3), 16), parseInt(col.slice(3, 5), 16), parseInt(col.slice(5, 7), 16)] : null;
            for (let k = 0; k < n; k++, p++) {
                if (!rgb) continue;
                img.data[p * 4] = rgb[0]; img.data[p * 4 + 1] = rgb[1]; img.data[p * 4 + 2] = rgb[2]; img.data[p * 4 + 3] = 255;
            }
        }
        ctx.putImageData(img, 0, 0);
    }
    const ha = k => (s.classes || []).find(x => x.id === k.id);
    $('#sat_res_legend').html(classes.map((k, i) => `<span><span class="sat-swatch" style="background:${colorOf[i + 1]}"></span>${esc(k.name)}</span>`).join('')
        + `<span><span class="sat-swatch" style="background:${UNCERTAIN_COLOR}"></span>${std ? 'Uncertain (season not seen: clouds)' : 'Uncertain'}</span><span><span class="sat-swatch" style="background:#1f2937"></span>No clear image</span>`);
    const total = (s.classes || []).reduce((t, k) => t + k.ha, 0) + (s.uncertain_ha || 0);
    $('#sat_res_areas').html('<table class="sat-mini-table"><thead><tr><th>Class</th><th class="num">ha</th><th class="num">%</th></tr></thead><tbody>'
        + classes.map((k, i) => { const h = ha(k) ? ha(k).ha : 0; return `<tr><td><span class="sat-swatch" style="display:inline-block;vertical-align:middle;background:${colorOf[i + 1]}"></span> ${esc(k.name)}${k.trained ? '' : ' <span class="text-warning">(no example)</span>'}</td><td class="num">${fmt(h)}</td><td class="num">${fmt(total ? 100 * h / total : 0)}</td></tr>`; }).join('')
        + `<tr><td><span class="sat-swatch" style="display:inline-block;vertical-align:middle;background:${UNCERTAIN_COLOR}"></span> ${std ? 'Uncertain (season not seen)' : `Uncertain (below ${fmt(cm.min_confidence, 0)}% of the votes)`}</td><td class="num">${fmt(s.uncertain_ha || 0)}</td><td class="num">${fmt(total ? 100 * (s.uncertain_ha || 0) / total : 0)}</td></tr>`
        + (sm.length ? sm.map(z => `<tr><td style="padding-left:24px">${esc(z.label)}: ${esc(cm.standard ? cm.standard.crop : 'crop')}${z.sowing ? ` <span class="sat-muted sat-small">(sown ~${fmtDate(z.sowing.median)})</span>` : ''}</td><td class="num">${fmt(z.crop_ha)}</td><td class="num">${fmt(total ? 100 * z.crop_ha / total : 0)}</td></tr>`).join('') : '')
        + '</tbody></table>');
    const a = cm.accuracy;
    let acc = '';
    if (std) {
        acc += `<div class="sat-small"><b>Method:</b> stored ${esc(cm.standard.crop)} curve matched to every pixel (no examples). <span class="text-warning">Proof of concept.</span></div>`;
        if (s.sowing) acc += `<div style="margin-top:6px"><b>Sowing</b> (estimated from the curve): median ${fmtDate(s.sowing.median)}, most between ${fmtDate(s.sowing.q10)} and ${fmtDate(s.sowing.q90)}; cycle about ${s.sowing.cycle_days} days.</div>`;
        const chk = (s.check || []).filter(c => c.pixels > 0);
        if (chk.length) {
            const px = chk.reduce((t, c) => t + c.pixels, 0), asCrop = chk.reduce((t, c) => t + c.as_crop, 0);
            acc += `<div style="margin-top:6px"><b>Check with your step-2 field:</b> ${fmt(100 * asCrop / px, 0)}% of its ${px} pixels found as ${esc(cm.standard.crop)}`
                + ` (${chk.reduce((t, c) => t + c.as_other, 0)} not, ${chk.reduce((t, c) => t + c.uncertain, 0)} uncertain).</div>`;
        } else {
            acc += '<div class="sat-muted sat-small" style="margin-top:6px">Accuracy not measured: no field of known maize to check against.</div>';
        }
    } else if (a) {
        if (cm.comparison && cm.comparison.length > 1) {
            acc += '<div class="sat-small" style="margin-bottom:6px"><b>Classifiers compared</b> (same folds by drawn area; best kappa used):</div><table class="sat-mini-table" style="margin-bottom:8px"><thead><tr><th>Model</th><th class="num">Accuracy</th><th class="num">Kappa</th><th class="num">s</th></tr></thead><tbody>'
                + cm.comparison.map(z => z.failed ? `<tr><td>${esc(z.label)}</td><td colspan="3" class="sat-muted sat-small">could not be fitted</td></tr>`
                    : `<tr${z.chosen ? ' style="background:var(--sat-accent-soft)"' : ''}><td>${z.chosen ? '<b>' : ''}${esc(z.label)}${z.chosen ? '</b> ✓' : ''}</td><td class="num">${fmt(100 * z.overall, 1)}%</td><td class="num">${fmt(z.kappa, 2)}</td><td class="num">${z.seconds}</td></tr>`).join('') + '</tbody></table>';
        } else if (cm.model_label) acc += `<div class="sat-small" style="margin-bottom:6px"><b>Classifier:</b> ${esc(cm.model_label)}</div>`;
        const names = a.classes.map(id => (classes.find(k => k.id === id) || { name: id }).name);
        acc += `<div><b>Accuracy</b> ${fmt(100 * a.overall)}% · kappa ${fmt(a.kappa, 2)} <span class="sat-muted sat-small">(cross-validation, ${a.folds} folds by drawn area, ${a.pixels} pixels)</span></div>`
            + '<table class="sat-mini-table sat-cm" style="margin-top:6px"><thead><tr><th>drawn \\ mapped</th>' + names.map(n => `<th>${esc(n)}</th>`).join('') + '<th>right</th></tr></thead><tbody>'
            + a.matrix.map((row, i) => `<tr><th>${esc(names[i])}</th>` + row.map((v, j) => `<td class="${i === j ? 'diag' : ''}">${v}</td>`).join('') + `<td>${fmt(100 * a.producer[i], 0)}%</td></tr>`).join('')
            + '</tbody></table><div class="sat-help" style="margin-top:4px">Measured only on the drawn areas: land covers you did not draw are not checked (see Uncertain).</div>';
    } else {
        acc += '<div class="sat-muted sat-small">Accuracy not measured: draw at least 2 areas of each class.</div>';
    }
    if (cm.importance && cm.importance.length) acc += `<div class="sat-small" style="margin-top:8px"><b>Most useful image features:</b> ${cm.importance.slice(0, 6).map(i => esc(i.feature)).join(' · ')}</div>`;
    $('#sat_res_accuracy').html(acc);
}

const SEASON_LABEL = { season: 'season', other: "season outside the country's season windows" };
/** The site's season names (summer, safrinha…) with the labels the run used. */
function learnSeasonLabels(R) {
    const Y = R.yield || {};
    (Y.season_names || []).forEach((n, i) => { SEASON_LABEL[n] = (Y.season_labels || [])[i] || n; });
    ((R.crop_map || {}).seasons || []).forEach(z => { SEASON_LABEL[z.id] = z.label || z.id; });
}
/** "main season 2025/26 · bare until 10 Nov · peak 12 Feb (0.88) · harvested between 2 and 14 Apr" */
function seasonText(z) {
    if (!z) return '';
    const p = [`${SEASON_LABEL[z.label] || 'season'} ${z.year || ''}`];
    p.push(z.started_before_period ? `green from ${fmtDate(z.green_from)} (sown before the period)` : `bare until ${fmtDate(z.bare_until)}`);
    p.push(`peak ${fmtDate(z.peak_date)} (${fmt(z.peak, 2)})`);
    p.push(!z.harvested ? `still green on ${fmtDate(z.last_green)}`
        : z.end_type === 'dry-down' ? `dried down slowly (no sharp harvest) by ${fmtDate(z.bare_again)}`
            : `harvested between ${fmtDate(z.last_green)} and ${fmtDate(z.bare_again)}`);
    return p.join(' · ');
}
function seasonsCell(t) {
    if (t.season) return `<span class="sat-small">${esc(seasonText(t.season))}</span>`;
    if (t.seasons && t.seasons.length) return `<span class="sat-small sat-muted">${t.seasons.map(z => esc(seasonText(z))).join('<br>')}</span>`;
    return '';
}

function renderResultIndex(R, s) {
    const Y = R.yield;
    let h = `<div class="sat-small sat-muted">Relative yield index (no known yields): ${esc(Y.index_basis || 'season curve')} of each field, 100 = the average of the fields of the same kind of season · ${Y.season_mode && Y.season_mode !== 'dates' ? `seasons found in each field's curve (${esc({ detected: 'all', main: 'main season', second: 'second crop' }[Y.season_mode])})` : `season ${fmtDate(Y.season.start)} – ${fmtDate(Y.season.end)}`}</div>`
        + (Y.references && Y.references.length
            ? '<div class="sat-warn" style="margin-top:8px"><b>Approximate kg/ha, not a calibration.</b> The regional average yield below is scaled by each field\'s season curve, assuming your fields average like the region. Good, irrigated or trial fields can be far above it; the error cannot be measured without fields of known yield.</div>'
                + '<table class="sat-mini-table" style="margin:6px 0 10px"><thead><tr><th>Reference</th><th>Area</th><th class="num">kg/ha</th><th>Years</th><th>Used for</th></tr></thead><tbody>'
                + Y.references.map(r => `<tr><td><a href="${esc(r.url)}" target="_blank" rel="noopener">${esc(r.source)}</a> · ${esc(r.crop)}</td><td>${esc(r.area)} (${esc(r.level)})</td><td class="num">${fmt(r.value, 0)}</td><td class="sat-small">${esc(r.basis)}</td><td class="sat-small">${(r.sites || []).map(esc).join(', ')} (${r.fields} field${r.fields === 1 ? '' : 's'})</td></tr>`).join('')
                + '</tbody></table>'
            : '<div class="sat-warn" style="margin-top:8px">An index compares the fields of this run with each other: 120 means a greener, longer season than the average field, which usually means more yield, but it is not a yield in kg/ha and its error cannot be measured without fields of known yield.</div>');
    const ts = (Y.targets || []).filter(t => String(t.site_id) === String(s.id)).sort((a, b) => (a.rank ?? 1e9) - (b.rank ?? 1e9));
    h += `<h4>Fields${R.sites.length > 1 ? ` of ${esc(s.name)}` : ''}</h4>`;
    if (!ts.length) h += '<div class="sat-muted sat-small">No field to estimate here.</div>';
    else {
        const est = ts.some(t => t.estimate !== undefined && t.estimate !== null);
        const share = ts.some(t => t.map_crop_share !== undefined && t.map_crop_share !== null);
        h += `<div style="max-height:420px;overflow:auto"><table class="sat-mini-table"><thead><tr><th class="num">Rank</th><th>Field</th><th>Season</th><th>From</th><th class="num">ha</th><th class="num">Clear dates</th><th class="num">NDVI peak</th><th class="num">Index</th>${share ? `<th class="num">${esc(cropLabel())} on the map</th>` : ''}${est ? '<th class="num">≈ kg/ha</th>' : ''}<th></th></tr></thead><tbody>`
            + ts.map(t => `<tr><td class="num">${t.rank ?? '–'}</td><td>${esc(t.field || t.name)}</td><td>${seasonsCell(t)}</td><td class="sat-muted">${t.source === 'map' ? 'found by the map' : 'your field'}</td><td class="num">${fmt(t.area_ha, 2)}</td><td class="num">${t.n_dates}</td>`
                + `<td class="num">${fmt(t.ndvi_max, 2)}</td><td class="num"><b>${t.index !== null && t.index !== undefined ? fmt(t.index, 0) : '–'}</b></td>`
                + (share ? `<td class="num">${t.map_crop_share !== undefined && t.map_crop_share !== null ? `${fmt(100 * t.map_crop_share, 0)}%` : ''}</td>` : '')
                + (est ? `<td class="num">${t.estimate !== undefined && t.estimate !== null ? `≈ ${fmt(t.estimate, 0)}` : '–'}</td>` : '')
                + `<td class="sat-small sat-muted">${esc(t.reason || '')}</td></tr>`).join('')
            + '</tbody></table></div>';
    }
    const withEst = (Y.totals || []).some(t => t.production !== null && t.production !== undefined);
    if (Y.totals && (Y.totals.length > 1 || withEst)) {
        h += `<h4>Per location</h4><table class="sat-mini-table"><thead><tr><th>Location</th><th class="num">Fields</th><th class="num">ha</th><th class="num">Mean index (by area)</th>${withEst ? '<th class="num">≈ kg/ha</th><th class="num">≈ production (t)</th>' : ''}</tr></thead><tbody>`
            + Y.totals.map(t => `<tr><td>${esc(t.site)}</td><td class="num">${t.fields}</td><td class="num">${fmt(t.area_ha)}</td><td class="num">${fmt(t.mean_index, 0)}</td>`
                + (withEst ? `<td class="num">${t.mean_yield !== null && t.mean_yield !== undefined ? `≈ ${fmt(t.mean_yield, 0)}` : '–'}</td><td class="num">${t.production !== null && t.production !== undefined ? `≈ ${fmt(t.production / 1000, 1)}` : '–'}</td>` : '') + '</tr>').join('');
        if (withEst && Y.totals.length > 1) {
            const p = Y.totals.reduce((a, t) => a + (t.production || 0), 0), ha = Y.totals.reduce((a, t) => a + (t.area_ha || 0), 0);
            h += `<tr><th>Total</th><th class="num">${Y.totals.reduce((a, t) => a + t.fields, 0)}</th><th class="num">${fmt(ha)}</th><th></th><th></th><th class="num">≈ ${fmt(p / 1000, 1)}</th></tr>`;
        }
        h += '</tbody></table>';
    }
    $('#sat_res_yield').html(h);
    $('#sat_res_csv').attr('href', R.fields_file ? fileUrl('fields.csv') : '#').toggle(!!R.fields_file);
}

function renderResultYield(R, s) {
    if (R.yield.mode === 'index') { renderResultIndex(R, s); return; }
    const Y = R.yield, u = Y.unit ? ` (${esc(Y.unit)})` : '';
    let h = `<div class="sat-small sat-muted">${esc(String(Y.trait || 'Yield').replace(/\|[^|]*$/, ''))} · ${esc(YIELD_MODEL_LABELS[Y.model] || Y.model)} on ${(Y.predictor_labels || []).map(esc).join(' + ')}${Y.metrics && Y.metrics.cv ? ` · validated ${esc(Y.metrics.cv)}` : ''}</div>`;
    if (Y.comparison && Y.comparison.length > 1) {
        h += '<details style="margin-top:6px" open><summary class="sat-small"><b>Models compared</b> — ' + esc((Y.selection || {}).rule || '') + '</summary><table class="sat-mini-table" style="margin-top:4px"><thead><tr><th>Model</th><th class="num">R²</th><th class="num">RMSE</th><th class="num">MAE</th><th class="num">Bias</th><th></th></tr></thead><tbody>'
            + Y.comparison.map(z => z.failed ? `<tr><td>${esc(z.label)}</td><td colspan="5" class="sat-muted sat-small">could not be fitted</td></tr>`
                : `<tr${z.chosen ? ' style="background:var(--sat-accent-soft)"' : ''}><td>${z.chosen ? '<b>' : ''}${esc(z.label)}${z.chosen ? '</b> ✓' : ''}</td><td class="num">${fmt(z.r2, 2)}</td><td class="num">${fmt(z.rmse, 1)}</td><td class="num">${fmt(z.mae, 1)}</td><td class="num">${fmt(z.bias, 1)}</td><td></td></tr>`).join('')
            + '</tbody></table></details>';
    }
    if (Y.metrics) {
        const m = Y.metrics;
        h += `<div class="sat-stats" style="margin:10px 0"><div class="sat-stat"><div class="v">${fmt(m.r2, 2)}</div><div class="l">R² (${esc(m.cv || 'cross-validation')})</div></div>`
            + `<div class="sat-stat"><div class="v">${fmt(m.rmse)}</div><div class="l">error RMSE${u}</div></div><div class="sat-stat"><div class="v">${fmt(m.mae)}</div><div class="l">mean abs. error</div></div>`
            + `<div class="sat-stat"><div class="v">${m.n}</div><div class="l">calibration fields</div></div></div>`;
        if (m.r2 < 0.3) h += `<div class="sat-warn">The satellite curve explains little of the yield differences between these calibration fields (R² ${fmt(m.r2, 2)}): treat the estimates as rough.</div>`;
        h += '<div class="row"><div class="col-sm-5" id="sat_yield_plot"></div><div class="col-sm-7">';
        if (Y.coefficients && Y.coefficients.length) h += '<table class="sat-mini-table"><thead><tr><th>Term</th><th class="num">Estimate</th><th class="num">SE</th></tr></thead><tbody>'
            + Y.coefficients.map(c => `<tr><td>${esc(PREDICTOR_NAMES[c.term] || c.term)}</td><td class="num">${fmt(c.estimate, 3)}</td><td class="num">${c.se !== undefined ? fmt(c.se, 3) : ''}</td></tr>`).join('') + '</tbody></table>';
        h += '</div></div>';
    } else {
        h += `<div class="sat-warn">No yield model: ${Y.n_used} of ${Y.n_calibration} calibration fields usable, at least ${Y.min_fields} needed. The fields below show their season index only (not a yield).</div>`;
    }
    // estimates
    const ts = (Y.targets || []).filter(t => String(t.site_id) === String(s.id));
    h += `<h4>Fields${R.sites.length > 1 ? ` of ${esc(s.name)}` : ''}</h4>`;
    if (!ts.length) h += '<div class="sat-muted sat-small">No field to estimate here.</div>';
    else {
        h += `<div style="max-height:360px;overflow:auto"><table class="sat-mini-table"><thead><tr><th>Field</th><th>From</th><th class="num">ha</th><th class="num">Clear dates</th><th class="num">NDVI peak</th><th class="num">NDVI area</th>${Y.metrics ? `<th class="num">Yield${u}</th><th class="num">${fmt(Y.level * 100, 0)}% interval</th>` : ''}<th></th></tr></thead><tbody>`
            + ts.map(t => `<tr><td>${esc(t.field || t.name)}${t.map_crop_share !== undefined && t.map_crop_share !== null ? `<br><span class="sat-small sat-muted">${fmt(100 * t.map_crop_share, 0)}% ${esc(cropLabel())} on the map</span>` : ''}${t.season || (t.seasons && t.seasons.length) ? `<br>${seasonsCell(t)}` : ''}</td><td class="sat-muted">${t.source === 'map' ? 'found by the map' : 'your field'}</td><td class="num">${fmt(t.area_ha, 2)}</td><td class="num">${t.n_dates}</td><td class="num">${fmt(t.ndvi_max, 2)}</td><td class="num">${fmt(t.ndvi_auc, 0)}</td>`
                + (Y.metrics ? `<td class="num"><b>${fmt(t.estimate)}</b></td><td class="num sat-muted">${t.lower !== undefined ? `${fmt(t.lower)} – ${fmt(t.upper)}` : ''}</td>` : '')
                + `<td class="sat-small">${t.extrapolation ? '<span class="text-warning" title="Its season curve is outside the range of the calibration fields">outside calibration</span>' : esc(t.reason || '')}</td></tr>`).join('')
            + '</tbody></table></div>';
    }
    if (Y.totals && Y.totals.length) {
        h += '<h4>Totals per location</h4><table class="sat-mini-table"><thead><tr><th>Location</th><th class="num">Fields</th><th class="num">ha</th><th class="num">Mean yield</th>' + (Y.per_ha ? '<th class="num">Production</th>' : '') + '</tr></thead><tbody>'
            + Y.totals.map(t => `<tr><td>${esc(t.site)}</td><td class="num">${t.fields}</td><td class="num">${fmt(t.area_ha)}</td><td class="num">${fmt(t.mean_yield)}</td>` + (Y.per_ha ? `<td class="num">${fmt(t.production, 0)}</td>` : '') + '</tr>').join('');
        if (Y.totals.length > 1) {
            const sum = (k) => Y.totals.reduce((a, t) => a + (t[k] || 0), 0);
            h += `<tr><th>Total</th><th class="num">${sum('fields')}</th><th class="num">${fmt(sum('area_ha'))}</th><th></th>` + (Y.per_ha ? `<th class="num">${fmt(sum('production'), 0)}</th>` : '') + '</tr>';
        }
        h += '</tbody></table>';
    }
    // calibration fields
    const cal = Y.calibration || [];
    if (cal.length) {
        h += `<details style="margin-top:10px"><summary class="sat-small"><b>Calibration fields (${cal.filter(c => c.used).length} used of ${cal.length})</b></summary><table class="sat-mini-table" style="margin-top:6px"><thead><tr><th>Field</th><th>From</th><th>Season</th><th class="num">Observed${u}</th><th class="num">Predicted (left out)</th><th class="num">Clear dates</th><th></th></tr></thead><tbody>`
            + cal.map(c => `<tr><td>${esc(c.name)}</td><td class="sat-muted">${c.source === 'trial' ? 'trial' : 'drawn'}</td><td class="sat-small">${esc(c.start)} – ${esc(c.end)}</td><td class="num">${fmt(c.observed)}</td><td class="num">${c.loo !== null && c.loo !== undefined ? fmt(c.loo) : ''}</td><td class="num">${c.n_dates}</td><td class="sat-small text-warning">${esc(c.reason || '')}</td></tr>`).join('')
            + '</tbody></table></details>';
    }
    if (R.can_save_model) {
        h += R.saved_model_entry
            ? `<div class="sat-small text-success" style="margin-top:10px">Saved as the model "<b>${esc(R.saved_model_entry.name)}</b>": choose it next time with "Use a saved model".</div>`
            : '<div style="margin-top:10px"><button type="button" class="btn btn-primary btn-sm" id="sat_save_model">Save this trained model</button> <span class="sat-small sat-muted">to estimate other fields later without calibrating again (stored as a Breedbase analysis model).</span></div>';
    }
    if (Y.saved_model) h = `<div class="sat-small" style="margin-bottom:6px">Estimated with the saved model "<b>${esc(Y.saved_model.name || '')}</b>" (trained ${esc(String(Y.saved_model.created || '').slice(0, 10))} on ${Y.saved_model.n || '?'} fields).</div>` + h;
    $('#sat_res_yield').html(h);
    $('#sat_res_csv').attr('href', R.fields_file ? fileUrl('fields.csv') : '#').toggle(!!R.fields_file);
    if (Y.metrics) drawYieldPlot(cal.filter(c => c.used && c.loo !== null && c.loo !== undefined), u);
}

function drawYieldPlot(pts, unit) {
    if (!pts.length) return;
    const W = 360, H = 300, L0 = 52, B0 = 40, T0 = 12, R0 = 12;
    const all = pts.flatMap(p => [p.observed, p.loo]);
    let lo = Math.min(...all), hi = Math.max(...all);
    const pad = (hi - lo) * 0.08 || 1; lo -= pad; hi += pad;
    const X = v => L0 + (W - L0 - R0) * (v - lo) / (hi - lo), Y = v => H - B0 - (H - T0 - B0) * (v - lo) / (hi - lo);
    let svg = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Observed against predicted yield">`;
    for (let i = 0; i <= 4; i++) {
        const v = lo + (hi - lo) * i / 4;
        svg += `<line x1="${L0}" x2="${W - R0}" y1="${Y(v)}" y2="${Y(v)}" stroke="#eef0f2" /><text x="${L0 - 6}" y="${Y(v) + 4}" font-size="10" text-anchor="end" fill="#6b7280">${fmt(v, 0)}</text>`
            + `<text x="${X(v)}" y="${H - B0 + 14}" font-size="10" text-anchor="middle" fill="#6b7280">${fmt(v, 0)}</text>`;
    }
    svg += `<line x1="${X(lo)}" y1="${Y(lo)}" x2="${X(hi)}" y2="${Y(hi)}" stroke="#9ca3af" stroke-dasharray="4 3" />`;
    pts.forEach(p => { svg += `<circle cx="${X(p.observed)}" cy="${Y(p.loo)}" r="4.5" fill="${p.source === 'trial' ? '#2b7a4b' : '#fff'}" stroke="#2b7a4b" stroke-width="1.5"><title>${esc(p.name)}: observed ${fmt(p.observed)}, predicted ${fmt(p.loo)}</title></circle>`; });
    svg += `<text x="${(L0 + W - R0) / 2}" y="${H - 6}" font-size="11" text-anchor="middle" fill="#374151">observed${esc(unit.replace(/<[^>]+>/g, ''))}</text><text x="12" y="${(T0 + H - B0) / 2}" font-size="11" text-anchor="middle" fill="#374151" transform="rotate(-90 12 ${(T0 + H - B0) / 2})">predicted, field left out</text></svg>`;
    $('#sat_yield_plot').html(svg + '<div class="sat-help">Each field predicted by a model fitted without it. Dashed: perfect prediction. Filled: trials, open: drawn fields.</div>');
}

async function saveIndices(trialId, btn) {
    if (!confirm('Store the satellite NDVI, NDRE and EVI of the plots as phenotypes of this trial? Values already stored for the same plot and date are kept.')) return;
    $(btn).prop('disabled', true).text('Storing…');
    try {
        const r = await postJSON('save_indices', { run_id: S.job.runId, trial_id: trialId });
        S.job.results.saved_indices = { ...(S.job.results.saved_indices || {}), [trialId]: { values: r.values } };
        renderResults();
    } catch (err) {
        alert(err.message);
        $(btn).prop('disabled', false).text('Store as phenotypes of the trial');
    }
}

/* ---------- start ---------- */

$(async function () {
    setPreset('3m');
    renderControls();
    goStep(1);
    $('#sat_loc_search').on('input', renderLocations);
    $('#sat_locations').on('click', '.sat-loc', function () { toggleLocation($(this).data('id')); });
    $('#sat_selected').on('click', '.sat-chip-x', function () { removeSite(+$(this).data('i')); });
    $('#sat_selected').on('click', '#sat_clear_sites', () => {
        if (!confirm(`Remove all ${S.sites.length} locations from this analysis?`)) return;
        for (let i = S.sites.length - 1; i >= 0; i--) removeSite(i);
    });
    $('.sat-app').on('click', '.sat-site', function () { useSite(+$(this).data('i')); });
    // drawing and saving fields (step 2)
    $('#sat_draw_box').on('click', '#sat_draw_farm', () => startDraw('farm'));
    $('#sat_draw_box').on('click', '#sat_draw_trial', () => startDraw('trial'));
    $('#sat_draw_box').on('click', '#sat_draw_finish', finishDraw);
    $('#sat_draw_box').on('click', '#sat_draw_cancel', cancelDraw);
    $('#sat_draw_box').on('click', '#sat_draw_undo', () => { S.draw.pts.pop(); renderDrawBox(); drawMap(false); });
    $('#sat_draw_box').on('click', '#sat_trial_save', () => saveTrialField(false));
    $('#sat_draw_box').on('click', '#sat_trial_remove', () => { if (confirm(`Remove the field saved with ${S.trial.name}?`)) saveTrialField(true); });
    $('#sat_draw_box').on('click', '.sat-field-del', function () {
        const i = +$(this).data('i');
        if (!confirm(`Delete ${S.farmFields[i].name}?`)) return;
        S.farmFields = S.farmFields.filter((f, k) => k !== i);
        S.fieldsDirty = true;
        refreshField(); renderControls(); drawMap(false);
    });
    $('#sat_draw_box').on('change', '.sat-field-name', function () {
        const i = +$(this).data('i'), name = String($(this).val()).trim();
        if (!name || S.farmFields.some((f, k) => k !== i && f.name.toLowerCase() === name.toLowerCase())) { $(this).val(S.farmFields[i].name); return; }
        S.farmFields = S.farmFields.map((f, k) => (k === i ? { ...f, name } : f));
        S.fieldsDirty = true;
        renderControls(); drawMap(false);
    });
    $(document).on('keydown', ev => {
        if (ev.key === 'Escape' && !S.draw.active && $('.sat-map-full').length) {
            if (S.map && $('#sat_map').hasClass('sat-map-full')) toggleFullscreen(S.map, '#sat_map', null, true);
            if (S.mmap && $('#sat_model_map').hasClass('sat-map-full')) toggleFullscreen(S.mmap, '#sat_model_map', null, true);
            return;
        }
        if (!S.draw.active || S.step !== (S.draw.where === 'model' ? 5 : 2) || $(ev.target).is('input, textarea, select')) return;
        if (ev.key === 'Escape') cancelDraw();
        if (ev.key === 'Enter' && S.draw.pts.length >= 3) finishDraw();
    });
    window.addEventListener('beforeunload', ev => {
        saveSite();
        if (S.sites.some(st => st.trialDirty)) { ev.preventDefault(); ev.returnValue = ''; }
    });
    $('#sat_stepper').on('click', 'li', function () { goStep(+$(this).data('step')); });
    $('.sat-app').on('click', '.sat-next', function () { goStep(+$(this).data('to')); });
    $('#sat_field_mode').on('click', '.sat-option', function (ev) { ev.preventDefault(); setMode($(this).data('v')); });
    $('#sat_view').on('click', '.sat-option', function (ev) {
        ev.preventDefault();
        S.view = $(this).data('v');
        renderControls();
        if (S.scenes.length && S.step === 4) renderImages();
    });
    $('#sat_sources').on('click', '.sat-option', function (ev) {
        ev.preventDefault();
        const k = $(this).data('v');
        S.sources[k] = !S.sources[k];
        renderControls();
    });
    $('#sat_cloudy, #sat_cloudy4').on('change', function () {
        S.showCloudy = $(this).prop('checked');
        renderControls();
        if (S.scenes.length && S.step === 4) renderImages();
    });
    $('#sat_trial').on('change', function () { chooseTrial($(this).val()); });
    $('#sat_start, #sat_end').on('change', () => {
        S.start = $('#sat_start').val(); S.end = $('#sat_end').val(); S.preset = null; S.datesTouched = true;
        renderControls();
        if (S.start && S.end && S.start <= S.end) datesChanged(false);   // loaded by the Load images button
    });
    $('#sat_load').on('click', () => {
        S.start = $('#sat_start').val(); S.end = $('#sat_end').val();
        if (!S.start || !S.end || S.start > S.end) { alert('Choose a start date before the end date.'); return; }
        datesChanged(true);
    });
    $('#sat_go').on('click', () => goStep(4));
    // step 5
    $('#sat_models').on('click', '.sat-option', function (ev) {
        ev.preventDefault();
        if ($(this).hasClass('disabled')) return;
        const k = $(this).data('v');
        S.models[k] = !S.models[k];
        if (S.draw.active && S.draw.where === 'model') cancelDraw();
        renderModel(); drawModelMap(false);
        if (k === 'yield' && S.models.yield) loadTrialInfo();
    });
    $('#sat_crop').on('change', function () {
        S.crop = $(this).val();
        renderModel();
    });
    $('#sat_crop_other').on('input', function () { S.cropOther = $(this).val(); renderModel(); $('#sat_crop_other').focus(); });
    $('#sat_season_start, #sat_season_end').on('change', () => { S.season = { start: $('#sat_season_start').val(), end: $('#sat_season_end').val() }; renderModel(); });
    $('#sat_classes').on('click', '.sat-class-draw', function () { startDraw(`label:${S.classes[+$(this).data('i')].id}`, 'model'); });
    $('#sat_classes').on('click', '.sat-class-del', function () {
        const k = S.classes[+$(this).data('i')];
        const n = allSites().reduce((t, st) => t + (st.labels || []).filter(l => l.class === k.id).length, 0);
        if (n && !confirm(`Remove the class ${k.name} and its ${n} example area${n === 1 ? '' : 's'}?`)) return;
        S.sites.forEach(st => { st.labels = (st.labels || []).filter(l => l.class !== k.id); });
        S.labels = S.labels.filter(l => l.class !== k.id);
        S.classes = S.classes.filter(c => c.id !== k.id);
        renderModel(); drawModelMap(false);
    });
    $('#sat_classes').on('change', '.sat-class-name', function () {
        const i = +$(this).data('i'), name = String($(this).val()).trim();
        if (!name || S.classes.some((k, j) => j !== i && k.name.toLowerCase() === name.toLowerCase())) { $(this).val(S.classes[i].name); return; }
        S.classes[i].name = name; renderReady(); drawModelMap(false);
    });
    $('#sat_yield_box').on('input', '#sat_yield_unit', function () { S.yieldUnit = $(this).val(); });
    $('#sat_yield_box').on('change', '#sat_yield_unit', () => renderModel());
    $('#sat_yield_box').on('change', '#sat_yield_perha', function () { S.perHa = $(this).prop('checked'); renderModel(); });
    $('#sat_yield_box').on('click', '#sat_draw_calib', () => startDraw('calib', 'model'));
    $('#sat_yield_box').on('change', '#sat_saved', function () { S.savedModelId = $(this).val() || null; renderModel(); });
    $('#sat_yield_box').on('change', '#sat_ref_on', function () { S.useReference = $(this).prop('checked'); renderModel(); });
    $('#sat_yield_mode').on('click', '.sat-option', function (ev) {
        ev.preventDefault();
        S.yieldMode = $(this).data('v');
        S.yieldModeAuto = false;
        if (S.yieldMode === 'saved') S.savedModels = null;   // a model may have been trained in another tab
        renderModel(); drawModelMap(false);
    });
    $('#sat_ready').on('click', '.sat-go', function (ev) {
        ev.preventDefault();
        if ($(this).data('go') === 'year') { S.datesTouched = true; setPreset('12m'); datesChanged(false); renderModel(); return; }
        if ($(this).data('go') === 'calib') {
            const el = document.getElementById('sat_calib_anchor');
            if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); $('#sat_calib_box').addClass('sat-flash'); setTimeout(() => $('#sat_calib_box').removeClass('sat-flash'), 1600); }
        }
    });
    $('#sat_yield_box').on('click', '#sat_draw_target', () => startDraw('target', 'model'));
    $('#sat_map_method').on('click', '.sat-option', function (ev) { ev.preventDefault(); S.mapMethod = $(this).data('v'); if (S.draw.active) endDraw(); renderModel(); drawModelMap(false); });
    $('#sat_classes_box').on('change', '#sat_use_step2_labels', function () { S.useStep2Labels = $(this).prop('checked'); renderModel(); drawModelMap(false); });
    $('#sat_yield_box').on('change', '#sat_map_areas', function () { S.mapAreas = $(this).prop('checked'); renderModel(); });
    $('#sat_yield_box').on('change', '#sat_use_step2', function () { S.useStep2 = $(this).prop('checked'); renderModel(); drawModelMap(false); });
    $('#sat_yield_box').on('input change', '.sat-calib-in', function () {
        const i = +$(this).data('i'), k = $(this).data('k');
        S.calib[i][k] = String($(this).val()).trim();
        renderReady();
    });
    $('#sat_yield_box').on('click', '.sat-calib-del', function () { S.calib.splice(+$(this).data('i'), 1); renderModel(); drawModelMap(false); });
    $('#sat_yield_box').on('change', '.sat-target-name', function () {
        const i = +$(this).data('i'), name = String($(this).val()).trim();
        if (name) S.targets = S.targets.map((t, j) => (j === i ? { ...t, name } : t));
        else $(this).val(S.targets[i].name);
        renderReady(); drawModelMap(false);
    });
    $('#sat_yield_box').on('click', '.sat-target-del', function () { const i = +$(this).data('i'); S.targets = S.targets.filter((t, j) => j !== i); renderModel(); drawModelMap(false); });
    $('#sat_model_draw').on('click', '#sat_mdraw_finish', finishDraw);
    $('#sat_model_draw').on('click', '#sat_mdraw_cancel', cancelDraw);
    $('#sat_model_draw').on('click', '#sat_mdraw_undo', () => { S.draw.pts.pop(); renderModelDraw(); drawModelMap(false); });
    $('#sat_adv_open').on('click', () => { renderAdvanced(); $('#sat_adv_modal').modal('show'); });
    $('#sat_adv_body').on('change', '.sat-adv', function () { readAdvanced(this); renderModel(); });
    $('#sat_adv_body').on('change', '.sat-adv-pred', () => {
        const v = $('#sat_adv_body .sat-adv-pred:checked').map((i, e) => e.value).get();
        if (!v.length) { alert('Keep at least one predictor.'); renderAdvanced(); return; }
        S.settings.predictors = v; renderModel();
    });
    $('#sat_adv_reset').on('click', () => { S.settings = {}; renderAdvanced(); renderModel(); });
    $('#sat_run').on('click', startRun);
    $('#sat_full_report').on('click', () => {
        // everything that applies to the area: crop map, yield with seasons (calibrated if fields of known yield exist), plot indices
        const plots = allSites().some(st => st.field && st.field.kind === 'plots');
        S.models = { crop_map: true, yield: true, indices: plots };
        if (isMaize()) S.mapMethod = 'standard';
        S.seasonMode = 'detected';
        S.yieldMode = calibCount() >= +setting('min_fields') ? 'calibrated' : S.savedModelId ? 'saved' : 'index';
        S.yieldModeAuto = false;
        if (S.yieldMode === 'index') S.useReference = true;
        loadTrialInfo();
        renderModel(); drawModelMap(false);
        $('#sat_ready')[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
    });
    $('#sat_report_print').on('click', () => window.print());
    $('#sat_report_html').on('click', downloadReport);
    $('#sat_ana_start5, #sat_ana_end5').on('change', function () {
        S.ana = { start: $('#sat_ana_start5').val(), end: $('#sat_ana_end5').val() };
        S.anaPreset = null;
        renderAna();
    });
    $('.sat-app').on('click', '.sat-run-open', function () { openRun(String($(this).data('id'))); });
    $('.sat-app').on('click', '.sat-runs-refresh', () => { S.runsList = null; renderRuns(); loadRuns(); });
    // step 6
    $('#sat_results').on('click', '.sat-res-tabs .sat-site', function () { S.job.site = +$(this).data('i'); renderResults(); });
    $('#sat_results').on('click', '.sat-save-ind', function () { saveIndices(+$(this).data('trial'), this); });
    $('#sat_results').on('click', '#sat_save_model', async function () {
        const R = S.job.results;
        const name = (prompt('Name of the model:', `${cropLabelOf(R)} ${String((R.yield || {}).trait || 'yield').replace(/\|[^|]*$/, '')} ${(R.dates || {}).end || ''}`) || '').trim();
        if (!name) return;
        $(this).prop('disabled', true).text('Saving…');
        try {
            const r = await postJSON('save_model', { run_id: S.job.runId, name, description: '' });
            R.saved_model_entry = { id: r.model_id, name: r.name };
            S.savedModels = null;   // reload the list next time
            renderResults();
        } catch (err) { alert(err.message); $(this).prop('disabled', false).text('Save this trained model'); }
    });
    $('#sat_results').on('click', '#sat_res_season .sat-seg', function () { S.job.mapSeason = String($(this).data('v')) || null; renderResults(); });
    $('#sat_grid').on('click', '.sat-tile', function () { showBig(+$(this).data('i')); });
    $('#sat_grid').on('click', '.sat-hide, .sat-unhide', function (ev) {
        ev.stopPropagation();
        const sc = S.visible[+$(this).data('i')];
        if (sc) setHidden(sc, $(this).hasClass('sat-hide'));
    });
    $('#sat_hidden_box').on('change', '#sat_show_hidden', function () { S.showHidden = $(this).prop('checked'); renderImages(); });
    $('#sat_big_hide').on('click', () => {
        const sc = S.visible[S.bigIndex];
        if (!sc) return;
        const hide = !isHidden(sc);
        $('#sat_big_modal').modal('hide');
        setHidden(sc, hide);
    });
    $('#sat_timeline').on('click', '.sat-tick', function () {
        const i = S.visible.findIndex(sc => sc.id === $(this).data('id'));
        if (i >= 0) showBig(i);
    });
    $('#sat_prev').on('click', () => showBig(S.bigIndex - 1));
    $('#sat_next').on('click', () => showBig(S.bigIndex + 1));
    $(document).on('keydown', ev => {
        if (!$('#sat_big_modal').hasClass('in')) return;
        if (ev.key === 'ArrowLeft') showBig(S.bigIndex - 1);
        if (ev.key === 'ArrowRight') showBig(S.bigIndex + 1);
    });
    try {
        const { sources } = await getJSON('sources');
        S.offered = sources;
        sources.forEach(o => { S.sources[o.id] = !o.paid; });   // free ones on; a paid one only when asked
    } catch (err) {
        $('#sat_sources').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`);
    }
    renderControls();
    getJSON('crops').then(r => {
        S.crops = r.crops || [];
        S.seasonNames = r.seasons || [];
        S.seasonCountries = r.season_countries || [];
        // the site's species (sgn.conf preferred_species), else the one with most accessions
        if (!S.crop) S.crop = r.preferred && S.crops.some(c => c.species === r.preferred) ? r.preferred : (S.crops[0] || {}).species || '';
        if (S.step === 5) renderModel();
    }).catch(() => { /* the crop can still be typed */ });
    // a run to show (link from the jobs list): ?run=sat_...
    const want = new URLSearchParams(window.location.search).get('run');
    if (want && /^sat_\d+_\d+$/.test(want)) {
        S.job = { runId: want, timer: null, results: null, site: 0, status: 'running', skipped: [] };
        goStep(6);
    }
    try {
        const { locations } = await getJSON('locations');
        S.locations = locations;
        renderLocations();
    } catch (err) {
        $('#sat_locations').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`);
    }
});
