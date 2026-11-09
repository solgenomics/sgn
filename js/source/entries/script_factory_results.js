/*
 * Script Factory - decision dashboard (/tools/script_factory/results/<run_id>)
 *
 * Shows every result of one Script Factory run on a single page to support
 * selection decisions: trial locations on a map, field layouts, trait
 * distributions and correlations, an interactive selection (rank by the
 * index or any trait, any selection intensity), performance and stability
 * across environments (Finlay-Wilkinson), environmental zones, outliers and
 * model details. A shortlist of candidate accessions follows the user across
 * all views and can be saved as an accession list.
 *
 * Charts are plain SVG; the map uses Leaflet.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

import '../legacy/leaflet.js';
import { openStoreDialog, storedNotice } from '../modules/script_factory_store.js';

const SVGNS = 'http://www.w3.org/2000/svg';
const ACCENT = '#2b7a4b';
const ZONE_COLORS = ['#2b7a4b', '#2563eb', '#d97706', '#9333ea', '#dc2626', '#0891b2', '#65a30d', '#db2777', '#4b5563', '#b45309'];
const CAT_COLORS = ['#2563eb', '#d97706', '#9333ea', '#0891b2', '#dc2626', '#65a30d', '#db2777', '#4b5563', '#b45309', '#2b7a4b', '#7c3aed', '#0d9488'];
const SEQ = ['#440154', '#3b528b', '#21918c', '#5ec962', '#fde725'];                      // viridis
const DIV_GOOD = ['#b45309', '#f59e0b', '#fde68a', '#f7f7f7', '#bbf7d0', '#22c55e', '#166534']; // poor -> good
const DIV_RESID = ['#2166ac', '#67a9cf', '#d1e5f0', '#f7f7f7', '#fddbc7', '#ef8a62', '#b2182b'];

let $;
let cfg = {};
let R = null;        // results of the run
let META = {};
let LOCS = {};       // location name -> {latitude, longitude}
const D = {};        // derived data
const S = {          // view state
    trait: null,
    shortlist: [],
    rankBy: 'index',
    rankDir: 'increase',
    selPct: 10,
    mapColor: 'mean',
    zoneTarget: null,
    mapAccession: '',
    fieldTrial: null,
    fieldLayer: 'value',
    scatterX: null,
    scatterY: null
};
let map = null;
let mapLayer = null;

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function esc(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function arr(x) { return Array.isArray(x) ? x : (x === null || x === undefined ? [] : [x]); }
function num(x) { return x === null || x === undefined || x === '' || !isFinite(Number(x)) ? null : Number(x); }
function fmt(x, d) {
    const v = num(x);
    if (v === null) return '&ndash;';
    if (d !== undefined) return v.toFixed(d);
    const a = Math.abs(v);
    return a !== 0 && (a < 0.01 || a >= 1e5) ? v.toExponential(2) : v.toFixed(a < 1 ? 3 : a < 100 ? 2 : 1);
}
function mean(a) { const v = a.filter(x => x !== null && isFinite(x)); return v.length ? v.reduce((s, x) => s + x, 0) / v.length : null; }
function sd(a) {
    const v = a.filter(x => x !== null && isFinite(x));
    if (v.length < 2) return null;
    const m = mean(v);
    return Math.sqrt(v.reduce((s, x) => s + (x - m) * (x - m), 0) / (v.length - 1));
}
function cor(x, y) {
    const p = [];
    for (let i = 0; i < x.length; i++) if (x[i] !== null && y[i] !== null) p.push([x[i], y[i]]);
    if (p.length < 3) return null;
    const mx = mean(p.map(q => q[0])), my = mean(p.map(q => q[1]));
    let sxy = 0, sxx = 0, syy = 0;
    p.forEach(q => { sxy += (q[0] - mx) * (q[1] - my); sxx += (q[0] - mx) ** 2; syy += (q[1] - my) ** 2; });
    return sxx > 0 && syy > 0 ? sxy / Math.sqrt(sxx * syy) : null;
}
function niceTicks(min, max, n) {
    if (!isFinite(min) || !isFinite(max)) return [];
    if (min === max) { min -= 1; max += 1; }
    const step0 = (max - min) / (n || 5);
    const mag = Math.pow(10, Math.floor(Math.log10(step0)));
    const err = step0 / mag;
    const step = (err >= 7.5 ? 10 : err >= 3.5 ? 5 : err >= 1.5 ? 2 : 1) * mag;
    const out = [];
    for (let v = Math.ceil(min / step) * step; v <= max + step * 1e-9; v += step) out.push(Math.abs(v) < step * 1e-9 ? 0 : v);
    return out;
}
function tickLabel(v) { const a = Math.abs(v); return a >= 1e5 || (a > 0 && a < 1e-3) ? v.toExponential(1) : String(Math.round(v * 1000) / 1000); }

function hexToRgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
function interp(stops, t) {
    if (t === null || !isFinite(t)) return '#e5e7eb';
    t = Math.max(0, Math.min(1, t));
    const p = t * (stops.length - 1), i = Math.min(stops.length - 2, Math.floor(p)), f = p - i;
    const a = hexToRgb(stops[i]), b = hexToRgb(stops[i + 1]);
    return 'rgb(' + a.map((x, k) => Math.round(x + (b[k] - x) * f)).join(',') + ')';
}
function seqColor(v, lo, hi) { return v === null ? '#e5e7eb' : interp(SEQ, hi > lo ? (v - lo) / (hi - lo) : 0.5); }
function divColor(v, lim, stops) { return v === null ? '#e5e7eb' : interp(stops || DIV_GOOD, lim > 0 ? 0.5 + 0.5 * v / lim : 0.5); }
function textOn(rgb) {
    const m = /^#/.test(String(rgb)) ? hexToRgb(String(rgb)) : String(rgb).match(/\d+/g);
    if (!m) return '#111';
    return (0.299 * m[0] + 0.587 * m[1] + 0.114 * m[2]) > 150 ? '#111' : '#fff';
}

function svg(parent, w, h) {
    const s = document.createElementNS(SVGNS, 'svg');
    s.setAttribute('width', w); s.setAttribute('height', h);
    s.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
    s.setAttribute('font-family', 'Helvetica, Arial, sans-serif'); s.setAttribute('font-size', 11);
    parent.appendChild(s);
    return s;
}
function el(name, attrs, parent, text) {
    const e = document.createElementNS(SVGNS, name);
    Object.keys(attrs || {}).forEach(k => { if (attrs[k] !== undefined && attrs[k] !== null) e.setAttribute(k, attrs[k]); });
    if (text !== undefined) e.textContent = text;
    if (parent) parent.appendChild(e);
    return e;
}
function box(id) { const b = document.getElementById(id); if (b) b.innerHTML = ''; return b; }

function h2Badge(v) {
    const x = num(v);
    if (x === null) return '&ndash;';
    return '<span class="sfd-h2" style="background:' + h2Color(x) + '">' + x.toFixed(2) + '</span>';
}
function h2Color(x) { return x >= 0.6 ? '#2b7a4b' : x >= 0.3 ? '#d97706' : '#dc2626'; }

function accLink(a) {
    const on = isShort(a);
    return '<span class="sfd-acc' + (on ? ' on' : '') + '" data-acc="' + esc(a) + '" title="Click to ' + (on ? 'remove from' : 'add to') + ' the shortlist">' +
        (on ? '<span class="glyphicon glyphicon-star"></span> ' : '') + esc(a) + '</span>' +
        ' <a href="/stock/' + encodeURIComponent(a) + '/view" target="_blank" title="Accession page" class="sfd-help"><span class="glyphicon glyphicon-new-window" style="font-size:9px"></span></a>';
}

function dataTable(sel, opts) {
    if (!$.fn.DataTable) return;
    if ($.fn.DataTable.isDataTable(sel)) $(sel).DataTable().destroy();
    $(sel).DataTable(Object.assign({ pageLength: 15, lengthMenu: [10, 15, 25, 50, 100], autoWidth: false }, opts || {}));
}

function table(rows, cols, opts) {
    opts = opts || {};
    rows = arr(rows);
    if (!rows.length) return '<p class="sfd-help">' + (opts.empty || 'Nothing to show.') + '</p>';
    let h = '<div class="table-responsive"><table class="table table-condensed table-hover"' + (opts.id ? ' id="' + opts.id + '"' : '') + ' style="width:100%"><thead><tr>' +
        cols.map(c => '<th' + (c.title ? ' title="' + esc(c.title) + '"' : '') + '>' + c.l + '</th>').join('') + '</tr></thead><tbody>';
    rows.forEach(r => {
        h += '<tr' + (opts.rowAttr ? ' ' + opts.rowAttr(r) : '') + '>' + cols.map(c => {
            const v = r[c.k];
            return '<td' + (c.order ? ' data-order="' + esc(c.order(v, r)) + '"' : '') + '>' + (c.f ? c.f(v, r) : typeof v === 'number' ? fmt(v) : esc(v)) + '</td>';
        }).join('') + '</tr>';
    });
    return h + '</tbody></table></div>';
}

// tooltip on any element with data-tip
function initTooltip() {
    const tip = $('#sfd_tooltip');
    $(document).on('mousemove', '[data-tip]', function(e) {
        tip.html($(this).attr('data-tip')).show();
        const w = tip.outerWidth(), h = tip.outerHeight();
        let x = e.clientX + 14, y = e.clientY + 14;
        if (x + w > window.innerWidth - 8) x = e.clientX - w - 14;
        if (y + h > window.innerHeight - 8) y = e.clientY - h - 14;
        tip.css({ left: x, top: y });
    });
    $(document).on('mouseleave', '[data-tip]', () => tip.hide());
}

// axes for a plot area; returns scale functions
function axes(s, o) {
    // o: {x0, x1, y0, y1, xmin, xmax, ymin, ymax, xlabel, ylabel, xticks, yticks, grid}
    const xs = v => o.x0 + (o.x1 - o.x0) * (v - o.xmin) / ((o.xmax - o.xmin) || 1);
    const ys = v => o.y1 - (o.y1 - o.y0) * (v - o.ymin) / ((o.ymax - o.ymin) || 1);
    const g = el('g', {}, s);
    if (o.yticks !== false) niceTicks(o.ymin, o.ymax, o.yticks || 5).forEach(t => {
        if (t < o.ymin || t > o.ymax) return;
        el('line', { x1: o.x0, x2: o.x1, y1: ys(t), y2: ys(t), stroke: '#eef0f3' }, g);
        el('text', { x: o.x0 - 6, y: ys(t) + 4, 'text-anchor': 'end', fill: '#6b7280' }, g, tickLabel(t));
    });
    if (o.xticks !== false) niceTicks(o.xmin, o.xmax, o.xticks || 6).forEach(t => {
        if (t < o.xmin || t > o.xmax) return;
        if (o.grid) el('line', { x1: xs(t), x2: xs(t), y1: o.y0, y2: o.y1, stroke: '#eef0f3' }, g);
        el('line', { x1: xs(t), x2: xs(t), y1: o.y1, y2: o.y1 + 4, stroke: '#9ca3af' }, g);
        el('text', { x: xs(t), y: o.y1 + 16, 'text-anchor': 'middle', fill: '#6b7280' }, g, tickLabel(t));
    });
    el('line', { x1: o.x0, x2: o.x1, y1: o.y1, y2: o.y1, stroke: '#9ca3af' }, g);
    el('line', { x1: o.x0, x2: o.x0, y1: o.y0, y2: o.y1, stroke: '#9ca3af' }, g);
    if (o.xlabel) el('text', { x: (o.x0 + o.x1) / 2, y: o.y1 + 32, 'text-anchor': 'middle', fill: '#374151', 'font-weight': 600 }, g, o.xlabel);
    if (o.ylabel) el('text', { x: 0, y: 0, transform: 'translate(' + (o.x0 - 42) + ',' + ((o.y0 + o.y1) / 2) + ') rotate(-90)', 'text-anchor': 'middle', fill: '#374151', 'font-weight': 600 }, g, o.ylabel);
    return { xs: xs, ys: ys };
}

function legendBar(stops, lo, hi, label) {
    return '<div><b>' + esc(label) + '</b></div><div class="bar" style="background:linear-gradient(90deg,' + stops.join(',') + ')"></div>' +
        '<div style="display:flex;justify-content:space-between"><span>' + lo + '</span><span>' + hi + '</span></div>';
}

// ---------------------------------------------------------------------------
// shortlist
// ---------------------------------------------------------------------------

function storeKey() { return 'sfd_shortlist_' + cfg.run_id; }
function saveShort() { try { window.localStorage.setItem(storeKey(), JSON.stringify(S.shortlist)); } catch (e) { /* storage unavailable */ } }
function loadShort() {
    try {
        const v = JSON.parse(window.localStorage.getItem(storeKey()) || 'null');
        if (Array.isArray(v)) return v.filter(a => D.accSet[a]);
    } catch (e) { /* storage unavailable */ }
    return null;
}
function isShort(a) { return S.shortlist.indexOf(a) >= 0; }
function toggleShort(a) {
    if (!D.accSet[a]) return;
    const i = S.shortlist.indexOf(a);
    if (i >= 0) S.shortlist.splice(i, 1); else S.shortlist.push(a);
    saveShort();
    renderShortDependent();
}
function defaultShortlist() { return rankRows().filter(r => r.selected).map(r => r.accession); }

