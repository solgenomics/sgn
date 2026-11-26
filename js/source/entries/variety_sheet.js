/*
 * Commercial variety profiles: step-by-step editor (/tools/variety_sheet),
 * profile page (/variety_sheet/<id>) and list (/variety_sheets).
 *
 * The same renderSheet() draws the preview in the editor and the published
 * page, so what the breeder sees is what gets printed.
 */

import '../legacy/leaflet.js';
import { gaugeGrid, diseaseBands, relativeBands, bandRanges, bandAt, fractionOf } from '../modules/gauge.js';

const $ = window.jQuery;
const VERSION = 1;

const RATINGS = ['Resistant', 'Moderately resistant', 'Intermediate', 'Moderately susceptible', 'Susceptible', 'Tolerant', 'Not rated'];
const ACCENTS = ['#1f5f3f', '#2e5e8c', '#8a3b12', '#6b2d6b', '#9a7b0a', '#333333'];
const STEPS = [
    { key: 'accession', title: 'Accession', icon: 'glyphicon-leaf' },
    { key: 'identity', title: 'Commercial name', icon: 'glyphicon-tag' },
    { key: 'performance', title: 'Performance', icon: 'glyphicon-stats' },
    { key: 'traits', title: 'Traits & ratings', icon: 'glyphicon-list-alt' },
    { key: 'photos', title: 'Photos', icon: 'glyphicon-camera' },
    { key: 'publish', title: 'Preview & publish', icon: 'glyphicon-print' },
];

/* ------------------------------------------------------------------ helpers */

