/*
 * Weather for breeders (/breeders/weather)
 *
 * Research stations (Breedbase locations) on the left. For the chosen one:
 *   1 Distance range  km or miles (default from the configuration, 200 km)
 *   2 Weather station real observing stations within the range, saved as
 *                     the station of the location (a rain gauge is paired
 *                     with a station for temperature)
 *   3 Season          dates, crop and planting date, or the season of a trial
 * Tabs:
 *   Season       stress by crop stage, stress calendar, aligned charts, tables
 *   Trials       environmental covariates of each trial of the location (G x E)
 *   Past years   the same dates in the previous years: was this season normal?
 *   Comparison   the environments of several locations for the same dates (its own dates)
 *   Data sources map, stations and the comparison of the rain sources
 *   Concepts     how GDD, ET0, water balance, stages and maize RM are calculated
 * Temperatures are kept in °C; the °C / °F switch changes only what is shown.
 * Only observations of real stations are used (no model, no forecast).
 * Calculations: modules/weather_breeding.js; charts: modules/weather_charts.js.
 *
 * Endpoints: /ajax/weather/* (SGN::Controller::AJAX::Weather).
 *
 * Author: Chris Simoes
 */

import '../legacy/leaflet.js';
import { CROPS, DEFAULTS, num, addDays, daysBetween, median, seasonDays, summarize, cropStages, stressDays, verdicts, covariates, covariateColumns, RM_STEPS, rmToGddF, rmSeason, rmDates, rmZone, rmBand, daysBand,
    UNITS, isF, tUnit, ddUnit, toT, toDD, toCelsius, fmtT, fmtTh, inUnit, rmReasonText } from '../modules/weather_breeding.js';
import { chartXY as chartXYBase, stressStrip as stressStripBase, catBars as catBarsBase } from '../modules/weather_charts.js';

let $;
const API = '/ajax/weather';
const KM_PER_MI = 1.609344;
const COLORS = { tmax: '#eb6834', tmin: '#2a78d6', rain: '#2a78d6', et0: '#eb6834', gdd: '#1baf7a', dew: '#1baf7a', temp: '#eb6834' };
const NET_NAMES = { local: 'Uploaded', airport: 'Airport', synop: 'National service', cocorahs: 'CoCoRaHS', ideam: 'IDEAM', inmet: 'INMET', ana: 'ANA', cemaden: 'CEMADEN', dwd: 'DWD', jma: 'JMA AMeDAS' };
const RAIN_NETS = ['synop', 'cocorahs', 'ideam', 'inmet', 'ana', 'cemaden', 'dwd', 'jma'];
// networks with temperature (stations of mixed networks say rain_only when they have none)
const TEMP_NETS = ['airport', 'synop', 'inmet', 'dwd', 'jma'];
const STRESS_ROWS = [
    { key: 'heat', label: 'Heat', color: '#e34948' },
    { key: 'frost', label: 'Frost', color: '#6250d6' },
    { key: 'dry', label: 'Dry spell', color: '#eda100' },
    { key: 'heavy', label: 'Heavy rain', color: '#2a78d6' },
    { key: 'missing', label: 'No data', color: '#cbd5e1' },
];

const S = {
    cfg: null, locations: [], lfilter: 'coords', lsearch: '', ltype: '',
    loc: null, range: 200, unit: 'km', stations: [], netFilter: 'all', station: null, tempStation: null, compare: null,
    tab: 'season', preset: '90', start: '', end: '', planting: '', plantingSet: false, trials: [], trialsAll: [],
    daily: null, dailyKey: '', seq: 0, cache: {}, autoPicked: false, skipped: [], silent: {},
    crop: '', p: Object.assign({}, DEFAULTS),
    trialRows: null, years: null, locRows: null, locPick: {}, localStations: [], chosen: {}, cmp: null,
    map: null, mapLayers: null,
};
const chartXY = (sel, pts, series, opt) => chartXYBase($, sel, pts, series, opt);
const stressStrip = (sel, stress, rows, opt) => stressStripBase($, sel, stress, rows, opt);
const catBars = (sel, items, opt) => catBarsBase($, sel, items, opt);

// ---------------------------------------------------------------- helpers
function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function f1(v, d) { const x = num(v); return x === null ? '–' : x.toFixed(d === undefined ? 1 : d); }
function call(type, url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, type: type, data: data, dataType: 'json', cache: false, timeout: 60000 })
            .done(r => (r && r.error ? reject(new Error(r.error)) : resolve(r)))
            .fail(x => {
                const j = x.responseJSON || {};
                reject(new Error(j.error || j.message || (x.statusText === 'timeout' ? 'The request took too long. Try a shorter date range.' : 'Server error ' + x.status)));
            });
    });
}
function alertHtml(type, msg) { return '<div class="alert alert-' + type + ' wx-alert">' + msg + '</div>'; }
function flash(type, msg) {
    $('#wx_flash').html(alertHtml(type, '<button type="button" class="close" data-dismiss="alert">&times;</button>' + msg));
    if (type === 'success') setTimeout(() => $('#wx_flash .alert-success').fadeOut(), 4000);
}
function loading(msg) { return '<div class="wx-loading"><span class="glyphicon glyphicon-refresh wx-spin"></span> ' + esc(msg || 'Loading...') + '</div>'; }
function iso(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
function dist(km) {
    const x = num(km);
    if (x === null) return '–';
    return S.unit === 'mi' ? (x / KM_PER_MI).toFixed(x / KM_PER_MI < 10 ? 1 : 0) + ' mi' : x.toFixed(x < 10 ? 1 : 0) + ' km';
}
function netName(n) { return NET_NAMES[n] || netConf(n).short || n; }
// the networks of the configuration with rain / temperature (new networks say it in /config)
const isRainNet = n => RAIN_NETS.includes(n) || !!netConf(n).rain;
const isTempNet = n => TEMP_NETS.includes(n) || !!netConf(n).temp;
function netConf(n) { return (S.cfg && S.cfg.networks && S.cfg.networks[n]) || {}; }
function netLabel(n) { return '<span class="wx-net wx-net-' + esc(n) + '">' + esc(netName(n)) + '</span>'; }
function stationLabel(s) {
    if (!s) return '';
    if (s.network === 'hilltop') return s.name || s.id;    // council sites: internal ids, the name says it
    return s.network === 'cemaden' ? (s.code || s.id) + ' ' + String(s.name || '').replace(/^.*\(/, '(') : s.id + ' ' + (s.name || '');
}
// stations the page may pick by itself, best first: rain gauges, then stations reporting now, then any;
// stations already found silent for the current dates are left out
function autoCandidates() {
    const ok = s => s.ready && !(S.silent || {})[stationKey(s) + '|' + S.start + '|' + S.end];
    const list = [];
    const add = s => { if (s && !list.includes(s)) list.push(s); };
    S.stations.filter(s => isOwnLocal(s) && ok(s)).forEach(add);    // the stations of the farm itself first
    S.stations.filter(s => measuresRain(s) && ok(s)).forEach(add);
    S.stations.filter(s => ok(s) && (s.network !== 'airport' || s.latest)).forEach(add);
    S.stations.filter(ok).forEach(add);
    return list;
}
// did the station send anything for these dates?
function hasObservations(r) {
    return (r.days || []).some(d => num(d.tmax) !== null || num(d.tmin) !== null || num(d.rain) !== null || num(d.rain_hours));
}

// uploaded stations (network 'local') say what they measure; the others are known by their network
function measuresRain(s) { return s && (s.network === 'local' ? !!s.has_rain : Array.isArray(s.measures) ? s.measures.includes('rain') : isRainNet(s.network)) && s.ready; }
function measuresTemp(s) { return s && (s.network === 'local' ? !!s.has_temp : Array.isArray(s.measures) ? s.measures.includes('temperature') : isTempNet(s.network)) && s.ready && !s.rain_only; }
function plainStation(s) {
    return s ? { network: s.network, id: s.id, name: s.name, lat: s.lat, lon: s.lon, elev: s.elev, distance_km: s.distance_km, direction: s.direction, rain_only: s.rain_only, ready: s.ready, approx_position: s.approx_position, history_hours: s.history_hours } : null;
}
function fmtDate(d) { return d ? d.slice(8) + '/' + d.slice(5, 7) + '/' + d.slice(0, 4) : ''; }
function shortDate(d) { return d ? d.slice(8) + '/' + d.slice(5, 7) : ''; }
function ago(epoch) {
    if (!epoch) return '';
    const m = Math.round((Date.now() / 1000 - epoch) / 60);
    return m < 60 ? m + ' min ago' : m < 48 * 60 ? Math.round(m / 60) + ' h ago' : Math.round(m / 1440) + ' days ago';
}
function stationKey(st) { return st ? st.network + ':' + st.id : ''; }

// ---------------------------------------------------------------- uploaded stations of the location (network 'local')
// shown on their own, at once (no search needed); the public stations are found by the search of step 1
const isOwnLocal = s => !!s && s.network === 'local' && S.loc && String(s.location_id) === String(S.loc.id);
function kmBetween(lat1, lon1, lat2, lon2) {
    const r = Math.PI / 180;
    const a = Math.sin((lat2 - lat1) * r / 2) ** 2 + Math.cos(lat1 * r) * Math.cos(lat2 * r) * Math.sin((lon2 - lon1) * r / 2) ** 2;
    return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(a)));
}
function toLocalStation(s) {
    const d = hasCoords(S.loc) && num(s.lat) !== null && num(s.lon) !== null ? kmBetween(Number(S.loc.lat), Number(S.loc.lon), Number(s.lat), Number(s.lon)) : 0;
    return Object.assign({}, s, {
        network: 'local', ready: 1, rain_only: s.has_temp ? 0 : 1, rain_amounts: s.has_rain, distance_km: Math.round(d * 10) / 10, direction: '',
        measures: [s.has_temp && 'temperature', s.has_rain && 'rain', s.has_radiation && 'radiation', s.has_rh && 'humidity', s.has_wind && 'wind'].filter(Boolean),
    });
}
// the uploaded stations of the location join the list of stations (the search may not have run yet)
function mergeLocal() {
    S.localStations.forEach(s => {
        const i = S.stations.findIndex(x => stationKey(x) === stationKey(s));
        if (i < 0) S.stations.unshift(s);
        else if (!S.stations[i].location_id) S.stations[i].location_id = s.location_id;
    });
}
function loadLocalStations() {
    const seq = S.seq;
    return call('GET', API + '/local_stations', { location_id: S.loc.id }).then(r => {
        if (seq !== S.seq) return;
        S.localStations = (r.stations || []).filter(x => x.days).map(toLocalStation);
        mergeLocal();
        if (!S.station && S.localStations.length) {
            S.station = S.localStations[0];
            S.autoPicked = true;
            renderChosen();
            stationChanged();
        }
        else {
            // the station saved for the location may be one of them: complete it (what it measures, dates)
            const same = S.station && S.localStations.find(x => stationKey(x) === stationKey(S.station));
            if (same) Object.assign(S.station, same);
            renderChosen();
        }
    }).catch(() => {});
}
function storage(key, val) {
    try {
        if (val === undefined) return JSON.parse(window.localStorage.getItem('wx_' + key));
        window.localStorage.setItem('wx_' + key, JSON.stringify(val));
    } catch (e) { /* private window */ }
    return null;
}

// ---------------------------------------------------------------- locations
function loadLocations() {
    return call('GET', API + '/locations').then(r => {
        S.locations = r.locations || [];
        const types = [...new Set(S.locations.map(l => l.type).filter(Boolean))].sort();
        $('#wx_ltype').html('<option value="">All location types</option>' + types.map(t => '<option>' + esc(t) + '</option>').join(''))
            .toggle(types.length > 1);
        renderLocations();
    });
}

function hasCoords(l) { return num(l.lat) !== null && num(l.lon) !== null && !(Number(l.lat) === 0 && Number(l.lon) === 0); }

function renderLocations() {
    const q = S.lsearch.toLowerCase();
    const base = S.locations.filter(l => !S.ltype || l.type === S.ltype)
        .filter(l => !q || [l.name, l.abbreviation, l.country, l.program, l.type].join(' ').toLowerCase().includes(q));
    const counts = { coords: base.filter(hasCoords).length, linked: base.filter(l => l.station).length, all: base.length };
    $('.wx-seg[data-lfilter]').each(function () {
        const f = $(this).data('lfilter');
        $(this).toggleClass('on', f === S.lfilter).find('.wx-count').text(counts[f]);
    });
    const list = base.filter(l => S.lfilter === 'all' || (S.lfilter === 'linked' ? l.station : hasCoords(l)));
    if (!list.length) {
        $('#wx_locations').html('<div class="wx-loading">No locations' + (q ? ' match the search' : '') + '.</div>');
        return;
    }
    $('#wx_locations').html(list.map(l => {
        const st = l.station
            ? '<span class="wx-pill wx-pill-st" title="' + esc(l.station.name) + '">' + esc(l.station.station_id) + ' · ' + dist(l.station.distance_km) + '</span>'
            : hasCoords(l) ? '' : '<span class="wx-pill wx-pill-warn">no coordinates</span>';
        return '<a class="wx-litem' + (S.loc && S.loc.id === l.id ? ' on' : '') + (hasCoords(l) ? '' : ' off') + '" data-lid="' + l.id + '">'
            + '<b>' + esc(l.name) + '</b> ' + st
            + '<span class="wx-litem-meta">' + esc([l.type, l.country, l.program].filter(Boolean).join(' · ')) + '</span></a>';
    }).join(''));
}

function selectLocation(id) {
    const l = S.locations.find(x => String(x.id) === String(id));
    if (!l) return;
    S.loc = l;
    S.seq++;
    S.stations = [];
    S.station = l.station ? {
        network: l.station.network, id: l.station.station_id, name: l.station.name, lat: l.station.lat,
        lon: l.station.lon, elev: l.station.elev, distance_km: l.station.distance_km, saved: true,
    } : null;
    S.tempStation = l.station && l.station.temp_station_id ? {
        network: l.station.temp_network, id: l.station.temp_station_id, name: l.station.temp_name, lat: l.station.temp_lat,
        lon: l.station.temp_lon, elev: l.station.temp_elev, distance_km: l.station.temp_distance_km, ready: 1,
    } : null;
    S.compare = null;
    S.autoPicked = false; S.skipped = []; S.silent = {}; S.localStations = [];
    if (S.station && ((!isTempNet(S.station.network) && S.station.network !== 'local') || l.station.rain_only)) S.station.rain_only = 1;
    // the stations used for this location earlier in this session (chosen or suggested, maybe not saved)
    const mem = S.chosen[l.id];
    if (mem && mem.st) { S.station = Object.assign({}, mem.st); S.tempStation = mem.t ? Object.assign({}, mem.t) : null; }
    S.station && (S.station.ready = 1);
    S.range = num(l.station && l.station.range) || S.cfg.range;
    S.unit = (l.station && l.station.unit) || storage('unit') || S.cfg.unit;
    S.daily = null; S.dailyKey = ''; S.trialRows = null; S.years = null;
    S.lastFind = null;
    findRun++;
    setFindBusy(false);
    findStatus('', '');
    try { window.history.replaceState(null, '', '?location_id=' + l.id); } catch (e) { /* ignore */ }
    renderLocations();
    $('#wx_empty').hide();
    $('#wx_workspace').show();
    $('#wx_flash').empty();
    renderHead();
    renderRangeStep();
    renderChosen();
    $('#wx_stats').empty().hide();
    $('#wx_station_table').empty();
    $('#wx_season, #wx_trials, #wx_years').empty();
    loadTrials();
    loadLocalStations();
    if (!hasCoords(l)) {
        $('#wx_station_table').html(alertHtml('warning', 'This location has no latitude and longitude. Add them in Manage &rsaquo; <a href="/breeders/locations">Locations</a> to find the weather stations around it.'));
        drawMap();
        return;
    }
    findStations();
    showTab(S.tab);
}

function renderHead() {
    const l = S.loc;
    const meta = [
        hasCoords(l) ? '<span><span class="glyphicon glyphicon-globe"></span>' + f1(l.lat, 4) + ', ' + f1(l.lon, 4) + '</span>' : '',
        num(l.elev) !== null ? '<span><span class="glyphicon glyphicon-signal"></span>' + Math.round(l.elev) + ' m</span>' : '',
        l.type ? '<span><span class="glyphicon glyphicon-tag"></span>' + esc(l.type) + '</span>' : '',
        l.country ? '<span><span class="glyphicon glyphicon-flag"></span>' + esc(l.country) + '</span>' : '',
        l.program ? '<span><span class="glyphicon glyphicon-briefcase"></span>' + esc(l.program) + '</span>' : '',
        '<span><span class="glyphicon glyphicon-leaf"></span><a href="/search/trials?location_id=' + l.id + '">' + l.trials + ' trials</a></span>',
    ].filter(Boolean).join('');
    const linked = l.station
        ? '<div class="wx-small wx-muted" style="text-align:right">Default weather station<br><b style="color:#111827">' + esc(l.station.station_id) + '</b> ' + esc(l.station.name)
          + '<br>saved' + (l.station.saved_by_name ? ' by ' + esc(l.station.saved_by_name) : '') + ' ' + esc(l.station.saved_date || '') + '</div>'
        : '<div class="wx-small wx-muted">No default weather station yet</div>';
    const upload = S.cfg.can_upload
        ? '<div style="margin-top:6px;text-align:right"><button type="button" class="btn btn-default btn-xs" data-wx-upload-location-id="' + esc(l.id) + '" data-wx-upload-location-name="' + esc(l.name)
          + '" title="Upload a CSV or Excel file with the observations of the weather station of this farm"><span class="glyphicon glyphicon-upload"></span> Upload local station data</button></div>'
        : '';
    $('#wx_head').html('<div class="wx-head-main"><div><h3>' + esc(l.name) + (l.abbreviation ? ' <small>' + esc(l.abbreviation) + '</small>' : '')
        + '</h3><div class="wx-head-meta">' + meta + '</div></div><div>' + linked + upload + '</div></div>');
}