function renderShortlist() {
    $('#sfd_short_n').text(S.shortlist.length);
    const rk = {};
    rankRows().forEach(r => { rk[r.accession] = r.rank; });
    $('#sfd_short_list').html(S.shortlist.length ? S.shortlist.map(a =>
        '<li><span><span class="rk">' + (rk[a] ? '#' + rk[a] : '') + '</span>' + esc(a) + '</span><button class="x" data-acc="' + esc(a) + '" title="Remove">&times;</button></li>').join('') :
        '<li class="sfd-help">No accession yet.</li>');
}

function renderShortDependent() {
    safely('shortlist', renderShortlist);
    safely('ranking', renderRankTable);
    safely('top accessions', renderRankChart);
    safely('distribution', renderDistributions);
    safely('scatter plot', renderScatter);
    safely('reaction norm', renderReaction);
    safely('stability', renderStability);
    if ($('#sfd_gxe_rows').val() === 'shortlist') safely('accession x environment', renderGxeHeat);
    safely('field layout', renderField);
    $('.sfd-acc').each(function() {
        const a = $(this).attr('data-acc');
        const on = isShort(a);
        $(this).toggleClass('on', on).attr('title', 'Click to ' + (on ? 'remove from' : 'add to') + ' the shortlist')
            .html((on ? '<span class="glyphicon glyphicon-star"></span> ' : '') + esc(a));
    });
}