function esc(s) {
    return String(s === undefined || s === null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// escaped text with paragraphs, **bold** and *italic*
function rich(s) {
    if (!s) return '';
    return String(s).trim().split(/\n\s*\n/).map(p =>
        '<p>' + esc(p).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/\*(.+?)\*/g, '<em>$1</em>').replace(/\n/g, '<br>') + '</p>'
    ).join('');
}

function inline(s) {
    return esc(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>').replace(/\*(.+?)\*/g, '<em>$1</em>');
}

function num(x, d) {
    if (x === undefined || x === null || x === '' || isNaN(x)) return '\u2013';
    d = (d === undefined || d === null || d === '') ? autoDecimals(x) : +d;
    return Number(x).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
}

function autoDecimals(x) {
    const a = Math.abs(x);
    return a >= 1000 ? 0 : a >= 100 ? 1 : a >= 1 ? 2 : 3;
}

function plural(n, one, many) {
    return num(n, 0) + ' ' + (n == 1 ? one : (many || one + 's'));
}

function listText(items) {
    items = items.filter(Boolean);
    if (items.length <= 1) return items.join('');
    return items.slice(0, -1).join(', ') + ' and ' + items[items.length - 1];
}

function stars(p) {
    if (p === undefined || p === null) return '';
    return p < 0.001 ? '***' : p < 0.01 ? '**' : p < 0.05 ? '*' : '';
}

function better(pct, direction) {
    if (pct === null || pct === undefined) return null;
    if (Math.abs(pct - 100) < 0.05) return 0;
    return (direction === 'lower' ? pct < 100 : pct > 100) ? 1 : -1;
}

function today() {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}

function ajax(url, opts) {
    opts = opts || {};
    return new Promise((resolve, reject) => {
        $.ajax({
            url: url,
            method: opts.method || 'GET',
            data: opts.json ? { data: JSON.stringify(opts.json) } : opts.data,
            dataType: 'json',
            success: r => (r && r.error) ? reject(new Error(r.error)) : resolve(r),
            error: (xhr, status, err) => reject(new Error('Server error: ' + (err || status))),
        });
    });
}

function traitResult(results, traitId) {
    return results && results.traits ? results.traits.find(t => t.trait_id == traitId) : null;
}

/* ------------------------------------------------------------ default profile */

function newSheet(acc) {
    // yield first (it becomes the headline trait), one trait per label, then by number of trials
    const isYield = t => /yield|\byld|^gy_|_gy_|^yld/i.test(t.name + ' ' + t.label) ? (/\/(ha|ac)\b/.test(t.unit || '') ? 2 : 1) : 0;
    const seen = {};
    const traits = (acc.traits || []).filter(t => t.numeric && t.kind !== 'disease')
        .sort((a, b) => isYield(b) - isYield(a) || b.trials - a.trials)
        .filter(t => { const k = (t.label || t.name).toLowerCase(); if (seen[k]) return false; seen[k] = 1; return true; })
        .slice(0, 3);
    const checks = (acc.suggested_checks || []).filter(c => c.control_plots || c.released_variety_name).slice(0, 2);
    if (!checks.length && acc.suggested_checks && acc.suggested_checks.length) checks.push(acc.suggested_checks[0]);
    const s = {
        version: VERSION,
        stock_id: acc.stock_id,
        species: acc.species || '',
        commercial_name: (acc.released_variety_name || [])[0] || '',
        tagline: '',
        market_class: '',
        release_year: String(new Date().getFullYear()),
        developed_by: (acc.evidence.programs || []).join(', '),
        pedigree: publicPedigree(acc.pedigree),
        evidence: acc.evidence,
        evidence_as_of: today(),
        performance: {
            source: 'trials', analysis_id: null, analysis_name: null,
            checks: checks.map(c => ({ stock_id: c.stock_id, name: checkName(c) })),
            primary_check_id: checks.length ? checks[0].stock_id : null,
            traits: traits.map(t => traitConfig(t)),
            year_min: '', year_max: '', results: null,
        },
        ratings: { traits: [], results: null },
        characteristics: [],
        text: { pedigree: '', market: '', production: '', disease: '', recommendations: '', acknowledgements: '', availability: '', contact: '' },
        images: [],
        decisions: (acc.meetings || []).map(decisionLink),
        options: { show_pedigree: true, show_decisions: true, show_map: true, show_pct_chart: true, show_year_chart: true, show_stats: true, show_testing: true, accent: ACCENTS[0], photo_columns: 3, ratings_view: 'gauge', gauge_checks: true, perf_gauges: traits.slice(0, 1).map(t => t.trait_id), perf_gauge_min: 70, perf_gauge_max: 130 },
    };
    s.text.pedigree = autoPedigree(s);
    return s;
}

function traitConfig(t) {
    return { trait_id: t.trait_id, name: t.name, label: t.label || t.name, unit: (t.unit !== undefined && t.unit !== null) ? t.unit : guessUnit(t.name), direction: t.direction || 'higher', decimals: '',
             scale_min: t.scale_minimum, scale_max: t.scale_maximum, kind: t.kind };
}

function guessUnit(name) {
    const m = String(name || '').toLowerCase().replace(/\|.*$/, '');
    const units = [[/kg_?ha\b/, 'kg/ha'], [/kg_?plot\b/, 'kg/plot'], [/(_pct|percent)\b/, '%'], [/_cm\b/, 'cm'], [/_mm\b/, 'mm'], [/_g\b/, 'g'],
                   [/plntha\b/, 'plants/ha'], [/plntplot\b/, 'plants/plot'], [/1to9\b/, '1\u20139'], [/1to5\b/, '1\u20135'], [/bu_?ac\b/, 'bu/ac'], [/cwt_?ac\b/, 'cwt/ac'],
                   [/\(([^)]{1,15})\)\s*$/, null]];
    for (const [re, u] of units) {
        const hit = m.match(re);
        if (hit) return u === null ? hit[1] : u;
    }
    return '';
}

/* ------------------------------------------------------ automatic narrative */

// the experimental name is confidential: a profile only ever shows the commercial name
function sheetName(s) {
    return s.commercial_name || 'This variety';
}

// a check is shown by its released variety name when it has one, never by its experimental name
function checkName(c) {
    return c.public_name || c.released_variety_name || c.name;
}

// the descriptions (tagline and texts) use commercial names only: a check without a
// released variety name is "the check" (results carry released: 1 for the others)
function checkText(s, c, fallback) {
    const id = c && c.stock_id;
    const hit = [(s.performance || {}).results, (s.ratings || {}).results]
        .flatMap(res => (res && res.traits || []).flatMap(t => t.checks || []))
        .find(x => x.stock_id == id && x.released);
    return hit ? hit.name : (fallback || 'the check');
}

// the pedigree the profile keeps: parents and grandparents by released variety name only
function publicPedigree(p) {
    p = p || {};
    const node = n => n ? Object.assign({ stock_id: n.stock_id, released_name: n.released_name || '' },
        n.female ? { female: node(n.female) } : {}, n.male ? { male: node(n.male) } : {}) : undefined;
    const out = {};
    if (p.female) out.female = node(p.female);
    if (p.male) out.male = node(p.male);
    if (p.cross_type) out.cross_type = p.cross_type;
    return out;
}

function autoPedigree(s) {
    // released variety names only: experimental names of the variety and its parents are confidential,
    // so a parent without a released name is just "mother" / "father"
    const p = s.pedigree || {};
    const name = sheetName(s);
    const pub = n => (n && n.released_name) || '';
    const out = [];
    const f = pub(p.female), m = pub(p.male);
    const cross = p.cross_type ? `${p.cross_type} ` : '';
    if (f && m) out.push(`${name} comes from the ${cross}cross ${f} (mother) \u00d7 ${m} (father).`);
    else if (f) out.push(`${name} comes from a ${cross}cross with ${f} as its mother.`);
    else if (m) out.push(`${name} comes from a ${cross}cross with ${m} as its father.`);
    else if (p.female || p.male) out.push(`${name} comes from a ${cross}cross made by the breeding program.`);
    const side = (k, who) => {
        const gp = p[k] ? ['female', 'male'].map(j => pub(p[k][j])).filter((g, i, a) => g && a.indexOf(g) === i) : [];
        return gp.length ? `${listText(gp)} on the ${who}'s side` : '';
    };
    const sides = [side('female', 'mother'), side('male', 'father')].filter(Boolean);
    if (sides.length) out.push(`Its pedigree includes ${sides.join(' and ')}.`);
    return out.join(' ');
}

function autoTesting(s) {
    const e = s.evidence || {};
    if (!e.trials) return '';
    const years = e.year_min && e.year_max ? (e.year_min === e.year_max ? `in ${e.year_min}` : `over ${plural(e.years, 'year')} (${e.year_min}\u2013${e.year_max})`) : '';
    // the same country can be stored with different capitalisation (Brazil, BRAZIL)
    const countries = (e.countries || []).map(c => c.name).filter((c, i, a) => a.findIndex(x => String(x).toLowerCase() === String(c).toLowerCase()) === i);
    return `Tested in ${plural(e.trials, 'trial')} at ${plural(e.locations, 'location')} ${years}${countries.length ? ' in ' + listText(countries.slice(0, 6)) + (countries.length > 6 ? ' and other countries' : '') : ''}, a total of ${num(e.plots, 0)} plots.`;
}

function autoProduction(s) {
    const perf = s.performance || {};
    const res = perf.results;
    if (!res || !res.traits) return '';
    const name = sheetName(s);
    const pc = (perf.checks || []).find(c => c.stock_id == perf.primary_check_id) || (perf.checks || [])[0];
    const out = [];
    perf.traits.forEach(t => {
        const r = traitResult(res, t.trait_id);
        if (!r) return;
        const label = (t.label || t.name).toLowerCase();
        if (res.source === 'analysis') {
            if (r.variety.rank) out.push(`${capital(label)} ranked ${r.variety.rank} of ${r.variety.entries} entries (top ${r.variety.top_pct}%)${r.pct_of_mean ? ', ' + num(r.pct_of_mean, 0) + '% of the trial mean' : ''}.`);
            return;
        }
        const ch = pc ? r.checks.find(c => c.stock_id == pc.stock_id) : null;
        if (ch && ch.shared_trials && ch.pct_of_check !== null) {
            const winPct = Math.round(100 * ch.wins / ch.shared_trials);
            out.push(`${capital(label)} averaged ${num(ch.pct_of_check, 0)}% of ${checkText(s, ch)} in ${plural(ch.shared_trials, 'head-to-head trial')} and was better in ${winPct}% of them${t.direction === 'lower' ? ' (lower is better)' : ''}.`);
        } else if (r.variety.mean !== null) {
            out.push(`${capital(label)} averaged ${num(r.variety.mean, t.decimals)}${t.unit ? ' ' + t.unit : ''} across ${plural(r.variety.trials, 'trial')}.`);
        }
    });
    return out.length ? `${name}: ` + out.join(' ') : '';
}

function autoDisease(s) {
    const groups = {};
    (s.ratings.traits || []).forEach(t => {
        if (!t.rating || t.rating === 'Not rated') return;
        (groups[t.rating] = groups[t.rating] || []).push((t.label || t.name).replace(/ severity| incidence| score/ig, ''));
    });
    const order = ['Resistant', 'Moderately resistant', 'Tolerant', 'Intermediate', 'Moderately susceptible', 'Susceptible'];
    const parts = order.filter(k => groups[k]).map(k => `${k} to ${listText(groups[k].map(x => x.toLowerCase()))}`);
    return parts.length ? parts.join('. ') + '.' : '';
}

/* ------------------------------------------------------- decision meetings */

// what the profile keeps from a meeting (meeting comments stay in the meeting)
function decisionLink(m) {
    return { meeting_id: m.meeting_id, meeting_name: m.meeting_name, date: m.date, location: m.location,
             program: m.program, decision: m.decision, previous_stage: m.previous_stage, new_stage: m.new_stage };
}
function meetingUrl(id) { return '/ajax/decisionmeeting/meeting_report_html?meeting_id=' + encodeURIComponent(id); }
function stageText(d) {
    if (d.previous_stage && d.new_stage && d.previous_stage !== d.new_stage) return `${esc(d.previous_stage)} \u2192 ${esc(d.new_stage)}`;
    return esc(d.new_stage || d.previous_stage || '');
}
function decisionTable(rows, linkMeetings) {
    return '<table class="vs-table vs-decisions"><thead><tr><th>Date</th><th>Meeting</th><th>Program</th><th>Decision</th><th>Stage</th></tr></thead><tbody>' +
        rows.map(d => `<tr><td>${esc(d.date)}</td><td>${linkMeetings ? `<a href="${meetingUrl(d.meeting_id)}" target="_blank">${esc(d.meeting_name)}</a>` : esc(d.meeting_name)}</td>` +
                      `<td>${esc(d.program)}</td><td>${esc(capital(d.decision || ''))}</td><td>${stageText(d)}</td></tr>`).join('') +
        '</tbody></table>';
}

function capital(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

// rating scale of a trait: its scale_min / scale_max, else 1-9 / 1-5 read from the name
function scaleOf(t) {
    const min = parseFloat(t.scale_min), max = parseFloat(t.scale_max);
    if (!isNaN(min) && !isNaN(max) && max > min) return { min, max };
    if (/1to9|1-9/.test(t.name)) return { min: 1, max: 9 };
    if (/1to5|1-5/.test(t.name)) return { min: 1, max: 5 };
    return null;
}
function scaleText(t) { const sc = scaleOf(t); return sc ? `${sc.min}–${sc.max}` : ''; }

// dial settings of a rating trait (modules/gauge.js): resistant end on the right
function ratingDial(t) {
    const sc = scaleOf(t) || { min: 0, max: 1 };
    return { min: sc.min, max: sc.max, reverse: t.direction === 'lower', bands: diseaseBands(), bandsOnFraction: true };
}

// where a mean score sits between the susceptible (0) and resistant (1) ends of the trait scale
function resistanceFrac(t, mean) { return scaleOf(t) ? fractionOf(mean, ratingDial(t)) : null; }

function suggestRating(t, r) {
    const x = r ? resistanceFrac(t, r.variety.mean) : null;
    return x === null ? 'Not rated' : bandAt(bandRanges(ratingDial(t)), x).name;
}

// up to 3 performance traits as dials (modules/gauge.js): % of the main check (trials) or of the
// mean of all entries (stored analysis); green = better, so "lower is better" traits flip the dial
function perfGaugeIds(s) {
    const perf = s.performance || {};
    return ((s.options || {}).perf_gauges || []).filter(id => (perf.traits || []).some(t => t.trait_id == id)).slice(0, 3);
}
function perfGauges(s, pc) {
    const perf = s.performance, res = perf.results, o = s.options || {};
    let min = parseFloat(o.perf_gauge_min), max = parseFloat(o.perf_gauge_max);
    if (!(min < 100)) min = 70;
    if (!(max > 100)) max = 130;
    return gaugeGrid(perfGaugeIds(s).map(id => {
        const t = perf.traits.find(x => x.trait_id == id), r = traitResult(res, id);
        const lower = t.direction === 'lower';
        let value = null, text = '';
        const extra = [];
        if (res && res.source === 'analysis') {
            value = r ? r.pct_of_mean : null;
            if (value !== null && value !== undefined) text = `${num(value, 0)}% of the mean of all entries`;
            if (r && r.variety.rank) extra.push(`rank ${r.variety.rank} of ${r.variety.entries}`);
        } else if (r && pc) {
            const ch = r.checks.find(c => c.stock_id == pc.stock_id);
            value = ch ? ch.pct_of_check : null;
            if (value !== null && value !== undefined) text = `${num(value, 0)}% of ${pc.name}`;
            if (ch && ch.shared_trials) extra.push(`better in ${ch.wins} of ${plural(ch.shared_trials, 'trial')}`);
            r.checks.filter(c => c.stock_id != pc.stock_id && c.pct_of_check !== null && c.pct_of_check !== undefined)
                .forEach(c => extra.push(`${num(c.pct_of_check, 0)}% of ${c.name}`));
        }
        return {
            title: t.label || t.name, min, max, reverse: lower, value,
            bands: relativeBands(min, max, null, { wording: 'better', lowerIsBetter: lower }),
            startLabel: `${lower ? max : min}%`, endLabel: `${lower ? min : max}%`,
            valueText: text, note: extra.join(' · '), emptyText: 'Compute the performance first',
        };
    }));
}

// one dial per disease (modules/gauge.js): reaction classes, the variety's needle, the checks as numbered markers
function ratingGauges(s, rated, checks, withChecks) {
    return gaugeGrid(rated.map(t => {
        const r = traitResult(s.ratings.results, t.trait_id);
        const mean = r ? r.variety.mean : null;
        const hasScale = !!scaleOf(t);
        const marks = [];
        if (withChecks && r && hasScale) checks.forEach((c, i) => {
            const ch = r.checks.find(k => k.stock_id == c.stock_id);
            if (ch && ch.shared_trials && ch.check_mean !== null && ch.check_mean !== undefined) marks.push({ n: i + 1, value: ch.check_mean, label: c.name, valueText: num(ch.check_mean, t.decimals) });
        });
        const sc = scaleText(t);
        const pill = t.rating && t.rating !== 'Not rated' ? `<span class="vs-rating vs-r-${t.rating.replace(/\s+/g, '-').toLowerCase()}">${esc(t.rating)}</span>` : '';
        const score = mean !== null && mean !== undefined ? ` <span class="bb-gauge-val"><b>${num(mean, t.decimals)}</b>${sc ? ` on ${esc(sc)}` : ''}${r && r.variety.trials ? ` · ${plural(r.variety.trials, 'trial')}` : ''}</span>` : '';
        // the breeder has the final word: the needle stays inside the chosen class
        const chosen = diseaseBands().find(b => b.name === t.rating);
        return Object.assign(ratingDial(t), {
            title: t.label || t.name, value: hasScale ? mean : null, clampBand: chosen ? chosen.name : undefined,
            startLabel: 'Susceptible', endLabel: 'Resistant', marks, readout: pill + score, note: t.note || '', emptyText: 'No score on a rating scale',
        });
    }));
}

/* ------------------------------------------- writing the profile from the data */

function mainCheck(s) {
    const perf = s.performance || {};
    return (perf.checks || []).find(c => c.stock_id == perf.primary_check_id) || (perf.checks || [])[0] || null;
}
function lowerFirst(x) { x = String(x || ''); return /^[A-Z][a-z]/.test(x) ? x.charAt(0).toLowerCase() + x.slice(1) : x; }
// '1.2 kg/ha', or '3.5 on a 1–9 scale' when the unit is a rating scale
function unitText(v, unit) {
    if (!unit) return `${v}`;
    const sc = String(unit).match(/^\s*(\d+)\s*(?:-|\u2013|to)\s*(\d+)\s*$/i);
    return sc ? `${v} on a ${sc[1]}\u2013${sc[2]} scale` : `${v} ${unit}`;
}
function withUnit(v, t) { return unitText(v, t.unit); }
// readable label: raw trait names lose a '|person' suffix
function niceLabel(t) { return String(t.label || t.name || '').replace(/\|[^|]*$/, '').trim() || t.name; }

// the variety against the main check on one trait, from the computed numbers
function compareTrait(s, t) {
    const res = (s.performance || {}).results, pc = mainCheck(s);
    if (!res || res.source === 'analysis' || !pc) return null;
    const r = traitResult(res, t.trait_id);
    const ch = r ? r.checks.find(c => c.stock_id == pc.stock_id) : null;
    // fewer than 3 head-to-head trials: described, not judged
    if (!ch || !(ch.shared_trials >= 3) || ch.pct_of_check === null || ch.pct_of_check === undefined) return null;
    const lower = t.direction === 'lower', d = ch.pct_of_check - 100;
    const years = (ch.by_year || []).filter(y => y.variety !== null && y.variety !== undefined && y.check !== null && y.check !== undefined);
    const yearsBetter = years.filter(y => lower ? y.variety < y.check : y.variety > y.check).length;
    const similar = Math.abs(d) < 3, better = !similar && (lower ? d < 0 : d > 0), worse = !similar && !better;
    const sig = ch.p_value !== null && ch.p_value !== undefined && ch.p_value < 0.05;
    // how strongly this trait sells the variety: better, significant, consistent, large
    const strength = better ? (sig ? 2 : 1) + Math.min(Math.abs(d), 30) / 10 + ch.wins / ch.shared_trials : 0;
    return { r, ch, pc, d, lower, similar, better, worse, sig, years, yearsBetter, strength };
}

function cmpPhrase(s, t, c, withValues) {
    const label = lowerFirst(t.label || t.name);
    const vals = withValues ? ` (${withUnit(num(c.ch.variety_mean, t.decimals), t)} vs ${num(c.ch.check_mean, t.decimals)}${c.better || c.worse ? `; better in ${c.ch.wins} of ${plural(c.ch.shared_trials, 'trial')}` : ''})` : '';
    if (c.similar) return `${label} similar to ${checkText(s, c.pc)}${vals}`;
    return `${num(Math.abs(c.d), 0)}% ${c.d > 0 ? 'higher' : 'lower'} ${label} than ${checkText(s, c.pc)}${vals}`;
}

function autoTagline(s) {
    const perf = s.performance || {}, parts = [];
    const cmp = (perf.traits || []).map(t => ({ t, c: compareTrait(s, t) })).filter(x => x.c);
    const head = cmp.find(x => x.t.trait_id == ((perf.traits || [])[0] || {}).trait_id);
    if (head && head.c.better) parts.push(cmpPhrase(s, head.t, head.c));
    else if (head && head.c.similar) parts.push(`${lowerFirst(head.t.label || head.t.name)} on par with ${checkText(s, head.c.pc)}`);
    const extra = cmp.filter(x => x !== head && x.c.better && x.c.sig).sort((a, b) => b.c.strength - a.c.strength)[0];
    if (extra) parts.push(cmpPhrase(s, extra.t, extra.c));
    const res = (s.ratings.traits || []).filter(t => /resistant/i.test(t.rating || '') && !/moderately/i.test(t.rating || ''))
        .map(t => lowerFirst((t.label || t.name).replace(/ severity| incidence| score| rating/ig, '')));
    if (res.length) parts.push(`resistant to ${listText(res.slice(0, 3))}`);
    if (!parts.length) return '';
    return capital(parts.join(', ')) + '.';
}

function autoProductionText(s) {
    const perf = s.performance || {}, res = perf.results, name = sheetName(s);
    if (!res || !res.traits) return '';
    if (res.source === 'analysis') return autoProduction(s);
    const out = [];
    const cmp = (perf.traits || []).map(t => ({ t, c: compareTrait(s, t) }));
    const withC = cmp.filter(x => x.c);
    if (withC.length) {
        const pc = withC[0].c.pc;
        // strengths first, then similar, then weaker traits
        const order = withC.slice().sort((a, b) => (b.c.better - a.c.better) || (a.c.worse - b.c.worse));
        out.push(`Compared with ${checkText(s, pc)} in the same trials, ${name} had ${listText(order.map(x => cmpPhrase(s, x.t, x.c, true)))}.`);
        const head = withC[0];
        if (head.c.better && head.c.sig) out.push(`The ${lowerFirst(head.t.label || head.t.name)} advantage is statistically significant (paired t-test, p ${head.c.ch.p_value < 0.001 ? '< 0.001' : '= ' + num(head.c.ch.p_value, 3)}).`);
        if (head.c.years.length >= 2) {
            const ys = head.c.years.map(y => y.year);
            const span = ys.length > 1 ? `${ys[0]}–${ys[ys.length - 1]}` : ys[0];
            if (head.c.yearsBetter === head.c.years.length) out.push(`It was ahead of ${checkText(s, pc)} for ${lowerFirst(head.t.label || head.t.name)} in every year tested (${span}).`);
            else if (head.c.yearsBetter > 0) out.push(`It was ahead of ${checkText(s, pc)} for ${lowerFirst(head.t.label || head.t.name)} in ${head.c.yearsBetter} of ${head.c.years.length} years (${span}).`);
        }
        // other checks are named only when they have a commercial name
        const others = head.c.r.checks.filter(c => c.stock_id != pc.stock_id && c.released && c.pct_of_check !== null && c.pct_of_check !== undefined);
        if (others.length) out.push(`For ${lowerFirst(head.t.label || head.t.name)} it also reached ${listText(others.map(c => `${num(c.pct_of_check, 0)}% of ${c.name}`))}.`);
    }
    cmp.filter(x => !x.c).forEach(x => {
        const r = traitResult(res, x.t.trait_id);
        if (r && r.variety.mean !== null && r.variety.mean !== undefined) out.push(`${capital(lowerFirst(x.t.label || x.t.name))} averaged ${withUnit(num(r.variety.mean, x.t.decimals), x.t)} over ${plural(r.variety.trials, 'trial')}.`);
    });
    return out.join(' ');
}

function autoRecommendations(s) {
    const out = [], e = s.evidence || {}, perf = s.performance || {};
    const locs = (e.location_list || []).slice(0, 4).map(l => l.name).filter(Boolean);
    if (locs.length) out.push(`Recommended for conditions like those of its test ${locs.length > 1 ? 'locations' : 'location'} (${listText(locs)}${(e.location_list || []).length > 4 ? ' and others' : ''}).`);
    const weak = (s.ratings.traits || []).filter(t => /susceptible/i.test(t.rating || '')).map(t => lowerFirst((t.label || t.name).replace(/ severity| incidence| score| rating/ig, '')));
    if (weak.length) out.push(`Monitor for ${listText(weak)}, to which it is ${weak.length > 1 ? 'not resistant' : (s.ratings.traits.find(t => /susceptible/i.test(t.rating || '')).rating || 'susceptible').toLowerCase()}.`);
    const worse = (perf.traits || []).map(t => ({ t, c: compareTrait(s, t) })).filter(x => x.c && x.c.worse && x.c.sig);
    if (worse.length) out.push(`Take into account its ${listText(worse.map(x => cmpPhrase(s, x.t, x.c)))}.`);
    return out.join(' ');
}

// one trait per family (gy_adj_kgha, gy_fw_kgplot -> gy), per-area units preferred
function traitFamily(t) {
    const n = String(t.name || '').toLowerCase().replace(/\|.*$/, '').trim();
    return /^[a-z0-9]+_/.test(n) ? n.split('_')[0] : String(t.label || n).toLowerCase();
}
function perArea(t) { return /\/(ha|ac|a)\b|kgha|tha\b|_bua|cwt/i.test(`${t.unit || ''} ${t.name}`) ? 1 : 0; }

// editable parts of the profile (step 6): text parts are edited in place, the others open their step
const EDIT_PARTS = {
    identity: { title: 'Name and identity', step: 'identity' },
    tagline: { title: 'Edit the tagline', text: 'tagline', writer: s => autoTagline(s) },
    pedigree: { title: 'Edit the pedigree text', text: 'pedigree', writer: s => autoPedigree(s) },
    market: { title: 'Write the market features', text: 'market' },
    production: { title: 'Edit the production text', text: 'production', writer: s => autoProductionText(s) },
    characteristics: { title: 'Edit the characteristics', step: 'traits' },
    performance: { title: 'Change traits, checks or gauges', step: 'performance' },
    disease: { title: 'Edit the disease text', text: 'disease', writer: s => autoDisease(s) },
    ratings: { title: 'Change the disease traits and classes', step: 'traits' },
    recommendations: { title: 'Edit the recommendations', text: 'recommendations', writer: s => autoRecommendations(s) },
    decisions: { title: 'Choose the decision meetings', step: 'identity' },
    photos: { title: 'Choose the photos', step: 'photos' },
};

// option cards for how the Performance row is shown (same look as the disease choice)
function perfViewCards(view, name) {
    return `<div class="bb-options vs-pview-cards">${[
        ['gauge', 'Gauges only', 'A dial per trait, from worse to better than the main check, with the % of the variety.'],
        ['table', 'Table only', 'The value of the variety and its % of each check in the same trials.'],
        ['both', 'Gauges and table', 'The gauges, and the table below them.']].map(([v, title, text]) => `
        <label class="bb-option ${view === v ? 'on' : ''}"><input type="radio" name="${name}" value="${v}" ${view === v ? 'checked' : ''}>
          <span class="bb-option-title">${title}</span><span class="bb-option-text">${text}</span></label>`).join('')}</div>`;
}

/* ---------------------------------------------------------------- the profile */

function renderSheet(s, opts) {
    opts = opts || {};
    const o = s.options || {};
    const accent = o.accent || ACCENTS[0];
    const perf = s.performance || {};
    const res = perf.results;
    const e = s.evidence || {};
    const name = sheetName(s);
    const pc = (perf.checks || []).find(c => c.stock_id == perf.primary_check_id) || (perf.checks || [])[0];
    let h = `<div class="vs-sheet" style="--vs-accent:${esc(accent)}">`;

    // header
    const ed = !!opts.editable;
    const edBtn = (key, label) => ed ? `<button type="button" class="vs-ed-btn" data-ed="${key}" title="${EDIT_PARTS[key].title}"><span class="glyphicon glyphicon-pencil"></span>${label ? ' ' + label : ''}</button>` : '';
    h += `<header class="vs-head"><div><h1>${esc(name)}${edBtn('identity')}</h1>`;
    if (s.tagline || ed) h += `<div class="vs-tagline${s.tagline ? '' : ' vs-ed-blank'}" data-sec="tagline">${s.tagline ? inline(s.tagline) : '<span class="vs-ed-empty">No tagline yet</span>'}${edBtn('tagline')}</div>`;
    const sub = [];
    if (s.species) sub.push(`<em>${esc(s.species)}</em>`);
    if (s.market_class) sub.push(esc(s.market_class));
    if (s.release_year) sub.push('Released ' + esc(s.release_year));
    h += `<div class="vs-sub">${sub.join(' \u00b7 ')}</div></div>`;
    if (s.developed_by) h += `<div class="vs-dev"><span>Developed by</span>${esc(s.developed_by)}</div>`;
    h += `</header>`;

    // key figures
    const tiles = [];
    if (o.show_testing !== false && e.trials) {
        tiles.push([num(e.trials, 0), e.trials == 1 ? 'trial' : 'trials']);
        tiles.push([num(e.locations, 0), e.locations == 1 ? 'location' : 'locations']);
        if (e.years) tiles.push([num(e.years, 0), (e.years == 1 ? 'year' : 'years') + (e.year_min ? ` <small>${esc(e.year_min)}${e.year_max !== e.year_min ? '\u2013' + esc(e.year_max) : ''}</small>` : '')]);
    }
    if (res && res.traits && perf.traits && perf.traits.length) {
        const t = perf.traits[0];
        const r = traitResult(res, t.trait_id);
        if (r && res.source !== 'analysis' && pc) {
            const ch = r.checks.find(c => c.stock_id == pc.stock_id);
            if (ch && ch.pct_of_check !== null) tiles.push([num(ch.pct_of_check, 0) + '%', `${esc(t.label || t.name)} of ${esc(ch.name)}`, better(ch.pct_of_check, t.direction)]);
        } else if (r && res.source === 'analysis' && r.variety.rank) {
            tiles.push([`#${r.variety.rank}`, `of ${r.variety.entries} for ${esc(t.label || t.name)}`, 1]);
        }
    }
    if (tiles.length) {
        h += '<div class="vs-tiles">' + tiles.map(t => `<div class="vs-tile${t[2] === 1 ? ' vs-good' : t[2] === -1 ? ' vs-bad' : ''}"><b>${t[0]}</b><span>${t[1]}</span></div>`).join('') + '</div>';
    }

    // text sections
    // editable (step 6 of the editor): a pencil per part; empty text parts show as "not written yet"
    const sec = (title, body, key, extra) => {
        if (!body && !(ed && key && EDIT_PARTS[key].text)) return '';
        return `<section class="vs-sec${ed && key ? ' vs-ed-sec' : ''}${body ? '' : ' vs-ed-blank'}"${key ? ` data-sec="${key}"` : ''}><h2>${title}${key ? edBtn(key) : ''}${extra || ''}</h2>` +
            `${body || '<p class="vs-ed-empty">Not written yet: click the pencil to write it.</p>'}</section>`;
    };
    if (o.show_pedigree !== false) h += sec('Pedigree', rich(s.text.pedigree), 'pedigree');
    h += sec('Market features', rich(s.text.market), 'market');
    let prod = rich(s.text.production);
    if (o.show_testing !== false && autoTesting(s)) prod = `<p>${esc(autoTesting(s))}</p>` + prod;
    h += sec('Production features', prod, 'production');

    // characteristics
    const chars = (s.characteristics || []).filter(c => c.label && c.value);
    if (chars.length) {
        h += sec('Characteristics', '<dl class="vs-chars">' + chars.map(c => `<div><dt>${inline(c.label)}</dt><dd>${inline(c.value)}</dd></div>`).join('') + '</dl>', 'characteristics');
    }

    // performance
    if (res && res.traits && perf.traits.length) {
        h += `<section class="vs-sec${ed ? ' vs-ed-sec' : ''}" data-sec="performance"><h2>Performance${edBtn('performance')}</h2>`;
        // o.perf_view: 'both' (gauges + table, default), 'gauge' or 'table'; without gauges the table always shows
        const pview = o.perf_view || 'both', hasG = perfGaugeIds(s).length > 0;
        if (hasG && pview !== 'table') {
            h += perfGauges(s, pc);
            h += `<div class="vs-foot">${res.source === 'analysis' ? '100% = the mean of all entries of the analysis.' : `100% = ${esc(pc ? pc.name : 'the main check')} in the same trials.`} Green = better than ${res.source === 'analysis' ? 'the mean' : 'the check'}; for traits where lower is better the dial is turned so that better is still on the right.</div>`;
        }
        if (!hasG || pview !== 'gauge') h += res.source === 'analysis' ? analysisTable(s) : trialTable(s);
        let charts = '';
        if (o.show_pct_chart !== false && res.source !== 'analysis' && pc) charts += pctChart(s, pc);
        if (o.show_year_chart !== false && res.source !== 'analysis' && pc) charts += yearChart(s, pc);
        if (charts) h += `<div class="vs-charts">${charts}</div>`;
        h += `</section>`;
    }

    // disease / ratings: gauges, a table against the checks, or both (o.ratings_view; older profiles = table)
    const rated = (s.ratings.traits || []).filter(t => t.rating && t.rating !== 'Not rated' || t.note);
    if (rated.length || s.text.disease || ed) {
        let body = rich(s.text.disease);
        if (rated.length) {
            const view = o.ratings_view || 'table';
            if (view !== 'table') {
                body += ratingGauges(s, rated, perf.checks || [], o.gauge_checks !== false);
                body += `<div class="vs-foot">Needle: mean score of the variety in its trials, placed on the trait scale between the susceptible and the resistant end. Coloured bands: reaction classes S susceptible, MS moderately susceptible, I intermediate, MR moderately resistant, R resistant.${o.gauge_checks !== false && (perf.checks || []).length ? ' Numbered markers: the checks, scored in the same trials.' : ''}</div>`;
            }
            if (view !== 'gauge') {
                body += '<table class="vs-table vs-ratings"><thead><tr><th>Disease / trait</th><th>Reaction</th>' +
                    ((perf.checks || []).length ? '<th>Score</th>' + perf.checks.map(c => `<th>${esc(c.name)}</th>`).join('') : '<th>Score</th>') + '</tr></thead><tbody>';
                rated.forEach(t => {
                    const r = traitResult(s.ratings.results, t.trait_id);
                    body += `<tr><td>${esc(t.label || t.name)}${t.note && view === 'table' ? `<div class="vs-note">${inline(t.note)}</div>` : ''}</td><td><span class="vs-rating vs-r-${(t.rating || '').replace(/\s+/g, '-').toLowerCase()}">${esc(t.rating || '')}</span></td>`;
                    body += `<td>${r ? num(r.variety.mean, t.decimals) : '–'}</td>`;
                    (perf.checks || []).forEach(c => {
                        const ch = r ? r.checks.find(x => x.stock_id == c.stock_id) : null;
                        body += `<td>${ch && ch.shared_trials ? num(ch.check_mean, t.decimals) : '–'}</td>`;
                    });
                    body += '</tr>';
                });
                body += '</tbody></table>';
                const scaled = rated.filter(t => t.scale_min !== undefined && t.scale_min !== null && t.scale_max);
                if (scaled.length) body += `<div class="vs-foot">Scores are trial means on the trait scale (${esc(scaled[0].scale_min)}–${esc(scaled[0].scale_max)}${scaled[0].direction === 'lower' ? ', lower is better' : ''}); check scores come from the same trials.</div>`;
            }
        }
        h += sec('Reaction to diseases', body, 'disease', edBtn('ratings', 'ratings'));
    }

    h += sec('Recommendations', rich(s.text.recommendations), 'recommendations');

    // decision trail
    const dec = (s.decisions || []).filter(d => d && d.meeting_id);
    if (o.show_decisions !== false && dec.length) h += sec('Decision history', decisionTable(dec, opts.link_meetings), 'decisions');
    else if (ed && o.show_decisions !== false) h += `<section class="vs-sec vs-ed-sec vs-ed-blank" data-sec="decisions"><h2>Decision history${edBtn('decisions')}</h2><p class="vs-ed-empty">No decision meeting linked: click the pencil to choose the meetings that led to this release.</p></section>`;

    // photos
    // o.show_photos: false hides the photos (they stay chosen)
    const showPhotos = o.show_photos !== false;
    if (ed && showPhotos && !(s.images || []).length) h += `<section class="vs-sec vs-ed-sec vs-ed-blank" data-sec="photos"><h2>Photos${edBtn('photos')}</h2><p class="vs-ed-empty">No photos chosen.</p></section>`;
    if (showPhotos && (s.images || []).length) {
        const cols = o.photo_columns || 3;
        h += `<section class="vs-sec vs-photos-sec${ed ? ' vs-ed-sec' : ''}" data-sec="photos">${ed ? `<h2>Photos${edBtn('photos')}</h2>` : ''}<div class="vs-photos" style="grid-template-columns:repeat(${cols},1fr)">` +
            s.images.map(i => `<figure><img src="${esc(i.url)}" alt="${esc(i.caption || name)}" loading="lazy">${i.caption ? `<figcaption>${inline(i.caption)}</figcaption>` : ''}</figure>`).join('') + '</div></section>';
    }

    // where tested
    if (o.show_map !== false && (e.location_list || []).some(l => l.lat !== null && l.lon !== null && l.lat !== undefined)) {
        h += `<section class="vs-sec vs-map-sec"><h2>Where it was tested</h2><div class="vs-map" data-map="1">${opts.static_map ? '<div class="vs-map-ph">Map of test locations</div>' : ''}</div>`;
        const top = (e.countries || []).slice(0, 8).map(c => `${esc(c.name)} (${plural(c.trials, 'trial')})`);
        if (top.length) h += `<div class="vs-foot">${top.join(' \u00b7 ')}</div>`;
        h += `</section>`;
    }

    // footer
    const foot = [];
    if (s.text.availability) foot.push(`<div><h3>Availability</h3>${rich(s.text.availability)}</div>`);
    if (s.text.contact) foot.push(`<div><h3>Contact</h3>${rich(s.text.contact)}</div>`);
    h += `<footer class="vs-footer">${foot.length ? `<div class="vs-foot-cols">${foot.join('')}</div>` : ''}${rich(s.text.acknowledgements)}`;
    const stamp = [];
    if (res && res.computed_on) stamp.push('performance data as of ' + esc(res.computed_on));
    if (s.evidence_as_of) stamp.push('testing summary as of ' + esc(s.evidence_as_of));
    h += `<div class="vs-stamp">Generated with Breedbase from field trial data${stamp.length ? ' \u00b7 ' + stamp.join(' \u00b7 ') : ''}${opts.url ? ' \u00b7 ' + esc(opts.url) : ''}</div></footer>`;
    h += '</div>';
    return h;
}

function trialTable(s) {
    const perf = s.performance;
    const res = perf.results;
    const o = s.options || {};
    let h = '<table class="vs-table"><thead><tr><th>Trait</th><th>' + esc(sheetName(s)) + '</th>';
    perf.checks.forEach(c => { h += `<th>vs ${esc(c.name)}</th>`; });
    h += '</tr></thead><tbody>';
    perf.traits.forEach(t => {
        const r = traitResult(res, t.trait_id);
        if (!r) return;
        h += `<tr><td>${esc(t.label || t.name)}${t.unit ? ` <span class="vs-unit">(${esc(t.unit)})</span>` : ''}${t.direction === 'lower' ? ' <span class="vs-unit" title="lower is better">\u2193</span>' : ''}</td>`;
        h += `<td><b>${num(r.variety.mean, t.decimals)}</b><div class="vs-small">${plural(r.variety.trials, 'trial')}</div></td>`;
        perf.checks.forEach(c => {
            const ch = r.checks.find(x => x.stock_id == c.stock_id);
            if (!ch || !ch.shared_trials) { h += '<td>\u2013</td>'; return; }
            const b = better(ch.pct_of_check, t.direction);
            h += `<td><b class="${b === 1 ? 'vs-up' : b === -1 ? 'vs-down' : ''}">${num(ch.pct_of_check, 0)}%${o.show_stats !== false ? `<sup>${stars(ch.p_value)}</sup>` : ''}</b>` +
                 `<div class="vs-small">${num(ch.variety_mean, t.decimals)} vs ${num(ch.check_mean, t.decimals)} \u00b7 ${t.direction === 'lower' ? 'lower' : 'ahead'} in ${ch.wins}/${ch.shared_trials}</div></td>`;
        });
        h += '</tr>';
    });
    h += '</tbody></table>';
    h += `<div class="vs-foot">Head-to-head: means of the trials where both were tested; % = ${esc(sheetName(s))} / check \u00d7 100. ` +
         `"ahead in" counts trials where ${esc(sheetName(s))} was better.` + (o.show_stats !== false ? ' Paired t-test: * p&lt;0.05, ** p&lt;0.01, *** p&lt;0.001.' : '') +
         ((perf.year_min || perf.year_max) ? ` Years ${esc(perf.year_min || '\u2026')}\u2013${esc(perf.year_max || '\u2026')}.` : '') + '</div>';
    return h;
}

function analysisTable(s) {
    const perf = s.performance;
    const res = perf.results;
    let h = '<table class="vs-table"><thead><tr><th>Trait</th><th>' + esc(sheetName(s)) + '</th><th>Rank</th><th>% of mean</th>';
    perf.checks.forEach(c => { h += `<th>${esc(c.name)}</th>`; });
    h += '</tr></thead><tbody>';
    perf.traits.forEach(t => {
        const r = traitResult(res, t.trait_id);
        if (!r) return;
        h += `<tr><td>${esc(t.label || t.name)}${t.unit ? ` <span class="vs-unit">(${esc(t.unit)})</span>` : ''}</td><td><b>${num(r.variety.mean, t.decimals)}</b></td>`;
        h += `<td>${r.variety.rank ? r.variety.rank + ' / ' + r.variety.entries : '\u2013'}</td><td>${r.pct_of_mean ? num(r.pct_of_mean, 0) + '%' : '\u2013'}</td>`;
        perf.checks.forEach(c => {
            const ch = r.checks.find(x => x.stock_id == c.stock_id);
            if (!ch || ch.check_mean === null) { h += '<td>\u2013</td>'; return; }
            const b = better(ch.pct_of_check, t.direction);
            h += `<td>${num(ch.check_mean, t.decimals)}<div class="vs-small ${b === 1 ? 'vs-up' : b === -1 ? 'vs-down' : ''}">${num(ch.pct_of_check, 0)}% \u00b7 rank ${ch.rank || '\u2013'}</div></td>`;
        });
        h += '</tr>';
    });
    h += `</tbody></table><div class="vs-foot">Values from the stored analysis "${esc(res.analysis_name || perf.analysis_name || '')}". Rank 1 = best.</div>`;
    return h;
}

function pctChart(s, pc) {
    const perf = s.performance;
    const rows = perf.traits.map(t => {
        const r = traitResult(perf.results, t.trait_id);
        const ch = r ? r.checks.find(c => c.stock_id == pc.stock_id) : null;
        return ch && ch.pct_of_check !== null ? { label: t.label || t.name, pct: ch.pct_of_check, b: better(ch.pct_of_check, t.direction) } : null;
    }).filter(Boolean);
    if (!rows.length) return '';
    const W = 360, rowH = 24, left = 150, right = 44, top = 22;
    const H = top + rows.length * rowH + 8;
    const lo = Math.min(80, ...rows.map(r => Math.floor(r.pct / 10) * 10));
    const hi = Math.max(120, ...rows.map(r => Math.ceil(r.pct / 10) * 10));
    const x = v => left + (v - lo) / (hi - lo) * (W - left - right);
    let g = `<svg viewBox="0 0 ${W} ${H}" class="vs-chart" role="img" aria-label="Percent of ${esc(pc.name)}">`;
    g += `<text x="${left}" y="13" class="vs-ct">% of ${esc(pc.name)}</text>`;
    rows.forEach((r, i) => {
        const y = top + i * rowH;
        const x0 = x(100), x1 = x(r.pct);
        g += `<text x="${left - 6}" y="${y + 15}" text-anchor="end" class="vs-cl">${esc(r.label.length > 26 ? r.label.slice(0, 25) + '\u2026' : r.label)}</text>`;
        g += `<rect x="${Math.min(x0, x1)}" y="${y + 4}" width="${Math.max(1.5, Math.abs(x1 - x0))}" height="${rowH - 9}" rx="2" class="${r.b === 1 ? 'vs-bar-good' : r.b === -1 ? 'vs-bar-bad' : 'vs-bar'}"/>`;
        g += `<text x="${Math.max(x0, x1) + 4}" y="${y + 15}" class="vs-cv">${num(r.pct, 0)}%</text>`;
    });
    g += `<line x1="${x(100)}" x2="${x(100)}" y1="${top - 2}" y2="${H - 4}" class="vs-ref"/></svg>`;
    return `<figure class="vs-fig">${g}<figcaption>Bars to the good side of 100% favour ${esc(sheetName(s))} (direction of each trait taken into account).</figcaption></figure>`;
}

function yearChart(s, pc) {
    const perf = s.performance;
    const t = perf.traits[0];
    const r = traitResult(perf.results, t.trait_id);
    const ch = r ? r.checks.find(c => c.stock_id == pc.stock_id) : null;
    if (!ch || !ch.by_year || ch.by_year.length < 2) return '';
    const data = ch.by_year;
    const W = 360, H = 200, left = 44, bottom = 34, top = 36;
    const peak = Math.max(...data.map(d => Math.max(d.variety || 0, d.check || 0))) || 1;
    const mag = Math.pow(10, Math.floor(Math.log10(peak)));
    const axisTop = Math.ceil(peak / mag * 2) / 2 * mag;
    const max = axisTop * 1.05;
    const bw = (W - left - 10) / data.length;
    const y = v => H - bottom - (v / max) * (H - bottom - top);
    let g = `<svg viewBox="0 0 ${W} ${H}" class="vs-chart" role="img" aria-label="${esc(t.label || t.name)} by year">`;
    g += `<text x="${left}" y="13" class="vs-ct">${esc(t.label || t.name)}${t.unit ? ' (' + esc(t.unit) + ')' : ''} by year</text>`;
    [0, 0.5, 1].forEach(f => {
        const v = axisTop * f;
        g += `<line x1="${left}" x2="${W - 6}" y1="${y(v)}" y2="${y(v)}" class="vs-grid"/><text x="${left - 4}" y="${y(v) + 3}" text-anchor="end" class="vs-cv">${num(v, v >= 100 ? 0 : 1)}</text>`;
    });
    data.forEach((d, i) => {
        const x0 = left + i * bw + bw * 0.14, w = bw * 0.34;
        g += `<rect x="${x0}" y="${y(d.variety)}" width="${w}" height="${H - bottom - y(d.variety)}" class="vs-bar-var"><title>${esc(sheetName(s))} ${d.year}: ${num(d.variety, t.decimals)}</title></rect>`;
        g += `<rect x="${x0 + w + 2}" y="${y(d.check)}" width="${w}" height="${H - bottom - y(d.check)}" class="vs-bar-chk"><title>${esc(pc.name)} ${d.year}: ${num(d.check, t.decimals)}</title></rect>`;
        g += `<text x="${left + i * bw + bw / 2}" y="${H - bottom + 13}" text-anchor="middle" class="vs-cl">${esc(d.year)}</text>`;
        g += `<text x="${left + i * bw + bw / 2}" y="${H - bottom + 25}" text-anchor="middle" class="vs-cv">n=${d.n}</text>`;
    });
    g += `<rect x="${left}" y="19" width="9" height="9" class="vs-bar-var"/><text x="${left + 13}" y="27" class="vs-cv">${esc(sheetName(s).slice(0, 24))}</text>`;
    g += `<rect x="${left + 170}" y="19" width="9" height="9" class="vs-bar-chk"/><text x="${left + 183}" y="27" class="vs-cv">${esc(pc.name.slice(0, 24))}</text>`;
    g += '</svg>';
    return `<figure class="vs-fig">${g}<figcaption>Head-to-head trials per year (n = trials with both).</figcaption></figure>`;
}

function drawMaps(root, s) {
    if (!window.L) return;
    $(root).find('.vs-map[data-map]').each(function () {
        if (this._vsMap) { this._vsMap.remove(); this._vsMap = null; }
        if ($(this).find('.vs-map-ph').length) return;
        const locs = (s.evidence.location_list || []).filter(l => l.lat !== null && l.lon !== null && l.lat !== undefined && !(l.lat == 0 && l.lon == 0));
        if (!locs.length) return;
        try { this._vsMap = makeMap(this, locs, s); } catch (err) { console.log('variety profile map: ' + err); }
    });
}

function makeMap(el, locs, s) {
    {
        const map = window.L.map(el, { scrollWheelZoom: false, attributionControl: true, zoomControl: true, preferCanvas: false });
        window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 12, attribution: '\u00a9 OpenStreetMap' }).addTo(map);
        const max = Math.max(...locs.map(l => l.trials));
        const accent = (s.options && s.options.accent) || ACCENTS[0];
        locs.forEach(l => {
            window.L.circleMarker([l.lat, l.lon], { radius: 4 + 8 * Math.sqrt(l.trials / max), color: '#fff', weight: 1, fillColor: accent, fillOpacity: 0.8 })
                .bindTooltip(`${esc(l.name)}: ${plural(l.trials, 'trial')}`).addTo(map);
        });
        map.fitBounds(window.L.latLngBounds(locs.map(l => [l.lat, l.lon])).pad(0.15));
        return map;
    }
}

