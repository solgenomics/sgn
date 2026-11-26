/*
 * Charts of the variety votes of decision meetings (meeting page and public
 * vote pages): participation (voted / missing, totals only: nobody is named)
 * and the most voted varieties (points of the Borda count). Plain HTML bars,
 * readable on phones; hover shows the numbers.
 *
 * Author: Chris Simoes
 */

const GREEN = '#2b7a4b';
const MISSING = '#d1d5db';

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function pct(x, total) { return total ? Math.round(100 * x / total) : 0; }

const swatch = color => '<span style="display:inline-block; width:10px; height:10px; border-radius:2px; background:' + color + '; margin:0 4px 0 0; vertical-align:baseline"></span>';

// progress: {registered, voted, invited_not_registered, expected, missing}
export function participationChart(p) {
    const total = p.voted + p.missing;
    if (!total) return '<p style="color:#6b7280">Nobody registered yet.</p>';
    const pv = pct(p.voted, total);
    const seg = (n, color, label, first, last) => n ? '<div title="' + esc(label) + '" style="flex:' + n + ' 1 0; background:' + color + '; height:22px; min-width:4px;' +
        ' border-radius:' + (first ? '4px' : '0') + ' ' + (last ? '4px 4px' : '0 0') + ' ' + (first ? '4px' : '0') + '"></div>' : '';
    const votedLabel = p.voted + ' voted (' + pv + '%)';
    const missingLabel = p.missing + ' missing (' + (100 - pv) + '%)';
    return '<div class="dv-chart" role="img" aria-label="' + esc(votedLabel + ', ' + missingLabel) + '" style="max-width:560px; margin:6px 0 4px 0">' +
        '<div style="font-size:13px; margin-bottom:4px">' +
        '<span style="margin-right:14px">' + swatch(GREEN) + '<b>' + p.voted + '</b> voted (' + pv + '%)</span>' +
        '<span>' + swatch(MISSING) + '<b>' + p.missing + '</b> missing (' + (100 - pv) + '%)</span></div>' +
        '<div style="display:flex; gap:2px">' + seg(p.voted, GREEN, votedLabel, true, !p.missing) + seg(p.missing, MISSING, missingLabel, !p.voted, true) + '</div>' +
        '<div style="font-size:11px; color:#6b7280; margin-top:3px">Of ' + total + ' invited or registered ' + (total === 1 ? 'person' : 'people') +
        '. Only totals are shown: nobody sees who voted.</div></div>';
}

// candidates: [{accession, place, points, first, n_votes, mean_rank}] sorted by place
export function mostVotedChart(candidates, opts) {
    const o = opts || {};
    const list = (candidates || []).slice(0, o.max || 20);
    if (!list.length) return '';
    const top = Math.max(1, ...list.map(x => x.points));
    const rows = list.map(x => {
        const tip = x.accession + ': ' + x.points + ' points, ' + x.first + ' vote' + (x.first === 1 ? '' : 's') + ' for place 1' +
            (x.mean_rank !== null && x.mean_rank !== undefined ? ', average place ' + x.mean_rank : '');
        return '<div title="' + esc(tip) + '" style="display:flex; align-items:center; margin:0 0 6px 0">' +
            '<div style="width:34px; flex:none; text-align:right; padding-right:8px; color:#6b7280">' + x.place + '</div>' +
            '<div style="width:28%; min-width:64px; max-width:220px; flex:none; padding-right:8px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;' + (x.place === 1 ? ' font-weight:700' : '') + '">' + esc(x.accession) + '</div>' +
            '<div style="flex:1; min-width:60px"><div style="height:16px; width:' + Math.max(1, Math.round(100 * x.points / top)) + '%; background:' + GREEN + '; border-radius:0 4px 4px 0"></div></div>' +
            '<div style="flex:none; width:104px; padding-left:8px; font-size:12px; white-space:nowrap"><b>' + x.points + '</b> pts' +
            (x.first ? ' &middot; ' + x.first + '&times; 1st' : '') + '</div></div>';
    }).join('');
    const more = (candidates || []).length > list.length ? '<div style="font-size:11px; color:#6b7280">Showing the first ' + list.length + ' of ' + candidates.length + '.</div>' : '';
    ensureStyle();
    return '<div class="dv-chart dvc-wrap">' +
        (o.title ? '<div class="dvc-title" style="margin-bottom:8px">' + esc(o.title) + '</div>' : '') + rows + more +
        '<div style="font-size:11px; color:#6b7280">Points: place 1 on a ballot gives the most points, the last place 1 point. Hover a bar for details.</div></div>';
}