function shortlistCSV() {
    const traits = D.traits;
    const rk = {};
    rankRows().forEach(r => { rk[r.accession] = r; });
    const lines = [['accession', 'rank', 'score'].concat(traits.map(t => t + ' (' + D.label + ')')).join(',')];
    S.shortlist.forEach(a => {
        const r = rk[a] || {};
        lines.push(['"' + a.replace(/"/g, '""') + '"', r.rank || '', r.score !== undefined ? r.score : ''].concat(traits.map(t => { const v = D.gv[a] ? D.gv[a][t] : null; return v === null || v === undefined ? '' : v; })).join(','));
    });
    const blob = new Blob([lines.join('\n') + '\n'], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'shortlist_' + (META.script_name || 'script_factory').replace(/[^A-Za-z0-9_-]+/g, '_') + '.csv';
    document.body.appendChild(a); a.click(); a.remove();
}

function saveShortList() {
    if (!S.shortlist.length) { alert('The shortlist is empty.'); return; }
    if (typeof CXGN === 'undefined' || !CXGN.List) { alert('The list tools are not available on this page.'); return; }
    const name = prompt('Name of the new accession list:', 'Shortlist ' + (META.dataset_name || META.script_name || '') + ' ' + new Date().toISOString().slice(0, 10));
    if (!name) return;
    const lo = new CXGN.List();
    const id = lo.newList(name.trim(), 'Shortlisted with the Script Factory decision dashboard');
    if (!id) return;   // newList already alerts when the name exists
    lo.addBulk(id, S.shortlist);
    lo.setListType(id, 'accessions');
    alert('List "' + name + '" created with ' + S.shortlist.length + ' accessions.');
}

// ---------------------------------------------------------------------------
// data preparation
// ---------------------------------------------------------------------------

function prepare() {
    const s = R.summary || {};
    D.traits = arr(s.traits);
    D.label = R.value_label || 'BLUP';
    D.random = R.genotype_effect !== 'fixed';

    // genotype values
    D.gv = {};
    D.accessions = [];
    arr(R.genotype_values).forEach(r => {
        D.gv[r.accession] = {};
        D.traits.forEach(t => { D.gv[r.accession][t] = num(r[t]); });
        D.accessions.push(r.accession);
    });
    D.accSet = {};
    D.accessions.forEach(a => { D.accSet[a] = true; });

    // model summary per trait
    D.s2 = {};
    arr(R.stage2).forEach(r => { D.s2[r.trait] = r; });

    // direction of each trait (from the index settings of the script)
    D.dir = {};
    const it = ((R.recipe || {}).index || {}).traits || {};
    Object.keys(it).forEach(k => { D.dir[k.replace(/\|.*$/, '')] = it[k].direction || 'increase'; });

    // trials, locations, environments
    D.trials = arr(R.trials);
    D.trialInfo = {};
    D.trials.forEach(t => { D.trialInfo[t.trial] = t; });
    D.locations = {};
    D.trials.forEach(t => {
        const L0 = D.locations[t.location] || (D.locations[t.location] = { name: t.location, trials: [], n_plots: 0, coords: LOCS[t.location] || null });
        L0.trials.push(t);
        L0.n_plots += Number(t.n_plots) || 0;
    });

    // per environment values (stage 1 means or cell means)
    D.s1 = {};       // trait -> [{accession, value, trial, env}]
    arr(R.stage1_means).forEach(r => {
        (D.s1[r.trait] = D.s1[r.trait] || []).push({ accession: r.accession, value: num(r.value), trial: r.trial, env: r.env });
    });

    // plots
    D.plots = arr(R.plots);
    D.plotsByTrial = {};
    D.plots.forEach(p => { (D.plotsByTrial[p.trial] = D.plotsByTrial[p.trial] || []).push(p); });

    // outliers
    D.outlierSet = {};
    arr(R.outliers).forEach(o => { D.outlierSet[o.unit + '|' + o.trait] = o; });

    // stage 1 summaries
    D.stage1 = {};
    arr(R.stage1).forEach(r => { D.stage1[r.trial + '|' + r.trait] = r; });

    // zones
    D.zones = arr(R.zones);
}

function traitDir(t) { return D.dir[t] || 'increase'; }

// ---------------------------------------------------------------------------
// ranking
// ---------------------------------------------------------------------------

let rankCache = null;
function rankRows() {
    if (rankCache) return rankCache;
    let rows;
    if (S.rankBy === 'index' && R.index) {
        rows = arr(R.index.table).map(r => ({ accession: r.accession, score: num(r.index) }));
    } else {
        const t = S.rankBy;
        const sign = S.rankDir === 'decrease' ? -1 : 1;
        rows = D.accessions.map(a => ({ accession: a, score: D.gv[a][t], key: D.gv[a][t] === null ? null : sign * D.gv[a][t] }));
    }
    rows = rows.filter(r => r.score !== null);
    rows.sort((a, b) => (b.key !== undefined ? b.key - a.key : b.score - a.score));
    const n = Math.max(1, Math.round(rows.length * S.selPct / 100));
    rows.forEach((r, i) => { r.rank = i + 1; r.selected = i < n; });
    rankCache = rows;
    return rows;
}
function invalidateRank() { rankCache = null; }

// ---------------------------------------------------------------------------
// header and overview
// ---------------------------------------------------------------------------

function renderHeader() {
    const rc = R.recipe || {};
    const name = META.script_name || rc.name || 'Script Factory analysis';
    $('#sfd_title').text(name);
    document.title = name + ' - Decision dashboard';
    const chips = [];
    if (META.dataset_name) chips.push('Dataset: ' + (META.dataset_id ? '<a style="color:#fff;text-decoration:underline" href="/dataset/' + encodeURIComponent(META.dataset_id) + '">' + esc(META.dataset_name) + '</a>' : esc(META.dataset_name)));
    chips.push(R.strategy === 'two_stage' ? 'Two-stage analysis' : 'Single-stage analysis' + (((rc.single || {}).mode) === 'custom' ? ' (custom formula)' : ''));
    chips.push(esc(D.label) + 's (genotype ' + esc(R.genotype_effect) + ')');
    if (META.created) chips.push('Run ' + esc(String(META.created).replace('T', ' ').slice(0, 16)));
    $('#sfd_subtitle').html(chips.map(c => '<span class="chip">' + c + '</span>').join(''));

    const dl = { genotype_values: 'Genotype values (' + D.label + 's)', stage1_means: 'Means per trial', outliers: 'Removed outliers', index: 'Selection index ranking', zones: 'Environmental zones' };
    const files = R.files || {};
    $('#sfd_downloads').html(Object.keys(files).map(k => '<li><a href="' + esc(files[k]) + '" download>' + esc(dl[k] || k) + ' (.csv)</a></li>').join('') || '<li class="disabled"><a>No files</a></li>');
}

function renderOverview() {
    const s = R.summary || {};
    const nObs = arr(R.outlier_summary).reduce((a, r) => a + (Number(r.n_observations) || 0), 0);
    const nOut = arr(R.outliers).length;
    const h2s = D.traits.map(t => num((D.s2[t] || {}).h2)).filter(x => x !== null);
    const stat = (v, l, title) => '<div class="sfd-stat"' + (title ? ' title="' + esc(title) + '"' : '') + '><div class="v">' + v + '</div><div class="l">' + l + '</div></div>';
    $('#sfd_stats').html(
        stat(s.n_trials, 'Trials') + stat(Object.keys(D.locations).length, 'Locations') + stat(s.n_environments, 'Environments (' + esc(String(s.environment_unit || 'trial').replace('_', ' &times; ')) + ')') +
        stat(s.n_accessions, 'Accessions') + stat(s.n_plots, 'Plots') +
        stat(nOut + (nObs ? ' <small style="font-size:13px;color:#6b7280">(' + (100 * nOut / nObs).toFixed(1) + '%)</small>' : ''), 'Values removed') +
        stat(h2s.length ? mean(h2s).toFixed(2) : '&ndash;', 'Mean heritability') +
        stat('<span id="sfd_stat_sel">' + rankRows().filter(r => r.selected).length + '</span>', 'Selected accessions'));

    const w = arr(R.warnings);
    $('#sfd_warnings').html(w.length ? '<div class="alert alert-warning"><a data-toggle="collapse" href="#sfd_warn_list"><b>' + w.length + ' note(s) from the analysis</b> <span class="caret"></span></a><ul id="sfd_warn_list" class="collapse" style="margin:6px 0 0">' + w.map(x => '<li>' + esc(x) + '</li>').join('') + '</ul></div>' : '');

    const outBy = {};
    arr(R.outlier_summary).forEach(r => { outBy[r.trait] = r; });
    const rows = D.traits.map(t => {
        const m = D.s2[t] || {};
        const vals = D.accessions.map(a => D.gv[a][t]).filter(x => x !== null);
        return { trait: t, mean: num(m.mean), gmin: Math.min.apply(null, vals), gmax: Math.max.apply(null, vals), var_g: num(m.var_g), var_ge: num(m.var_ge), var_e: num(m.var_e), h2: num(m.h2), pct: num((outBy[t] || {}).pct_removed), message: m.message, dropped: m.dropped_terms };
    });
    const verdict = h => h === null ? '<span class="sfd-help">no heritability (genotype fixed)</span>' :
        h >= 0.6 ? '<span style="color:#2b7a4b">reliable for selection</span>' :
            h >= 0.3 ? '<span style="color:#b45309">moderate: weigh with care</span>' : '<span style="color:#dc2626">low: selection is risky</span>';
    $('#sfd_trait_summary').html(table(rows, [
        { k: 'trait', l: 'Trait', f: (v) => '<a href="#" class="sfd-set-trait" data-trait="' + esc(v) + '">' + esc(v) + '</a>' + (traitDir(v) === 'decrease' ? ' <span class="sfd-help" title="lower is better">&darr;</span>' : '') },
        { k: 'mean', l: 'Mean' },
        { k: 'gmin', l: D.label + ' range', f: (v, r) => fmt(r.gmin) + ' &ndash; ' + fmt(r.gmax) },
        { k: 'var_g', l: '&sigma;&sup2;<sub>G</sub>' },
        { k: 'var_ge', l: R.strategy === 'two_stage' ? '&sigma;&sup2;<sub>GE+e</sub>' : '&sigma;&sup2;<sub>GE</sub>' },
        { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) },
        { k: 'pct', l: 'Removed', f: v => v === null ? '&ndash;' : fmt(v, 1) + '%' },
        { k: 'h2', l: 'Verdict', f: (v, r) => (r.message && r.message !== 'OK' ? '<small style="color:#dc2626">' + esc(r.message) + '</small>' : verdict(v)) }
    ]));
    renderVarComp();
}

function prettyComp(c) {
    return { tr_rep: 'trial:rep', tr_block: 'trial:rep:block', tr_row: 'trial:row', tr_col: 'trial:col', Residual: 'residual', accession: 'genotype' }[c] || c;
}
function compColor(c, i) {
    if (c === 'accession') return ACCENT;
    if (c === 'Residual') return '#9ca3af';
    if (/accession/.test(c)) return ['#d97706', '#f59e0b', '#b45309', '#fbbf24'][i % 4];
    return ['#2563eb', '#60a5fa', '#1e40af', '#93c5fd', '#0891b2', '#67e8f9'][i % 6];
}

function renderVarComp() {
    const b = box('sfd_varcomp');
    const vc = arr(R.variance_components);
    if (!vc.length) { b.innerHTML = '<p class="sfd-help">No variance components (genotype fitted as a fixed effect without other random terms).</p>'; return; }
    const traits = D.traits.filter(t => vc.some(r => r.trait === t));
    const comps = [];
    vc.forEach(r => { if (comps.indexOf(r.component) < 0) comps.push(r.component); });
    // genotype first, residual last
    comps.sort((a, c) => (a === 'accession' ? -1 : c === 'accession' ? 1 : a === 'Residual' ? 1 : c === 'Residual' ? -1 : 0));
    const colors = {};
    let gi = 0, oi = 0;
    comps.forEach(c => { colors[c] = compColor(c, /accession/.test(c) && c !== 'accession' ? gi++ : oi++); });
    const W = 820, M = { l: 190, r: 20, t: 8 }, bh = 26, H = M.t + traits.length * bh + 6;
    const s = svg(b, W, H);
    const xs = f => M.l + (W - M.l - M.r) * f;
    traits.forEach((t, i) => {
        const rows = vc.filter(r => r.trait === t && num(r.variance) !== null && r.variance > 0);
        const tot = rows.reduce((a, r) => a + Number(r.variance), 0);
        const y = M.t + i * bh;
        el('text', { x: M.l - 8, y: y + bh / 2 + 4, 'text-anchor': 'end', fill: '#111' }, s, t.length > 28 ? t.slice(0, 27) + '…' : t);
        let acc = 0;
        comps.forEach(c => {
            const r = rows.find(x => x.component === c);
            if (!r || !tot) return;
            const f = r.variance / tot;
            el('rect', { x: xs(acc), y: y + 4, width: Math.max(0.5, xs(acc + f) - xs(acc)), height: bh - 8, fill: colors[c],
                'data-tip': '<b>' + esc(t) + '</b><br/>' + esc(prettyComp(c)) + ': ' + fmt(r.variance) + ' (' + (100 * f).toFixed(1) + '%)' }, s);
            if (f > 0.07) el('text', { x: xs(acc + f / 2), y: y + bh / 2 + 4, 'text-anchor': 'middle', fill: '#fff', 'font-size': 10, 'pointer-events': 'none' }, s, Math.round(100 * f) + '%');
            acc += f;
        });
    });
    const lg = document.createElement('div');
    lg.className = 'sfd-help';
    lg.style.paddingLeft = M.l + 'px';
    lg.innerHTML = comps.map(c => '<span style="display:inline-block;margin-right:12px"><span style="display:inline-block;width:10px;height:10px;border-radius:2px;background:' + colors[c] + ';margin-right:4px"></span>' + esc(prettyComp(c)) + '</span>').join('');
    b.appendChild(lg);
}

// ---------------------------------------------------------------------------
// map
// ---------------------------------------------------------------------------

function locationValues() {
    const t = S.trait;
    const out = {};
    Object.keys(D.locations).forEach(name => {
        const L0 = D.locations[name];
        const trialNames = L0.trials.map(x => x.trial);
        const vals = [];
        trialNames.forEach(tr => arr(D.plotsByTrial[tr]).forEach(p => { const v = num(p[t]); if (v !== null) vals.push(v); }));
        const h2 = mean(trialNames.map(tr => num((D.stage1[tr + '|' + t] || {}).h2)));
        // accession deviation from the mean of the trial, averaged over the trials of the location
        let accDev = null;
        const top = [];
        const s1 = arr(D.s1[t]).filter(r => trialNames.indexOf(r.trial) >= 0 && r.value !== null);
        if (s1.length) {
            const byTrial = {};
            s1.forEach(r => { (byTrial[r.trial] = byTrial[r.trial] || []).push(r); });
            const devs = {};
            Object.keys(byTrial).forEach(tr => {
                const m = mean(byTrial[tr].map(r => r.value));
                byTrial[tr].forEach(r => { (devs[r.accession] = devs[r.accession] || []).push(r.value - m); });
            });
            if (S.mapAccession && devs[S.mapAccession]) accDev = mean(devs[S.mapAccession]);
            const sign = traitDir(t) === 'decrease' ? -1 : 1;
            Object.keys(devs).map(a => ({ a: a, v: mean(devs[a]) })).sort((x, y) => sign * (y.v - x.v)).slice(0, 5).forEach(x => top.push(x));
        }
        out[name] = { mean: mean(vals), n: vals.length, cv: vals.length > 1 ? 100 * sd(vals) / Math.abs(mean(vals)) : null, h2: h2, accDev: accDev, top: top, zones: zonesOfLocation(name) };
    });
    return out;
}

function zonesOfLocation(name) {
    const z = D.zones.find(x => x.target === S.zoneTarget) || D.zones[0];
    if (!z) return [];
    const zs = {};
    arr(z.membership).forEach(m => {
        const locs = String(m.location || '').split(/,\s*/);
        if (locs.indexOf(name) >= 0 || m.env === name) zs[m.zone] = (zs[m.zone] || 0) + 1;
    });
    return Object.keys(zs).sort((a, b) => zs[b] - zs[a]);
}
function zoneColor(z) {
    const zt = D.zones.find(x => x.target === S.zoneTarget) || D.zones[0];
    const names = [];
    arr(zt && zt.membership).forEach(m => { if (names.indexOf(m.zone) < 0) names.push(m.zone); });
    names.sort((a, b) => Number(a.replace(/\D/g, '')) - Number(b.replace(/\D/g, '')));
    return ZONE_COLORS[Math.max(0, names.indexOf(z)) % ZONE_COLORS.length];
}

function renderMap() {
    $('#sfd_map_zone_target').toggle(S.mapColor === 'zone');
    $('#sfd_map_accession').toggle(S.mapColor === 'accession');
    const vals = locationValues();
    const names = Object.keys(D.locations);
    const mapped = names.filter(n => D.locations[n].coords);
    const t = S.trait;

    // colour of each location
    let colorOf, legend = '';
    if (S.mapColor === 'zone') {
        if (!D.zones.length) { colorOf = () => '#9ca3af'; legend = '<span class="sfd-help">No zones in this analysis</span>'; }
        else {
            colorOf = n => vals[n].zones.length ? zoneColor(vals[n].zones[0]) : '#9ca3af';
            const zt = D.zones.find(x => x.target === S.zoneTarget) || D.zones[0];
            const zn = [];
            arr(zt.membership).forEach(m => { if (zn.indexOf(m.zone) < 0) zn.push(m.zone); });
            legend = '<b>' + esc(zt.target) + '</b><br/>' + zn.map(z => '<div><span class="sw" style="background:' + zoneColor(z) + '"></span>' + esc(z) + '</div>').join('');
        }
    } else if (S.mapColor === 'accession') {
        const v = names.map(n => vals[n].accDev).filter(x => x !== null);
        const lim = v.length ? Math.max.apply(null, v.map(Math.abs)) : 1;
        const sign = traitDir(t) === 'decrease' ? -1 : 1;
        colorOf = n => vals[n].accDev === null ? '#d1d5db' : divColor(sign * vals[n].accDev, lim);
        legend = S.mapAccession ? legendBar(DIV_GOOD, 'worse', 'better', S.mapAccession + ' vs trial mean') + '<div class="sfd-help">grey: not tested</div>' : '<span class="sfd-help">Type an accession name</span>';
    } else {
        const key = S.mapColor === 'h2' ? 'h2' : 'mean';
        const v = names.map(n => vals[n][key]).filter(x => x !== null);
        const lo = key === 'h2' ? 0 : Math.min.apply(null, v), hi = key === 'h2' ? 1 : Math.max.apply(null, v);
        colorOf = n => vals[n][key] === null ? '#d1d5db' : seqColor(vals[n][key], lo, hi);
        legend = v.length ? legendBar(SEQ, fmt(lo), fmt(hi), key === 'h2' ? 'Heritability of ' + t : 'Mean of ' + t) : '<span class="sfd-help">' + (key === 'h2' ? 'Trial heritabilities exist only for two-stage analyses' : 'No values') + '</span>';
    }
    $('#sfd_map_legend').html(legend);

    // popups
    const popup = n => {
        const L0 = D.locations[n], v = vals[n];
        let h = '<b style="font-size:14px">' + esc(n) + '</b><table>' +
            L0.trials.map(x => '<tr><td>' + esc(x.trial) + '</td><td class="sfd-help">' + esc(x.year) + ' &middot; ' + esc(x.design) + ' &middot; ' + esc(x.n_plots) + ' plots</td></tr>').join('') + '</table>' +
            '<div style="margin-top:4px">' + esc(t) + ': mean <b>' + fmt(v.mean) + '</b>' + (v.cv !== null ? ', CV ' + fmt(v.cv, 1) + '%' : '') + (v.h2 !== null ? ', H&sup2; ' + h2Badge(v.h2) : '') + '</div>';
        if (v.zones.length) h += '<div>Zone: ' + v.zones.map(z => '<span class="sfd-zone-chip" style="background:' + zoneColor(z) + '">' + esc(z) + '</span>').join(' ') + '</div>';
        if (S.mapAccession && S.mapColor === 'accession') h += '<div>' + esc(S.mapAccession) + ': ' + (v.accDev === null ? 'not tested here' : (v.accDev >= 0 ? '+' : '') + fmt(v.accDev) + ' vs trial mean') + '</div>';
        if (v.top.length) h += '<div style="margin-top:4px"><b>Best here</b> (vs trial mean):<ol style="padding-left:18px;margin:2px 0">' + v.top.map(x => '<li>' + accLink(x.a) + ' <span class="sfd-help">' + (x.v >= 0 ? '+' : '') + fmt(x.v) + '</span></li>').join('') + '</ol></div>';
        return h;
    };

    if (!map) {
        map = L.map('sfd_map', { scrollWheelZoom: false }).setView([0, 0], 2);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 18, attribution: '&copy; OpenStreetMap contributors' }).addTo(map);
        mapLayer = L.layerGroup().addTo(map);
        // Leaflet may keep clicks inside popups from reaching the document
        map.on('popupopen', ev => {
            $(ev.popup.getElement()).find('[data-acc]').on('click', function(e) {
                e.stopPropagation();
                toggleShort($(this).attr('data-acc'));
            });
        });
    }
    mapLayer.clearLayers();
    const bounds = [];
    const maxPlots = Math.max.apply(null, names.map(n => D.locations[n].n_plots).concat([1]));
    mapped.forEach(n => {
        const c = D.locations[n].coords;
        const ll = [Number(c.latitude), Number(c.longitude)];
        bounds.push(ll);
        L.circleMarker(ll, { radius: 7 + 11 * Math.sqrt(D.locations[n].n_plots / maxPlots), color: '#fff', weight: 2, fillColor: colorOf(n), fillOpacity: 0.92 })
            .bindPopup(popup(n), { maxWidth: 340 }).bindTooltip(esc(n)).addTo(mapLayer);
    });
    if (!map._sfdFitted && bounds.length) {
        if (bounds.length === 1) map.setView(bounds[0], 8); else map.fitBounds(bounds, { padding: [30, 30], maxZoom: 10 });
        map._sfdFitted = true;
    }
    setTimeout(() => map.invalidateSize(), 50);
    const missing = names.filter(n => !D.locations[n].coords);
    $('#sfd_map_note').html(!mapped.length ? '<div class="alert alert-info" style="margin:8px 0 0">None of the locations has coordinates. Add latitude and longitude in <a href="/breeders/locations" target="_blank">Manage locations</a> to see them on the map.</div>' :
        missing.length ? 'Not on the map (no coordinates): ' + missing.map(esc).join(', ') + '. <a href="/breeders/locations" target="_blank">Add coordinates</a>.' : '');

    // table of all locations
    const rows = names.map(n => ({ location: n, trials: D.locations[n].trials.length, plots: D.locations[n].n_plots, mean: vals[n].mean, cv: vals[n].cv, h2: vals[n].h2, zones: vals[n].zones, top: vals[n].top, color: colorOf(n) }));
    $('#sfd_location_table').html(table(rows, [
        { k: 'location', l: 'Location', f: (v, r) => '<span class="sfd-legend-dot" style="display:inline-block;width:10px;height:10px;border-radius:50%;background:' + r.color + ';margin-right:6px"></span>' + esc(v) },
        { k: 'trials', l: 'Trials', f: v => v }, { k: 'plots', l: 'Plots', f: v => v },
        { k: 'mean', l: 'Mean ' + esc(t) }, { k: 'cv', l: 'CV %', f: v => fmt(v, 1) }, { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) },
        { k: 'zones', l: 'Zone', f: v => arr(v).map(z => '<span class="sfd-zone-chip" style="background:' + zoneColor(z) + '">' + esc(z) + '</span>').join(' ') },
        { k: 'top', l: 'Best accession here', f: v => v.length ? accLink(v[0].a) : '' }
    ]));
}

