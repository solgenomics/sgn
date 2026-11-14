/*
 * Variety vote of a decision meeting - public pages (no login)
 *
 * /decision_vote/ballot/<ballot token>: the personal link e-mailed to an
 * invited person (there is no public link). A place for each candidate
 * variety (1 = best; the list never moves), optional notes on every variety
 * (the other accessions of the vote are only for notes). Until the end date
 * the vote can be sent again: it replaces the previous one. The page shows
 * only how many people are registered and how many voted; after the end date
 * the anonymous results (Borda count) with the trait values and the selection
 * index of the candidates. Data: /ajax/decision_vote/public/*.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

import { participationChart, mostVotedChart } from '../modules/decision_vote_charts.js';

let $;
// list: the candidates in a fixed order (they never move); place: accession => place given (1 = best)
const S = { token: '', kind: '', data: null, list: [], place: {}, comments: {} };

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function fmt(v) {
    if (v === null || v === undefined || v === '' || isNaN(Number(v))) return '';
    const x = Number(v);
    const a = Math.abs(x);
    return a >= 1000 ? x.toFixed(0) : a >= 100 ? x.toFixed(1) : a >= 1 ? x.toFixed(2) : x.toPrecision(3);
}
function call(type, url, data) {
    return new Promise((resolve, reject) => {
        $.ajax({ url: url, type: type, data: data, dataType: 'json', cache: false })
            .done(r => { if (r && r.error) { const e = new Error(r.error); e.data = r; reject(e); } else resolve(r); })
            .fail((x, st, err) => reject(new Error('Server error: ' + (err || st) + '. Please try again.')));
    });
}
function alertHtml(type, msg) { return '<div class="alert alert-' + type + '">' + msg + '</div>'; }
function app() { return $('#dv_app'); }

function load() {
    return call('GET', '/ajax/decision_vote/public/info', { token: S.token })
        .then(r => { S.data = r; render(); })
        .catch(e => app().html(alertHtml('danger', esc(e.message))));
}

const STATE = {
    upcoming: '<span class="label label-info">not started</span>',
    open: '<span class="label label-success">voting open</span>',
    closed: '<span class="label label-default">closed</span>',
};

function header(v) {
    let h = '<div class="dv-box"><h3 style="margin-top:0">' + esc(v.name) + ' ' + STATE[v.state] + '</h3>';
    if (v.meeting_name) h += '<div class="dv-muted">Decision meeting: ' + esc(v.meeting_name) + '</div>';
    if (v.description) h += '<p style="white-space:pre-wrap; margin-top:6px">' + esc(v.description) + '</p>';
    h += '<p><span class="glyphicon glyphicon-calendar"></span> Voting from <b>' + esc(v.start_date) + '</b> to <b>' + esc(v.end_date) + '</b>' +
        ' <span class="dv-muted">(today is ' + esc(v.today) + ')</span></p>';
    h += progressHtml(v.progress) + '</div>';
    return h;
}

function progressHtml(p) {
    let h = '<div>' +
        '<span class="dv-progress-num"><b>' + p.registered + '</b>registered</span>' +
        '<span class="dv-progress-num"><b>' + p.voted + '</b>votes done</span>' +
        '<span class="dv-progress-num"><b>' + p.missing + '</b>votes missing</span>' +
        '</div>';
    h += participationChart(p);
    return h;
}

function render() {
    const r = S.data;
    const v = r.vote;
    let h = header(v);
    h += ballotHtml(v, r.voter);
    if (v.state === 'closed') h += resultsHtml(v, r.voter);
    else h += '<div class="dv-box"><button class="btn btn-default" disabled title="Available after ' + esc(v.end_date) + '"><span class="glyphicon glyphicon-lock"></span> Show results</button> ' +
        '<span class="dv-muted">The results are shown here after the end of the vote (' + esc(v.end_date) + '), anonymous.</span></div>';
    app().html(h);
    if (v.state === 'open') renderOrder();
}

// ---------------------------------------------------------------- the varieties of the vote

function chips(list) { return list.map(a => '<span class="label label-default" style="display:inline-block; margin:2px">' + esc(a) + '</span>').join(' '); }

// the two groups of accessions, said plainly
function groupsHtml(v) {
    let h = '<p><b>' + v.accessions.length + ' candidate varieties to vote</b><br/>' + chips(v.accessions) + '</p>';
    // a long list of the other varieties stays folded
    if ((v.note_accessions || []).length) h += '<details><summary style="cursor:pointer"><b>' + v.note_accessions.length + ' other varieties</b>, only for notes (not voted) &mdash; show</summary>' +
        '<div style="margin-top:6px">' + chips(v.note_accessions) + '</div></details>';
    return h;
}

// ---------------------------------------------------------------- ballot

function ballotHtml(v, w) {
    let h = '<div class="dv-box"><h4 style="margin-top:0">Hello, ' + esc(w.name) + '</h4>';
    if (w.voted) h += '<p><span class="glyphicon glyphicon-ok text-success"></span> You voted on ' + esc(w.voted) + '.' + (v.state === 'open' ? ' You can change your vote until ' + esc(v.end_date) + '.' : '') + '</p>';
    if (v.state === 'upcoming') {
        h += '<p>The vote opens on <b>' + esc(v.start_date) + '</b>. Come back to this page (keep the link) to vote.</p>' +
            groupsHtml(v) + '</div>';
        return h;
    }
    if (v.state === 'closed') {
        h += w.voted ? '' : '<p>You did not vote.</p>';
        const ranked = (w.ballot || []).filter(b => b.rank);
        const others = (w.ballot || []).filter(b => !b.rank && b.comment);
        if (ranked.length) {
            h += '<p><b>Your vote:</b></p><ol>' + ranked.map(b => '<li>' + esc(b.accession) + (b.comment ? ' <span class="dv-muted">&mdash; your notes: ' + esc(b.comment) + '</span>' : '') + '</li>').join('') + '</ol>';
        }
        if (others.length) {
            h += '<p><b>Your notes on the other varieties:</b></p><ul>' + others.map(b => '<li>' + esc(b.accession) + ' <span class="dv-muted">&mdash; ' + esc(b.comment) + '</span></li>').join('') + '</ul>';
        }
        return h + '</div>';
    }
    // open: the candidates in alphabetical order, always the same (no variety is favoured
    // by the list order, and nothing moves while voting); the places of a vote already sent
    S.list = v.accessions.slice().sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    if (!Object.keys(S.place).length && (w.ballot || []).length) {
        S.comments = {};
        w.ballot.forEach(b => { if (b.rank) S.place[b.accession] = b.rank; if (b.comment) S.comments[b.accession] = b.comment; });
    }
    const others = v.note_accessions || [];
    h += '<div class="alert alert-info" style="margin-bottom:12px"><ol style="margin:0; padding-left:20px">' +
        '<li><b>Vote:</b> choose a place for each of the ' + v.accessions.length + ' candidate varieties, <b>1 = the best</b>. Each variety gets a different place.</li>' +
        '<li><b>Notes</b> (optional): write what you think of any variety' + (others.length ? ', also of the ' + others.length + ' other varieties (they are not voted on)' : '') + '.</li>' +
        '<li>Click <b>Send my vote</b>. You can change it until ' + esc(v.end_date) + '.</li></ol></div>' +
        (others.length ? '<h4>1. Candidate varieties: to vote (' + v.accessions.length + ')</h4>' : '') +
        '<div id="dv_order"></div><p id="dv_places_status" style="margin:-2px 0 8px 0"></p>' +
        (others.length ? othersHtml(others) : '') +
        '<div class="form-group"><label>General notes on the vote <span class="dv-muted">(not required; also shown without your name)</span></label><textarea class="form-control" id="dv_general" rows="2" maxlength="2000">' + esc(w.general_comment || '') + '</textarea></div>' +
        '<div id="dv_vote_msg"></div>' +
        '<button class="btn btn-success btn-lg" id="dv_vote_btn"><span class="glyphicon glyphicon-check"></span> ' + (w.voted ? 'Change my vote' : 'Send my vote') + '</button></div>';
    return h;
}

// part 2: the varieties only for notes, folded (open when there are notes), one compact line each, with a search
function othersHtml(others) {
    const withNotes = others.filter(a => (S.comments[a] || '').trim()).length;
    const open = withNotes > 0 || others.length <= 5;
    return '<h4 style="margin-top:18px">2. Other varieties: only for notes, not voted (' + others.length + ')</h4>' +
        '<p class="dv-muted" style="margin-bottom:6px">Not required. Write a note only on the varieties you want to comment on.' +
        (withNotes ? ' You wrote notes on ' + withNotes + '.' : '') + '</p>' +
        '<button type="button" class="btn btn-default btn-sm" id="dv_others_toggle"' + (open ? ' style="display:none"' : '') + '>' +
        '<span class="glyphicon glyphicon-pencil"></span> Write notes on the ' + others.length + ' other varieties (optional)</button>' +
        '<div id="dv_others"' + (open ? '' : ' style="display:none"') + '>' +
        (others.length > 10 ? '<input type="search" class="form-control input-sm" id="dv_others_filter" placeholder="Find a variety..." style="margin:0 0 6px 0; max-width:320px"/>' : '') +
        '<div style="max-height:420px; overflow-y:auto; border:1px solid #e5e7eb; border-radius:6px">' +
        others.map(a => '<div class="dv-note-row" data-name="' + esc(a.toLowerCase()) + '" style="display:flex; align-items:center; gap:8px; padding:4px 8px; border-bottom:1px solid #f1f3f5">' +
            '<div style="flex:0 0 38%; font-weight:600; word-break:break-word">' + esc(a) + '</div>' +
            '<input type="text" class="form-control input-sm dv-comment" maxlength="2000" placeholder="Note (optional)" data-acc="' + esc(a) + '" value="' + esc(S.comments[a] || '') + '"/></div>').join('') +
        '</div></div>';
}

// accessions that share a place with another one
function duplicatedPlaces() {
    const by = {};
    S.list.forEach(a => { const p = S.place[a]; if (p) (by[p] = by[p] || []).push(a); });
    const dup = {};
    Object.keys(by).forEach(p => { if (by[p].length > 1) by[p].forEach(a => { dup[a] = p; }); });
    return dup;
}

function renderOrder() {
    const n = S.list.length;
    $('#dv_order').html(S.list.map(a => {
        const p = S.place[a] || '';
        return '<div class="dv-item" data-acc="' + esc(a) + '">' +
            '<div class="dv-main"><div class="dv-name">' + esc(a) + '</div>' +
            '<div class="dv-field"><label>Place</label> <select class="form-control input-sm dv-place" data-acc="' + esc(a) + '" style="display:inline-block; width:auto">' +
            '<option value="">Choose...</option>' +
            Array.from({ length: n }, (x, j) => j + 1).map(k => '<option value="' + k + '"' + (Number(p) === k ? ' selected' : '') + '>' + k +
                (k === 1 ? ' (best)' : k === n ? ' (last)' : '') + '</option>').join('') + '</select>' +
            ' <span class="dv-place-msg text-warning"></span></div>' +
            '<div class="dv-field"><label>Notes <span class="dv-muted">(not required)</span></label>' +
            '<textarea class="form-control dv-comment" rows="2" maxlength="2000" placeholder="What do you think of this variety?" data-acc="' + esc(a) + '">' + esc(S.comments[a] || '') + '</textarea></div></div></div>';
    }).join(''));
    checkPlaces();
}

// marks the varieties that share a place (nothing moves) and counts the ones without a place
function checkPlaces() {
    const dup = duplicatedPlaces();
    $('#dv_order .dv-item').each(function() {
        const a = $(this).attr('data-acc');
        const d = dup[a];
        $(this).toggleClass('dv-dup', !!d).find('.dv-place-msg').text(d ? 'Place ' + d + ' is given to more than one variety' : '');
    });
    const missing = S.list.filter(a => !S.place[a]).length;
    const nDup = Object.keys(dup).length;
    $('#dv_places_status').html(missing || nDup ? '<span class="text-warning">' +
        (missing ? missing + ' variet' + (missing === 1 ? 'y has' : 'ies have') + ' no place yet. ' : '') +
        (nDup ? 'Some places are repeated: each variety needs a different place.' : '') + '</span>'
        : '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> Every variety has a different place.</span>');
}

function vote() {
    $('#dv_vote_msg').empty();
    const missing = S.list.filter(a => !S.place[a]);
    if (missing.length || Object.keys(duplicatedPlaces()).length) {
        checkPlaces();
        $('#dv_vote_msg').html(alertHtml('warning', 'Please give each candidate variety a different place (1 = the best)' +
            (missing.length ? '. Without a place: ' + esc(missing.join(', ')) : '') + '.'));
        return;
    }
    // the order sent: by the places given
    const order = S.list.slice().sort((a, b) => S.place[a] - S.place[b]);
    $('#dv_vote_btn').prop('disabled', true);
    const comments = {};
    Object.keys(S.comments).forEach(a => { if ((S.comments[a] || '').trim()) comments[a] = S.comments[a]; });
    call('POST', '/ajax/decision_vote/public/ballot', { token: S.token, order: JSON.stringify(order), comments: JSON.stringify(comments), general_comment: $('#dv_general').val() })
        .then(r => {
            S.data.vote.progress = r.progress;
            const w = S.data.voter;
            // notes that still had disrespectful words after the last try: not saved
            const removed = r.notes_removed || [];
            removed.forEach(a => { if (a === 'general') $('#dv_general').val(''); else { delete comments[a]; delete S.comments[a]; } });
            w.ballot = order.map((a, i) => ({ accession: a, rank: i + 1, comment: comments[a] || null }))
                .concat((S.data.vote.note_accessions || []).filter(a => comments[a]).map(a => ({ accession: a, rank: null, comment: comments[a] })));
            w.general_comment = $('#dv_general').val();
            w.voted = 'today';
            render();
            app().find('.dv-box').eq(1).prepend(alertHtml('success', '<span class="glyphicon glyphicon-ok"></span> ' + (r.changed ? 'Your vote was changed.' : 'Thank you! Your vote was recorded.') +
                ' The results will be shown on this page after ' + esc(S.data.vote.end_date) + '.' +
                (removed.length ? '<br/><span class="glyphicon glyphicon-info-sign"></span> Your ' + removed.map(a => a === 'general' ? 'general notes' : 'notes on ' + esc(a)).join(', ') +
                    ' were not saved, because some words were not changed. The rest of your vote was saved.' : '')));
            window.scrollTo(0, 0);
        })
        .catch(e => {
            const blocked = (e.data && e.data.blocked) || [];
            $('#dv_app .dv-comment, #dv_general').closest('.dv-field, .form-group, .dv-note-row').removeClass('has-warning');
            blocked.forEach(b => {
                const el = b.field === 'general' ? $('#dv_general') : $('#dv_app .dv-comment').filter(function() { return 'note:' + $(this).attr('data-acc') === b.field; });
                el.closest('.dv-field, .form-group, .dv-note-row').addClass('has-warning');
                // a note of a folded variety: unfold it so the voter sees it
                if (el.closest('#dv_others').length) { $('#dv_others_toggle').hide(); $('#dv_others').show(); $('#dv_others_filter').val('').trigger('input'); }
            });
            $('#dv_vote_msg').html(alertHtml(blocked.length ? 'warning' : 'danger', esc(e.message)));
            $('#dv_vote_btn').prop('disabled', false);
        });
}

// ---------------------------------------------------------------- results

function resultsHtml(v, w) {
    const res = v.results;
    if (!res) return '';
    const ev = v.evidence;
    const traits = ev ? (ev.traits || []) : [];
    const mine = {};
    ((w && w.ballot) || []).forEach(b => { mine[b.accession] = b.rank; });
    let h = '<div class="dv-box"><h4 style="margin-top:0"><span class="glyphicon glyphicon-stats"></span> Results</h4>';
    if (!v.progress.voted) return h + '<p>Nobody voted.</p></div>';
    h += '<p class="dv-muted">' + v.progress.voted + ' vote(s). Each vote gives ' + res.max_points + ' points to the variety in place 1, ' +
        (res.max_points - 1) + ' to the one in place 2 (' + res.max_points + ' candidates), and so on down to 1 point for the last one.</p>';
    h += mostVotedChart(res.candidates, { title: 'Most voted varieties' });
    h += '<div class="table-responsive"><table class="table table-bordered table-condensed"><thead><tr><th>Place</th><th>Variety</th><th>Points</th><th>Votes for place 1</th><th>Average place</th>' +
        (w ? '<th>Your place</th>' : '') + '</tr></thead><tbody>';
    h += res.candidates.map(x => '<tr' + (x.place === 1 ? ' class="dv-first"' : '') + '><td><b>' + x.place + '</b></td><td>' + esc(x.accession) + '</td><td>' + x.points + '</td>' +
        '<td>' + x.first + '</td><td>' + (x.mean_rank === null || x.mean_rank === undefined ? '' : x.mean_rank) + '</td>' +
        (w ? '<td>' + (mine[x.accession] || '') + '</td>' : '') + '</tr>').join('');
    h += '</tbody></table></div>';
    if (ev) {
        h += '<h4>Field results of the varieties</h4><p class="dv-muted">From the analysis' + (ev.analysis_name ? ' <b>' + esc(ev.analysis_name) + '</b>' : '') +
            ': ' + esc(ev.value_label || 'genetic value') + ' of each trait (rank among all the accessions of the analysis in brackets; 1 = best)' +
            (ev.index ? ' and the selection index' : '') + '.</p>';
        h += '<div class="table-responsive"><table class="table table-striped table-bordered table-condensed"><thead><tr><th>Place in the vote</th><th>Variety</th>' +
            traits.map(t => '<th>' + esc(t.trait) + (t.direction === 'decrease' ? ' <span class="dv-muted" title="lower is better">&darr;</span>' : t.direction === 'increase' ? ' <span class="dv-muted" title="higher is better">&uarr;</span>' : '') + '</th>').join('') +
            (ev.index ? '<th>Selection index</th><th>Index rank</th>' : '') + '</tr></thead><tbody>';
        h += res.candidates.map(x => {
            const e = x.evidence || {};
            return '<tr><td>' + x.place + '</td><td>' + esc(x.accession) + '</td>' +
                traits.map(t => { const val = (e.values || {})[t.trait]; const rk = (e.ranks || {})[t.trait]; return '<td>' + fmt(val) + (rk ? ' <span class="dv-muted">(' + rk + ')</span>' : '') + '</td>'; }).join('') +
                (ev.index ? '<td>' + fmt(e.index) + '</td><td>' + (e.index_rank || '') + '</td>' : '') + '</tr>';
        }).join('');
        h += '</tbody></table></div>';
    }
    const withComments = res.candidates.filter(x => (x.comments || []).length);
    const otherNotes = res.other_notes || [];
    if (withComments.length || otherNotes.length || (res.general_comments || []).length) {
        h += '<h4>Notes from the voters</h4><p class="dv-muted">All the notes together, without the names of the people who wrote them.</p>';
        h += withComments.map(x => '<p style="margin-bottom:2px"><b>' + esc(x.accession) + '</b> <span class="dv-muted">(' + x.comments.length + ' note' + (x.comments.length === 1 ? '' : 's') + ')</span></p>' +
            x.comments.map(cm => '<div class="dv-quote">' + esc(cm) + '</div>').join('')).join('');
        if (otherNotes.length) {
            h += '<p style="margin:10px 0 2px 0"><b>Other varieties (only for notes, not voted)</b></p>' +
                otherNotes.map(x => '<p style="margin-bottom:2px">' + esc(x.accession) + ' <span class="dv-muted">(' + x.comments.length + ' note' + (x.comments.length === 1 ? '' : 's') + ')</span></p>' +
                    x.comments.map(cm => '<div class="dv-quote">' + esc(cm) + '</div>').join('')).join('');
        }
        if ((res.general_comments || []).length) h += '<p style="margin:8px 0 2px 0"><b>General notes on the vote</b></p>' + res.general_comments.map(cm => '<div class="dv-quote">' + esc(cm) + '</div>').join('');
    }
    return h + '</div>';
}

export function init() {
    $ = window.jQuery;
    S.token = app().data('token') || '';
    S.kind = app().data('kind') || '';
    if (!S.token) { app().html(alertHtml('danger', 'This link is not valid. Please check it with the organizer of the vote.')); return; }
    app().on('change', '.dv-place', function() {
        const a = $(this).attr('data-acc');
        if ($(this).val()) S.place[a] = Number($(this).val()); else delete S.place[a];
        checkPlaces();
    });
    app().on('input', '.dv-comment', function() { S.comments[$(this).attr('data-acc')] = $(this).val(); });
    app().on('click', '#dv_vote_btn', vote);
    app().on('click', '#dv_others_toggle', function() { $(this).hide(); $('#dv_others').show(); $('#dv_others_filter').trigger('focus'); });
    app().on('input', '#dv_others_filter', function() {
        const q = ($(this).val() || '').trim().toLowerCase();
        $('#dv_others .dv-note-row').each(function() { $(this).toggle(!q || $(this).attr('data-name').indexOf(q) >= 0); });
    });
    load();
}
