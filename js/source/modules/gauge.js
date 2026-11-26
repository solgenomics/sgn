/*
 * Gauge (speedometer dial) for any Breedbase tool.
 *
 *   import { gaugeHtml, diseaseBands, relativeBands } from '../modules/gauge.js';
 *
 *   // disease reaction: score on the trait scale, lower is better
 *   el.innerHTML = gaugeHtml({
 *       title: 'Late blight', min: 1, max: 9, reverse: true, value: 2.1,
 *       bands: diseaseBands(),                      // S, MS, I, MR, R on the 0..1 resistance axis
 *       bandsOnFraction: true,                      // bands are given on 0..1 of the dial, not in score units
 *       valueText: '2.1 on 1-9', marks: [{ value: 6.8, label: 'Atlantic' }],
 *   });
 *
 *   // yield relative to a check: % of the check, 100 = same yield
 *   el.innerHTML = gaugeHtml({
 *       title: 'Marketable yield', min: 70, max: 130, value: 112,
 *       bands: relativeBands(70, 130), valueText: '112% of Atlantic',
 *       startLabel: 'Lower', endLabel: 'Higher',
 *   });
 *
 * Options (gaugeSvg and gaugeHtml):
 *   min, max      ends of the dial in the tool's units (default 0..1)
 *   reverse       true when lower values are better: min is drawn on the right
 *   value         where the needle points (null/undefined = no needle)
 *   bands         [{ to, name, short, color, ink }] in increasing order; each band ends at `to`
 *                 (the last one at max). With bandsOnFraction, `to` is 0..1 of the dial (left to right).
 *   marks         [{ value, label }] numbered markers outside the dial (e.g. check varieties)
 *   startLabel / endLabel   words under the two ends of the dial
 *   clampBand     name of a band the needle must stay in (a class chosen by the user)
 * gaugeHtml also takes: title, valueText (plain text), readout (HTML, replaces the
 *   band pill + valueText line), note (plain text), legend (default true: list the marks).
 *
 * Everything is inline SVG plus a small stylesheet added once to the page
 * (class prefix bb-gauge), so it prints and needs nothing else.
 */

const CSS = `
.bb-gauges { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px 18px; margin: 6px 0 4px; }
.bb-gauge { margin: 0; text-align: center; break-inside: avoid; font-family: "Helvetica Neue", Arial, sans-serif; }
.bb-gauge-title { font-size: 12.5px; font-weight: 700; margin-bottom: 2px; }
.bb-gauge-svg { width: 100%; max-width: 250px; height: auto; display: block; margin: 0 auto; }
.bb-gauge-read { font-size: 12px; margin-top: 2px; }
.bb-gauge-pill { display: inline-block; padding: 1px 7px; border-radius: 10px; font-size: 11px; font-weight: 600; }
.bb-gauge-val { color: #5f6b73; white-space: nowrap; margin-left: 4px; }
.bb-gauge-legend { display: flex; flex-wrap: wrap; justify-content: center; gap: 2px 10px; font-size: 10.5px; color: #5f6b73; margin-top: 3px; }
.bb-gauge-legend i { display: inline-block; width: 14px; height: 14px; line-height: 12px; border: 1.5px solid #4b5563; border-radius: 50%; font-style: normal; font-weight: 700; font-size: 8.5px; color: #374151; margin-right: 3px; text-align: center; }
.bb-gauge-note { font-size: 11px; color: #5f6b73; margin-top: 2px; }
.bb-gauge-none { font-size: 11px; color: #5f6b73; padding: 30px 0; border: 1px dashed #dfe3e6; border-radius: 6px; }
`;

export function ensureGaugeCss() {
    if (typeof document === 'undefined' || document.getElementById('bb-gauge-css')) return;
    const st = document.createElement('style');
    st.id = 'bb-gauge-css';
    st.textContent = CSS;
    document.head.appendChild(st);
}

