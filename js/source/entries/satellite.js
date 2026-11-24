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
    'farmFields', 'farmCanEdit', 'fieldsDirty', 'scenes', 'info', 'visible', 'area', 'warnings', 'runKey'];
const S = {
    locations: [], sites: [], cur: -1, typeFilter: 'all',
    loc: null, trials: [], trial: null, trialPlots: null, trialDrawn: null, trialCanEdit: 0, trialDirty: false,
    field: null, point: null, size: 1000, mode: 'point', farmFields: [], farmCanEdit: 0, fieldsDirty: false,
    start: null, end: null, preset: '3m', view: 'rgb', showCloudy: false,
    offered: [], sources: {}, landsatToken: null, tokenFetch: null, warnings: [],
    scenes: [], info: {}, run: 0, abort: null, running: false, visible: [], bigIndex: -1, runKey: null,
    map: null, layers: null, step: 1, draw: { active: false, pts: [], target: null },
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
    return n === 4 && sitesReady() && !!(S.start && S.end) && chosenSources().length > 0;
}

function goStep(n) {
    if (!stepAllowed(n)) return;
    S.step = n;
    $('.sat-pane').hide();
    $(`.sat-pane[data-step="${n}"]`).show();
    renderStepper();
    if (S.draw.active && n !== 2) cancelDraw();
    renderSiteTabs();
    if (n === 2) drawMap(true);
    if (n === 4) showSiteImages();
    window.scrollTo && window.scrollTo(0, 0);
}

