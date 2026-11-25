/*
 * Charts of the Decisions tab of a decision meeting:
 *
 *   stageDonut(program, configStages)  the breeding program's active accessions by stage
 *                                      (whole database), with the dropped ones beside it
 *   decisionsByStage(rows)             this meeting: for each current stage, how the
 *                                      decisions split (advance, jump, hold, drop, to decide)
 *   stageShift(rows, configStages)     this meeting: accessions per stage now and after the
 *                                      decisions (advance/jump move up, drop leaves)
 *   stageFunnel(program, configStages, rates)
 *                                      program size by stage: a linear violin of the ON
 *                                      accessions now, in front of the funnel of the
 *                                      accessions that ever reached each stage (history, no
 *                                      setting needed); with breeding_stage_rates also the
 *                                      target flow (dotted)
 *   dropsByYear(program, configStages) the program's dropped accessions per year of the drop,
 *                                      stacked by the stage they were dropped at; the drops
 *                                      of this meeting (not saved yet) hatched on top
 *   withDecisions(program, rows)       the program counts as they will be once the decisions
 *                                      of the meeting are saved (deltas per stage), so the
 *                                      charts follow the decisions while they are taken
 *
 * Stages are ordinal: one green ramp, light (first stage) to dark (last). Stages outside the
 * configuration (e.g. 'untested') are gray. Decisions use the colors of the decision buttons.
 * Plain SVG/HTML; one tooltip for hover and keyboard focus.
 *
 * Author: Chris Simoes
 */

const LIGHT = [150, 206, 168];   // #96cea8
const DARK = [20, 83, 45];       // #14532d
const OTHER = '#c4c9d0';
export const DECISION_COLORS = { advance: '#16a34a', jump: '#7c3aed', hold: '#d97706', drop: '#dc2626', none: '#e5e7eb' };
const DECISION_LABELS = { advance: 'Advance', jump: 'Jump', hold: 'Hold', drop: 'Drop', none: 'To decide' };

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
const pct = (x, t) => (t ? Math.round(1000 * x / t) / 10 : 0);
const fmtN = n => Number(n || 0).toLocaleString();

export function stageToken(stage) {
    const p = String(stage || '').split('-').filter(Boolean);
    return p.length ? p[p.length - 1] : '';
}
const isDrop = stage => /^\s*DROP(-|$)/i.test(String(stage || ''));

// color of a stage: its place among the configured stages
export function stageColor(stage, configStages) {
    const i = (configStages || []).indexOf(stage);
    if (i < 0) return OTHER;
    const n = configStages.length;
    const t = n > 1 ? i / (n - 1) : 1;
    return 'rgb(' + LIGHT.map((x, k) => Math.round(x + (DARK[k] - x) * t)).join(',') + ')';
}
function inkOn(stage, configStages) {
    const i = (configStages || []).indexOf(stage);
    return i >= 0 && configStages.length > 1 && i / (configStages.length - 1) > 0.45 ? '#fff' : '#1f2937';
}

// ---------------------------------------------------------------- donut
function arc(cx, cy, r0, r1, a0, a1) {
    const p = (r, a) => [cx + r * Math.sin(a), cy - r * Math.cos(a)];
    const large = a1 - a0 > Math.PI ? 1 : 0;
    const [x0, y0] = p(r1, a0), [x1, y1] = p(r1, a1), [x2, y2] = p(r0, a1), [x3, y3] = p(r0, a0);
    return 'M' + x0 + ' ' + y0 + 'A' + r1 + ' ' + r1 + ' 0 ' + large + ' 1 ' + x1 + ' ' + y1 +
        'L' + x2 + ' ' + y2 + 'A' + r0 + ' ' + r0 + ' 0 ' + large + ' 0 ' + x3 + ' ' + y3 + 'Z';
}

