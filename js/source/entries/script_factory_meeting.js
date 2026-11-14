/*
 * Analysis Pipeline - analysis evidence of a decision meeting
 *
 * On the decision meeting page (/breeders/meeting): the stored Analysis
 * Pipeline analyses linked to the selected meeting, and for a chosen one
 * the evidence per accession (genotype value and rank per trait, selection
 * index, environmental zones), restricted by default to the accessions of
 * the meeting. Links are kept in the meeting (meeting_json related_analyses).
 * Several analyses can be added or removed at once. After the decisions are
 * saved, analyses can still be added (flagged "added after the decisions were
 * saved") but none can be removed: the evidence is a permanent record. Every
 * change is kept in the meeting's history (analyses_history).
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
    let h = '<p><b>' + esc(r.meeting.name) + '</b> ' + (closed ? '<span class="label label-default" title="The decisions are saved: analyses can still be added, but the evidence of the decisions cannot be removed">decisions saved</span>' : '<span class="label label-success">open</span>') + ' &middot; ';
    h += list.length ? list.length + ' analysis(es) as evidence. Click one to see its results per accession.' : 'No analysis linked yet.' + (r.can_link ? ' Use <b>Add analyses</b>.' : '');
    h += '</p>';
    h += list.map(a => '<div class="sfm-card' + (S.current === a.analysis_id ? ' on' : '') + '" data-id="' + esc(a.analysis_id) + '">' +
        '<div class="sfm-card-title">' + esc(a.name || ('analysis ' + a.analysis_id)) + '</div>' +
        '<div class="sfm-card-meta">' + (a.hidden ? 'private analysis of another user' : esc((a.created || '').slice(0, 10)) + (a.owner ? ' &middot; ' + esc(a.owner) : '')) +
        (a.linked_by ? '<br/>added by ' + esc(a.linked_by) + (a.linked_at ? ' on ' + esc(a.linked_at) : '') : '') +
        (a.after_save ? '<br/><span class="sfm-late">added after the decisions were saved</span>' : '') + '</div>' +
        (a.hidden ? '' : '<a class="btn btn-default btn-xs" target="_blank" href="/tools/script_factory/analysis/' + esc(a.analysis_id) + '"><span class="glyphicon glyphicon-dashboard"></span> Results page</a> ') +
        (r.can_link && !closed ? '<button class="btn btn-default btn-xs sfm-unlink" data-id="' + esc(a.analysis_id) + '"><span class="glyphicon glyphicon-remove"></span> Remove</button>' : '') +
        (closed ? '<span class="sfm-locked" title="The decisions are saved: this evidence is a permanent record and the analysis cannot be removed or deleted"><span class="glyphicon glyphicon-lock"></span> permanent record</span>' : '') +
        '</div>').join('');
    $('#sfm_linked').html(h);

    $('#sfm_actions').toggle(!!r.can_link || !!(r.history || []).length);
    $('#sfm_add_toggle').toggle(!!r.can_link);
    $('#sfm_remove_toggle').toggle(!!r.can_link && list.length > 0 && !closed);
    $('#sfm_history_toggle').toggle(!!(r.history || []).length);
    if (!r.can_link) $('#sfm_add_row, #sfm_remove_row').hide();
    if (!list.length || closed) $('#sfm_remove_row').hide();
    renderAddList();
    renderRemoveList();
    renderHistory();
    if (!list.length) { $('#sfm_evidence').hide(); return; }
    const show = list.find(a => a.analysis_id === S.current && !a.hidden) || list.find(a => !a.hidden);
    if (show) showEvidence(show.analysis_id); else $('#sfm_evidence').hide();
}

// analyses that can be added: stored ones not yet linked, filtered by the search box
function renderAddList() {
    const r = S.data;
    const linked = {};
    (r.analyses || []).forEach(a => { linked[a.analysis_id] = true; });
    const checked = {};
    $('#sfm_add_list input:checked').each(function() { checked[this.value] = true; });
    const q = String($('#sfm_add_filter').val() || '').toLowerCase().trim();
    const mine = $('#sfm_add_mine').is(':checked');
    const all = (r.available || []).filter(a => !linked[a.analysis_id]);
    const shown = all.filter(a => (!mine || a.is_owner) && (!q || [a.name, a.owner, a.created].join(' ').toLowerCase().indexOf(q) >= 0));
    $('#sfm_add_list').html(shown.length
        ? shown.map(a => '<label><input type="checkbox" value="' + esc(a.analysis_id) + '"' + (checked[a.analysis_id] ? ' checked' : '') + ' />' + esc(a.name) +
            ' <span class="sfm-muted">&middot; ' + esc((a.created || '').slice(0, 10)) + ' &middot; ' + (a.is_owner ? 'mine' : esc(a.owner || 'other user')) + '</span></label>').join('')
        : '<div class="sfm-muted" style="padding:6px 8px">' + (all.length ? 'No analysis matches the search.' : 'Every stored Analysis Pipeline analysis you can open is already linked to this meeting.') + '</div>');
    updateButtons();
}

function renderRemoveList() {
    const list = (S.data.analyses || []);
    $('#sfm_remove_list').html(list.map(a => '<label><input type="checkbox" value="' + esc(a.analysis_id) + '" />' + esc(a.name || ('analysis ' + a.analysis_id)) +
        (a.linked_by ? ' <span class="sfm-muted">&middot; added by ' + esc(a.linked_by) + (a.linked_at ? ' on ' + esc(a.linked_at) : '') + '</span>' : '') + '</label>').join(''));
    updateButtons();
}

function renderHistory() {
    const hist = (S.data.history || []).slice().reverse();
    $('#sfm_history').html('<b>History of the evidence of this meeting</b>' + (hist.length
        ? '<table class="table table-condensed" style="margin:6px 0 0 0"><thead><tr><th>Date</th><th>Change</th><th>Analysis</th><th>By</th></tr></thead><tbody>' +
            hist.map(x => '<tr><td>' + esc(x.on || '') + '</td><td>' + (x.action === 'removed' ? '<span class="text-danger">removed</span>' : '<span class="text-success">added</span>') +
                (x.after_save ? ' <span class="sfm-late">(after the decisions were saved)</span>' : '') + '</td><td>' + esc(x.name || ('analysis ' + x.analysis_id)) + '</td><td>' + esc(x.by || '') + '</td></tr>').join('') + '</tbody></table>'
        : '<div class="sfm-muted">No change recorded.</div>'));
}

function updateButtons() {
    const nAdd = $('#sfm_add_list input:checked').length;
    const nRem = $('#sfm_remove_list input:checked').length;
    $('#sfm_add_btn').prop('disabled', !nAdd).html('<span class="glyphicon glyphicon-link"></span> Add ' + (nAdd ? nAdd + ' ' : '') + 'checked analys' + (nAdd === 1 ? 'is' : 'es'));
    $('#sfm_remove_btn').prop('disabled', !nRem).html('<span class="glyphicon glyphicon-remove"></span> Remove ' + (nRem ? nRem + ' ' : '') + 'checked analys' + (nRem === 1 ? 'is' : 'es'));
}

function checkedIds(sel) { return $(sel + ' input:checked').map(function() { return this.value; }).get(); }

function link(ids, action) {
    const list = [].concat(ids).map(String).filter(x => /^\d+$/.test(x));
    if (!list.length) return Promise.resolve();
    $('#sfm_add_btn, #sfm_remove_btn').prop('disabled', true);
    return post('/ajax/script_factory/meetings/link', { meeting_id: S.meeting.meeting_id, analysis_id: list.join(','), action: action })
        .then(() => {
            if (action === 'unlink' && list.indexOf(String(S.current)) >= 0) S.current = null;
            if (action === 'link') { S.current = Number(list[list.length - 1]); $('#sfm_add_list input').prop('checked', false); }
            return loadMeeting();
        })
        .catch(e => { $('#sfm_linked').prepend(alertHtml('danger', esc(e.message))); updateButtons(); });
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
        (nInMeeting ? '' : ' <b>(none: check the meeting\'s accession list or uncheck the filter)</b>') + '. Rank 1 = best of the analysis.' +
        (e.index ? ' ' + e.rows.filter(r => r.index_rank).length + ' of the ' + e.rows.length + ' accessions are ranked by the index: the others miss a value of an index trait (' + esc((e.index.traits || []).join(', ')) + ').' : '') +
        ((e.zone_targets || []).length ? ' ' + e.rows.filter(r => r.zones && Object.keys(r.zones).length).length + ' are ranked in an environmental zone.' : '') +
        ' Accessions without a value are listed last.</span>';
    $('#sfm_summary').html(s);
    $('#sfm_only_selected').closest('label').toggle(!!e.index);

    // every cell is {d: html shown, s: sort key}; accessions without a value sort last (rank 1 = best first)
    const LAST = 1e12;
    const cell = (d, s) => ({ d: d, s: s === null || s === undefined || s === '' ? LAST : s });
    const idxTraits = (e.index && e.index.traits) || [];
    const cols = [{ title: 'Accession' }, { title: 'In meeting' }];
    e.traits.forEach(t => cols.push({ title: esc(t.trait) + ' <small>(' + esc(label) + ', rank)</small>' }));
    if (e.index) cols.push({ title: 'Index' }, { title: 'Index rank' }, { title: 'Selected' });
    (e.zone_targets || []).forEach(z => cols.push({ title: 'Best zone: ' + esc(z) + ' <small>(rank in zone)</small>' }));
    const data = rows.map(r => {
        const out = [cell(r.stock_id ? '<a href="/stock/' + encodeURIComponent(r.stock_id) + '/view" target="_blank">' + esc(r.accession) + '</a>' : esc(r.accession), r.accession),
            cell(inMeeting[r.accession] ? '<span class="sfm-in glyphicon glyphicon-ok" title="In this meeting"></span>' : '', inMeeting[r.accession] ? 0 : 1)];
        e.traits.forEach(t => {
            const v = r.values[t.trait];
            out.push(v ? cell(fmt(v.v) + (v.se !== null && v.se !== undefined ? ' <span class="sfm-rank">&plusmn;' + fmt(v.se) + '</span>' : '') +
                ' <span class="sfm-rank">#' + v.rank + '</span>', v.rank) : cell('<span class="sfm-muted" title="No value for this trait">&ndash;</span>', null));
        });
        if (e.index) {
            if (r.index_rank) {
                out.push(cell(fmt(r.index, 3), r.index_rank), cell(String(r.index_rank), r.index_rank), cell(r.selected ? '<span class="sfm-sel">selected</span>' : '', r.selected ? 0 : 1));
            } else {
                const miss = idxTraits.filter(t => !r.values[t]);
                const why = miss.length ? 'Not ranked by the index: no value for ' + miss.join(', ') : 'Not ranked by the index';
                out.push(cell('<span class="sfm-muted" title="' + esc(why) + '">not ranked</span>', null), cell('', null), cell('', 2));
            }
        }
        (e.zone_targets || []).forEach(z => {
            const b = (r.zones || {})[z];
            const min = (e.zone_min_env || {})[z];
            out.push(b ? cell(esc(b.zone) + ' <span class="sfm-rank">#' + b.rank + ' of ' + b.n + '</span>', b.rank / (b.n || 1))
                : cell('<span class="sfm-muted" title="Not ranked in any zone: ' + (e.index && !r.index_rank && /index/i.test(z) ? 'no index value' : 'tested in fewer than ' + esc(min || 'the minimum number of') + ' environments of each zone') + '">&ndash;</span>', null));
        });
        return out;
    });
    if (S.dt) { S.dt.destroy(); S.dt = null; }
    $('#sfm_table').empty();
    if ($.fn.DataTable) {
        // best first: index rank, else rank of the first trait
        const order = e.index ? [[2 + e.traits.length + 1, 'asc']] : (e.traits.length ? [[2, 'asc']] : []);
        S.dt = $('#sfm_table').DataTable({ data: data, columns: cols, pageLength: 25, order: order, scrollX: true, deferRender: true,
            columnDefs: [{ targets: '_all', render: { _: 'd', sort: 's', type: 's' } }] });
    } else {
        $('#sfm_table').html('<thead><tr>' + cols.map(c => '<th>' + c.title + '</th>').join('') + '</tr></thead><tbody>' + data.map(r => '<tr><td>' + r.map(x => x.d).join('</td><td>') + '</td></tr>').join('') + '</tbody>');
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
    $('#sfm_add_toggle').on('click', () => { $('#sfm_remove_row, #sfm_history').hide(); $('#sfm_add_row').toggle(); $('#sfm_add_filter').trigger('focus'); });
    $('#sfm_remove_toggle').on('click', () => { $('#sfm_add_row, #sfm_history').hide(); $('#sfm_remove_row').toggle(); });
    $('#sfm_history_toggle').on('click', () => { $('#sfm_add_row, #sfm_remove_row').hide(); $('#sfm_history').toggle(); });
    $('#sfm_add_cancel').on('click', () => $('#sfm_add_row').hide());
    $('#sfm_remove_cancel').on('click', () => $('#sfm_remove_row').hide());
    $('#sfm_add_filter').on('input', renderAddList);
    $('#sfm_add_mine').on('change', renderAddList);
    $('#sfm_add_all').on('click', () => { $('#sfm_add_list input').prop('checked', true); updateButtons(); });
    $('#sfm_add_none').on('click', () => { $('#sfm_add_list input').prop('checked', false); updateButtons(); });
    $('#sfm_add_list, #sfm_remove_list').on('change', 'input', updateButtons);
    $('#sfm_add_btn').on('click', () => link(checkedIds('#sfm_add_list'), 'link'));
    $('#sfm_remove_btn').on('click', () => {
        const ids = checkedIds('#sfm_remove_list');
        if (ids.length && window.confirm('Remove ' + ids.length + ' analys' + (ids.length === 1 ? 'is' : 'es') + ' from the evidence of the meeting? (The analyses themselves are not changed.)')) link(ids, 'unlink');
    });
    $('#sfm_only_meeting, #sfm_only_selected').on('change', () => { if (S.current && S.evidence[S.current]) renderEvidence(); });
    $('#sfm_csv').on('click', downloadCsv);
    // a meeting may already be selected (or the tracker loads later)
    setTimeout(onMeetingChange, 500);
}