function loadTrials() {
    const seq = S.seq;
    $('#wx_trial').html('<option value="">Use the season of a trial...</option>');
    call('GET', API + '/trials', { location_id: S.loc.id }).then(r => {
        if (seq !== S.seq) return;
        S.trialsAll = r.trials || [];
        S.trials = S.trialsAll.filter(t => t.planting);
        const none = (r.trials || []).length - S.trials.length;
        $('#wx_trial').html('<option value="">' + (S.trials.length ? 'Use the season of a trial (' + S.trials.length + ')...' : 'No trial here has a planting date') + '</option>'
            + S.trials.map(t => '<option value="' + t.id + '">' + esc(t.name) + ' · ' + esc(t.planting) + ' → ' + esc(t.harvest || 'no harvest date') + '</option>').join(''))
            .prop('disabled', !S.trials.length)
            .attr('title', none ? none + ' trial(s) of this location have no planting date' : '');
        // opened from a trial page (?trial_id=): use the season of that trial
        if (S.pendingTrial) {
            const t = S.trials.find(x => String(x.id) === String(S.pendingTrial));
            const any = S.trialsAll.find(x => String(x.id) === String(S.pendingTrial));
            S.pendingTrial = null;
            if (t) { $('#wx_trial').val(t.id); useTrialSeason(t); }
            else if (any) flash('info', esc(any.name) + ' has no planting date: choose the dates of its season in step 3.');
        }
    }).catch(() => {});
}

// ---------------------------------------------------------------- step 1: range
function renderRangeStep() {
    $('#wx_range').val(S.range);
    $('#wx_unit button').each(function () { $(this).toggleClass('on', $(this).data('unit') === S.unit); });
    const maxKm = S.cfg.max_range_km;
    $('#wx_range').attr('title', 'Distance around the location. Up to ' + (S.unit === 'mi' ? Math.floor(maxKm / KM_PER_MI) + ' miles' : maxKm + ' km')
        + ', default ' + S.cfg.range + ' ' + (S.cfg.unit === 'mi' ? 'miles' : 'km') + '.');
    $('#wx_range_title').text(S.range + ' ' + (S.unit === 'mi' ? 'miles' : 'km'));
}

// ---------------------------------------------------------------- step 1: search status (running / done / failed / out of date)
const SPIN = '<span class="glyphicon glyphicon-refresh wx-spin"></span>';
let findTimer = null;
let findRun = 0;
function findStatus(kind, html) {
    $('#wx_find_status').attr('class', 'wx-find-status' + (kind ? ' ' + kind : '')).html(html || '');
}
function setFindBusy(busy) {
    if (findTimer) { clearInterval(findTimer); findTimer = null; }
    $('#wx_find').prop('disabled', busy)
        .html(busy ? SPIN + ' Searching...' : '<span class="glyphicon glyphicon-search"></span> Find stations');
}
function rangeText(range, unit) { return range + ' ' + (unit === 'mi' ? 'miles' : 'km'); }
function clockNow() { return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }

// tell the user when the typed range differs from the one the list was found with
function checkRangeStale() {
    const last = S.lastFind;
    if (!last || findTimer) return;
    const r = num($('#wx_range').val());
    if (r && (r !== last.range || S.unit !== last.unit)) {
        findStatus('stale', '<span class="glyphicon glyphicon-exclamation-sign"></span> Range changed: press <b>Find stations</b>.');
    }
    else findStatus(last.kind, last.html);
}

function findStations() {
    const range = num($('#wx_range').val());
    if (!range || range <= 0) { findStatus('err', 'Type a distance range first.'); return; }
    S.range = range;
    renderRangeStep();
    const seq = S.seq;
    const run = ++findRun;
    const t0 = Date.now();
    const label = rangeText(S.range, S.unit);
    $('#wx_n_stations').text('');
    $('#wx_station_table').html(loading('Looking for weather stations within ' + label + '...'));
    $('#wx_step1').addClass('on');
    setFindBusy(true);
    const tick = () => findStatus('run', SPIN + ' Searching within ' + esc(label) + '... ' + Math.round((Date.now() - t0) / 1000) + ' s (up to ~20 s)');
    tick();
    findTimer = setInterval(tick, 1000);
    const secs = () => Math.max(1, Math.round((Date.now() - t0) / 1000));
    call('GET', API + '/nearby', { location_id: S.loc.id, range: S.range, unit: S.unit }).then(r => {
        if (seq !== S.seq || run !== findRun) return;
        const list = r.stations || [];
        const nWarn = (r.warnings || []).length;
        let kind, html;
        if (list.length) {
            const byNet = {};
            list.forEach(s => { byNet[s.network] = (byNet[s.network] || 0) + 1; });
            kind = 'done';
            const detail = Object.keys(byNet).map(n => byNet[n] + ' ' + netName(n)).join(', ') + ' · updated ' + clockNow() + ' (' + secs() + ' s)'
                + (nWarn ? ' · ' + nWarn + ' source' + (nWarn === 1 ? '' : 's') + ' did not answer' : '');
            html = '<span title="' + esc(detail) + '"><span class="glyphicon glyphicon-ok"></span> <b>' + list.length + ' station' + (list.length === 1 ? '' : 's') + '</b> within ' + esc(label)
                + (nWarn ? ' <span class="glyphicon glyphicon-warning-sign"></span>' : '') + '</span> · <a data-goto-tab="sources">map</a>';
        }
        else {
            kind = 'empty';
            html = '<span class="glyphicon glyphicon-exclamation-sign"></span> No station within ' + esc(label) + ': try a larger range'
                + (nWarn ? ' or <a id="wx_find_retry">search again</a>' : '') + '.';
        }
        S.lastFind = { range: S.range, unit: S.unit, kind, html };
        setFindBusy(false);
        findStatus(kind, html);
        S.stations = r.stations || [];
        mergeLocal();
        if (S.station) {
            const same = S.stations.find(s => stationKey(s) === stationKey(S.station));
            if (same) S.station = Object.assign(same, { saved: S.station.saved });
        }
        else if (S.stations.length) {
            // suggest the nearest station that measures rain amounts, else the nearest readable one
            const first = autoCandidates()[0];
            if (first) { S.station = first; S.autoPicked = true; }
        }
        if (S.tempStation) {
            const same = S.stations.find(s => stationKey(s) === stationKey(S.tempStation));
            if (same) S.tempStation = same;
        }
        suggestTempStation();
        $('#wx_n_stations').text(S.stations.length);
        renderNetFilter();
        renderStations();
        drawMap();
        renderChosen();
        const warn = (r.warnings || []).map(esc).join('<br>');
        if (warn) $('#wx_station_table').prepend(alertHtml('warning', warn));
        if (S.station) stationChanged();
    }).catch(e => {
        if (seq !== S.seq || run !== findRun) return;
        setFindBusy(false);
        S.lastFind = null;
        findStatus('err', '<span class="glyphicon glyphicon-remove"></span> Search failed: ' + esc(e.message) + ' · <a id="wx_find_retry">try again</a>');
        $('#wx_station_table').html(alertHtml('danger', esc(e.message)));
    }).finally(() => {
        if (run === findRun) $('#wx_step1').removeClass('on');
    });
}

// ---------------------------------------------------------------- stations: list and map
function renderNetFilter() {
    const nets = [...new Set(S.stations.map(s => s.network))];
    if (nets.length < 2) { $('#wx_netfilter').empty(); S.netFilter = 'all'; return; }
    const count = n => S.stations.filter(s => n === 'all' || s.network === n).length;
    $('#wx_netfilter').html(['all'].concat(nets).map(n => '<button class="wx-seg' + (S.netFilter === n ? ' on' : '') + '" data-net="' + n + '">'
        + (n === 'all' ? 'All' : netName(n)) + '<span class="wx-count">' + count(n) + '</span></button>').join(''));
}

function renderStations() {
    const list = S.stations.filter(s => S.netFilter === 'all' || s.network === S.netFilter);
    if (!list.length) {
        $('#wx_station_table').html('<div class="wx-empty-card"><span class="glyphicon glyphicon-search"></span><h4>No weather station within '
            + S.range + ' ' + (S.unit === 'mi' ? 'miles' : 'km') + '</h4><p>Try a larger distance range.</p></div>');
        return;
    }
    const elev = num(S.loc.elev);
    const keyOff = [...new Set(list.filter(s => !s.ready && s.network !== 'local').map(s => s.network))];
    const rowOf = s => {
        const m = s.latest || {};
        const de = elev !== null && num(s.elev) !== null ? Math.round(s.elev - elev) : null;
        let now;
        if (s.network === 'airport') {
            now = m.time ? f1(toT(m.temp_c), 0) + ' ' + tUnit() + ' · ' + (m.rh !== null && m.rh !== undefined ? m.rh + '% · ' : '') + (m.wind_kmh !== null && m.wind_kmh !== undefined ? m.wind_kmh + ' km/h' : '') + ' <span class="wx-muted wx-small">' + ago(m.time) + '</span> <span class="wx-muted wx-small" title="Airports here report rain hours, not millimetres">· no rain mm</span>' : '<span class="wx-muted">no recent report</span>';
        }
        else if (s.network === 'cemaden') {
            now = m.time ? 'rain 24 h: <b>' + f1(m.rain_24h) + '</b> mm · 96 h: ' + f1(m.rain_96h) + ' mm <span class="wx-muted wx-small">' + ago(m.time) + '</span>' : '<span class="wx-muted">no recent value</span>';
        }
        else if (s.network === 'ana') {
            now = '<span class="wx-muted">rain gauge' + (s.operator ? ' · ' + esc(s.operator) : '') + (s.river ? ' · river ' + esc(s.river) : '') + '</span>';
        }
        else if (s.network === 'synop') {
            now = '<span class="wx-muted">WMO ' + esc(s.id) + (s.country ? ' · ' + esc(s.country) : '') + '</span>';
        }
        else if (s.network === 'cocorahs') {
            now = '<span class="wx-muted">volunteer rain gauge, read every morning</span>';
        }
        else if (s.network === 'local') {
            now = '<span class="wx-muted">uploaded data · ' + esc(s.first || '') + ' to ' + esc(s.last || '') + ' (' + (s.days || 0) + ' days)</span>';
        }
        else if (s.network !== 'ideam' && s.network !== 'inmet' && Array.isArray(s.measures) && s.ready) {
            now = '<span class="wx-muted">' + (s.rain_only ? 'rain gauge' : 'climate station') + ' · daily values' + (s.since ? ' since ' + esc(String(s.since).slice(0, 4)) : '') + '</span>';
        }
        else if (s.network === 'ideam') {
            now = '<span class="wx-muted">automatic rain gauge' + (s.last ? ' · last value ' + esc(String(s.last).slice(0, 16).replace('T', ' ')) : '') + '</span>';
        }
        else {
            now = s.ready ? '<span class="wx-muted">' + esc(s.status || '') + '</span>' : '<span class="wx-muted" title="Set ' + esc(netConf(s.network).key_config || '') + ' in the configuration">needs a ' + esc(netName(s.network)) + ' key</span>';
        }
        const measures = (s.network === 'local' || Array.isArray(s.measures)) ? (s.measures || []).join(' · ') : s.network === 'airport' ? 'temp · rain hours' + (s.country === 'US' ? ' · rain' : '') : s.network === 'inmet' ? 'temp · rain · radiation' : s.network === 'synop' ? 'temp · rain (when sent)' : 'rain';
        const on = stationKey(s) === stationKey(S.station);
        return '<tr class="' + (on ? 'on' : '') + '" data-skey="' + esc(stationKey(s)) + '">'
            + '<td>' + netLabel(s.network) + '</td>'
            + '<td><b>' + esc(s.network === 'cemaden' ? s.code || s.id : s.network === 'hilltop' ? '' : s.id) + '</b> ' + esc(s.network === 'cemaden' ? String(s.name).replace(/^.*\(/, '(') : s.name) + (s.state ? ' <span class="wx-muted">' + esc(s.state) + '</span>' : '') + '<div class="wx-small wx-muted">' + measures + '</div></td>'
            + '<td class="n">' + (s.approx_position ? '<span title="Position not published: distance to the centre of the municipality">≈ </span>' : '') + dist(s.distance_km) + ' <span class="wx-muted wx-small">' + esc(s.direction) + '</span></td>'
            + '<td class="n">' + (num(s.elev) !== null ? Math.round(s.elev) + ' m' : '–') + (de !== null ? ' <span class="wx-muted wx-small">(' + (de > 0 ? '+' : '') + de + ')</span>' : '') + '</td>'
            + '<td>' + now + '</td>'
            + '<td class="n">' + (on ? '<span class="wx-pill wx-pill-st"><span class="glyphicon glyphicon-ok"></span> chosen</span>'
                : '<button class="btn btn-default btn-xs" data-choose="' + esc(stationKey(s)) + '"' + (s.ready ? '' : ' disabled') + '>Choose</button>') + '</td></tr>';
    };
    // uploaded stations (of the location first) in their own section, then the public stations
    const sep = t => '<tr class="wx-sep"><td colspan="6">' + t + '</td></tr>';
    const up = list.filter(x => x.network === 'local').sort((a, b) => (isOwnLocal(b) - isOwnLocal(a)) || (a.distance_km - b.distance_km));
    const pub = list.filter(x => x.network !== 'local');
    const rows = (up.length ? sep('Uploaded stations') + up.map(rowOf).join('') + (pub.length ? sep('Public stations') : '') : '') + pub.map(rowOf).join('');
    $('#wx_station_table').html(keyOff.map(n => alertHtml('info', esc(netName(n)) + ' stations are listed, but reading their data needs a free key: get one at '
        + (netConf(n).key_url ? '<a href="' + esc(netConf(n).key_url) + '" target="_blank" rel="noopener">' + esc(netConf(n).key_url) + '</a>' : 'the provider') + ' and set <code>' + esc(netConf(n).key_config || n + '_api_key') + '</code> in sgn_local.conf.')).join('')
        + (list.some(s => s.approx_position) ? '<p class="wx-note">≈ CEMADEN does not publish the position of its gauges: the distance is to the centre of their municipality.</p>' : '')
        + '<div class="wx-table-wrap"><table class="table table-condensed table-hover wx-table"><thead><tr><th>Network</th><th>Station</th><th class="n">Distance</th><th class="n">Elevation (vs. location)</th><th>Now</th><th></th></tr></thead><tbody>'
        + rows + '</tbody></table></div>');
}

function drawMap() {
    const L = window.L;
    if (!L || !document.getElementById('wx_map')) return;
    if (!S.map) {
        // a first view: Leaflet adds layers only to a map that has one (the tab may still be hidden)
        S.map = L.map('wx_map', { scrollWheelZoom: false }).setView([0, 0], 2);
        L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}', {
            attribution: 'Tiles &copy; Esri', maxZoom: 17,
        }).addTo(S.map);
        S.mapLayers = L.layerGroup().addTo(S.map);
    }
    S.mapLayers.clearLayers();
    const l = S.loc;
    if (!hasCoords(l)) { S.mapBounds = null; S.map.setView([0, 0], 2); $('#wx_map_legend').empty(); return; }
    const center = [Number(l.lat), Number(l.lon)];
    const rkm = S.unit === 'mi' ? S.range * KM_PER_MI : S.range;
    L.circle(center, { radius: rkm * 1000, color: '#1d6fa5', weight: 1.5, fillOpacity: 0.04, dashArray: '4 4' }).addTo(S.mapLayers);
    const tip = s => '<b>' + esc(s.id) + '</b> ' + esc(s.name) + '<br>' + dist(s.distance_km) + ' ' + esc(s.direction)
        + (s.latest && s.latest.temp_c !== null && s.latest.temp_c !== undefined ? '<br>' + fmtT(s.latest.temp_c, 0) + ' ' + ago(s.latest.time) : '');
    let chosen = null;
    S.stations.forEach(s => {
        if (stationKey(s) === stationKey(S.station)) { chosen = s; return; }
        // the other stations: small and grey, so that only the location and the chosen station stand out
        L.circleMarker([s.lat, s.lon], {
            radius: 4, color: '#fff', weight: 1, fillColor: '#64748b', fillOpacity: s.ready ? 0.75 : 0.3,
        }).bindTooltip(tip(s) + (s.ready ? '<br><i>click to choose it</i>' : ''))
            .on('click', () => { if (s.ready) chooseStation(stationKey(s)); })
            .addTo(S.mapLayers);
    });
    L.circleMarker(center, { radius: 9, color: '#fff', weight: 3, fillColor: '#dc2626', fillOpacity: 1 })
        .bindTooltip('<b>' + esc(l.name) + '</b> (research station)', { permanent: false }).addTo(S.mapLayers);
    // the chosen weather station: a golden star, drawn last so it stays on top
    if (!chosen && S.station && num(S.station.lat) !== null && num(S.station.lon) !== null) chosen = S.station;
    if (chosen) {
        L.marker([chosen.lat, chosen.lon], { icon: L.divIcon({ className: 'wx-star-icon', html: STAR_SVG, iconSize: [30, 30], iconAnchor: [15, 16] }), zIndexOffset: 1000, keyboard: false })
            .bindTooltip('<b>Chosen weather station</b><br>' + tip(chosen), { offset: [0, -8] }).addTo(S.mapLayers);
    }
    renderMapLegend(chosen);
    // from the centre and the radius: circle.getBounds() needs a map already drawn
    S.mapBounds = L.latLng(center).toBounds(rkm * 2000);
    fitMap();
}