// Results per accession: for each candidate (in the order of the result), how
// many voters gave it place 1, 2, ... n. Cells are shaded by the share of the
// voters; the most frequent place of each accession is in bold.
// candidates: [{accession, stock_id, place, points, n_votes, places: [count place 1, ...]}]
// opts: {n: number of places, links: link the accession names, mine: {accession: own place}}
export function placesTable(candidates, opts) {
    const o = opts || {};
    const list = candidates || [];
    const n = o.n || Math.max(0, ...list.map(x => (x.places || []).length));
    if (!list.length || !n) return '';
    const cols = Array.from({ length: n }, (_, i) => i + 1);
    const name = x => o.links && x.stock_id ? '<a target="_blank" href="/stock/' + x.stock_id + '/view">' + esc(x.accession) + '</a>' : esc(x.accession);
    const head = '<tr><th rowspan="2" style="vertical-align:bottom">Result</th><th rowspan="2" style="vertical-align:bottom">Accession</th>' +
        '<th colspan="' + n + '" style="text-align:center">Number of voters who gave it place</th><th rowspan="2" style="vertical-align:bottom">Votes</th>' +
        (o.mine ? '<th rowspan="2" style="vertical-align:bottom">Your place</th>' : '') + '</tr>' +
        '<tr>' + cols.map(i => '<th style="text-align:center; min-width:34px">' + i + '</th>').join('') + '</tr>';
    const body = list.map(x => {
        const pl = x.places || [];
        const total = x.n_votes || pl.reduce((a, b) => a + (b || 0), 0);
        const most = Math.max(0, ...pl.map(c => c || 0));
        const cells = cols.map(i => {
            const c = pl[i - 1] || 0;
            const share = total ? c / total : 0;
            const bg = c ? 'rgba(43,122,75,' + (0.12 + 0.68 * share).toFixed(2) + ')' : 'transparent';
            const color = share > 0.55 ? '#fff' : 'inherit';
            return '<td title="' + esc(x.accession + ': ' + c + ' of ' + total + ' voter' + (total === 1 ? '' : 's') + ' gave place ' + i + ' (' + pct(c, total) + '%)') + '"' +
                ' style="text-align:center; background:' + bg + '; color:' + color + (c && c === most ? '; font-weight:700' : '') + '">' + (c || '<span style="color:#c0c4cc">0</span>') + '</td>';
        }).join('');
        return '<tr><td><b>' + x.place + '</b></td><td style="white-space:nowrap">' + name(x) + '</td>' + cells + '<td>' + total + '</td>' +
            (o.mine ? '<td>' + (o.mine[x.accession] || '') + '</td>' : '') + '</tr>';
    }).join('');
    return '<div class="dv-chart" style="margin:8px 0 12px 0">' +
        (o.title ? '<div style="font-weight:600; margin-bottom:6px">' + esc(o.title) + '</div>' : '') +
        '<div class="table-responsive"><table class="table table-condensed table-bordered dv-places" style="width:auto; margin-bottom:4px"><thead>' + head + '</thead><tbody>' + body + '</tbody></table></div>' +
        '<div style="font-size:11px; color:#6b7280">Darker = more voters. The most frequent place of each accession is in bold. Hover a cell for details.</div></div>';
}

// ---------------------------------------------------------------- places chart
// Diverging stacked bars ("liked / disliked"): one bar per accession, centred on
// a middle line. The upper places of the ballots grow to the right in greens
// (place 1 darkest, at the outer end), the lower places to the left in warm
// tones (last place darkest), the middle place (odd number of candidates) in
// gray across the centre. Every segment is the share of the voters of that
// accession. A label tells how much the voters agree.

const TOP_DARK = [27, 94, 55], TOP_LIGHT = [140, 196, 158];    // #1b5e37 -> #8cc49e
const LOW_DARK = [143, 52, 24], LOW_LIGHT = [238, 164, 122];    // #8f3418 -> #eea47a
const MID = '#d9dce1';

function lerp(a, b, t) { return 'rgb(' + a.map((x, i) => Math.round(x + (b[i] - x) * t)).join(',') + ')'; }

// color of place i (1-based) of n
export function placeColor(i, n) {
    const k = Math.floor(n / 2);
    if (n % 2 && i === k + 1) return MID;
    if (i <= k) return lerp(TOP_DARK, TOP_LIGHT, k > 1 ? (i - 1) / (k - 1) : 0);
    const j = n - i + 1;   // 1 = last place
    return lerp(LOW_DARK, LOW_LIGHT, k > 1 ? (j - 1) / (k - 1) : 0);
}

