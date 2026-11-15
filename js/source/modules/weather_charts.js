/*
 * Small SVG charts of the Weather page (/breeders/weather): one y axis per
 * chart, thin marks, hover tooltips, optional crop-stage bands so the charts
 * of a season line up with the stress calendar.
 *
 *   chartXY(el, points, series, opt)   lines / bars over dates
 *   stressStrip(el, stress, rows, opt) day-by-day stress calendar
 *   catBars(el, items, opt)            one bar per category (years, locations, trials)
 *
 * Author: Chris Simoes
 */

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export const M = { l: 44, r: 10, t: 18, b: 24 };    // shared margins so stacked charts align

function niceTicks(min, max, n) {
    if (min === max) { min -= 1; max += 1; }
    const step0 = (max - min) / (n || 5);
    const mag = Math.pow(10, Math.floor(Math.log10(step0)));
    const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => s >= step0) || step0;
    const ticks = [];
    for (let v = Math.floor(min / step) * step; v <= Math.ceil(max / step) * step + step / 2; v += step) ticks.push(Math.round(v * 1e6) / 1e6);
    return ticks;
}

// crop-stage bands behind a plot: alternating light fills, the critical stage tinted
function bandsSvg(bands, X, ih, withLabels) {
    if (!bands || !bands.length) return '';
    return bands.map((b, i) => {
        const x0 = X(b.from) - (b.half || 0), x1 = X(b.to) + (b.half || 0);
        const fill = b.critical ? 'rgba(245,158,11,.13)' : (i % 2 ? 'rgba(148,163,184,.08)' : 'rgba(148,163,184,0)');
        return '<rect x="' + x0.toFixed(1) + '" y="0" width="' + Math.max(0, x1 - x0).toFixed(1) + '" height="' + ih + '" fill="' + fill + '"/>'
            + (i ? '<line x1="' + x0.toFixed(1) + '" x2="' + x0.toFixed(1) + '" y1="0" y2="' + ih + '" stroke="#cbd5e1" stroke-dasharray="2 3"/>' : '')
            + (withLabels && x1 - x0 > 34 ? '<text x="' + ((x0 + x1) / 2).toFixed(1) + '" y="-5" text-anchor="middle" font-size="10" fill="' + (b.critical ? '#92400e' : '#6b7280') + '"' + (b.critical ? ' font-weight="600"' : '') + '>' + esc(b.label) + '</text>' : '');
    }).join('');
}

function dayScale(pts, iw, bars) {
    const x0 = pts[0].x, x1 = pts[pts.length - 1].x;
    const slot = iw / Math.max(1, pts.length);
    const X = v => (x1 === x0 ? iw / 2 : bars ? ((v - x0) / (x1 - x0)) * (iw - slot) + slot / 2 : ((v - x0) / (x1 - x0)) * iw);
    return { X, slot };
}

function hover(el, svg, W, pts, X, render) {
    const tip = el.find('.wx-tip');
    el.find('.wx-hit').on('mousemove', function (ev) {
        const rect = svg.getBoundingClientRect();
        const scale = W / rect.width;
        const mx = (ev.clientX - rect.left) * scale - M.l;
        let best = 0, bd = Infinity;
        pts.forEach((p, i) => { const dd = Math.abs(X(p.x) - mx); if (dd < bd) { bd = dd; best = i; } });
        const cx = X(pts[best].x);
        el.find('.wx-cross').attr({ x1: cx, x2: cx }).show();
        tip.html(render(pts[best], best, cx));
        const left = (cx + M.l) / scale;
        tip.css({ display: 'block', top: 4, left: left > rect.width / 2 ? left - tip.outerWidth() - 12 : left + 12 });
    }).on('mouseleave', () => { tip.hide(); el.find('.wx-cross, .wx-dot').hide(); });
}

