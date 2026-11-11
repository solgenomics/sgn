/*
 * Commercial variety sheets: step-by-step editor (/tools/variety_sheet),
 * sheet page (/variety_sheet/<id>) and list (/variety_sheets).
 *
 * The same renderSheet() draws the preview in the editor and the published
 * page, so what the breeder sees is what gets printed.
 */

import '../legacy/leaflet.js';

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

/* ------------------------------------------------------------ default sheet */

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
        accession_name: acc.accession_name,
        species: acc.species || '',
        commercial_name: (acc.released_variety_name || [])[0] || '',
        tagline: '',
        market_class: '',
        release_year: String(new Date().getFullYear()),
        developed_by: (acc.evidence.programs || []).join(', '),
        former_names: [acc.accession_name].concat(acc.synonyms || []),
        pedigree: acc.pedigree || {},
        evidence: acc.evidence,
        evidence_as_of: today(),
        performance: {
            source: 'trials', analysis_id: null, analysis_name: null,
            checks: checks.map(c => ({ stock_id: c.stock_id, name: c.name })),
            primary_check_id: checks.length ? checks[0].stock_id : null,
            traits: traits.map(t => traitConfig(t)),
            year_min: '', year_max: '', results: null,
        },
        ratings: { traits: [], results: null },
        characteristics: [],
        text: { pedigree: '', market: '', production: '', disease: '', recommendations: '', acknowledgements: '', availability: '', contact: '' },
        images: [],
        options: { show_map: true, show_pct_chart: true, show_year_chart: true, show_stats: true, show_testing: true, accent: ACCENTS[0], photo_columns: 3 },
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

function sheetName(s) {
    return s.commercial_name || s.accession_name || 'This variety';
}

function autoPedigree(s) {
    const p = s.pedigree || {};
    const name = sheetName(s);
    const out = [];
    if (p.female || p.male) {
        out.push(`${name} comes from the cross ${p.female ? p.female.name : 'unknown'} \u00d7 ${p.male ? p.male.name : 'unknown'}${p.cross_type ? ' (' + p.cross_type + ')' : ''}.`);
        const gp = [];
        ['female', 'male'].forEach(k => { if (p[k]) ['female', 'male'].forEach(j => { if (p[k][j]) gp.push(p[k][j].name); }); });
        const uniq = gp.filter((g, i) => gp.indexOf(g) === i);
        if (uniq.length) out.push(`Grandparents are ${listText(uniq)}.`);
    }
    const former = (s.former_names || []).filter(n => n && n !== s.commercial_name);
    if (former.length) out.push(`${name} was evaluated as ${listText(former)}.`);
    return out.join(' ');
}