// ---------------------------------------------------------------------------
// field layout and trial quality
// ---------------------------------------------------------------------------

function renderField() {
    const b = box('sfd_field');
    const tr = S.fieldTrial;
    const plots = arr(D.plotsByTrial[tr]);
    const t = S.trait;
    if (!plots.length) { b.innerHTML = '<p class="sfd-help">No plots.</p>'; return; }
    const layer = S.fieldLayer;
    const key = layer === 'resid' ? 'resid:' + t : t;
    const withRC = plots.filter(p => num(p.row) !== null && num(p.col) !== null).length >= 0.8 * plots.length;

    let cells;
    if (withRC) {
        cells = plots.filter(p => num(p.row) !== null && num(p.col) !== null).map(p => ({ p: p, r: Number(p.row), c: Number(p.col) }));
    } else {
        // no coordinates: plots in replicate order on a grid
        const sorted = plots.slice().sort((a, c) => String(a.rep).localeCompare(String(c.rep), undefined, { numeric: true }) || String(a.unit).localeCompare(String(c.unit), undefined, { numeric: true }));
        const nc = Math.ceil(Math.sqrt(sorted.length * 2));
        cells = sorted.map((p, i) => ({ p: p, r: Math.floor(i / nc) + 1, c: (i % nc) + 1 }));
    }
    const rows = cells.map(x => x.r), cols = cells.map(x => x.c);
    const r0 = Math.min.apply(null, rows), r1 = Math.max.apply(null, rows), c0 = Math.min.apply(null, cols), c1 = Math.max.apply(null, cols);
    const nr = r1 - r0 + 1, nc = c1 - c0 + 1;
    const cs = Math.max(8, Math.min(34, Math.floor(860 / nc), Math.floor(560 / nr)));
    const M = { l: 34, t: 22, r: 10, b: 10 };
    const W = M.l + nc * cs + M.r, H = M.t + nr * cs + M.b;

    const vals = cells.map(x => num(x.p[key])).filter(v => v !== null);
    let color, legend;
    if (layer === 'rep') {
        const reps = [];
        cells.forEach(x => { const k = String(x.p.rep); if (reps.indexOf(k) < 0) reps.push(k); });
        color = x => CAT_COLORS[reps.indexOf(String(x.p.rep)) % CAT_COLORS.length];
        legend = 'Replicates: ' + reps.map(r => '<span class="sw" style="display:inline-block;width:10px;height:10px;background:' + CAT_COLORS[reps.indexOf(r) % CAT_COLORS.length] + ';margin:0 3px 0 8px"></span>' + esc(r)).join('');
    } else if (layer === 'shortlist') {
        color = x => isShort(x.p.accession) ? ACCENT : '#e5e7eb';
        legend = '<span style="display:inline-block;width:10px;height:10px;background:' + ACCENT + '"></span> shortlisted accession';
    } else if (layer === 'resid') {
        const lim = vals.length ? Math.max.apply(null, vals.map(Math.abs)) : 1;
        color = x => divColor(num(x.p[key]), lim, DIV_RESID);
        legend = vals.length ? 'Residual of ' + esc(t) + ': <span style="display:inline-block;width:120px;height:9px;border-radius:4px;vertical-align:middle;background:linear-gradient(90deg,' + DIV_RESID.join(',') + ')"></span> &minus;' + fmt(lim) + ' &hellip; +' + fmt(lim) :
            'No residuals for this trial and trait (e.g. an unreplicated trial).';
    } else {
        const lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals);
        color = x => seqColor(num(x.p[key]), lo, hi);
        legend = vals.length ? esc(t) + ': <span style="display:inline-block;width:120px;height:9px;border-radius:4px;vertical-align:middle;background:linear-gradient(90deg,' + SEQ.join(',') + ')"></span> ' + fmt(lo) + ' &hellip; ' + fmt(hi) : 'No values';
    }

    const head = document.createElement('div');
    head.className = 'sfd-help';
    head.style.marginBottom = '6px';
    head.innerHTML = (withRC ? nr + ' rows &times; ' + nc + ' columns, ' : '<b>No row/column coordinates</b>: plots drawn in replicate order. ') + plots.length + ' plots &middot; ' + legend;
    b.appendChild(head);
    const s = svg(b, W, H);
    for (let c = c0; c <= c1; c += Math.max(1, Math.ceil(nc / 20))) el('text', { x: M.l + (c - c0 + 0.5) * cs, y: 14, 'text-anchor': 'middle', fill: '#9ca3af', 'font-size': 10 }, s, withRC ? c : '');
    for (let r = r0; r <= r1; r += Math.max(1, Math.ceil(nr / 25))) el('text', { x: M.l - 6, y: M.t + (r - r0 + 0.5) * cs + 4, 'text-anchor': 'end', fill: '#9ca3af', 'font-size': 10 }, s, withRC ? r : '');
    cells.forEach(x => {
        const p = x.p;
        const X = M.l + (x.c - c0) * cs, Y = M.t + (x.r - r0) * cs;
        const out = D.outlierSet[p.unit + '|' + t];
        const tip = '<b>' + esc(p.unit) + '</b><br/>' + esc(p.accession) + (isShort(p.accession) ? ' &#9733;' : '') + '<br/>rep ' + esc(p.rep) + ', block ' + esc(p.block) +
            (withRC ? ', row ' + esc(p.row) + ', col ' + esc(p.col) : '') + '<br/>' + esc(t) + ': ' + (out ? '<s>' + fmt(out.value) + '</s> removed (' + esc(out.reason) + ')' : fmt(p[t])) +
            (num(p['resid:' + t]) !== null ? '<br/>residual: ' + fmt(p['resid:' + t]) : '');
        el('rect', { x: X + 0.5, y: Y + 0.5, width: cs - 1, height: cs - 1, fill: color(x), stroke: isShort(p.accession) && layer !== 'shortlist' ? '#111' : 'none', 'stroke-width': 2, 'data-tip': tip, 'data-acc': p.accession, style: 'cursor:pointer' }, s);
        if (out) {
            el('path', { d: 'M' + (X + 3) + ' ' + (Y + 3) + 'L' + (X + cs - 3) + ' ' + (Y + cs - 3) + 'M' + (X + cs - 3) + ' ' + (Y + 3) + 'L' + (X + 3) + ' ' + (Y + cs - 3), stroke: '#dc2626', 'stroke-width': 1.6, 'pointer-events': 'none' }, s);
        }
    });
}

function renderTrialQuality() {
    const b = box('sfd_trial_quality');
    const t = S.trait;
    const rows = D.trials.map(tr => {
        const s1 = D.stage1[tr.trial + '|' + t];
        const vals = arr(D.plotsByTrial[tr.trial]).map(p => num(p[t])).filter(v => v !== null);
        const cv = s1 && num(s1.cv) !== null ? num(s1.cv) : vals.length > 1 ? 100 * sd(vals) / Math.abs(mean(vals)) : null;
        return { trial: tr.trial, h2: s1 ? num(s1.h2) : null, cv: cv, n: vals.length, mean: vals.length ? mean(vals) : null, model: s1 ? s1.model : '', design: tr.design };
    }).filter(r => r.n > 0);
    if (!rows.length) { b.innerHTML = '<p class="sfd-help">No data for this trait.</p>'; return; }
    const hasH2 = rows.some(r => r.h2 !== null);
    const W = 820, bh = 22, M = { l: 200, t: 22, b: 30 }, half = hasH2 ? (W - M.l - 40) / 2 : W - M.l - 20;
    const H = M.t + rows.length * bh + M.b;
    const s = svg(b, W, H);
    const cvMax = Math.max.apply(null, rows.map(r => r.cv || 0).concat([10]));
    const x0h = M.l, x0c = hasH2 ? M.l + half + 40 : M.l;
    if (hasH2) el('text', { x: x0h, y: 12, fill: '#374151', 'font-weight': 600 }, s, 'Heritability (H²)');
    el('text', { x: x0c, y: 12, fill: '#374151', 'font-weight': 600 }, s, 'Coefficient of variation (%)' + (hasH2 ? '' : ' of the plot values'));
    rows.forEach((r, i) => {
        const y = M.t + i * bh;
        el('text', { x: M.l - 8, y: y + bh / 2 + 4, 'text-anchor': 'end', fill: '#111' }, s, r.trial.length > 30 ? r.trial.slice(0, 29) + '…' : r.trial);
        const tip = '<b>' + esc(r.trial) + '</b><br/>' + esc(r.design) + ', ' + r.n + ' values, mean ' + fmt(r.mean) + '<br/>H² ' + fmt(r.h2, 2) + ', CV ' + fmt(r.cv, 1) + '%' + (r.model ? '<br/><code>' + esc(r.model) + '</code>' : '');
        if (hasH2) {
            el('rect', { x: x0h, y: y + 4, width: half, height: bh - 8, fill: '#f3f4f6', rx: 3 }, s);
            if (r.h2 !== null) el('rect', { x: x0h, y: y + 4, width: Math.max(1, half * Math.max(0, Math.min(1, r.h2))), height: bh - 8, fill: h2Color(r.h2), rx: 3, 'data-tip': tip }, s);
            el('text', { x: x0h + half + 4, y: y + bh / 2 + 4, fill: '#6b7280', 'font-size': 10 }, s, r.h2 === null ? '–' : r.h2.toFixed(2));
        }
        const wc = half;
        if (r.cv !== null) el('rect', { x: x0c, y: y + 4, width: Math.max(1, wc * r.cv / cvMax), height: bh - 8, fill: r.cv > 30 ? '#dc2626' : r.cv > 20 ? '#d97706' : '#60a5fa', rx: 3, 'data-tip': tip }, s);
        el('text', { x: x0c + (r.cv !== null ? wc * r.cv / cvMax : 0) + 4, y: y + bh / 2 + 4, fill: '#6b7280', 'font-size': 10 }, s, r.cv === null ? '–' : r.cv.toFixed(1));
    });
    el('text', { x: M.l, y: H - 8, fill: '#9ca3af', 'font-size': 10 }, s, 'H² ≥ 0.6 green, 0.3–0.6 orange, < 0.3 red · CV > 20% orange, > 30% red');
}

