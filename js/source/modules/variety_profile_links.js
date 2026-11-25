/*
 * Links from the decision meeting (decisions, variety vote) to the commercial
 * variety profiles (Variety Release Profiles, /tools/variety_sheet).
 *
 * The profiles of the database are read once per page from
 * /ajax/variety_sheet/list (published ones, plus the user's own drafts; all for
 * curators). Where that tool is not installed the request fails and no link is
 * shown, so the meeting works the same without it.
 *
 *   profilesReady()             promise of { available, byStock: {stock_id: [sheet, ...]} }
 *   profileLink(stock_id, opts) HTML (empty when nothing to show); opts.canCreate:
 *                               offer "New profile" when the accession has none (curators);
 *                               opts.placeholder: where the tool is not installed, a greyed-out
 *                               "Variety profile (not installed)" in its place (curators;
 *                               opts.placeholderAll: everyone, e.g. the report)
 *
 * Author: Chris Simoes
 */

let ready = null;
let data = { available: false, byStock: {} };
let checked = false;   // the answer of the server is known (available or not)

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function profilesReady() {
    if (ready) return ready;
    ready = new Promise(resolve => {
        const $ = window.jQuery;
        if (!$) { resolve(data); return; }
        $.ajax({ url: '/ajax/variety_sheet/list', dataType: 'json', cache: false })
            .done(r => {
                if (!r || !Array.isArray(r.sheets)) { checked = true; resolve(data); return; }
                const byStock = {};
                r.sheets.forEach(s => { if (s.stock_id) (byStock[s.stock_id] = byStock[s.stock_id] || []).push(s); });
                // published first, then the most recent
                Object.keys(byStock).forEach(k => byStock[k].sort((a, b) => (a.status === 'published' ? 0 : 1) - (b.status === 'published' ? 0 : 1) ||
                    String(b.modified_date || '').localeCompare(String(a.modified_date || ''))));
                data = { available: true, byStock };
                checked = true;
                resolve(data);
            })
            .fail(() => { checked = true; resolve(data); });
    });
    return ready;
}

export function profilesAvailable() { return data.available; }

export function profileLink(stockId, opts) {
    const o = opts || {};
    if (!stockId) return '';
    if (!data.available) {
        // the Variety Release Profiles tool is not on this site: show where its link will be
        return checked && o.placeholder && (o.canCreate || o.placeholderAll) ? '<span class="vpl-chip vpl-off" title="Variety Release Profiles are not installed on this site: the link to start the commercial profile of this accession will be here">' +
            '<span class="glyphicon glyphicon-plus"></span> Variety profile <i>(not installed)</i></span>' : '';
    }
    const list = data.byStock[stockId] || [];
    if (list.length) {
        const s = list[0];
        const name = s.commercial_name || s.accession_name || '';
        const draft = s.status !== 'published';
        return '<a class="vpl-chip' + (draft ? ' vpl-draft' : '') + '" href="/variety_sheet/' + esc(s.variety_sheet_id) + '" target="_blank" title="' +
            esc('Variety profile' + (name ? ': ' + name : '') + (draft ? ' (draft, not published)' : '') + (list.length > 1 ? ' - ' + list.length + ' profiles' : '')) + '">' +
            '<span class="glyphicon glyphicon-tag"></span> ' + esc(name || 'Profile') + (draft ? ' <i>draft</i>' : '') + '</a>';
    }
    if (!o.canCreate) return '';
    return '<a class="vpl-chip vpl-new" href="/tools/variety_sheet?stock_id=' + esc(stockId) + '" target="_blank" title="Start the commercial variety profile of this accession">' +
        '<span class="glyphicon glyphicon-plus"></span> Variety profile</a>';
}

// styles, once
if (typeof document !== 'undefined' && !document.getElementById('vpl_style')) {
    const st = document.createElement('style');
    st.id = 'vpl_style';
    st.textContent = '.vpl-chip { display:inline-flex; align-items:center; gap:3px; margin-left:6px; padding:0 7px; border-radius:10px; font-size:11px; line-height:18px; white-space:nowrap;' +
        ' background:#eef6f1; color:#1b5e37 !important; border:1px solid #cfe5d7; text-decoration:none !important; vertical-align:middle }' +
        '.vpl-chip:hover { background:#dcefe3 } .vpl-chip .glyphicon { font-size:10px; top:0 }' +
        '.vpl-draft { background:#f6f7f9; color:#4b5563 !important; border-color:#e5e7eb } .vpl-draft i { color:#9ca3af }' +
        '.vpl-new { background:#fff; color:#2b7a4b !important; border:1px dashed #9cc9ad } .vpl-new:hover { background:#f1f8f3 }' +
        '.vpl-off { background:#f6f7f9; color:#9ca3af !important; border:1px dashed #d1d5db; cursor:not-allowed } .vpl-off i { font-style:normal; font-size:10px }';
    document.head.appendChild(st);
}