function autoTesting(s) {
    const e = s.evidence || {};
    if (!e.trials) return '';
    const years = e.year_min && e.year_max ? (e.year_min === e.year_max ? `in ${e.year_min}` : `over ${plural(e.years, 'year')} (${e.year_min}\u2013${e.year_max})`) : '';
    const countries = (e.countries || []).map(c => c.name);
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
            out.push(`${capital(label)} averaged ${num(ch.pct_of_check, 0)}% of ${ch.name} in ${plural(ch.shared_trials, 'head-to-head trial')} and was better in ${winPct}% of them${t.direction === 'lower' ? ' (lower is better)' : ''}.`);
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

function capital(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

function suggestRating(t, r) {
    if (!r || r.variety.mean === null || r.variety.mean === undefined) return 'Not rated';
    const min = parseFloat(t.scale_min), max = parseFloat(t.scale_max);
    let f = null;
    if (!isNaN(min) && !isNaN(max) && max > min) f = (r.variety.mean - min) / (max - min);
    else if (/1to9|1-9/.test(t.name)) f = (r.variety.mean - 1) / 8;
    else if (/1to5|1-5/.test(t.name)) f = (r.variety.mean - 1) / 4;
    if (f === null) return 'Not rated';
    if (t.direction !== 'lower') f = 1 - f;
    return f < 0.25 ? 'Resistant' : f < 0.45 ? 'Moderately resistant' : f < 0.6 ? 'Intermediate' : f < 0.75 ? 'Moderately susceptible' : 'Susceptible';
}

/* ---------------------------------------------------------------- the sheet */

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
    h += `<header class="vs-head"><div><h1>${esc(name)}</h1>`;
    if (s.tagline) h += `<div class="vs-tagline">${inline(s.tagline)}</div>`;
    const sub = [];
    if (s.species) sub.push(`<em>${esc(s.species)}</em>`);
    if (s.market_class) sub.push(esc(s.market_class));
    if (s.commercial_name && s.accession_name && s.commercial_name !== s.accession_name) sub.push('Experimental name ' + esc(s.accession_name));
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
    const sec = (title, body) => body ? `<section class="vs-sec"><h2>${title}</h2>${body}</section>` : '';
    h += sec('Pedigree', rich(s.text.pedigree));
    h += sec('Market features', rich(s.text.market));
    let prod = rich(s.text.production);
    if (o.show_testing !== false && autoTesting(s)) prod = `<p>${esc(autoTesting(s))}</p>` + prod;
    h += sec('Production features', prod);

    // characteristics
    const chars = (s.characteristics || []).filter(c => c.label && c.value);
    if (chars.length) {
        h += sec('Characteristics', '<dl class="vs-chars">' + chars.map(c => `<div><dt>${inline(c.label)}</dt><dd>${inline(c.value)}</dd></div>`).join('') + '</dl>');
    }

    // performance
    if (res && res.traits && perf.traits.length) {
        h += `<section class="vs-sec"><h2>Performance</h2>`;
        h += res.source === 'analysis' ? analysisTable(s) : trialTable(s);
        let charts = '';
        if (o.show_pct_chart !== false && res.source !== 'analysis' && pc) charts += pctChart(s, pc);
        if (o.show_year_chart !== false && res.source !== 'analysis' && pc) charts += yearChart(s, pc);
        if (charts) h += `<div class="vs-charts">${charts}</div>`;
        h += `</section>`;
    }

    // disease / ratings
    const rated = (s.ratings.traits || []).filter(t => t.rating && t.rating !== 'Not rated' || t.note);
    if (rated.length || s.text.disease) {
        let body = rich(s.text.disease);
        if (rated.length) {
            body += '<table class="vs-table vs-ratings"><thead><tr><th>Disease / trait</th><th>Reaction</th>' +
                ((perf.checks || []).length ? '<th>Score</th>' + perf.checks.map(c => `<th>${esc(c.name)}</th>`).join('') : '<th>Score</th>') + '</tr></thead><tbody>';
            rated.forEach(t => {
                const r = traitResult(s.ratings.results, t.trait_id);
                body += `<tr><td>${esc(t.label || t.name)}${t.note ? `<div class="vs-note">${inline(t.note)}</div>` : ''}</td><td><span class="vs-rating vs-r-${(t.rating || '').replace(/\s+/g, '-').toLowerCase()}">${esc(t.rating || '')}</span></td>`;
                body += `<td>${r ? num(r.variety.mean, t.decimals) : '\u2013'}</td>`;
                (perf.checks || []).forEach(c => {
                    const ch = r ? r.checks.find(x => x.stock_id == c.stock_id) : null;
                    body += `<td>${ch && ch.shared_trials ? num(ch.check_mean, t.decimals) : '\u2013'}</td>`;
                });
                body += '</tr>';
            });
            body += '</tbody></table>';
            const scaled = rated.filter(t => t.scale_min !== undefined && t.scale_min !== null && t.scale_max);
            if (scaled.length) body += `<div class="vs-foot">Scores are trial means on the trait scale (${esc(scaled[0].scale_min)}\u2013${esc(scaled[0].scale_max)}${scaled[0].direction === 'lower' ? ', lower is better' : ''}); check scores come from the same trials.</div>`;
        }
        h += sec('Reaction to diseases', body);
    }

    h += sec('Recommendations', rich(s.text.recommendations));

    // photos
    if ((s.images || []).length) {
        const cols = o.photo_columns || 3;
        h += `<section class="vs-sec vs-photos-sec"><div class="vs-photos" style="grid-template-columns:repeat(${cols},1fr)">` +
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
        try { this._vsMap = makeMap(this, locs, s); } catch (err) { console.log('variety sheet map: ' + err); }
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
            <ol class="vs-steps">${STEPS.map((s, i) => `<li data-step="${i}"><span class="vs-step-n">${i + 1}</span><span class="glyphicon ${s.icon}"></span> ${s.title}</li>`).join('')}</ol>
            <div class="vs-msg"></div>
            <div class="row">
              <div class="vs-form-col col-lg-7 col-md-12"><div class="vs-panel"></div>
                <div class="vs-nav">
                  <button class="btn btn-default vs-back"><span class="glyphicon glyphicon-chevron-left"></span> Back</button>
                  <span class="vs-save-state text-muted"></span>
                  <button class="btn btn-default vs-save-draft"><span class="glyphicon glyphicon-floppy-disk"></span> Save draft</button>
                  <button class="btn btn-primary vs-next">Next <span class="glyphicon glyphicon-chevron-right"></span></button>
                </div>
              </div>
              <div class="vs-preview-col col-lg-5 hidden-md hidden-sm hidden-xs">
                <div class="vs-preview-label">Live preview</div>
                <div class="vs-preview-wrap"><div class="vs-preview"></div></div>
              </div>
            </div>
          </div>`);
        this.root.on('click', '.vs-steps li', e => {
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
        this.root.find('.vs-steps li').each((j, li) => {
            $(li).toggleClass('active', j === i).toggleClass('done', !!this.sheet && j < i).toggleClass('disabled', !this.sheet && j > 0);
        });
        this.root.find('.vs-back').prop('disabled', i === 0);
        this.root.find('.vs-next').toggle(i < STEPS.length - 1).prop('disabled', !this.sheet);
        this.root.find('.vs-save-draft').toggle(!!this.sheet && !!(this.acc && this.acc.can_edit));
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
        if (!this.sheet) { this.root.find('.vs-preview').html('<div class="text-muted vs-empty">The sheet appears here as you build it.</div>'); return; }
        if (STEPS[this.step].key === 'publish') {
            const el = this.root.find('.vs-full-preview');
            el.html(renderSheet(this.sheet, { url: this.sheetId ? location.origin + '/variety_sheet/' + this.sheetId : '' }));
            drawMaps(el, this.sheet);
        } else {
            this.root.find('.vs-preview').html(renderSheet(this.sheet, { static_map: true }));
        }
    }

    /* ---------------------------------------------- step 1: accession */

    step_accession(p) {
        const acc = this.acc;
        p.html(`
          <h3>1. Choose the accession</h3>
          <p class="text-muted">Start from the accession that will become the commercial variety. You can type its experimental name, a synonym or a released name.</p>
          <div class="input-group vs-acc-search">
            <input type="text" class="form-control input-lg" id="vs_accession" placeholder="Accession name" value="${esc(acc ? acc.accession_name : '')}">
            <span class="input-group-btn"><button class="btn btn-primary btn-lg" id="vs_accession_go">Load</button></span>
          </div>
          <div id="vs_acc_info">${acc ? this.accessionCard() : ''}</div>
          <h4 class="vs-h4">Variety sheets</h4><div id="vs_sheet_list"><span class="text-muted">Loading\u2026</span></div>`);
        const input = p.find('#vs_accession');
        if (input.autocomplete) input.autocomplete({ source: '/ajax/stock/accession_autocomplete', minLength: 2, select: (e, ui) => { input.val(ui.item.value); this.findAccession(ui.item.value); } });
        p.on('click', '#vs_accession_go', () => this.findAccession(input.val()));
        input.on('keydown', e => { if (e.key === 'Enter') this.findAccession(input.val()); });
        p.on('click', '.vs-open-sheet', e => { e.preventDefault(); this.openSheet($(e.currentTarget).data('id')); });
        p.on('click', '.vs-new-sheet', e => { e.preventDefault(); this.startNewSheet(); });
        p.on('click', '.vs-del-sheet', e => { e.preventDefault(); this.deleteSheet($(e.currentTarget).data('id')); });
        this.loadSheetList();
    }

    accessionCard() {
        const a = this.acc, e = a.evidence, p = a.pedigree || {};
        const parents = (p.female || p.male) ? `${esc(p.female ? p.female.name : '?')} \u00d7 ${esc(p.male ? p.male.name : '?')}` : '<span class="text-muted">not recorded</span>';
        const mine = (a.sheets || []);
        return `<div class="panel panel-default vs-acc-card"><div class="panel-body">
            <h4><a href="/stock/${a.stock_id}/view" target="_blank">${esc(a.accession_name)}</a> ${a.species ? `<small><em>${esc(a.species)}</em></small>` : ''}</h4>
            <div class="row vs-mini-stats">
              <div class="col-xs-3"><b>${num(e.trials, 0)}</b>trials</div><div class="col-xs-3"><b>${num(e.locations, 0)}</b>locations</div>
              <div class="col-xs-3"><b>${num(e.years, 0)}</b>years${e.year_min ? ` <small>${e.year_min}\u2013${e.year_max}</small>` : ''}</div><div class="col-xs-3"><b>${num(a.images.length, 0)}</b>photos</div>
            </div>
            <table class="table table-condensed vs-kv">
              <tr><th>Pedigree</th><td>${parents}</td></tr>
              <tr><th>Synonyms</th><td>${a.synonyms.length ? esc(a.synonyms.join(', ')) : '<span class="text-muted">none</span>'}</td></tr>
              <tr><th>Released name</th><td>${a.released_variety_name.length ? esc(a.released_variety_name.join(', ')) : '<span class="text-muted">none yet</span>'}</td></tr>
              <tr><th>Programs</th><td>${esc((e.programs || []).join(', ')) || '<span class="text-muted">\u2013</span>'}</td></tr>
              <tr><th>Stored analyses</th><td>${a.analyses.length ? plural(a.analyses.length, 'analysis', 'analyses') : '<span class="text-muted">none</span>'}</td></tr>
            </table>
            ${!e.trials ? '<div class="alert alert-warning">This accession has no field trial data yet. You can still write a sheet, but the testing summary and performance tables will be empty.</div>' : ''}
            ${mine.length ? `<p><b>${plural(mine.length, 'sheet')} already exist for this accession.</b> Open one below or start a new one.</p>` : ''}
            ${this.sheet && this.sheet.stock_id == a.stock_id ? `<p class="text-success"><span class="glyphicon glyphicon-ok"></span> ${this.sheetId ? 'Editing sheet #' + this.sheetId : 'New sheet started'} \u2014 continue with <b>Next</b>.</p>` : `<button class="btn btn-success vs-new-sheet"><span class="glyphicon glyphicon-plus"></span> Start a sheet for ${esc(a.accession_name)}</button>`}
          </div></div>`;
    }

    async loadSheetList() {
        try {
            const r = await ajax('/ajax/variety_sheet/list');
            const el = this.root.find('#vs_sheet_list');
            if (!r.sheets.length) { el.html('<p class="text-muted">No variety sheets yet.</p>'); return; }
            el.html(`<table class="table table-condensed table-hover"><thead><tr><th>Commercial name</th><th>Accession</th><th>Status</th><th>Owner</th><th>Updated</th><th></th></tr></thead><tbody>` +
                r.sheets.map(s => `<tr><td><a href="/variety_sheet/${s.variety_sheet_id}" target="_blank">${esc(s.commercial_name)}</a></td><td>${esc(s.accession_name)}</td>
                  <td><span class="label label-${s.status === 'published' ? 'success' : 'default'}">${esc(s.status)}</span></td><td>${esc(s.owner || '')}</td><td>${esc(s.modified_date)}</td>
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
        this.root.find('#vs_acc_info').html('<p class="text-muted"><span class="glyphicon glyphicon-refresh vs-spin"></span> Collecting trials, traits, photos and analyses\u2026</p>');
        try {
            this.acc = await ajax('/ajax/variety_sheet/accession_summary', { data: { stock_id: stockId } });
        } catch (err) { this.message(esc(err.message), 'danger'); this.go(0); return; }
        if (!keepSheet && !(this.sheet && this.sheet.stock_id == stockId)) { this.sheet = null; this.sheetId = null; }
        if (keepSheet && this.sheet) {
            // keep the testing summary current while editing
            this.sheet.evidence = this.acc.evidence;
            this.sheet.evidence_as_of = today();
            this.sheet.pedigree = this.acc.pedigree;
        }
        if (!this.acc.can_edit) this.message('You can look at variety sheets, but only curators, breeders and submitters can save them.', 'warning');
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
            this.root.find('.vs-save-state').text(`Sheet #${id} (${r.status})`);
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    async deleteSheet(id) {
        if (!confirm('Delete this variety sheet? This cannot be undone.')) return;
        try {
            await ajax('/ajax/variety_sheet/delete', { method: 'POST', data: { sheet_id: id } });
            if (this.sheetId == id) { this.sheet = null; this.sheetId = null; this.dirty = false; }
            this.loadSheetList();
            if (this.acc) { this.acc.sheets = this.acc.sheets.filter(s => s.variety_sheet_id != id); this.root.find('#vs_acc_info').html(this.accessionCard()); }
        } catch (err) { this.message(esc(err.message), 'danger'); }
    }

    /* -------------------------------------------- step 2: identity */

    step_identity(p) {
        const s = this.sheet, a = this.acc;
        p.html(`
          <h3>2. Commercial name and identity</h3>
          <div class="form-group">
            <label for="vs_name">Commercial name</label>
            <input type="text" class="form-control input-lg" id="vs_name" maxlength="100" value="${esc(s.commercial_name)}" placeholder="e.g. Kanestio">
            <div id="vs_name_check" class="vs-name-check"></div>
          </div>
          <div class="panel panel-default"><div class="panel-heading"><b>Save the name in Breedbase</b></div><div class="panel-body">
            <div class="checkbox"><label><input type="checkbox" id="vs_opt_released" ${this.nameOptions.released_variety_name ? 'checked' : ''}> As the <b>released variety name</b> of ${esc(a.accession_name)} <span class="text-muted">\u2014 shown in the accession's "Released variety name" box; the official name.</span></label></div>
            <div class="checkbox"><label><input type="checkbox" id="vs_opt_synonym" ${this.nameOptions.synonym ? 'checked' : ''}> As a <b>synonym</b> <span class="text-muted">\u2014 searches, lists and uploads then find the accession by its commercial name.</span></label></div>
            <p class="help-block">The name is stored when you save the sheet. Leave both unticked to keep the name on the sheet only (e.g. while the name is still confidential). The experimental name ${esc(a.accession_name)} stays the record's identifier, so trial history is kept.${a.can_save_names ? '' : ' <b>Your role cannot change accession properties</b>; the name will stay on the sheet.'}</p>
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
            <textarea class="form-control vs-bind-text" data-k="pedigree" rows="4">${esc(s.text.pedigree)}</textarea>
            <p class="help-block">Use *italic* for species names and **bold** for emphasis. Add the story behind the name here too.</p></div>`);
        this.bindCommon(p);
        const nameInput = p.find('#vs_name');
        nameInput.on('input', () => { s.commercial_name = nameInput.val(); this.markDirty(); clearTimeout(this._nc); this._nc = setTimeout(() => this.checkName(), 400); });
        p.on('change', '#vs_opt_released', e => { this.nameOptions.released_variety_name = e.target.checked; });
        p.on('change', '#vs_opt_synonym', e => { this.nameOptions.synonym = e.target.checked; });
        if (!a.can_save_names) p.find('#vs_opt_released, #vs_opt_synonym').prop({ checked: false, disabled: true });
        this.checkName();
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
                el.html(`<span class="text-danger"><span class="glyphicon glyphicon-warning-sign"></span> Already used by ${r.conflicts.map(c => `<a href="/stock/${c.stock_id}/view" target="_blank">${esc(c.name)}</a> (${esc(c.as)})`).join(', ')}. It can only stay on the sheet.</span>`);
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
          <h3>3. Performance against checks</h3>
          <div class="vs-evidence well well-sm"><span class="glyphicon glyphicon-info-sign"></span> ${esc(autoTesting(s)) || 'No field trial data for this accession yet.'}</div>
          <div class="form-group">
            <label>Where do the numbers come from?</label>
            <div class="vs-source">
              <label class="vs-choice ${perf.source !== 'analysis' ? 'active' : ''}"><input type="radio" name="vs_source" value="trials" ${perf.source !== 'analysis' ? 'checked' : ''}>
                <b>Field trials, head-to-head</b><span>Trial means of the variety and each check in the trials where both were grown: % of check, trials won, paired t-test, results by year.</span></label>
              <label class="vs-choice ${perf.source === 'analysis' ? 'active' : ''} ${a.analyses.length ? '' : 'disabled'}"><input type="radio" name="vs_source" value="analysis" ${perf.source === 'analysis' ? 'checked' : ''} ${a.analyses.length ? '' : 'disabled'}>
                <b>Stored analysis</b><span>${a.analyses.length ? 'BLUPs/BLUEs from a saved analysis: value, rank among all entries, % of the trial mean.' : 'No stored analysis includes this accession.'}</span></label>
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
          <h4 class="vs-h4">Checks <small>tick up to 4; the starred check is used in the headline and charts</small></h4>
          <div id="vs_checks"></div>
          <div class="input-group input-group-sm vs-add-check"><input class="form-control" id="vs_add_check" placeholder="Add another check by name"><span class="input-group-btn"><button class="btn btn-default" id="vs_add_check_btn">Add</button></span></div>
          <h4 class="vs-h4">Traits <small>tick the traits to show; the first ticked trait is the headline trait</small></h4>
          <div id="vs_traits"></div>
          <div class="vs-compute-bar"><button class="btn btn-primary" id="vs_compute"><span class="glyphicon glyphicon-stats"></span> Compute performance</button> <span id="vs_compute_state" class="text-muted"></span></div>
          <div id="vs_results"></div>`);
        this.renderChecks();
        this.renderTraits();
        this.renderResultsSummary();

        p.on('change', 'input[name=vs_source]', e => {
            perf.source = e.target.value;
            p.find('.vs-choice').removeClass('active'); $(e.target).closest('.vs-choice').addClass('active');
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
        perf.checks.forEach(c => { if (!sugg.find(x => x.stock_id == c.stock_id)) sugg.unshift({ stock_id: c.stock_id, name: c.name, shared_trials: null }); });
        const el = this.root.find('#vs_checks');
        if (!sugg.length) { el.html('<p class="text-muted">No accessions were tested alongside this one. Add a check by name.</p>'); return; }
        el.html(`<div class="vs-check-list">` + sugg.map(c => {
            const on = perf.checks.some(x => x.stock_id == c.stock_id);
            const primary = perf.primary_check_id == c.stock_id;
            return `<label class="vs-check ${on ? 'on' : ''}"><input type="checkbox" data-id="${c.stock_id}" data-name="${esc(c.name)}" ${on ? 'checked' : ''}>
                <span class="vs-check-name">${esc(c.name)}${c.released_variety_name ? ` <small>(${esc(c.released_variety_name)})</small>` : ''}</span>
                ${c.control_plots ? '<span class="label label-info">check in trials</span>' : ''}${c.released_variety_name ? ' <span class="label label-success">released</span>' : ''}
                <span class="vs-check-n">${c.shared_trials !== null && c.shared_trials !== undefined ? plural(c.shared_trials, 'shared trial') : ''}</span>
                <a href="#" class="vs-star ${primary ? 'on' : ''}" data-id="${c.stock_id}" title="Use as the main check">${primary ? '\u2605' : '\u2606'}</a></label>`;
        }).join('') + '</div>');
        el.off().on('change', 'input[type=checkbox]', e => {
            const id = +$(e.target).data('id');
            if (e.target.checked) {
                if (perf.checks.length >= 4) { e.target.checked = false; this.message('Up to 4 checks keep the sheet readable.', 'warning'); return; }
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
                perf.checks.push({ stock_id: id, name: c.name });
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
                if (perf.checks.length >= 4) { this.message('Up to 4 checks keep the sheet readable.', 'warning'); return; }
                perf.checks.push({ stock_id: m.stock_id, name: m.name });
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
        const perf = this.sheet.performance;
        const el = this.root.find('#vs_traits');
        const avail = this.availableTraits();
        if (perf.source === 'analysis' && !perf.analysis_id) { el.html('<p class="text-muted">Choose an analysis first.</p>'); return; }
        if (!avail.length) { el.html('<p class="text-muted">No numeric traits available.</p>'); return; }
        const chosen = perf.traits.map(t => t.trait_id);
        const ordered = perf.traits.map(t => avail.find(a => a.trait_id == t.trait_id) || t).concat(avail.filter(a => chosen.indexOf(a.trait_id) < 0));
        el.html(`<div class="vs-trait-table-wrap"><table class="table table-condensed vs-trait-table"><thead><tr><th></th><th>Trait</th><th>Label on the sheet</th><th>Unit</th><th>Better</th><th>${perf.source === 'analysis' ? 'Entries' : 'Trials'}</th><th></th></tr></thead><tbody>` +
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

    async computePerformance() {
        const perf = this.sheet.performance;
        if (!perf.traits.length) { this.message('Tick at least one trait.', 'warning'); return; }
        if (perf.source === 'analysis' && !perf.analysis_id) { this.message('Choose an analysis.', 'warning'); return; }
        const btn = this.root.find('#vs_compute').prop('disabled', true);
        this.root.find('#vs_compute_state').html('<span class="glyphicon glyphicon-refresh vs-spin"></span> Computing\u2026');
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

    step_traits(p) {
        const s = this.sheet;
        const traits = (this.acc.traits || []).filter(t => t.numeric);
        const disease = traits.filter(t => t.kind === 'disease');
        const other = traits.filter(t => t.kind !== 'disease');
        const chosen = s.ratings.traits.map(t => t.trait_id);
        const opt = t => `<option value="${t.trait_id}" ${chosen.indexOf(t.trait_id) >= 0 ? 'disabled' : ''}>${esc(t.name)} \u2014 ${plural(t.trials, 'trial')}</option>`;
        p.html(`
          <h3>4. Disease reactions, characteristics and selling points</h3>
          <h4 class="vs-h4">Disease and stress reactions</h4>
          <p class="text-muted">Pick the rating traits. Breedbase computes the variety's mean score (and the checks' in the same trials) and suggests a reaction class from the trait scale; you have the final word.</p>
          <div class="input-group input-group-sm"><select class="form-control" id="vs_rating_add"><option value="">Add a trait\u2026</option>
            ${disease.length ? `<optgroup label="Disease / stress">${disease.map(opt).join('')}</optgroup>` : ''}<optgroup label="Other traits">${other.map(opt).join('')}</optgroup></select>
            <span class="input-group-btn"><button class="btn btn-default" id="vs_rating_compute"><span class="glyphicon glyphicon-refresh"></span> Update scores</button></span></div>
          <div id="vs_ratings"></div>
          <div class="form-group"><label>Reaction to diseases (text)</label> <button class="btn btn-xs btn-link vs-auto" data-k="disease"><span class="glyphicon glyphicon-flash"></span> Write it from the ratings</button>
            <textarea class="form-control vs-bind-text" data-k="disease" rows="3" placeholder="e.g. Resistant to potato virus Y, late blight race US-23 and golden nematode race Ro1. Moderately susceptible to common scab.">${esc(s.text.disease)}</textarea></div>

          <h4 class="vs-h4">Characteristics</h4>
          <p class="text-muted">Short facts shown as a table: maturity, plant habit, flower color, seed size\u2026 Pull a value from the trial data or type it.</p>
          <div id="vs_chars"></div>
          <div class="btn-group btn-group-sm">
            <button class="btn btn-default" id="vs_char_add"><span class="glyphicon glyphicon-plus"></span> Add row</button>
            <button class="btn btn-default dropdown-toggle" data-toggle="dropdown">Add from a trait <span class="caret"></span></button>
            <ul class="dropdown-menu vs-char-traits" style="max-height:300px;overflow:auto">${traits.map(t => `<li><a href="#" data-id="${t.trait_id}">${esc(t.label)} <small class="text-muted">${esc(t.name)}</small></a></li>`).join('')}</ul>
          </div>

          <h4 class="vs-h4">Selling points</h4>
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
          <h3>5. Photos</h3>
          <p class="text-muted">Pick the photos for the sheet (6 works well: plant, leaf, flower, fruit or tuber, cross-section, field). They come from the accession and from its plots and plants.
            <a href="/image/add?type_id=${a.stock_id}&action=new&type=stock&refering_page=${encodeURIComponent('/stock/' + a.stock_id + '/view')}" target="_blank">Upload new photos</a> to the accession, then <a href="#" id="vs_reload_images">reload</a>.</p>
          <h4 class="vs-h4">On the sheet <small>${s.images.length} selected</small></h4>
          <div id="vs_selected_photos"></div>
          <div class="form-inline vs-pad"><label>Columns&nbsp;</label><select class="form-control input-sm vs-bind-opt" data-k="photo_columns">${[2, 3, 4].map(n => `<option ${s.options.photo_columns == n ? 'selected' : ''} value="${n}">${n}</option>`).join('')}</select></div>
          <h4 class="vs-h4">Available <small>
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
        if (!s.commercial_name) missing.push('commercial name (step 2)');
        if (!s.performance.results) missing.push('performance numbers (step 3)');
        if (!s.images.length) missing.push('photos (step 5)');
        const chk = (k, label) => `<label class="checkbox-inline"><input type="checkbox" class="vs-bind-opt" data-k="${k}" ${o[k] !== false ? 'checked' : ''}> ${label}</label>`;
        p.html(`
          <h3>6. Preview and publish</h3>
          ${missing.length ? `<div class="alert alert-warning">Still missing: ${missing.join(', ')}.</div>` : ''}
          <div class="row">
            <div class="col-md-8">
              <div class="form-group"><label>Show</label><div>${chk('show_testing', 'testing summary')} ${chk('show_pct_chart', '% of check chart')} ${chk('show_year_chart', 'by-year chart')} ${chk('show_map', 'map of test locations')} ${chk('show_stats', 'significance stars')}</div></div>
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
            ${this.acc.can_edit ? `<button class="btn btn-default" id="vs_save_draft2"><span class="glyphicon glyphicon-floppy-disk"></span> Save draft</button>
            <button class="btn btn-success" id="vs_publish"><span class="glyphicon glyphicon-globe"></span> ${this.status === 'published' ? 'Update published sheet' : 'Publish'}</button>` : ''}
            <button class="btn btn-default" id="vs_print"><span class="glyphicon glyphicon-print"></span> Print / save as PDF</button>
            ${this.sheetId ? `<a class="btn btn-link" href="/variety_sheet/${this.sheetId}" target="_blank">Open sheet page</a>` : ''}
            <span class="text-muted vs-pub-state">${this.status === 'published' ? 'Published: anyone with the link can see it.' : 'Drafts are visible to you and curators only.'}</span>
          </div>
          <div class="vs-full-preview"></div>`);
        this.bindCommon(p);
        p.on('click', '.vs-accent', e => { e.preventDefault(); o.accent = $(e.currentTarget).data('c'); p.find('.vs-accent').removeClass('on'); $(e.currentTarget).addClass('on'); p.find('input[type=color]').val(o.accent); this.markDirty(); });
        p.on('click', '#vs_save_draft2', () => this.save('draft'));
        p.on('click', '#vs_publish', () => this.save('published'));
        p.on('click', '#vs_print', () => { this.preview(); setTimeout(() => window.print(), 400); });
    }

    async save(status) {
        const s = this.sheet;
        if (!s) return;
        if (!(s.commercial_name || '').trim()) { this.message('Give the variety a commercial name first (step 2).', 'warning'); this.go(1); return; }
        if (status === 'published' && this.status !== 'published' && !confirm('Publish this sheet? Anyone with the link will be able to see it.')) return;
        const opts = (this.nameCheck && this.nameCheck.conflicts.length) || !this.acc.can_save_names ? {} : this.nameOptions;
        const btns = this.root.find('.vs-save-draft, #vs_save_draft2, #vs_publish').prop('disabled', true);
        try {
            const r = await ajax('/ajax/variety_sheet/save', { method: 'POST', json: { sheet_id: this.sheetId, stock_id: s.stock_id, status, sheet: s, name_options: opts } });
            this.sheetId = r.sheet_id;
            this.status = r.status;
            this.dirty = false;
            history.replaceState(null, '', '/tools/variety_sheet?sheet_id=' + r.sheet_id);
            this.root.find('.vs-save-state').text(`Saved ${new Date().toLocaleTimeString()} \u00b7 sheet #${r.sheet_id} (${r.status})`);
            const msgs = (r.messages || []).map(esc);
            if (r.status === 'published') msgs.unshift(`Published. Share this link: <a href="${r.url}" target="_blank">${esc(location.origin + r.url)}</a>`);
            this.message(msgs.join('<br>') || 'Saved.', 'success');
            if ((r.messages || []).length) { this.acc.released_variety_name.push(s.commercial_name); this.nameCheck = null; }
            if (STEPS[this.step].key === 'publish') this.go(this.step);
        } catch (err) { this.message(esc(err.message), 'danger'); }
        btns.prop('disabled', false);
    }
}

function newSheetSkeleton() {
    return {
        version: VERSION, performance: { source: 'trials', checks: [], traits: [], results: null }, ratings: { traits: [], results: null },
        characteristics: [], images: [], evidence: {},
        text: { pedigree: '', market: '', production: '', disease: '', recommendations: '', acknowledgements: '', availability: '', contact: '' },
        options: { show_map: true, show_pct_chart: true, show_year_chart: true, show_stats: true, show_testing: true, accent: ACCENTS[0], photo_columns: 3 },
    };
}

/* -------------------------------------------------------------- entry points */

// photos whose file is missing on the server: hidden on the sheet, flagged in the editor
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

export function initEditor(root, opts) {
    guardImages();
    const ed = new Editor(root, opts);
    ed.start();
    return ed;
}

export function initView(root, row) {
    guardImages();
    const el = $(root);
    const sheet = Object.assign(newSheetSkeleton(), row.sheet);
    sheet.text = Object.assign(newSheetSkeleton().text, sheet.text || {});
    sheet.options = Object.assign(newSheetSkeleton().options, sheet.options || {});
    el.html(renderSheet(sheet, { url: location.origin + '/variety_sheet/' + row.variety_sheet_id }));
    drawMaps(el, sheet);
}

export function initList(root) {
    const el = $(root);
    ajax('/ajax/variety_sheet/list').then(r => {
        const pub = r.sheets.filter(s => s.status === 'published');
        const drafts = r.sheets.filter(s => s.status !== 'published');
        const card = s => `<a class="vs-card" href="/variety_sheet/${s.variety_sheet_id}"><b>${esc(s.commercial_name)}</b><span>${esc(s.accession_name)}</span><small>${esc(s.owner || '')} \u00b7 ${esc(s.modified_date)}</small></a>`;
        el.html((pub.length ? `<div class="vs-cards">${pub.map(card).join('')}</div>` : '<p class="text-muted">No published variety sheets yet.</p>') +
            (drafts.length ? `<h4 class="vs-h4">Drafts</h4><div class="vs-cards">${drafts.map(card).join('')}</div>` : ''));
    }).catch(err => el.html(`<p class="text-danger">${esc(err.message)}</p>`));
}

// exported for tests
export const _test = { renderSheet, autoPedigree, autoTesting, autoProduction, autoDisease, suggestRating, newSheet, esc, rich, num };