// ---------------------------------------------------------------------------
// traits
// ---------------------------------------------------------------------------

function renderDistributions() {
    const b = box('sfd_distributions');
    $('#sfd_dist_help').html(D.label + 's of all accessions; <span style="color:' + ACCENT + '">&#9679;</span> shortlisted');
    D.traits.forEach(t => {
        const vals = D.accessions.map(a => D.gv[a][t]).filter(v => v !== null);
        if (!vals.length) return;
        const wrap = document.createElement('div');
        const m = D.s2[t] || {};
        wrap.innerHTML = '<h5>' + esc(t) + ' ' + (traitDir(t) === 'decrease' ? '<span class="sfd-help">&darr; lower is better</span> ' : '') + '<span style="float:right">' + h2Badge(m.h2) + '</span></h5>';
        b.appendChild(wrap);
        const W = 280, H = 140, M = { l: 30, r: 8, t: 6, b: 34 };
        const lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals);
        const nb = Math.min(20, Math.max(6, Math.round(Math.sqrt(vals.length))));
        const bw = (hi - lo) / nb || 1;
        const bins = new Array(nb).fill(0);
        vals.forEach(v => { bins[Math.min(nb - 1, Math.floor((v - lo) / bw))]++; });
        const s = svg(wrap, W, H);
        const ax = axes(s, { x0: M.l, x1: W - M.r, y0: M.t, y1: H - M.b, xmin: lo, xmax: hi === lo ? lo + 1 : hi, ymin: 0, ymax: Math.max.apply(null, bins), xticks: 4, yticks: 3 });
        bins.forEach((n, i) => {
            if (!n) return;
            el('rect', { x: ax.xs(lo + i * bw) + 0.5, y: ax.ys(n), width: Math.max(1, ax.xs(lo + (i + 1) * bw) - ax.xs(lo + i * bw) - 1), height: ax.ys(0) - ax.ys(n), fill: '#cbd5e1',
                'data-tip': n + ' accession(s) between ' + fmt(lo + i * bw) + ' and ' + fmt(lo + (i + 1) * bw) }, s);
        });
        const sv = S.shortlist.map(a => D.gv[a] ? D.gv[a][t] : null).filter(v => v !== null);
        S.shortlist.forEach(a => {
            const v = D.gv[a] ? D.gv[a][t] : null;
            if (v === null) return;
            el('circle', { cx: ax.xs(v), cy: H - M.b + 24, r: 3.5, fill: ACCENT, 'fill-opacity': 0.75, 'data-tip': '<b>' + esc(a) + '</b><br/>' + esc(t) + ': ' + fmt(v), 'data-acc': a, style: 'cursor:pointer' }, s);
        });
        const pm = mean(vals);
        el('line', { x1: ax.xs(pm), x2: ax.xs(pm), y1: M.t, y2: H - M.b, stroke: '#6b7280', 'stroke-dasharray': '3,3', 'data-tip': 'population mean ' + fmt(pm) }, s);
        if (sv.length) {
            const smn = mean(sv);
            el('line', { x1: ax.xs(smn), x2: ax.xs(smn), y1: M.t, y2: H - M.b, stroke: ACCENT, 'stroke-width': 2, 'data-tip': 'shortlist mean ' + fmt(smn) + ' (' + (smn - pm >= 0 ? '+' : '') + fmt(smn - pm) + ')' }, s);
        }
    });
}

function renderCorrelations() {
    const traits = D.traits;
    if (traits.length < 2) { $('#sfd_correlations').html('<p class="sfd-help">Only one trait.</p>'); return; }
    const col = t => D.accessions.map(a => D.gv[a][t]);
    let h = '<table class="sfd-heat"><thead><tr><th></th>' + traits.map(t => '<th title="' + esc(t) + '">' + esc(t.length > 10 ? t.slice(0, 9) + '…' : t) + '</th>').join('') + '</tr></thead><tbody>';
    traits.forEach(a => {
        h += '<tr><th class="r" title="' + esc(a) + '">' + esc(a.length > 22 ? a.slice(0, 21) + '…' : a) + '</th>';
        traits.forEach(c => {
            const r = a === c ? 1 : cor(col(a), col(c));
            const bg = r === null ? '#f3f4f6' : divColor(r, 1, ['#b45309', '#f59e0b', '#fde68a', '#f7f7f7', '#bfdbfe', '#3b82f6', '#1e3a8a']);
            h += '<td style="background:' + bg + ';color:' + textOn(bg) + ';cursor:pointer;min-width:42px" class="sfd-cor" data-x="' + esc(c) + '" data-y="' + esc(a) + '" data-tip="' + esc(esc(a) + ' vs ' + esc(c) + ': r = ' + (r === null ? 'n/a' : r.toFixed(2))) + '">' + (r === null ? '' : r.toFixed(2)) + '</td>';
        });
        h += '</tr>';
    });
    $('#sfd_correlations').html(h + '</tbody></table>');
}

function renderScatter() {
    const b = box('sfd_scatter');
    const tx = S.scatterX, ty = S.scatterY;
    if (!tx || !ty) return;
    const pts = D.accessions.map(a => ({ a: a, x: D.gv[a][tx], y: D.gv[a][ty] })).filter(p => p.x !== null && p.y !== null);
    if (!pts.length) { b.innerHTML = '<p class="sfd-help">No accession has both values.</p>'; return; }
    const sel = {};
    rankRows().forEach(r => { if (r.selected) sel[r.accession] = true; });
    const W = 560, H = 380, M = { l: 62, r: 14, t: 10, b: 46 };
    const xv = pts.map(p => p.x), yv = pts.map(p => p.y);
    const pad = (lo, hi) => { const d = (hi - lo) * 0.05 || 1; return [lo - d, hi + d]; };
    const [x0, x1] = pad(Math.min.apply(null, xv), Math.max.apply(null, xv));
    const [y0, y1] = pad(Math.min.apply(null, yv), Math.max.apply(null, yv));
    const s = svg(b, W, H);
    const ax = axes(s, { x0: M.l, x1: W - M.r, y0: M.t, y1: H - M.b, xmin: x0, xmax: x1, ymin: y0, ymax: y1, xlabel: tx + ' (' + D.label + ')', ylabel: ty + ' (' + D.label + ')', grid: true });
    // regression line
    const r = cor(xv, yv);
    if (r !== null) {
        const mx = mean(xv), my = mean(yv), bslope = r * sd(yv) / sd(xv);
        el('line', { x1: ax.xs(x0), y1: ax.ys(my + bslope * (x0 - mx)), x2: ax.xs(x1), y2: ax.ys(my + bslope * (x1 - mx)), stroke: '#94a3b8', 'stroke-dasharray': '5,4' }, s);
        el('text', { x: W - M.r - 4, y: M.t + 14, 'text-anchor': 'end', fill: '#374151', 'font-weight': 600 }, s, 'r = ' + r.toFixed(2) + '  (n = ' + pts.length + ')');
    }
    // grey first, then selected, then shortlist on top
    const order = p => (isShort(p.a) ? 2 : sel[p.a] ? 1 : 0);
    pts.sort((p, q) => order(p) - order(q)).forEach(p => {
        const sh = isShort(p.a);
        el('circle', { cx: ax.xs(p.x), cy: ax.ys(p.y), r: sh ? 5 : 3.6, fill: sh ? ACCENT : sel[p.a] ? '#86efac' : '#9ca3af', 'fill-opacity': sh ? 0.95 : 0.6,
            stroke: sel[p.a] ? '#166534' : 'none', 'stroke-width': 1, style: 'cursor:pointer',
            'data-acc': p.a, 'data-tip': '<b>' + esc(p.a) + '</b>' + (sh ? ' &#9733;' : '') + (sel[p.a] ? ' (selected)' : '') + '<br/>' + esc(tx) + ': ' + fmt(p.x) + '<br/>' + esc(ty) + ': ' + fmt(p.y) }, s);
    });
    el('text', { x: M.l + 4, y: H - 4, fill: '#9ca3af', 'font-size': 10 }, s, '● shortlist   ● selected (outlined)   ● other — click a point to add/remove it from the shortlist');
}

// ---------------------------------------------------------------------------
// selection
// ---------------------------------------------------------------------------

function renderSelection() {
    invalidateRank();
    const rows = rankRows();
    const nSel = rows.filter(r => r.selected).length;
    $('#sfd_sel_pct_label').text(S.selPct);
    $('#sfd_sel_n').text(nSel + ' of ' + rows.length);
    $('#sfd_stat_sel').text(nSel);
    $('#sfd_rank_dir').toggle(S.rankBy !== 'index');
    $('#sfd_rank_dir button').each(function() { $(this).toggleClass('active', $(this).data('dir') === S.rankDir); });

    // expected response
    const selSet = {};
    rows.forEach(r => { if (r.selected) selSet[r.accession] = true; });
    const ranked = rows.map(r => r.accession);
    const idxTraits = ((R.recipe || {}).index || {}).traits || {};
    const inIndex = {};
    Object.keys(idxTraits).forEach(k => { inIndex[k.replace(/\|.*$/, '')] = idxTraits[k]; });
    const gains = D.traits.map(t => {
        const all = ranked.map(a => D.gv[a][t]).filter(v => v !== null);
        const sel = ranked.filter(a => selSet[a]).map(a => D.gv[a][t]).filter(v => v !== null);
        const pm = mean(all), sm = mean(sel);
        const S0 = sm !== null && pm !== null ? sm - pm : null;
        const h2 = num((D.s2[t] || {}).h2);
        const gain = S0 === null ? null : D.random ? S0 : (h2 !== null ? h2 * S0 : null);
        const good = S0 === null ? null : (traitDir(t) === 'decrease' ? S0 <= 0 : S0 >= 0);
        return { trait: t, used: S.rankBy === 'index' ? !!inIndex[t] : S.rankBy === t, pm: pm, sm: sm, S: S0, Spct: S0 !== null && pm ? 100 * S0 / Math.abs(pm) : null, h2: h2, gain: gain, good: good };
    });
    $('#sfd_gains').html(table(gains, [
        { k: 'trait', l: 'Trait', f: (v, r) => esc(v) + (r.used ? ' <span class="label label-success">ranked on</span>' : '') + (traitDir(v) === 'decrease' ? ' <span class="sfd-help">&darr;</span>' : '') },
        { k: 'pm', l: 'Population mean' }, { k: 'sm', l: 'Selected mean' }, { k: 'S', l: 'Selection differential' },
        { k: 'Spct', l: 'S %', f: (v, r) => v === null ? '&ndash;' : '<b style="color:' + (r.good ? '#2b7a4b' : '#dc2626') + '">' + (v >= 0 ? '+' : '') + fmt(v, 1) + '%</b>' },
        { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) },
        { k: 'gain', l: 'Expected gain', f: (v, r) => v === null ? '&ndash;' : '<b style="color:' + (r.good ? '#2b7a4b' : '#dc2626') + '">' + (v >= 0 ? '+' : '') + fmt(v) + '</b>' }
    ]) + '<p class="sfd-help">' + (D.random ? 'Values are BLUPs (already shrunk by heritability): the expected gain equals the selection differential.' : 'Expected gain = H&sup2; &times; selection differential on BLUEs.') +
        ' Red figures move the trait in the unwanted direction.</p>');
    renderRankChart();
    renderRankTable();
    renderScatter();
}