const STAR_SVG = '<svg viewBox="0 0 24 24" width="30" height="30" aria-hidden="true"><path d="M12 1.8l3.1 6.6 7.2.9-5.3 5 1.4 7.1L12 17.9l-6.4 3.5 1.4-7.1-5.3-5 7.2-.9z" fill="#f5b400" stroke="#7a5200" stroke-width="1.2" stroke-linejoin="round"/></svg>';

// what the symbols of the map mean
function renderMapLegend(chosen) {
    $('#wx_map_legend').html(
        '<span><i class="wx-lg-dot wx-lg-loc"></i>Location: ' + esc(S.loc.name) + '</span>'
        + (chosen ? '<span><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path d="M12 1.8l3.1 6.6 7.2.9-5.3 5 1.4 7.1L12 17.9l-6.4 3.5 1.4-7.1-5.3-5 7.2-.9z" fill="#f5b400" stroke="#7a5200" stroke-width="1.5"/></svg>Weather station: ' + esc(stationLabel(chosen)) + '</span>' : '')
        + (S.stations.length > (chosen ? 1 : 0) ? '<span><i class="wx-lg-dot wx-lg-other"></i>Other weather stations (click one to choose it)</span>' : '')
        + '<span><i class="wx-lg-ring"></i>Search range (' + esc(rangeText(S.range, S.unit)) + ')</span>');
}

// Leaflet cannot size a map in a hidden tab (0 x 0 px): the view is set when the Data sources tab is visible
function fitMap() {
    if (!S.map) return;
    setTimeout(() => {
        const el = document.getElementById('wx_map');
        if (!el || !el.offsetWidth || !el.offsetHeight) return;    // hidden: showTab('sources') calls again
        S.map.invalidateSize();
        if (S.mapBounds) S.map.fitBounds(S.mapBounds, { padding: [10, 10] });
        else S.map.setView([0, 0], 2);
    }, 50);
}

function chooseStation(key) {
    const s = S.stations.find(x => stationKey(x) === key);
    if (!s) return;
    S.autoPicked = false;
    S.skipped = [];
    S.station = Object.assign(s, { saved: S.loc.station && (S.loc.station.network + ':' + S.loc.station.station_id) === key });
    suggestTempStation();
    renderStations();
    drawMap();
    renderChosen();
    stationChanged();
}

// a rain-only gauge needs a second station for temperature and ET0: the nearest airport / INMET with data
function suggestTempStation() {
    if (!S.station || !S.station.rain_only) return;
    if (S.tempStation && measuresTemp(S.tempStation)) return;
    if (S.tempStation && S.tempStation.ready && !S.stations.length) return;
    const t = S.stations.find(s => measuresTemp(s) && (s.network !== 'airport' || s.latest)) || S.stations.find(measuresTemp);
    S.tempStation = t || null;
}

function stationChanged() {
    S.daily = null; S.dailyKey = ''; S.trialRows = null; S.years = null;
    if (S.tab !== 'sources' && S.tab !== 'locations') showTab(S.tab);
}

// ---------------------------------------------------------------- step 2: chosen station
// the data a station gives (from its network: no request needed)
function dataTypes(x) {
    if (x.network === 'local' || Array.isArray(x.measures)) return (x.measures && x.measures.length) ? x.measures : ['rain'];
    if (x.network === 'inmet') return ['temperature', 'rain', 'radiation', 'humidity', 'wind'];
    if (x.network === 'synop') return ['temperature', 'rain', 'humidity', 'wind'];
    if (x.network === 'airport') return x.country === 'US' ? ['temperature', 'rain', 'humidity', 'wind'] : ['temperature', 'humidity', 'wind'];
    return ['rain'];
}
const isSilent = x => !!(S.silent || {})[stationKey(x) + '|' + S.start + '|' + S.end];

// drop-down of every station found: the farm's own uploaded stations first, then the others nearest first;
// the readable one(s) with the most data types are marked
function stationSelectHtml() {
    const opts = S.stations.filter(isOwnLocal).concat(S.stations.filter(x => !isOwnLocal(x)));
    if (S.station && !opts.some(x => stationKey(x) === stationKey(S.station))) opts.unshift(S.station);
    if (!opts.length) {
        return '<div class="wx-small wx-muted">' + (S.lastFind ? 'No station within the range.' : 'Find the stations first.')
            + (S.cfg.can_upload ? ' <a href="#" data-wx-upload-location-id="' + esc(S.loc.id) + '" data-wx-upload-location-name="' + esc(S.loc.name) + '">Upload the farm station data</a>' : '') + '</div>';
    }
    const readable = x => x.network === 'local' || x.ready;
    const usable = opts.filter(x => readable(x) && !isSilent(x));
    const most = usable.length ? Math.max(...usable.map(x => dataTypes(x).length)) : 0;
    const best = x => readable(x) && !isSilent(x) && dataTypes(x).length === most && most > 1;
    const note = x => (!readable(x) ? ' - not readable' : isSilent(x) ? ' - no data for these dates' : x.network === 'airport' && !x.latest ? ' - no recent report' : '');
    const label = x => isOwnLocal(x) ? 'Farm station · ' + x.name
        : x.network === 'local' ? dist(x.distance_km) + ' · Uploaded · ' + x.name + (x.location_name ? ' (' + x.location_name + ')' : '')
        : dist(x.distance_km) + ' · ' + netName(x.network) + ' ' + stationLabel(x);
    return '<select class="form-control input-sm" id="wx_station_select" style="width:100%" title="Nearest first. ✔ = the most types of data">'
        + (S.station ? '' : '<option value="">Choose a weather station...</option>')
        + opts.map(x => '<option value="' + esc(stationKey(x)) + '"' + (best(x) ? ' style="font-weight:bold"' : '')
            + (stationKey(x) === stationKey(S.station) ? ' selected' : '') + (readable(x) ? '' : ' disabled') + '>'
            + esc((best(x) ? '✔ ' : '') + label(x) + ': ' + dataTypes(x).join(', ') + (best(x) ? ' (most data)' : '') + note(x)
                + (stationKey(x) === savedKey() ? ' - default' : '')) + '</option>').join('')
        + '</select>';
}

function renderChosen() {
    const s = S.station;
    if (!s) {
        $('#wx_chosen').html(stationSelectHtml());
        return;
    }
    const inRange = !S.stations.length || S.stations.some(x => stationKey(x) === stationKey(s));
    const where = isOwnLocal(s) ? 'at this location'
        : dist(s.distance_km) + (s.direction ? ' ' + esc(s.direction) : '');
    const meta = '<div class="wx-st-meta"><span>' + where + (num(s.elev) !== null ? ' · elev. ' + Math.round(s.elev) + ' m' : '')
        + (inRange ? '' : ' · <span style="color:#92400e">outside the range</span>') + '</span></div>';
    let temp = '';
    if (s.rain_only) {
        const opts = S.stations.filter(measuresTemp);
        if (S.tempStation && !opts.some(x => stationKey(x) === stationKey(S.tempStation))) opts.unshift(S.tempStation);
        temp = '<div class="wx-st-temp">Rain gauge only: temperature and ET0 from'
            + '<select class="form-control input-sm" id="wx_temp_station"><option value="">(none)</option>'
            + opts.map(x => '<option value="' + esc(stationKey(x)) + '"' + (stationKey(x) === stationKey(S.tempStation) ? ' selected' : '') + '>' + esc(dist(x.distance_km) + ' · ' + netName(x.network) + ' ' + x.id + ' ' + x.name) + '</option>').join('')
            + '</select></div>';
    }
    $('#wx_chosen').html(stationSelectHtml() + meta + temp + defaultHtml(s));
}

// the default weather station of the research location: opened with the page and used on its trial pages
function savedKey() { return S.loc.station ? S.loc.station.network + ':' + S.loc.station.station_id : ''; }
function defaultHtml(s) {
    const d = S.loc.station;
    const isLinked = savedKey() === stationKey(s);
    const tempNow = (s.rain_only && S.tempStation) ? String(S.tempStation.id).toUpperCase() : '';
    const same = isLinked && Number(d.range) === Number(S.range) && d.unit === S.unit && (d.temp_station_id || '') === tempNow;
    const canSave = S.cfg.can_save;
    const two = !!tempNow;
    const savedName = d ? netName(d.network) + ' ' + (d.network === 'local' ? (d.name || '') : d.station_id)
        + (d.temp_station_id ? ' + temperature from ' + d.temp_station_id : '') : '';
    let text, btn = '';
    if (same) {
        text = '<span class="glyphicon glyphicon-ok" style="color:var(--wx-green)"></span> ' + (two ? 'These are' : 'This is') + ' the default of <b>' + esc(S.loc.name) + '</b>';
        if (canSave) btn = '<button class="btn btn-link btn-xs" id="wx_clear" style="padding:0">remove</button>';
    }
    else {
        text = !d ? '<b>' + esc(S.loc.name) + '</b> has no default station yet'
            : isLinked ? 'Default of <b>' + esc(S.loc.name) + '</b>: this station, saved with ' + ((d.temp_station_id || '') !== tempNow ? 'another temperature station' : 'another search area')
            : 'Default of <b>' + esc(S.loc.name) + '</b>: ' + esc(savedName);
        if (canSave) {
            btn = '<button class="btn btn-success btn-xs" id="wx_save"><span class="glyphicon glyphicon-floppy-disk"></span> '
                + (isLinked ? 'Update the default' : d ? 'Replace with ' + (two ? 'the selected ones' : 'the selected one') : 'Make ' + (two ? 'them' : 'it') + ' the default') + '</button>';
        }
    }
    return '<div class="wx-default" title="The default weather station opens automatically for ' + esc(S.loc.name) + ' and is used on the trial pages of this location.'
        + (canSave ? '' : ' Only curators and submitters can change it.') + '"><span>' + text + '</span>' + (btn ? '<span>' + btn + '</span>' : '') + '</div>';
}

function saveStation() {
    const s = S.station;
    $('#wx_save').prop('disabled', true);
    call('POST', API + '/save_station', {
        location_id: S.loc.id, network: s.network, station_id: s.id, name: s.name, lat: s.lat, lon: s.lon,
        elev: s.elev, distance_km: s.distance_km, range: S.range, unit: S.unit, rain_only: s.rain_only ? 1 : 0,
        ...(s.rain_only && S.tempStation ? {
            temp_network: S.tempStation.network, temp_station_id: S.tempStation.id, temp_name: S.tempStation.name, temp_lat: S.tempStation.lat,
            temp_lon: S.tempStation.lon, temp_elev: S.tempStation.elev, temp_distance_km: S.tempStation.distance_km,
        } : {}),
    }).then(r => {
        S.loc.station = r.station;
        s.saved = true;
        flash('success', '<b>' + esc(s.id) + '</b> is now the default weather station of ' + esc(S.loc.name) + '.');
        renderHead(); renderChosen(); renderLocations();
    }).catch(e => { flash('danger', esc(e.message)); $('#wx_save').prop('disabled', false); });
}

function clearStation() {
    if (!window.confirm('Remove the weather station of ' + S.loc.name + '?')) return;
    call('POST', API + '/clear_station', { location_id: S.loc.id }).then(() => {
        S.loc.station = null;
        renderHead(); renderChosen(); renderLocations();
    }).catch(e => flash('danger', esc(e.message)));
}


// ---------------------------------------------------------------- stat tiles
function tile(label, value, unit, sub, cls) {
    return '<div class="wx-stat' + (cls ? ' ' + cls : '') + '"><div class="l">' + label + '</div><div class="v">' + value + (unit ? '<small>' + unit + '</small>' : '') + '</div>'
        + (sub ? '<div class="s">' + sub + '</div>' : '') + '</div>';
}
const sign = v => (v > 0 ? '+' : '') + v.toFixed(0);

function seasonTiles(x) {
    const t = [];
    if (x.rain !== null) {
        t.push(tile('Rain', f1(x.rain, 0), 'mm', x.rainyDays + ' rainy days'));
        if (x.balance !== null) t.push(tile('Water balance', sign(x.balance), 'mm', 'rain − ET0', x.balance < -50 ? 'wx-stat-bad' : x.balance < 0 ? 'wx-stat-warn' : 'wx-stat-good'));
        t.push(tile('Longest dry spell', x.dry ? x.dry.days : '–', 'days', x.dry && x.dry.days ? shortDate(x.dry.start) + '–' + shortDate(x.dry.end) : '', x.dry && x.dry.days >= S.p.dry ? 'wx-stat-warn' : ''));
    }
    else t.push(tile('Rain hours', x.rainHours, 'h', 'this station gives no mm'));
    if (x.et0 !== null) t.push(tile('ET0', f1(x.et0, 0), 'mm', 'crop water demand (reference)'));
    if (x.gdd !== null) t.push(tile('Degree-days', f1(toDD(x.gdd), 0), ddUnit(), 'base ' + fmtTh(S.p.base)));
    if (x.hasTemp) {
        t.push(tile('Mean max / min', f1(toT(x.tmax)) + ' / ' + f1(toT(x.tmin)), tUnit(), 'from ' + fmtT(x.absMin) + ' to ' + fmtT(x.absMax)));
        t.push(tile('Heat days', x.heat, '', 'max ≥ ' + fmtTh(S.p.heat), x.heat ? 'wx-stat-bad' : ''));
        t.push(tile('Frost days', x.frost, '', 'min ≤ ' + fmtTh(S.p.frost), x.frost ? 'wx-stat-bad' : ''));
    }
    t.push(tile('Days observed', Math.round(100 * x.coverage), '%', x.withData + ' of ' + x.days, x.coverage < 0.8 ? 'wx-stat-warn' : ''));
    return t;
}

// ---------------------------------------------------------------- tabs
function needStation(el) {
    if (S.station) return false;
    $(el).html('<div class="wx-empty-card"><span class="glyphicon glyphicon-map-marker"></span><h4>Choose a weather station first</h4><p>Step 2: find the stations around the location and choose one (Data sources tab).</p></div>');
    return true;
}

function showTab(tab) {
    S.tab = tab;
    $('.wx-tab').each(function () { $(this).toggleClass('on', $(this).data('tab') === tab); });
    $('.wx-pane').each(function () { $(this).toggle($(this).data('pane') === tab); });
    if (tab === 'sources') fitMap();
    if (!S.loc || !hasCoords(S.loc)) return;
    if (tab === 'season') loadSeason();
    if (tab === 'trials') loadTrialsTab();
    if (tab === 'years') renderYearsIntro();
    if (tab === 'locations') renderLocationsTab();
    if (tab === 'sources') loadCompare();
}

// ---------------------------------------------------------------- step 3: season
function applyPreset(p) {
    S.preset = p;
    const today = S.cfg.today || iso(new Date());
    if (p === 'year') { S.start = today.slice(0, 4) + '-01-01'; S.end = today; }
    else if (p === 'lastyear') { const y = Number(today.slice(0, 4)) - 1; S.start = y + '-01-01'; S.end = y + '-12-31'; }
    else { S.start = addDays(today, -(Number(p) - 1)); S.end = today; }
    if (!S.plantingSet) S.planting = S.start;
    renderDates();
}

// dates are shown and typed as YYYY-MM-DD (a native date input follows the browser locale)
const isIsoDate = v => /^\d{4}-\d{2}-\d{2}$/.test(v || '') && !isNaN(Date.parse(v));
function setDateInput(sel, v) {
    $(sel).val(v || '');
    const dp = $(sel).data('daterangepicker');
    if (dp && isIsoDate(v)) { dp.setStartDate(v); dp.setEndDate(v); }
}
function initDatePickers() {
    if (!$.fn.daterangepicker) return;
    $('#wx_start, #wx_end, #wx_planting').each(function () {
        $(this).daterangepicker({ singleDatePicker: true, showDropdowns: true, autoUpdateInput: false, locale: { format: 'YYYY-MM-DD' } })
            .on('apply.daterangepicker', function (e, picker) { $(this).val(picker.startDate.format('YYYY-MM-DD')).trigger('change'); });
    });
}

function renderDates() {
    setDateInput('#wx_start', S.start);
    setDateInput('#wx_end', S.end);
    setDateInput('#wx_planting', S.planting);
    $('#wx_presets .wx-seg').each(function () { $(this).toggleClass('on', String($(this).data('preset')) === String(S.preset)); });
}

function applyDates() {
    const a = $('#wx_start').val(), b = $('#wx_end').val();
    let pl = $('#wx_planting').val() || a;
    if (!a || !b) { flash('warning', 'Choose the start and the end date.'); return; }
    if (!isIsoDate(a) || !isIsoDate(b)) { flash('warning', 'Write the dates as YYYY-MM-DD.'); return; }
    if (!isIsoDate(pl)) pl = a;
    if (a > b) { flash('warning', 'The start date must be before the end date.'); return; }
    const n = daysBetween(a, b);
    if (n > S.cfg.max_days) { flash('warning', 'The period has ' + n + ' days; the limit is ' + S.cfg.max_days + ' days.'); return; }
    if (pl < a || pl > b) { pl = a; S.plantingSet = false; }
    S.start = a; S.end = b; S.planting = pl;
    S.years = null;
    renderDates();
    $('#wx_flash').empty();
    showTab(S.tab === 'trials' ? 'season' : S.tab);
}

// ---------------------------------------------------------------- data
// OGIMET (SYNOP) accepts one slow query every 20 s per server: SYNOP requests go one at a time,
// and wait when OGIMET asks to
let synopQueue = Promise.resolve();
const sleep = ms => new Promise(r => setTimeout(r, ms));
function getDaily(st, start, end, locId, tries) {
    const data = { location_id: locId || S.loc.id, network: st.network, station: st.id, start, end, lat: st.lat, lon: st.lon, elev: st.elev };
    return call('GET', API + '/daily', data).catch(e => {
        if (/quota|every 20 seconds/i.test(e.message) && (tries || 0) < 3) return sleep(21000).then(() => getDaily(st, start, end, locId, (tries || 0) + 1));
        throw e;
    });
}
function fetchDaily(st, start, end, locId) {
    const key = [stationKey(st), start, end].join('|');
    if (!S.cache[key]) {
        if (st.network === 'synop') {
            S.cache[key] = synopQueue.then(() => getDaily(st, start, end, locId));
            synopQueue = S.cache[key].catch(() => null);
        }
        else S.cache[key] = getDaily(st, start, end, locId);
        S.cache[key].catch(() => { delete S.cache[key]; });
    }
    return S.cache[key];
}