// program: {program, active, dropped, stages: [{stage, active, dropped, configured}]}
export function stageDonut(program, configStages) {
    ensureStyle();
    const parts = (program.stages || []).filter(s => s.active > 0);
    const total = program.active || 0;
    if (!total) return '<div class="dsc-empty">No accession of ' + esc(program.program) + ' has a stage yet.</div>';
    const cx = 90, cy = 90, r1 = 84, r0 = 54;
    let a = 0;
    const paths = parts.map(s => {
        const da = 2 * Math.PI * s.active / total;
        const a0 = a, a1 = a + da;
        a = a1;
        const tip = s.stage + ': ' + fmtN(s.active) + ' accession' + (s.active === 1 ? '' : 's') + ' (' + pct(s.active, total) + '% of the active ones)' + (s.configured ? '' : ' - not a configured stage');
        const d = parts.length === 1 ? arc(cx, cy, r0, r1, 0, 2 * Math.PI - 1e-4) : arc(cx, cy, r0, r1, a0, a1);
        return '<path d="' + d + '" fill="' + stageColor(s.stage, configStages) + '" stroke="#fff" stroke-width="2" class="dsc-hit" tabindex="0" data-dsc-tip="' + esc(tip) + '" aria-label="' + esc(tip) + '"></path>';
    }).join('');
    const center = '<text x="' + cx + '" y="' + (cy - 4) + '" text-anchor="middle" class="dsc-big">' + fmtN(total) + '</text>' +
        '<text x="' + cx + '" y="' + (cy + 16) + '" text-anchor="middle" class="dsc-small">active</text>';
    const legend = parts.map(s => '<div class="dsc-leg"><span class="dsc-sw" style="background:' + stageColor(s.stage, configStages) + '"></span>' +
        '<span class="dsc-leg-name">' + esc(s.stage) + (s.configured ? '' : ' <i>(not configured)</i>') + '</span>' +
        '<span class="dsc-leg-v"><b>' + pct(s.active, total) + '%</b> <span class="dsc-muted">' + fmtN(s.active) + '</span>' + deltaHtml(s.d_active) + '</span></div>').join('');
    return '<div class="dsc-donut-wrap"><svg viewBox="0 0 180 180" width="180" height="180" role="img" aria-label="' + esc(program.program + ': active accessions by stage') + '">' + paths + center + '</svg>' +
        '<div class="dsc-legend">' + legend + '</div></div>';
}

function deltaHtml(d, upIsBad) {
    if (!d) return '';
    const good = upIsBad ? d < 0 : d > 0;
    return ' <span class="dsc-d ' + (good ? 'up' : 'down') + '">' + (d > 0 ? '+' : '&minus;') + fmtN(Math.abs(d)) + '</span>';
}

// year of a stage value: DROP-23-Y2 -> 2023, ON-2026-T1 -> 2026
export function stageYear(value) {
    for (const p of String(value || '').split('-')) {
        if (/^(19|20)\d\d$/.test(p)) return p;
        if (/^\d\d$/.test(p)) return String(2000 + Number(p));
    }
    return '';
}

// ---------------------------------------------------------------- program after the decisions
function classify(value) {
    const v = String(value || '').trim();
    if (!v) return null;
    return { tok: stageToken(v) || v, drop: isDrop(v), on: /^ON-/i.test(v) };
}

// program counts once the decisions of rows (this meeting, this program) are saved
export function withDecisions(program, rows) {
    const st = {};
    (program.stages || []).forEach(x => { st[x.stage] = Object.assign({}, x, { d_active: 0, d_on: 0, d_dropped: 0 }); });
    const get = t => (st[t] = st[t] || { stage: t, active: 0, on: 0, dropped: 0, configured: 0, d_active: 0, d_on: 0, d_dropped: 0 });
    let dDropped = 0, dActive = 0, dOn = 0;
    const meetingDrops = [];
    const move = (c, k) => {
        const x = get(c.tok);
        if (c.drop) { x.dropped += k; x.d_dropped += k; dDropped += k; return; }
        x.active += k; x.d_active += k; dActive += k;
        if (c.on) { x.on += k; x.d_on += k; dOn += k; }
    };
    (rows || []).forEach(r => {
        if (!r.decision) return;
        const before = classify(r.stage);
        if (!before) return;
        let after = before;
        if (r.decision === 'drop') after = { tok: before.tok, drop: true, on: false };
        else if (r.new_stage) after = classify(r.new_stage) || before;
        if (after.tok === before.tok && after.drop === before.drop && after.on === before.on) return;
        move(before, -1);
        move(after, 1);
        if (after.drop && !before.drop) meetingDrops.push({ year: stageYear(r.new_stage) || String(new Date().getFullYear()), stage: after.tok, n: 1 });
        if (before.drop && !after.drop) meetingDrops.push({ year: stageYear(r.stage), stage: before.tok, n: -1 });
    });
    const cfgOrder = (program.stages || []).map(x => x.stage);
    const stages = cfgOrder.map(t => st[t]).concat(Object.keys(st).filter(t => cfgOrder.indexOf(t) < 0).map(t => st[t]));
    return Object.assign({}, program, {
        stages, active: program.active + dActive, on: (program.on || 0) + dOn, dropped: program.dropped + dDropped,
        d_active: dActive, d_on: dOn, d_dropped: dDropped, meeting_drops: meetingDrops,
    });
}

