/*
 * Decision Meeting (/breeders/meeting)
 *
 * One page per meeting: pick a meeting on the left, then
 *   Evidence   the analyses the meeting decides on: Analysis Pipeline runs
 *              (suggested) or stored analyses (/analyses). Their accessions
 *              are the accessions of the meeting.
 *   Decisions  one row per accession and breeding program of the meeting:
 *              current stage, evidence (index rank, trait values) and the
 *              decision (drop / hold / advance / jump) with its new stage.
 *              Decisions are kept as a draft until they are saved for good.
 *   Report     summary, meeting report and history of the evidence.
 *   Under the tabs, always open: variety votes of farmers and field workers
 *   (decision_vote.js).
 *
 * Endpoints: /ajax/decisionmeeting/* (meetings, decisions, stages, save,
 * Excel template) and /ajax/decision_evidence/* (sources, evidence, drafts).
 * The selected meeting is announced with the jQuery event 'dm:meeting' and
 * window.getSelectedDecisionMeeting() (used by the vote section).
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

import '../modules/decision_meeting_create.js';

let $;
const API = '/ajax/decisionmeeting';
const EV = '/ajax/decision_evidence';
const DECISIONS = [
    { v: 'drop', label: 'Drop', icon: 'remove' },
    { v: 'hold', label: 'Hold', icon: 'pause' },
    { v: 'advance', label: 'Advance', icon: 'arrow-right' },
    { v: 'jump', label: 'Jump', icon: 'forward' },
];
const MAX_TRAIT_COLS = 6;

const S = {
    meetings: [], filter: 'open', search: '',
    id: null, src: null, tab: 'evidence', seq: 0,
    rows: [], rowsLoaded: false, ev: {}, evKey: '', viewKey: '',
    dfilter: 'all', dsearch: '', dprogram: '', sort: 'rank', page: 50, checked: {},
    pending: {}, draftTimer: null, available: null, addTab: 'runs',
};

// ---------------------------------------------------------------- helpers
function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function fmt(v) {
    if (v === null || v === undefined || v === '' || isNaN(Number(v))) return '';
    const x = Number(v), a = Math.abs(x);
    return a >= 1000 ? x.toFixed(0) : a >= 100 ? x.toFixed(1) : a >= 1 ? x.toFixed(2) : x.toPrecision(3);
}
function call(type, url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, type: type, data: data, dataType: 'json', cache: false })
            .done(r => (r && r.error ? reject(new Error(r.error)) : resolve(r)))
            .fail(x => {
                const j = x.responseJSON || {};
                reject(new Error(j.message || j.error || ('Server error ' + x.status)));
            });
    });
}
function alertHtml(type, msg) { return '<div class="alert alert-' + type + ' dm-alert">' + msg + '</div>'; }
function rowKey(r) { return r.accession + '\t' + r.breeding_program; }
function trimName(t) { return String(t || '').replace(/\|.*$/, ''); }
function kindLabel(s) {
    return s.source === 'run' ? '<span class="dm-kind dm-kind-run">Pipeline run</span>'
        : s.kind === 'pipeline' ? '<span class="dm-kind dm-kind-pipe">Pipeline analysis</span>'
            : '<span class="dm-kind dm-kind-an">Stored analysis</span>';
}
function decisionLabel(v) { const d = DECISIONS.find(x => x.v === v); return d ? d.label : ''; }
function meetingYear() {
    const m = String((S.src && S.src.meeting.date) || '').match(/^(\d{4})/);
    return m ? m[1] : '';
}
function editable() { return S.src && S.src.can_decide && !S.src.meeting.saved; }

// ---------------------------------------------------------------- meeting list
function loadMeetings() {
    return call('GET', API + '/meetings').then(r => {
        S.meetings = (r.rows || []).map(m => {
            const d = m.meeting_data || {};
            return {
                id: String(m.project_id), name: m.meeting_name || m.project_name, date: m.meeting_date || '',
                programs: m.meeting_programs || '', location: m.meeting_location || '',
                saved: !!(m.meeting_saved === true || m.meeting_saved === 1 || m.meeting_saved === '1'),
                n_sources: Array.isArray(d.related_analyses) ? d.related_analyses.length : 0,
                saved_rows: Array.isArray(d.accessions) ? d.accessions : [],
            };
        }).sort((a, b) => (a.saved - b.saved) || b.date.localeCompare(a.date));
        renderMeetings();
    }).catch(e => $('#dm_meetings').html(alertHtml('danger', esc(e.message))));
}

function renderMeetings() {
    const q = S.search.toLowerCase();
    const list = S.meetings.filter(m => (S.filter === 'all' || (S.filter === 'open') !== m.saved) &&
        (!q || (m.name + ' ' + m.programs + ' ' + m.location + ' ' + m.date).toLowerCase().indexOf(q) >= 0));
    const n = { open: S.meetings.filter(m => !m.saved).length, saved: S.meetings.filter(m => m.saved).length };
    $('.dm-seg[data-filter]').each(function () {
        const f = $(this).data('filter');
        $(this).toggleClass('on', f === S.filter).find('.dm-count').text(f === 'all' ? S.meetings.length : n[f]);
    });
    $('#dm_meetings').html(list.length ? list.map(m =>
        '<a href="#" class="dm-mitem' + (m.id === S.id ? ' on' : '') + '" data-id="' + esc(m.id) + '">' +
        '<span class="dm-mitem-top"><b>' + esc(m.name) + '</b>' + (m.saved ? '<span class="dm-pill dm-pill-saved">saved</span>' : '<span class="dm-pill dm-pill-open">open</span>') + '</span>' +
        '<span class="dm-mitem-meta">' + esc(m.date) + (m.programs ? ' &middot; ' + esc(m.programs) : '') + '</span>' +
        '<span class="dm-mitem-meta">' + (m.n_sources ? m.n_sources + ' analys' + (m.n_sources === 1 ? 'is' : 'es') : 'no analysis yet') + (m.location ? ' &middot; ' + esc(m.location) : '') + '</span>' +
        '</a>').join('')
        : '<div class="dm-empty-small">' + (S.meetings.length ? 'No meeting matches.' : 'No meeting yet. Create the first one.') + '</div>');
}

// ---------------------------------------------------------------- open a meeting
function openMeeting(id, tab) {
    S.id = id ? String(id) : null;
    S.src = null; S.rows = []; S.rowsLoaded = false; S.ev = {}; S.evKey = ''; S.viewKey = ''; S.checked = {}; S.pending = {};
    if (tab) S.tab = tab;
    renderMeetings();
    updateUrl();
    if (!S.id) {
        $('#dm_workspace').hide();
        $('#dm_empty').show();
        announce();
        return Promise.resolve();
    }
    $('#dm_empty').hide();
    $('#dm_workspace').show();
    $('#dm_head').html('<div class="dm-loading"><span class="glyphicon glyphicon-refresh dm-spin"></span> Loading the meeting...</div>');
    $('#dm_stats').empty();
    return loadSources().then(() => { announce(); showTab(S.tab); });
}

function announce() {
    $(document).trigger('dm:meeting', [S.id && S.src ? selected() : null]);
}
function selected() {
    if (!S.id || !S.src) return null;
    return { meeting_id: S.id, meeting_name: S.src.meeting.name, meeting_date: S.src.meeting.date, saved: S.src.meeting.saved };
}

function updateUrl() {
    if (!window.history || !window.history.replaceState) return;
    const u = new URL(window.location.href);
    if (S.id) { u.searchParams.set('meeting_id', S.id); u.searchParams.set('tab', S.tab); } else { u.searchParams.delete('meeting_id'); u.searchParams.delete('tab'); }
    window.history.replaceState(null, '', u.toString());
}

function loadSources() {
    const seq = ++S.seq;
    return call('GET', EV + '/sources', { meeting_id: S.id }).then(r => {
        if (seq !== S.seq) return;
        S.src = r;
        const keys = (r.sources || []).filter(s => !s.error).map(s => s.key);
        if (keys.indexOf(S.evKey) < 0) S.evKey = (r.sources.find(s => s.n_selected && !s.error) || r.sources.find(s => !s.error) || {}).key || '';
        if (keys.indexOf(S.viewKey) < 0) S.viewKey = S.evKey;
        renderHead();
        renderEvidence();
        renderReport();
    }).catch(e => { if (seq === S.seq) $('#dm_head').html(alertHtml('danger', esc(e.message))); });
}

function renderHead() {
    const m = S.src.meeting;
    const att = (m.attendees || []).join(', ');
    $('#dm_head').html(
        '<div class="dm-head-main">' +
        '<div><h3>' + esc(m.name) + ' ' + (m.saved ? '<span class="dm-pill dm-pill-saved" title="Saved ' + esc(m.saved_at || '') + '"><span class="glyphicon glyphicon-lock"></span> decisions saved</span>' : '<span class="dm-pill dm-pill-open">open</span>') + '</h3>' +
        '<div class="dm-head-meta">' +
        [m.date && '<span><span class="glyphicon glyphicon-calendar"></span> ' + esc(m.date) + '</span>',
            m.location && '<span><span class="glyphicon glyphicon-map-marker"></span> ' + esc(m.location) + '</span>',
            (m.programs || []).length && '<span><span class="glyphicon glyphicon-leaf"></span> ' + esc(m.programs.join(', ')) + '</span>',
            att && '<span title="' + esc(att) + '"><span class="glyphicon glyphicon-user"></span> ' + (m.attendees.length > 3 ? esc(m.attendees.slice(0, 3).join(', ')) + ' +' + (m.attendees.length - 3) : esc(att)) + '</span>'].filter(Boolean).join('') +
        '</div></div>' +
        '<div class="dm-head-actions"><button class="btn btn-default btn-sm" id="dm_report_btn"><span class="glyphicon glyphicon-file"></span> Meeting report</button></div>' +
        '</div>');
    renderStats();
}

function decisionCounts() {
    const c = { total: 0, decided: 0, drop: 0, hold: 0, advance: 0, jump: 0 };
    S.rows.forEach(r => { c.total++; if (r.decision) { c.decided++; c[r.decision]++; } });
    return c;
}

function renderStats() {
    if (!S.src) return;
    const c = decisionCounts();
    const nAcc = (S.src.accessions || []).length;
    const stat = (v, l, cls) => '<div class="dm-stat' + (cls ? ' ' + cls : '') + '"><div class="v">' + v + '</div><div class="l">' + l + '</div></div>';
    $('#dm_stats').html(
        stat((S.src.sources || []).length, 'Analyses') +
        stat(nAcc, 'Accessions') +
        stat(S.rowsLoaded ? c.decided + '<small>/' + c.total + '</small>' : (S.src.n_drafts || 0) + '<small>' + (S.src.meeting.saved ? '' : ' draft') + '</small>', 'Decided') +
        stat(S.rowsLoaded ? c.advance + c.jump : '&ndash;', 'Advance / jump', 'dm-stat-adv') +
        stat(S.rowsLoaded ? c.hold : '&ndash;', 'Hold', 'dm-stat-hold') +
        stat(S.rowsLoaded ? c.drop : '&ndash;', 'Drop', 'dm-stat-drop'));
    $('#dm_tab_count_evidence').text((S.src.sources || []).length || '');
    $('#dm_tab_count_decide').text(S.rowsLoaded && c.total ? c.decided + '/' + c.total : '');
}

function showTab(tab) {
    S.tab = tab;
    updateUrl();
    $('.dm-tab').removeClass('on').filter('[data-tab="' + tab + '"]').addClass('on');
    $('.dm-pane').hide().filter('[data-pane="' + tab + '"]').show();
    if (tab === 'decide' && !S.rowsLoaded) loadRows();
    if (tab === 'evidence') renderEvidenceTable();
}

// ---------------------------------------------------------------- evidence
function getEvidence(key) {
    if (!key) return Promise.resolve(null);
    if (S.ev[key]) return Promise.resolve(S.ev[key]);
    return call('GET', EV + '/evidence', { meeting_id: S.id, key: key }).then(e => {
        e.byAcc = {};
        (e.rows || []).forEach(r => { e.byAcc[r.accession] = r; });
        S.ev[key] = e;
        return e;
    });
}

function renderEvidence() {
    const r = S.src;
    const list = r.sources || [];
    const closed = r.meeting.saved;
    let h = '';
    if (r.meeting.legacy_list && closed) {
        h += alertHtml('info', 'This meeting was decided on an accession list, before meetings used analyses. Its saved decisions are in the <b>Decisions</b> tab and in the meeting report.');
    }
    if (!list.length) {
        h += '<div class="dm-empty-card"><span class="glyphicon glyphicon-stats"></span><h4>Which analyses will this meeting decide on?</h4>' +
            '<p>Add one or more analyses: their accessions become the accessions of the meeting. ' +
            'Runs of the <b>Analysis Pipeline</b> are suggested: they bring genotype values, ranks and the selection index.</p>' +
            (r.can_link ? '<button class="btn btn-success dm-add-open"><span class="glyphicon glyphicon-plus"></span> Add analyses</button>' : '<p class="dm-muted">Only the meeting roles can add analyses.</p>') + '</div>';
    } else {
        h += '<div class="dm-sources">' + list.map(s =>
            '<div class="dm-source' + (s.key === S.viewKey ? ' on' : '') + (s.error ? ' err' : '') + '" data-key="' + esc(s.key) + '">' +
            '<div class="dm-source-top">' + kindLabel(s) + (s.after_save ? '<span class="dm-kind dm-kind-late" title="Added after the decisions were saved">added later</span>' : '') + '</div>' +
            '<div class="dm-source-name">' + esc(s.name) + '</div>' +
            (s.error ? '<div class="dm-source-meta text-danger">' + esc(s.error) + '</div>'
                : '<div class="dm-source-meta"><b>' + s.n_accessions + '</b> accessions' + (s.n_selected ? ' &middot; <b>' + s.n_selected + '</b> selected by the index' : '') + '</div>' +
                (s.traits && s.traits.length ? '<div class="dm-source-traits">' + s.traits.slice(0, 5).map(t => '<span class="dm-chip">' + esc(trimName(t)) + '</span>').join('') + (s.traits.length > 5 ? '<span class="dm-muted"> +' + (s.traits.length - 5) + '</span>' : '') + '</div>' : '')) +
            '<div class="dm-source-foot"><span class="dm-muted">' + (s.linked_by ? 'added by ' + esc(s.linked_by) + (s.linked_at ? ', ' + esc(s.linked_at) : '') : '') + '</span>' +
            '<span><a class="btn btn-link btn-xs" target="_blank" href="' + esc(s.link) + '" title="Open the results"><span class="glyphicon glyphicon-new-window"></span></a>' +
            (r.can_link && !closed ? '<button class="btn btn-link btn-xs dm-unlink" data-key="' + esc(s.key) + '" title="Remove from this meeting"><span class="glyphicon glyphicon-trash"></span></button>'
                : closed ? '<span class="dm-muted" title="The decisions are saved: this evidence is a permanent record"><span class="glyphicon glyphicon-lock"></span></span>' : '') +
            '</span></div></div>').join('') +
            (r.can_link ? '<button class="dm-source dm-source-add dm-add-open"><span class="glyphicon glyphicon-plus"></span><br/>Add analyses</button>' : '') + '</div>';
        if (list.some(s => s.source === 'run')) {
            h += '<p class="dm-muted dm-small"><span class="glyphicon glyphicon-info-sign"></span> Pipeline runs are temporary: a copy of their results is kept with the meeting. Store a run as an analysis to keep its full results page.</p>';
        }
    }
    $('#dm_sources').html(h);
    $('#dm_evidence_view').toggle(list.length > 0);
}

function renderEvidenceTable() {
    if (!S.src || !(S.src.sources || []).length || !S.viewKey) { $('#dm_ev_table, #dm_glance, #dm_sel_body').empty(); return; }
    const key = S.viewKey;
    const src = S.src.sources.find(s => s.key === key) || {};
    $('.dm-ev-title').html(esc(src.name || ''));
    $('#dm_ev_pick').html((S.src.sources || []).filter(s => !s.error).map(s => '<button class="dm-seg' + (s.key === key ? ' on' : '') + '" data-view="' + esc(s.key) + '">' + esc(s.name) + '</button>').join(''));
    $('#dm_ev_table').html('<div class="dm-loading"><span class="glyphicon glyphicon-refresh dm-spin"></span> Reading the results...</div>');
    getEvidence(key).then(e => {
        if (S.viewKey !== key) return;
        if (SEL.key !== key) resetSelection(e, key);
        renderGlance(e);
        renderSelection(e);
    }).catch(err => { $('#dm_glance, #dm_sel_body').empty(); $('#dm_ev_table').html(alertHtml('warning', esc(err.message))); });
}

// ---------------------------------------------------------------- traits at a glance and selection
// as on the results page of the Analysis Pipeline (script_factory_results.js)
const SEL = { key: null, rankBy: 'index', dir: 'increase', pct: 10 };

function num(x) { return x === null || x === undefined || x === '' || !isFinite(Number(x)) ? null : Number(x); }
function mean(a) { const v = a.filter(x => x !== null && isFinite(x)); return v.length ? v.reduce((s, x) => s + x, 0) / v.length : null; }
function traitOf(e, t) { return (e.traits || []).find(x => x.trait === t) || {}; }
function tLabel(t) { return t.label || trimName(t.trait); }
function valueOf(r, t) { const v = (r.values || {})[t]; return v ? num(v.v) : null; }
function h2Badge(v) {
    const x = num(v);
    if (x === null) return '<span class="dm-muted">&ndash;</span>';
    return '<span class="dm-h2" style="background:' + (x >= 0.6 ? '#2b7a4b' : x >= 0.3 ? '#d97706' : '#dc2626') + '">' + x.toFixed(2) + '</span>';
}
function accBadge(v) {
    const a = num(v);
    if (a === null) return '<span class="dm-muted">&ndash;</span>';
    return '<b style="color:' + (a >= 0.8 ? '#2b7a4b' : a >= 0.6 ? '#b7791f' : '#9b2c2c') + '">' + a.toFixed(3) + '</b>';
}
function dash(v) { return v === null || v === undefined || v === '' ? '<span class="dm-muted">&ndash;</span>' : v; }

function resetSelection(e, key) {
    SEL.key = key;
    const first = (e.traits || [])[0] || {};
    SEL.rankBy = e.index ? 'index' : first.trait || '';
    SEL.dir = e.index ? 'increase' : (first.direction || 'increase');
    SEL.pct = Math.min(50, Math.max(1, Math.round(num(e.index && e.index.selection_pct) || 10)));
}

function renderGlance(e) {
    const random = e.genotype_effect !== 'fixed';
    const twoStage = e.strategy === 'two_stage';
    const verdict = (t) => {
        if (t.message && t.message !== 'OK') return '<small class="text-danger">' + esc(t.message) + '</small>';
        const h = num(t.h2);
        if (h === null) return '<span class="dm-muted">' + (e.genotype_effect === 'fixed' ? 'no heritability (genotype fixed)' : 'no model summary') + '</span>';
        return h >= 0.6 ? '<span style="color:#2b7a4b">reliable for selection</span>' : h >= 0.3 ? '<span style="color:#b45309">moderate: weigh with care</span>' : '<span style="color:#dc2626">low: selection is risky</span>';
    };
    const rows = (e.traits || []).map(t => {
        const vals = (e.rows || []).map(r => valueOf(r, t.trait)).filter(v => v !== null);
        const m = num(t.mean) !== null ? num(t.mean) : mean(vals);
        return '<tr><td><b>' + esc(tLabel(t)) + '</b>' + (t.direction === 'decrease' ? ' <span class="dm-muted" title="lower is better">&darr;</span>' : '') +
            (t.in_index ? ' <span class="dm-chip" title="Index weight">index' + (num(t.weight) !== null ? ' &times;' + fmt(t.weight) : '') + '</span>' : '') + '</td>' +
            '<td>' + dash(fmt(m)) + '</td><td>' + (vals.length ? fmt(Math.min.apply(null, vals)) + ' &ndash; ' + fmt(Math.max.apply(null, vals)) : dash('')) + '</td>' +
            '<td>' + dash(fmt(t.var_g)) + '</td><td>' + dash(fmt(t.var_ge)) + '</td><td>' + h2Badge(t.h2) + '</td><td>' + accBadge(t.accuracy) + '</td>' +
            '<td>' + (num(t.pct_removed) === null ? dash('') : num(t.pct_removed).toFixed(1) + '%') + '</td><td>' + verdict(t) + '</td></tr>';
    }).join('');
    $('#dm_glance').html(rows ? '<div class="dm-table-wrap"><table class="table table-condensed dm-table"><thead><tr><th>Trait</th><th>Mean</th><th>' + esc(e.value_label || 'Value') + ' range</th>' +
        '<th>&sigma;&sup2;<sub>G</sub></th><th>' + (twoStage ? '&sigma;&sup2;<sub>GE+e</sub>' : '&sigma;&sup2;<sub>GE</sub>') + '</th><th>H&sup2;</th><th title="How closely the values follow the true genetic values (0 to 1)">Accuracy</th><th>Removed</th><th>Verdict</th></tr></thead><tbody>' +
        rows + '</tbody></table></div>' +
        (e.dashboard && /^\/analyses\//.test(e.dashboard) ? '<p class="dm-muted dm-small">This analysis was made with another tool: only its stored values are known (no heritability or accuracy).</p>'
            : random ? '' : '<p class="dm-muted dm-small">Genotype as a fixed effect (BLUEs): no genetic variance, so no accuracy.</p>')
        : '<p class="dm-muted">No trait.</p>');
}

// accessions in ranking order for the current choice, with score and selected flag
function selRows(e) {
    let rows;
    if (SEL.rankBy === 'index' && e.index) {
        rows = (e.rows || []).map(r => ({ r: r, score: num(r.index), key: num(r.index) }));
    } else {
        const sign = SEL.dir === 'decrease' ? -1 : 1;
        rows = (e.rows || []).map(r => { const v = valueOf(r, SEL.rankBy); return { r: r, score: v, key: v === null ? null : sign * v }; });
    }
    rows = rows.filter(x => x.key !== null).sort((a, b) => b.key - a.key);
    const n = Math.max(1, Math.round(rows.length * SEL.pct / 100));
    rows.forEach((x, i) => { x.rank = i + 1; x.selected = i < n; });
    return rows;
}

function renderSelection(e) {
    const traits = e.traits || [];
    const opts = (e.index ? '<option value="index"' + (SEL.rankBy === 'index' ? ' selected' : '') + '>Selection index (' + (e.index.method === 'rank_sum' ? 'rank sum' : 'Z-score') + ')</option>' : '') +
        traits.map(t => '<option value="' + esc(t.trait) + '"' + (SEL.rankBy === t.trait ? ' selected' : '') + '>' + esc(tLabel(t)) + '</option>').join('');
    $('#dm_sel_by').html(opts);
    $('#dm_sel_dir').toggle(SEL.rankBy !== 'index').find('button').each(function () { $(this).toggleClass('active', $(this).data('dir') === SEL.dir); });
    $('#dm_sel_pct').val(SEL.pct);
    const rows = selRows(e);
    const sel = rows.filter(x => x.selected);
    $('#dm_sel_pct_label').text(SEL.pct);
    $('#dm_sel_n').text(sel.length + ' of ' + rows.length);
    const scoreLabel = SEL.rankBy === 'index' ? 'Index' : tLabel(traitOf(e, SEL.rankBy)) + ' (' + (e.value_label || 'value') + ')';

    // accuracy of what the ranking uses
    let acc = null, what = '';
    if (SEL.rankBy === 'index' && e.index) {
        what = 'the selection index';
        const ts = traits.filter(t => t.in_index && num(t.accuracy) !== null);
        if (num(e.index.accuracy) !== null) acc = num(e.index.accuracy);
        else if (ts.length) {
            const w = ts.map(t => Math.abs(num(t.weight) || 0)), ws = w.reduce((a, b) => a + b, 0);
            acc = ws > 0 ? ts.reduce((a, t, i) => a + w[i] * num(t.accuracy), 0) / ws : mean(ts.map(t => num(t.accuracy)));
        }
    } else {
        what = tLabel(traitOf(e, SEL.rankBy));
        acc = num(traitOf(e, SEL.rankBy).accuracy);
    }
    const word = acc === null ? '' : acc >= 0.8 ? 'high' : acc >= 0.6 ? 'moderate' : 'low';
    $('#dm_sel_acc').attr('class', 'dm-acc-box' + (word ? ' dm-acc-' + word : ''))
        .attr('title', acc === null ? 'No accuracy: it needs the genetic variance (genotype as a random effect).' : 'Selection accuracy of ' + what + ': how closely the ranking follows the true genetic values; 1 would be perfect.')
        .html('<div class="v">' + (acc === null ? '<span class="dm-muted">n/a</span>' : acc.toFixed(3) + ' <small>' + word + '</small>') + '</div><div class="l">Selection accuracy</div>');

    // expected response to selection
    const random = e.genotype_effect !== 'fixed';
    const gains = traits.map(t => {
        const all = rows.map(x => valueOf(x.r, t.trait)).filter(v => v !== null);
        const s = sel.map(x => valueOf(x.r, t.trait)).filter(v => v !== null);
        const pm = mean(all), sm = mean(s);
        const d = pm !== null && sm !== null ? sm - pm : null;
        const h2 = num(t.h2);
        const gain = d === null ? null : random && h2 !== null ? d : h2 !== null ? h2 * d : null;
        const good = d === null ? null : (t.direction === 'decrease' ? d <= 0 : d >= 0);
        const used = SEL.rankBy === 'index' ? !!t.in_index : SEL.rankBy === t.trait;
        const col = v => v === null ? dash('') : '<b style="color:' + (good ? '#2b7a4b' : '#dc2626') + '">' + v + '</b>';
        return '<tr><td>' + esc(tLabel(t)) + (used ? ' <span class="label label-success">ranked on</span>' : '') + (t.direction === 'decrease' ? ' <span class="dm-muted">&darr;</span>' : '') + '</td>' +
            '<td>' + dash(fmt(pm)) + '</td><td>' + dash(fmt(sm)) + '</td><td>' + dash(fmt(d)) + '</td>' +
            '<td>' + col(d !== null && pm ? (d >= 0 ? '+' : '') + (100 * d / Math.abs(pm)).toFixed(1) + '%' : null) + '</td>' +
            '<td>' + h2Badge(t.h2) + '</td><td>' + col(gain === null ? null : (gain >= 0 ? '+' : '') + fmt(gain)) + '</td><td>' + accBadge(t.accuracy) + '</td></tr>';
    }).join('');
    $('#dm_sel_gains').html('<div class="dm-table-wrap"><table class="table table-condensed dm-table"><thead><tr><th>Trait</th><th>Population mean</th><th>Selected mean</th><th>Selection differential</th><th>S %</th><th>H&sup2;</th><th>Expected gain</th><th>Accuracy</th></tr></thead><tbody>' +
        gains + '</tbody></table></div><p class="dm-muted dm-small">' + (random ? 'Values are BLUPs (already shrunk by heritability): the expected gain equals the selection differential.' : 'Expected gain = H&sup2; &times; selection differential.') +
        ' Red figures move the trait in the unwanted direction.</p>');

    // top accessions
    const top = rows.slice(0, Math.min(40, Math.max(15, sel.length + 5)));
    const sc = top.map(x => x.score);
    const lo = Math.min(0, Math.min.apply(null, sc)), hi = Math.max(0, Math.max.apply(null, sc));
    const pos = v => (hi > lo ? 100 * (v - lo) / (hi - lo) : 50);
    $('#dm_sel_chart').html(top.length ? top.map(x => {
        const a = pos(Math.min(0, x.score)), b = pos(Math.max(0, x.score));
        return '<div class="dm-hbar' + (x.selected ? ' sel' : '') + '" title="' + esc(x.rank + '. ' + x.r.accession + ' - ' + scoreLabel + ': ' + fmt(x.score)) + '">' +
            '<span class="dm-hbar-l">' + x.rank + '. ' + esc(x.r.accession) + '</span><span class="dm-hbar-t"><span class="dm-hbar-zero" style="left:' + pos(0) + '%"></span>' +
            '<span class="dm-hbar-b" style="left:' + a + '%;width:' + Math.max(0.5, b - a) + '%"></span></span><span class="dm-hbar-v">' + fmt(x.score) + '</span></div>';
    }).join('') : '<p class="dm-muted">No value to rank on.</p>');

    // ranking with every value
    const q = ($('#dm_ev_search').val() || '').toLowerCase();
    const onlySel = $('#dm_ev_selected').is(':checked');
    const shown = rows.filter(x => (!onlySel || x.selected) && (!q || x.r.accession.toLowerCase().indexOf(q) >= 0));
    const tcols = traits.filter(t => SEL.rankBy !== t.trait);
    $('#dm_ev_table').html('<div class="dm-muted dm-small" style="margin-bottom:4px">' + shown.length + ' accession(s)' + (shown.length > 500 ? ', first 500 shown' : '') +
        (e.index ? ' &middot; the analysis itself selected ' + (e.rows || []).filter(r => r.selected).length + ' with its index (top ' + esc(e.index.selection_pct || '') + '%)' : '') + '</div>' +
        '<div class="dm-table-wrap"><table class="table table-condensed dm-table"><thead><tr><th>#</th><th>Accession</th><th>' + esc(scoreLabel) + '</th>' +
        tcols.map(t => '<th title="' + esc(t.trait) + '">' + esc(tLabel(t)) + (t.direction === 'decrease' ? ' &darr;' : '') + '</th>').join('') + '<th></th></tr></thead><tbody>' +
        shown.slice(0, 500).map(x => '<tr' + (x.selected ? ' class="dm-sel-row"' : '') + '><td>' + x.rank + '</td><td>' + accLink(x.r.accession, x.r.stock_id) + '</td><td><b>' + fmt(x.score) + '</b></td>' +
            tcols.map(t => { const v = (x.r.values || {})[t.trait]; return '<td>' + (v ? fmt(v.v) + (v.rank ? ' <span class="dm-rank">#' + v.rank + '</span>' : '') : '') + '</td>'; }).join('') +
            '<td>' + (x.selected ? '<span class="dm-badge-sel">selected</span>' : '') + '</td></tr>').join('') + '</tbody></table></div>');
    $('#dm_sel_use').prop('disabled', !sel.length || !S.src.can_decide || S.src.meeting.saved)
        .html('<span class="glyphicon glyphicon-check"></span> Check these ' + sel.length + ' in Decisions');
}

// the accessions selected here become the checked rows of the Decisions tab
function useSelection() {
    const e = S.ev[S.viewKey];
    if (!e) return;
    const chosen = {};
    selRows(e).filter(x => x.selected).forEach(x => { chosen[x.r.accession] = true; });
    const go = () => {
        S.checked = {};
        S.rows.forEach(r => { if (chosen[r.accession]) S.checked[rowKey(r)] = true; });
        S.dfilter = 'all';
        if (S.evKey !== S.viewKey) { S.evKey = S.viewKey; $('#dm_dec_source').val(S.evKey); }
        renderRows();
        const n = Object.keys(S.checked).length;
        flash('info', '<b>' + n + ' row(s) checked</b> from the selection. Choose Drop, Hold, Advance or Jump in the bar above the table to decide them at once.');
    };
    showTab('decide');
    if (S.rowsLoaded) go(); else loadRows().then(go);
}

function accLink(name, id) {
    return id ? '<a href="/stock/' + esc(id) + '/view" target="_blank">' + esc(name) + '</a>' : esc(name);
}

function evidenceCsv() {
    const e = S.ev[S.viewKey];
    if (!e) return;
    const q = x => { const s = x === null || x === undefined ? '' : String(x); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const traits = e.traits || [];
    const lines = [['accession'].concat(e.index ? ['index', 'index_rank', 'selected'] : []).concat(traits.map(t => t.label || trimName(t.trait))).map(q).join(',')];
    (e.rows || []).forEach(r => lines.push([r.accession].concat(e.index ? [r.index, r.index_rank, r.selected ? 1 : 0] : [])
        .concat(traits.map(t => ((r.values || {})[t.trait] || {}).v)).map(q).join(',')));
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([lines.join('\n')], { type: 'text/csv' }));
    a.download = (S.src.meeting.name + ' - evidence.csv').replace(/[\\/:*?"<>|]/g, '_');
    a.click();
}

// add analyses dialog
function openAdd() {
    $('#dm_add_msg').empty();
    $('#dm_add_modal').modal('show');
    $('#dm_add_search').val('');
    if (S.available) { renderAdd(); return; }
    $('#dm_add_list').html('<div class="dm-loading"><span class="glyphicon glyphicon-refresh dm-spin"></span> Loading your runs and analyses...</div>');
    call('GET', EV + '/available').then(r => { S.available = r; renderAdd(); })
        .catch(e => $('#dm_add_list').html(alertHtml('danger', esc(e.message))));
}

function renderAdd() {
    const r = S.available || { runs: [], analyses: [] };
    const linked = {};
    (S.src.sources || []).forEach(s => { linked[s.key] = true; });
    $('.dm-add-tab').removeClass('on').filter('[data-add="' + S.addTab + '"]').addClass('on');
    $('#dm_add_n_runs').text(r.runs.length);
    $('#dm_add_n_an').text(r.analyses.length);
    const q = ($('#dm_add_search').val() || '').toLowerCase();
    const mine = $('#dm_add_mine').is(':checked');
    $('#dm_add_mine').closest('label').toggle(S.addTab === 'analyses');
    let items;
    if (S.addTab === 'runs') {
        items = r.runs.filter(x => !q || (x.name + ' ' + (x.dataset_name || '') + ' ' + x.created).toLowerCase().indexOf(q) >= 0).map(x => {
            const key = x.stored_key || x.key;
            const on = linked[key];
            return '<label class="dm-pick' + (on ? ' off' : '') + '"><input type="checkbox" value="' + esc(x.key) + '"' + (on ? ' disabled checked' : '') + ' />' +
                '<span class="dm-pick-main"><b>' + esc(x.name) + '</b><span class="dm-muted">' + esc((x.created || '').replace('T', ' ').slice(0, 16)) + (x.dataset_name ? ' &middot; dataset ' + esc(x.dataset_name) : '') + '</span></span>' +
                (x.stored_key ? '<span class="dm-kind dm-kind-pipe" title="This run is stored: the stored analysis is added">stored: ' + esc(x.stored_name || '') + '</span>' : '<span class="dm-kind dm-kind-run">not stored</span>') +
                (on ? '<span class="dm-muted dm-small">already in the meeting</span>' : '') + '</label>';
        });
        if (!r.runs.length) items = ['<div class="dm-empty-small">No Analysis Pipeline run with results yet. Runs are made in <a href="/tools/script_factory" target="_blank">Analyze &rsaquo; Analysis Pipeline</a> and listed on your personal page.</div>'];
    } else {
        items = r.analyses.filter(x => (!mine || x.is_owner) && (!q || (x.name + ' ' + (x.owner || '') + ' ' + x.created).toLowerCase().indexOf(q) >= 0)).map(x => {
            const on = linked[x.key];
            return '<label class="dm-pick' + (on ? ' off' : '') + '"><input type="checkbox" value="' + esc(x.key) + '"' + (on ? ' disabled checked' : '') + ' />' +
                '<span class="dm-pick-main"><b>' + esc(x.name) + '</b><span class="dm-muted">' + esc((x.created || '').slice(0, 16)) + (x.owner ? ' &middot; ' + esc(x.owner) : '') + (x.model_type ? ' &middot; ' + esc(x.model_type) : '') + '</span></span>' +
                (x.kind === 'pipeline' ? '<span class="dm-kind dm-kind-pipe">Pipeline</span>' : '<span class="dm-kind dm-kind-an">Other tool</span>') +
                (on ? '<span class="dm-muted dm-small">already in the meeting</span>' : '') + '</label>';
        });
        if (!r.analyses.length) items = ['<div class="dm-empty-small">No stored analysis. See <a href="/analyses" target="_blank">Manage &rsaquo; Analyses</a>.</div>'];
    }
    $('#dm_add_list').html(items.join('') || '<div class="dm-empty-small">Nothing matches.</div>');
    countAdd();
}

function countAdd() {
    const n = $('#dm_add_list input:checked:not(:disabled)').length;
    $('#dm_add_go').prop('disabled', !n).html('<span class="glyphicon glyphicon-plus"></span> Add ' + (n ? n + ' ' : '') + 'to the meeting');
}

function addChecked() {
    const keys = $('#dm_add_list input:checked:not(:disabled)').map(function () { return this.value; }).get();
    if (!keys.length) return;
    $('#dm_add_go').prop('disabled', true).html('<span class="glyphicon glyphicon-refresh dm-spin"></span> Reading the results...');
    call('POST', EV + '/link', { meeting_id: S.id, keys: keys.join(','), action: 'link' }).then(r => {
        $('#dm_add_modal').modal('hide');
        S.rowsLoaded = false;
        flash('success', (r.changed || 0) + ' analys' + (r.changed === 1 ? 'is' : 'es') + ' added.' + ((r.notes || []).length ? '<br/>' + r.notes.map(esc).join('<br/>') : ''));
        return refreshAfterEvidence();
    }).catch(e => { $('#dm_add_msg').html(alertHtml('danger', esc(e.message))); countAdd(); });
}

function unlink(key) {
    const s = (S.src.sources || []).find(x => x.key === key);
    if (!s || !window.confirm('Remove "' + s.name + '" from this meeting?\n\nIts accessions leave the meeting unless another analysis has them. The analysis itself is not changed.')) return;
    call('POST', EV + '/link', { meeting_id: S.id, keys: key, action: 'unlink' })
        .then(() => { delete S.ev[key]; S.rowsLoaded = false; return refreshAfterEvidence(); })
        .catch(e => flash('danger', esc(e.message)));
}

function refreshAfterEvidence() {
    return Promise.all([loadSources(), loadMeetings()]).then(() => {
        announce();
        if (S.tab === 'decide') loadRows(); else renderEvidenceTable();
    });
}

function flash(type, html) {
    const $f = $(alertHtml(type, html + ' <button type="button" class="close" aria-label="Close">&times;</button>'));
    $f.find('.close').on('click', () => $f.remove());
    $('#dm_flash').html($f);
    if (type === 'success') setTimeout(() => $f.fadeOut(400, () => $f.remove()), 6000);
}

// ---------------------------------------------------------------- decisions
function loadRows() {
    const id = S.id;
    $('#dm_dec_table').html('<div class="dm-loading"><span class="glyphicon glyphicon-refresh dm-spin"></span> Loading accessions, stages and decisions...</div>');
    const legacy = S.meetings.find(m => m.id === id);
    const fromSaved = () => (legacy && legacy.saved_rows || []).map(r => ({
        stock_id: r.stock_id, accession: r.accession, breeding_program: r.breeding_program, stage: r.previous_stage || '',
        decision: r.decision || '', new_stage: r.new_stage || '', notes: r.notes || '', save_comment: r.save_comment || '', female_parent: '', male_parent: '',
    }));
    const req = (S.src.sources || []).length
        ? call('GET', API + '/decisions', { meeting_id: id }).then(r => r.rows || [])
        : Promise.resolve(fromSaved());
    return Promise.all([req, getEvidence(S.evKey).catch(() => null)]).then(([rows]) => {
        if (S.id !== id) return;
        S.rows = rows.map(r => Object.assign({}, r, { decision: String(r.decision || '').toLowerCase(), allowed: null }));
        S.rowsLoaded = true;
        renderDecideToolbar();
        renderRows();
        renderStats();
        renderReport();
    }).catch(e => $('#dm_dec_table').html(alertHtml('danger', esc(e.message))));
}

function renderDecideToolbar() {
    const progs = [...new Set(S.rows.map(r => r.breeding_program).filter(Boolean))].sort();
    $('#dm_dec_program').html('<option value="">All programs</option>' + progs.map(p => '<option' + (p === S.dprogram ? ' selected' : '') + '>' + esc(p) + '</option>').join('')).toggle(progs.length > 1);
    const srcs = (S.src.sources || []).filter(s => !s.error);
    $('#dm_dec_source').html(srcs.map(s => '<option value="' + esc(s.key) + '"' + (s.key === S.evKey ? ' selected' : '') + '>' + esc(s.name) + '</option>').join('')).closest('.dm-field').toggle(srcs.length > 0);
    const ed = editable();
    $('#dm_bulk, #dm_save_btn, #dm_upload_btn').toggle(ed);
    $('#dm_readonly_note').html(S.src.meeting.saved
        ? '<span class="glyphicon glyphicon-lock"></span> The decisions of this meeting are saved' + (S.src.meeting.saved_at ? ' (' + esc(S.src.meeting.saved_at) + ')' : '') + '. They can no longer change.'
        : !S.src.can_decide ? '<span class="glyphicon glyphicon-eye-open"></span> You can see the decisions; only the decision roles can change them.' : '').toggle(!ed);
}

function filteredRows() {
    const e = S.ev[S.evKey];
    const q = S.dsearch.toLowerCase();
    const selIn = {};
    (S.src.accessions || []).forEach(a => { selIn[a.accession] = (a.selected_in || []).length; });
    let rows = S.rows.filter(r => (!S.dprogram || r.breeding_program === S.dprogram) &&
        (!q || (r.accession + ' ' + (r.stage || '') + ' ' + (r.female_parent || '') + ' ' + (r.male_parent || '')).toLowerCase().indexOf(q) >= 0) &&
        (S.dfilter === 'all' || (S.dfilter === 'selected' && selIn[r.accession]) || (S.dfilter === 'undecided' && !r.decision) || (S.dfilter === 'decided' && r.decision)));
    const rank = r => { const x = e && e.byAcc[r.accession]; return x && x.index_rank ? x.index_rank : 1e9; };
    const sorters = {
        rank: (a, b) => rank(a) - rank(b) || a.accession.localeCompare(b.accession),
        accession: (a, b) => a.accession.localeCompare(b.accession) || a.breeding_program.localeCompare(b.breeding_program),
        stage: (a, b) => String(a.stage).localeCompare(String(b.stage)) || a.accession.localeCompare(b.accession),
        decision: (a, b) => String(b.decision).localeCompare(String(a.decision)) || rank(a) - rank(b),
    };
    return rows.sort(sorters[S.sort] || sorters.rank);
}

function renderRows() {
    if (!S.rowsLoaded) return;
    const e = S.ev[S.evKey];
    const ed = editable();
    const selIn = {};
    (S.src.accessions || []).forEach(a => { selIn[a.accession] = a.selected_in || []; });
    const rows = filteredRows();
    const counts = { all: S.rows.length, selected: S.rows.filter(r => (selIn[r.accession] || []).length).length, undecided: S.rows.filter(r => !r.decision).length, decided: S.rows.filter(r => r.decision).length };
    $('.dm-seg[data-dfilter]').each(function () { const f = $(this).data('dfilter'); $(this).toggleClass('on', f === S.dfilter).find('.dm-count').text(counts[f]); });
    if (!S.rows.length) {
        $('#dm_dec_table').html('<div class="dm-empty-card"><span class="glyphicon glyphicon-list"></span><h4>No accession yet</h4><p>The accessions come from the analyses of the meeting.</p>' +
            '<button class="btn btn-default dm-goto" data-tab="evidence">Go to Evidence</button></div>');
        $('#dm_dec_foot').empty();
        return;
    }
    const traits = e ? (e.traits || []).slice(0, MAX_TRAIT_COLS) : [];
    const shown = S.page === 'all' ? rows : rows.slice(0, S.page);
    const sortIcon = k => S.sort === k ? ' <span class="glyphicon glyphicon-triangle-bottom dm-sort-on"></span>' : '';
    const head = '<tr>' + (ed ? '<th class="dm-cb"><input type="checkbox" id="dm_check_all" title="Check all shown" /></th>' : '') +
        '<th class="dm-sortable" data-sort="accession">Accession' + sortIcon('accession') + '</th>' +
        '<th>Program</th><th class="dm-sortable" data-sort="stage">Stage' + sortIcon('stage') + '</th>' +
        (e && e.index ? '<th class="dm-sortable" data-sort="rank" title="Selection index rank in ' + esc((S.src.sources.find(s => s.key === S.evKey) || {}).name || '') + '">Index' + sortIcon('rank') + '</th>' : '') +
        traits.map(t => '<th class="dm-trait-col" title="' + esc(t.trait) + '">' + esc(t.label || trimName(t.trait)) + '</th>').join('') +
        '<th class="dm-sortable" data-sort="decision">Decision' + sortIcon('decision') + '</th><th>New stage</th><th>Comment</th></tr>';
    const body = shown.map(r => {
        const k = rowKey(r);
        const x = e && e.byAcc[r.accession];
        const sel = selIn[r.accession] || [];
        const parents = r.female_parent || r.male_parent ? '<div class="dm-parents">' + esc(r.female_parent || '?') + ' &times; ' + esc(r.male_parent || '?') + '</div>' : '';
        return '<tr data-k="' + esc(k) + '" class="dm-row-' + (r.decision || 'none') + '">' +
            (ed ? '<td class="dm-cb"><input type="checkbox" class="dm-check" data-k="' + esc(k) + '"' + (S.checked[k] ? ' checked' : '') + ' /></td>' : '') +
            '<td class="dm-acc">' + accLink(r.accession, r.stock_id) + (sel.length ? ' <span class="dm-badge-sel" title="Selected by the index of ' + sel.length + ' analysis(es)">selected</span>' : '') +
            (r.notes ? ' <span class="glyphicon glyphicon-comment dm-muted" title="' + esc(r.notes) + '"></span>' : '') + parents + '</td>' +
            '<td>' + esc(r.breeding_program) + '</td><td>' + (r.stage ? '<span class="dm-stage">' + esc(r.stage) + '</span>' : '<span class="dm-muted">&ndash;</span>') + '</td>' +
            (e && e.index ? '<td>' + (x && x.index_rank ? '<b>#' + x.index_rank + '</b> <span class="dm-muted dm-small">' + fmt(x.index) + '</span>' : '<span class="dm-muted">&ndash;</span>') + '</td>' : '') +
            traits.map(t => { const v = x && (x.values || {})[t.trait]; return '<td class="dm-trait-col">' + (v ? fmt(v.v) + (v.rank ? ' <span class="dm-rank">#' + v.rank + '</span>' : '') : '') + '</td>'; }).join('') +
            '<td>' + decisionCell(r, ed) + '</td><td class="dm-newstage">' + newStageCell(r, ed) + '</td>' +
            '<td>' + (ed ? '<input type="text" class="form-control input-sm dm-comment" data-k="' + esc(k) + '" value="' + esc(r.save_comment || '') + '" placeholder="why?" maxlength="4000" />' : esc(r.save_comment || '')) + '</td></tr>';
    }).join('');
    $('#dm_dec_table').html('<div class="dm-table-wrap"><table class="table table-condensed dm-table dm-dec"><thead>' + head + '</thead><tbody>' +
        (body || '<tr><td colspan="20" class="dm-muted text-center">Nothing matches the filters.</td></tr>') + '</tbody></table></div>');
    $('#dm_dec_foot').html('<span class="dm-muted">' + shown.length + ' of ' + rows.length + ' row(s) shown</span>' +
        (rows.length > shown.length ? ' <button class="btn btn-link btn-xs dm-more">show ' + (S.page === 50 ? '200' : 'all') + '</button>' : '') +
        (traits.length && e.traits.length > traits.length ? ' <span class="dm-muted">&middot; first ' + traits.length + ' of ' + e.traits.length + ' traits; all in the Evidence tab</span>' : ''));
    updateBulk();
}

function decisionCell(r, ed) {
    if (!ed) return r.decision ? '<span class="dm-dec-tag dm-dec-' + r.decision + '">' + decisionLabel(r.decision) + '</span>' : '<span class="dm-muted">&ndash;</span>';
    return '<div class="dm-decide" data-k="' + esc(rowKey(r)) + '">' + DECISIONS.map(d =>
        '<button type="button" class="dm-dbtn dm-dbtn-' + d.v + (r.decision === d.v ? ' on' : '') + '" data-v="' + d.v + '" title="' + d.label + '">' + d.label + '</button>').join('') + '</div>';
}

function newStageCell(r, ed) {
    if (r.busy) return '<span class="glyphicon glyphicon-refresh dm-spin dm-muted"></span>';
    if (ed && (r.decision === 'advance' || r.decision === 'jump') && r.allowed && r.allowed.length > 1) {
        return '<select class="form-control input-sm dm-stage-sel" data-k="' + esc(rowKey(r)) + '">' + r.allowed.map(s => '<option' + (s === r.selected_stage ? ' selected' : '') + '>' + esc(s) + '</option>').join('') + '</select>' +
            '<div class="dm-small dm-muted">' + esc(r.new_stage || '') + '</div>';
    }
    return r.new_stage ? '<span class="dm-stage dm-stage-new">' + esc(r.new_stage) + '</span>' : (r.warning ? '<span class="text-warning dm-small">' + esc(r.warning) + '</span>' : '');
}

function rowByKey(k) { return S.rows.find(r => rowKey(r) === k); }

function redrawRow(r) {
    const k = rowKey(r);
    const $tr = $('#dm_dec_table tr[data-k]').filter(function () { return $(this).attr('data-k') === k; });
    if (!$tr.length) return;
    $tr.attr('class', 'dm-row-' + (r.decision || 'none'));
    $tr.find('.dm-decide').replaceWith(decisionCell(r, editable()));
    $tr.find('.dm-newstage').html(newStageCell(r, editable()));
}

// the new stage of a decision (advance and jump may choose among stages)
function computeStage(r, selectedStage) {
    return call('POST', API + '/compute_new_stage', {
        current_stage: r.stage || '', decision: r.decision, year: meetingYear(), meeting_date: S.src.meeting.date || '',
        stock_id: r.stock_id || '', selected_stage: selectedStage || '',
    }).then(x => {
        r.allowed = x.allowed_stages || [];
        r.selected_stage = x.selected_stage || '';
        r.new_stage = x.new_stage || '';
        r.warning = (r.decision === 'advance' || r.decision === 'jump') && !r.allowed.length ? (x.warning || 'No next stage for this accession') : '';
    });
}

function setDecision(r, v) {
    r.decision = v;
    r.warning = '';
    if (!v) { r.new_stage = ''; r.allowed = null; redrawRow(r); queueDraft(r); renderStats(); return Promise.resolve(); }
    r.busy = true;
    redrawRow(r);
    return computeStage(r, '').catch(e => { r.warning = e.message; r.new_stage = ''; })
        .then(() => { r.busy = false; redrawRow(r); queueDraft(r); renderStats(); });
}

function queueDraft(r) {
    if (!editable()) return;
    S.pending[rowKey(r)] = { accession: r.accession, breeding_program: r.breeding_program, decision: r.decision || '', new_stage: r.new_stage || '', save_comment: r.save_comment || '' };
    $('#dm_draft_state').html('<span class="dm-muted">unsaved changes...</span>');
    clearTimeout(S.draftTimer);
    S.draftTimer = setTimeout(flushDraft, 900);
}

function flushDraft() {
    const rows = Object.values(S.pending);
    if (!rows.length || !S.id) return Promise.resolve();
    S.pending = {};
    $('#dm_draft_state').html('<span class="dm-muted"><span class="glyphicon glyphicon-refresh dm-spin"></span> saving draft...</span>');
    return call('POST', EV + '/draft', { meeting_id: S.id, rows: JSON.stringify(rows) })
        .then(() => $('#dm_draft_state').html('<span class="dm-ok"><span class="glyphicon glyphicon-ok"></span> draft saved</span>'))
        .catch(e => {
            rows.forEach(x => { S.pending[x.accession + '\t' + x.breeding_program] = S.pending[x.accession + '\t' + x.breeding_program] || x; });
            $('#dm_draft_state').html('<span class="text-danger" title="' + esc(e.message) + '"><span class="glyphicon glyphicon-warning-sign"></span> draft not saved</span>');
        });
}

function updateBulk() {
    const n = Object.keys(S.checked).filter(k => S.checked[k]).length;
    $('#dm_bulk_n').text(n ? n + ' checked' : 'Check rows to decide many at once');
    $('#dm_bulk .dm-dbtn, #dm_bulk_clear').prop('disabled', !n);
}

function bulkDecide(v) {
    const rows = Object.keys(S.checked).filter(k => S.checked[k]).map(rowByKey).filter(Boolean);
    if (!rows.length) return;
    // one at a time: the new stage of each accession is computed on the server
    const next = i => (i >= rows.length ? Promise.resolve() : setDecision(rows[i], v).then(() => next(i + 1)));
    $('#dm_bulk .dm-dbtn').prop('disabled', true);
    next(0).then(() => { S.checked = {}; renderRows(); });
}

function openSave() {
    flushDraft();
    const decided = S.rows.filter(r => r.decision);
    if (!decided.length) { flash('warning', 'No decision yet: choose Drop, Hold, Advance or Jump for the accessions first.'); return; }
    const missing = decided.filter(r => (r.decision === 'advance' || r.decision === 'jump') && !r.new_stage);
    const c = decisionCounts();
    $('#dm_save_summary').html(
        '<div class="dm-stats dm-stats-sm">' +
        '<div class="dm-stat"><div class="v">' + c.decided + '<small>/' + c.total + '</small></div><div class="l">decided</div></div>' +
        '<div class="dm-stat dm-stat-adv"><div class="v">' + (c.advance + c.jump) + '</div><div class="l">advance / jump</div></div>' +
        '<div class="dm-stat dm-stat-hold"><div class="v">' + c.hold + '</div><div class="l">hold</div></div>' +
        '<div class="dm-stat dm-stat-drop"><div class="v">' + c.drop + '</div><div class="l">drop</div></div></div>' +
        (missing.length ? alertHtml('warning', missing.length + ' advance/jump decision(s) have no new stage: ' + esc(missing.slice(0, 5).map(r => r.accession).join(', ')) + (missing.length > 5 ? '...' : '') + '. Their stage will not change.') : '') +
        (c.total > c.decided ? '<p class="dm-muted">' + (c.total - c.decided) + ' row(s) without decision are not saved.</p>' : '') +
        '<div class="dm-table-wrap" style="max-height:260px"><table class="table table-condensed dm-table"><thead><tr><th>Accession</th><th>Program</th><th>Stage</th><th>Decision</th><th>New stage</th><th>Comment</th></tr></thead><tbody>' +
        decided.map(r => '<tr><td>' + esc(r.accession) + '</td><td>' + esc(r.breeding_program) + '</td><td>' + esc(r.stage) + '</td><td><span class="dm-dec-tag dm-dec-' + r.decision + '">' + decisionLabel(r.decision) + '</span></td><td>' + esc(r.new_stage) + '</td><td>' + esc(r.save_comment) + '</td></tr>').join('') +
        '</tbody></table></div>');
    $('#dm_save_notes').val(S.src.meeting.notes || '');
    $('#dm_save_msg').empty();
    $('#dm_save_confirm').prop('disabled', false);
    $('#dm_save_modal').modal('show');
}

function confirmSave() {
    const m = S.src.meeting;
    const payload = {
        meeting_id: S.id, meeting_name: m.name, date: m.date, attendees: (m.attendees || []).join(', '),
        meeting_notes: $.trim($('#dm_save_notes').val() || ''),
        accessions: S.rows.filter(r => r.decision).map(r => ({
            stock_id: r.stock_id || '', accession: r.accession, breeding_program: r.breeding_program, previous_stage: r.stage || '',
            decision: r.decision, new_stage: r.new_stage || '', notes: r.notes || '', save_comment: r.save_comment || '',
        })),
    };
    $('#dm_save_confirm').prop('disabled', true).html('<span class="glyphicon glyphicon-refresh dm-spin"></span> Saving...');
    fetch(API + '/save_all_decisions', { method: 'POST', headers: { Accept: 'application/json', 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
        .then(resp => resp.json().catch(() => ({})).then(d => {
            if (!resp.ok || d.error) throw new Error(d.message || d.error || ('HTTP ' + resp.status));
            $('#dm_save_modal').modal('hide');
            flash('success', '<b>Decisions saved.</b> The new stages are recorded on the accessions.');
            document.dispatchEvent(new CustomEvent('meeting:decisions-saved', { detail: { meeting_id: S.id } }));
            return Promise.all([loadMeetings(), loadSources()]).then(() => loadRows());
        }))
        .catch(e => $('#dm_save_msg').html(alertHtml('danger', esc(e.message))))
        .then(() => $('#dm_save_confirm').prop('disabled', false).html('<span class="glyphicon glyphicon-lock"></span> Save decisions for good'));
}

function uploadExcel(file) {
    if (!file) return;
    const fd = new FormData();
    fd.append('decision_upload_file', file);
    fd.append('meeting_id', S.id);
    flash('info', '<span class="glyphicon glyphicon-refresh dm-spin"></span> Reading ' + esc(file.name) + '...');
    fetch(API + '/upload_decision_template', { method: 'POST', body: fd, headers: { Accept: 'application/json' } })
        .then(resp => resp.json().catch(() => ({})).then(d => {
            if (!resp.ok || d.error) throw new Error(d.message || d.error || ('HTTP ' + resp.status));
            let n = 0;
            (d.rows || []).forEach(u => {
                const r = rowByKey(u.accession + '\t' + u.breeding_program);
                if (!r) return;
                const dec = String(u.decision || '').toLowerCase();
                if (dec === (r.decision || '') && (u.new_stage || '') === (r.new_stage || '') && (u.save_comment || '') === (r.save_comment || '')) return;
                r.decision = dec; r.new_stage = u.new_stage || ''; r.save_comment = u.save_comment || ''; r.allowed = null;
                queueDraft(r); n++;
            });
            renderRows(); renderStats();
            flash('success', n + ' decision(s) taken from the file. Check them before saving.' + ((d.unmatched_rows || []).length ? ' ' + d.unmatched_rows.length + ' row(s) of the file are not accessions of this meeting.' : ''));
        }))
        .catch(e => flash('danger', 'The file could not be used: ' + esc(e.message)));
}

// ---------------------------------------------------------------- report
function renderReport() {
    if (!S.src) return;
    const m = S.src.meeting;
    const c = decisionCounts();
    const hist = S.src.history || [];
    $('#dm_report').html(
        '<div class="row"><div class="col-md-6"><div class="dm-card"><h4>Meeting</h4><dl class="dm-dl">' +
        '<dt>Date</dt><dd>' + esc(m.date || '') + '</dd><dt>Location</dt><dd>' + esc(m.location || '') + '</dd>' +
        '<dt>Programs</dt><dd>' + esc((m.programs || []).join(', ')) + '</dd><dt>Attendees</dt><dd>' + esc((m.attendees || []).join(', ')) + '</dd>' +
        '<dt>Status</dt><dd>' + (m.saved ? 'decisions saved' + (m.saved_at ? ' (' + esc(m.saved_at) + ')' : '') : 'open') + '</dd>' +
        (m.notes ? '<dt>Notes</dt><dd>' + esc(m.notes) + '</dd>' : '') + '</dl>' +
        '<button class="btn btn-primary btn-sm" id="dm_report_btn2"><span class="glyphicon glyphicon-file"></span> Open the meeting report</button></div></div>' +
        '<div class="col-md-6"><div class="dm-card"><h4>Decisions</h4>' +
        (S.rowsLoaded ? '<div class="dm-bars">' + DECISIONS.map(d => { const n = c[d.v]; const pct = c.total ? Math.round(100 * n / c.total) : 0; return '<div class="dm-barrow"><span>' + d.label + '</span><div class="dm-bar"><div class="dm-bar-in dm-dec-' + d.v + '" style="width:' + pct + '%"></div></div><b>' + n + '</b></div>'; }).join('') +
            '<div class="dm-barrow"><span>None</span><div class="dm-bar"><div class="dm-bar-in" style="background:#cbd5e1;width:' + (c.total ? Math.round(100 * (c.total - c.decided) / c.total) : 0) + '%"></div></div><b>' + (c.total - c.decided) + '</b></div></div>'
            : '<p class="dm-muted">Open the <a href="#" class="dm-goto" data-tab="decide">Decisions</a> tab to load them.</p>') +
        '</div><div class="dm-card"><h4>History of the evidence</h4>' + (hist.length ? '<ul class="dm-hist">' + hist.slice().reverse().map(h =>
            '<li><span class="dm-hist-' + esc(h.action) + '">' + esc(h.action) + '</span> ' + esc(h.name || '') + ' <span class="dm-muted">&middot; ' + esc(h.by || '') + ', ' + esc(h.on || '') + (h.after_save ? ', after the decisions were saved' : '') + '</span></li>').join('') + '</ul>' : '<p class="dm-muted">No change yet.</p>') +
        '</div></div></div>');
}

function openReport() {
    window.open(API + '/meeting_report_html?meeting_id=' + encodeURIComponent(S.id), '_blank', 'noopener');
}

// ---------------------------------------------------------------- init
export function init() {
    $ = window.jQuery;
    if (!$('#dm-app').length) return;
    window.getSelectedDecisionMeeting = selected;
    window.requireSelectedDecisionMeeting = () => selected() || (window.alert('Please select one meeting first.'), null);

    // meeting list
    $(document).on('click', '.dm-mitem', function (ev) { ev.preventDefault(); flushDraft(); openMeeting($(this).data('id')); });
    $(document).on('click', '.dm-seg[data-filter]', function () { S.filter = $(this).data('filter'); renderMeetings(); });
    $('#dm_msearch').on('input', function () { S.search = this.value; renderMeetings(); });
    document.addEventListener('meeting:created', ev => {
        const id = ev.detail && (ev.detail.project_id || ev.detail.meeting_id);
        S.filter = 'open';
        loadMeetings().then(() => { if (id) openMeeting(id, 'evidence'); });
    });

    // tabs
    $(document).on('click', '.dm-tab', function () { showTab($(this).data('tab')); });
    $(document).on('click', '.dm-goto', function (ev) { ev.preventDefault(); showTab($(this).data('tab')); });
    $(document).on('click', '#dm_report_btn, #dm_report_btn2', openReport);

    // evidence
    $(document).on('click', '.dm-add-open', openAdd);
    $(document).on('click', '.dm-add-tab', function () { S.addTab = $(this).data('add'); renderAdd(); });
    $('#dm_add_search').on('input', renderAdd);
    $('#dm_add_mine').on('change', renderAdd);
    $(document).on('change', '#dm_add_list input', countAdd);
    $('#dm_add_go').on('click', addChecked);
    $(document).on('click', '.dm-unlink', function (ev) { ev.stopPropagation(); unlink($(this).data('key')); });
    $(document).on('click', '.dm-source[data-key]', function (ev) {
        if ($(ev.target).closest('a,button').length) return;
        S.viewKey = $(this).data('key');
        $('.dm-source').removeClass('on').filter(this).addClass('on');
        renderEvidenceTable();
    });
    $(document).on('click', '.dm-seg[data-view]', function () { S.viewKey = $(this).data('view'); renderEvidence(); renderEvidenceTable(); });
    $('#dm_ev_search').on('input', () => renderEvidenceTable());
    $('#dm_ev_selected').on('change', () => renderEvidenceTable());
    $('#dm_ev_csv').on('click', evidenceCsv);
    $('#dm_sel_by').on('change', function () {
        SEL.rankBy = this.value;
        const e = S.ev[S.viewKey];
        if (e && SEL.rankBy !== 'index') SEL.dir = traitOf(e, SEL.rankBy).direction || 'increase';
        renderEvidenceTable();
    });
    $(document).on('click', '#dm_sel_dir button', function () { SEL.dir = $(this).data('dir'); renderEvidenceTable(); });
    $('#dm_sel_pct').on('input change', function () { SEL.pct = Number(this.value); const e = S.ev[S.viewKey]; if (e) renderSelection(e); });
    $('#dm_sel_use').on('click', useSelection);

    // decisions
    $(document).on('click', '.dm-seg[data-dfilter]', function () { S.dfilter = $(this).data('dfilter'); renderRows(); });
    $('#dm_dec_search').on('input', function () { S.dsearch = this.value; renderRows(); });
    $('#dm_dec_program').on('change', function () { S.dprogram = this.value; renderRows(); });
    $('#dm_dec_source').on('change', function () {
        S.evKey = this.value;
        $('#dm_dec_table').css('opacity', 0.5);
        getEvidence(S.evKey).catch(e => flash('warning', esc(e.message))).then(() => { $('#dm_dec_table').css('opacity', 1); renderRows(); });
    });
    $(document).on('click', '.dm-sortable', function () { S.sort = $(this).data('sort'); renderRows(); });
    $(document).on('click', '.dm-more', () => { S.page = S.page === 50 ? 200 : 'all'; renderRows(); });
    $(document).on('click', '.dm-decide .dm-dbtn', function () {
        const r = rowByKey($(this).closest('.dm-decide').data('k'));
        if (!r) return;
        const v = $(this).data('v');
        setDecision(r, r.decision === v ? '' : v);
    });
    $(document).on('change', '.dm-stage-sel', function () {
        const r = rowByKey($(this).data('k'));
        if (!r) return;
        r.busy = true; redrawRow(r);
        computeStage(r, this.value).catch(e => { r.warning = e.message; }).then(() => { r.busy = false; redrawRow(r); queueDraft(r); });
    });
    $(document).on('change', '.dm-comment', function () {
        const r = rowByKey($(this).data('k'));
        if (r) { r.save_comment = this.value; queueDraft(r); }
    });
    $(document).on('change', '.dm-check', function () { S.checked[$(this).data('k')] = this.checked; updateBulk(); });
    $(document).on('change', '#dm_check_all', function () {
        const on = this.checked;
        $('.dm-check').each(function () { this.checked = on; S.checked[$(this).data('k')] = on; });
        updateBulk();
    });
    $(document).on('click', '#dm_bulk .dm-dbtn', function () { bulkDecide($(this).data('v')); });
    $('#dm_bulk_clear').on('click', () => bulkDecide(''));
    $('#dm_bulk_selected').on('click', () => {
        const sel = {};
        (S.src.accessions || []).forEach(a => { if ((a.selected_in || []).length) sel[a.accession] = true; });
        S.checked = {};
        filteredRows().forEach(r => { if (sel[r.accession]) S.checked[rowKey(r)] = true; });
        renderRows();
    });
    $('#dm_save_btn').on('click', openSave);
    $('#dm_save_confirm').on('click', confirmSave);
    $('#dm_template_btn').on('click', () => { window.location = API + '/decision_upload_template?meeting_id=' + encodeURIComponent(S.id); });
    $('#dm_upload_btn').on('click', () => $('#dm_upload_file').val('').trigger('click'));
    $('#dm_upload_file').on('change', function () { uploadExcel(this.files && this.files[0]); });
    window.addEventListener('beforeunload', () => { if (Object.keys(S.pending).length) flushDraft(); });

    const u = new URL(window.location.href);
    const tab = u.searchParams.get('tab');
    if (['evidence', 'decide', 'report'].indexOf(tab) >= 0) S.tab = tab;
    // the variety vote is always shown under the tabs; old links with tab=vote scroll to it
    if (tab === 'vote') setTimeout(() => { const v = document.getElementById('dm_vote_section'); if (v && v.scrollIntoView) v.scrollIntoView(); }, 1500);
    loadMeetings().then(() => {
        const id = u.searchParams.get('meeting_id');
        if (id && S.meetings.some(m => m.id === String(id))) {
            const m = S.meetings.find(x => x.id === String(id));
            if (m.saved) S.filter = 'all';
            renderMeetings();
            openMeeting(id);
        } else {
            openMeeting(null);
        }
    });
}