function scoreLabel() { return S.rankBy === 'index' ? 'Index' : S.rankBy + ' (' + D.label + ')'; }

function renderRankChart() {
    const b = box('sfd_rank_chart');
    const all = rankRows();
    const nSel = all.filter(r => r.selected).length;
    const rows = all.slice(0, Math.min(40, Math.max(15, nSel + 5)));
    if (!rows.length) return;
    const vals = rows.map(r => r.score);
    const mn = Math.min(0, Math.min.apply(null, vals)), mx = Math.max(0, Math.max.apply(null, vals));
    const M = { l: 170, r: 56, t: 4, b: 4 }, bh = 17, W = 520, H = M.t + M.b + rows.length * bh;
    const xs = v => M.l + (W - M.l - M.r) * (v - mn) / ((mx - mn) || 1);
    const s = svg(b, W, H);
    el('line', { x1: xs(0), x2: xs(0), y1: M.t, y2: H - M.b, stroke: '#94a3b8' }, s);
    rows.forEach((r, i) => {
        const y = M.t + i * bh, sh = isShort(r.accession);
        el('rect', { x: Math.min(xs(0), xs(r.score)), y: y + 3, width: Math.max(1, Math.abs(xs(r.score) - xs(0))), height: bh - 6, rx: 2, fill: r.selected ? ACCENT : '#a7d3b5',
            'data-tip': '<b>' + r.rank + '. ' + esc(r.accession) + '</b><br/>' + esc(scoreLabel()) + ': ' + fmt(r.score), 'data-acc': r.accession, style: 'cursor:pointer' }, s);
        el('text', { x: M.l - 6, y: y + bh / 2 + 4, 'text-anchor': 'end', fill: sh ? ACCENT : '#111', 'font-weight': sh ? 700 : 400, 'data-acc': r.accession, style: 'cursor:pointer' }, s,
            (sh ? '★ ' : '') + r.rank + '. ' + (r.accession.length > 22 ? r.accession.slice(0, 21) + '…' : r.accession));
        el('text', { x: Math.max(xs(0), xs(r.score)) + 4, y: y + bh / 2 + 4, fill: '#6b7280', 'font-size': 10 }, s, fmt(r.score).replace('&ndash;', '–'));
    });
}

function renderRankTable() {
    const rows = rankRows();
    const cols = [
        { k: 'rank', l: '#', f: v => v },
        { k: 'accession', l: 'Accession', f: v => accLink(v), order: v => v },
        { k: 'score', l: esc(scoreLabel()) }
    ].concat(D.traits.filter(t => t !== S.rankBy).map(t => ({ k: t, l: esc(t), f: (v, r) => fmt(D.gv[r.accession][t]), order: (v, r) => D.gv[r.accession][t] === null ? -1e300 : D.gv[r.accession][t] })))
        .concat([{ k: 'selected', l: '', f: v => v ? '<span class="label label-success">selected</span>' : '', order: v => (v ? 1 : 0) }]);
    let page = 0, order = [[0, 'asc']];
    if ($.fn.DataTable && $.fn.DataTable.isDataTable('#sfd_dt_rank')) {
        const dt = $('#sfd_dt_rank').DataTable();
        page = dt.page(); order = dt.order();
    }
    $('#sfd_rank_table').html(table(rows, cols, { id: 'sfd_dt_rank' }));
    dataTable('#sfd_dt_rank', { order: order, pageLength: 15 });
    if (page && $.fn.DataTable) $('#sfd_dt_rank').DataTable().page(page).draw(false);
}

// ---------------------------------------------------------------------------
// performance and stability across environments
// ---------------------------------------------------------------------------

function envMatrix(t) {
    const rows = arr(D.s1[t]).filter(r => r.value !== null);
    const envs = [], acc = {};
    const cell = {};
    rows.forEach(r => {
        if (envs.indexOf(r.env) < 0) envs.push(r.env);
        acc[r.accession] = true;
        const k = r.accession + '\u0001' + r.env;
        (cell[k] = cell[k] || []).push(r.value);
    });
    const get = (a, e) => { const v = cell[a + '\u0001' + e]; return v ? mean(v) : null; };
    const envMean = {};
    envs.forEach(e => { envMean[e] = mean(Object.keys(acc).map(a => get(a, e))); });
    const grand = mean(envs.map(e => envMean[e]));
    const envIndex = {};
    envs.forEach(e => { envIndex[e] = envMean[e] - grand; });
    envs.sort((a, b) => envIndex[a] - envIndex[b]);
    return { envs: envs, accessions: Object.keys(acc), get: get, envMean: envMean, envIndex: envIndex, grand: grand };
}

function stabilityStats(t) {
    const m = envMatrix(t);
    if (m.envs.length < 3) return { m: m, rows: [] };
    const rows = [];
    m.accessions.forEach(a => {
        const p = m.envs.map(e => [m.envIndex[e], m.get(a, e)]).filter(q => q[1] !== null);
        if (p.length < 3) return;
        const mx = mean(p.map(q => q[0])), my = mean(p.map(q => q[1]));
        let sxy = 0, sxx = 0;
        p.forEach(q => { sxy += (q[0] - mx) * (q[1] - my); sxx += (q[0] - mx) ** 2; });
        if (sxx <= 0) return;
        const bb = sxy / sxx;
        const a0 = my - bb * mx;
        const ssd = p.reduce((s, q) => s + (q[1] - a0 - bb * q[0]) ** 2, 0) / Math.max(1, p.length - 2);
        const perf = D.gv[a] && D.gv[a][t] !== null && D.gv[a][t] !== undefined ? D.gv[a][t] : my;
        rows.push({ accession: a, b: bb, s2d: ssd, mean: perf, raw_mean: my, n_env: p.length });
    });
    return { m: m, rows: rows };
}

function renderStability() {
    const b = box('sfd_stability');
    const t = S.trait;
    const st = stabilityStats(t);
    const dec = traitDir(t) === 'decrease';
    if (!st.rows.length) {
        $('#sfd_stability_note').html(st.m.envs.length < 3 ? 'Stability needs at least three environments (this analysis has ' + st.m.envs.length + ').' : 'Not enough accessions tested in three or more environments.');
        $('#sfd_quadrants').html('');
        return;
    }
    $('#sfd_stability_note').html('x: ' + esc(D.label) + ' of ' + esc(t) + (dec ? ' (lower is better)' : '') + '; y: regression slope <i>b</i> on the environment index. <i>b</i> &lt; 1: performance changes less than the environment (stable); <i>b</i> &gt; 1: responsive to good environments. ' + st.rows.length + ' accessions tested in &ge; 3 of ' + st.m.envs.length + ' environments.');
    const W = 560, H = 400, M = { l: 56, r: 14, t: 12, b: 46 };
    const xv = st.rows.map(r => r.mean), yv = st.rows.map(r => r.b);
    const pm = mean(xv);
    const padr = (lo, hi) => { const d = (hi - lo) * 0.06 || 0.5; return [lo - d, hi + d]; };
    const [x0, x1] = padr(Math.min.apply(null, xv), Math.max.apply(null, xv));
    const [y0, y1] = padr(Math.min(Math.min.apply(null, yv), 1), Math.max(Math.max.apply(null, yv), 1));
    const s = svg(b, W, H);
    const ax = axes(s, { x0: M.l, x1: W - M.r, y0: M.t, y1: H - M.b, xmin: x0, xmax: x1, ymin: y0, ymax: y1, xlabel: t + ' (' + D.label + ')', ylabel: 'slope b', grid: true });
    // quadrant shading: good side
    const goodX0 = dec ? ax.xs(x0) : ax.xs(pm), goodX1 = dec ? ax.xs(pm) : ax.xs(x1);
    el('rect', { x: goodX0, y: ax.ys(1), width: goodX1 - goodX0, height: ax.ys(y0) - ax.ys(1), fill: '#e8f4ec', 'fill-opacity': 0.8 }, s);
    el('line', { x1: ax.xs(x0), x2: ax.xs(x1), y1: ax.ys(1), y2: ax.ys(1), stroke: '#6b7280', 'stroke-dasharray': '4,3' }, s);
    el('line', { x1: ax.xs(pm), x2: ax.xs(pm), y1: ax.ys(y0), y2: ax.ys(y1), stroke: '#6b7280', 'stroke-dasharray': '4,3' }, s);
    el('text', { x: goodX0 + 6, y: ax.ys(y0) - 6, fill: '#166534', 'font-size': 10, 'font-weight': 600 }, s, 'superior & stable');
    const pts = st.rows.slice().sort((p, q) => (isShort(p.accession) ? 1 : 0) - (isShort(q.accession) ? 1 : 0));
    pts.forEach(r => {
        const sh = isShort(r.accession);
        el('circle', { cx: ax.xs(r.mean), cy: ax.ys(r.b), r: sh ? 5 : 3.5, fill: sh ? ACCENT : '#9ca3af', 'fill-opacity': sh ? 0.95 : 0.6, style: 'cursor:pointer', 'data-acc': r.accession,
            'data-tip': '<b>' + esc(r.accession) + '</b>' + (sh ? ' &#9733;' : '') + '<br/>' + esc(D.label) + ': ' + fmt(r.mean) + '<br/>b = ' + fmt(r.b, 2) + ', s&sup2;d = ' + fmt(r.s2d) + '<br/>' + r.n_env + ' environments' }, s);
    });

    // quadrant lists
    const better = r => (dec ? r.mean < pm : r.mean >= pm);
    const sorter = (p, q) => (dec ? p.mean - q.mean : q.mean - p.mean);
    const quad = (title, desc, f, color) => {
        const list = st.rows.filter(f).sort(sorter).slice(0, 8);
        return '<div style="border-top:3px solid ' + color + '"><b>' + title + '</b><span class="sfd-help">' + desc + '</span><ol>' + (list.map(r => '<li>' + accLink(r.accession) + ' <span class="sfd-help">b ' + r.b.toFixed(2) + '</span></li>').join('') || '<li class="sfd-help">none</li>') + '</ol></div>';
    };
    $('#sfd_quadrants').html(
        quad('Superior and stable', 'broad adaptation', r => better(r) && r.b <= 1, '#2b7a4b') +
        quad('Superior and responsive', 'best in good environments', r => better(r) && r.b > 1, '#2563eb') +
        quad('Inferior and stable', 'low but predictable', r => !better(r) && r.b <= 1, '#9ca3af') +
        quad('Inferior and responsive', 'unstable', r => !better(r) && r.b > 1, '#d97706'));
}