function esc(s) {
    return String(s === undefined || s === null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

/* ------------------------------------------------------------------ presets */

// reaction classes on the 0..1 resistance axis (0 = susceptible end); use with bandsOnFraction
export function diseaseBands() {
    return [
        { to: 0.25, name: 'Susceptible', short: 'S', color: '#c0392b', ink: '#fff' },
        { to: 0.4, name: 'Moderately susceptible', short: 'MS', color: '#e67e22', ink: '#fff' },
        { to: 0.55, name: 'Intermediate', short: 'I', color: '#f1c40f', ink: '#5b4a00' },
        { to: 0.75, name: 'Moderately resistant', short: 'MR', color: '#7cb342', ink: '#fff' },
        { to: 1, name: 'Resistant', short: 'R', color: '#2e7d32', ink: '#fff' },
    ];
}

// value relative to a reference in % (100 = same as the reference, e.g. yield as % of a check);
// cuts are the class limits in %, clipped to the dial.
// opt.wording 'level' (default: Well below .. Well above) or 'better' (Much worse .. Much better);
// opt.lowerIsBetter: low values are the good ones (green); draw the dial with reverse: true
// so the good end stays on the right.
export function relativeBands(min, max, cuts, opt) {
    opt = opt || {};
    const c = cuts || [90, 97, 103, 110];
    let names = opt.wording === 'better' ? ['Much worse', 'Worse', 'Similar', 'Better', 'Much better'] : ['Well below', 'Below', 'Similar', 'Above', 'Well above'];
    let shorts = opt.wording === 'better' ? ['−−', '−', '=', '+', '++'] : ['−−', '−', '=', '+', '++'];
    let colors = [['#c0392b', '#fff'], ['#e67e22', '#fff'], ['#cfd8dc', '#37474f'], ['#7cb342', '#fff'], ['#2e7d32', '#fff']];
    if (opt.lowerIsBetter) {
        colors = colors.slice().reverse();
        if (opt.wording === 'better') { names = names.slice().reverse(); shorts = shorts.slice().reverse(); }
    }
    const base = names.map((n, i) => ({ name: n, short: shorts[i], color: colors[i][0], ink: colors[i][1] }));
    let prev = min;
    return base.map((b, i) => Object.assign({}, b, { to: i < c.length ? Math.min(max, Math.max(min, c[i])) : max }))
        .filter(b => { const keep = b.to > prev; if (keep) prev = b.to; return keep; });   // classes outside the dial drop out
}

/* ------------------------------------------------------------------ geometry */

// position of a value on the dial, 0 (left) .. 1 (right), clamped
export function fractionOf(value, o) {
    if (value === null || value === undefined || value === '' || isNaN(value)) return null;
    const min = o.min === undefined ? 0 : +o.min, max = o.max === undefined ? 1 : +o.max;
    if (!(max > min)) return null;
    const f = Math.max(0, Math.min(1, (+value - min) / (max - min)));
    return o.reverse ? 1 - f : f;
}

// bands as [from, to] fractions of the dial, left to right
export function bandRanges(o) {
    const bands = o.bands || [];
    let prev = 0;
    return bands.map(b => {
        const to = o.bandsOnFraction ? +b.to : fractionOf(b.to, Object.assign({}, o, { reverse: false }));
        const r = Object.assign({}, b, { from: prev, to: to === null ? 1 : to });
        prev = r.to;
        return r;
    }).map(b => (o.reverse && !o.bandsOnFraction) ? Object.assign({}, b, { from: 1 - b.to, to: 1 - b.from }) : b)
      .sort((a, b) => a.from - b.from);
}

// the band a dial position falls in (strictly above a band's start, as the class cut-offs)
export function bandAt(ranges, x) {
    if (x === null || x === undefined) return null;
    return ranges.slice().reverse().find(b => x > b.from) || ranges[0] || null;
}

/* ------------------------------------------------------------------ drawing */

export function gaugeSvg(o) {
    const cx = 120, cy = 124, R = 100, r = 64;
    const pt = (f, rad) => { const a = Math.PI * (1 - f); return [+(cx + rad * Math.cos(a)).toFixed(1), +(cy - rad * Math.sin(a)).toFixed(1)]; };
    const ranges = bandRanges(o);
    let x = fractionOf(o.value, o);
    if (o.clampBand) {
        const b = ranges.find(k => k.name === o.clampBand);
        if (b) x = x === null ? (b.from + b.to) / 2 : Math.min(b.to - 0.02, Math.max(b.from + 0.02, x));
    }
    let g = '';
    ranges.forEach(b => {
        if (!(b.to > b.from)) return;
        const [x1, y1] = pt(b.from, R), [x2, y2] = pt(b.to, R), [x3, y3] = pt(b.to, r), [x4, y4] = pt(b.from, r);
        g += `<path d="M${x1} ${y1} A${R} ${R} 0 0 1 ${x2} ${y2} L${x3} ${y3} A${r} ${r} 0 0 0 ${x4} ${y4} Z" fill="${esc(b.color || '#9ca3af')}"><title>${esc(b.name || '')}</title></path>`;
        if (b.short && b.to - b.from >= 0.06) {
            const [lx, ly] = pt((b.from + b.to) / 2, (R + r) / 2);
            g += `<text x="${lx}" y="${ly}" dy="3.5" text-anchor="middle" font-size="10.5" font-weight="700" fill="${esc(b.ink || '#fff')}">${esc(b.short)}</text>`;
        }
    });
    const lab = (txt, xx, anchor) => txt ? `<text x="${xx}" y="${cy + 17}" text-anchor="${anchor}" font-size="9.5" fill="#5f6b73">${esc(txt)}</text>` : '';
    g += lab(o.startLabel, cx - R, 'start') + lab(o.endLabel, cx + R, 'end');
    (o.marks || []).forEach((m, i) => {
        const mx = fractionOf(m.value, o);
        if (mx === null) return;
        const [px, py] = pt(mx, R + 10);
        g += `<g><title>${esc(m.label || '')}${m.valueText ? ': ' + esc(m.valueText) : ''}</title><circle cx="${px}" cy="${py}" r="7.5" fill="#fff" stroke="#4b5563" stroke-width="1.5"/>` +
             `<text x="${px}" y="${py}" dy="3.3" text-anchor="middle" font-size="9" font-weight="700" fill="#374151">${m.n || i + 1}</text></g>`;
    });
    if (x !== null) {
        const [nx, ny] = pt(x, r + 10), a = Math.PI * (1 - x), dx = 4 * Math.sin(a), dy = 4 * Math.cos(a);
        g += `<polygon points="${(cx - dx).toFixed(1)},${(cy - dy).toFixed(1)} ${nx},${ny} ${(cx + dx).toFixed(1)},${(cy + dy).toFixed(1)}" fill="${esc(o.needleColor || '#1d2327')}"/>` +
             `<circle cx="${cx}" cy="${cy}" r="8" fill="${esc(o.needleColor || '#1d2327')}" stroke="#fff" stroke-width="2"/>`;
    }
    return `<svg class="bb-gauge-svg" viewBox="0 0 240 146" role="img" aria-label="${esc(o.title || 'gauge')}">${g}</svg>`;
}

// the needle position and its band, for readouts
export function gaugeReading(o) {
    const ranges = bandRanges(o);
    let x = fractionOf(o.value, o);
    if (o.clampBand) { const b = ranges.find(k => k.name === o.clampBand); if (b) x = x === null ? (b.from + b.to) / 2 : Math.min(b.to - 0.02, Math.max(b.from + 0.02, x)); }
    return { x, band: bandAt(ranges, x) };
}

export function gaugeHtml(o) {
    ensureGaugeCss();
    const { x, band } = gaugeReading(o);
    const marks = (o.marks || []).map((m, i) => Object.assign({ n: i + 1 }, m)).filter(m => fractionOf(m.value, o) !== null);
    let h = `<figure class="bb-gauge">${o.title ? `<figcaption class="bb-gauge-title">${esc(o.title)}</figcaption>` : ''}`;
    h += x !== null || marks.length ? gaugeSvg(Object.assign({}, o, { marks })) : `<div class="bb-gauge-none">${esc(o.emptyText || 'No value')}</div>`;
    if (o.readout !== undefined) h += `<div class="bb-gauge-read">${o.readout}</div>`;
    else if (band || o.valueText) {
        h += `<div class="bb-gauge-read">${band && x !== null ? `<span class="bb-gauge-pill" style="background:${esc(band.color)};color:${esc(band.ink || '#fff')}">${esc(band.name)}</span>` : ''}` +
             `${o.valueText ? `<span class="bb-gauge-val">${esc(o.valueText)}</span>` : ''}</div>`;
    }
    if (o.legend !== false && marks.length) h += `<div class="bb-gauge-legend">${marks.map(m => `<span><i>${m.n}</i>${esc(m.label || '')}${m.valueText ? ' ' + esc(m.valueText) : ''}</span>`).join('')}</div>`;
    if (o.note) h += `<div class="bb-gauge-note">${esc(o.note)}</div>`;
    return h + '</figure>';
}

// several gauges in a responsive grid
export function gaugeGrid(list) {
    ensureGaugeCss();
    return `<div class="bb-gauges">${list.map(gaugeHtml).join('')}</div>`;
}