function renderStepper() {
    $('#sat_stepper li').each(function () {
        const n = +$(this).data('step');
        $(this).toggleClass('active', n === S.step).toggleClass('done', n < S.step && stepAllowed(n)).toggleClass('off', !stepAllowed(n));
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
    if (f && f.kind === 'farm') return `${f.count} field${f.count === 1 ? '' : 's'}, ${f.ha.toFixed(1)} ha${st.fieldsDirty ? ' (not saved)' : ''}`;
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
        scenes: [], info: {}, visible: [], area: null, warnings: [], runKey: null,
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
    if (S.draw.active) cancelDraw();
    if (S.running) { if (S.abort) S.abort.abort(); S.run++; S.running = false; S.runKey = null; busyEnd(P.token); }
    saveSite();
    loadSite(i);
    S.fieldMsg = '';
    renderTrialSelect();
    renderControls();
    renderSiteTabs();
    if (S.step === 2) drawMap(true);
    if (S.step === 4) showSiteImages();
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
    if ((st.fieldsDirty || st.trialDirty) && !confirm(`${st.loc.name} has fields drawn but not saved. Remove it anyway?`)) return;
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
    const [trials, fields] = await Promise.all([
        getJSON('trials', { location_id: st.loc.id }).then(r => r.trials).catch(() => []),
        getJSON('location_fields', { location_id: st.loc.id }).catch(() => ({ fields: [], can_edit: 0 })),
    ]);
    if (!S.sites.includes(st)) return;
    const farm = (fields.fields || []).map(f => ({ name: f.name, ring: f.ring.slice(0, -1) }));
    siteSet(st, { trials, farmFields: farm, farmCanEdit: fields.can_edit ? 1 : 0, mode: farm.length ? 'fields' : st.mode });
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
        if (t.planting) setPreset('trial');
    }
    renderControls();
    if (S.sites[S.cur] === st) drawMap(true);
}

function setMode(m) {
    if (m === 'trial' && !(S.trials || []).length) return;
    if (S.draw.active) cancelDraw();
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

function startDraw(target) {
    S.fieldMsg = '';
    S.draw = { active: true, pts: [], target };
    if (S.map) { S.map.doubleClickZoom.disable(); $('#sat_map').addClass('sat-drawing'); }
    renderControls();
    drawMap(false);
}

function cancelDraw() {
    S.draw = { active: false, pts: [], target: null };
    if (S.map) { S.map.doubleClickZoom.enable(); $('#sat_map').removeClass('sat-drawing'); }
    renderControls();
    drawMap(false);
}

function finishDraw() {
    const pts = S.draw.pts;
    if (pts.length < 3) { alert('A field needs at least 3 corners.'); return; }
    if (ringHa(pts) < 0.01) { alert('This field is smaller than 0.01 ha.'); return; }
    if (S.draw.target === 'trial') {
        S.trialDrawn = pts.slice(); S.trialDirty = true;
    } else {
        const used = new Set(S.farmFields.map(f => f.name.toLowerCase()));
        let k = S.farmFields.length + 1;
        while (used.has(`field ${k}`)) k++;
        S.farmFields = S.farmFields.concat([{ name: `Field ${k}`, ring: pts.slice() }]);
        S.fieldsDirty = true;
    }
    S.draw = { active: false, pts: [], target: null };
    if (S.map) { S.map.doubleClickZoom.enable(); $('#sat_map').removeClass('sat-drawing'); }
    refreshField();
    renderControls();
    drawMap(false);
}

async function saveFarmFields() {
    const st = S.sites[S.cur];
    $('#sat_fields_save').prop('disabled', true);
    try {
        const r = await postJSON('location_fields', { location_id: st.loc.id, fields: JSON.stringify(S.farmFields.map(f => ({ name: f.name, ring: f.ring }))) });
        siteSet(st, { farmFields: r.fields.map(f => ({ name: f.name, ring: f.ring.slice(0, -1) })), fieldsDirty: false });
        refreshField(st);
        fieldMsg(`Saved ${r.fields.length} field${r.fields.length === 1 ? '' : 's'} with ${esc(st.loc.name)}.`);
    } catch (err) { fieldMsg(esc(err.message), true); }
    renderControls();
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
    const drawing = S.draw.active;
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
            html += '<div class="sat-muted sat-small">No field drawn for this farm yet: the analysis uses the square around its point. Draw the farm\'s fields to analyse exactly them (they are saved with the farm for next time).</div>';
        }
        if (S.fieldsDirty) {
            html += S.farmCanEdit
                ? '<div class="sat-draw-save"><span class="text-warning">Not saved yet.</span> <button type="button" class="btn btn-primary btn-xs" id="sat_fields_save">Save fields with the farm</button></div>'
                : '<div class="sat-small text-warning">These fields are used in this analysis; saving them with the farm needs the submitter or curator role.</div>';
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
        ? `${S.farmFields.length} field${S.farmFields.length === 1 ? '' : 's'} drawn for this location (${S.farmFields.reduce((t, f) => t + ringHa(f.ring), 0).toFixed(1)} ha). Draw, rename or delete fields.`
        : 'Draw the production fields of the farm on the map; they are saved with the farm for the next analyses.');
    $('#sat_field_loc').text(S.loc ? S.loc.name : '');
    $('#sat_trial_box').toggle(S.mode === 'trial');
    $('#sat_size_box').toggle(!S.field);
    renderDrawBox();
    segs('#sat_size', SIZES.map(([v, l]) => [v, l]), S.size, v => { S.size = +v; renderControls(); drawMap(false); });
    const season = trialSeason();
    segs('#sat_presets', [['3m', 'Last 3 months'], ['12m', 'Last 12 months'], ['year', 'This year'],
        ['trial', 'Trial season', !season, season ? `${season[0]} to ${season[1]} (planting − 15 days to harvest + 15 days)` : 'Choose a trial with a planting date in step 2']], S.preset, setPreset);
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
    else if (S.field && S.field.kind === 'plots') hint = `Yellow: the ${S.field.count} plots of this trial (from their GPS coordinates). Dashed square: the area shown, the plots + ${FIELD_MARGIN} m.`;
    else if (S.field) hint = `Yellow: the field${S.field.count === 1 ? '' : 's'}. Dashed square: the area shown, the field${S.field.count === 1 ? '' : 's'} + ${FIELD_MARGIN} m. Cloud is measured over the field${S.field.count === 1 ? '' : 's'}.`;
    else if (S.mode === 'trial' && !S.trial) hint = 'Choose a trial.';
    else if (S.mode === 'trial') hint = 'No plot coordinates and no field drawn: <b>click the map on the field</b> to centre the square on it, or draw the field. Cloud is measured over the whole square.';
    else if (a) hint = 'Red: the location. Dashed square: the area shown. <b>Click the map on the field</b> to move it. Cloud is measured over the whole square.';
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

function drawMap(fit) {
    // only on the visible step-2 map: Leaflet measures its box when drawing, and a hidden
    // box (size 0) would zoom out to the whole world
    if (!$('#sat_map').is(':visible')) return;
    if (!S.map) {
        S.map = L.map('sat_map', { scrollWheelZoom: false }).setView([0, 0], 2);
        L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
            maxZoom: 19, attribution: 'Imagery &copy; Esri, Maxar, Earthstar Geographics',
        }).addTo(S.map);
        S.layers = L.layerGroup().addTo(S.map);
        S.map.on('click', ev => {
            if (S.draw.active) {
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
        S.map.on('dblclick', () => { if (S.draw.active && S.draw.pts.length >= 3) finishDraw(); });
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
    if (S.draw.active && S.draw.pts.length) {
        const ll = S.draw.pts.map(p => [p[1], p[0]]);
        if (ll.length > 1) L.polyline(ll.concat(ll.length > 2 ? [ll[0]] : []), { color: '#f97316', weight: 2, dashArray: ll.length > 2 ? null : '4 3' }).addTo(S.layers);
        ll.forEach(p => L.circleMarker(p, { radius: 4, color: '#fff', weight: 1, fillColor: '#f97316', fillOpacity: 1 }).addTo(S.layers));
    }
    const a = area();
    if (a) {
        const b = squareBounds(a);
        L.rectangle(b, { color: '#22d3ee', weight: 2, fill: false, dashArray: '5 4', interactive: false }).addTo(S.layers);
        if (fit && !S.draw.active) S.map.fitBounds(L.latLngBounds(b).pad(0.6));
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
    let plots = null, box = null;
    if (S.field) {
        plots = S.field.plots.map(r => r.map(p => latLonToUtm(p[1], p[0], utm.zone, utm.south)));
        const all = plots.flat();
        box = [Math.min(...all.map(p => p[0])), Math.min(...all.map(p => p[1])), Math.max(...all.map(p => p[0])), Math.max(...all.map(p => p[1]))];
    }
    return { e, n, utm, plots, box };
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
    let total = 0, valid = 0, cloud = 0;
    for (let y = y0; y < y1; y++) {
        for (let x = x0; x < x1; x++) {
            const m = mask[y * win.w + x];
            total++;
            if (m === M_NODATA) continue;
            valid++;
            if (m === M_CLOUD) cloud++;
        }
    }
    return {
        g, mask, maskWin: win,
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

/** Step 4 for the site shown: its images, searched when not done yet for the current choices. */
function showSiteImages() {
    renderSiteTabs();
    $('#sat_site_name').text(S.sites.length > 1 && S.loc ? S.loc.name : '');
    if (S.runKey === runKey() && S.scenes.length) {
        busyEnd(P.token);
        drawTimeline();
        renderStats();
        renderImages();
        return;
    }
    run();
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
                const inField = x >= fx0 && x < fx1 && y >= fy0 && y < fy1;
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
    ctx.strokeStyle = '#facc15';
    ctx.lineWidth = Math.max(1, px / 400);
    if (g.plots) {
        g.plots.forEach(r => {
            ctx.beginPath();
            if (r.length === 1) { const [x, y] = toPx(r[0]); ctx.arc(x, y, 1.5, 0, 2 * Math.PI); }
            else { r.forEach((p, i) => { const [x, y] = toPx(p); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }); ctx.closePath(); }
            ctx.stroke();
        });
    } else {
        const [x, y] = toPx([g.e, g.n]);
        const r = Math.max(5, px / 60);
        ctx.beginPath(); ctx.moveTo(x - r, y); ctx.lineTo(x + r, y); ctx.moveTo(x, y - r); ctx.lineTo(x, y + r); ctx.stroke();
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

async function renderImages() {
    const runId = S.run;
    const signal = S.abort ? S.abort.signal : undefined;
    S.visible = S.scenes.filter(sc => isShown(S.info[sc.id]));
    $('#sat_legend').html(S.view === 'ndvi'
        ? `NDVI <canvas class="sat-ramp" id="sat_ramp" width="180" height="10"></canvas> −0.2 bare soil … 0.9 dense green canopy · grey = cloud / shadow`
        : (!S.area.fromPlots ? 'Yellow cross: the centre point.' : S.area.kind === 'plots' ? 'Yellow: trial plots.' : S.area.kind === 'farm' ? "Yellow: the farm's fields." : "Yellow: the trial's field.") + ' Click an image to enlarge.');
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
        return `<div class="sat-tile" data-i="${i}"><canvas width="10" height="10"></canvas><div class="sat-tile-cap"><span><b>${esc(fmtDate(sc.date))}</b><br><span class="sat-sat${sc.source === 'landsat' ? ' ls' : ''}">${esc(satName(sc))} · ${sc.res || 10} m</span></span><span class="sat-muted">${info.clearPct}% clear${S.view === 'ndvi' ? '<br><span class="sat-ndvi">…</span>' : ''}</span></div></div>`;
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
    const pts = S.visible.map(sc => ({ sc, b: (S.info[sc.id].images || {}).ndvi })).filter(p => p.b && p.b.ndvi !== null)
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
    $('#sat_chart_note').html(`Mean NDVI of the cloud-free pixels over ${!S.area.fromPlots ? 'the whole square' : S.area.kind === 'plots' ? 'the trial plots (bounding box)' : S.area.kind === 'farm' ? "the farm's fields (bounding box)" : "the trial's field (bounding box)"}; a date counts when at least half of them are clear. ${pts.length} point${pts.length === 1 ? '' : 's'}.`
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
    $('#sat_big_modal').modal('show');
    try {
        const built = await buildImage(sc, S.abort ? S.abort.signal : undefined);
        if (S.bigIndex === i) paint($('#sat_big canvas')[0], sc, built, 860);
    } catch (err) { if (err.name !== 'AbortError') $('#sat_big_info').text('This image could not be read.'); }
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
    $('#sat_draw_box').on('click', '#sat_fields_save', saveFarmFields);
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
        if (!S.draw.active || S.step !== 2 || $(ev.target).is('input, textarea, select')) return;
        if (ev.key === 'Escape') cancelDraw();
        if (ev.key === 'Enter' && S.draw.pts.length >= 3) finishDraw();
    });
    window.addEventListener('beforeunload', ev => {
        saveSite();
        if (S.sites.some(st => st.fieldsDirty || st.trialDirty)) { ev.preventDefault(); ev.returnValue = ''; }
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
    $('#sat_start, #sat_end').on('change', () => { S.start = $('#sat_start').val(); S.end = $('#sat_end').val(); S.preset = null; renderControls(); });
    $('#sat_go').on('click', () => goStep(4));
    $('#sat_grid').on('click', '.sat-tile', function () { showBig(+$(this).data('i')); });
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
    try {
        const { locations } = await getJSON('locations');
        S.locations = locations;
        renderLocations();
    } catch (err) {
        $('#sat_locations').html(`<span class="text-danger sat-small">${esc(err.message)}</span>`);
    }
});