export function chartXY($, sel, pts, series, opt) {
    opt = opt || {};
    const el = $(sel);
    if (!el.length) return;
    if (!pts.length) { el.html('<p class="wx-muted wx-small">No data.</p>'); return; }
    const W = Math.max(280, el.width() || 600), H = opt.height || 200;
    const iw = W - M.l - M.r, ih = H - M.t - M.b;
    const ys = [];
    pts.forEach(p => series.forEach(s => { if (p[s.key] !== null && p[s.key] !== undefined) ys.push(p[s.key]); }));
    if (!ys.length) { el.html('<p class="wx-muted wx-small">No data.</p>'); return; }
    (opt.refLines || []).forEach(r => { if (r.y >= Math.min(...ys) - 8 && r.y <= Math.max(...ys) + 8) ys.push(r.y); });
    let ymin = Math.min(...ys), ymax = Math.max(...ys);
    if (opt.zero) ymin = Math.min(0, ymin);
    const ticks = niceTicks(ymin, ymax, 4);
    ymin = ticks[0]; ymax = ticks[ticks.length - 1];
    const bars = series.some(s => s.type === 'bar');
    const { X, slot } = dayScale(pts, iw, bars || opt.slots);
    const Y = v => ih - ((v - ymin) / (ymax - ymin)) * ih;
    let g = bandsSvg((opt.bands || []).map(b => Object.assign({ half: (bars || opt.slots) ? slot / 2 : 0 }, b)), X, ih, opt.bandLabels !== false);
    g += '<g class="grid">' + ticks.map(t => '<line x1="0" x2="' + iw + '" y1="' + Y(t) + '" y2="' + Y(t) + '"/>').join('') + '</g>';
    g += '<g class="axis">' + ticks.map(t => '<text x="-6" y="' + (Y(t) + 3.5) + '" text-anchor="end">' + t + '</text>').join('') + '</g>';
    if (ymin < 0 && ymax > 0) g += '<line class="zero" x1="0" x2="' + iw + '" y1="' + Y(0) + '" y2="' + Y(0) + '"/>';
    (opt.refLines || []).forEach(r => {
        if (r.y < ymin || r.y > ymax) return;
        g += '<line x1="0" x2="' + iw + '" y1="' + Y(r.y) + '" y2="' + Y(r.y) + '" stroke="' + (r.color || '#9ca3af') + '" stroke-dasharray="4 3"/><text x="' + (iw - 2) + '" y="' + (Y(r.y) - 3) + '" text-anchor="end" fill="#6b7280" font-size="10">' + esc(r.label) + '</text>';
    });
    const every = Math.max(1, Math.ceil(pts.length / 7));
    g += '<g class="axis">' + pts.map((p, i) => (i % every ? '' : '<text x="' + X(p.x) + '" y="' + (ih + 16) + '" text-anchor="middle">' + esc(p.short || String(p.label).slice(5)) + '</text>')).join('') + '</g>';
    series.forEach(s => {
        if (s.type === 'bar') {
            const bw = Math.max(1, Math.min(14, slot - 2));
            g += pts.map(p => {
                const v = p[s.key];
                if (v === null || v === undefined || v <= 0) return '';
                const y = Y(v), h = Y(Math.max(0, ymin)) - y;
                return '<rect x="' + (X(p.x) - bw / 2).toFixed(1) + '" y="' + y.toFixed(1) + '" width="' + bw.toFixed(1) + '" height="' + Math.max(0.5, h).toFixed(1) + '" rx="' + Math.min(2, bw / 3) + '" fill="' + ((s.colorOf && s.colorOf(p)) || s.color) + '"/>';
            }).join('');
        }
        else {
            let d = '', pen = false;
            pts.forEach(p => {
                const v = p[s.key];
                if (v === null || v === undefined) { pen = false; return; }
                d += (pen ? 'L' : 'M') + X(p.x).toFixed(1) + ',' + Y(v).toFixed(1);
                pen = true;
            });
            g += '<path d="' + d + '" fill="none" stroke="' + s.color + '" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"' + (s.dash ? ' stroke-dasharray="5 4"' : '') + '/>';
        }
    });
    g += '<line class="wx-cross" x1="0" x2="0" y1="0" y2="' + ih + '" stroke="#6b7280" stroke-width="1" style="display:none"/>';
    g += series.filter(s => s.type !== 'bar').map((s, i) => '<circle class="wx-dot wx-dot' + i + '" r="4" fill="' + s.color + '" stroke="#fff" stroke-width="2" style="display:none"/>').join('');
    g += '<rect class="wx-hit" x="0" y="0" width="' + iw + '" height="' + ih + '" fill="transparent"/>';
    el.html('<svg viewBox="0 0 ' + W + ' ' + H + '" height="' + H + '" role="img" aria-label="' + esc(series.map(s => s.label).join(', ')) + '"><g transform="translate(' + M.l + ',' + M.t + ')">' + g + '</g></svg><div class="wx-tip"></div>');
    const lines = series.filter(s => s.type !== 'bar');
    hover(el, el.find('svg')[0], W, pts, X, (p, i, cx) => {
        lines.forEach((s, k) => {
            const v = p[s.key];
            const dot = el.find('.wx-dot' + k);
            if (v === null || v === undefined) dot.hide(); else dot.attr({ cx, cy: Y(v) }).show();
        });
        return '<b>' + esc(p.label) + '</b>' + (p.stage ? ' <span style="opacity:.75">' + esc(p.stage) + '</span>' : '') + '<br>'
            + series.map(s => '<i style="background:' + s.color + '"></i>' + esc(s.label) + ': ' + (p[s.key] === null || p[s.key] === undefined ? '–' : (+p[s.key]).toFixed(s.digits === undefined ? 1 : s.digits) + ' ' + s.unit)).join('<br>');
    });
}