function placeTextColor(i, n) {
    const k = Math.floor(n / 2);
    if (n % 2 && i === k + 1) return '#1f2937';
    const j = i <= k ? i : n - i + 1;
    return (k > 1 ? (j - 1) / (k - 1) : 0) < 0.5 ? '#fff' : '#1f2937';
}

// spread of the places given to an accession, 0 (all the same) .. 1 (split between first and last)
function agreement(places, n) {
    const tot = places.reduce((a, b) => a + (b || 0), 0);
    if (tot < 2 || n < 2) return null;
    const mean = places.reduce((a, c, i) => a + (c || 0) * (i + 1), 0) / tot;
    const sd = Math.sqrt(places.reduce((a, c, i) => a + (c || 0) * Math.pow(i + 1 - mean, 2), 0) / tot);
    const s = sd / ((n - 1) / 2);
    if (s < 0.4) return { label: 'Agree', dots: 3, tip: 'The voters gave it similar places' };
    if (s < 0.65) return { label: 'Mixed', dots: 2, tip: 'The places given vary' };
    return { label: 'Divided', dots: 1, tip: 'Some voters put it high, others low' };
}

const ordinal = i => i + (i % 100 >= 11 && i % 100 <= 13 ? 'th' : ['th', 'st', 'nd', 'rd'][i % 10] || 'th');