// ---------------------------------------------------------------- funnel of the ON accessions
// ---------------------------------------------------------------- program size by stage
// Smooth closed outline through the half widths (Catmull-Rom as cubic Bezier), mirrored on cx.
function smoothSide(P, cx, side) {
    let d = '';
    for (let i = 0; i < P.length - 1; i++) {
        const p0 = P[Math.max(0, i - 1)], p1 = P[i], p2 = P[i + 1], p3 = P[Math.min(P.length - 1, i + 2)];
        const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
        const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
        const X = x => (cx + side * Math.max(0.5, x)).toFixed(1);
        d += 'C' + X(c1[0]) + ' ' + c1[1].toFixed(1) + ' ' + X(c2[0]) + ' ' + c2[1].toFixed(1) + ' ' + X(p2[0]) + ' ' + p2[1].toFixed(1);
    }
    return d;
}

// program: {program, on, d_on, stages: [{stage, on, active, dropped, d_on}]}
// Violin: ON accessions now (linear width; white lines = the real values at each stage).
// Behind it, dashed: every accession that ever reached the stage (now at it or beyond, active or
// dropped; all years). Dotted, only with breeding_stage_rates: the target flow from the first stage.
export function stageFunnel(program, configStages, rates) {
    ensureStyle();
    const by = {};
    (program.stages || []).forEach(x => { by[x.stage] = x; });
    const all = (configStages || []).map(t => {
        const x = by[t] || {};
        return { t, n: x.on || 0, d: x.d_on || 0, here: (x.active || 0) + (x.dropped || 0) };
    });
    // reached: at this stage or beyond
    for (let i = all.length - 1, acc = 0; i >= 0; i--) { acc += all[i].here; all[i].reached = acc; }
    const first = all.findIndex(x => x.reached > 0);
    let last = -1;
    all.forEach((x, i) => { if (x.n > 0 || x.here > 0) last = i; });
    if (first < 0 || !all.some(x => x.n > 0)) return '<div class="dsc-empty">No ON accession with a configured stage in ' + esc(program.program) + '.</div>';
    const rows = all.slice(first, last + 1);
    const useRates = rates && rows.length > 1 && rows.slice(0, -1).every(x => rates[x.t] > 0);
    const target = useRates ? rows.reduce((o, x, k) => o.concat(k ? o[k - 1] * rates[rows[k - 1].t] / 100 : x.reached), []) : null;

    const n = rows.length, W = 460, L = 40, R = 150, area = W - L - R, cx = L + area / 2, step = 40, top = 18;
    const H = top * 2 + step * (n - 1);
    const max = Math.max(...rows.map(x => Math.max(x.reached, x.n)), ...(target || [0]));
    const half = v => (v > 0 ? Math.max(1.5, (area / 2) * v / max) : 0.5);
    const ys = rows.map((_, k) => top + k * step);
    let svg = '';

    // history funnel (straight between stages)
    const fl = rows.map((x, k) => (cx - half(x.reached)).toFixed(1) + ' ' + ys[k]);
    const fr = rows.map((x, k) => (cx + half(x.reached)).toFixed(1) + ' ' + ys[k]).reverse();
    svg += '<path d="M' + fl.join('L') + 'L' + fr.join('L') + 'Z" fill="#eef2f6" stroke="#94a3b8" stroke-width="1.2" stroke-dasharray="5 3"></path>';
    if (target) {
        const tl = target.map((v, k) => (cx - half(v)).toFixed(1) + ' ' + ys[k]);
        const tr = target.map((v, k) => (cx + half(v)).toFixed(1) + ' ' + ys[k]);
        svg += '<path d="M' + tl.join('L') + '" fill="none" stroke="#92400e" stroke-width="1.4" stroke-dasharray="1.5 3" stroke-linecap="round"></path>' +
               '<path d="M' + tr.join('L') + '" fill="none" stroke="#92400e" stroke-width="1.4" stroke-dasharray="1.5 3" stroke-linecap="round"></path>';
    }

    // violin of the ON accessions now
    const pts = rows.map((x, k) => [half(x.n), ys[k]]);
    const ext = [[pts[0][0], ys[0] - step * 0.35]].concat(pts).concat([[pts[n - 1][0], ys[n - 1] + step * 0.35]]);
    const rev = ext.slice().reverse();
    svg += '<path d="M' + cx + ' ' + ext[0][1] + 'L' + (cx + ext[0][0]).toFixed(1) + ' ' + ext[0][1] + smoothSide(ext, cx, 1) +
        'L' + cx + ' ' + ext[ext.length - 1][1] + 'L' + (cx - rev[0][0]).toFixed(1) + ' ' + rev[0][1] + smoothSide(rev, cx, -1) + 'Z" fill="' + stageColor(configStages[Math.floor(configStages.length / 2)], configStages) +
        '" fill-opacity="0.9" stroke="#14532d" stroke-width="1"></path>';

    rows.forEach((x, k) => {
        const y = ys[k];
        if (x.n) svg += '<line x1="' + (cx - half(x.n)).toFixed(1) + '" x2="' + (cx + half(x.n)).toFixed(1) + '" y1="' + y + '" y2="' + y + '" stroke="#fff" stroke-width="1.6"></line>';
        const still = x.reached ? Math.round(100 * x.n / x.reached) : 0;
        const tip = x.t + ': ' + fmtN(x.n) + ' ON now' + (x.d ? ' (' + (x.d > 0 ? '+' : '') + x.d + ' with this meeting\'s decisions)' : '') +
            '; ' + fmtN(x.reached) + ' ever reached this stage (all years), ' + still + '% of them are here now' +
            (target && k ? '; target ' + fmtN(Math.round(target[k])) : '');
        svg += '<rect x="0" y="' + (y - step / 2) + '" width="' + W + '" height="' + step + '" fill="transparent" class="dsc-hit dsc-row" tabindex="0" data-dsc-tip="' + esc(tip) + '" aria-label="' + esc(tip) + '"></rect>';
        svg += '<text x="' + (L - 8) + '" y="' + (y + 4) + '" text-anchor="end" class="dsc-ft">' + esc(x.t) + '</text>';
        svg += '<text x="' + (W - R + 8) + '" y="' + (y + 4) + '" class="dsc-fn">' + fmtN(x.n) +
            (x.d ? '<tspan class="dsc-fd ' + (x.d > 0 ? 'up' : 'down') + '" dx="4">' + (x.d > 0 ? '+' : '−') + fmtN(Math.abs(x.d)) + '</tspan>' : '') +
            '<tspan class="dsc-fk" dx="6">of ' + fmtN(x.reached) + ' reached</tspan></text>';
    });
    const key = (sw, label) => '<span class="dsc-lg">' + sw + label + '</span>';
    return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%" style="max-width:' + W + 'px; display:block" role="img" aria-label="' + esc(program.program + ': ON accessions by stage, with the accessions that reached each stage') + '">' + svg + '</svg>' +
        '<div class="dsc-legend-row" style="margin:6px 0 0 0">' +
        key('<svg width="16" height="10"><rect x="1" y="1" width="14" height="8" rx="3" fill="' + stageColor(configStages[Math.floor(configStages.length / 2)], configStages) + '"></rect></svg>', 'ON accessions now (' + fmtN(program.on) + deltaHtml(program.d_on) + ')') +
        key('<svg width="16" height="10"><rect x="1" y="1" width="14" height="8" fill="#eef2f6" stroke="#94a3b8" stroke-dasharray="3 2"></rect></svg>', 'reached the stage, all years') +
        (target ? key('<svg width="16" height="10"><line x1="1" y1="5" x2="15" y2="5" stroke="#92400e" stroke-width="1.6" stroke-dasharray="1.5 3" stroke-linecap="round"></line></svg>', 'target (breeding_stage_rates)') : '') +
        '</div>';
}

