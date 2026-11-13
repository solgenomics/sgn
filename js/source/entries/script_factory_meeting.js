/*
 * Analysis Pipeline - analysis evidence of a decision meeting
 *
 * On the decision meeting page (/breeders/meeting): the stored Analysis
 * Pipeline analyses linked to the selected meeting, and for a chosen one
 * the evidence per accession (genotype value and rank per trait, selection
 * index, environmental zones), restricted by default to the accessions of
 * the meeting. Links are kept in the meeting (meeting_json related_analyses)
 * and can be changed while the meeting is open (not saved).
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

let $;
const S = { meeting: null, data: null, current: null, evidence: {}, dt: null, seq: 0 };

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function fmt(v, d) {
    if (v === null || v === undefined || v === '' || isNaN(Number(v))) return '';
    const x = Number(v);
    if (d !== undefined) return x.toFixed(d);
    const a = Math.abs(x);
    return a >= 1000 ? x.toFixed(0) : a >= 100 ? x.toFixed(1) : a >= 1 ? x.toFixed(2) : x.toPrecision(3);
}
function get(url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, data: data, dataType: 'json', cache: false })
            .done(r => (r && r.error ? reject(new Error(r.error)) : resolve(r)))
            .fail((x, st, err) => reject(new Error('Server error: ' + (err || st))));
    });
}
function post(url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, type: 'POST', data: data, dataType: 'json' })
            .done(r => (r && r.error ? reject(new Error(r.error)) : resolve(r)))
            .fail((x, st, err) => reject(new Error('Server error: ' + (err || st))));
    });
}
function alertHtml(type, msg) { return '<div class="alert alert-' + type + '" style="margin:6px 0">' + msg + '</div>'; }

// meeting selected in the Meeting Tracker (decision_meeting.js)
function selectedMeeting() {
    if (typeof window.getSelectedDecisionMeeting === 'function') return window.getSelectedDecisionMeeting();
    const c = $('.dm-meeting-check:checked').first();
    return c.length ? { meeting_id: c.data('meeting-id'), meeting_name: c.data('meeting-name') } : null;
}

// accessions of the meeting: stored with it (saved meetings) and in the decision table
function meetingAccessions() {
    const set = {};
    ((S.data && S.data.meeting && S.data.meeting.accessions) || []).forEach(a => { set[a] = true; });
    const tbl = $('#decision_table');
    if (tbl.length && $.fn.DataTable && $.fn.DataTable.isDataTable(tbl[0])) {
        tbl.DataTable().column(0).data().toArray().forEach(a => {
            const name = $('<div>' + a + '</div>').text().trim();
            if (name) set[name] = true;
        });
    }
    return set;
}

function onMeetingChange() {
    const m = selectedMeeting();
    const id = m && m.meeting_id ? String(m.meeting_id) : null;
    if (id === (S.meeting && String(S.meeting.meeting_id))) return;
    S.meeting = m;
    S.current = null;
    if (!id) {
        $('#sfm_body').hide();
        $('#sfm_status').show().html('Select a meeting in the Meeting Tracker to see the analyses that support its decisions.');
        return;
    }
    loadMeeting();
}

function loadMeeting() {
    const seq = ++S.seq;
    $('#sfm_status').show().html('<span class="glyphicon glyphicon-refresh"></span> Loading the analyses of the meeting...');
    get('/ajax/script_factory/meetings/analyses', { meeting_id: S.meeting.meeting_id })
        .then(r => {
            if (seq !== S.seq) return;
            S.data = r;
            $('#sfm_status').hide();
            $('#sfm_body').show();
            renderLinked();
        })
        .catch(e => { if (seq === S.seq) $('#sfm_status').show().html(alertHtml('danger', esc(e.message))); });
}

function renderLinked() {
    const r = S.data;
    const list = r.analyses || [];
    const closed = r.meeting.saved;
    let h = '<p><b>' + esc(r.meeting.name) + '</b> ' + (closed ? '<span class="label label-default">saved: evidence fixed</span>' : '<span class="label label-success">open</span>') + ' &middot; ';
    h += list.length ? list.length + ' analysis(es) as evidence. Click one to see its results per accession.' : 'No analysis linked yet.';
    h += '</p>';
    h += list.map(a => '<div class="sfm-card' + (S.current === a.analysis_id ? ' on' : '') + '" data-id="' + esc(a.analysis_id) + '">' +
        '<div class="sfm-card-title">' + esc(a.name || ('analysis ' + a.analysis_id)) + '</div>' +
        '<div class="sfm-card-meta">' + (a.hidden ? 'private analysis of another user' : esc((a.created || '').slice(0, 10)) + (a.owner ? ' &middot; ' + esc(a.owner) : '')) +
        (a.linked_by ? '<br/>added by ' + esc(a.linked_by) + (a.linked_at ? ' on ' + esc(a.linked_at) : '') : '') + '</div>' +
        (a.hidden ? '' : '<a class="btn btn-default btn-xs" target="_blank" href="/tools/script_factory/analysis/' + esc(a.analysis_id) + '"><span class="glyphicon glyphicon-dashboard"></span> Results page</a> ') +
        (r.can_link ? '<button class="btn btn-default btn-xs sfm-unlink" data-id="' + esc(a.analysis_id) + '"><span class="glyphicon glyphicon-remove"></span> Remove</button>' : '') +
        '</div>').join('');
    $('#sfm_linked').html(h);

    const linked = {};
    list.forEach(a => { linked[a.analysis_id] = true; });
    const avail = (r.available || []).filter(a => !linked[a.analysis_id]);
    $('#sfm_add_row').toggle(!!r.can_link);
    $('#sfm_add_select').html(avail.length
        ? '<option value="">Choose a stored analysis...</option>' + avail.map(a => '<option value="' + esc(a.analysis_id) + '">' + esc(a.name) + ' (' + esc((a.created || '').slice(0, 10)) + (a.is_owner ? '' : ', ' + esc(a.owner || 'other user')) + ')</option>').join('')
        : '<option value="">No other stored Analysis Pipeline analysis</option>');
    if (!list.length) { $('#sfm_evidence').hide(); return; }
    const show = list.find(a => a.analysis_id === S.current && !a.hidden) || list.find(a => !a.hidden);
    if (show) showEvidence(show.analysis_id); else $('#sfm_evidence').hide();
}

function link(analysisId, action) {
    return post('/ajax/script_factory/meetings/link', { meeting_id: S.meeting.meeting_id, analysis_id: analysisId, action: action })
        .then(() => loadMeeting())
        .catch(e => $('#sfm_linked').prepend(alertHtml('danger', esc(e.message))));
}

function showEvidence(id) {
    S.current = id;
    $('.sfm-card').removeClass('on').filter('[data-id="' + id + '"]').addClass('on');
    $('#sfm_evidence').show();
    if (S.evidence[id]) { renderEvidence(); return; }
    $('#sfm_summary').html('<span class="glyphicon glyphicon-refresh"></span> Reading the results of the analysis...');
    if (S.dt) { S.dt.destroy(); S.dt = null; }
    $('#sfm_table').empty();
    get('/ajax/script_factory/decision_evidence', { analysis_id: id })
        .then(e => { S.evidence[id] = e; if (S.current === id) renderEvidence(); })
        .catch(err => { if (S.current === id) $('#sfm_summary').html(alertHtml('warning', err.message)); });
}

const GENETIC = { iid: 'unrelated accessions', parents: 'mother + father effects', pedigree: 'pedigree (A matrix)', genomic: 'genomic (G matrix)', single_step: 'single-step (H matrix)' };

function evidenceRows() {
    const e = S.evidence[S.current];
    const only = $('#sfm_only_meeting').is(':checked');
    const sel = $('#sfm_only_selected').is(':checked');
    const inMeeting = meetingAccessions();
    return { e: e, inMeeting: inMeeting, rows: e.rows.filter(r => (!only || inMeeting[r.accession]) && (!sel || r.selected)) };
}

function renderEvidence() {
    const { e, inMeeting, rows } = evidenceRows();
    const nInMeeting = e.rows.filter(r => inMeeting[r.accession]).length;
    const label = e.value_label || 'BLUP';
    let s = '<b>' + esc(e.name) + '</b> &middot; ' + (e.strategy === 'two_stage' ? 'two-stage' : 'single-stage') + ' analysis' + (e.n_trials ? ' of ' + e.n_trials + ' trial(s)' : '') +
        ', ' + (e.engine === 'blupf90' ? 'BLUPF90+' : 'R') + ', ' + esc(GENETIC[e.genetic_model] || e.genetic_model || '') +
        (e.genomic ? ' (' + esc(e.genomic.protocol_name || '') + ')' : '') + '. Values: <b>' + esc(label) + 's</b>. ' +
        '<a href="' + esc(e.dashboard) + '" target="_blank">Open the results page</a>.<br/>' +
        e.traits.map(t => '<span class="sfm-chip" title="' + (t.direction === 'decrease' ? 'lower is better (selection index)' : 'higher is better') + '">' + esc(t.trait) +
            (t.h2 !== null && t.h2 !== undefined ? ' &middot; H&sup2; ' + fmt(t.h2, 2) : '') + (t.direction === 'decrease' ? ' &darr;' : '') + '</span>').join(' ') +
        (e.index ? ' <span class="sfm-chip">index: ' + esc(e.index.method === 'rank_sum' ? 'rank sum' : 'weighted Z-score') + ', top ' + esc(e.index.selection_pct) + '% selected</span>' : '') +
        '<br/><span class="sfm-muted">' + nInMeeting + ' of the ' + e.rows.length + ' accessions of the analysis are in this meeting' +
        (nInMeeting ? '' : ' <b>(none: check the meeting\'s accession list or uncheck the filter)</b>') + '. Rank 1 = best of the analysis.</span>';
    $('#sfm_summary').html(s);
    $('#sfm_only_selected').closest('label').toggle(!!e.index);

    const cols = [{ title: 'Accession' }, { title: 'In meeting' }];
    e.traits.forEach(t => cols.push({ title: esc(t.trait) + ' <small>(' + esc(label) + ', rank)</small>' }));
    if (e.index) cols.push({ title: 'Index' }, { title: 'Index rank' }, { title: 'Selected' });
    (e.zone_targets || []).forEach(z => cols.push({ title: 'Best zone: ' + esc(z) }));
    const data = rows.map(r => {
        const out = [r.stock_id ? '<a href="/stock/' + encodeURIComponent(r.stock_id) + '/view" target="_blank">' + esc(r.accession) + '</a>' : esc(r.accession),
            inMeeting[r.accession] ? '<span class="sfm-in glyphicon glyphicon-ok" title="In this meeting"></span>' : ''];
        e.traits.forEach(t => {
            const v = r.values[t.trait];
            out.push(v ? '<span data-order="' + v.v + '">' + fmt(v.v) + (v.se !== null && v.se !== undefined ? ' <span class="sfm-rank">&plusmn;' + fmt(v.se) + '</span>' : '') +
                ' <span class="sfm-rank">#' + v.rank + '</span></span>' : '');
        });
        if (e.index) out.push(fmt(r.index, 3), r.index_rank || '', r.selected ? '<span class="sfm-sel">selected</span>' : '');
        (e.zone_targets || []).forEach(z => { const b = (r.zones || {})[z]; out.push(b ? esc(b.zone) + ' <span class="sfm-rank">#' + b.rank + ' of ' + b.n + '</span>' : ''); });
        return out;
    });
    if (S.dt) { S.dt.destroy(); S.dt = null; }
    $('#sfm_table').empty();
    if ($.fn.DataTable) {
        const order = e.index ? [[2 + e.traits.length + 1, 'asc']] : [];
        S.dt = $('#sfm_table').DataTable({ data: data, columns: cols, pageLength: 25, order: order, scrollX: true, deferRender: true,
            columnDefs: [{ targets: '_all', type: 'html-num-fmt' }, { targets: [0, 1], type: 'html' }] });
    } else {
        $('#sfm_table').html('<thead><tr>' + cols.map(c => '<th>' + c.title + '</th>').join('') + '</tr></thead><tbody>' + data.map(r => '<tr><td>' + r.join('</td><td>') + '</td></tr>').join('') + '</tbody>');
    }
}

function downloadCsv() {
    const { e, inMeeting, rows } = evidenceRows();
    const q = v => { const s = v === null || v === undefined ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const head = ['accession', 'in_meeting'];
    e.traits.forEach(t => head.push(t.trait, t.trait + '_se', t.trait + '_rank'));
    if (e.index) head.push('index', 'index_rank', 'selected');
    (e.zone_targets || []).forEach(z => head.push('best_zone_' + z, 'zone_rank_' + z));
    const lines = [head.map(q).join(',')].concat(rows.map(r => {
        const o = [r.accession, inMeeting[r.accession] ? 'yes' : 'no'];
        e.traits.forEach(t => { const v = r.values[t.trait]; o.push(v ? v.v : '', v ? v.se : '', v ? v.rank : ''); });
        if (e.index) o.push(r.index, r.index_rank, r.selected ? 'yes' : 'no');
        (e.zone_targets || []).forEach(z => { const b = (r.zones || {})[z]; o.push(b ? b.zone : '', b ? b.rank : ''); });
        return o.map(q).join(',');
    }));
    const blob = new Blob([lines.join('\n') + '\n'], { type: 'text/csv' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = (S.meeting.meeting_name || 'meeting') + '_' + (e.name || 'analysis') + '_evidence.csv';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
}

export function init() {
    $ = window.jQuery;
    $(document).on('change', '.dm-meeting-check', () => setTimeout(onMeetingChange, 0));
    $('#sfm_linked').on('click', '.sfm-card', function(ev) {
        if ($(ev.target).closest('a, button').length) return;
        const id = Number($(this).data('id'));
        const a = (S.data.analyses || []).find(x => x.analysis_id === id);
        if (a && !a.hidden) showEvidence(id);
    });
    $('#sfm_linked').on('click', '.sfm-unlink', function() {
        const id = $(this).data('id');
        if (window.confirm('Remove this analysis from the evidence of the meeting? (The analysis itself is not changed.)')) link(id, 'unlink');
    });
    $('#sfm_add_btn').on('click', () => { const id = $('#sfm_add_select').val(); if (!id) return; S.current = Number(id); link(id, 'link'); });
    $('#sfm_only_meeting, #sfm_only_selected').on('change', () => { if (S.current && S.evidence[S.current]) renderEvidence(); });
    $('#sfm_csv').on('click', downloadCsv);
    // a meeting may already be selected (or the tracker loads later)
    setTimeout(onMeetingChange, 500);
}