function renderReaction() {
    const b = box('sfd_reaction');
    const t = S.trait;
    const m = envMatrix(t);
    if (m.envs.length < 2) { b.innerHTML = '<p class="sfd-help">Reaction norms need at least two environments.</p>'; return; }
    const accs = S.shortlist.filter(a => m.envs.some(e => m.get(a, e) !== null)).slice(0, 12);
    if (!accs.length) { b.innerHTML = '<p class="sfd-help">Add accessions to the shortlist to compare them across environments.</p>'; return; }
    const W = 820, H = 360, M = { l: 56, r: 170, t: 12, b: 70 };
    const vals = [];
    accs.forEach(a => m.envs.forEach(e => { const v = m.get(a, e); if (v !== null) vals.push(v); }));
    m.envs.forEach(e => vals.push(m.envMean[e]));
    const lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals), d = (hi - lo) * 0.05 || 1;
    const s = svg(b, W, H);
    const xs = i => M.l + (W - M.l - M.r) * (m.envs.length > 1 ? i / (m.envs.length - 1) : 0.5);
    const ax = axes(s, { x0: M.l, x1: W - M.r, y0: M.t, y1: H - M.b, xmin: 0, xmax: 1, ymin: lo - d, ymax: hi + d, ylabel: t, xticks: false });
    m.envs.forEach((e, i) => {
        el('line', { x1: xs(i), x2: xs(i), y1: M.t, y2: H - M.b, stroke: '#f3f4f6' }, s);
        el('text', { x: 0, y: 0, transform: 'translate(' + (xs(i) + 3) + ',' + (H - M.b + 10) + ') rotate(35)', fill: '#6b7280', 'font-size': 10 }, s, e.length > 18 ? e.slice(0, 17) + '…' : e);
    });
    // environment mean
    el('polyline', { points: m.envs.map((e, i) => xs(i) + ',' + ax.ys(m.envMean[e])).join(' '), fill: 'none', stroke: '#111', 'stroke-width': 2, 'stroke-dasharray': '6,4' }, s);
    el('text', { x: W - M.r + 8, y: ax.ys(m.envMean[m.envs[m.envs.length - 1]]) + 4, fill: '#111', 'font-size': 11 }, s, 'environment mean');
    accs.forEach((a, k) => {
        const c = CAT_COLORS[k % CAT_COLORS.length];
        const pts = m.envs.map((e, i) => [i, m.get(a, e)]).filter(p => p[1] !== null);
        el('polyline', { points: pts.map(p => xs(p[0]) + ',' + ax.ys(p[1])).join(' '), fill: 'none', stroke: c, 'stroke-width': 2, 'stroke-opacity': 0.85 }, s);
        pts.forEach(p => el('circle', { cx: xs(p[0]), cy: ax.ys(p[1]), r: 3.5, fill: c, 'data-tip': '<b>' + esc(a) + '</b><br/>' + esc(m.envs[p[0]]) + ': ' + fmt(p[1]) + '<br/>environment mean ' + fmt(m.envMean[m.envs[p[0]]]) }, s));
        el('text', { x: W - M.r + 8, y: M.t + 14 + k * 15, fill: c, 'font-size': 11, 'font-weight': 600, 'data-acc': a, style: 'cursor:pointer' }, s, (a.length > 22 ? a.slice(0, 21) + '…' : a));
    });
    if (S.shortlist.length > 12) el('text', { x: M.l, y: H - 4, fill: '#9ca3af', 'font-size': 10 }, s, 'Showing the first 12 shortlisted accessions.');
}

function renderGxeHeat() {
    const t = S.trait;
    const m = envMatrix(t);
    if (m.envs.length < 2) { $('#sfd_gxe_heat').html('<p class="sfd-help">Needs at least two environments.</p>'); return; }
    const dec = traitDir(t) === 'decrease';
    const mode = $('#sfd_gxe_rows').val();
    const scale = $('#sfd_gxe_scale').val();
    let accs = m.accessions.filter(a => D.gv[a]);
    accs.sort((a, b) => { const x = D.gv[a][t], y = D.gv[b][t]; return (y === null) - (x === null) || (dec ? x - y : y - x); });
    if (mode === 'top') accs = accs.slice(0, 30);
    else if (mode === 'shortlist') accs = accs.filter(isShort);
    if (!accs.length) { $('#sfd_gxe_heat').html('<p class="sfd-help">No accession to show' + (mode === 'shortlist' ? ': the shortlist is empty.' : '.') + '</p>'); return; }
    const all = [];
    accs.forEach(a => m.envs.forEach(e => { const v = m.get(a, e); if (v !== null) all.push(scale === 'dev' ? v - m.envMean[e] : v); }));
    const lim = all.length ? Math.max.apply(null, all.map(Math.abs)) : 1;
    const lo = Math.min.apply(null, all), hi = Math.max.apply(null, all);
    const colorOf = v => v === null ? '#fff' : scale === 'dev' ? divColor(dec ? -v : v, lim) : seqColor(v, lo, hi);
    let h = '<table class="sfd-heat"><thead><tr><th class="r">Accession</th><th title="' + esc(D.label) + ' across environments">' + esc(D.label) + '</th>' +
        m.envs.map(e => '<th title="' + esc(e) + ' &middot; mean ' + fmt(m.envMean[e]).replace(/&[a-z]+;/g, '-') + '">' + esc(e.length > 12 ? e.slice(0, 11) + '…' : e) + '</th>').join('') + '</tr></thead><tbody>';
    accs.forEach(a => {
        h += '<tr><th class="r">' + accLink(a) + '</th><td><b>' + fmt(D.gv[a][t]) + '</b></td>' + m.envs.map(e => {
            const v = m.get(a, e);
            const x = v === null ? null : scale === 'dev' ? v - m.envMean[e] : v;
            const bg = colorOf(x);
            const tip = '<b>' + esc(a) + '</b><br/>' + esc(e) + ': ' + (v === null ? 'not tested' : fmt(v) + ' (env. mean ' + fmt(m.envMean[e]) + ')');
            return '<td style="background:' + bg + ';color:' + textOn(bg) + '" data-tip="' + esc(tip) + '">' + (x === null ? '' : fmt(x)) + '</td>';
        }).join('') + '</tr>';
    });
    h += '</tbody></table><p class="sfd-help" style="margin-top:6px">Environments ordered from the poorest to the best mean. ' + (scale === 'dev' ? 'Green: better than the environment mean; orange: worse.' : '') + '</p>';
    $('#sfd_gxe_heat').html(h);
}

// ---------------------------------------------------------------------------
// zones, outliers, model
// ---------------------------------------------------------------------------

function renderZones() {
    const z = D.zones.find(x => x.target === S.zoneTarget) || D.zones[0];
    if (!z) return;
    const names = [];
    arr(z.membership).forEach(m => { if (names.indexOf(m.zone) < 0) names.push(m.zone); });
    let h = '<p><b>' + esc(z.target) + '</b>: <b>' + z.n_zones + '</b> zone(s) by ' + (z.method === 'lin' ? 'the Lin (1982) G&times;E test' : 'genetic correlation clustering') +
        '. <a href="#sfd_map_section" class="sfd-zones-on-map"><span class="glyphicon glyphicon-map-marker"></span> Show on the map</a></p><div class="row">';
    names.forEach(zn => {
        const envs = arr(z.membership).filter(m => m.zone === zn);
        const top = arr(z.top).filter(x => x.zone === zn);
        h += '<div class="col-lg-6"><div class="sfd-card" style="border-top:4px solid ' + zoneColor(zn) + '"><h4 style="margin-top:0"><span class="sfd-zone-chip" style="background:' + zoneColor(zn) + '">' + esc(zn) + '</span> ' + envs.length + ' environment(s)</h4>' +
            '<p class="sfd-help">' + envs.map(e => esc(e.env) + (e.location && e.location !== e.env ? ' <small>(' + esc(e.location) + ')</small>' : '')).join(', ') + '</p>' +
            table(top, [{ k: 'rank', l: '#', f: v => v }, { k: 'accession', l: 'Best accessions', f: v => accLink(v) }, { k: 'value', l: 'Mean' }, { k: 'n_env', l: 'Envs', f: v => v }], { empty: 'No accession tested in all environments of this zone.' }) + '</div></div>';
    });
    h += '</div>';
    if (z.correlation && arr(z.correlation.environments).length) {
        const envs = arr(z.correlation.environments), mat = arr(z.correlation.matrix);
        const zoneOf = {};
        arr(z.membership).forEach(m => { zoneOf[m.env] = m.zone; });
        h += '<h4>Genetic correlation between environments</h4><div class="sfd-scroll"><table class="sfd-heat"><thead><tr><th></th>' +
            envs.map(e => '<th title="' + esc(e) + '" style="border-bottom:3px solid ' + zoneColor(zoneOf[e]) + '">' + esc(e.length > 12 ? e.slice(0, 11) + '…' : e) + '</th>').join('') + '</tr></thead><tbody>';
        envs.forEach((e, i) => {
            h += '<tr><th class="r" style="border-left:3px solid ' + zoneColor(zoneOf[e]) + '">' + esc(e) + '</th>' + arr(mat[i]).map(v => {
                const bg = v === null ? '#f3f4f6' : divColor(v, 1, ['#b45309', '#f59e0b', '#fde68a', '#f7f7f7', '#bbf7d0', '#22c55e', '#166534']);
                return '<td style="background:' + bg + ';color:' + textOn(bg) + '">' + (v === null ? '' : Number(v).toFixed(2)) + '</td>';
            }).join('') + '</tr>';
        });
        h += '</tbody></table></div>';
    }
    if (arr(z.pairwise).length) {
        h += '<h4>Pairwise G&times;E tests</h4>' + table(z.pairwise, [
            { k: 'env1', l: 'Environment 1' }, { k: 'env2', l: 'Environment 2' }, { k: 'n_genotypes', l: 'Common accessions', f: v => v },
            { k: 'f', l: 'F' }, { k: 'p_value', l: 'p', f: v => fmt(v, 4) },
            { k: 'compatible', l: 'Same zone?', f: v => v ? '<span class="glyphicon glyphicon-ok" style="color:#2b7a4b"></span>' : '<span class="glyphicon glyphicon-remove" style="color:#dc2626"></span>' }]);
    }
    $('#sfd_zones').html(h);
}

function renderOutliers() {
    const b = box('sfd_outlier_chart');
    const out = arr(R.outliers);
    const summ = arr(R.outlier_summary);
    if (summ.length) {
        const W = 820, bh = 22, M = { l: 190, r: 120, t: 6 }, H = M.t + summ.length * bh + 8;
        const s = svg(b, W, H);
        const mx = Math.max(5, Math.max.apply(null, summ.map(r => Number(r.pct_removed) || 0)));
        summ.forEach((r, i) => {
            const y = M.t + i * bh, w = (W - M.l - M.r) * (Number(r.pct_removed) || 0) / mx;
            el('text', { x: M.l - 8, y: y + bh / 2 + 4, 'text-anchor': 'end', fill: '#111' }, s, r.trait.length > 28 ? r.trait.slice(0, 27) + '…' : r.trait);
            el('rect', { x: M.l, y: y + 4, width: W - M.l - M.r, height: bh - 8, fill: '#f3f4f6', rx: 3 }, s);
            el('rect', { x: M.l, y: y + 4, width: Math.max(r.n_removed ? 2 : 0, w), height: bh - 8, fill: '#dc2626', 'fill-opacity': 0.8, rx: 3, 'data-tip': r.n_removed + ' of ' + r.n_observations + ' values removed' }, s);
            el('text', { x: W - M.r + 6, y: y + bh / 2 + 4, fill: '#374151' }, s, r.n_removed + ' / ' + r.n_observations + ' (' + Number(r.pct_removed).toFixed(1) + '%)');
        });
    }
    $('#sfd_outlier_table').html(table(out, [
        { k: 'unit', l: 'Plot' }, { k: 'trial', l: 'Trial' }, { k: 'accession', l: 'Accession', f: v => accLink(v), order: v => v }, { k: 'trait', l: 'Trait' }, { k: 'value', l: 'Value' }, { k: 'reason', l: 'Reason' }
    ], { id: 'sfd_dt_outliers', empty: 'No values were removed.' }));
    if (out.length) dataTable('#sfd_dt_outliers', { pageLength: 10 });
}