// ---------------------------------------------------------------- dropped per year
// drops get their own warm ramp by the stage of the drop (early: light orange, late: dark red),
// spread over the stages that have drops so neighbours stay apart
const DROP_LIGHT = [251, 191, 140], DROP_DARK = [127, 29, 29];
function dropColor(stage, configStages) {
    const i = (configStages || []).indexOf(stage);
    if (i < 0) return OTHER;
    const t = configStages.length > 1 ? i / (configStages.length - 1) : 1;
    return 'rgb(' + DROP_LIGHT.map((x, k) => Math.round(x + (DROP_DARK[k] - x) * t)).join(',') + ')';
}

export function dropsByYear(program, configStages) {
    ensureStyle();
    const by = {}, mine = {};
    (program.drops || []).forEach(x => { if (x.year) { by[x.year] = by[x.year] || {}; by[x.year][x.stage] = (by[x.year][x.stage] || 0) + x.n; } });
    (program.meeting_drops || []).forEach(x => { if (x.year) mine[x.year] = (mine[x.year] || 0) + x.n; });
    const ys = Object.keys(by).concat(Object.keys(mine)).map(Number).filter(Boolean);
    if (!ys.length) return '<div class="dsc-empty">No dropped accession in ' + esc(program.program) + '.</div>';
    const years = [];
    for (let y = Math.min(...ys); y <= Math.max(...ys); y++) years.push(String(y));
    const stagesIn = [...new Set((program.drops || []).map(x => x.stage))];
    const order = stageOrder(stagesIn, configStages);
    const tot = y => Object.values(by[y] || {}).reduce((a, b) => a + b, 0);
    const max = Math.max(1, ...years.map(y => tot(y) + Math.max(0, mine[y] || 0)));
    const cols = years.map(y => {
        const t = tot(y), m = mine[y] || 0;
        const segs = order.filter(st => (by[y] || {})[st]).map(st => {
            const v = by[y][st];
            const tip = y + ': ' + fmtN(v) + ' dropped at ' + st + ' (' + Math.round(100 * v / t) + '% of the year)';
            return '<span class="dsc-ys dsc-hit" tabindex="0" data-dsc-tip="' + esc(tip) + '" aria-label="' + esc(tip) + '" style="height:' + (100 * v / max).toFixed(2) + '%; background:' + dropColor(st, order) + '"></span>';
        }).reverse().join('');
        const mineSeg = m > 0 ? '<span class="dsc-ys dsc-ys-new dsc-hit" tabindex="0" data-dsc-tip="' + esc(y + ': ' + m + ' dropped by this meeting (not saved yet)') + '" style="height:' + (100 * m / max).toFixed(2) + '%"></span>' : '';
        const label = (t ? fmtN(t) : '') + (m ? '<span class="dsc-d down">' + (m > 0 ? '+' : '&minus;') + Math.abs(m) + '</span>' : '');
        return '<div class="dsc-ycol"><div class="dsc-yv">' + (t || m ? label : '') + '</div><div class="dsc-ystack">' + mineSeg + segs + '</div><div class="dsc-yl">' + esc(y) + '</div></div>';
    }).join('');
    const legend = order.map(st => '<span class="dsc-lg"><span class="dsc-sw" style="background:' + dropColor(st, order) + '"></span>' + esc(st) + '</span>').join('') +
        (Object.keys(mine).length ? '<span class="dsc-lg"><span class="dsc-sw dsc-ys-new" style="border-radius:3px"></span>this meeting</span>' : '');
    return '<div class="dsc-legend-row"><span class="dsc-muted" style="margin-right:2px">Dropped at:</span>' + legend + '</div><div class="dsc-ycols">' + cols + '</div>' +
        '<div class="dsc-foot dsc-muted">' + fmtN(program.dropped) + ' dropped in all' + deltaHtml(program.d_dropped, true) + '.</div>';
}