/* ------------------------------------------------------------------ editor */

class Editor {
    constructor(root, opts) {
        this.root = $(root);
        this.opts = opts || {};
        this.step = 0;
        this.acc = null;
        this.sheet = null;
        this.sheetId = null;
        this.status = 'draft';
        this.dirty = false;
        this.analysisTraits = {};
        this.nameCheck = null;
        this.nameOptions = { released_variety_name: true, synonym: true };
        this.imageFilter = 'all';
        window.addEventListener('beforeunload', e => { if (this.dirty) { e.preventDefault(); e.returnValue = ''; } });
    }

    async start() {
        this.renderShell();
        if (this.opts.sheet_id) {
            await this.openSheet(this.opts.sheet_id);
        } else if (this.opts.stock_id) {
            await this.loadAccession(this.opts.stock_id);
        } else {
            this.go(0);
        }
    }

    renderShell() {
        this.root.html(`
          <div class="vs-editor">
            <ol class="bb-stepper">${STEPS.map((s, i) => `<li data-step="${i}"><span class="bb-step-num">${i + 1}</span><span class="bb-step-label">${s.title}</span></li>`).join('')}</ol>
            <div class="vs-msg"></div>
            <div class="row">
              <div class="vs-form-col col-lg-7 col-md-12">
                <div class="bb-card vs-panel"></div>
                <div class="vs-nav">
                  <button class="btn btn-default vs-back"><span class="glyphicon glyphicon-chevron-left"></span> Back</button>
                  <span class="vs-nav-right">
                    <span class="vs-save-state"></span>
                    <button class="btn btn-default vs-save-draft" title="Save in Breedbase"><span class="glyphicon glyphicon-floppy-disk"></span> <span class="vs-save-label">Save</span></button>
                    <button class="btn btn-primary vs-next">Next <span class="glyphicon glyphicon-chevron-right"></span></button>
                  </span>
                </div>
              </div>
              <div class="vs-preview-col col-lg-5 hidden-md hidden-sm hidden-xs">
                <div class="bb-side bb-card vs-side">
                  <div class="vs-side-head"><h4><span class="glyphicon glyphicon-eye-open"></span> Live preview</h4><span class="vs-side-name"></span></div>
                  <div class="vs-preview-wrap"><div class="vs-preview"></div></div>
                </div>
              </div>
            </div>
          </div>`);
        this.root.on('click', '.bb-stepper li', e => {
            const i = +$(e.currentTarget).data('step');
            if (i === 0 || this.sheet) this.go(i);
        });
        this.root.on('click', '.vs-back', () => this.go(this.step - 1));
        this.root.on('click', '.vs-next', () => this.go(this.step + 1));
        this.root.on('click', '.vs-save-draft', () => this.save(this.status === 'published' ? 'published' : 'draft'));
    }

    message(html, type) {
        const m = this.root.find('.vs-msg');
        if (!html) { m.empty(); return; }
        m.html(`<div class="alert alert-${type || 'info'} alert-dismissible"><button type="button" class="close" data-dismiss="alert">&times;</button>${html}</div>`);
    }

    markDirty() {
        this.dirty = true;
        this.root.find('.vs-save-state').text('Unsaved changes');
        clearTimeout(this._pv);
        this._pv = setTimeout(() => this.preview(), 250);
    }

    go(i) {
        if (i < 0 || i >= STEPS.length) return;
        if (i > 0 && !this.sheet) { this.message('Choose an accession first.', 'warning'); return; }
        this.step = i;
        this.root.find('.bb-stepper li').each((j, li) => {
            $(li).toggleClass('active', j === i).toggleClass('done', !!this.sheet && j < i).toggleClass('off', !this.sheet && j > 0);
        });
        this.root.find('.vs-back').prop('disabled', i === 0);
        this.root.find('.vs-next').toggle(i < STEPS.length - 1).prop('disabled', !this.sheet);
        this.root.find('.vs-save-draft').toggle(!!this.sheet && !!(this.acc && this.acc.can_edit))
            .find('.vs-save-label').text(this.acc && this.acc.public_profiles && this.status !== 'published' ? 'Save draft' : 'Save');
        const full = STEPS[i].key === 'publish';
        this.root.find('.vs-form-col').toggleClass('col-lg-7', !full).toggleClass('col-lg-12', full);
        this.root.find('.vs-preview-col').toggle(!full && !!this.sheet);
        const panel = this.root.find('.vs-panel');
        panel.off();
        this['step_' + STEPS[i].key](panel);
        this.preview();
        window.scrollTo({ top: this.root.offset().top - 60, behavior: 'smooth' });
    }

    preview() {
        this.root.find('.vs-side-name').text(this.sheet ? (this.sheet.commercial_name || '') : '');
        if (!this.sheet) { this.root.find('.vs-preview').html('<div class="text-muted vs-empty">The profile appears here as you build it.</div>'); return; }
        if (STEPS[this.step].key === 'publish') {
            const el = this.root.find('.vs-full-preview');
            if (this.editing && el.find('.vs-ed-box').length) return;
            this.editing = false;
            el.html(renderSheet(this.sheet, { url: this.sheetId ? location.origin + '/variety_sheet/' + this.sheetId : '', link_meetings: true, editable: !!(this.acc && this.acc.can_edit) }));
            drawMaps(el, this.sheet);
        } else {
            this.root.find('.vs-preview').html(renderSheet(this.sheet, { static_map: true, link_meetings: true }));
        }
    }

    /* ---------------------------------------------- step 1: accession */