// candidates: [{accession, stock_id, place, n_votes, mean_rank, places}] in result order
// opts: {n, title, links, mine: {accession: own place}}
export function placesChart(candidates, opts) {
    const o = opts || {};
    const list = candidates || [];
    const n = o.n || Math.max(0, ...list.map(x => (x.places || []).length));
    if (!list.length || n < 2) return '';
    const k = Math.floor(n / 2);
    const odd = n % 2 === 1;
    const legendItem = i => '<span style="display:inline-flex; align-items:center; margin:0 10px 4px 0; white-space:nowrap">' +
        '<span style="width:12px; height:12px; border-radius:3px; background:' + placeColor(i, n) + '; margin-right:4px"></span>' +
        ordinal(i) + (i === 1 ? ' (best)' : i === n ? ' (last)' : '') + '</span>';
    const legend = '<div style="font-size:12px; color:#374151; margin:0 0 10px 0; display:flex; flex-wrap:wrap; align-items:center">' +
        '<span style="margin-right:8px; color:#6b7280">Place given by the voters:</span>' + Array.from({ length: n }, (_, i) => legendItem(i + 1)).join('') + '</div>';

    const seg = (x, i, share, c, total, outerRound) => {
        if (!c) return '';
        const w = (100 * share).toFixed(2);
        const label = share >= 0.12 ? Math.round(100 * share) + '%' : '';
        const tip = x.accession + ' | place ' + i + ': ' + c + ' of ' + total + ' voter' + (total === 1 ? '' : 's') + ' (' + pct(c, total) + '%)';
        return '<div class="dvc-seg" data-tip="' + esc(tip) + '" tabindex="0" aria-label="' + esc(tip) + '" style="width:' + w + '%; background:' + placeColor(i, n) + '; color:' + placeTextColor(i, n) +
            '; height:26px; line-height:26px; font-size:11px; font-weight:600; text-align:center; overflow:visible; white-space:nowrap; flex:none; box-shadow:0 0 0 1px #fff; border-radius:' + outerRound + '">' + label + '</div>';
    };

    const rows = list.map(x => {
        const pl = x.places || [];
        const total = x.n_votes || pl.reduce((a, b) => a + (b || 0), 0);
        if (!total) {
            return '<div class="dvc-row"><div class="dvc-place">' + x.place + '</div><div class="dvc-name">' + nameHtml(x, o) + '</div>' +
                '<div class="dvc-bars" style="color:#9ca3af; font-size:12px; text-align:center; line-height:26px">no votes</div><div class="dvc-side"></div></div>';
        }
        const sh = i => (pl[i - 1] || 0) / total;
        const midShare = odd ? sh(k + 1) : 0;
        // left, from the outer end (last place) to the centre
        const lowIdx = Array.from({ length: k }, (_, j) => n - j);            // n, n-1, ... k+1(+1)
        const topIdx = Array.from({ length: k }, (_, j) => k - j);            // k ... 1 (centre -> outer)
        const lowSum = lowIdx.reduce((a, i) => a + sh(i), 0);
        const topSum = topIdx.reduce((a, i) => a + sh(i), 0);
        let left = lowIdx.map((i, j) => seg(x, i, sh(i), pl[i - 1], total, j === 0 ? '5px 0 0 5px' : '0')).join('');
        let right = topIdx.map((i, j) => seg(x, i, sh(i), pl[i - 1], total, j === k - 1 ? '0 5px 5px 0' : '0')).join('');
        if (odd && midShare) {
            const half = midShare / 2, c = pl[k];
            const tip = x.accession + ' | place ' + (k + 1) + ' (middle): ' + c + ' of ' + total + ' voter' + (total === 1 ? '' : 's') + ' (' + pct(c, total) + '%)';
            const m = r => '<div class="dvc-seg" data-tip="' + esc(tip) + '" tabindex="0" aria-label="' + esc(tip) + '" style="width:' + (100 * half).toFixed(2) + '%; background:' + MID + '; height:26px; flex:none; box-shadow:0 0 0 1px #fff; border-radius:' + r + '"></div>';
            left += m(lowSum ? '0' : '5px 0 0 5px');
            right = m(topSum ? '0' : '0 5px 5px 0') + right;
        }
        const ag = agreement(pl, n);
        const mine = o.mine && o.mine[x.accession];
        return '<div class="dvc-row' + (x.place === 1 ? ' dvc-win' : '') + '">' +
            '<div class="dvc-place">' + (x.place === 1 ? '<span class="glyphicon glyphicon-star" style="color:#c99a06" title="Most voted"></span> ' : '') + x.place + '</div>' +
            '<div class="dvc-name">' + nameHtml(x, o) + (mine ? '<div class="dvc-mine">your place: ' + mine + '</div>' : '') + '</div>' +
            '<div class="dvc-bars">' +
            '<div class="dvc-half" style="justify-content:flex-end">' + left + '</div><div class="dvc-axis"></div>' +
            '<div class="dvc-half">' + right + '</div></div>' +
            '<div class="dvc-side">' +
            '<span class="dvc-up" title="Voters who gave it one of the top ' + k + ' place' + (k === 1 ? '' : 's') + '">' + Math.round(100 * topSum) + '% <small>top</small></span>' +
            (ag ? '<span class="dvc-ag" title="' + esc(ag.tip) + '">' + '<span class="dvc-dots">' + [1, 2, 3].map(d => '<i' + (d <= ag.dots ? ' class="on"' : '') + '></i>').join('') + '</span>' + ag.label + '</span>' : '') +
            '<span class="dvc-meta">' + total + ' vote' + (total === 1 ? '' : 's') + (x.mean_rank !== null && x.mean_rank !== undefined ? ' &middot; avg ' + x.mean_rank : '') + '</span>' +
            '</div></div>';
    }).join('');

    const scale = '<div class="dvc-row dvc-scale"><div class="dvc-place"></div><div class="dvc-name"></div><div class="dvc-bars">' +
        '<div class="dvc-half" style="justify-content:space-between"><span>100%</span><span>50%</span><span></span></div><div class="dvc-axis" style="background:transparent"></div>' +
        '<div class="dvc-half" style="justify-content:space-between"><span></span><span>50%</span><span>100%</span></div></div><div class="dvc-side"></div></div>' +
        '<div class="dvc-row dvc-scale" style="margin-top:-2px"><div class="dvc-place"></div><div class="dvc-name"></div><div class="dvc-bars">' +
        '<div class="dvc-half" style="justify-content:flex-end; padding-right:8px">&larr; lower places</div><div class="dvc-axis" style="background:transparent"></div>' +
        '<div class="dvc-half" style="padding-left:8px">upper places &rarr;</div></div><div class="dvc-side"></div></div>';

    ensureStyle();
    return '<div class="dvc-wrap" role="group" aria-label="' + esc((o.title || 'Places given to each accession') + '. Use the table below for the numbers.') + '">' +
        (o.title ? '<div class="dvc-title">' + esc(o.title) + '</div>' : '') +
        '<div class="dvc-sub">Each bar is 100% of the voters of that accession. Green to the right: they put it in the upper places; orange to the left: the lower places' +
        (odd ? '; gray: the middle place' : '') + '.</div>' + legend + rows + scale + '</div>';
}

function nameHtml(x, o) {
    return o.links && x.stock_id ? '<a target="_blank" href="/stock/' + x.stock_id + '/view" title="' + esc(x.accession) + '">' + esc(x.accession) + '</a>' : '<span title="' + esc(x.accession) + '">' + esc(x.accession) + '</span>';
}