// ---------------------------------------------------------------- this meeting
const DEC_ORDER = ['advance', 'jump', 'hold', 'drop', 'none'];

function stageOrder(tokens, configStages) {
    const cfg = (configStages || []).filter(t => tokens.indexOf(t) >= 0);
    return cfg.concat(tokens.filter(t => cfg.indexOf(t) < 0).sort());
}

// rows: decision rows {stage, decision}; one bar per current stage
export function decisionsByStage(rows, configStages) {
    ensureStyle();
    const by = {};
    (rows || []).forEach(r => {
        const t = isDrop(r.stage) ? 'dropped' : (stageToken(r.stage) || 'no stage');
        by[t] = by[t] || { n: 0, advance: 0, jump: 0, hold: 0, drop: 0, none: 0 };
        by[t].n++;
        by[t][r.decision && DECISION_COLORS[r.decision] ? r.decision : 'none']++;
    });
    const tokens = Object.keys(by);
    if (!tokens.length) return '';
    const order = stageOrder(tokens.filter(t => t !== 'no stage' && t !== 'dropped'), configStages)
        .concat(tokens.filter(t => t === 'no stage' || t === 'dropped'));
    const max = Math.max(...order.map(t => by[t].n));
    const bars = order.map(t => {
        const b = by[t];
        const segs = DEC_ORDER.filter(d => b[d]).map(d => {
            const tip = t + ' - ' + DECISION_LABELS[d] + ': ' + b[d] + ' of ' + b.n + ' (' + Math.round(100 * b[d] / b.n) + '%)';
            return '<span class="dsc-seg dsc-hit" tabindex="0" data-dsc-tip="' + esc(tip) + '" aria-label="' + esc(tip) + '" style="flex:' + b[d] + ' 0 0; background:' + DECISION_COLORS[d] +
                (d === 'none' ? '; color:#4b5563' : '') + '">' + (b[d] / max >= 0.08 ? b[d] : '') + '</span>';
        }).join('');
        return '<div class="dsc-brow"><span class="dsc-blabel"><span class="dsc-sw" style="background:' + (configStages.indexOf(t) >= 0 ? stageColor(t, configStages) : OTHER) + '"></span>' + esc(t) + '</span>' +
            '<span class="dsc-btrack"><span class="dsc-bar" style="width:' + (100 * b.n / max).toFixed(1) + '%">' + segs + '</span></span><span class="dsc-bn">' + b.n + '</span></div>';
    }).join('');
    const legend = DEC_ORDER.map(d => '<span class="dsc-lg"><span class="dsc-sw" style="background:' + DECISION_COLORS[d] + '"></span>' + DECISION_LABELS[d] + '</span>').join('');
    return '<div class="dsc-legend-row">' + legend + '</div>' + bars;
}