// stress calendar: one row per kind of stress, one cell per day, the stages on top
export function stressStrip($, sel, stress, rows, opt) {
    opt = opt || {};
    const el = $(sel);
    if (!el.length || !stress.length) return;
    const W = Math.max(280, el.width() || 600);
    const rowH = 16, gap = 4;
    const H = M.t + rows.length * (rowH + gap) + 22;
    const iw = W - M.l - M.r, ih = rows.length * (rowH + gap) - gap;
    const pts = stress.map(d => ({ x: new Date(d.date + 'T12:00:00').getTime(), label: d.date, d }));
    const { X, slot } = dayScale(pts, iw, true);
    const cw = Math.max(1, slot - (slot > 4 ? 1 : 0));
    let g = bandsSvg((opt.bands || []).map(b => Object.assign({ half: slot / 2 }, b)), X, ih, true);
    rows.forEach((r, k) => {
        const y = k * (rowH + gap);
        g += '<text x="-6" y="' + (y + rowH - 4) + '" text-anchor="end" font-size="10.5" fill="#374151">' + esc(r.label) + '</text>';
        g += '<rect x="0" y="' + y + '" width="' + iw + '" height="' + rowH + '" fill="#f8fafc"/>';
        g += pts.map(p => (p.d[r.key] ? '<rect x="' + (X(p.x) - cw / 2).toFixed(1) + '" y="' + y + '" width="' + cw.toFixed(1) + '" height="' + rowH + '" rx="' + Math.min(2, cw / 3) + '" fill="' + r.color + '"/>' : '')).join('');
    });
    const every = Math.max(1, Math.ceil(pts.length / 7));
    g += '<g class="axis">' + pts.map((p, i) => (i % every ? '' : '<text x="' + X(p.x) + '" y="' + (ih + 15) + '" text-anchor="middle">' + esc(String(p.label).slice(5)) + '</text>')).join('') + '</g>';
    g += '<line class="wx-cross" x1="0" x2="0" y1="0" y2="' + ih + '" stroke="#6b7280" stroke-width="1" style="display:none"/>';
    g += '<rect class="wx-hit" x="0" y="0" width="' + iw + '" height="' + ih + '" fill="transparent"/>';
    el.html('<svg viewBox="0 0 ' + W + ' ' + H + '" height="' + H + '" role="img" aria-label="Stress calendar"><g transform="translate(' + M.l + ',' + M.t + ')">' + g + '</g></svg><div class="wx-tip"></div>');
    hover(el, el.find('svg')[0], W, pts, X, p => {
        const on = rows.filter(r => p.d[r.key]);
        return '<b>' + esc(p.label) + '</b>' + (opt.stageOf ? ' <span style="opacity:.75">' + esc(opt.stageOf(p.label)) + '</span>' : '') + '<br>'
            + (on.length ? on.map(r => '<i style="background:' + r.color + '"></i>' + esc(r.label)).join('<br>') : 'no stress') + (opt.detail ? '<br>' + opt.detail(p.label) : '');
    });
}

// one horizontal bar per item: { label, value, highlight, note }
export function catBars($, sel, items, opt) {
    opt = opt || {};
    const el = $(sel);
    if (!el.length) return;
    const vals = items.map(i => i.value).filter(v => v !== null && v !== undefined);
    if (!vals.length) { el.html('<p class="wx-muted wx-small">No data.</p>'); return; }
    const lo = Math.min(0, ...vals), hi = Math.max(0, ...vals);
    const span = hi - lo || 1;
    const ref = opt.ref;
    el.html('<div class="wx-cbars">' + items.map(i => {
        const v = i.value;
        const left = ((Math.min(0, v === null ? 0 : v) - lo) / span) * 100;
        const width = v === null || v === undefined ? 0 : (Math.abs(v) / span) * 100;
        return '<div class="wx-cbar' + (i.highlight ? ' on' : '') + '" title="' + esc(i.label + ': ' + (v === null || v === undefined ? 'no data' : (+v).toFixed(opt.digits || 0) + ' ' + (opt.unit || '')) + (i.note ? ' · ' + i.note : '')) + '">'
            + '<span class="wx-cbar-l">' + esc(i.label) + '</span>'
            + '<span class="wx-cbar-t">' + (ref !== null && ref !== undefined ? '<span class="wx-cbar-ref" style="left:' + (((ref - lo) / span) * 100).toFixed(1) + '%"></span>' : '')
            + '<span class="wx-cbar-b" style="left:' + left.toFixed(1) + '%;width:' + Math.max(v ? 0.6 : 0, width).toFixed(1) + '%;background:' + (i.highlight ? (opt.highlightColor || '#1d6fa5') : (opt.color || '#9cc3de')) + (i.faded ? ';opacity:.45' : '') + '"></span></span>'
            + '<span class="wx-cbar-v">' + (v === null || v === undefined ? '–' : (+v).toFixed(opt.digits || 0)) + '</span></div>';
    }).join('') + (ref !== null && ref !== undefined ? '<div class="wx-small wx-muted" style="margin-top:4px"><span class="wx-cbar-refkey"></span> ' + esc(opt.refLabel || 'median') + ' ' + (+ref).toFixed(opt.digits || 0) + ' ' + esc(opt.unit || '') + '</div>' : '') + '</div>');
}