// rain from the rain gauge, temperature / humidity / radiation / ET0 from the temperature station
function mergeDaily(rain, temp, tst) {
    const tby = {};
    (temp.days || []).forEach(d => { tby[d.date] = d; });
    const dates = [...new Set((rain.days || []).map(d => d.date).concat((temp.days || []).map(d => d.date)))].sort();
    const rby = {};
    (rain.days || []).forEach(d => { rby[d.date] = d; });
    const days = dates.map(date => {
        const r = rby[date] || { date, rain: null, rain_hours: null, complete: 0 };
        const t = tby[date] || {};
        return Object.assign({}, r, {
            tmax: t.tmax, tmin: t.tmin, tmean: t.tmean, rh: t.rh, radiation: t.radiation, et0: t.et0, et0_method: t.et0_method,
            wind_mean: t.wind_mean, gust_max: t.gust_max, temp_complete: t.complete,
        });
    });
    return Object.assign({}, rain, { days, temp_source: temp.source, temp_station: tst, stale: rain.stale || temp.stale });
}

// the observations of a rain station (+ its temperature station) for a period
function fetchPair(st, tst, start, end, locId) {
    const t = st.rain_only ? tst : null;
    return Promise.all([fetchDaily(st, start, end, locId), t ? fetchDaily(t, start, end, locId).catch(e => ({ error: e.message })) : null])
        .then(([r, tr]) => (tr && !tr.error ? mergeDaily(r, tr, t) : Object.assign({}, r, tr && tr.error ? { temp_error: tr.error } : {})));
}

function analysis(daily, start, end, planting) {
    const from = planting && planting > start ? planting : start;
    const days = seasonDays(daily, from, end, S.p, S.cfg.today);
    const rep = !!daily.rain_reported;
    const s = summarize(days, rep, S.p);
    const stages = cropStages(days, rep, S.p, S.crop);
    return { days, rep, s, stages, stress: stressDays(days, rep, S.p), findings: verdicts(stages, s, S.p), from };
}

// ---------------------------------------------------------------- Season (breeding view)
function loadSeason() {
    if (needStation('#wx_season')) return;
    if (!S.start) return;
    const s = S.station, t = s.rain_only ? S.tempStation : null;
    rememberChoice();
    const key = [stationKey(s), stationKey(t), S.start, S.end].join('|');
    if (S.daily && S.dailyKey === key) { renderSeason(); return; }
    const seq = S.seq;
    $('#wx_season').html(loading('Reading ' + daysBetween(S.start, S.end) + ' days of observations of ' + stationLabel(s) + (t ? ' and ' + stationLabel(t) : '') + '... (a long period can take some seconds the first time)'));
    fetchPair(s, t, S.start, S.end).then(r => {
        if (seq !== S.seq || stationKey(S.station) !== stationKey(s)) return;
        // a station the page picked by itself sent nothing (listed but silent): try the next one
        if (!hasObservations(r)) {
            // remember it: the drop-down lists it under 'Sent no observations for these dates'
            S.silent = S.silent || {};
            S.silent[stationKey(s) + '|' + S.start + '|' + S.end] = 1;
            renderChosen();
        }
        if (!hasObservations(r) && S.autoPicked && S.skipped.length < 4) {
            const next = autoCandidates().find(x => stationKey(x) !== stationKey(s));
            if (next) {
                if (S.skippedKey !== S.start + '|' + S.end) S.skipped = [];
                S.skipped.push(s);
                S.skippedKey = S.start + '|' + S.end;
                S.station = next;
                if (next.rain_only) suggestTempStation();
                renderStations(); drawMap(); renderChosen();
                $('#wx_season').html(loading(stationLabel(s) + ' sent no observations for these dates: trying ' + stationLabel(next) + ' (' + dist(next.distance_km) + ')...'));
                setTimeout(loadSeason, 0);
                return;
            }
        }
        S.daily = r;
        S.dailyKey = key;
        renderSeason();
    }).catch(e => $('#wx_season').html(alertHtml('danger', esc(e.message))));
}

// stations with a 'Choose' button, for an empty result
function alternativesHtml() {
    const alts = S.stations.filter(x => x.ready && stationKey(x) !== stationKey(S.station)).slice(0, 4);
    if (!alts.length) return '';
    return '<div class="wx-inline" style="margin-top:8px">Try: ' + alts.map(x => '<button class="btn btn-default btn-xs" data-choose="' + esc(stationKey(x)) + '">'
        + esc(netName(x.network) + ' ' + stationLabel(x) + ' · ' + dist(x.distance_km)) + '</button>').join(' ') + '</div>';
}

function stageBands(stages) {
    return stages.map(st => ({ from: new Date(st.start + 'T12:00:00').getTime(), to: new Date(st.end + 'T12:00:00').getTime(), label: st.name, critical: st.critical }));
}

function findingHtml(f) {
    const icon = { water: 'tint', dry: 'fire', heat: 'certificate', frost: 'asterisk', wet: 'cloud', undefined: 'info-sign' }[f.kind] || 'info-sign';
    return '<li class="wx-find wx-find-' + f.level + '"><span class="glyphicon glyphicon-' + icon + '"></span> <b>' + esc(f.stage) + (f.critical ? ' (critical)' : '') + ':</b> ' + esc(f.text)
        + (f.detail ? ' <span class="wx-muted">· ' + esc(f.detail) + '</span>' : '') + '</li>';
}

function issueChips(issues) {
    if (!issues || !issues.length) return '<span class="wx-flag wx-flag-spray">favourable</span>';
    return issues.map(i => '<span class="wx-flag ' + (i.level === 'bad' ? 'wx-flag-heat' : 'wx-flag-wind') + '" title="' + esc(i.detail || '') + '">' + esc(i.text) + '</span>').join(' ');
}

function renderSeason() {
    const r = S.daily;
    if (S.skippedKey !== S.start + '|' + S.end) S.skipped = [];    // skipped for other dates
    if (!hasObservations(r)) {
        $('#wx_season').html(alertHtml('warning', '<b>' + esc(stationLabel(S.station)) + ' sent no observations between ' + fmtDate(S.start) + ' and ' + fmtDate(S.end) + '.</b> '
            + 'Some stations are listed by their network but do not report, or stopped reporting. '
            + (S.skipped.length ? 'Also tried: ' + S.skipped.map(x => esc(stationLabel(x))).join(', ') + '. ' : '')
            + 'Choose another station or other dates.' + alternativesHtml()));
        $('#wx_stats').hide();
        return;
    }
    const A = analysis(r, S.start, S.end, S.planting);
    S.season = A;
    const x = A.s;
    $('#wx_stats').html(seasonTiles(x).join('')).show();
    const crop = CROPS.find(c => c.v === S.crop) || CROPS[0];
    const crit = A.stages.find(st => st.critical);
    const bands = stageBands(A.stages);
    const stageOf = date => { const st = A.stages.find(s => date >= s.start && date <= s.end); return st ? st.name : ''; };

    // findings
    const serious = A.findings.filter(f => f.level !== 'info');
    const findings = '<div class="wx-card wx-verdict ' + (serious.some(f => f.level === 'bad') ? 'bad' : serious.length ? 'warn' : 'good') + '">'
        + '<div class="wx-card-head"><h4><span class="glyphicon glyphicon-check"></span> What the season means for the crop</h4>'
        + '<span class="wx-muted wx-small">' + esc(crop.label) + ' planted ' + fmtDate(A.from) + (crit ? ' · critical stage <b>' + esc(crit.name) + '</b> ' + shortDate(crit.start) + '–' + shortDate(crit.end) : '') + '</span></div>'
        + (serious.length ? '<ul class="wx-finds">' + A.findings.map(findingHtml).join('') + '</ul>'
            : '<p class="wx-find-ok"><span class="glyphicon glyphicon-ok-circle"></span> No major stress found for ' + esc(crop.label.toLowerCase()) + ' in this period' + (x.coverage < 0.8 ? ' (but only ' + Math.round(100 * x.coverage) + '% of the days were observed)' : '') + '.</p>')
        + '<p class="wx-note">Stages are estimated from the degree-days since planting (proportions typical of ' + esc(crop.label.toLowerCase()) + '); when the trial has flowering dates, use them to read the stress at flowering.</p></div>';

    // stage table
    const rep = A.rep;
    const stageRows = A.stages.map(st => {
        const s = st.s;
        return '<tr class="' + (st.critical ? 'wx-crit' : '') + '"><td><b>' + esc(st.name) + '</b>' + (st.critical ? ' <span class="wx-pill wx-pill-warn">critical</span>' : '') + '</td>'
            + '<td style="white-space:nowrap">' + shortDate(st.start) + ' – ' + shortDate(st.end) + '</td><td class="n">' + st.days.length + '</td>'
            + '<td class="n">' + f1(toDD(s.gdd), 0) + '</td>'
            + (rep ? '<td class="n">' + f1(s.rain, 0) + '</td>' : '<td class="n">' + s.rainHours + ' h</td>')
            + '<td class="n">' + f1(s.et0, 0) + '</td>'
            + (rep ? '<td class="n ' + (s.balance !== null && s.balance < 0 ? 'wx-neg' : 'wx-pos') + '">' + (s.balance === null ? '–' : sign(s.balance)) + '</td><td class="n">' + (s.dry ? s.dry.days : '–') + '</td>' : '')
            + '<td class="n">' + f1(toT(s.tmax)) + '</td><td class="n">' + (s.heat === null ? '–' : s.heat) + '</td><td class="n">' + (s.frost === null ? '–' : s.frost) + '</td>'
            + '<td><div class="wx-flags">' + issueChips(st.issues) + '</div></td></tr>';
    }).join('');
    const stageTable = '<div class="wx-card"><div class="wx-card-head"><h4><span class="glyphicon glyphicon-tasks"></span> Crop stages</h4>'
        + '<span class="wx-muted wx-small">' + (A.stages[0] && A.stages[0].byGdd ? 'by degree-days' : 'by days (no temperature data)') + '</span></div>'
        + '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr><th>Stage</th><th>Dates</th><th class="n">Days</th><th class="n">Degree-days ' + ddUnit() + '</th>'
        + (rep ? '<th class="n">Rain mm</th>' : '<th class="n">Rain hours</th>') + '<th class="n">ET0 mm</th>' + (rep ? '<th class="n">Balance mm</th><th class="n">Longest dry spell</th>' : '')
        + '<th class="n">Mean max ' + tUnit() + '</th><th class="n">Heat days</th><th class="n">Frost days</th><th>Stress</th></tr></thead><tbody>' + stageRows + '</tbody></table></div></div>';

    // stress calendar + aligned charts
    const pts = A.days.map(d => ({
        x: new Date(d.date + 'T12:00:00').getTime(), label: d.date, short: shortDate(d.date), stage: stageOf(d.date),
        tmax: toT(d.tmax), tmin: toT(d.tmin), rain: num(d.rain), rain_hours: num(d.rain_hours), gddCum: d.gdd === null && !d.gddCum ? null : toDD(d.gddCum),
        rainCum: d.rainCum, et0Cum: num(d.et0) === null && !d.et0Cum ? null : d.et0Cum,
    }));
    const hasEt0 = x.et0 !== null;
    const charts = '<div class="wx-card"><div class="wx-card-head"><h4><span class="glyphicon glyphicon-calendar"></span> Stress calendar</h4><span class="wx-muted wx-small">heat ≥ ' + fmtTh(S.p.heat) + ' · frost ≤ ' + fmtTh(S.p.frost) + ' · dry spell ≥ ' + S.p.dry + ' days under 1 mm · heavy rain ≥ ' + S.p.heavy + ' mm</span></div>'
        + '<div class="wx-chart" id="wx_c_stress"></div>'
        + (x.hasTemp ? '<div class="wx-sub">Daily maximum and minimum temperature (' + tUnit() + ')</div><div class="wx-legend"><span><i style="background:' + COLORS.tmax + '"></i>Maximum</span><span><i style="background:' + COLORS.tmin + '"></i>Minimum</span></div><div class="wx-chart" id="wx_c_temp"></div>' : '')
        + '<div class="wx-sub">' + (rep ? 'Daily rain (mm)' : 'Hours with rain per day (this station gives no mm)') + '</div><div class="wx-chart" id="wx_c_rain"></div>'
        + (rep || hasEt0 ? '<div class="wx-sub">' + (rep && hasEt0 ? 'Water: accumulated rain against accumulated crop water demand (ET0), mm' : rep ? 'Accumulated rain (mm)' : 'Accumulated ET0 (mm)') + '</div>'
            + (rep && hasEt0 ? '<div class="wx-legend"><span><i style="background:' + COLORS.rain + '"></i>Rain</span><span><i style="background:' + COLORS.et0 + '"></i>ET0 (the gap is the water deficit)</span></div>' : '') + '<div class="wx-chart" id="wx_c_water"></div>' : '')
        + (x.gdd !== null ? '<div class="wx-sub">Accumulated degree-days (' + ddUnit() + ', base ' + fmtTh(S.p.base) + ')</div><div class="wx-chart" id="wx_c_gdd"></div>' : '')
        + '<p class="wx-note">The shaded band is the critical stage. Hover the charts to read each day.</p></div>';

    const notes = [
        S.skipped.length ? '<span class="glyphicon glyphicon-random"></span>' + S.skipped.map(x => esc(stationLabel(x))).join(', ') + ' (nearer) sent no observations for these dates, so ' + esc(stationLabel(S.station)) + ' is used.' : '',
        '<span class="glyphicon glyphicon-info-sign"></span><b>Data:</b> ' + esc(r.source) + (r.temp_source ? '; temperature and ET0: ' + esc(r.temp_source) : '') + '. ' + esc(r.note || ''),
        r.rain_reported ? '' : '<span class="glyphicon glyphicon-tint"></span>This station gives rain hours, not millimetres: water balance and dry spells need a rain gauge (Data sources).',
        x.coverage < 0.8 ? '<span class="glyphicon glyphicon-warning-sign" style="color:#b45309"></span>Only ' + Math.round(100 * x.coverage) + '% of the days were observed' + (r.history_hours ? ' (CEMADEN keeps only the last ' + r.history_hours / 24 + ' days)' : '') + ': totals are lower than the real ones.' : '',
        r.rain_only && !x.hasTemp ? '<span class="glyphicon glyphicon-info-sign"></span>This is a rain gauge: choose a station for temperature and ET0 in step 2.' + (r.temp_error ? ' (' + esc(r.temp_error) + ')' : '') : '',
        r.stale ? '<span class="glyphicon glyphicon-warning-sign" style="color:#b45309"></span>A weather service did not answer: the last copy read earlier is shown.' : '',
    ].filter(Boolean).map(n => '<p class="wx-note">' + n + '</p>').join('');

    $('#wx_season').html(findings + stageTable + (S.crop === 'maize' ? rmCard(A) : '') + charts
        + '<div class="wx-card"><div class="wx-card-head"><h4><span class="glyphicon glyphicon-th-list"></span> By month</h4>'
        + '<span><button class="btn btn-default btn-xs" id="wx_csv"><span class="glyphicon glyphicon-download-alt"></span> Daily CSV</button> '
        + '<button class="btn btn-default btn-xs" id="wx_cov_csv"><span class="glyphicon glyphicon-download-alt"></span> Covariates CSV</button></span></div>'
        + monthTable(A.days, rep) + notes
        + '<details class="wx-details"><summary>Daily observations (' + A.days.length + ' days)</summary>' + dailyTable(A.days, rep) + '</details></div>');

    const bandOpt = { bands };
    stressStrip('#wx_c_stress', A.stress, STRESS_ROWS.filter(rw => (rw.key !== 'dry' && rw.key !== 'heavy') || rep).filter(rw => (rw.key !== 'heat' && rw.key !== 'frost') || x.hasTemp),
        { bands, stageOf, detail: date => { const d = A.days.find(z => z.date === date) || {}; return 'max ' + f1(toT(d.tmax)) + ' / min ' + f1(toT(d.tmin)) + ' ' + tUnit() + ' · ' + (rep ? 'rain ' + f1(d.rain) + ' mm' : 'rain hours ' + (d.rain_hours === undefined ? '–' : d.rain_hours)); } });
    chartXY('#wx_c_temp', pts, [{ key: 'tmax', label: 'Maximum', color: COLORS.tmax, unit: tUnit() }, { key: 'tmin', label: 'Minimum', color: COLORS.tmin, unit: tUnit() }],
        Object.assign({ slots: true, bandLabels: false, refLines: [{ y: toT(S.p.heat), label: 'heat ' + fmtTh(S.p.heat), color: '#e34948' }, { y: toT(S.p.frost), label: 'frost ' + fmtTh(S.p.frost), color: '#6250d6' }] }, bandOpt));
    chartXY('#wx_c_rain', pts, [rep ? { key: 'rain', label: 'Rain', color: COLORS.rain, unit: 'mm', colorOf: p => (p.rain >= S.p.heavy ? '#1e3a8a' : null) } : { key: 'rain_hours', label: 'Rain hours', color: COLORS.rain, unit: 'h', digits: 0 }],
        Object.assign({ zero: true, height: 150, bandLabels: false, type: 'bar' }, bandOpt));
    chartXY('#wx_c_water', pts, (rep ? [{ key: 'rainCum', label: 'Rain', color: COLORS.rain, unit: 'mm' }] : []).concat(hasEt0 ? [{ key: 'et0Cum', label: 'ET0', color: COLORS.et0, unit: 'mm' }] : []),
        Object.assign({ zero: true, slots: true, bandLabels: false }, bandOpt));
    chartXY('#wx_c_gdd', pts, [{ key: 'gddCum', label: 'Degree-days', color: COLORS.gdd, unit: ddUnit(), digits: 0 }], Object.assign({ zero: true, height: 150, slots: true, bandLabels: false }, bandOpt));
}