// accessions per stage now, and after the decisions of this meeting
export function stageShift(rows, configStages) {
    ensureStyle();
    const now = {}, after = {};
    let leaving = 0, untouched = 0;
    (rows || []).forEach(r => {
        if (isDrop(r.stage)) return;
        const t = stageToken(r.stage);
        if (!t || configStages.indexOf(t) < 0) { untouched++; return; }
        now[t] = (now[t] || 0) + 1;
        if (r.decision === 'drop') { leaving++; return; }
        const nt = (r.decision === 'advance' || r.decision === 'jump') && r.new_stage ? stageToken(r.new_stage) : t;
        after[nt] = (after[nt] || 0) + 1;
    });
    const order = (configStages || []).filter(t => now[t] || after[t]);
    if (!order.length) return '';
    const max = Math.max(...order.map(t => Math.max(now[t] || 0, after[t] || 0)));
    const col = t => {
        const a = now[t] || 0, b = after[t] || 0, d = b - a;
        const tip = t + ': ' + a + ' now, ' + b + ' after the decisions' + (d ? ' (' + (d > 0 ? '+' : '') + d + ')' : '');
        return '<div class="dsc-col dsc-hit" tabindex="0" data-dsc-tip="' + esc(tip) + '" aria-label="' + esc(tip) + '">' +
            '<div class="dsc-delta ' + (d > 0 ? 'up' : d < 0 ? 'down' : '') + '">' + (d ? (d > 0 ? '+' : '') + d : '&nbsp;') + '</div>' +
            '<div class="dsc-pair"><span class="dsc-cb now" style="height:' + (100 * a / max).toFixed(1) + '%"></span>' +
            '<span class="dsc-cb" style="height:' + (100 * b / max).toFixed(1) + '%; background:' + stageColor(t, configStages) + '"></span></div>' +
            '<div class="dsc-clabel">' + esc(t) + '</div></div>';
    };
    return '<div class="dsc-legend-row"><span class="dsc-lg"><span class="dsc-sw" style="background:#cbd5e1"></span>Now</span>' +
        '<span class="dsc-lg"><span class="dsc-sw" style="background:' + stageColor(configStages[Math.floor(configStages.length / 2)], configStages) + '"></span>After the decisions</span></div>' +
        '<div class="dsc-cols">' + order.map(col).join('') + '</div>' +
        '<div class="dsc-foot">' + (leaving ? '<span style="color:#dc2626"><b>&minus;' + leaving + '</b> dropped</span>' : '<span class="dsc-muted">none dropped yet</span>') +
        (untouched ? ' &middot; <span class="dsc-muted">' + untouched + ' without a configured stage not shown</span>' : '') + '</div>';
}