let styled = false;
function ensureStyle() {
    if (styled || typeof document === 'undefined') return;
    styled = true;
    const css = `
.dvc-wrap { container-type: inline-size; max-width: 980px; margin: 10px 0 16px 0; padding: 14px 16px 10px 16px; border: 1px solid #e5e7eb; border-radius: 10px; background: #fff; box-shadow: 0 1px 2px rgba(16,24,40,.04); }
.dvc-title { font-weight: 700; font-size: 15px; color: #111827; margin-bottom: 2px; }
.dvc-sub { font-size: 12px; color: #6b7280; margin-bottom: 10px; }
.dvc-row { display: flex; align-items: center; gap: 10px; padding: 5px 6px; border-radius: 8px; }
.dvc-row:not(.dvc-scale):hover { background: #f8faf9; }
.dvc-win { background: #f1f8f3; }
.dvc-place { width: 40px; flex: none; text-align: right; font-weight: 700; color: #374151; font-variant-numeric: tabular-nums; }
.dvc-name { width: 22%; min-width: 90px; max-width: 220px; flex: none; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 600; color: #111827; }
.dvc-win .dvc-name { font-weight: 800; }
.dvc-mine { font-size: 11px; font-weight: 400; color: #2b7a4b; }
.dvc-bars { flex: 1; min-width: 180px; display: flex; align-items: center; }
.dvc-half { flex: 1 1 0; display: flex; align-items: center; min-width: 0; }
.dvc-axis { width: 2px; align-self: stretch; background: #9ca3af; flex: none; margin: -5px 0; }
.dvc-seg { cursor: default; transition: filter .12s; }
.dvc-seg:hover, .dvc-seg:focus { filter: brightness(1.08) saturate(1.1); outline: 2px solid #111827; outline-offset: -2px; position: relative; z-index: 1; }
.dvc-side { width: 230px; flex: none; display: flex; align-items: center; gap: 10px; font-size: 12px; color: #374151; white-space: nowrap; }
.dvc-up { font-weight: 700; font-variant-numeric: tabular-nums; min-width: 52px; }
.dvc-up small { font-weight: 400; color: #6b7280; }
.dvc-ag { display: inline-flex; align-items: center; gap: 4px; padding: 1px 7px; border-radius: 10px; background: #f3f4f6; min-width: 72px; }
.dvc-dots { display: inline-flex; gap: 2px; }
.dvc-dots i { width: 6px; height: 6px; border-radius: 50%; background: #d1d5db; display: inline-block; }
.dvc-dots i.on { background: #4b5563; }
.dvc-meta { color: #6b7280; font-variant-numeric: tabular-nums; }
.dvc-scale { padding-top: 0; padding-bottom: 0; font-size: 10px; color: #9ca3af; }
.dvc-tip { position: fixed; z-index: 10000; pointer-events: none; background: #111827; color: #fff; font-size: 12px; padding: 6px 9px; border-radius: 6px; box-shadow: 0 4px 12px rgba(0,0,0,.2); max-width: 320px; }
@container (max-width: 680px) {
  .dvc-row { flex-wrap: wrap; gap: 4px 8px; }
  .dvc-place { width: auto; }
  .dvc-name { width: auto; max-width: none; flex: 1; }
  .dvc-bars { flex-basis: 100%; min-width: 0; order: 3; }
  .dvc-side { width: auto; order: 4; }
  .dvc-scale .dvc-place, .dvc-scale .dvc-name, .dvc-scale .dvc-side { display: none; }
}`;
    const st = document.createElement('style');
    st.textContent = css;
    document.head.appendChild(st);
    // one tooltip for every chart of the page (hover and keyboard focus)
    let tip = null;
    const show = (el, x, y) => {
        if (!tip) { tip = document.createElement('div'); tip.className = 'dvc-tip'; document.body.appendChild(tip); }
        tip.textContent = el.getAttribute('data-tip');
        tip.style.display = 'block';
        const r = tip.getBoundingClientRect();
        tip.style.left = Math.max(6, Math.min(window.innerWidth - r.width - 6, x + 12)) + 'px';
        tip.style.top = Math.max(6, y - r.height - 10) + 'px';
    };
    const hide = () => { if (tip) tip.style.display = 'none'; };
    document.addEventListener('mousemove', e => {
        const el = e.target.closest && e.target.closest('.dvc-seg');
        if (el) show(el, e.clientX, e.clientY); else hide();
    });
    document.addEventListener('focusin', e => {
        const el = e.target.closest && e.target.closest('.dvc-seg');
        if (el) { const r = el.getBoundingClientRect(); show(el, r.left + r.width / 2, r.top); } else hide();
    });
    document.addEventListener('scroll', hide, true);
}