// ---------------------------------------------------------------- maize relative maturity
const isMaize = () => S.crop === 'maize';
const fmtInt = v => (v === null || v === undefined ? '–' : Math.round(v).toLocaleString('en-US'));

function rmCell(c) {
    if (!c.rm_temp_ok) return '<span class="wx-muted" title="needs temperature on 80% of the days">–</span>';
    if (c.rm_end_reason && /frost/.test(c.rm_end_reason)) return '<b>RM ' + (c.max_rm === null ? '<' + RM_STEPS[0] : c.max_rm) + '</b><div class="wx-small wx-muted">frost ' + shortDate(c.rm_season_end) + '</div>';
    return c.rm_ref_days ? '<b>' + c.rm_ref_days + ' d</b><div class="wx-small wx-muted">RM ' + S.p.rmRef + ', no frost</div>' : '<span class="wx-muted">RM ' + S.p.rmRef + ' not mature</span>';
}

function rmCard(A) {
    const r = rmSeason(A.days, S.p);
    const head = '<div class="wx-card-head"><h4><span class="glyphicon glyphicon-dashboard"></span> Relative maturity (RM) this season supports</h4>'
        + '<span class="wx-muted wx-small">GDD 50/86 °F · RM 100 = ' + fmtInt(S.p.rm100) + ' GDD °F to black layer, ' + S.p.rmDay + ' GDD °F per RM day (settings)</span></div>';
    if (!r.ok) return '<div class="wx-card">' + head + alertHtml('warning', 'Only ' + Math.round(100 * r.tempCoverage) + '% of the days have temperatures: choose a station with temperature (step 2) to compute RM.') + '</div>';
    const tropical = !r.frost;
    const top = r.rm !== null ? r.rm : tropical ? S.p.rmRef : Math.min(...RM_STEPS);
    const steps = RM_STEPS.filter(x => x >= top - 20 && x <= top + 15);
    const maxNeed = rmToGddF(steps[steps.length - 1], S.p);
    const rows = steps.map(rm => {
        const d = rmDates(A.days, rm, S.p);
        const status = d.black && !d.frostBefore ? '<span class="wx-flag wx-flag-spray">matures</span>'
            : d.frostBefore ? '<span class="wx-flag wx-flag-heat">killing frost ' + shortDate(d.frostBefore) + ' before black layer</span>'
                : '<span class="wx-flag wx-flag-wind">not by ' + shortDate(r.end) + ': short by ' + fmtInt(d.short * 1.8) + ' GDD °F</span>';
        const daysTo = d.black ? daysBetween(A.from, d.black) : null;
        const pct = Math.min(100, (100 * r.gddF) / d.needF);
        return '<tr class="' + (rm === Math.floor(top / 5) * 5 ? 'wx-crit' : '') + '"><td><b>RM ' + rm + '</b></td><td class="n">' + fmtInt(d.needF) + '</td>'
            + '<td>' + (d.silk ? fmtDate(d.silk) + ' <span class="wx-muted wx-small">' + daysBetween(A.from, d.silk) + ' d</span>' : '–') + '</td><td>' + (d.black ? fmtDate(d.black) + ' <span class="wx-muted wx-small">' + daysTo + ' d</span>' : '–') + '</td>'
            + '<td style="min-width:120px"><div class="wx-ibar" title="' + Math.round(pct) + '% of the GDD needed"><div style="width:' + pct.toFixed(0) + '%;background:' + (pct >= 100 ? '#1baf7a' : '#eda100') + '"></div></div></td>'
            + '<td>' + status + '</td></tr>';
    }).join('');
    const headline = tropical
        ? 'No killing frost: the season length, not frost, limits the hybrid. Here an <b>RM ' + S.p.rmRef + '</b> hybrid planted ' + fmtDate(A.from) + ' silks in <b class="wx-big">' + (r.refSilkDays || '–') + ' days</b> and reaches black layer in <b class="wx-big">' + (r.refDays || '–') + ' days</b>'
            + (r.gddFPerDay ? ' (' + r.gddFPerDay.toFixed(1) + ' GDD °F a day)' : '') + (r.refDays ? '.' : ': not reached by ' + fmtDate(r.end) + '.')
        : r.rm !== null
            ? 'Hybrids up to <b class="wx-big">RM ' + r.rm + '</b> reach black layer: ' + fmtInt(r.gddF) + ' GDD °F' + (isF() ? '' : ' (' + fmtInt(r.gddC) + ' °C·d)') + ' from planting ' + fmtDate(A.from) + ' to ' + fmtDate(r.end) + ' (' + esc(rmReasonText(r.reason, r.killTemp)) + ').'
            : 'Only ' + fmtInt(r.gddF) + ' GDD °F before the killing frost of ' + fmtDate(r.end) + ': not enough for an RM ' + RM_STEPS[0] + ' hybrid.';
    return '<div class="wx-card">' + head + '<p class="wx-rm-head">' + headline + '</p>'
        + (tropical ? '<p class="wx-note"><span class="glyphicon glyphicon-info-sign"></span>Where there is no frost, hybrids are placed by how fast they mature (days to silking and black layer) against the length of the rainy season or of the planting window. The reference RM can be changed in the settings.</p>' : '')
        + '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr><th>Hybrid</th><th class="n">GDD °F to black layer</th><th>Silking (~' + S.p.silk + '%)</th><th>Black layer</th><th>GDD reached</th><th>This season</th></tr></thead><tbody>' + rows + '</tbody></table></div>'
        + '<p class="wx-note">Dates for a hybrid planted ' + fmtDate(A.from) + ' at this station. RM ratings differ between companies: adjust the conversion in "Stress thresholds and degree-days". Use Past years for the RM zone (the RM that matures in 8 of 10 years).</p></div>';
}

function monthTable(days, rep) {
    const months = {};
    days.forEach(d => { (months[d.date.slice(0, 7)] = months[d.date.slice(0, 7)] || []).push(d); });
    const rows = Object.keys(months).sort().map(m => {
        const s = summarize(months[m], rep, S.p);
        return '<tr><td>' + m + '</td><td class="n">' + s.withData + ' / ' + s.days + '</td>'
            + (rep ? '<td class="n">' + f1(s.rain) + '</td><td class="n">' + s.rainyDays + '</td>' : '<td class="n">' + s.rainHours + '</td>')
            + '<td class="n">' + f1(s.et0) + '</td>' + (rep ? '<td class="n ' + (s.balance !== null && s.balance < 0 ? 'wx-neg' : 'wx-pos') + '">' + (s.balance === null ? '–' : sign(s.balance)) + '</td>' : '')
            + '<td class="n">' + f1(toT(s.tmax)) + '</td><td class="n">' + f1(toT(s.tmin)) + '</td><td class="n">' + f1(toDD(s.gdd), 0) + '</td>'
            + '<td class="n">' + (s.heat === null ? '–' : s.heat) + '</td><td class="n">' + (s.frost === null ? '–' : s.frost) + '</td></tr>';
    }).join('');
    return '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr><th>Month</th><th class="n">Days observed</th>'
        + (rep ? '<th class="n">Rain mm</th><th class="n">Rainy days</th>' : '<th class="n">Rain hours</th>')
        + '<th class="n">ET0 mm</th>' + (rep ? '<th class="n">Balance mm</th>' : '') + '<th class="n">Mean max ' + tUnit() + '</th><th class="n">Mean min ' + tUnit() + '</th>'
        + '<th class="n">Degree-days ' + ddUnit() + '</th><th class="n">Heat days</th><th class="n">Frost days</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
}

function dailyCols(rep) {
    return [
        ['date', 'Date'], ['tmax', 'Max ' + tUnit()], ['tmin', 'Min ' + tUnit()], ['tmean', 'Mean ' + tUnit()], ['rh', 'RH %'],
        rep ? ['rain', 'Rain mm'] : null, ['rain_hours', 'Rain hours'], ['et0', 'ET0 mm'], ['et0_method', 'ET0 method'],
        ['gdd', 'Degree-days ' + ddUnit()], ['radiation', 'Radiation MJ/m²'], ['wind_mean', 'Wind km/h'], ['hours', 'Reports'],
    ].filter(Boolean);
}

// a daily value in the display unit (temperatures and degree-days rounded to 0.1)
const TEMP_COLS = ['tmax', 'tmin', 'tmean'];
function dailyVal(d, k) {
    if (k === 'gdd' || TEMP_COLS.includes(k)) {
        const v = inUnit(k, k === 'gdd' ? d.gdd : d[k]);
        return v === null || v === undefined ? null : (Math.round(v * 10) / 10).toFixed(1);
    }
    return d[k];
}

function dailyTable(days, rep) {
    const cols = dailyCols(rep);
    const cell = (d, k) => {
        if (k === 'date') return esc(d.date);
        if (k === 'et0_method') return d.et0_method === 'PM' ? 'Penman-Monteith' : d.et0_method === 'HS' ? 'Hargreaves' : '';
        const v = dailyVal(d, k);
        return v === null || v === undefined || v === '' ? '–' : esc(v);
    };
    const rows = days.slice().reverse().map(d => '<tr' + (d.missing || !d.complete ? ' class="wx-fc" title="no or incomplete observation"' : '') + '>'
        + cols.map(c => '<td' + (c[0] === 'date' || c[0] === 'et0_method' ? '' : ' class="n"') + '>' + cell(d, c[0]) + '</td>').join('') + '</tr>').join('');
    return '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr>' + cols.map(c => '<th' + (c[0] === 'date' || c[0] === 'et0_method' ? '' : ' class="n"') + '>' + c[1] + '</th>').join('') + '</tr></thead><tbody>' + rows + '</tbody></table></div>';
}