// ---------------------------------------------------------------- style and tooltip
let styled = false;
function ensureStyle() {
    if (styled || typeof document === 'undefined') return;
    styled = true;
    const st = document.createElement('style');
    st.textContent = `
.dsc-muted { color: #6b7280; }
.dsc-empty { color: #6b7280; padding: 20px 0; text-align: center; }
.dsc-donut-wrap { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }
.dsc-donut-wrap svg { flex: none; }
.dsc-big { font-size: 26px; font-weight: 800; fill: #111827; }
.dsc-small { font-size: 12px; fill: #6b7280; }
.dsc-legend { flex: 1; min-width: 150px; font-size: 12px; }
.dsc-leg { display: flex; align-items: center; gap: 6px; padding: 2px 0; }
.dsc-leg-name { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; } .dsc-leg-name i { color: #9ca3af; font-style: normal; }
.dsc-leg-v { font-variant-numeric: tabular-nums; white-space: nowrap; }
.dsc-sw { display: inline-block; width: 10px; height: 10px; border-radius: 3px; flex: none; }
.dsc-drop { margin-top: 8px; padding-top: 6px; border-top: 1px dashed #e5e7eb; color: #4b5563; }
.dsc-drop .glyphicon { color: #dc2626; }
.dsc-legend-row { display: flex; flex-wrap: wrap; gap: 4px 12px; font-size: 11px; color: #4b5563; margin-bottom: 8px; }
.dsc-lg { display: inline-flex; align-items: center; gap: 4px; }
.dsc-brow { display: flex; align-items: center; gap: 8px; margin: 0 0 5px 0; font-size: 12px; }
.dsc-blabel { width: 96px; flex: none; display: flex; align-items: center; gap: 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 600; }
.dsc-btrack { flex: 1; min-width: 60px; }
.dsc-bar { display: flex; gap: 2px; height: 18px; min-width: 4px; }
.dsc-seg { display: block; height: 18px; line-height: 18px; text-align: center; color: #fff; font-size: 10px; font-weight: 700; min-width: 3px; }
.dsc-seg:first-child { border-radius: 4px 0 0 4px; } .dsc-seg:last-child { border-radius: 0 4px 4px 0; } .dsc-seg:only-child { border-radius: 4px; }
.dsc-bn { width: 30px; flex: none; text-align: right; color: #6b7280; font-variant-numeric: tabular-nums; }
.dsc-cols { display: flex; align-items: flex-end; gap: 10px; height: 150px; padding-top: 4px; overflow-x: auto; }
.dsc-col { flex: 1 0 34px; max-width: 64px; height: 100%; display: flex; flex-direction: column; align-items: center; }
.dsc-pair { flex: 1; width: 100%; display: flex; align-items: flex-end; gap: 2px; justify-content: center; }
.dsc-cb { width: 42%; max-width: 18px; min-height: 2px; border-radius: 4px 4px 0 0; }
.dsc-cb.now { background: #cbd5e1; }
.dsc-clabel { font-size: 11px; font-weight: 600; margin-top: 4px; border-top: 1px solid #d1d5db; width: 100%; text-align: center; padding-top: 2px; }
.dsc-delta { font-size: 11px; font-weight: 700; height: 15px; } .dsc-delta.up { color: #15803d; } .dsc-delta.down { color: #b91c1c; }
.dsc-foot { font-size: 12px; margin-top: 6px; }
.dsc-ycols { display: flex; align-items: stretch; gap: 6px; height: 170px; overflow-x: auto; }
.dsc-ycol { flex: 1 0 30px; max-width: 70px; display: flex; flex-direction: column; }
.dsc-yv { font-size: 11px; font-weight: 700; text-align: center; height: 16px; white-space: nowrap; font-variant-numeric: tabular-nums; }
.dsc-yv .dsc-d { margin-left: 2px; }
.dsc-ystack { flex: 1; display: flex; flex-direction: column; justify-content: flex-end; gap: 2px; align-items: center; }
.dsc-ys { display: block; width: 70%; max-width: 30px; min-height: 2px; }
.dsc-ystack .dsc-ys:first-child { border-radius: 4px 4px 0 0; }
.dsc-ys-new { background: repeating-linear-gradient(135deg, #111827 0 2px, #fff 2px 5px); box-shadow: inset 0 0 0 1px #111827; }
.dsc-yl { font-size: 11px; font-weight: 600; text-align: center; border-top: 1px solid #d1d5db; padding-top: 2px; margin-top: 2px; }
.dsc-d { font-size: 11px; font-weight: 700; } .dsc-d.up { color: #15803d; } .dsc-d.down { color: #b91c1c; }
.dsc-ft { font-size: 12px; font-weight: 700; fill: #374151; }
.dsc-fn { font-size: 12px; font-weight: 700; fill: #111827; font-variant-numeric: tabular-nums; }
.dsc-fk { font-size: 11px; font-weight: 400; fill: #6b7280; }
.dsc-row:hover, .dsc-row:focus { fill: rgba(17,24,39,.04); }
.dsc-fd { font-size: 11px; font-weight: 700; } .dsc-fd.up { fill: #15803d; } .dsc-fd.down { fill: #b91c1c; }
rect.dsc-hit:not(.dsc-row):hover, rect.dsc-hit:not(.dsc-row):focus { filter: brightness(1.08); stroke: #111827; stroke-width: 1.5; }
.dsc-hit { cursor: default; outline: none; }
path.dsc-hit:hover, path.dsc-hit:focus { filter: brightness(1.08); stroke: #111827; }
.dsc-seg:hover, .dsc-seg:focus, .dsc-col:hover .dsc-cb, .dsc-col:focus .dsc-cb { filter: brightness(1.1); box-shadow: 0 0 0 1px #111827 inset; }
.dsc-tip { position: fixed; z-index: 10000; pointer-events: none; background: #111827; color: #fff; font-size: 12px; padding: 6px 9px; border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,.2); max-width: 320px; }`;
    document.head.appendChild(st);
    let tip = null;
    const show = (el, x, y) => {
        if (!tip) { tip = document.createElement('div'); tip.className = 'dsc-tip'; document.body.appendChild(tip); }
        tip.textContent = el.getAttribute('data-dsc-tip');
        tip.style.display = 'block';
        const r = tip.getBoundingClientRect();
        tip.style.left = Math.max(6, Math.min(window.innerWidth - r.width - 6, x + 12)) + 'px';
        tip.style.top = Math.max(6, y - r.height - 10) + 'px';
    };
    const hide = () => { if (tip) tip.style.display = 'none'; };
    document.addEventListener('mousemove', e => {
        const el = e.target.closest && e.target.closest('[data-dsc-tip]');
        if (el) show(el, e.clientX, e.clientY); else hide();
    });
    document.addEventListener('focusin', e => {
        const el = e.target.closest && e.target.closest('[data-dsc-tip]');
        if (el) { const r = el.getBoundingClientRect(); show(el, r.left + r.width / 2, r.top); } else hide();
    });
    document.addEventListener('scroll', hide, true);
}
