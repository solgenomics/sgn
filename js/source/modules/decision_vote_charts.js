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
    return '<div class="dv-chart" style="max-width:720px; margin:8px 0 12px 0">' +
        (o.title ? '<div style="font-weight:600; margin-bottom:6px">' + esc(o.title) + '</div>' : '') + rows + more +
        '<div style="font-size:11px; color:#6b7280">Points: place 1 on a ballot gives the most points, the last place 1 point. Hover a bar for details.</div></div>';
}