function csvDownload(name, head, rows) {
    const q = v => { const s = v === null || v === undefined ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const blob = new Blob([[head.map(q).join(',')].concat(rows.map(r => r.map(q).join(','))).join('\n') + '\n'], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name.replace(/[^\w.-]+/g, '_');
    document.body.appendChild(a);
    a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500);
}

function stationText(r) {
    return stationLabel(S.station) + (r && r.temp_station ? ' + ' + stationLabel(r.temp_station) : '');
}

function downloadDaily() {
    const A = S.season, cols = dailyCols(A.rep);
    csvDownload('weather_' + S.loc.name + '_' + S.start + '_' + S.end + '.csv', ['location', 'stations'].concat(cols.map(c => c[1])),
        A.days.map(d => [S.loc.name, stationText(S.daily)].concat(cols.map(c => dailyVal(d, c[0])))));
}

const r1 = v => (v === null || v === undefined ? '' : typeof v === 'number' ? Math.round(v * 10) / 10 : v);
function covRow(c) { return covariateColumns().map(([k]) => (k === 'coverage' ? Math.round(100 * c.coverage) : r1(inUnit(k, c[k])))); }

function downloadSeasonCov() {
    const c = covariates(S.season.days, S.season.rep, S.p, S.crop);
    csvDownload('environment_' + S.loc.name + '_' + S.start + '_' + S.end + '.csv',
        ['location', 'stations', 'crop', 'start', 'end', 'planting'].concat(covariateColumns().map(c2 => c2[1])),
        [[S.loc.name, stationText(S.daily), (CROPS.find(x => x.v === S.crop) || CROPS[0]).label, S.start, S.end, S.season.from].concat(covRow(c))]);
}

// ---------------------------------------------------------------- Trials: environmental covariates per trial
function trialWindow(t) {
    const today = S.cfg.today || iso(new Date());
    let end = t.harvest && t.harvest > t.planting ? t.harvest : today;
    if (end > today) end = today;
    if (daysBetween(t.planting, end) > S.cfg.max_days) end = addDays(t.planting, S.cfg.max_days - 1);
    return { start: t.planting, end, noHarvest: !t.harvest };
}

function loadTrialsTab() {
    if (needStation('#wx_trials')) return;
    if (!S.trialsAll.length) {
        $('#wx_trials').html('<div class="wx-empty-card"><span class="glyphicon glyphicon-leaf"></span><h4>No trial at this location</h4><p>Trials of this location with a planting date get their own environment here.</p></div>');
        return;
    }
    if (!S.trials.length) {
        $('#wx_trials').html('<div class="wx-empty-card"><span class="glyphicon glyphicon-leaf"></span><h4>' + S.trialsAll.length + ' trial(s), none with a planting date</h4><p>Add the planting (and harvest) date on the trial pages to get the environment of each trial.</p></div>');
        return;
    }
    const key = [stationKey(S.station), stationKey(S.tempStation), S.crop, JSON.stringify(S.p)].join('|');
    if (S.trialRows && S.trialRows.key === key) { renderTrials(); return; }
    const seq = S.seq;
    S.trialRows = { key, rows: S.trials.map(t => ({ t, w: trialWindow(t), state: 'loading' })) };
    renderTrials();
    let i = 0;
    const next = () => {
        if (seq !== S.seq || !S.trialRows || S.trialRows.key !== key || i >= S.trialRows.rows.length) return Promise.resolve();
        const row = S.trialRows.rows[i++];
        if (row.w.start > (S.cfg.today || '9999')) { row.state = 'error'; row.error = 'planted in the future'; return next(); }
        return fetchPair(S.station, S.tempStation, row.w.start, row.w.end).then(r => {
            const days = seasonDays(r, row.w.start, row.w.end, S.p, S.cfg.today);
            row.cov = covariates(days, !!r.rain_reported, S.p, S.crop);
            row.rep = !!r.rain_reported;
            row.state = 'ok';
        }).catch(e => { row.state = 'error'; row.error = e.message; })
            .then(() => { if (S.tab === 'trials') renderTrials(); return next(); });
    };
    Promise.all([next(), next()]);
}

function bar(v, max, neg) {
    if (v === null || v === undefined || !max) return '';
    return '<div class="wx-ibar"><div style="width:' + Math.min(100, Math.round(100 * Math.abs(v) / max)) + '%;background:' + (neg && v < 0 ? '#e34948' : '#2a78d6') + '"></div></div>';
}

function covTable(rows, labelCell, extraHead, opt) {
    opt = opt || {};
    const ok = rows.filter(r => r.state === 'ok' && r.cov.coverage >= 0.2);
    const mx = k => Math.max(0, ...ok.map(r => Math.abs(num(r.cov[k]) || 0)));
    const M2 = { rain: mx('rain'), water_balance: mx('water_balance'), gdd: mx('gdd'), critical_balance: mx('critical_balance') };
    const body = rows.map(row => {
        const head = labelCell(row);
        if (row.state === 'loading') return '<tr>' + head + '<td colspan="11"><span class="glyphicon glyphicon-refresh wx-spin"></span> reading...</td></tr>';
        if (row.state === 'error') return '<tr>' + head + '<td colspan="11" class="text-danger wx-small">' + esc(row.error) + '</td></tr>';
        const c = row.cov;
        if (c.coverage < 0.2) return '<tr class="wx-fc">' + head + '<td class="n wx-warn-txt">' + Math.round(100 * c.coverage) + '%</td><td colspan="10" class="wx-muted wx-small">too few days observed by this station for these dates (the station may not have existed yet)</td>' + (isMaize() ? '<td class="n">' + rmCell(c) + '</td>' : '') + '<td></td>' + (opt.tail ? opt.tail(row) : '') + '</tr>';
        const n = (k, d) => { const v = num(inUnit(k, c[k])); return v === null ? '–' : v.toFixed(d || 0); };
        return '<tr' + (row.highlight ? ' class="on"' : '') + '>' + head
            + '<td class="n' + (c.coverage < 0.8 ? ' wx-warn-txt' : '') + '">' + Math.round(100 * c.coverage) + '%</td>'
            + '<td class="n">' + (row.rep ? n('rain') + bar(c.rain, M2.rain) : '–') + '</td>'
            + '<td class="n ' + (num(c.water_balance) !== null && c.water_balance < 0 ? 'wx-neg' : 'wx-pos') + '">' + (num(c.water_balance) === null ? '–' : sign(c.water_balance)) + bar(c.water_balance, M2.water_balance, true) + '</td>'
            + '<td class="n">' + n('longest_dry_spell') + '</td>'
            + '<td class="n">' + n('gdd') + bar(c.gdd, M2.gdd) + '</td>'
            + '<td class="n">' + n('tmax_mean', 1) + '</td><td class="n">' + n('heat_days') + '</td><td class="n">' + n('frost_days') + '</td>'
            + '<td class="n ' + (num(c.critical_balance) !== null && c.critical_balance < 0 ? 'wx-neg' : 'wx-pos') + '">' + (num(c.critical_balance) === null ? '–' : sign(c.critical_balance)) + bar(c.critical_balance, M2.critical_balance, true) + '</td>'
            + '<td class="n">' + n('critical_heat_days') + '</td>'
            + (isMaize() ? '<td class="n">' + rmCell(c) + '</td>' : '')
            + '<td><div class="wx-flags">' + issueChips(c.issues.slice().sort((a, b) => (a.level === 'bad' ? 0 : 1) - (b.level === 'bad' ? 0 : 1) || (b.critical ? 1 : 0) - (a.critical ? 1 : 0)).slice(0, 3)
                .map(i => Object.assign({}, i, { text: i.stage + ': ' + i.text }))) + '</div></td>'
            + (opt.tail ? opt.tail(row) : '') + '</tr>';
    }).join('');
    return '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr>' + extraHead
        + '<th class="n">Days observed</th><th class="n">Rain mm</th><th class="n">Balance mm</th><th class="n">Longest dry spell</th><th class="n">Degree-days ' + ddUnit() + '</th>'
        + '<th class="n">Mean max ' + tUnit() + '</th><th class="n">Heat days</th><th class="n">Frost days</th><th class="n" title="Rain − ET0 in the critical stage">Critical balance mm</th><th class="n">Critical heat days</th>' + (isMaize() ? '<th class="n" title="Largest RM reaching black layer before the first killing frost; without frost, days for the reference RM to reach black layer">Max RM / days to black layer</th>' : '') + '<th>Main stress</th>'
        + (opt.tailHead || '') + '</tr></thead><tbody>' + body + '</tbody></table></div>';
}

function renderTrials() {
    const rows = S.trialRows.rows;
    const loadingN = rows.filter(r => r.state === 'loading').length;
    const noDate = S.trialsAll.length - S.trials.length;
    const crop = CROPS.find(c => c.v === S.crop) || CROPS[0];
    const table = covTable(rows, row => '<td><a href="/breeders/trial/' + row.t.id + '" target="_blank">' + esc(row.t.name) + '</a><div class="wx-small wx-muted">' + esc(row.t.year || '') + ' · ' + shortDate(row.w.start) + '/' + row.w.start.slice(2, 4) + ' → ' + shortDate(row.w.end) + '/' + row.w.end.slice(2, 4) + (row.w.noHarvest ? ' (no harvest date)' : '') + '</div></td>',
        '<th>Trial (planting → harvest)</th>', { tailHead: '<th></th>', tail: row => '<td><button class="btn btn-default btn-xs" data-trial-season="' + row.t.id + '" title="Open this season in the Season tab">Season</button></td>' });
    const ok = rows.filter(r => r.state === 'ok' && r.cov.coverage >= 0.2);
    let charts = '';
    if (ok.length > 1) {
        charts = '<div class="wx-grid2" style="margin-top:14px"><div><div class="wx-sub">Rain in the season (mm)</div><div id="wx_tc_rain"></div></div>'
            + '<div><div class="wx-sub">Water balance in the critical stage (mm)</div><div id="wx_tc_crit"></div></div>'
            + '<div><div class="wx-sub">Degree-days in the season</div><div id="wx_tc_gdd"></div></div>'
            + '<div><div class="wx-sub">Heat-stress days in the season</div><div id="wx_tc_heat"></div></div></div>';
    }
    $('#wx_trials').html('<div class="wx-card"><div class="wx-card-head"><h4><span class="glyphicon glyphicon-leaf"></span> Environment of each trial at ' + esc(S.loc.name) + '</h4>'
        + '<button class="btn btn-default btn-xs" id="wx_trials_csv"' + (loadingN ? ' disabled' : '') + '><span class="glyphicon glyphicon-download-alt"></span> Covariates CSV (for G×E)</button></div>'
        + '<p class="wx-small wx-muted">Each trial from its planting to its harvest date (or today), crop stages of ' + esc(crop.label.toLowerCase()) + ' (step 3). '
        + (noDate ? noDate + ' trial(s) without planting date are not shown. ' : '') + (loadingN ? 'Reading ' + loadingN + ' more...' : '') + '</p>'
        + table + charts
        + '<p class="wx-note"><span class="glyphicon glyphicon-info-sign"></span>Use these covariates to explain genotype × environment interaction: a trial with a water deficit or heat at flowering is a stress environment. Values come from the weather station of the location (' + esc(stationText(null)) + ').</p></div>');
    if (ok.length > 1) {
        const items = k => ok.map(r => ({ label: r.t.name, value: num(inUnit(k, r.cov[k])) }));
        catBars('#wx_tc_rain', items('rain'), { unit: 'mm', ref: median(items('rain').map(i => i.value).filter(v => v !== null)) });
        catBars('#wx_tc_crit', items('critical_balance'), { unit: 'mm', color: '#f4a3a3', ref: 0, refLabel: 'no deficit' });
        catBars('#wx_tc_gdd', items('gdd'), { unit: ddUnit(), color: '#9fdcc3' });
        catBars('#wx_tc_heat', items('heat_days'), { unit: 'days', color: '#f4a3a3' });
    }
}

function downloadTrials() {
    const ok = S.trialRows.rows.filter(r => r.state === 'ok');
    csvDownload('trial_environments_' + S.loc.name + '.csv',
        ['trial_id', 'trial', 'year', 'location', 'stations', 'crop', 'planting', 'end', 'harvest_date_known'].concat(covariateColumns().map(c => c[1])),
        ok.map(r => [r.t.id, r.t.name, r.t.year, S.loc.name, stationText(null), (CROPS.find(x => x.v === S.crop) || CROPS[0]).label, r.w.start, r.w.end, r.w.noHarvest ? 'no' : 'yes'].concat(covRow(r.cov))));
}

// ---------------------------------------------------------------- Past years: was this season normal?
function shiftYears(date, k) {
    const y = Number(date.slice(0, 4)) - k;
    let md = date.slice(4);
    if (md === '-02-29') md = '-02-28';
    return y + md;
}

function renderYearsIntro() {
    if (needStation('#wx_years')) return;
    if (S.years && S.years.key === yearsKey()) { renderYears(); return; }
    $('#wx_years').html('<div class="wx-card"><h4><span class="glyphicon glyphicon-stats"></span> Was this season normal?</h4>'
        + '<p>Compares ' + fmtDate(S.start) + ' to ' + fmtDate(S.end) + ' with the same dates of the previous years, from the same station' + (S.station.rain_only && S.tempStation ? 's' : '') + ' (' + esc(stationText(null)) + ').</p>'
        + (S.station.history_hours ? alertHtml('warning', 'This rain gauge keeps only the last ' + S.station.history_hours / 24 + ' days: choose a station with history (Data sources) to compare years.') : '')
        + '<div class="wx-inline"><span>Years to compare</span><select class="form-control input-sm" id="wx_years_n"><option>5</option><option selected>10</option><option>15</option></select>'
        + '<button class="btn btn-primary btn-sm" id="wx_years_go"><span class="glyphicon glyphicon-play"></span> Compare</button></div>'
        + '<p class="wx-note">Each year is one request to the free weather services, read one after the other: 10 years can take a minute the first time.</p></div>');
}

function yearsKey() { return [stationKey(S.station), stationKey(S.tempStation), S.start, S.end, S.planting, S.crop, JSON.stringify(S.p)].join('|'); }

function loadYears() {
    const n = Number($('#wx_years_n').val()) || 10;
    const key = yearsKey();
    const seq = S.seq;
    const list = [];
    for (let k = 0; k <= n; k++) list.push({ k, start: shiftYears(S.start, k), end: shiftYears(S.end, k), planting: shiftYears(S.planting || S.start, k), state: 'loading' });
    S.years = { key, list };
    renderYears();
    let i = 0;
    const next = () => {
        if (seq !== S.seq || !S.years || S.years.key !== key || i >= list.length) return Promise.resolve();
        const y = list[i++];
        return fetchPair(S.station, S.tempStation, y.start, y.end).then(r => {
            const A = analysis(r, y.start, y.end, y.planting);
            y.cov = covariates(A.days, A.rep, S.p, S.crop);
            y.rep = A.rep;
            y.state = 'ok';
        }).catch(e => { y.state = 'error'; y.error = e.message; })
            .then(() => { if (S.tab === 'years') renderYears(); return next(); });
    };
    next();
}

function rankText(list, k, cur, words) {
    const vals = list.filter(y => y.state === 'ok' && y.cov.coverage >= 0.8 && num(y.cov[k]) !== null);
    if (vals.length < 4 || num(cur.cov[k]) === null || cur.cov.coverage < 0.8) return '';
    const sorted = vals.map(y => y.cov[k]).sort((a, b) => a - b);
    const low = sorted.filter(v => v < cur.cov[k]).length + 1;
    const high = sorted.filter(v => v > cur.cov[k]).length + 1;
    const med = median(sorted);
    const pct = med ? Math.round(100 * (cur.cov[k] - med) / Math.abs(med)) : null;
    const pos = low <= high ? (low === 1 ? 'the ' + words[0] : low + suffix(low) + ' ' + words[0]) : (high === 1 ? 'the ' + words[1] : high + suffix(high) + ' ' + words[1]);
    return pos + ' of ' + vals.length + ' years (median ' + med.toFixed(0) + (pct !== null && Math.abs(pct) < 1000 ? ', ' + (pct > 0 ? '+' : '') + pct + '%' : '') + ')';
}
function suffix(n) { return n % 10 === 1 && n % 100 !== 11 ? 'st' : n % 10 === 2 && n % 100 !== 12 ? 'nd' : n % 10 === 3 && n % 100 !== 13 ? 'rd' : 'th'; }

function renderYears() {
    const list = S.years.list;
    const cur = list[0];
    const loadingN = list.filter(y => y.state === 'loading').length;
    const label = y => (y.start.slice(0, 4) === y.end.slice(0, 4) ? y.start.slice(0, 4) : y.start.slice(0, 4) + '/' + y.end.slice(2, 4));
    let summary = '';
    if (cur.state === 'ok' && !loadingN) {
        const parts = [
            cur.rep ? ['Rain', rankText(list, 'rain', cur, ['driest', 'wettest'])] : null,
            cur.rep ? ['Water balance', rankText(list, 'water_balance', cur, ['most deficient', 'least deficient'])] : null,
            ['Degree-days', rankText(list, 'gdd', cur, ['coolest', 'warmest'])],
            ['Heat-stress days', rankText(list, 'heat_days', cur, ['fewest', 'most'])],
            cur.rep ? ['Critical-stage balance', rankText(list, 'critical_balance', cur, ['driest', 'wettest'])] : null,
        ].filter(x => x && x[1]);
        if (isMaize()) {
            const tempYears = list.filter(y => y.state === 'ok' && y.cov.rm_temp_ok);
            const frostYears = tempYears.filter(y => /frost/.test(y.cov.rm_end_reason || ''));
            if (frostYears.length >= tempYears.length / 2) {
                // years whose killing frost came too early for even the smallest RM count as RM 0
                const z = rmZone(tempYears.map(y => (/frost/.test(y.cov.rm_end_reason || '') ? (y.cov.max_rm === null ? 0 : y.cov.max_rm) : 999)), 0.8);
                parts.unshift(['RM zone', z ? 'hybrids up to RM ' + z.rm + ' reached black layer before the killing frost in at least 80% of ' + z.years + ' years (this season: ' + (cur.cov.max_rm === null ? '–' : 'RM ' + cur.cov.max_rm) + ')' : 'needs at least 3 years with temperature']);
            }
            else {
                const ds = tempYears.map(y => y.cov.rm_ref_days).filter(v => v !== null);
                if (ds.length >= 3) parts.unshift(['Maize speed', 'an RM ' + S.p.rmRef + ' hybrid reached black layer in ' + Math.min(...ds) + ' to ' + Math.max(...ds) + ' days (median ' + median(ds) + ') over ' + ds.length + ' years; no killing frost limits the season']);
            }
        }
        summary = parts.length ? '<ul class="wx-finds">' + parts.map(p => '<li class="wx-find wx-find-info"><b>' + p[0] + ':</b> ' + esc(p[1]) + '</li>').join('') + '</ul>'
            : '<p class="wx-muted">Not enough complete years to rank this season.</p>';
    }
    const rows = list.map(y => Object.assign(y, { highlight: y.k === 0 }));
    const table = covTable(rows, y => '<td><b>' + label(y) + '</b>' + (y.k === 0 ? ' <span class="wx-pill wx-pill-st">this season</span>' : '') + '<div class="wx-small wx-muted">' + shortDate(y.start) + ' → ' + shortDate(y.end) + '</div></td>', '<th>Year</th>');
    const ok = list.filter(y => y.state === 'ok' && y.cov.coverage >= 0.2).slice().reverse();
    $('#wx_years').html('<div class="wx-card"><div class="wx-card-head"><h4><span class="glyphicon glyphicon-stats"></span> This season against the previous ' + (list.length - 1) + ' years</h4>'
        + '<span>' + (loadingN ? '<span class="wx-muted wx-small"><span class="glyphicon glyphicon-refresh wx-spin"></span> reading ' + loadingN + ' more year(s)... </span>' : '')
        + '<button class="btn btn-default btn-xs" id="wx_years_csv"' + (loadingN ? ' disabled' : '') + '><span class="glyphicon glyphicon-download-alt"></span> CSV</button> '
        + '<button class="btn btn-link btn-xs" id="wx_years_again">change</button></span></div>'
        + summary
        + (ok.length > 1 ? '<div class="wx-grid2"><div><div class="wx-sub">' + (cur.rep ? 'Rain (mm)' : 'Rain hours') + '</div><div id="wx_yc_rain"></div></div>'
            + '<div><div class="wx-sub">Water balance in the critical stage (mm)</div><div id="wx_yc_crit"></div></div>'
            + '<div><div class="wx-sub">Degree-days</div><div id="wx_yc_gdd"></div></div>'
            + '<div><div class="wx-sub">Heat-stress days</div><div id="wx_yc_heat"></div></div>'
            + (isMaize() ? '<div><div class="wx-sub">Largest maize RM reaching black layer</div><div id="wx_yc_rm"></div></div>' : '') + '</div>' : '')
        + '<h5 class="wx-sub" style="margin-top:14px">Every year</h5>' + table
        + '<p class="wx-note">Years with less than 80% of the days observed are not ranked (shown faded). The same planting date and crop stages are used every year.</p></div>');
    if (ok.length > 1) {
        const items = k => ok.map(y => ({ label: label(y), value: num(inUnit(k, y.cov[k])), highlight: y.k === 0, faded: y.cov.coverage < 0.8 }));
        const ref = k => median(ok.filter(y => y.cov.coverage >= 0.8 && num(y.cov[k]) !== null).map(y => num(inUnit(k, y.cov[k]))));
        catBars('#wx_yc_rain', items('rain'), { unit: 'mm', ref: ref('rain') });
        catBars('#wx_yc_crit', items('critical_balance'), { unit: 'mm', ref: ref('critical_balance'), color: '#f4a3a3', highlightColor: '#c0392b' });
        catBars('#wx_yc_gdd', items('gdd'), { unit: ddUnit(), ref: ref('gdd'), color: '#9fdcc3', highlightColor: '#0f8a5f' });
        catBars('#wx_yc_heat', items('heat_days'), { unit: 'days', ref: ref('heat_days'), color: '#f4a3a3', highlightColor: '#c0392b' });
        if (isMaize()) {
            const tempYears = list.filter(y => y.state === 'ok' && y.cov.rm_temp_ok).slice().reverse();
            const frostY = tempYears.filter(y => /frost/.test(y.cov.rm_end_reason || '')).length >= tempYears.length / 2;
            const it = tempYears.map(y => ({ label: label(y), value: frostY ? num(y.cov.max_rm) : num(y.cov.rm_ref_days), highlight: y.k === 0 }));
            const z = frostY ? rmZone(tempYears.map(y => (y.cov.max_rm === null ? 0 : y.cov.max_rm)), 0.8) : null;
            $('#wx_yc_rm').prev('.wx-sub').text(frostY ? 'Largest maize RM reaching black layer before the killing frost' : 'Days for an RM ' + S.p.rmRef + ' hybrid to reach black layer');
            catBars('#wx_yc_rm', it, { unit: frostY ? 'RM' : 'days', ref: z ? z.rm : median(it.map(i => i.value).filter(v => v !== null)), refLabel: frostY ? 'RM zone (80% of years)' : 'median', color: '#9fdcc3', highlightColor: '#0f8a5f' });
        }
    }
}

function downloadYears() {
    const ok = S.years.list.filter(y => y.state === 'ok');
    csvDownload('past_years_' + S.loc.name + '_' + S.start + '_' + S.end + '.csv',
        ['location', 'stations', 'start', 'end', 'planting', 'this_season'].concat(covariateColumns().map(c => c[1])),
        ok.map(y => [S.loc.name, stationText(null), y.start, y.end, y.planting, y.k === 0 ? 'yes' : 'no'].concat(covRow(y.cov))));
}

// ---------------------------------------------------------------- Locations: environments of the trial network
// stations used for the open location (Season tab): kept per location for this session, so the
// Locations comparison uses exactly the same stations as the Season tab
function rememberChoice() {
    if (!S.loc || !S.station) return;
    S.chosen[S.loc.id] = { st: S.station, t: S.station.rain_only ? S.tempStation : null };
}
const sameStation = (a, b) => (!a && !b) || (!!a && !!b && stationKey(a).toUpperCase() === stationKey(b).toUpperCase());

// the station(s) of a location for the comparison: the open location uses the stations on the page,
// the others the stations used for them earlier in this session, else their saved station
function savedPair(l) {
    const saved = l.station ? savedPairOf(l) : null;
    const open = S.loc && String(l.id) === String(S.loc.id) && S.station;
    const mem = open ? { st: S.station, t: S.station.rain_only ? S.tempStation : null } : S.chosen[l.id];
    if (mem && mem.st) {
        const notSaved = !saved || !sameStation(mem.st, saved.st) || !sameStation(mem.t, saved.t);
        return { st: mem.st, t: mem.t || null, current: notSaved };
    }
    return saved;
}

function savedPairOf(l) {
    const s = l.station;
    const st = { network: s.network, id: s.station_id, name: s.name, lat: s.lat, lon: s.lon, elev: s.elev, distance_km: s.distance_km, ready: 1, rain_only: !!s.rain_only || !isTempNet(s.network) };
    const t = s.temp_station_id ? { network: s.temp_network, id: s.temp_station_id, name: s.temp_name, lat: s.temp_lat, lon: s.temp_lon, elev: s.temp_elev, ready: 1 } : null;
    return { st, t };
}

// the dates of the Comparison tab: its own, copied from step 3 the first time
function cmpDates() {
    if (!S.cmp && S.start) S.cmp = { start: S.start, end: S.end, planting: S.planting || S.start };
    return S.cmp || {};
}

// reads and checks the dates typed in the Comparison tab; returns false (and says why) when they are not valid
function readCmpDates() {
    const a = $('#wx_cmp_start').val(), b = $('#wx_cmp_end').val();
    let pl = $('#wx_cmp_planting').val() || a;
    if (!isIsoDate(a) || !isIsoDate(b)) { flash('warning', 'Comparison: write the start and end dates as YYYY-MM-DD.'); return false; }
    if (a > b) { flash('warning', 'Comparison: the start date must be before the end date.'); return false; }
    const n = daysBetween(a, b);
    if (n > S.cfg.max_days) { flash('warning', 'Comparison: the period has ' + n + ' days; the limit is ' + S.cfg.max_days + ' days.'); return false; }
    if (!isIsoDate(pl) || pl < a || pl > b) pl = a;
    S.cmp = { start: a, end: b, planting: pl };
    return true;
}

function renderLocationsTab() {
    if (!S.start) return;
    const D = cmpDates();
    const linked = S.locations.filter(l => l.station || (S.loc && String(l.id) === String(S.loc.id) && S.station) || S.chosen[l.id]);
    if (!linked.length) {
        $('#wx_locs').html('<div class="wx-empty-card"><span class="glyphicon glyphicon-globe"></span><h4>No location has a weather station yet</h4><p>Save a station for each location (step 2) to compare their environments here.</p></div>');
        return;
    }
    if (!Object.keys(S.locPick).length) linked.slice(0, 8).forEach(l => { S.locPick[l.id] = true; });
    if (S.loc && S.loc.station) S.locPick[S.loc.id] = true;
    if (S.loc && S.station) S.locPick[S.loc.id] = true;
    const picks = linked.map(l => { const p = savedPair(l); return '<label class="wx-lpick"><input type="checkbox" data-lpick="' + l.id + '"' + (S.locPick[l.id] ? ' checked' : '') + ' /> ' + esc(l.name)
        + ' <span class="wx-muted wx-small">' + esc(stationLabel(p.st).split(' ')[0]) + (p.t ? ' + ' + esc(p.t.id) : '') + (p.current ? ' (not saved)' : '') + '</span></label>'; }).join('');
    const withoutN = S.locations.filter(l => !l.station && hasCoords(l)).length;
    const dateIn = (id, v, label) => '<label class="wx-small">' + label + '<br><input type="text" class="form-control input-sm" id="' + id + '" value="' + esc(v || '') + '" placeholder="YYYY-MM-DD" style="width:120px" /></label> ';
    $('#wx_locs').html('<div class="wx-card"><h4><span class="glyphicon glyphicon-globe"></span> Compare the environments of your locations</h4>'
        + '<p class="wx-small wx-muted">The same dates for every ticked location, each with its weather station (the stations used on its Season tab in this session, otherwise its saved station). '
        + (withoutN ? withoutN + ' location(s) with coordinates have no station yet.' : '') + '</p>'
        + '<div class="wx-cmp-dates" style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end;margin-bottom:8px">'
        + dateIn('wx_cmp_start', D.start, 'Start') + dateIn('wx_cmp_end', D.end, 'End') + dateIn('wx_cmp_planting', D.planting, 'Planting')
        + '<a href="#" id="wx_cmp_step3" class="wx-small" style="margin-bottom:6px">use the dates of step 3</a></div>'
        + '<div class="wx-lpicks">' + picks + '</div>'
        + '<button class="btn btn-primary btn-sm" id="wx_locs_go"><span class="glyphicon glyphicon-play"></span> Compare</button></div>'
        + '<div id="wx_locs_result"></div>');
    if ($.fn.daterangepicker) {
        $('#wx_cmp_start, #wx_cmp_end, #wx_cmp_planting').each(function () {
            $(this).daterangepicker({ singleDatePicker: true, showDropdowns: true, autoUpdateInput: false, locale: { format: 'YYYY-MM-DD' } })
                .on('apply.daterangepicker', function (e, picker) { $(this).val(picker.startDate.format('YYYY-MM-DD')).trigger('change'); });
        });
    }
    if (S.locRows && S.locRows.key === locKey()) renderLocRows();
    else if (S.locRows) $('#wx_locs_result').html('<p class="wx-note"><span class="glyphicon glyphicon-info-sign"></span> The stations, dates or locations changed since the last comparison: press Compare to run it again.</p>');
}

// what a comparison depends on: the ticked locations with their stations, the dates and the crop settings
function locKey() {
    const ids = Object.keys(S.locPick).filter(k => S.locPick[k]).sort();
    const stations = ids.map(id => {
        const l = S.locations.find(x => String(x.id) === String(id));
        if (!l || !(l.station || (S.loc && String(l.id) === String(S.loc.id) && S.station) || S.chosen[l.id])) return id + ':-';
        const p = savedPair(l);
        return id + ':' + stationKey(p.st) + (p.t ? '+' + stationKey(p.t) : '');
    });
    const D = cmpDates();
    return [stations.join(','), D.start, D.end, D.planting, S.crop, JSON.stringify(S.p)].join('|');
}

function loadLocRows() {
    if (!readCmpDates()) return;
    const D = cmpDates();
    const key = locKey();
    const ids = Object.keys(S.locPick).filter(k => S.locPick[k]);
    if (!ids.length) { flash('warning', 'Tick at least one location.'); return; }
    const rows = S.locations.filter(l => (l.station || (S.loc && String(l.id) === String(S.loc.id) && S.station) || S.chosen[l.id]) && ids.includes(String(l.id)))
        .map(l => Object.assign({ l, state: 'loading', highlight: S.loc && l.id === S.loc.id }, savedPair(l)));
    S.locRows = { key, rows };
    renderLocRows();
    let i = 0;
    const next = () => {
        if (!S.locRows || S.locRows.key !== key || i >= rows.length) return Promise.resolve();
        const row = rows[i++];
        return fetchPair(row.st, row.t, D.start, D.end, row.l.id).then(r => {
            const A = analysis(r, D.start, D.end, D.planting);
            row.cov = covariates(A.days, A.rep, S.p, S.crop);
            row.rep = A.rep;
            row.state = 'ok';
        }).catch(e => { row.state = 'error'; row.error = e.message; })
            .then(() => { if (S.tab === 'locations') renderLocRows(); return next(); });
    };
    Promise.all([next(), next()]);
}

function renderLocRows() {
    const rows = S.locRows.rows;
    const ok = rows.filter(r => r.state === 'ok' && r.cov.coverage >= 0.2);
    const loadingN = rows.filter(r => r.state === 'loading').length;
    const table = covTable(rows, r => '<td><b>' + esc(r.l.name) + '</b><div class="wx-small wx-muted">' + esc(stationLabel(r.st)) + (r.t ? ' + ' + esc(r.t.id) : '') + (r.current ? ' (used on this page, not saved)' : '')
        + (r.st.rain_only && !r.t ? '<div class="wx-warn-txt">rain gauge without a temperature station: open the location and save one for temperatures, GDD and RM</div>' : '') + '</div></td>', '<th>Location (station)</th>');
    const D = cmpDates();
    $('#wx_locs_result').html('<div class="wx-card"><div class="wx-card-head"><h4>Environments ' + fmtDate(D.start) + ' to ' + fmtDate(D.end) + ', planting ' + fmtDate(D.planting) + '</h4>'
        + '<span>' + (loadingN ? '<span class="wx-muted wx-small"><span class="glyphicon glyphicon-refresh wx-spin"></span> reading ' + loadingN + ' more... </span>' : '')
        + '<button class="btn btn-default btn-xs" id="wx_locs_csv"' + (loadingN ? ' disabled' : '') + '><span class="glyphicon glyphicon-download-alt"></span> CSV</button></span></div>'
        + (ok.length > 1 ? '<div class="wx-grid2"><div><div class="wx-sub">Rain (mm)</div><div id="wx_lc_rain"></div></div>'
            + '<div><div class="wx-sub">Water balance in the critical stage (mm)</div><div id="wx_lc_crit"></div></div>'
            + '<div><div class="wx-sub">Degree-days</div><div id="wx_lc_gdd"></div></div>'
            + '<div><div class="wx-sub">Heat-stress days</div><div id="wx_lc_heat"></div></div></div>' : '')
        + table + (isMaize() ? rmZonesCard(ok) : '') + '</div>');
    if (ok.length > 1) {
        const items = k => ok.map(r => ({ label: r.l.name, value: num(inUnit(k, r.cov[k])), highlight: r.highlight, faded: r.cov.coverage < 0.8 }));
        catBars('#wx_lc_rain', items('rain'), { unit: 'mm', ref: median(items('rain').map(i => i.value).filter(v => v !== null)) });
        catBars('#wx_lc_crit', items('critical_balance'), { unit: 'mm', color: '#f4a3a3', highlightColor: '#c0392b', ref: 0, refLabel: 'no deficit' });
        catBars('#wx_lc_gdd', items('gdd'), { unit: ddUnit(), color: '#9fdcc3', highlightColor: '#0f8a5f' });
        catBars('#wx_lc_heat', items('heat_days'), { unit: 'days', color: '#f4a3a3', highlightColor: '#c0392b' });
    }
}

// locations grouped in RM bands of 5 days: where each hybrid maturity fits
function rmZonesCard(ok) {
    const groups = {};
    ok.forEach(r => {
        const c = r.cov;
        const frost = /frost/.test(c.rm_end_reason || '');
        const b = !c.rm_temp_ok ? null : frost ? 'RM ' + (c.max_rm === null ? '< ' + RM_STEPS[0] : rmBand(c.max_rm, 5)) : c.rm_ref_days ? 'RM ' + S.p.rmRef + ' matures in ' + daysBand(c.rm_ref_days, 10) : null;
        r.zoneNote = !c.rm_temp_ok ? '' : frost ? 'RM ' + (c.max_rm === null ? '–' : c.max_rm) + ', frost ' + shortDate(c.rm_season_end) : c.rm_ref_days + ' days, no frost';
        (groups[b || 'none'] = groups[b || 'none'] || []).push(r);
    });
    const keys = Object.keys(groups).filter(k => k !== 'none').sort((a, b) => (a.indexOf('matures') - b.indexOf('matures')) || (parseInt(b.replace(/\D+/, ''), 10) - parseInt(a.replace(/\D+/, ''), 10)));
    if (!keys.length) return '';
    return '<h5 class="wx-sub" style="margin-top:16px"><span class="glyphicon glyphicon-th-large"></span> Hybrid maturity zones for these dates</h5>'
        + '<div class="wx-zones">' + keys.map(k => '<div class="wx-zone"><div class="wx-zone-h">' + esc(k) + '</div>'
            + groups[k].map(r => '<div>' + esc(r.l.name) + ' <span class="wx-muted wx-small">' + esc(r.zoneNote) + (r.cov.coverage < 0.8 ? ', partial rain data' : '') + '</span></div>').join('') + '</div>').join('')
        + (groups.none ? '<div class="wx-zone"><div class="wx-zone-h">no temperature data</div>' + groups.none.map(r => '<div>' + esc(r.l.name) + '</div>').join('') + '</div>' : '') + '</div>'
        + '<p class="wx-note">One season only. For zones that hold most years, open each location\'s Past years (RM zone at 80% of the years).</p>';
}

function downloadLocs() {
    const ok = S.locRows.rows.filter(r => r.state === 'ok');
    const D = cmpDates();
    csvDownload('location_environments_' + D.start + '_' + D.end + '.csv',
        ['location_id', 'location', 'station', 'temperature_station', 'start', 'end', 'planting'].concat(covariateColumns().map(c => c[1])),
        ok.map(r => [r.l.id, r.l.name, stationLabel(r.st), r.t ? r.t.network + ' ' + r.t.id : '', D.start, D.end, D.planting].concat(covRow(r.cov))));
}

// ---------------------------------------------------------------- Compare: rain of every nearby source for the same dates
function compareCandidates() {
    const max = Number($('#wx_cmp_max').val()) || 8;
    // the 2 nearest of each network first (so every source is compared), then the nearest others
    const all = S.stations.filter(measuresRain);
    const pick = [];
    ['local'].concat([...new Set(all.map(s => s.network))].filter(n => n !== 'local')).forEach(n => all.filter(s => s.network === n).slice(0, 2).forEach(s => pick.push(s)));
    all.forEach(s => { if (pick.length < max && !pick.includes(s)) pick.push(s); });
    const rain = pick.slice(0, Math.max(max, pick.length)).sort((a, b) => a.distance_km - b.distance_km);
    // stations that measure rain but cannot be read here (INMET without token): shown so the user knows they exist
    S.stations.filter(s => isRainNet(s.network) && !s.ready).slice(0, 2).forEach(s => rain.push(s));
    rain.sort((a, b) => a.distance_km - b.distance_km);
    const air = $('#wx_cmp_air').is(':checked') ? S.stations.filter(s => s.network === 'airport' && s.ready).slice(0, 2) : [];
    if (S.station && !rain.concat(air).some(x => stationKey(x) === stationKey(S.station)) && S.station.ready) rain.unshift(S.station);
    return rain.concat(air);
}

function loadCompare() {
    if (!S.start) return;
    if (!S.stations.length) {
        $('#wx_compare').html('<div class="wx-empty-card"><span class="glyphicon glyphicon-search"></span><h4>Find the stations first</h4><p>Step 1.</p></div>');
        return;
    }
    const cands = compareCandidates();
    const key = cands.map(stationKey).join(',') + '|' + S.start + '|' + S.end;
    if (S.compare && S.compare.key === key) { renderCompare(); return; }
    const seq = S.seq;
    S.compare = { key, rows: cands.map(st => (st.ready ? { st, state: 'loading' } : { st, state: 'error', error: 'measures rain, but its data needs a free key (' + (netConf(st.network).key_config || st.network + '_api_key') + ' in sgn_local.conf)' })) };
    renderCompare();
    let i = 0;
    const next = () => {
        if (i >= S.compare.rows.length) return Promise.resolve();
        const row = S.compare.rows[i++];
        if (row.state !== 'loading') return next();
        return fetchDaily(row.st, S.start, S.end).then(r => { row.state = 'ok'; row.r = r; })
            .catch(e => { row.state = 'error'; row.error = e.message; })
            .then(() => { if (seq === S.seq && S.compare && S.compare.key === key) renderCompare(); return next(); });
    };
    Promise.all([next(), next(), next()]);
}

function renderCompare() {
    const C = S.compare;
    const allDays = [];
    for (let d = S.start; d <= S.end && d <= (S.cfg.today || S.end); d = addDays(d, 1)) allDays.push(d);
    const showDays = allDays.length <= 16;
    const today = S.cfg.today || iso(new Date());
    const pastDays = allDays.filter(d => d < today);    // today is never complete: not counted in the coverage
    C.rows.forEach(row => {
        if (row.state !== 'ok') return;
        const by = {};
        (row.r.days || []).forEach(d => { by[d.date] = d; });
        row.by = by;
        row.amounts = !!row.r.rain_reported;
        row.covered = pastDays.filter(d => by[d] && by[d].complete).length;
        row.coverage = pastDays.length ? row.covered / pastDays.length : (by[today] ? 1 : 0);
        row.total = allDays.reduce((a, d) => a + (by[d] ? (row.amounts ? num(by[d].rain) || 0 : num(by[d].rain_hours) || 0) : 0), 0);
    });
    const amountRows = C.rows.filter(r => r.state === 'ok' && r.amounts && r.covered);
    // a gauge with 0 mm while the others measured rain is suspect (blocked or broken): left out of the references
    amountRows.forEach(r => {
        const o = median(amountRows.filter(x => x !== r && x.total > 0).map(x => x.total / Math.max(1, x.covered)));
        r.suspect = r.covered >= 3 && r.total === 0 && o !== null && o * r.covered >= 5;
    });
    const good = amountRows.filter(r => !r.suspect);
    const full = good.filter(r => r.coverage >= 0.8);
    const others = row => full.filter(r => r !== row).map(r => r.total);
    const ref = median(full.map(r => r.total));
    // days every good gauge has complete: a like-for-like comparison when some gauges keep a short history
    const common = pastDays.filter(d => good.length && good.every(r => r.by[d] && r.by[d].complete));
    const commonTotal = row => common.reduce((a, d) => a + (row.amounts ? num(row.by[d] && row.by[d].rain) || 0 : num(row.by[d] && row.by[d].rain_hours) || 0), 0);
    const showCommon = common.length && common.length < pastDays.length && good.length > 1;
    const refCommon = showCommon ? median(good.map(commonTotal)) : null;
    const maxTotal = Math.max(1, ...C.rows.filter(r => r.state === 'ok' && r.amounts).map(r => r.total));
    C.rows.forEach(row => {
        row.flags = [];
        if (row.state !== 'ok') return;
        if (!row.amounts) { row.flags.push(['info', row.st.network === 'synop' ? 'sends no rain amounts' : 'rain hours only (no mm)']); return; }
        if (!row.covered) { row.flags.push(['bad', 'no data for these dates']); return; }
        const o = median(others(row));
        if (row.suspect) row.flags.push(['bad', 'suspect: 0 mm while the others measured rain']);
        else if (o !== null && o >= 10 && row.coverage >= 0.8 && Math.abs(row.total - o) / o > 0.5) row.flags.push(['warn', (row.total > o ? '+' : '') + Math.round(100 * (row.total - o) / o) + '% vs. the others']);
        if (row.coverage < 0.8) row.flags.push(['warn', row.st.history_hours ? 'only the last ' + row.st.history_hours / 24 + ' days (CEMADEN)' : row.covered + ' of ' + pastDays.length + ' days']);
        if (!row.flags.length) row.flags.push(['ok', 'consistent']);
    });
    // recommended: the nearest gauge with almost every day, consistent with the others
    const rec = C.rows.filter(r => r.state === 'ok' && r.amounts && !r.suspect && r.coverage >= 0.8 && r.flags.every(f => f[0] === 'ok'))
        .sort((a, b) => a.st.distance_km - b.st.distance_km)[0];
    if (rec) rec.flags.unshift(['ok', '★ recommended']);
    const flagHtml = f => '<span class="wx-flag ' + ({ bad: 'wx-flag-heat', warn: 'wx-flag-wind', ok: 'wx-flag-spray', info: 'wx-flag-rain' }[f[0]]) + '">' + esc(f[1]) + '</span>';
    const dayHead = showDays ? allDays.map(d => '<th class="n">' + d.slice(8) + '/' + d.slice(5, 7) + '</th>').join('') : '';
    const rows = C.rows.map(row => {
        const st = row.st;
        const on = stationKey(st) === stationKey(S.station);
        const name = '<td>' + netLabel(st.network) + ' <b>' + esc(st.network === 'cemaden' ? st.code || st.id : st.network === 'hilltop' ? '' : st.id) + '</b> ' + esc(st.network === 'cemaden' ? String(st.name).replace(/^.*\(/, '(') : st.name) + '</td>'
            + '<td class="n">' + (st.approx_position ? '≈ ' : '') + dist(st.distance_km) + '</td>';
        const span = allDays.length * showDays + 4 + (showCommon ? 1 : 0);
        if (row.state === 'loading') return '<tr>' + name + '<td colspan="' + span + '"><span class="glyphicon glyphicon-refresh wx-spin"></span> reading...</td></tr>';
        if (row.state === 'error') return '<tr>' + name + '<td colspan="' + span + '" class="' + (row.st.ready ? 'text-danger ' : 'wx-muted ') + 'wx-small">' + esc(row.error) + '</td></tr>';
        const cells = showDays ? allDays.map(d => {
            const v = row.by[d];
            if (!v) return '<td class="n wx-muted">–</td>';
            const x = row.amounts ? num(v.rain) : num(v.rain_hours);
            return '<td class="n' + (v.complete ? '' : ' wx-muted') + '"' + (v.complete ? '' : ' title="incomplete day"') + '>' + (x === null ? '–' : row.amounts ? x.toFixed(1) : x + ' h') + '</td>';
        }).join('') : '';
        const bar = row.amounts ? '<div style="height:6px;background:#eef2f7;border-radius:3px;margin-top:3px"><div style="height:6px;border-radius:3px;background:' + COLORS.rain + ';width:' + Math.round(100 * row.total / maxTotal) + '%"></div></div>' : '';
        return '<tr class="' + (on ? 'on' : '') + '">' + name + cells
            + '<td class="n"><b>' + (row.amounts ? row.total.toFixed(1) + ' mm' : row.total + ' h') + '</b>' + bar + '</td>'
            + (showCommon ? '<td class="n">' + (row.amounts ? commonTotal(row).toFixed(1) + ' mm' : commonTotal(row) + ' h') + '</td>' : '')
            + '<td class="n">' + Math.round(100 * row.coverage) + '%</td>'
            + '<td><div class="wx-flags">' + row.flags.map(flagHtml).join(' ') + '</div></td>'
            + '<td class="n">' + (on ? '<span class="wx-pill wx-pill-st">in use</span>' : '<button class="btn btn-default btn-xs" data-use="' + esc(stationKey(st)) + '">Use</button>') + '</td></tr>';
    }).join('');
    const loadingN = C.rows.filter(r => r.state === 'loading').length;
    const fmtDay = d => d.slice(8) + '/' + d.slice(5, 7);
    let summary = ref !== null
        ? 'Whole period: median of ' + full.length + ' gauge(s) with complete data <b>' + ref.toFixed(1) + ' mm</b>' + (full.length > 1 ? ' (from ' + Math.min(...full.map(r => r.total)).toFixed(1) + ' to ' + Math.max(...full.map(r => r.total)).toFixed(1) + ' mm)' : '') + '.'
        : (loadingN ? '' : 'No gauge has complete data for every day.');
    if (showCommon) summary += ' Days that all ' + good.length + ' good gauges share (' + fmtDay(common[0]) + ' to ' + fmtDay(common[common.length - 1]) + ', ' + common.length + ' days): median <b>' + refCommon.toFixed(1) + ' mm</b>.';
    const suspects = amountRows.filter(r => r.suspect).length;
    if (suspects) summary += ' ' + suspects + ' suspect gauge(s) left out.';
    if (rec && stationKey(rec.st) !== stationKey(S.station)) summary += ' <b>Recommended: ' + esc(stationLabel(rec.st)) + '</b> (' + dist(rec.st.distance_km) + ', ' + Math.round(100 * rec.coverage) + '% of the days, consistent with its neighbours) <button class="btn btn-success btn-xs" data-use="' + esc(stationKey(rec.st)) + '">Use it</button>';
    $('#wx_compare_body').html('<p>' + summary + (loadingN ? ' <span class="wx-muted">Reading ' + loadingN + ' more...</span>' : '') + '</p>'
        + '<div class="wx-table-wrap"><table class="table table-condensed wx-table"><thead><tr><th>Source</th><th class="n">Distance</th>' + dayHead + '<th class="n">Total</th>' + (showCommon ? '<th class="n" title="Days that every good gauge has complete">Same days (' + common.length + ')</th>' : '') + '<th class="n">Days complete</th><th>Check</th><th></th></tr></thead><tbody>' + rows + '</tbody></table></div>'
        + '<p class="wx-note"><span class="glyphicon glyphicon-info-sign"></span>Rain can change a lot within a few kilometres, especially in thunderstorms: gauges closer to the field and consistent with their neighbours are the best choice. A gauge with 0 mm while the others measured rain is probably blocked or broken. Days in grey are incomplete.</p>');
    $('#wx_compare_title').text(S.start + ' to ' + S.end);
}


// ---------------------------------------------------------------- crop and thresholds
function readParams() {
    const v = (id, d) => { const x = num($(id).val()); return x === null ? d : x; };
    const t = (id, d) => { const x = toCelsius($(id).val()); return x === null ? d : x; };    // typed in the unit shown, kept in C
    S.p = { base: t('#wx_base', DEFAULTS.base), cap: t('#wx_cap', DEFAULTS.cap), heat: t('#wx_heat', DEFAULTS.heat), frost: t('#wx_frost', DEFAULTS.frost), dry: Math.max(2, v('#wx_dry', DEFAULTS.dry)), heavy: v('#wx_heavy', DEFAULTS.heavy),
        kill: t('#wx_kill', DEFAULTS.kill), rm100: v('#wx_rm100', DEFAULTS.rm100), rmDay: Math.max(1, v('#wx_rmday', DEFAULTS.rmDay)), silk: v('#wx_silk', DEFAULTS.silk), rmRef: v('#wx_rmref', DEFAULTS.rmRef) };
    storage('params', { crop: S.crop, p: S.p });
    S.years = null; S.locRows = null;
    renderConcepts();
    refreshAnalysis();
}

function refreshAnalysis() {
    if (S.tab === 'season' && S.daily) renderSeason();
    else if (S.tab === 'trials') loadTrialsTab();
    else if (S.tab === 'years') renderYearsIntro();
    else if (S.tab === 'locations') renderLocationsTab();
}

function renderParams() {
    $('#wx_crop').html(CROPS.map(c => '<option value="' + c.v + '"' + (c.v === S.crop ? ' selected' : '') + '>' + esc(c.label) + '</option>').join(''));
    const tv = c => { const x = toT(c); return x === null ? '' : Math.round(x * 10) / 10; };
    $('#wx_base').val(tv(S.p.base)); $('#wx_cap').val(tv(S.p.cap)); $('#wx_heat').val(tv(S.p.heat)); $('#wx_frost').val(tv(S.p.frost)); $('#wx_dry').val(S.p.dry); $('#wx_heavy').val(S.p.heavy);
    $('#wx_kill').val(tv(S.p.kill));
    $('.wx-tunit').text(tUnit());
    $('#wx_tunit button').each(function () { $(this).toggleClass('on', $(this).data('tunit') === UNITS.temp); }); $('#wx_rm100').val(S.p.rm100); $('#wx_rmday').val(S.p.rmDay); $('#wx_silk').val(S.p.silk); $('#wx_rmref').val(S.p.rmRef);
    $('.wx-rm-params').toggle(S.crop === 'maize');
}

// ---------------------------------------------------------------- events
function bind() {
    $(document)
        // the upload dialog (mason/breeders_toolbox/weather/upload_dialog.mas) stored or deleted a local station
        .on('weather:uploaded', function (e, r) {
            if (!S.loc) return;
            if (r && r.deleted) {
                const gone = 'local:' + String(r.deleted).toUpperCase();
                if (S.station && stationKey(S.station).toUpperCase() === gone) S.station = null;
                if (S.tempStation && stationKey(S.tempStation).toUpperCase() === gone) S.tempStation = null;
                if (S.loc.station && (S.loc.station.network + ':' + S.loc.station.station_id).toUpperCase() === gone) { S.loc.station = null; renderHead(); renderLocations(); }
            }
            S.daily = null; S.dailyKey = ''; S.trialRows = null; S.years = null; S.locRows = null; S.compare = null;
            S.stations = S.stations.filter(x => !isOwnLocal(x));
            S.localStations = [];
            loadLocalStations();
            if (hasCoords(S.loc)) findStations();
        })
        .on('input', '#wx_lsearch', function () { S.lsearch = $(this).val(); renderLocations(); })
        .on('change', '#wx_ltype', function () { S.ltype = $(this).val(); renderLocations(); })
        .on('click', '.wx-seg[data-lfilter]', function () { S.lfilter = $(this).data('lfilter'); renderLocations(); })
        .on('click', '.wx-litem', function () { selectLocation($(this).data('lid')); })
        .on('click', '#wx_unit button', function () {
            const u = $(this).data('unit');
            if (u === S.unit) return;
            const r = num($('#wx_range').val()) || S.range;
            S.range = Math.round(u === 'mi' ? r / KM_PER_MI : r * KM_PER_MI);
            S.unit = u;
            storage('unit', u);
            renderRangeStep(); renderStations(); renderChosen(); renderLocations();
            if (S.lastFind && !findTimer) {
                // same distance in the other unit: the list is still valid, only its labels change
                S.lastFind.range = S.range; S.lastFind.unit = S.unit;
                checkRangeStale();
            }
        })
        .on('click', '#wx_tunit button', function () { setTempUnit(String($(this).data('tunit'))); })
        .on('input', '#wx_range', checkRangeStale)
        .on('keydown', '#wx_range', e => { if (e.key === 'Enter' && !findTimer) findStations(); })
        .on('click', '#wx_find, #wx_find_retry', () => { $('#wx_flash').empty(); findStations(); })
        .on('click', '[data-goto-tab]', function (e) { e.preventDefault(); showTab($(this).data('goto-tab')); })
        .on('click', '[data-choose]', function (e) { e.stopPropagation(); chooseStation(String($(this).data('choose'))); })
        .on('click', '#wx_station_table tbody tr', function () {
            const s = S.stations.find(x => stationKey(x) === String($(this).data('skey')));
            if (s && s.ready) chooseStation(stationKey(s));
        })
        .on('click', '.wx-seg[data-net]', function () { S.netFilter = $(this).data('net'); renderNetFilter(); renderStations(); })
        .on('click', '#wx_save', saveStation)
        .on('click', '#wx_clear', clearStation)
        .on('click', '.wx-tab', function () { showTab($(this).data('tab')); })
        .on('click', '.wx-seg[data-preset]', function () { applyPreset(String($(this).data('preset'))); $('#wx_trial').val(''); applyDates(); })
        .on('change', '#wx_start, #wx_end', () => { S.preset = ''; $('#wx_presets .wx-seg').removeClass('on'); if (!S.plantingSet) setDateInput('#wx_planting', $('#wx_start').val()); })
        .on('change', '#wx_planting', () => { S.plantingSet = true; applyDates(); })
        .on('click', '#wx_apply', applyDates)
        .on('change', '#wx_trial', function () {
            const t = S.trials.find(x => String(x.id) === String($(this).val()));
            if (!t) return;
            useTrialSeason(t);
        })
        .on('click', '[data-trial-season]', function () {
            const t = S.trials.find(x => String(x.id) === String($(this).data('trial-season')));
            if (t) { $('#wx_trial').val(t.id); useTrialSeason(t); }
        })
        .on('change', '#wx_crop', function () {
            S.crop = $(this).val();
            const c = CROPS.find(x => x.v === S.crop);
            if (c) { $('#wx_base').val(Math.round(toT(c.base) * 10) / 10); $('#wx_cap').val(Math.round(toT(c.cap) * 10) / 10); }
            $('.wx-rm-params').toggle(S.crop === 'maize');
            readParams();
        })
        .on('change', '#wx_base, #wx_cap, #wx_heat, #wx_frost, #wx_dry, #wx_heavy, #wx_kill, #wx_rm100, #wx_rmday, #wx_silk, #wx_rmref', readParams)
        .on('click', '#wx_csv', downloadDaily)
        .on('click', '#wx_cov_csv', downloadSeasonCov)
        .on('click', '#wx_trials_csv', downloadTrials)
        .on('change', '[data-lpick]', function () { S.locPick[$(this).data('lpick')] = $(this).is(':checked'); })
        .on('click', '#wx_years_go', loadYears)
        .on('click', '#wx_years_again', () => { S.years = null; renderYearsIntro(); })
        .on('click', '#wx_years_csv', downloadYears)
        .on('click', '#wx_locs_go', loadLocRows)
        .on('click', '#wx_cmp_step3', e => { e.preventDefault(); S.cmp = null; renderLocationsTab(); })
        .on('click', '#wx_locs_csv', downloadLocs)
        .on('change', '#wx_station_select', function () { const k = String($(this).val() || ''); if (k && k !== stationKey(S.station)) chooseStation(k); })
        .on('change', '#wx_temp_station', function () {
            const k = $(this).val();
            S.tempStation = S.stations.find(x => stationKey(x) === k) || (S.tempStation && stationKey(S.tempStation) === k ? S.tempStation : null);
            renderChosen();
            stationChanged();
        })
        .on('click', '[data-use]', function () { chooseStation(String($(this).data('use'))); renderCompare(); })
        .on('change', '#wx_cmp_max, #wx_cmp_air', () => loadCompare());
    let t;
    $(window).on('resize', () => {
        clearTimeout(t);
        t = setTimeout(() => {
            if (S.tab === 'season' && S.daily) renderSeason();
            if (S.tab === 'trials' && S.trialRows) renderTrials();
            if (S.tab === 'years' && S.years) renderYears();
            if (S.tab === 'locations' && S.locRows) renderLocRows();
        }, 250);
    });
}

// Concepts tab: the explanations quote the current settings
function renderConcepts() {
    const p = S.p;
    const set = { base: fmtTh(p.base), cap: fmtTh(p.cap), heat: fmtTh(p.heat), frost: fmtTh(p.frost), kill: fmtTh(p.kill),
        dry: p.dry, heavy: p.heavy + ' mm', rm100: fmtInt(p.rm100), rmday: p.rmDay, rm110: fmtInt(rmToGddF(110, p)), silk: p.silk + '%', rmref: p.rmRef };
    Object.keys(set).forEach(k => $('[data-c="' + k + '"]').text(set[k]));
}

// °C / °F: only the display changes, every value is kept in °C
function setTempUnit(u) {
    if (u !== 'C' && u !== 'F') return;
    UNITS.temp = u;
    storage('tunit', u);
    renderParams();
    if (S.stations.length) renderStations();
    if (S.tab === 'season' && S.daily) renderSeason();
    if (S.tab === 'trials' && S.trialRows) renderTrials();
    if (S.tab === 'years' && S.years) renderYears();
    if (S.tab === 'locations' && S.locRows) renderLocRows();
    renderConcepts();
}

function useTrialSeason(t) {
    const w = trialWindow(t);
    S.start = w.start; S.end = w.end; S.planting = t.planting; S.plantingSet = true; S.preset = '';
    if (w.end !== (t.harvest || w.end)) flash('info', 'The season of ' + esc(t.name) + ' is longer than ' + S.cfg.max_days + ' days: showing its first ' + S.cfg.max_days + ' days.');
    renderDates();
    S.years = null; S.locRows = null;
    showTab('season');
}

export function init() {
    $ = window.jQuery;
    const saved = storage('params');
    if (saved && saved.p) { S.crop = saved.crop || ''; S.p = Object.assign({}, DEFAULTS, saved.p); }
    if (storage('tunit') === 'F') UNITS.temp = 'F';
    renderParams();
    renderConcepts();
    bind();
    initDatePickers();
    call('GET', API + '/config').then(cfg => {
        S.cfg = cfg;
        S.range = cfg.range;
        S.unit = storage('unit') || cfg.unit;
        applyPreset('90');
        return loadLocations();
    }).then(() => {
        const m = window.location.search.match(/[?&]location_id=(\d+)/);
        const tm = window.location.search.match(/[?&]trial_id=(\d+)/);
        if (m && tm) S.pendingTrial = tm[1];
        const first = (m && S.locations.find(l => String(l.id) === m[1])) || S.locations.find(l => l.station);
        if (first) selectLocation(first.id);
        else $('#wx_empty').show();
    }).catch(e => {
        $('#wx_locations').html(alertHtml('danger', esc(e.message)));
        $('#wx_empty').show();
    });
}