function renderModel() {
    const code = v => '<code>' + esc(v) + '</code>';
    let h = '';
    if (R.strategy === 'two_stage') {
        h += '<h4>Stage 1 (per trial)</h4>' + table(R.stage1, [
            { k: 'trial', l: 'Trial' }, { k: 'trait', l: 'Trait' }, { k: 'design', l: 'Design' }, { k: 'n', l: 'n', f: v => v }, { k: 'mean', l: 'Mean' },
            { k: 'cv', l: 'CV %', f: v => fmt(v, 1) }, { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) }, { k: 'model', l: 'Model', f: code }, { k: 'message', l: 'Status', f: v => v === 'OK' ? '' : '<small>' + esc(v) + '</small>' }
        ], { id: 'sfd_dt_stage1' });
        h += '<h4>Stage 2 (across trials)</h4>';
    } else {
        h += '<h4>Single-stage model</h4>';
    }
    h += table(R.stage2, [
        { k: 'trait', l: 'Trait' }, { k: 'model', l: 'Model', f: code },
        { k: 'var_g', l: '&sigma;&sup2;<sub>G</sub>' }, { k: 'var_ge', l: '&sigma;&sup2;<sub>GE</sub>' }, { k: 'var_e', l: '&sigma;&sup2;<sub>e</sub>' },
        { k: 'h2', l: 'H&sup2;', f: v => h2Badge(v) },
        { k: 'message', l: 'Status', f: (v, r) => esc(v) + (r.dropped_terms ? '<br/><small class="sfd-help">left out: ' + esc(r.dropped_terms) + '</small>' : '') }
    ]);
    if (arr(R.variance_components).length) {
        h += '<h4>Variance components</h4>' + table(R.variance_components, [{ k: 'trait', l: 'Trait' }, { k: 'component', l: 'Component', f: v => esc(prettyComp(v)) }, { k: 'variance', l: 'Variance' }], { id: 'sfd_dt_vc' });
    }
    h += '<h4>Trials</h4>' + table(R.trials, [{ k: 'trial', l: 'Trial' }, { k: 'location', l: 'Location' }, { k: 'year', l: 'Year' }, { k: 'design', l: 'Design' },
        { k: 'spatial_layout', l: 'Row/col', f: v => v ? 'yes' : '' }, { k: 'n_plots', l: 'Plots', f: v => v }, { k: 'n_accessions', l: 'Accessions', f: v => v }]);
    h += '<h4><a data-toggle="collapse" href="#sfd_recipe">Script definition <span class="caret"></span></a></h4><pre id="sfd_recipe" class="collapse" style="max-height:400px;overflow:auto;font-size:11px">' + esc(JSON.stringify(R.recipe || {}, null, 2)) + '</pre>';
    $('#sfd_model').html(h);
    if (arr(R.stage1).length) dataTable('#sfd_dt_stage1', { pageLength: 10 });
    if (arr(R.variance_components).length > 15) dataTable('#sfd_dt_vc', { pageLength: 10 });
}

// ---------------------------------------------------------------------------
// controls
// ---------------------------------------------------------------------------

function renderTraitDependent() {
    safely('map', renderMap);
    safely('field layout', renderField);
    safely('trial quality', renderTrialQuality);
    safely('stability', renderStability);
    safely('reaction norm', renderReaction);
    safely('accession x environment', renderGxeHeat);
}

function initControls() {
    const opt = (v, l, sel) => '<option value="' + esc(v) + '"' + (sel ? ' selected' : '') + '>' + esc(l) + '</option>';
    S.trait = (R.index && R.index.gains && D.traits.find(t => arr(R.index.gains).some(g => g.trait === t && g.in_index))) || D.traits[0];
    $('#sfd_trait').html(D.traits.map(t => opt(t, t, t === S.trait)).join(''));

    // selection
    S.rankBy = R.index ? 'index' : S.trait;
    S.rankDir = traitDir(S.rankBy);
    S.selPct = R.index ? Number(R.index.selection_pct) || 10 : 10;
    $('#sfd_rank_by').html((R.index ? opt('index', 'Selection index (' + (R.index.method === 'rank_sum' ? 'rank sum' : 'Z-score') + ')', true) : '') + D.traits.map(t => opt(t, t, !R.index && t === S.rankBy)).join(''));
    $('#sfd_sel_pct').val(S.selPct);

    // field
    S.fieldTrial = (D.trials.find(t => t.spatial_layout) || D.trials[0] || {}).trial;
    $('#sfd_field_trial').html(D.trials.map(t => opt(t.trial, t.trial + (t.spatial_layout ? '' : ' (no row/col)'), t.trial === S.fieldTrial)).join(''));

    // scatter
    S.scatterX = D.traits[0];
    S.scatterY = D.traits[1] || D.traits[0];
    $('#sfd_scatter_x').html(D.traits.map(t => opt(t, t, t === S.scatterX)).join(''));
    $('#sfd_scatter_y').html(D.traits.map(t => opt(t, t, t === S.scatterY)).join(''));

    // zones
    $('.sfd-zones-only').toggle(D.zones.length > 0);
    if (D.zones.length) {
        S.zoneTarget = D.zones[0].target;
        const zo = D.zones.map(z => opt(z.target, z.target, z.target === S.zoneTarget)).join('');
        $('#sfd_zone_target, #sfd_map_zone_target').html(zo);
    } else {
        $('#sfd_map_color option[value=zone]').remove();
    }
    $('#sfd_accession_options').html(D.accessions.map(a => '<option value="' + esc(a) + '">').join(''));

    // events
    $('#sfd_trait').on('change', function() { S.trait = $(this).val(); renderTraitDependent(); });
    $(document).on('click', '.sfd-set-trait', function(e) { e.preventDefault(); $('#sfd_trait').val($(this).data('trait')).trigger('change'); });
    $('#sfd_map_color').on('change', function() { S.mapColor = $(this).val(); renderMap(); });
    $('#sfd_map_zone_target').on('change', function() { S.zoneTarget = $(this).val(); $('#sfd_zone_target').val(S.zoneTarget); renderMap(); renderZones(); });
    $('#sfd_map_accession').on('change', function() { S.mapAccession = D.accSet[$(this).val()] ? $(this).val() : ''; renderMap(); });
    $('#sfd_field_trial').on('change', function() { S.fieldTrial = $(this).val(); renderField(); });
    $('#sfd_field_layer').on('change', function() { S.fieldLayer = $(this).val(); renderField(); });
    $('#sfd_scatter_x').on('change', function() { S.scatterX = $(this).val(); renderScatter(); });
    $('#sfd_scatter_y').on('change', function() { S.scatterY = $(this).val(); renderScatter(); });
    $('#sfd_correlations').on('click', '.sfd-cor', function() {
        S.scatterX = $(this).data('x'); S.scatterY = $(this).data('y');
        $('#sfd_scatter_x').val(S.scatterX); $('#sfd_scatter_y').val(S.scatterY);
        renderScatter();
    });
    $('#sfd_rank_by').on('change', function() {
        S.rankBy = $(this).val();
        if (S.rankBy !== 'index') S.rankDir = traitDir(S.rankBy);
        renderSelection();
    });
    $('#sfd_rank_dir').on('click', 'button', function() { S.rankDir = $(this).data('dir'); renderSelection(); });
    $('#sfd_sel_pct').on('input change', function() { S.selPct = Number($(this).val()); renderSelection(); });
    $('#sfd_gxe_rows, #sfd_gxe_scale').on('change', renderGxeHeat);
    $('#sfd_zone_target').on('change', function() { S.zoneTarget = $(this).val(); $('#sfd_map_zone_target').val(S.zoneTarget); renderZones(); if (S.mapColor === 'zone') renderMap(); });
    $(document).on('click', '.sfd-zones-on-map', function() {
        S.mapColor = 'zone'; $('#sfd_map_color').val('zone'); renderMap();
    });

    // shortlist
    $(document).on('click', '[data-acc]', function(e) {
        if ($(e.target).closest('a[href]').length) return;
        toggleShort($(this).attr('data-acc'));
    });
    $('#sfd_short_input').on('change', function() {
        const a = $(this).val();
        if (D.accSet[a] && !isShort(a)) toggleShort(a);
        $(this).val('');
    });
    $('#sfd_short_save').on('click', saveShortList);
    $('#sfd_short_csv').on('click', shortlistCSV);
    $('#sfd_short_reset').on('click', e => { e.preventDefault(); S.shortlist = defaultShortlist(); saveShort(); renderShortDependent(); });
    $('#sfd_short_clear').on('click', e => { e.preventDefault(); if (confirm('Remove every accession from the shortlist?')) { S.shortlist = []; saveShort(); renderShortDependent(); } });

    // navigation highlight
    const secs = $('.sfd-section');
    $(window).on('scroll', () => {
        let cur = null;
        secs.each(function() { if ($(this).is(':visible') && this.getBoundingClientRect().top < 140) cur = this.id; });
        $('#sfd_nav a').each(function() { $(this).toggleClass('on', $(this).attr('href') === '#' + cur); });
    });
}

// ---------------------------------------------------------------------------
// start
// ---------------------------------------------------------------------------

// each view is drawn on its own: a problem in one never hides the others
function safely(name, f) {
    try {
        f();
    } catch (e) {
        if (window.console) console.error('Dashboard view "' + name + '":', e);
        $('#sfd_message').append('<div class="alert alert-warning">The ' + esc(name) + ' view could not be drawn: ' + esc(e.message) + '</div>');
    }
}

function renderAll() {
    safely('header', renderHeader);
    safely('overview', renderOverview);
    safely('selection', renderSelection);
    S.shortlist = loadShort() || defaultShortlist();
    safely('shortlist', renderShortlist);
    safely('map', renderMap);
    safely('field layout', renderField);
    safely('trial quality', renderTrialQuality);
    safely('distribution', renderDistributions);
    safely('correlation', renderCorrelations);
    safely('scatter plot', renderScatter);
    safely('stability', renderStability);
    safely('reaction norm', renderReaction);
    safely('accession x environment', renderGxeHeat);
    if (D.zones.length) safely('zones', renderZones);
    safely('outliers', renderOutliers);
    safely('model', renderModel);
    safely('ranking', renderRankTable);
}

// open the steps of this analysis in the Script Factory: the stored analysis
// when there is one (it outlives the temporary run files), else the run
function initPipelineLink() {
    const stored = R.stored && R.stored.analysis_id;
    if (!stored && !META.is_owner) return;
    $('#sfd_pipeline').attr('href', '/tools/script_factory?' + (stored ? 'analysis_id=' + encodeURIComponent(R.stored.analysis_id) : 'run_id=' + encodeURIComponent(cfg.run_id))).show();
}

// store the analysis from the dashboard (the owner of the run only)
function initStore() {
    if (!META.is_owner) return;
    const stored = (id, name) => {
        $('#sfd_store_result').html(storedNotice(id, name));
        $('#sfd_store').prop('disabled', true).html('<span class="glyphicon glyphicon-ok"></span> Stored');
        R.stored = { analysis_id: id, name: name };
        initPipelineLink();
    };
    $('#sfd_store').show().on('click', () => openStoreDialog({
        runId: cfg.run_id,
        res: R,
        ctx: { scriptName: META.script_name || R.script_name, datasetName: META.dataset_name || R.dataset_name, outlierMethod: ((R.recipe || {}).outliers || {}).method },
        programs: R.programs || [],
        onStored: stored
    }));
    if (R.stored && R.stored.analysis_id) stored(R.stored.analysis_id, R.stored.name);
}

export function init(options) {
    $ = window.jQuery;
    cfg = options || {};
    initTooltip();
    if (!cfg.run_id) {
        $('#sfd_title').text('Decision dashboard');
        $('#sfd_message').html('<div class="alert alert-warning">No analysis was given. Run an analysis on the <a href="/tools/script_factory">Script Factory</a> page and open its dashboard from the results.</div>');
        return;
    }
    $.ajax({ url: '/ajax/script_factory/results', data: { run_id: cfg.run_id }, dataType: 'json' })
        .done(r => {
            if (r.error) {
                $('#sfd_title').text('Decision dashboard');
                $('#sfd_message').html('<div class="alert alert-warning">' + esc(r.error) + ' <a href="/tools/script_factory">Go to the Script Factory</a>.</div>');
                return;
            }
            R = r.results; META = r.meta || {}; LOCS = r.locations || {};
            prepare();
            $('#sfd_body').show();
            initControls();
            renderAll();
            initStore();
            initPipelineLink();
        })
        .fail(x => {
            $('#sfd_title').text('Decision dashboard');
            $('#sfd_message').html('<div class="alert alert-danger">Could not load the results (' + esc(x.status + ' ' + x.statusText) + ').</div>');
        });
}