    step_accession(p) {
        const acc = this.acc;
        const src = this.accSource || 'meeting';
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">1</span> Choose the accession</h3></div>
          <p class="bb-help">Start from the accession that will become the commercial variety: one selected in a decision meeting, or any accession by name.</p>
          <div class="bb-choices">
            <button type="button" class="bb-choice vs-src-tab ${src === 'meeting' ? 'on' : ''}" data-src="meeting"><span class="glyphicon glyphicon-check"></span>
              <b>Selected in decision meetings</b><span>Accessions advanced or jumped, newest first</span></button>
            <button type="button" class="bb-choice vs-src-tab ${src === 'search' ? 'on' : ''}" data-src="search"><span class="glyphicon glyphicon-search"></span>
              <b>Search any accession</b><span>Experimental name, synonym or released name</span></button>
          </div>
          <div class="vs-src" data-src="meeting" ${src === 'meeting' ? '' : 'style="display:none"'}><div id="vs_meeting_pick"><p class="bb-help"><span class="glyphicon glyphicon-refresh bb-spin"></span> Loading\u2026</p></div></div>
          <div class="vs-src" data-src="search" ${src === 'search' ? '' : 'style="display:none"'}>
            <div class="input-group vs-acc-search">
              <input type="text" class="form-control input-lg" id="vs_accession" placeholder="Accession name" value="${esc(acc ? acc.accession_name : '')}">
              <span class="input-group-btn"><button class="btn btn-primary btn-lg" id="vs_accession_go">Load</button></span>
            </div>
          </div>
          <div id="vs_acc_info">${acc ? this.accessionCard() : ''}</div>
          <h4 class="bb-section"><span class="glyphicon glyphicon-th-list"></span> Variety profiles</h4><div id="vs_sheet_list"><span class="text-muted">Loading\u2026</span></div>`);
        const input = p.find('#vs_accession');
        if (input.autocomplete) input.autocomplete({ source: '/ajax/stock/accession_autocomplete', minLength: 2, select: (e, ui) => { input.val(ui.item.value); this.findAccession(ui.item.value); } });
        p.on('click', '#vs_accession_go', () => this.findAccession(input.val()));
        input.on('keydown', e => { if (e.key === 'Enter') this.findAccession(input.val()); });
        p.on('click', '.vs-src-tab', e => { this.accSourceChosen = true; this.showSource($(e.currentTarget).data('src')); });
        p.on('click', '.vs-open-sheet', e => { e.preventDefault(); this.openSheet($(e.currentTarget).data('id')); });
        p.on('click', '.vs-new-sheet', e => { e.preventDefault(); this.startNewSheet(); });
        p.on('click', '.vs-auto-build', e => { e.preventDefault(); this.autoBuild(); });
        p.on('click', '.vs-del-sheet', e => { e.preventDefault(); this.deleteSheet($(e.currentTarget).data('id')); });
        this.loadSheetList();
        this.loadMeetings();
    }

    showSource(src) {
        this.accSource = src;
        const p = this.root.find('.vs-panel');
        p.find('.vs-src-tab').each((i, b) => $(b).toggleClass('on', $(b).data('src') === src));
        p.find('.vs-src').each((i, d) => $(d).toggle($(d).data('src') === src));
        if (src === 'search') p.find('#vs_accession').trigger('focus');
    }

    // accessions selected (advance / jump) in decision meetings, one row per accession,
    // filtered and paged on the server (scales to any number of meetings): curators only
    pickState() {
        if (!this.pick) this.pick = { q: '', program: '', period: '1y', meeting: null, noProfile: true, release: true, page: 1, programs: null, stages: [] };
        return this.pick;
    }

    async loadMeetings() {
        const el = this.root.find('#vs_meeting_pick');
        if (!el.length) return;
        const f = this.pickState();
        el.off();   // called again by "Clear the filters": no duplicate handlers
        el.html(`
          <div class="vs-pick-filters">
            <input type="search" class="form-control input-sm" id="vs_pick_q" placeholder="Search accession or meeting" value="${esc(f.q)}">
            <select class="form-control input-sm" id="vs_pick_program"><option value="">All programs</option></select>
            <select class="form-control input-sm" id="vs_pick_period">
              ${[['1y', 'Last 12 months'], ['2y', 'Last 2 years'], ['5y', 'Last 5 years'], ['all', 'Any date']].map(([v, l]) => `<option value="${v}" ${f.period === v ? 'selected' : ''}>${l}</option>`).join('')}
            </select>
            <span class="vs-pick-meet"></span>
          </div>
          <div class="vs-pick-checks">
            <label><input type="checkbox" id="vs_pick_noprofile" ${f.noProfile ? 'checked' : ''}> Without a profile only</label>
            <label class="vs-pick-release" style="display:none"><input type="checkbox" id="vs_pick_release" ${f.release ? 'checked' : ''}> Release stages only <span class="bb-muted"></span></label>
          </div>
          <div id="vs_pick_rows"><p class="bb-help"><span class="glyphicon glyphicon-refresh bb-spin"></span> Loading…</p></div>`);
        this.renderPickMeeting();
        this.fillPickFilters();
        const refetch = () => { f.page = 1; this.fetchPicks(); };
        el.find('#vs_pick_q').on('input', e => { f.q = e.target.value.trim(); clearTimeout(this._pq); this._pq = setTimeout(refetch, 300); });
        el.find('#vs_pick_program').on('change', e => { f.program = e.target.value; refetch(); });
        el.find('#vs_pick_period').on('change', e => { f.period = e.target.value; refetch(); });
        el.find('#vs_pick_noprofile').on('change', e => { f.noProfile = e.target.checked; refetch(); });
        el.find('#vs_pick_release').on('change', e => { f.release = e.target.checked; refetch(); });
        el.on('click', '.vs-pick-clear', e => { e.preventDefault(); Object.assign(f, { q: '', program: '', period: 'all', meeting: null, noProfile: false, release: false, page: 1 }); this.loadMeetings(); });
        el.on('click', '.vs-pick-meet-x', e => { e.preventDefault(); f.meeting = null; this.renderPickMeeting(); refetch(); });
        el.on('click', '.vs-pick-meeting', e => {
            e.preventDefault(); e.stopPropagation();
            f.meeting = { id: +$(e.currentTarget).data('mid'), name: $(e.currentTarget).data('mname') + '' };
            f.period = 'all'; el.find('#vs_pick_period').val('all');
            this.renderPickMeeting(); refetch();
        });
        el.on('click', '.vs-pg', e => { e.preventDefault(); const n = +$(e.currentTarget).data('page'); if (n) { f.page = n; this.fetchPicks(); } });
        el.on('click keydown', '.vs-pick-row', e => {
            if (e.type === 'keydown' && e.key !== 'Enter') return;
            e.preventDefault();
            this.loadAccession(+$(e.currentTarget).data('id'));
        });
        await this.fetchPicks();
    }

    // meeting filter: type-ahead over meetings with selections, or a chip once chosen
    renderPickMeeting() {
        const f = this.pickState(), box = this.root.find('.vs-pick-meet');
        if (f.meeting) {
            box.html(`<span class="vs-pick-chip"><span class="glyphicon glyphicon-check"></span> ${esc(f.meeting.name)}
                <a href="${meetingUrl(f.meeting.id)}" target="_blank" title="Meeting report"><span class="glyphicon glyphicon-new-window"></span></a>
                <a href="#" class="vs-pick-meet-x" title="Any meeting">×</a></span>`);
            return;
        }
        box.html('<input type="search" class="form-control input-sm" id="vs_pick_meeting" placeholder="Any meeting (type to find one)">');
        const inp = box.find('#vs_pick_meeting');
        if (!inp.autocomplete) return;
        inp.autocomplete({
            minLength: 0, delay: 250,
            source: (req, resp) => ajax('/ajax/variety_sheet/selection_meetings', { data: { q: req.term } })
                .then(r => resp(r.meetings.map(m => ({ label: `${m.meeting_name}${m.date ? ' · ' + m.date : ''} · ${m.n_selected} selected${m.saved ? '' : ' (open)'}`, value: m.meeting_name, m }))))
                .catch(() => resp([])),
            select: (e, ui) => {
                e.preventDefault();
                f.meeting = { id: ui.item.m.meeting_id, name: ui.item.m.meeting_name };
                f.period = 'all'; this.root.find('#vs_pick_period').val('all');
                f.page = 1; this.renderPickMeeting(); this.fetchPicks();
            },
        }).on('focus', function () { $(this).autocomplete('search', $(this).val()); });
    }

    fillPickFilters() {
        const f = this.pickState();
        if (f.programs) {
            const sel = this.root.find('#vs_pick_program');
            sel.html('<option value="">All programs</option>' + f.programs.map(x => `<option ${x === f.program ? 'selected' : ''}>${esc(x)}</option>`).join(''));
        }
        const rel = this.root.find('.vs-pick-release');
        rel.toggle(f.stages.length > 0).find('.bb-muted').text(f.stages.length ? '(' + f.stages.join(', ') + ')' : '');
    }

    async fetchPicks() {
        const f = this.pickState(), el = this.root.find('#vs_pick_rows');
        const seq = (this._pseq = (this._pseq || 0) + 1);
        const days = { '1y': 365, '2y': 730, '5y': 1826 }[f.period];
        const from = days ? new Date(Date.now() - days * 864e5).toISOString().slice(0, 10) : '';
        const data = { q: f.q, program: f.program, from, meeting_id: f.meeting ? f.meeting.id : '', no_profile: f.noProfile ? 1 : 0,
                       release_only: f.release ? 1 : 0, page: f.page, page_size: 25, with_programs: f.programs ? 0 : 1 };
        el.css('opacity', 0.6);
        let r;
        try { r = await ajax('/ajax/variety_sheet/meeting_selections', { data }); }
        catch (err) {
            if (seq !== this._pseq) return;
            this.root.find('.vs-pick-filters, .vs-pick-checks').hide();
            el.css('opacity', 1).html(`<div class="bb-empty-card"><span class="glyphicon glyphicon-lock"></span><p>${esc(err.message)}</p></div>`);
            if (!this.accSourceChosen && !this.acc) this.showSource('search');
            return;
        }
        if (seq !== this._pseq) return;
        el.css('opacity', 1);
        if (r.programs) f.programs = r.programs;
        f.stages = r.release_stages || [];
        this.fillPickFilters();
        const filtered = f.q || f.program || f.period !== 'all' || f.meeting || f.noProfile || (f.release && f.stages.length);
        if (!r.total) {
            if (!filtered || (f.programs && !f.programs.length)) {
                el.html('<div class="bb-empty-card"><span class="glyphicon glyphicon-blackboard"></span><h4>No accession selected in a meeting yet</h4>' +
                        '<p>Accessions marked <span class="bb-dec bb-dec-advance">Advance</span> or <span class="bb-dec bb-dec-jump">Jump</span> in a <a href="/breeders/meeting" target="_blank">decision meeting</a> appear here. Meanwhile, search any accession.</p></div>');
                if (!this.accSourceChosen && !this.acc) this.showSource('search');
            } else {
                el.html('<div class="bb-empty-card"><span class="glyphicon glyphicon-filter"></span><h4>No selected accession matches these filters</h4>' +
                        '<p><a href="#" class="vs-pick-clear">Clear the filters</a> to see every accession selected in a meeting.</p></div>');
            }
            return;
        }
        const cur = this.acc ? this.acc.stock_id : null;
        const profileChip = x => {
            if (!x.profiles.length) return '<span class="vs-chip vs-chip-none">no profile</span>';
            const pub = x.profiles.find(v => v.status === 'published');
            return pub ? `<span class="vs-chip vs-chip-pub">${esc(pub.commercial_name)} · published</span>` : `<span class="vs-chip vs-chip-draft">${plural(x.profiles.length, 'draft profile')}</span>`;
        };
        const pages = Math.max(1, Math.ceil(r.total / r.page_size)), pg = r.page;
        const first = (pg - 1) * r.page_size + 1, last = Math.min(r.total, pg * r.page_size);
        const nums = [];
        for (let i = 1; i <= pages; i++) if (i === 1 || i === pages || Math.abs(i - pg) <= 1) nums.push(i); else if (nums[nums.length - 1] !== '…') nums.push('…');
        const btn = (n, label, on, dis) => `<button type="button" class="vs-pg ${on ? 'on' : ''}" data-page="${dis ? '' : n}" ${dis ? 'disabled' : ''}>${label}</button>`;
        el.html(`
          <div class="vs-pick-list">${r.rows.map(x => `
            <div class="vs-pick-row bb-rowbox bb-row-${esc(x.decision)} ${x.stock_id == cur ? 'on' : ''}" data-id="${x.stock_id}" tabindex="0" role="button">
              <span class="vs-pick-main"><b>${esc(x.accession)}</b>
                <small>${x.program ? esc(x.program) + ' · ' : ''}<a href="#" class="vs-pick-meeting" data-mid="${x.meeting_id}" data-mname="${esc(x.meeting_name)}" title="Only this meeting">${esc(x.meeting_name)}</a>${x.date ? ' · ' + esc(x.date) : ''}${x.n_meetings > 1 ? ` · in ${x.n_meetings} meetings` : ''}</small></span>
              <span class="bb-dec bb-dec-${esc(x.decision)}">${esc(capital(x.decision))}${x.draft ? ' · draft' : ''}</span>
              <span class="vs-stage-flow">${x.previous_stage ? `<span class="bb-stage">${esc(x.previous_stage)}</span> → ` : ''}${x.new_stage ? `<span class="bb-stage bb-stage-new">${esc(x.new_stage)}</span>` : ''}</span>
              ${profileChip(x)}
              <span class="vs-pick-go">${x.stock_id == cur ? '<span class="glyphicon glyphicon-ok"></span>' : 'Choose <span class="glyphicon glyphicon-chevron-right"></span>'}</span>
            </div>`).join('')}</div>
          <div class="vs-pick-foot"><span class="bb-muted">Accessions ${first}–${last} of ${r.total}</span>
            ${pages > 1 ? `<span class="vs-pager">${btn(pg - 1, '‹', false, pg === 1)}${nums.map(n => n === '…' ? '<span class="bb-muted">…</span>' : btn(n, n, n === pg)).join('')}${btn(pg + 1, '›', false, pg === pages)}</span>` : ''}</div>`);
    }

    accessionCard() {
        const a = this.acc, e = a.evidence, p = a.pedigree || {};
        const parents = (p.female || p.male) ? `${esc(p.female ? p.female.name : '?')} \u00d7 ${esc(p.male ? p.male.name : '?')}` : '<span class="text-muted">not recorded</span>';
        const mine = (a.sheets || []);
        const sel = (a.meetings || []).filter(m => /^(advance|jump)$/i.test(m.decision || '')).slice(-1)[0];
        return `<div class="vs-acc-card">
            <div class="vs-acc-head"><h4><span class="glyphicon glyphicon-leaf"></span> <a href="/stock/${a.stock_id}/view" target="_blank">${esc(a.accession_name)}</a> ${a.species ? `<small><em>${esc(a.species)}</em></small>` : ''}</h4>
              ${sel ? `<span class="bb-dec bb-dec-${esc(sel.decision.toLowerCase())}" title="${esc(sel.meeting_name)} ${esc(sel.date)}">${esc(capital(sel.decision))} \u00b7 ${esc(sel.meeting_name)}</span>` : ''}</div>
            <div class="bb-stats">
              <div class="bb-stat"><div class="v">${num(e.trials, 0)}</div><div class="l">trials</div></div>
              <div class="bb-stat"><div class="v">${num(e.locations, 0)}</div><div class="l">locations</div></div>
              <div class="bb-stat"><div class="v">${num(e.years, 0)}${e.year_min ? ` <small>${e.year_min}\u2013${e.year_max}</small>` : ''}</div><div class="l">years</div></div>
              <div class="bb-stat"><div class="v">${num(a.images.length, 0)}</div><div class="l">photos</div></div>
            </div>
            <table class="table table-condensed vs-kv">
              <tr><th>Pedigree</th><td>${parents}</td></tr>
              <tr><th>Synonyms</th><td>${a.synonyms.length ? esc(a.synonyms.join(', ')) : '<span class="text-muted">none</span>'}</td></tr>
              <tr><th>Released name</th><td>${a.released_variety_name.length ? esc(a.released_variety_name.join(', ')) : '<span class="text-muted">none yet</span>'}</td></tr>
              <tr><th>Programs</th><td>${esc((e.programs || []).join(', ')) || '<span class="text-muted">\u2013</span>'}</td></tr>
              <tr><th>Stored analyses</th><td>${a.analyses.length ? plural(a.analyses.length, 'analysis', 'analyses') : '<span class="text-muted">none</span>'}</td></tr>
            </table>
            ${!e.trials ? '<div class="alert alert-warning">This accession has no field trial data yet. You can still write a profile, but the testing summary and performance tables will be empty.</div>' : ''}
            ${mine.length ? `<p><b>${plural(mine.length, 'profile')} already exist for this accession.</b> Open one below or start a new one.</p>` : ''}
            ${a.can_edit ? `<div class="vs-build-cta">
              <button class="btn btn-primary btn-lg vs-auto-build"><span class="glyphicon glyphicon-flash"></span> ${this.sheet && this.sheet.stock_id == a.stock_id && this.sheet.auto ? 'Build it again from the data' : 'Build the profile for me'}</button>
              <span class="bb-help">Breedbase finds the traits that matter for ${esc(a.accession_name)}, compares it with the checks, scores its disease reactions, picks photos and writes the texts. You then check and edit each part.</span></div>` : ''}
            ${this.sheet && this.sheet.stock_id == a.stock_id ? `<p class="bb-ok"><span class="glyphicon glyphicon-ok"></span> ${this.sheetId ? 'Editing profile #' + this.sheetId : 'New profile started'} \u2014 continue with <b>Next</b>, or build it from the data.</p>` : `<button class="btn btn-default vs-new-sheet"><span class="glyphicon glyphicon-plus"></span> Start an empty profile, step by step</button>`}
          </div>`;
    }

    async loadSheetList() {
        try {
            const r = await ajax('/ajax/variety_sheet/list');
            const el = this.root.find('#vs_sheet_list');
            if (!r.sheets.length) { el.html('<p class="text-muted">No variety profiles yet.</p>'); return; }
            el.html(`<table class="table table-condensed table-hover"><thead><tr><th>Commercial name</th><th>Accession</th><th>Status</th><th>Owner</th><th>Updated</th><th></th></tr></thead><tbody>` +
                r.sheets.map(s => `<tr><td><a href="/variety_sheet/${s.variety_sheet_id}" target="_blank">${esc(s.commercial_name)}</a></td><td>${esc(s.accession_name)}</td>
                  <td><span class="label label-${s.status === 'published' ? 'success' : 'default'}">${s.status === 'published' ? (r.public_profiles ? 'public page' : 'saved') : (r.public_profiles ? 'draft' : 'saved')}</span></td><td>${esc(s.owner || '')}</td><td>${esc(s.modified_date)}</td>
                  <td class="text-right">${s.can_edit ? `<a href="#" class="vs-open-sheet btn btn-xs btn-default" data-id="${s.variety_sheet_id}">Edit</a> <a href="#" class="vs-del-sheet btn btn-xs btn-link text-danger" data-id="${s.variety_sheet_id}">Delete</a>` : ''}</td></tr>`).join('') +
                '</tbody></table>');
        } catch (err) {
            this.root.find('#vs_sheet_list').html(`<span class="text-danger">${esc(err.message)}</span>`);
        }
    }

    async findAccession(name) {
        name = (name || '').trim();
        if (!name) return;
        try {
            const r = await ajax('/ajax/variety_sheet/find_accession', { data: { name } });
            if (r.matches.length > 1) this.message(`'${esc(name)}' matches ${r.matches.map(m => esc(m.name)).join(', ')}; using ${esc(r.matches[0].name)}.`, 'warning');
            await this.loadAccession(r.matches[0].stock_id);
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    async loadAccession(stockId, keepSheet) {
        this.root.find('#vs_acc_info').html('<p class="text-muted"><span class="glyphicon glyphicon-refresh bb-spin"></span> Collecting trials, traits, photos and analyses\u2026</p>');
        try {
            this.acc = await ajax('/ajax/variety_sheet/accession_summary', { data: { stock_id: stockId } });
        } catch (err) { this.message(esc(err.message), 'danger'); this.go(0); return; }
        if (!keepSheet && !(this.sheet && this.sheet.stock_id == stockId)) { this.sheet = null; this.sheetId = null; }
        if (keepSheet && this.sheet) {
            // keep the testing summary current while editing
            this.sheet.evidence = this.acc.evidence;
            this.sheet.evidence_as_of = today();
            this.sheet.pedigree = publicPedigree(this.acc.pedigree);
        }
        if (!this.acc.can_edit) this.message('You can look at variety profiles, but only curators can save them.', 'warning');
        if (!keepSheet && !this.acc.sheets.length && this.acc.can_edit) this.startNewSheet(true);
        this.go(keepSheet ? this.step : 0);
    }

    startNewSheet(silent) {
        this.sheet = newSheet(this.acc);
        this.sheetId = null;
        this.status = 'draft';
        this.dirty = !silent;
        if (!silent) this.go(1); else this.root.find('#vs_acc_info').html(this.accessionCard());
    }

    async openSheet(id) {
        if (this.dirty && !confirm('Discard unsaved changes?')) return;
        try {
            const r = await ajax('/ajax/variety_sheet/get', { data: { sheet_id: id } });
            if (!r.can_edit) { location.href = '/variety_sheet/' + id; return; }
            this.sheet = Object.assign(newSheetSkeleton(), r.sheet);
            this.sheetId = r.variety_sheet_id;
            this.status = r.status;
            this.dirty = false;
            history.replaceState(null, '', '/tools/variety_sheet?sheet_id=' + id);
            this.step = 1;
            await this.loadAccession(r.stock_id, true);
            this.root.find('.vs-save-state').text(`Profile #${id} (${r.status})`);
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    async deleteSheet(id) {
        if (!confirm('Delete this variety profile? This cannot be undone.')) return;
        try {
            await ajax('/ajax/variety_sheet/delete', { method: 'POST', data: { sheet_id: id } });
            if (this.sheetId == id) { this.sheet = null; this.sheetId = null; this.dirty = false; }
            this.loadSheetList();
            if (this.acc) { this.acc.sheets = this.acc.sheets.filter(s => s.variety_sheet_id != id); this.root.find('#vs_acc_info').html(this.accessionCard()); }
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    /* ---------------------------------- build the whole profile from the data */

    async autoBuild() {
        const a = this.acc;
        if (this.sheet && this.dirty && !confirm('Replace the current profile with one built from the data? Unsaved changes are lost.')) return;
        const box = this.root.find('#vs_acc_info');
        const STEPS_B = ['Ranking the traits', 'Comparing with the checks', 'Scoring disease reactions', 'Characteristics and photos', 'Writing the texts'];
        const show = (i, err) => box.html(`<div class="vs-build"><h4><span class="glyphicon glyphicon-flash"></span> Building the profile of ${esc(a.accession_name)}</h4><ol>` +
            STEPS_B.map((t, j) => `<li class="${j < i ? 'done' : j === i ? 'on' : ''}">${j < i ? '<span class="glyphicon glyphicon-ok"></span>' : j === i ? '<span class="glyphicon glyphicon-refresh bb-spin"></span>' : '<span class="glyphicon glyphicon-option-horizontal"></span>'} ${t}</li>`).join('') +
            `</ol>${err ? `<div class="alert alert-danger">${esc(err)}</div>` : ''}</div>`);
        const keepId = this.sheet && this.sheet.stock_id == a.stock_id ? this.sheetId : null;
        const keepStatus = keepId ? this.status : 'draft';
        const s = newSheet(a);
        const info = { built: today(), headline: null, performance: [], diseases: [], characteristics: [], gauges: [], skipped: [], notes: [] };
        try {
            // 1. which traits matter, from the data
            show(0);
            const imp = (await ajax('/ajax/variety_sheet/trait_importance', { data: { stock_id: a.stock_id } })).traits;
            const byId = {};
            (a.traits || []).forEach(t => { byId[t.trait_id] = t; });
            const fam = {};
            imp.forEach(x => {
                const t = byId[x.trait_id];
                if (!t) return;
                const k = traitFamily(t) + '|' + (t.kind === 'disease' ? 'd' : 'a');
                const cur = fam[k];
                // per family: the best, or a per-area version scoring at least 75% of it
                if (!cur || (perArea(t) && !perArea(cur.t) && x.score >= 0.75 * cur.x.score)) fam[k] = { t, x, best: cur ? Math.max(cur.best, x.score) : x.score };
                else cur.best = Math.max(cur.best, x.score);
            });
            const reps = Object.values(fam).sort((p, q) => q.best - p.best);
            const agr = reps.filter(f => f.t.kind !== 'disease' && !f.x.housekeeping && f.t.trials >= 2);
            const dis = reps.filter(f => f.t.kind === 'disease' && scaleOf(traitConfig(f.t)) && f.t.trials >= 2).slice(0, 6);
            reps.filter(f => f.x.housekeeping).slice(0, 3).forEach(f => info.skipped.push({ name: f.t.label || f.t.name, why: 'field-management record' }));
            // judged against the checks: traits whose better direction is known; the others are described
            const judged = agr.filter(f => f.t.direction_known && f.t.trials >= 3);
            const described = agr.filter(f => !f.t.direction_known);
            let perfF = (judged.length ? judged : agr).slice(0, 5);
            const head = perfF.find(f => f.x.yield) || perfF[0];
            if (head) perfF = [head].concat(perfF.filter(f => f !== head));
            s.performance.traits = perfF.map(f => Object.assign(traitConfig(f.t), { label: niceLabel(f.t) }));
            info.headline = head ? { name: head.t.label || head.t.name, why: head.x.reasons } : null;
            info.performance = perfF.map(f => ({ name: f.t.label || f.t.name, why: f.x.reasons }));

            // 2. head-to-head (or the newest stored analysis when there are no field trials)
            show(1);
            const perf = s.performance;
            if (!a.evidence.trials && a.analyses.length) {
                perf.source = 'analysis'; perf.analysis_id = a.analyses[0].analysis_id; perf.analysis_name = a.analyses[0].name;
                info.notes.push(`No field trials: performance comes from the stored analysis ${a.analyses[0].name}.`);
            }
            const calls = [];
            if (perf.traits.length) {
                calls.push(ajax('/ajax/variety_sheet/performance', { method: 'POST', json: {
                    stock_id: s.stock_id, checks: perf.checks.map(c => c.stock_id), traits: perf.traits.map(t => t.trait_id),
                    direction: Object.fromEntries(perf.traits.map(t => [t.trait_id, t.direction])),
                    source: perf.source, analysis_id: perf.analysis_id } }).then(r => { perf.results = r; }));
            }
            show(2);
            s.ratings.traits = dis.map(f => Object.assign(traitConfig(f.t), { label: niceLabel(f.t), rating: '', note: '' }));
            if (s.ratings.traits.length) {
                calls.push(ajax('/ajax/variety_sheet/performance', { method: 'POST', json: {
                    stock_id: s.stock_id, checks: perf.checks.map(c => c.stock_id), traits: s.ratings.traits.map(t => t.trait_id),
                    direction: Object.fromEntries(s.ratings.traits.map(t => [t.trait_id, t.direction])), source: 'trials' } }).then(r => { s.ratings.results = r; }));
            }
            // 4. characteristics: the next important traits, as means over all trials
            const charF = described.filter(f => perfF.indexOf(f) < 0).concat(judged.slice(5)).slice(0, 6);
            const main = mainCheck(s);
            let charRes = null;
            if (charF.length) calls.push(ajax('/ajax/variety_sheet/performance', { method: 'POST', json: { stock_id: s.stock_id, checks: main ? [main.stock_id] : [], traits: charF.map(f => f.t.trait_id), source: 'trials' } }).then(r => { charRes = r; }));
            await Promise.all(calls);

            s.ratings.traits.forEach(t => { const g = suggestRating(t, traitResult(s.ratings.results, t.trait_id)); t.rating = g === 'Not rated' ? '' : g; });
            info.diseases = dis.map(f => ({ name: f.t.label || f.t.name, why: f.x.reasons, rating: (s.ratings.traits.find(t => t.trait_id == f.t.trait_id) || {}).rating || 'no score' }));
            s.options.ratings_view = 'gauge';
            s.options.perf_view = 'both';

            // gauges: the headline trait + the clearest strengths (better, significant, consistent)
            const strengths = perf.traits.slice(1).map(t => ({ t, c: compareTrait(s, t) })).filter(x => x.c && x.c.better).sort((p, q) => q.c.strength - p.c.strength);
            s.options.perf_gauges = perf.traits.length ? [perf.traits[0].trait_id].concat(strengths.slice(0, 2).map(x => x.t.trait_id)) : [];
            info.gauges = s.options.perf_gauges.map(id => (perf.traits.find(t => t.trait_id == id) || {}).label);
            // the clearest strengths come right after the headline in the table
            if (strengths.length) perf.traits = [perf.traits[0]].concat(strengths.map(x => x.t), perf.traits.slice(1).filter(t => !strengths.some(x => x.t === t)));

            show(3);
            s.characteristics = [];
            charF.forEach(f => {
                const r = traitResult(charRes, f.t.trait_id);
                if (!r || r.variety.mean === null || r.variety.mean === undefined) return;
                const unit = f.t.unit || guessUnit(f.t.name);
                const ch = main ? (r.checks || []).find(c => c.stock_id == main.stock_id && c.shared_trials) : null;
                s.characteristics.push({ label: niceLabel(f.t),
                    value: `${unitText(num(r.variety.mean), unit)} (mean of ${plural(r.variety.trials, 'trial')}${ch && ch.check_mean !== null && ch.check_mean !== undefined ? `; ${ch.released ? ch.name : 'the check'} ${num(ch.check_mean)} in the same trials` : ''})` });
                info.characteristics.push({ name: niceLabel(f.t), why: f.x.reasons });
            });
            // photos: the accession's own pictures first, newest first, then plot / plant pictures
            const imgs = (a.images || []).slice().sort((p, q) => (q.own - p.own) || String(q.date || '').localeCompare(String(p.date || '')));
            s.images = imgs.slice(0, 3).map(im => ({ image_id: im.image_id, url: im.url, url_large: im.url_large, caption: im.description && im.description.length < 60 ? im.description : '' }));

            // 5. texts from the numbers
            show(4);
            s.text.pedigree = autoPedigree(s);
            s.text.production = autoProductionText(s);
            s.text.disease = autoDisease(s);
            s.text.recommendations = autoRecommendations(s);
            s.tagline = autoTagline(s);
            if (!s.commercial_name) info.notes.push('No commercial name yet: choose one in step 2 (required to save; the experimental name is never shown on the profile).');
            info.notes.push('Market features are not in the database: write them yourself.');
        } catch (err) {
            show(STEPS_B.length - 1, err.message);
            return;
        }
        s.auto = info;
        this.sheet = s;
        this.sheetId = keepId;
        this.status = keepStatus;
        this.dirty = true;
        this.root.find('.vs-save-state').text('Unsaved changes');
        this.go(STEPS.findIndex(x => x.key === 'publish'));
    }

    // what was built and why, on top of step 6
    buildSummary() {
        const i = this.sheet.auto;
        if (!i) return '';
        const li = x => `<li><b>${esc(x.name)}</b>${x.rating ? ` — ${esc(x.rating)}` : ''}${x.why && x.why.length ? ` <span class="bb-muted">(${esc(x.why.join(', '))})</span>` : ''}</li>`;
        return `<div class="vs-built">
            <div class="vs-built-head"><span><span class="glyphicon glyphicon-flash"></span> <b>Built from the data on ${esc(i.built)}.</b> Check every part: click <span class="glyphicon glyphicon-pencil"></span> to edit it. Texts can be rewritten from the numbers at any time.</span>
              <a href="#" class="vs-built-toggle">${this.builtOpen ? 'hide details' : 'why these traits?'}</a></div>
            <div class="vs-built-body" ${this.builtOpen ? '' : 'style="display:none"'}>
              ${i.performance.length ? `<p><b>Performance traits</b> (most important first; headline = ${esc(i.headline ? i.headline.name : '')}):</p><ul>${i.performance.map(li).join('')}</ul>` : '<p>No agronomic trait with enough data.</p>'}
              ${i.gauges.length ? `<p><b>Gauges:</b> ${esc(i.gauges.filter(Boolean).join(', '))} (the headline trait and the clearest strengths).</p>` : ''}
              ${i.diseases.length ? `<p><b>Disease reactions</b> (class suggested from the trait scale):</p><ul>${i.diseases.map(li).join('')}</ul>` : '<p>No disease trait with a rating scale and enough trials.</p>'}
              ${i.characteristics.length ? `<p><b>Characteristics</b> (described, not judged: which way is better is not clear from the trait): ${esc(i.characteristics.map(x => x.name).join(', '))}.</p>` : ''}
              ${i.skipped.length ? `<p class="bb-muted">Left out as field-management records: ${esc(i.skipped.map(x => x.name).join(', '))}.</p>` : ''}
              ${i.notes.map(n => `<p class="bb-muted">${esc(n)}</p>`).join('')}
            </div></div>`;
    }

    // edit one part of the profile from the preview of step 6
    editPart(key) {
        const part = EDIT_PARTS[key], s = this.sheet;
        if (!part) return;
        if (part.step) { this.go(STEPS.findIndex(x => x.key === part.step)); return; }
        const root = this.root.find('.vs-full-preview');
        const target = key === 'tagline' ? root.find('[data-sec="tagline"]') : root.find(`[data-sec="${key}"]`);
        if (!target.length) return;
        root.find('.vs-ed-box').remove();
        root.find('.vs-ed-hidden').removeClass('vs-ed-hidden');
        const get = () => key === 'tagline' ? (s.tagline || '') : (s.text[part.text] || '');
        const box = $(`<div class="vs-ed-box">
            <textarea class="form-control" rows="${key === 'tagline' ? 2 : 6}">${esc(get())}</textarea>
            <div class="vs-ed-bar">
              <button type="button" class="btn btn-primary btn-sm vs-ed-save">Save</button>
              <button type="button" class="btn btn-default btn-sm vs-ed-cancel">Cancel</button>
              ${part.writer ? '<button type="button" class="btn btn-link btn-sm vs-ed-auto"><span class="glyphicon glyphicon-flash"></span> Rewrite from the data</button>' : ''}
              <span class="bb-muted">*italic*, **bold**${key === 'tagline' ? '' : ', empty line = new paragraph'}</span>
            </div></div>`);
        if (key === 'tagline') { target.children().addClass('vs-ed-hidden'); target.contents().filter(function () { return this.nodeType === 3; }).wrap('<span class="vs-ed-hidden"></span>'); target.append(box); }
        else { target.children().not('h2').addClass('vs-ed-hidden'); target.append(box); }
        const ta = box.find('textarea').trigger('focus');
        box.on('click', '.vs-ed-cancel', () => { this.editing = false; this.preview(); });
        box.on('click', '.vs-ed-auto', () => {
            const txt = part.writer(s);
            if (!txt) { this.message('There is not enough data to write this part.', 'warning'); return; }
            ta.val(txt);
        });
        box.on('click', '.vs-ed-save', () => {
            const v = ta.val().trim();
            if (key === 'tagline') s.tagline = v; else s.text[part.text] = v;
            this.editing = false;
            this.markDirty();
            this.preview();
        });
        this.editing = true;
    }

    /* -------------------------------------------- step 2: identity */

    step_identity(p) {
        const s = this.sheet, a = this.acc;
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">2</span> Commercial name and identity</h3></div>
          <div class="form-group">
            <label for="vs_name">Commercial name</label>
            <input type="text" class="form-control input-lg" id="vs_name" maxlength="100" value="${esc(s.commercial_name)}" placeholder="e.g. Kanestio">
            <div id="vs_name_check" class="vs-name-check"></div>
          </div>
          <div class="panel panel-default"><div class="panel-heading"><b>Save the name in Breedbase</b></div><div class="panel-body">
            <div class="checkbox"><label><input type="checkbox" id="vs_opt_released" ${this.nameOptions.released_variety_name ? 'checked' : ''}> As the <b>released variety name</b> of ${esc(a.accession_name)} <span class="text-muted">\u2014 shown in the accession's "Released variety name" box; the official name.</span></label></div>
            <div class="checkbox"><label><input type="checkbox" id="vs_opt_synonym" ${this.nameOptions.synonym ? 'checked' : ''}> As a <b>synonym</b> <span class="text-muted">\u2014 searches, lists and uploads then find the accession by its commercial name.</span></label></div>
            <p class="help-block">The name is stored when you save the profile. Leave both unticked to keep the name on the profile only (e.g. while the name is still confidential). The experimental name ${esc(a.accession_name)} stays the record's identifier, so trial history is kept.${a.can_save_names ? '' : ' <b>Your role cannot change accession properties</b>; the name will stay on the profile.'}</p>
          </div></div>
          <div class="row">
            <div class="col-sm-8 form-group"><label>Tagline</label><input class="form-control vs-bind" data-k="tagline" value="${esc(s.tagline)}" placeholder="e.g. High-yielding chipping potato with excellent cold-storage chip color"></div>
            <div class="col-sm-4 form-group"><label>Release year</label><input class="form-control vs-bind" data-k="release_year" value="${esc(s.release_year)}"></div>
          </div>
          <div class="row">
            <div class="col-sm-4 form-group"><label>Species</label><input class="form-control vs-bind" data-k="species" value="${esc(s.species)}"></div>
            <div class="col-sm-8 form-group"><label>Market class / segment</label><input class="form-control vs-bind" data-k="market_class" value="${esc(s.market_class)}" placeholder="e.g. Chipping, full season"></div>
          </div>
          <div class="form-group"><label>Developed by</label><input class="form-control vs-bind" data-k="developed_by" value="${esc(s.developed_by)}"></div>
          <div class="form-group"><label>Pedigree</label> <button class="btn btn-xs btn-link vs-auto" data-k="pedigree"><span class="glyphicon glyphicon-flash"></span> Write it from Breedbase</button>
            <label class="checkbox-inline pull-right" style="padding-top:0"><input type="checkbox" class="vs-bind-opt" data-k="show_pedigree" ${s.options.show_pedigree !== false ? 'checked' : ''}> Show pedigree on the profile</label>
            <textarea class="form-control vs-bind-text" data-k="pedigree" rows="4">${esc(s.text.pedigree)}</textarea>
            <p class="help-block">Use *italic* for species names and **bold** for emphasis. Add the story behind the name here too.</p></div>
          <div id="vs_decisions"></div>`);
        this.bindCommon(p);
        this.renderDecisions();
        const nameInput = p.find('#vs_name');
        nameInput.on('input', () => { s.commercial_name = nameInput.val(); this.markDirty(); clearTimeout(this._nc); this._nc = setTimeout(() => this.checkName(), 400); });
        p.on('change', '#vs_opt_released', e => { this.nameOptions.released_variety_name = e.target.checked; });
        p.on('change', '#vs_opt_synonym', e => { this.nameOptions.synonym = e.target.checked; });
        if (!a.can_save_names) p.find('#vs_opt_released, #vs_opt_synonym').prop({ checked: false, disabled: true });
        this.checkName();
    }

    renderDecisions() {
        const s = this.sheet, a = this.acc, el = this.root.find('#vs_decisions');
        if (!Array.isArray(s.decisions)) s.decisions = [];
        const rows = (a.meetings || []).slice();
        s.decisions.forEach(d => { if (!rows.some(m => m.meeting_id == d.meeting_id)) rows.push(d); });
        const linked = id => s.decisions.some(d => d.meeting_id == id);
        let h = `<div class="form-group"><label>Decision meetings</label> ${a.require_meeting ? '<span class="label label-warning">at least one required to publish</span>' : '<small class="text-muted">(optional)</small>'}
            <label class="checkbox-inline pull-right" style="padding-top:0"><input type="checkbox" class="vs-bind-opt" data-k="show_decisions" ${s.options.show_decisions !== false ? 'checked' : ''}> Show decision history on the profile</label>`;
        if (!rows.length) {
            h += `<p class="text-muted">${esc(a.accession_name)} has not been discussed in any decision meeting yet. Record the release decision in <a href="/breeders/meeting" target="_blank">Decision Meetings</a> and it will appear here.</p>`;
        } else {
            h += '<p class="help-block">Tick the meetings that led to this release. They are shown on the profile as its decision history (meeting comments are not).</p>' +
                 '<div class="vs-trait-table-wrap"><table class="table table-condensed"><thead><tr><th></th><th>Date</th><th>Meeting</th><th>Program</th><th>Decision</th><th>Stage</th><th>Comment</th></tr></thead><tbody>' +
                 rows.map(m => `<tr><td><input type="checkbox" class="vs-dec" data-id="${esc(m.meeting_id)}" ${linked(m.meeting_id) ? 'checked' : ''}></td><td>${esc(m.date)}</td>` +
                               `<td><a href="${meetingUrl(m.meeting_id)}" target="_blank">${esc(m.meeting_name)}</a></td><td>${esc(m.program)}</td><td>${m.decision ? `<span class="bb-dec bb-dec-${esc(m.decision.toLowerCase())}">${esc(capital(m.decision))}</span>` : ''}</td>` +
                               `<td>${stageText(m)}</td><td class="small">${esc(m.comment || '')}</td></tr>`).join('') +
                 '</tbody></table></div>';
        }
        el.html(h + '</div>');
        el.off('change.vsdec').on('change.vsdec', '.vs-dec', e => {
            const id = $(e.target).data('id');
            if (e.target.checked) {
                const m = rows.find(r => r.meeting_id == id);
                if (m && !linked(id)) s.decisions.push(decisionLink(m));
            } else {
                s.decisions = s.decisions.filter(d => d.meeting_id != id);
            }
            s.decisions.sort((x, y) => String(x.date || '').localeCompare(String(y.date || '')));
            this.markDirty();
        });
    }

    async checkName() {
        const el = this.root.find('#vs_name_check');
        const name = (this.sheet.commercial_name || '').trim();
        if (!name) { el.html('<span class="text-muted">Type the name the variety will be sold under.</span>'); this.nameCheck = null; return; }
        try {
            const r = await ajax('/ajax/variety_sheet/check_name', { data: { name, stock_id: this.sheet.stock_id } });
            if (name !== (this.sheet.commercial_name || '').trim()) return;
            this.nameCheck = r;
            if (r.conflicts.length) {
                el.html(`<span class="text-danger"><span class="glyphicon glyphicon-warning-sign"></span> Already used by ${r.conflicts.map(c => `<a href="/stock/${c.stock_id}/view" target="_blank">${esc(c.name)}</a> (${esc(c.as)})`).join(', ')}. It can only stay on the profile.</span>`);
                this.root.find('#vs_opt_released, #vs_opt_synonym').prop({ checked: false, disabled: true });
                this.nameOptions = { released_variety_name: false, synonym: false };
            } else {
                const have = [];
                if (r.already_released_name) have.push('released variety name');
                if (r.already_synonym) have.push('synonym');
                if (r.already_name) have.push('accession name');
                el.html(`<span class="text-success"><span class="glyphicon glyphicon-ok"></span> Available.${have.length ? ' Already stored as ' + have.join(' and ') + ' of this accession.' : ''}</span>`);
                if (this.acc.can_save_names) this.root.find('#vs_opt_released, #vs_opt_synonym').prop('disabled', false);
            }
        } catch (err) { el.html(`<span class="text-danger">${esc(err.message)}</span>`); }
    }

    bindCommon(p) {
        const s = this.sheet;
        p.on('input change', '.vs-bind', e => { s[$(e.target).data('k')] = $(e.target).val(); this.markDirty(); });
        p.on('input change', '.vs-bind-text', e => { s.text[$(e.target).data('k')] = $(e.target).val(); this.markDirty(); });
        p.on('input change', '.vs-bind-opt', e => {
            const t = e.target, k = $(t).data('k');
            s.options[k] = t.type === 'checkbox' ? t.checked : (t.type === 'number' ? +t.value : t.value);
            this.markDirty();
        });
        p.on('click', '.vs-auto', e => {
            e.preventDefault();
            const k = $(e.currentTarget).data('k');
            const f = { pedigree: autoPedigree, production: autoProduction, disease: autoDisease }[k];
            const txt = f ? f(s) : '';
            if (!txt) { this.message('There is not enough data yet to write this section automatically.', 'warning'); return; }
            if (s.text[k] && s.text[k].trim() && s.text[k].trim() !== txt && !confirm('Replace the current text?')) return;
            s.text[k] = txt;
            p.find(`.vs-bind-text[data-k="${k}"]`).val(txt);
            this.markDirty();
        });
    }

    /* ----------------------------------------- step 3: performance */

    step_performance(p) {
        const s = this.sheet, a = this.acc, perf = s.performance;
        const years = a.evidence.year_list || [];
        const yearOpts = sel => '<option value="">any</option>' + years.map(y => `<option ${sel == y ? 'selected' : ''}>${esc(y)}</option>`).join('');
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">3</span> Performance against checks</h3></div>
          <div class="vs-evidence well well-sm"><span class="glyphicon glyphicon-info-sign"></span> ${esc(autoTesting(s)) || 'No field trial data for this accession yet.'}</div>
          <div class="form-group">
            <label>Where do the numbers come from?</label>
            <div class="bb-options">
              <label class="bb-option vs-choice ${perf.source !== 'analysis' ? 'on' : ''}"><input type="radio" name="vs_source" value="trials" ${perf.source !== 'analysis' ? 'checked' : ''}>
                <span class="bb-option-title">Field trials, head-to-head</span><span class="bb-option-text">Trial means of the variety and each check in the trials where both were grown: % of check, trials won, paired t-test, results by year.</span></label>
              <label class="bb-option vs-choice ${perf.source === 'analysis' ? 'on' : ''} ${a.analyses.length ? '' : 'disabled'}"><input type="radio" name="vs_source" value="analysis" ${perf.source === 'analysis' ? 'checked' : ''} ${a.analyses.length ? '' : 'disabled'}>
                <span class="bb-option-title">Stored analysis</span><span class="bb-option-text">${a.analyses.length ? 'BLUPs/BLUEs from a saved analysis: value, rank among all entries, % of the trial mean.' : 'No stored analysis includes this accession.'}</span></label>
            </div>
          </div>
          <div class="form-group vs-analysis-row" style="${perf.source === 'analysis' ? '' : 'display:none'}">
            <label>Analysis</label>
            <select class="form-control" id="vs_analysis"><option value="">Choose\u2026</option>${a.analyses.map(x => `<option value="${x.analysis_id}" ${perf.analysis_id == x.analysis_id ? 'selected' : ''}>${esc(x.name)} (${plural(x.traits, 'trait')})</option>`).join('')}</select>
          </div>
          <div class="row vs-years-row" style="${perf.source === 'analysis' ? 'display:none' : ''}">
            <div class="col-xs-6 form-group"><label>From year</label><select class="form-control" id="vs_year_min">${yearOpts(perf.year_min)}</select></div>
            <div class="col-xs-6 form-group"><label>To year</label><select class="form-control" id="vs_year_max">${yearOpts(perf.year_max)}</select></div>
          </div>
          <h4 class="bb-section">Checks <small>tick up to 4 varieties to compare with</small></h4>
          <div class="vs-check-legend">
            <span><input type="checkbox" checked disabled> compared in the performance table</span>
            <span><b class="vs-star on">\u2605</b> <b>main check</b>: the headline %, the gauges and the charts use it (click \u2606 on another check to change it)</span>
            <span><span class="vs-tag vs-tag-ctl">check in trials</span> planted as a check plot in the trials</span>
            <span><span class="vs-tag vs-tag-rel">released</span> has a released variety name</span>
            <span><span class="vs-check-n">8 shared trials</span> trials where both were tested (more = fairer comparison)</span>
          </div>
          <div id="vs_checks"></div>
          <div class="input-group input-group-sm vs-add-check"><input class="form-control" id="vs_add_check" placeholder="Add another check by name"><span class="input-group-btn"><button class="btn btn-default" id="vs_add_check_btn">Add</button></span></div>
          <h4 class="bb-section">Traits <small>tick the traits to show; the first ticked trait is the headline trait</small></h4>
          <div id="vs_traits"></div>
          <h4 class="bb-section">Gauges <small>up to 3 traits shown as dials at the top of Performance, side by side</small></h4>
          <div id="vs_perf_gauges"></div>
          <div class="vs-compute-bar"><button class="btn btn-primary" id="vs_compute"><span class="glyphicon glyphicon-stats"></span> Compute performance</button> <span id="vs_compute_state" class="text-muted"></span></div>
          <div id="vs_results"></div>`);
        this.renderChecks();
        this.renderTraits();
        this.renderResultsSummary();

        p.on('change', 'input[name=vs_source]', e => {
            perf.source = e.target.value;
            p.find('.vs-choice').removeClass('on'); $(e.target).closest('.vs-choice').addClass('on');
            p.find('.vs-analysis-row').toggle(perf.source === 'analysis');
            p.find('.vs-years-row').toggle(perf.source !== 'analysis');
            perf.results = null;
            if (perf.source === 'analysis' && perf.analysis_id) this.loadAnalysisTraits(perf.analysis_id); else this.renderTraits();
            this.renderResultsSummary(); this.markDirty();
        });
        p.on('change', '#vs_analysis', e => {
            perf.analysis_id = e.target.value ? +e.target.value : null;
            const an = a.analyses.find(x => x.analysis_id == perf.analysis_id);
            perf.analysis_name = an ? an.name : null;
            perf.results = null;
            if (perf.source === 'analysis') perf.traits = [];
            if (perf.analysis_id) this.loadAnalysisTraits(perf.analysis_id); else this.renderTraits();
            this.markDirty();
        });
        p.on('change', '#vs_year_min', e => { perf.year_min = e.target.value; this.markDirty(); });
        p.on('change', '#vs_year_max', e => { perf.year_max = e.target.value; this.markDirty(); });
        p.on('click', '#vs_compute', () => this.computePerformance());
        const ac = p.find('#vs_add_check');
        if (ac.autocomplete) ac.autocomplete({ source: '/ajax/stock/accession_autocomplete', minLength: 2 });
        p.on('click', '#vs_add_check_btn', () => this.addCheck(ac.val()));
        if (perf.source === 'analysis' && perf.analysis_id) this.loadAnalysisTraits(perf.analysis_id);
    }

    renderChecks() {
        const perf = this.sheet.performance;
        const sugg = (this.acc.suggested_checks || []).slice();
        perf.checks.forEach(c => { if (!sugg.find(x => x.stock_id == c.stock_id)) sugg.unshift({ stock_id: c.stock_id, name: c.name, public_name: c.name, shared_trials: null }); });
        const el = this.root.find('#vs_checks');
        if (!sugg.length) { el.html('<p class="text-muted">No accessions were tested alongside this one. Add a check by name.</p>'); return; }
        el.html(`<div class="vs-check-list">` + sugg.map(c => {
            const on = perf.checks.some(x => x.stock_id == c.stock_id);
            const primary = perf.primary_check_id == c.stock_id;
            return `<label class="vs-check ${on ? 'on' : ''} ${primary ? 'main' : ''}"><input type="checkbox" data-id="${c.stock_id}" data-name="${esc(checkName(c))}" ${on ? 'checked' : ''}>
                <span class="vs-check-body">
                  <span class="vs-check-name">${esc(c.name)}${c.released_variety_name ? ` <small>(${esc(c.released_variety_name)})</small>` : ''}</span>
                  <span class="vs-check-tags">${c.control_plots ? '<span class="vs-tag vs-tag-ctl" title="Used as a check plot in the trials">check in trials</span>' : ''}${c.released_variety_name ? '<span class="vs-tag vs-tag-rel" title="Has a released variety name">released</span>' : ''}<span class="vs-check-n" title="Trials where this check and the variety were both tested">${c.shared_trials !== null && c.shared_trials !== undefined ? plural(c.shared_trials, 'shared trial') : ''}</span></span>
                </span>
                <a href="#" class="vs-star ${primary ? 'on' : ''}" data-id="${c.stock_id}" title="${primary ? 'Main check: used for the headline %, the gauges and the charts' : 'Click to make this the main check'}">${primary ? '\u2605' : '\u2606'}</a></label>`;
        }).join('') + '</div>');
        el.off().on('change', 'input[type=checkbox]', e => {
            const id = +$(e.target).data('id');
            if (e.target.checked) {
                if (perf.checks.length >= 4) { e.target.checked = false; this.message('Up to 4 checks keep the profile readable.', 'warning'); return; }
                perf.checks.push({ stock_id: id, name: $(e.target).data('name') + '' });
                if (!perf.primary_check_id) perf.primary_check_id = id;
            } else {
                perf.checks = perf.checks.filter(c => c.stock_id != id);
                if (perf.primary_check_id == id) perf.primary_check_id = perf.checks.length ? perf.checks[0].stock_id : null;
            }
            this.renderChecks(); this.markDirty(); this.flagStale();
        }).on('click', '.vs-star', e => {
            e.preventDefault();
            const id = +$(e.currentTarget).data('id');
            if (!perf.checks.some(c => c.stock_id == id)) {
                if (perf.checks.length >= 4) return;
                const c = sugg.find(x => x.stock_id == id);
                perf.checks.push({ stock_id: id, name: checkName(c) });
                this.flagStale();
            }
            perf.primary_check_id = id;
            this.renderChecks(); this.markDirty();
        });
    }

    async addCheck(name) {
        name = (name || '').trim();
        if (!name) return;
        try {
            const r = await ajax('/ajax/variety_sheet/find_accession', { data: { name } });
            const m = r.matches[0];
            const perf = this.sheet.performance;
            if (m.stock_id == this.sheet.stock_id) { this.message('That is the variety itself.', 'warning'); return; }
            if (!perf.checks.some(c => c.stock_id == m.stock_id)) {
                if (perf.checks.length >= 4) { this.message('Up to 4 checks keep the profile readable.', 'warning'); return; }
                perf.checks.push({ stock_id: m.stock_id, name: checkName(m) });
                if (!perf.primary_check_id) perf.primary_check_id = m.stock_id;
            }
            this.root.find('#vs_add_check').val('');
            this.renderChecks(); this.markDirty(); this.flagStale();
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    async loadAnalysisTraits(id) {
        if (!this.analysisTraits[id]) {
            try { this.analysisTraits[id] = (await ajax('/ajax/variety_sheet/analysis_traits', { data: { analysis_id: id } })).traits; }
            catch (err) { this.message(esc(err.message), 'danger'); return; }
        }
        this.renderTraits();
    }

    availableTraits() {
        const perf = this.sheet.performance;
        if (perf.source === 'analysis') return perf.analysis_id ? (this.analysisTraits[perf.analysis_id] || []) : [];
        return (this.acc.traits || []).filter(t => t.numeric);
    }

    renderTraits() {
        this.renderGaugePick();
        const perf = this.sheet.performance;
        const el = this.root.find('#vs_traits');
        const avail = this.availableTraits();
        if (perf.source === 'analysis' && !perf.analysis_id) { el.html('<p class="text-muted">Choose an analysis first.</p>'); return; }
        if (!avail.length) { el.html('<p class="text-muted">No numeric traits available.</p>'); return; }
        const chosen = perf.traits.map(t => t.trait_id);
        const ordered = perf.traits.map(t => avail.find(a => a.trait_id == t.trait_id) || t).concat(avail.filter(a => chosen.indexOf(a.trait_id) < 0));
        el.html(`<div class="vs-trait-table-wrap"><table class="table table-condensed vs-trait-table"><thead><tr><th></th><th>Trait</th><th>Label on the profile</th><th>Unit</th><th>Better</th><th>${perf.source === 'analysis' ? 'Entries' : 'Trials'}</th><th></th></tr></thead><tbody>` +
            ordered.map(t => {
                const cfg = perf.traits.find(x => x.trait_id == t.trait_id);
                const on = !!cfg;
                const c = cfg || traitConfig(t);
                return `<tr class="${on ? 'on' : ''}" data-id="${t.trait_id}">
                  <td><input type="checkbox" class="vs-t-on" ${on ? 'checked' : ''}></td>
                  <td class="vs-t-name" title="${esc(t.definition || '')}">${esc(t.name)}${t.kind === 'disease' ? ' <span class="label label-warning">disease</span>' : ''}</td>
                  <td><input class="form-control input-sm vs-t-f" data-f="label" value="${esc(c.label)}" ${on ? '' : 'disabled'}></td>
                  <td><input class="form-control input-sm vs-t-f vs-t-unit" data-f="unit" value="${esc(c.unit)}" ${on ? '' : 'disabled'}></td>
                  <td><select class="form-control input-sm vs-t-f" data-f="direction" ${on ? '' : 'disabled'}><option value="higher" ${c.direction !== 'lower' ? 'selected' : ''}>higher</option><option value="lower" ${c.direction === 'lower' ? 'selected' : ''}>lower</option></select></td>
                  <td>${num(perf.source === 'analysis' ? t.accessions : t.trials, 0)}</td>
                  <td class="vs-t-move">${on ? '<a href="#" class="vs-t-up" title="Move up">\u25b2</a>' : ''}</td></tr>`;
            }).join('') + '</tbody></table></div>');
        el.off().on('change', '.vs-t-on', e => {
            const id = +$(e.target).closest('tr').data('id');
            if (e.target.checked) {
                if (perf.traits.length >= 12) { e.target.checked = false; this.message('Up to 12 traits in the performance table.', 'warning'); return; }
                perf.traits.push(traitConfig(avail.find(t => t.trait_id == id)));
            } else perf.traits = perf.traits.filter(t => t.trait_id != id);
            this.renderTraits(); this.markDirty(); this.flagStale();
        }).on('input change', '.vs-t-f', e => {
            const id = +$(e.target).closest('tr').data('id');
            const cfg = perf.traits.find(t => t.trait_id == id);
            if (!cfg) return;
            const f = $(e.target).data('f');
            cfg[f] = $(e.target).val();
            if (f === 'direction') this.flagStale();
            this.markDirty();
        }).on('click', '.vs-t-up', e => {
            e.preventDefault();
            const id = +$(e.currentTarget).closest('tr').data('id');
            const i = perf.traits.findIndex(t => t.trait_id == id);
            if (i > 0) { const [t] = perf.traits.splice(i, 1); perf.traits.splice(i - 1, 0, t); }
            this.renderTraits(); this.markDirty();
        });
    }

    flagStale() {
        if (this.sheet.performance.results) this.root.find('#vs_compute_state').html('<span class="text-warning">Settings changed \u2014 compute again to update the numbers.</span>');
    }

    renderGaugePick() {
        const s = this.sheet, perf = s.performance, o = s.options, el = this.root.find('#vs_perf_gauges');
        if (!el.length) return;
        if (!Array.isArray(o.perf_gauges)) o.perf_gauges = [];
        o.perf_gauges = perfGaugeIds(s);
        const traits = perf.traits || [];
        if (!traits.length) { el.html('<p class="text-muted">Tick the traits above first.</p>'); return; }
        const sel = i => `<select class="form-control input-sm vs-pg-sel" data-i="${i}"><option value="">${i ? '— none —' : '— no gauges —'}</option>` +
            traits.map(t => `<option value="${t.trait_id}" ${o.perf_gauges[i] == t.trait_id ? 'selected' : ''} ${o.perf_gauges.indexOf(t.trait_id) >= 0 && o.perf_gauges[i] != t.trait_id ? 'disabled' : ''}>${esc(t.label || t.name)}${t.direction === 'lower' ? ' (lower is better)' : ''}</option>`).join('') + '</select>';
        const shown = Math.min(3, o.perf_gauges.length + 1);
        const pview = o.perf_view || 'both';
        el.html(`<div class="form-group"><label>Show the performance on the profile as</label>${perfViewCards(pview, 'vs_pview')}</div>
            <label>Gauge traits</label>
            <div class="vs-pg-pick">${[0, 1, 2].map(i => `<div class="vs-pg-slot" ${i < shown ? '' : 'style="display:none"'}><span class="vs-pg-n">${i + 1}</span>${sel(i)}</div>`).join('')}</div>
            <div class="vs-pg-range ${o.perf_gauges.length ? '' : 'text-muted'}">Dial from <input type="number" class="form-control input-sm vs-pg-r" data-k="perf_gauge_min" value="${esc(o.perf_gauge_min || 70)}" min="0" max="99" step="5"> to
              <input type="number" class="form-control input-sm vs-pg-r" data-k="perf_gauge_max" value="${esc(o.perf_gauge_max || 130)}" min="101" max="1000" step="5"> %
              <span class="bb-help">100% = ${perf.source === 'analysis' ? 'the mean of all entries' : 'the starred check'}; classes: much worse &lt;90, worse 90–97, similar 97–103, better 103–110, much better &gt;110</span></div>`);
        el.off().on('change', 'input[name=vs_pview]', e => {
            o.perf_view = e.target.value;
            el.find('.vs-pview-cards .bb-option').removeClass('on'); $(e.target).closest('.bb-option').addClass('on');
            this.markDirty();
        }).on('change', '.vs-pg-sel', () => {
            const ids = [];
            el.find('.vs-pg-sel').each((i, x) => { const v = +x.value; if (v && ids.indexOf(v) < 0) ids.push(v); });
            o.perf_gauges = ids;
            this.renderGaugePick(); this.markDirty();
        }).on('change', '.vs-pg-r', e => {
            const v = parseFloat(e.target.value), k = $(e.target).data('k');
            if (k === 'perf_gauge_min' ? v >= 0 && v < 100 : v > 100) { o[k] = v; this.markDirty(); }
            else e.target.value = o[k] || (k === 'perf_gauge_min' ? 70 : 130);
        });
    }

    async computePerformance() {
        const perf = this.sheet.performance;
        if (!perf.traits.length) { this.message('Tick at least one trait.', 'warning'); return; }
        if (perf.source === 'analysis' && !perf.analysis_id) { this.message('Choose an analysis.', 'warning'); return; }
        const btn = this.root.find('#vs_compute').prop('disabled', true);
        this.root.find('#vs_compute_state').html('<span class="glyphicon glyphicon-refresh bb-spin"></span> Computing\u2026');
        try {
            perf.results = await ajax('/ajax/variety_sheet/performance', { method: 'POST', json: {
                stock_id: this.sheet.stock_id, checks: perf.checks.map(c => c.stock_id), traits: perf.traits.map(t => t.trait_id),
                direction: Object.fromEntries(perf.traits.map(t => [t.trait_id, t.direction])),
                source: perf.source, analysis_id: perf.analysis_id, year_min: perf.year_min, year_max: perf.year_max } });
            this.root.find('#vs_compute_state').html(`<span class="text-success">Computed ${esc(perf.results.computed_on)}.</span>`);
            if (!this.sheet.text.production) this.sheet.text.production = autoProduction(this.sheet);
            this.renderResultsSummary(); this.markDirty();
        } catch (err) {
            this.root.find('#vs_compute_state').html(`<span class="text-danger">${esc(err.message)}</span>`);
        }
        btn.prop('disabled', false);
    }

    renderResultsSummary() {
        const s = this.sheet, el = this.root.find('#vs_results');
        if (!s.performance.results) { el.html(''); return; }
        const empty = s.performance.results.traits.every(r => r.variety.mean === null || r.variety.mean === undefined);
        el.html(`<div class="vs-results">${empty ? '<div class="alert alert-warning">No values found for these traits with the current settings.</div>' : ''}${s.performance.results.source === 'analysis' ? analysisTable(s) : trialTable(s)}</div>`);
    }

    /* ---------------------------------------- step 4: traits & ratings */

    // step 4: how the Performance row is shown (same setting as step 3 and the Layout of step 6)
    perfViewBlock() {
        const s = this.sheet, perf = s.performance, o = s.options;
        const pview = o.perf_view || 'both';
        const ids = perfGaugeIds(s);
        const names = ids.map(id => { const t = perf.traits.find(x => x.trait_id == id); return t ? esc(t.label || t.name) : ''; }).filter(Boolean);
        const state = !perf.traits.length ? 'No performance traits yet.'
            : !perf.results ? 'The performance is not computed yet.'
            : names.length ? `Gauges: <b>${names.join('</b>, <b>')}</b>.` : 'No gauge traits chosen: the table is shown.';
        return `<div class="form-group vs-pview4"><label>Show the performance on the profile as</label>${perfViewCards(pview, 'vs_pview4')}
            <p class="bb-help">${state} <a href="#" class="vs-go-perf">Change the traits, checks or gauges in step 3</a>.</p></div>`;
    }

    step_traits(p) {
        const s = this.sheet;
        const traits = (this.acc.traits || []).filter(t => t.numeric);
        const disease = traits.filter(t => t.kind === 'disease');
        const other = traits.filter(t => t.kind !== 'disease');
        const chosen = s.ratings.traits.map(t => t.trait_id);
        const rview = s.options.ratings_view || 'table';
        const opt = t => `<option value="${t.trait_id}" ${chosen.indexOf(t.trait_id) >= 0 ? 'disabled' : ''}>${esc(t.name)} \u2014 ${plural(t.trials, 'trial')}</option>`;
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">4</span> Disease reactions, characteristics and selling points</h3></div>
          <h4 class="bb-section">Performance</h4>
          ${this.perfViewBlock()}
          <h4 class="bb-section">Disease and stress reactions</h4>
          <p class="text-muted">Pick the rating traits. Breedbase computes the variety's mean score (and the checks' in the same trials) and suggests a reaction class from the trait scale; you have the final word.</p>
          <div class="input-group input-group-sm"><select class="form-control" id="vs_rating_add"><option value="">Add a trait\u2026</option>
            ${disease.length ? `<optgroup label="Disease / stress">${disease.map(opt).join('')}</optgroup>` : ''}<optgroup label="Other traits">${other.map(opt).join('')}</optgroup></select>
            <span class="input-group-btn"><button class="btn btn-default" id="vs_rating_compute"><span class="glyphicon glyphicon-refresh"></span> Update scores</button></span></div>
          <div id="vs_ratings"></div>
          <div class="form-group vs-rview-group"><label>Show the disease reactions on the profile as</label> <small class="text-muted">(the performance has its own choice above)</small>
            <div class="bb-options vs-rview">
              ${[['gauge', 'Gauges only', 'A dial per disease, from susceptible to resistant, with the score of the variety.'],
                 ['table', 'Table only', 'The score of the variety and of each check in the same trials.'],
                 ['both', 'Gauges and table', 'The gauges, and the table below them.']].map(([v, title, text]) => `
                <label class="bb-option ${rview === v ? 'on' : ''}"><input type="radio" name="vs_rview" class="vs-bind-opt" data-k="ratings_view" value="${v}" ${rview === v ? 'checked' : ''}>
                  <span class="bb-option-title">${title}</span><span class="bb-option-text">${text}</span></label>`).join('')}
            </div>
            <label class="checkbox-inline vs-gchecks" ${rview === 'table' ? 'style="display:none"' : ''}><input type="checkbox" class="vs-bind-opt" data-k="gauge_checks" ${s.options.gauge_checks !== false ? 'checked' : ''}> Mark the checks on the gauges ${s.performance.checks.length ? `<span class="text-muted">(${esc(s.performance.checks.map(c => c.name).join(', '))})</span>` : '<span class="text-muted">(choose checks in step 3)</span>'}</label>
          </div>
          <div class="form-group"><label>Reaction to diseases (text)</label> <button class="btn btn-xs btn-link vs-auto" data-k="disease"><span class="glyphicon glyphicon-flash"></span> Write it from the ratings</button>
            <textarea class="form-control vs-bind-text" data-k="disease" rows="3" placeholder="e.g. Resistant to potato virus Y, late blight race US-23 and golden nematode race Ro1. Moderately susceptible to common scab.">${esc(s.text.disease)}</textarea></div>

          <h4 class="bb-section">Characteristics</h4>
          <p class="text-muted">Short facts shown as a table: maturity, plant habit, flower color, seed size\u2026 Pull a value from the trial data or type it.</p>
          <div id="vs_chars"></div>
          <div class="btn-group btn-group-sm">
            <button class="btn btn-default" id="vs_char_add"><span class="glyphicon glyphicon-plus"></span> Add row</button>
            <button class="btn btn-default dropdown-toggle" data-toggle="dropdown">Add from a trait <span class="caret"></span></button>
            <ul class="dropdown-menu vs-char-traits" style="max-height:300px;overflow:auto">${traits.map(t => `<li><a href="#" data-id="${t.trait_id}">${esc(t.label)} <small class="text-muted">${esc(t.name)}</small></a></li>`).join('')}</ul>
          </div>

          <h4 class="bb-section">Selling points</h4>
          <div class="form-group"><label>Market features</label>
            <textarea class="form-control vs-bind-text" data-k="market" rows="3" placeholder="End use, quality, appearance\u2026 e.g. Chipping variety with round to oblong tubers and lightly netted skin.">${esc(s.text.market)}</textarea></div>
          <div class="form-group"><label>Production features</label> <button class="btn btn-xs btn-link vs-auto" data-k="production"><span class="glyphicon glyphicon-flash"></span> Write it from the performance results</button>
            <textarea class="form-control vs-bind-text" data-k="production" rows="4" placeholder="Maturity, yield, size\u2026 The testing summary (trials, locations, years) is added automatically above this text.">${esc(s.text.production)}</textarea></div>
          <div class="form-group"><label>Recommendations</label>
            <textarea class="form-control vs-bind-text" data-k="recommendations" rows="3" placeholder="Spacing, fertility, planting window, regions of adaptation\u2026">${esc(s.text.recommendations)}</textarea></div>`);
        this.bindCommon(p);
        this.renderRatings();
        this.renderChars();
        p.on('change', '#vs_rating_add', e => {
            const t = traits.find(x => x.trait_id == e.target.value);
            if (!t) return;
            s.ratings.traits.push(Object.assign(traitConfig(t), { rating: '', note: '' }));
            this.markDirty();
            this.step_traits(p.off());
            this.computeRatings();
        });
        p.on('click', '#vs_rating_compute', () => this.computeRatings());
        p.on('change', 'input[name=vs_pview4]', e => {
            s.options.perf_view = e.target.value;
            p.find('.vs-pview4 .bb-option').removeClass('on'); $(e.target).closest('.bb-option').addClass('on');
            this.markDirty();
        });
        p.on('click', '.vs-go-perf', e => { e.preventDefault(); this.go(STEPS.findIndex(x => x.key === 'performance')); });
        p.on('change', 'input[name=vs_rview]', e => {
            p.find('.vs-rview .bb-option').removeClass('on'); $(e.target).closest('.bb-option').addClass('on');
            p.find('.vs-gchecks').toggle(e.target.value !== 'table');
        });
        p.on('click', '#vs_char_add', () => { s.characteristics.push({ label: '', value: '' }); this.renderChars(); });
        p.on('click', '.vs-char-traits a', async e => {
            e.preventDefault();
            const t = traits.find(x => x.trait_id == $(e.currentTarget).data('id'));
            try {
                const r = await ajax('/ajax/variety_sheet/performance', { method: 'POST', json: { stock_id: s.stock_id, checks: [], traits: [t.trait_id], source: 'trials' } });
                const v = r.traits[0].variety;
                const unit = t.unit || guessUnit(t.name);
                s.characteristics.push({ label: t.label, value: `${num(v.mean)}${unit ? ' ' + unit : ''} (mean of ${plural(v.trials, 'trial')})` });
                this.renderChars(); this.markDirty();
            } catch (err) { this.message(esc(err.message), 'danger'); }
        });
    }

    renderRatings() {
        const s = this.sheet, el = this.root.find('#vs_ratings');
        if (!s.ratings.traits.length) { el.html('<p class="text-muted vs-pad">No rating traits yet.</p>'); return; }
        const checks = s.performance.checks;
        el.html(`<table class="table table-condensed vs-rating-table"><thead><tr><th>Trait</th><th>Label</th><th>Score</th>${checks.map(c => `<th>${esc(c.name)}</th>`).join('')}<th>Reaction</th><th>Note</th><th></th></tr></thead><tbody>` +
            s.ratings.traits.map((t, i) => {
                const r = traitResult(s.ratings.results, t.trait_id);
                const sugg = suggestRating(t, r);
                return `<tr data-i="${i}"><td class="vs-t-name">${esc(t.name)}${t.scale_min !== undefined && t.scale_min !== null ? `<div class="vs-small">scale ${esc(t.scale_min)}\u2013${esc(t.scale_max)}</div>` : ''}</td>
                  <td><input class="form-control input-sm vs-r-f" data-f="label" value="${esc(t.label)}"></td>
                  <td>${r ? `<b>${num(r.variety.mean)}</b><div class="vs-small">${plural(r.variety.trials, 'trial')}</div>` : '\u2026'}</td>
                  ${checks.map(c => { const ch = r ? r.checks.find(x => x.stock_id == c.stock_id) : null; return `<td>${ch && ch.shared_trials ? num(ch.check_mean) + `<div class="vs-small">${ch.shared_trials} shared</div>` : '\u2013'}</td>`; }).join('')}
                  <td><select class="form-control input-sm vs-r-f" data-f="rating"><option value="">\u2014</option>${RATINGS.map(x => `<option ${t.rating === x ? 'selected' : ''}>${x}</option>`).join('')}</select>
                    ${sugg !== 'Not rated' && sugg !== t.rating ? `<a href="#" class="vs-r-sugg vs-small" data-v="${sugg}">suggested: ${sugg}</a>` : ''}</td>
                  <td><input class="form-control input-sm vs-r-f" data-f="note" value="${esc(t.note)}" placeholder="e.g. race US-23"></td>
                  <td><a href="#" class="vs-r-del text-danger" title="Remove">&times;</a></td></tr>`;
            }).join('') + '</tbody></table>');
        el.off().on('input change', '.vs-r-f', e => {
            const t = s.ratings.traits[+$(e.target).closest('tr').data('i')];
            t[$(e.target).data('f')] = $(e.target).val();
            this.markDirty();
        }).on('click', '.vs-r-sugg', e => {
            e.preventDefault();
            const t = s.ratings.traits[+$(e.currentTarget).closest('tr').data('i')];
            t.rating = $(e.currentTarget).data('v');
            this.renderRatings(); this.markDirty();
        }).on('click', '.vs-r-del', e => {
            e.preventDefault();
            s.ratings.traits.splice(+$(e.currentTarget).closest('tr').data('i'), 1);
            this.renderRatings(); this.markDirty();
        });
    }

    async computeRatings() {
        const s = this.sheet;
        if (!s.ratings.traits.length) return;
        try {
            s.ratings.results = await ajax('/ajax/variety_sheet/performance', { method: 'POST', json: {
                stock_id: s.stock_id, checks: s.performance.checks.map(c => c.stock_id), traits: s.ratings.traits.map(t => t.trait_id),
                direction: Object.fromEntries(s.ratings.traits.map(t => [t.trait_id, t.direction])), source: 'trials' } });
            s.ratings.traits.forEach(t => { if (!t.rating) { const g = suggestRating(t, traitResult(s.ratings.results, t.trait_id)); if (g !== 'Not rated') t.rating = g; } });
            this.renderRatings(); this.markDirty();
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    renderChars() {
        const s = this.sheet, el = this.root.find('#vs_chars');
        el.html(s.characteristics.map((c, i) => `<div class="row vs-char-row" data-i="${i}">
            <div class="col-xs-4"><input class="form-control input-sm vs-c-f" data-f="label" value="${esc(c.label)}" placeholder="e.g. Maturity"></div>
            <div class="col-xs-7"><input class="form-control input-sm vs-c-f" data-f="value" value="${esc(c.value)}" placeholder="e.g. Full season"></div>
            <div class="col-xs-1"><a href="#" class="vs-c-del text-danger">&times;</a></div></div>`).join(''));
        el.off().on('input', '.vs-c-f', e => {
            s.characteristics[+$(e.target).closest('.vs-char-row').data('i')][$(e.target).data('f')] = $(e.target).val();
            this.markDirty();
        }).on('click', '.vs-c-del', e => {
            e.preventDefault();
            s.characteristics.splice(+$(e.currentTarget).closest('.vs-char-row').data('i'), 1);
            this.renderChars(); this.markDirty();
        });
    }

    /* ------------------------------------------------ step 5: photos */

    step_photos(p) {
        const s = this.sheet, a = this.acc;
        const own = a.images.filter(i => i.own).length;
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">5</span> Photos</h3></div>
          <p class="text-muted">Pick the photos for the profile (6 works well: plant, leaf, flower, fruit or tuber, cross-section, field). They come from the accession and from its plots and plants.
            <a href="/image/add?type_id=${a.stock_id}&action=new&type=stock&refering_page=${encodeURIComponent('/stock/' + a.stock_id + '/view')}" target="_blank">Upload new photos</a> to the accession, then <a href="#" id="vs_reload_images">reload</a>.</p>
          <h4 class="bb-section">On the profile <small>${s.images.length} selected</small></h4>
          <div id="vs_selected_photos"></div>
          <div class="form-inline vs-pad"><label>Columns&nbsp;</label><select class="form-control input-sm vs-bind-opt" data-k="photo_columns">${[2, 3, 4].map(n => `<option ${s.options.photo_columns == n ? 'selected' : ''} value="${n}">${n}</option>`).join('')}</select></div>
          <h4 class="bb-section">Available <small>
            <a href="#" class="vs-img-f ${this.imageFilter === 'all' ? 'b' : ''}" data-f="all">all (${a.images.length})</a> \u00b7
            <a href="#" class="vs-img-f ${this.imageFilter === 'own' ? 'b' : ''}" data-f="own">accession (${own})</a> \u00b7
            <a href="#" class="vs-img-f ${this.imageFilter === 'plots' ? 'b' : ''}" data-f="plots">plots and plants (${a.images.length - own})</a></small></h4>
          <div id="vs_available_photos" class="vs-thumbs"></div>`);
        this.bindCommon(p);
        this.renderPhotos();
        p.on('click', '.vs-img-f', e => { e.preventDefault(); this.imageFilter = $(e.currentTarget).data('f'); this.step_photos(p.off()); });
        p.on('click', '#vs_reload_images', async e => {
            e.preventDefault();
            await this.loadAccession(s.stock_id, true);
        });
    }

    renderPhotos() {
        const s = this.sheet, a = this.acc;
        const selIds = s.images.map(i => i.image_id);
        const sel = this.root.find('#vs_selected_photos');
        sel.html(s.images.length ? '<div class="vs-sel-photos">' + s.images.map((im, i) => `<div class="vs-sel" data-i="${i}">
              <img src="${esc(im.url)}" alt=""><input class="form-control input-sm vs-cap" value="${esc(im.caption || '')}" placeholder="Caption (optional)">
              <div class="vs-sel-btns"><a href="#" class="vs-mv" data-d="-1" title="Move left">\u25c0</a><a href="#" class="vs-mv" data-d="1" title="Move right">\u25b6</a><a href="#" class="vs-rm text-danger" title="Remove">&times;</a></div></div>`).join('') + '</div>'
            : '<p class="text-muted">Click photos below to add them.</p>');
        const list = a.images.filter(i => this.imageFilter === 'all' || (this.imageFilter === 'own' ? i.own : !i.own));
        this.root.find('#vs_available_photos').html(list.length ? list.map(im => `<a href="#" class="vs-thumb ${selIds.indexOf(im.image_id) >= 0 ? 'on' : ''}" data-id="${im.image_id}" title="${esc((im.name || im.filename || '') + ' \u2014 ' + im.stock_name + (im.date ? ' \u2014 ' + im.date : ''))}">
              <img src="${esc(im.url)}" alt="" loading="lazy"><span>${esc(im.own ? 'accession' : im.stock_name)}</span></a>`).join('')
            : '<p class="text-muted">No photos found. Upload photos to the accession, or tag field photos to its plots with the Field Book app.</p>');
        const root = this.root;
        root.find('#vs_available_photos').off().on('click', '.vs-thumb', e => {
            e.preventDefault();
            const id = +$(e.currentTarget).data('id');
            const i = s.images.findIndex(x => x.image_id === id);
            if (i >= 0) s.images.splice(i, 1);
            else {
                const im = a.images.find(x => x.image_id === id);
                s.images.push({ image_id: im.image_id, url: im.url, url_large: im.url_large, caption: im.description && im.description.length < 60 ? im.description : '' });
            }
            this.renderPhotos(); this.markDirty();
        });
        sel.off().on('input', '.vs-cap', e => {
            s.images[+$(e.target).closest('.vs-sel').data('i')].caption = $(e.target).val();
            this.markDirty();
        }).on('click', '.vs-mv', e => {
            e.preventDefault();
            const i = +$(e.currentTarget).closest('.vs-sel').data('i'), j = i + (+$(e.currentTarget).data('d'));
            if (j < 0 || j >= s.images.length) return;
            [s.images[i], s.images[j]] = [s.images[j], s.images[i]];
            this.renderPhotos(); this.markDirty();
        }).on('click', '.vs-rm', e => {
            e.preventDefault();
            s.images.splice(+$(e.currentTarget).closest('.vs-sel').data('i'), 1);
            this.renderPhotos(); this.markDirty();
        });
        this.root.find('.vs-panel h4 small').first().text(`${s.images.length} selected`);
    }

    /* --------------------------------------- step 6: preview & publish */

    step_publish(p) {
        const s = this.sheet, o = s.options;
        const missing = [];
        if (!s.commercial_name) missing.push('<b>commercial name (step 2; required to save)</b>');
        if (!s.performance.results) missing.push('performance numbers (step 3)');
        if (!s.images.length && o.show_photos !== false) missing.push('photos (step 5)');
        const chk = (k, label) => `<label class="checkbox-inline"><input type="checkbox" class="vs-bind-opt" data-k="${k}" ${o[k] !== false ? 'checked' : ''}> ${label}</label>`;
        p.html(`
          <div class="bb-card-head vs-step-head"><h3><span class="vs-step-badge">6</span> Preview and publish</h3></div>
          ${missing.length ? `<div class="alert alert-warning">Not filled yet: ${missing.join(', ')}. ${s.commercial_name ? 'You can save anyway.' : ''}</div>` : ''}
          <div class="row">
            <div class="col-md-8">
              <div class="form-group vs-layout"><label>Layout</label>
                <div><span>Performance</span><select class="form-control input-sm vs-bind-opt" data-k="perf_view">${[['both', 'Gauges and table'], ['gauge', 'Gauges only'], ['table', 'Table only']].map(([v, l]) => `<option value="${v}" ${(o.perf_view || 'both') === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
                     <span>Diseases</span><select class="form-control input-sm vs-bind-opt" data-k="ratings_view">${[['both', 'Gauges and table'], ['gauge', 'Gauges only'], ['table', 'Table only']].map(([v, l]) => `<option value="${v}" ${(o.ratings_view || 'table') === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
                     <span>Paper</span><select class="form-control input-sm vs-bind-opt" data-k="paper">${[['a4', 'A4'], ['letter', 'Letter']].map(([v, l]) => `<option value="${v}" ${(o.paper || defaultPaper()) === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div></div>
              <div class="form-group"><label>Show</label><div>${chk('show_pedigree', 'pedigree')} ${chk('show_decisions', 'decision history' + ((s.decisions || []).some(d => d && d.meeting_id) ? '' : ' <span class="text-muted">(no meeting linked: step 2)</span>'))} ${chk('show_testing', 'testing summary')} ${chk('show_pct_chart', '% of check chart')} ${chk('show_year_chart', 'by-year chart')} ${chk('show_photos', 'photos')} ${chk('show_map', 'map of test locations')} ${chk('show_stats', 'significance stars')}</div></div>
            </div>
            <div class="col-md-4">
              <div class="form-group"><label>Accent color</label><div class="vs-accents">${ACCENTS.map(c => `<a href="#" class="vs-accent ${o.accent === c ? 'on' : ''}" data-c="${c}" style="background:${c}"></a>`).join('')}<input type="color" class="vs-bind-opt" data-k="accent" value="${esc(o.accent)}"></div></div>
            </div>
          </div>
          <div class="row">
            <div class="col-md-4 form-group"><label>Availability / licensing</label><textarea class="form-control vs-bind-text" data-k="availability" rows="3" placeholder="e.g. Seed available from \u2026 An application has been filed for PVP.">${esc(s.text.availability)}</textarea></div>
            <div class="col-md-4 form-group"><label>Contact</label><textarea class="form-control vs-bind-text" data-k="contact" rows="3" placeholder="Name, email, phone">${esc(s.text.contact)}</textarea></div>
            <div class="col-md-4 form-group"><label>Acknowledgements</label><textarea class="form-control vs-bind-text" data-k="acknowledgements" rows="3" placeholder="e.g. Developed with support from \u2026">${esc(s.text.acknowledgements)}</textarea></div>
          </div>
          <div class="vs-publish-bar">
            ${this.acc.can_edit ? (this.acc.public_profiles ? `<button class="btn btn-default" id="vs_save_draft2"><span class="glyphicon glyphicon-floppy-disk"></span> ${this.status === 'published' ? 'Save' : 'Save draft'}</button>
            <button class="btn btn-success" id="vs_publish"><span class="glyphicon glyphicon-globe"></span> ${this.status === 'published' ? 'Update public page' : 'Publish as a public page'}</button>`
              : `<button class="btn btn-primary" id="vs_save_draft2"><span class="glyphicon glyphicon-floppy-disk"></span> Save in Breedbase</button>`) : ''}
            <button class="btn btn-default" id="vs_print" title="One page, in the paper size chosen above"><span class="glyphicon glyphicon-print"></span> Print / save as PDF</button>
            ${this.sheetId ? `<a class="btn btn-link" href="/variety_sheet/${this.sheetId}" target="_blank">Open the saved profile</a>` : ''}
            <span class="text-muted vs-pub-state">${!this.acc.public_profiles ? 'Saved profiles stay in Breedbase: only curators can open and edit them. To send one, print it or save it as a PDF.'
              : this.status === 'published' ? 'Public page: anyone with the link can see it.' : 'Drafts are visible to you and curators only.'}</span>
          </div>
          ${this.buildSummary()}
          <div class="vs-full-preview vs-editable"></div>`);
        this.bindCommon(p);
        p.on('click', '.vs-built-toggle', e => { e.preventDefault(); this.builtOpen = !this.builtOpen; p.find('.vs-built-body').toggle(this.builtOpen); $(e.currentTarget).text(this.builtOpen ? 'hide details' : 'why these traits?'); });
        p.on('click', '.vs-ed-btn', e => { e.preventDefault(); this.editPart($(e.currentTarget).data('ed')); });
        p.on('click', '.vs-accent', e => { e.preventDefault(); o.accent = $(e.currentTarget).data('c'); p.find('.vs-accent').removeClass('on'); $(e.currentTarget).addClass('on'); p.find('input[type=color]').val(o.accent); this.markDirty(); });
        p.on('click', '#vs_save_draft2', () => this.save('draft'));
        p.on('click', '#vs_publish', () => this.save('published'));
        p.on('click', '#vs_print', () => window.print());
    }

    async save(status) {
        const s = this.sheet;
        if (!s) return;
        if (!this.acc.public_profiles) status = 'draft';
        if (!(s.commercial_name || '').trim()) {
            this.message('Choose a commercial name before saving (step 2): a variety profile never shows the experimental name.', 'warning'); this.go(1); return;
        }
        if (status === 'published' && this.acc.require_meeting && !(s.decisions || []).some(d => d && d.meeting_id)) {
            this.message('Link this profile to at least one decision meeting before publishing it (step 2).', 'warning'); this.go(1); return;
        }
        if (status === 'published' && this.status !== 'published' && !confirm('Make this profile a public web page? Anyone with the link will be able to see it, without logging in.')) return;
        const opts = (this.nameCheck && this.nameCheck.conflicts.length) || !this.acc.can_save_names ? {} : this.nameOptions;
        const btns = this.root.find('.vs-save-draft, #vs_save_draft2, #vs_publish').prop('disabled', true);
        try {
            const r = await ajax('/ajax/variety_sheet/save', { method: 'POST', json: { sheet_id: this.sheetId, stock_id: s.stock_id, status, sheet: s, name_options: opts } });
            this.sheetId = r.sheet_id;
            this.status = r.status;
            this.dirty = false;
            history.replaceState(null, '', '/tools/variety_sheet?sheet_id=' + r.sheet_id);
            const state = r.status === 'published' ? 'public page' : this.acc.public_profiles ? 'draft' : 'curators only';
            this.root.find('.vs-save-state').text(`Saved ${new Date().toLocaleTimeString()} \u00b7 profile #${r.sheet_id} (${state})`);
            const msgs = (r.messages || []).map(esc);
            if (r.status === 'published') msgs.unshift(`Saved as a public page: <a href="${r.url}" target="_blank">${esc(location.origin + r.url)}</a>`);
            else msgs.unshift(`Saved in Breedbase as profile #${r.sheet_id}. Only curators can open it.`);
            this.message(msgs.join('<br>'), 'success');
            if ((r.messages || []).length) { this.acc.released_variety_name.push(s.commercial_name); this.nameCheck = null; }
            if (STEPS[this.step].key === 'publish') this.go(this.step);
        } catch (err) { this.message(esc(err.message), 'danger'); }
        btns.prop('disabled', false);
    }
}

function newSheetSkeleton() {
    return {
        version: VERSION, performance: { source: 'trials', checks: [], traits: [], results: null }, ratings: { traits: [], results: null },
        characteristics: [], images: [], evidence: {}, decisions: [],
        text: { pedigree: '', market: '', production: '', disease: '', recommendations: '', acknowledgements: '', availability: '', contact: '' },
        options: { show_pedigree: true, show_decisions: true, show_map: true, show_pct_chart: true, show_year_chart: true, show_stats: true, show_testing: true, accent: ACCENTS[0], photo_columns: 3 },
    };
}

/* -------------------------------------------------------------- entry points */

// photos whose file is missing on the server: hidden on the profile, flagged in the editor
let imageGuard = false;
function guardImages() {
    if (imageGuard) return;
    imageGuard = true;
    document.addEventListener('error', e => {
        const img = e.target;
        if (!img || img.tagName !== 'IMG') return;
        const fig = img.closest('.vs-photos figure');
        if (fig) fig.classList.add('vs-missing');
        const th = img.closest('.vs-thumb, .vs-sel');
        if (th) th.classList.add('vs-img-missing');
    }, true);
}

/* ------------------------------------------------------------------ printing */

// one page: a clean copy of the profile in a compact two-column layout, scaled to fit A4 or Letter
const PAPER = { a4: { w: 210, h: 297, css: 'A4' }, letter: { w: 215.9, h: 279.4, css: 'letter' } };
const PRINT_MARGIN_MM = 8, MIN_PRINT_ZOOM = 0.6;
const mmToPx = x => x * 96 / 25.4;
function defaultPaper() { return /^en-(US|CA)|^es-(MX|US)|^fil|^en-PH/i.test(navigator.language || '') ? 'letter' : 'a4'; }

function cleanupPrint() {
    ['vs-print-host', 'vs-print-page'].forEach(id => { const n = document.getElementById(id); if (n) n.remove(); });
}
function preparePrint(html, paper) {
    cleanupPrint();
    const p = PAPER[paper] || PAPER[defaultPaper()];
    const host = document.createElement('div');
    host.id = 'vs-print-host';
    host.innerHTML = html;
    const sheet = host.querySelector('.vs-sheet');
    if (!sheet) return;
    sheet.classList.add('vs-print-layout');
    // what does not belong on paper
    sheet.querySelectorAll('.vs-map-sec, .vs-ed-btn, .vs-ed-blank, .vs-ed-box').forEach(n => n.remove());
    document.body.appendChild(host);
    const W = mmToPx(p.w - 2 * PRINT_MARGIN_MM), H = mmToPx(p.h - 2 * PRINT_MARGIN_MM);
    sheet.style.width = W + 'px';
    const need = sheet.scrollHeight;
    const z = Math.max(MIN_PRINT_ZOOM, Math.min(1, (H - 6) / need));
    sheet.style.setProperty('zoom', z.toFixed(3));
    const st = document.createElement('style');
    st.id = 'vs-print-page';
    st.textContent = `@page { size: ${p.css}; margin: ${PRINT_MARGIN_MM}mm; }`;
    document.head.appendChild(st);
}
// getHtml() returns the profile to print; getPaper() 'a4' | 'letter'
let printInstalled = false;
function installPrint(getHtml, getPaper) {
    if (printInstalled) return;
    printInstalled = true;
    window.addEventListener('beforeprint', () => { const h = getHtml(); if (h) preparePrint(h, getPaper()); });
    window.addEventListener('afterprint', cleanupPrint);
}

export function initEditor(root, opts) {
    guardImages();
    const ed = new Editor(root, opts);
    ed.start();
    installPrint(() => ed.sheet ? renderSheet(ed.sheet, { url: ed.sheetId ? location.origin + '/variety_sheet/' + ed.sheetId : '' }) : '',
                 () => (ed.sheet && ed.sheet.options.paper) || defaultPaper());
    return ed;
}

export function initView(root, row) {
    guardImages();
    const el = $(root);
    const sheet = Object.assign(newSheetSkeleton(), row.sheet);
    sheet.text = Object.assign(newSheetSkeleton().text, sheet.text || {});
    sheet.options = Object.assign(newSheetSkeleton().options, sheet.options || {});
    el.html(renderSheet(sheet, { url: location.origin + '/variety_sheet/' + row.variety_sheet_id, link_meetings: !!row.can_edit }));
    drawMaps(el, sheet);
    installPrint(() => renderSheet(sheet, { url: location.origin + '/variety_sheet/' + row.variety_sheet_id }), () => sheet.options.paper || defaultPaper());
}

export function initList(root) {
    const el = $(root);
    ajax('/ajax/variety_sheet/list').then(r => {
        const card = s => `<a class="vs-card ${s.status === 'published' || !r.public_profiles ? '' : 'vs-card-draft'}" href="/variety_sheet/${s.variety_sheet_id}"><b>${esc(s.commercial_name)}</b><span>${esc(s.accession_name)}</span><small>${esc(s.owner || '')} \u00b7 ${esc(s.modified_date)}</small></a>`;
        if (!r.public_profiles) {
            // private profiles: one list, curators only
            el.html(`<div class="bb-stats"><div class="bb-stat"><div class="v">${r.sheets.length}</div><div class="l">saved profiles</div></div></div>` +
                `<div class="bb-card"><div class="bb-card-head"><h3><span class="glyphicon glyphicon-lock"></span> Saved profiles</h3><span class="bb-help">only curators can open them; print or save a PDF to send one</span></div>` +
                (r.sheets.length ? `<div class="vs-cards">${r.sheets.map(card).join('')}</div>` : '<div class="bb-empty-card"><span class="glyphicon glyphicon-tag"></span><p>No saved variety profiles you can open. Curators see all of them after logging in.</p></div>') + '</div>');
            return;
        }
        const pub = r.sheets.filter(s => s.status === 'published');
        const drafts = r.sheets.filter(s => s.status !== 'published');
        el.html(`<div class="bb-stats"><div class="bb-stat"><div class="v">${pub.length}</div><div class="l">published</div></div><div class="bb-stat"><div class="v">${drafts.length}</div><div class="l">drafts</div></div></div>` +
            `<div class="bb-card"><div class="bb-card-head"><h3><span class="glyphicon glyphicon-globe"></span> Published</h3></div>` +
            (pub.length ? `<div class="vs-cards">${pub.map(card).join('')}</div>` : '<div class="bb-empty-card"><span class="glyphicon glyphicon-tag"></span><p>No published variety profiles yet.</p></div>') + '</div>' +
            (drafts.length ? `<div class="bb-card"><div class="bb-card-head"><h3><span class="glyphicon glyphicon-pencil"></span> Drafts</h3></div><div class="vs-cards">${drafts.map(card).join('')}</div></div>` : ''));
    }).catch(err => el.html(`<p class="text-danger">${esc(err.message)}</p>`));
}

// exported for tests
export const _test = { renderSheet, autoPedigree, autoTesting, autoProduction, autoDisease, suggestRating, resistanceFrac, newSheet, esc, rich, num };
