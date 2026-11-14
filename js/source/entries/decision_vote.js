/*
 * Variety vote of a decision meeting - meeting page (/breeders/meeting)
 *
 * The votes of the meeting selected in the Meeting Tracker. A vote has
 * candidate accessions (by default those selected by the index of an
 * analysis linked to the meeting) and accessions only for notes, and start
 * and end dates. Invited people (Breedbase users or name and e-mail) are
 * registered automatically and receive their voting link by e-mail; others
 * can register with the public link. The vote is anonymous: the meeting page
 * shows the invitations (sent or not) and only the totals of registered
 * people and votes; the results are shown after the end of the vote.
 * Endpoints: /ajax/decision_vote/*.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

import { participationChart, mostVotedChart } from '../modules/decision_vote_charts.js';

let $;
const S = { showResults: false, picked: {}, meeting: null, votes: [], analyses: null, current: null, detail: null, editing: null, candidates: [], seq: 0 };

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
            .done(r => (r && r.error ? reject(new Error(r.error)) : resolve(r)))
            .fail((x, st, err) => reject(new Error('Server error: ' + (err || st))));
    });
}
function alertHtml(type, msg) { return '<div class="alert alert-' + type + '" style="margin:6px 0">' + msg + '</div>'; }
const STATE = {
    upcoming: '<span class="label label-info">not started</span>',
    open: '<span class="label label-success">voting open</span>',
    closed: '<span class="label label-default">closed</span>',
};

function selectedMeeting() {
    if (typeof window.getSelectedDecisionMeeting === 'function') return window.getSelectedDecisionMeeting();
    const c = $('.dm-meeting-check:checked').first();
    return c.length ? { meeting_id: c.data('meeting-id'), meeting_name: c.data('meeting-name') } : null;
}

function onMeetingChange() {
    const m = selectedMeeting();
    const id = m && m.meeting_id ? String(m.meeting_id) : null;
    if (id === (S.meeting && String(S.meeting.meeting_id))) return;
    S.meeting = m;
    S.current = null;
    S.analyses = null;
    $('#dvm_new, #dvm_detail').hide();
    if (!id) {
        $('#dvm_body').hide();
        $('#dvm_status').show().html('Select a meeting in the Meeting Tracker to see its variety votes.');
        return;
    }
    loadVotes();
}

function loadVotes() {
    const seq = ++S.seq;
    $('#dvm_status').show().html('<span class="glyphicon glyphicon-refresh"></span> Loading the votes of the meeting...');
    return call('GET', '/ajax/decision_vote/list', { meeting_id: S.meeting.meeting_id })
        .then(r => {
            if (seq !== S.seq) return;
            S.votes = r.votes || [];
            $('#dvm_status').hide();
            $('#dvm_body').show();
            renderVotes();
            // the selected vote, or the most recent one: its invitations are seen right away
            if (S.current && S.votes.some(v => v.vote_id === S.current)) return showDetail(S.current);
            if (S.votes.length) return showDetail(S.votes[0].vote_id);
            S.current = null;
            $('#dvm_detail').hide();
            return null;
        })
        .catch(e => { if (seq === S.seq) { $('#dvm_body').hide(); $('#dvm_status').show().html(alertHtml('warning', esc(e.message))); } });
}

function progressText(p) {
    return '<b>' + p.registered + '</b> ' + (p.registered === 1 ? 'person' : 'people') + ' registered to vote &middot; <b>' + p.voted + '</b> completed vote' + (p.voted === 1 ? '' : 's') +
        (p.invited_not_registered ? ' &middot; ' + p.invited_not_registered + ' invitation' + (p.invited_not_registered === 1 ? '' : 's') + ' not sent yet' : '');
}

function renderVotes() {
    let h = S.votes.length ? '' : '<p class="dvm-muted">No vote for this meeting yet. Use <b>New vote</b> to open one.</p>';
    h += S.votes.map(v => '<div class="dvm-card' + (S.current === v.vote_id ? ' on' : '') + '" data-id="' + v.vote_id + '">' +
        '<div class="dvm-card-title">' + esc(v.name) + ' ' + STATE[v.state] + '</div>' +
        '<div class="dvm-meta">' + esc(v.start_date) + ' to ' + esc(v.end_date) + ' &middot; ' + v.accessions.length + ' candidate' + (v.accessions.length === 1 ? '' : 's') + ' to vote' + ((v.note_accessions || []).length ? ', ' + v.note_accessions.length + ' only for notes' : '') +
        (v.evidence ? ' &middot; analysis ' + esc(v.evidence.analysis_name || '') : '') + '<br/>opened by ' + esc(v.created_by) + ' on ' + esc(v.created) + '</div>' +
        '<div style="margin:4px 0">' + progressText(v.progress) + '</div>' +
        (v.invitations && v.invitations.invited ? '<div class="dvm-meta"><span class="glyphicon glyphicon-envelope"></span> ' + v.invitations.invited + ' invited' +
            (v.invitations.not_sent ? ' &middot; <span class="text-warning"><b>' + v.invitations.not_sent + ' not sent yet</b></span>' : ' &middot; all invitations sent') + '</div>' : '') +
        '<button class="btn btn-default btn-xs dvm-edit" data-id="' + v.vote_id + '"><span class="glyphicon glyphicon-pencil"></span> Edit</button> ' +
        '<button class="btn btn-default btn-xs dvm-delete" data-id="' + v.vote_id + '"><span class="glyphicon glyphicon-trash"></span> Delete</button>' +
        '</div>').join('');
    $('#dvm_votes').html(h);
}

// ---------------------------------------------------------------- detail

function showDetail(id) {
    S.current = id;
    $('.dvm-card').removeClass('on').filter('[data-id="' + id + '"]').addClass('on');
    $('#dvm_detail').show().html('<span class="glyphicon glyphicon-refresh"></span> Loading the vote...');
    return call('GET', '/ajax/decision_vote/detail', { vote_id: id })
        .then(r => { if (S.current === id) { S.detail = r.vote; renderDetail(); } })
        .catch(e => { if (S.current === id) $('#dvm_detail').html(alertHtml('danger', esc(e.message))); });
}

function renderDetail() {
    const v = S.detail;
    const p = v.progress;
    let h = '<div class="dvm-panel"><h4 style="margin-top:0">' + esc(v.name) + ' ' + STATE[v.state] + '</h4>';
    if (v.description) h += '<p style="white-space:pre-wrap">' + esc(v.description) + '</p>';
    h += '<p class="dvm-muted"><span class="glyphicon glyphicon-lock"></span> Only the people you invite can vote: each one receives a personal voting link by e-mail.</p>';
    h += '<p>' + progressText(p) + '</p>' + participationChart(p);

    // invitations by e-mail
    const inv = v.invites || [];
    if (v.state !== 'closed') {
        h += '<div class="dvm-panel" style="background:#fff"><h4 style="margin-top:0"><span class="glyphicon glyphicon-envelope"></span> Invite more people</h4>' +
            '<div class="row"><div class="col-sm-6 form-group"><label>Breedbase users</label><div class="dvm-users" data-key="detail"></div>' +
            '<span class="help-block">They receive their voting link directly by e-mail.</span></div>' +
            '<div class="col-sm-6 form-group"><label>People without a Breedbase account <span class="dvm-muted">(one per line: <code>Name, e-mail</code>)</span></label>' +
            '<textarea class="form-control input-sm" id="dvm_invite_emails" rows="4" placeholder="Maria Silva, maria.silva@gmail.com&#10;Joao Souza, joao@farm.com.br"></textarea>' +
            '<span class="help-block">They receive their voting link by e-mail.</span></div></div>' +
            '<div class="form-group"><label>Message <span class="dvm-muted">(optional, added to the e-mail)</span></label>' +
            '<textarea class="form-control input-sm" id="dvm_invite_message" rows="2" maxlength="2000"></textarea></div>' +
            '<div class="dvm-total" data-key="detail" style="margin:0 0 6px 0"></div>' +
            '<button class="btn btn-success btn-sm dvm-invite-go" data-send="1"><span class="glyphicon glyphicon-send"></span> Send invitations now</button> ' +
            '<button class="btn btn-primary btn-sm dvm-invite-go" data-send="0"><span class="glyphicon glyphicon-floppy-disk"></span> Save to send later</button> ' +
            '<span id="dvm_invite_status" style="margin-left:8px"></span></div>';
    }
    if (inv.length) {
        const pending = inv.filter(x => !x.sent).length;
        h += '<h4>Invitations (' + inv.length + ') <small>' + (inv.length - pending) + ' sent' + (pending ? ', <span class="text-warning">' + pending + ' not sent yet</span>' : '') + '</small></h4>' +
            (pending && v.state !== 'closed' ? '<p><button class="btn btn-primary btn-sm" id="dvm_send_pending"><span class="glyphicon glyphicon-send"></span> Send the ' + pending +
                ' invitation' + (pending === 1 ? '' : 's') + ' not sent yet</button> <span id="dvm_pending_status" style="margin-left:8px"></span></p>' : '') +
            '<div class="table-responsive" style="max-height:320px; overflow-y:auto"><table class="table table-condensed table-bordered table-striped"><thead><tr>' +
            '<th>Name</th><th>E-mail</th><th>Account</th><th>Invitation</th>' + (v.state !== 'closed' ? '<th></th>' : '') + '</tr></thead><tbody>' +
            inv.map(x => '<tr' + (x.sent ? '' : ' class="warning"') + '><td>' + esc(x.name || '') + '</td><td>' + esc(x.email) + '</td>' +
                '<td>' + (x.breedbase_user ? 'Breedbase user' : '<span class="dvm-muted">no account</span>') + '</td>' +
                '<td>' + (x.sent ? '<span class="glyphicon glyphicon-envelope"></span> sent ' + esc(x.sent) + (x.times_sent > 1 ? ' (' + x.times_sent + ' times)' : '') : '<b>not sent yet</b>') + '</td>' +
                (v.state !== 'closed' && x.sent ? '<td><button class="btn btn-default btn-xs dvm-resend" data-invite="' + x.invite_id + '" title="E-mail the voting link to this person again (if it was lost)">' +
                    '<span class="glyphicon glyphicon-envelope"></span> Resend</button></td>' : (v.state !== 'closed' ? '<td></td>' : '')) + '</tr>').join('') +
            '</tbody></table></div>' +
            '<p class="dvm-muted" style="font-size:12px">The vote is anonymous: nobody sees who registered or who voted, only the totals above.</p>';
    }

    // results
    const res = v.results;
    h += '<h4>Results</h4>';
    if (v.state !== 'closed') {
        // displayed, but locked until the end of the vote
        h += '<p><button class="btn btn-default btn-sm" disabled title="Available after ' + esc(v.end_date) + '"><span class="glyphicon glyphicon-lock"></span> Show results</button> ' +
            '<span class="dvm-muted">Locked until the end of the vote (' + esc(v.end_date) + '). Then everyone sees the results, anonymous.</span></p>';
    } else if (!p.voted) {
        h += '<p><button class="btn btn-default btn-sm" disabled><span class="glyphicon glyphicon-stats"></span> Show results</button> <span class="dvm-muted">Nobody voted.</span></p>';
    } else {
        h += '<p><button class="btn btn-success btn-sm" id="dvm_show_results"><span class="glyphicon glyphicon-stats"></span> ' + (S.showResults ? 'Hide results' : 'Show results') + '</button></p>' +
            '<div id="dvm_results_box"' + (S.showResults ? '' : ' style="display:none"') + '>';
        const ev = v.evidence;
        const traits = ev ? (ev.traits || []) : [];
        const rows = (ev && ev.rows) || {};
        h += '<p class="dvm-muted">Borda count: with ' + res.max_points + ' candidates to vote, place 1 gets ' + res.max_points + ' points and the last place 1 point.' +
            (ev ? ' Trait values: ' + esc(ev.value_label || '') + ' of the analysis ' + esc(ev.analysis_name || '') + ' (rank among its accessions in brackets).' : '') + '</p>';
        h += mostVotedChart(res.candidates, { title: 'Most voted' + (v.state !== 'closed' ? ' so far' : '') });
        h += '<div class="table-responsive"><table id="dvm_results" class="table table-condensed table-bordered"><thead><tr><th>Place</th><th>Accession</th><th>Points</th><th>1st places</th><th>Average place</th>' +
            traits.map(t => '<th>' + esc(t.trait) + '</th>').join('') + (ev && ev.index ? '<th>Index</th><th>Index rank</th>' : '') + '</tr></thead><tbody>' +
            res.candidates.map(x => {
                const e = rows[x.accession] || {};
                return '<tr' + (x.place === 1 ? ' class="success"' : '') + '><td><b>' + x.place + '</b></td><td>' + (x.stock_id ? '<a target="_blank" href="/stock/' + x.stock_id + '/view">' + esc(x.accession) + '</a>' : esc(x.accession)) + '</td>' +
                    '<td>' + x.points + '</td><td>' + x.first + '</td><td>' + (x.mean_rank === null ? '' : x.mean_rank) + '</td>' +
                    traits.map(t => '<td>' + fmt((e.values || {})[t.trait]) + ((e.ranks || {})[t.trait] ? ' <span class="dvm-muted">(' + e.ranks[t.trait] + ')</span>' : '') + '</td>').join('') +
                    (ev && ev.index ? '<td>' + fmt(e.index) + '</td><td>' + (e.index_rank || '') + '</td>' : '') + '</tr>';
            }).join('') + '</tbody></table></div>';
        h += '<button class="btn btn-default btn-xs" id="dvm_csv"><span class="glyphicon glyphicon-download-alt"></span> Results CSV</button>';
        const cm = res.candidates.filter(x => (x.comments || []).length);
        const on = res.other_notes || [];
        if (cm.length || on.length || (res.general_comments || []).length) {
            h += '<h4>Notes from the voters <small>(anonymous)</small></h4>' + cm.map(x => '<p style="margin-bottom:2px"><b>' + esc(x.accession) + '</b> <span class="dvm-muted">(' + x.comments.length + ')</span></p><ul>' + x.comments.map(t => '<li>' + esc(t) + '</li>').join('') + '</ul>').join('');
            if (on.length) h += '<p style="margin-bottom:2px"><b>Accessions only for notes</b></p>' + on.map(x => '<p style="margin-bottom:2px">' + esc(x.accession) + ' <span class="dvm-muted">(' + x.comments.length + ')</span></p><ul>' + x.comments.map(t => '<li>' + esc(t) + '</li>').join('') + '</ul>').join('');
            if ((res.general_comments || []).length) h += '<p style="margin-bottom:2px"><b>General notes on the vote</b></p><ul>' + res.general_comments.map(t => '<li>' + esc(t) + '</li>').join('') + '</ul>';
        }
        h += '</div>';
    }
    h += '</div>';
    $('#dvm_detail').html(h);
    S.picked.detail = {};
    renderPickers();
}

// "Name, e-mail" per line (also "Name <e-mail>", tab separated columns of a
// spreadsheet, or only the e-mail; a line with several e-mails gives several
// people without names). Returns {people: [{name, email}], bad: [lines]}
const EMAIL_RE = /[^\s@,;<>()"']+@[^\s@,;<>()"']+\.[A-Za-z]{2,}/g;
function parsePeople(text) {
    const people = [];
    const bad = [];
    const seen = {};
    (text || '').split(/\r?\n/).map(l => l.trim()).filter(l => l).forEach(line => {
        const emails = line.match(EMAIL_RE) || [];
        if (!emails.length) { bad.push(line); return; }
        const name = emails.length === 1 ? line.replace(emails[0], ' ').replace(/[<>()"';,\t]+/g, ' ').replace(/\s+/g, ' ').trim() : '';
        emails.forEach(e => {
            if (seen[e.toLowerCase()]) return;
            seen[e.toLowerCase()] = true;
            people.push({ name: name, email: e });
        });
    });
    return { people: people, bad: bad };
}

function peopleCountText(text) {
    const p = parsePeople(text);
    if (!p.people.length && !p.bad.length) return '';
    return '<b>' + p.people.length + '</b> ' + (p.people.length === 1 ? 'person' : 'people') + ' to invite' +
        (p.people.filter(x => !x.name).length ? ' (' + p.people.filter(x => !x.name).length + ' without a name)' : '') +
        (p.bad.length ? ' &middot; <span class="text-danger">' + p.bad.length + ' line' + (p.bad.length === 1 ? '' : 's') + ' without an e-mail: ' + esc(p.bad.slice(0, 3).join(' | ')) + (p.bad.length > 3 ? ' ...' : '') + '</span>' : '');
}

// sends invitations in batches (the web server stops long requests); reports in $status.
// Resolves to {sent, invalid, recent, limit} (lists of e-mails)
function invitePeople(voteId, people, message, $status, send) {
    const out = { sent: [], saved: [], invalid: [], recent: [], limit: [] };
    let i = 0;
    const next = () => {
        if (i >= people.length) return Promise.resolve(out);
        const batch = people.slice(i, i + 5);
        $status.html('<span class="glyphicon glyphicon-refresh"></span> ' + (send ? 'Sending invitations: ' : 'Saving the list: ') + Math.min(i + batch.length, people.length) + ' of ' + people.length + '...');
        return call('POST', '/ajax/decision_vote/invite', { vote_id: voteId, people: JSON.stringify(batch), message: message || '', send: send ? 1 : 0 })
            .then(r => { (r.results || []).forEach(x => (out[x.status] || out.invalid).push(x.email)); i += batch.length; return next(); });
    };
    return next().catch(e => { e.sent = out.sent; throw e; });
}

function inviteSummary(out) {
    let msg = out.saved.length ? '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> ' + out.saved.length + (out.saved.length === 1 ? ' person' : ' people') +
            ' without an account added to the list (not sent yet).</span>'
        : '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> ' + out.sent.length + ' invitation' + (out.sent.length === 1 ? '' : 's') + ' sent.</span>';
    if (out.invalid.length) msg += '<br/><span class="text-danger">Not valid (not sent): ' + esc(out.invalid.join(', ')) + '</span>';
    if (out.recent.length) msg += '<br/><span class="text-warning"><b>Not sent again</b>: invited less than 2 minutes ago (to avoid sending twice by mistake): ' + esc(out.recent.join(', ')) + '. Wait 2 minutes to send to them again.</span>';
    if (out.limit.length) msg += '<br/><span class="text-danger">Limit of invitations reached (not sent): ' + esc(out.limit.join(', ')) + '</span>';
    return msg;
}

// ---------------------------------------------------------------- Breedbase users

// picked users of each picker (key: new = form, detail = vote detail): {sp_person_id: {name, username}}
function renderPickers() {
    $('.dvm-users').each(function() {
        const key = $(this).data('key');
        const picked = S.picked[key] || {};
        const ids = Object.keys(picked);
        $(this).html((ids.length ? '<div style="margin-bottom:4px">' + ids.map(id => '<span class="dvm-chip">' + esc(picked[id].name) +
            ' <button type="button" class="dvm-unpick" data-id="' + id + '" title="Remove">&times;</button></span>').join('') + '</div>' : '') +
            '<input type="text" class="form-control input-sm dvm-user-q" placeholder="Type a name to search users..." autocomplete="off"/>' +
            '<div class="dvm-found" style="display:none"></div>');
    });
    updateTotals();
}

let userTimer = null;
function searchUsers(input) {
    clearTimeout(userTimer);
    const $box = $(input).closest('.dvm-users');
    const q = ($(input).val() || '').trim();
    const $found = $box.find('.dvm-found');
    if (q.length < 2) { $found.hide(); return; }
    userTimer = setTimeout(() => {
        call('GET', '/ajax/decision_vote/users', { q: q }).then(r => {
            if (($(input).val() || '').trim() !== q) return;
            const picked = S.picked[$box.data('key')] || {};
            const list = (r.users || []).filter(u => !picked[u.sp_person_id]);
            $found.html(list.length ? list.map(u => u.has_email
                ? '<a class="dvm-pick" data-id="' + u.sp_person_id + '" data-name="' + esc(u.name || u.username) + '">' + esc(u.name || u.username) + ' <span class="dvm-muted">(' + esc(u.username) + ')</span></a>'
                : '<a class="off" title="This user has no e-mail in Breedbase">' + esc(u.name || u.username) + ' <span class="dvm-muted">(no e-mail)</span></a>').join('')
                : '<a class="off">No user found.</a>').show();
        }).catch(() => $found.hide());
    }, 300);
}

function pickedIds(key) { return Object.keys(S.picked[key] || {}).map(Number); }

// total to invite: the Breedbase users picked + the people written (both boxes)
const PEOPLE_BOX = { new: '#dvm_people', detail: '#dvm_invite_emails' };
function updateTotals() {
    $('.dvm-total').each(function() {
        const key = $(this).data('key');
        const users = pickedIds(key).length;
        const people = parsePeople($(PEOPLE_BOX[key]).val()).people.length;
        const total = users + people;
        $(this).html(total ? '<b>Total to invite: ' + total + '</b> <span class="dvm-muted">(' + users + ' Breedbase user' + (users === 1 ? '' : 's') + ' + ' +
            people + ' without an account)</span>' : '');
    });
}

// registers users and e-mails their voting links, in batches. Resolves to {sent, recent, no_email, unknown} (names)
function inviteUsers(voteId, ids, $status, send) {
    const out = { sent: [], saved: [], recent: [], no_email: [], unknown: [] };
    let i = 0;
    const next = () => {
        if (i >= ids.length) return Promise.resolve(out);
        const batch = ids.slice(i, i + 5);
        $status.html('<span class="glyphicon glyphicon-refresh"></span> ' + (send ? 'Sending voting links to Breedbase users: ' : 'Saving the list: ') + Math.min(i + batch.length, ids.length) + ' of ' + ids.length + '...');
        return call('POST', '/ajax/decision_vote/invite_users', { vote_id: voteId, sp_person_ids: JSON.stringify(batch), send: send ? 1 : 0 })
            .then(r => { (r.results || []).forEach(x => (out[x.status] || out.unknown).push(x.name || ('user ' + x.sp_person_id))); i += batch.length; return next(); });
    };
    return next().catch(e => { e.sent = out.sent; throw e; });
}

function usersSummary(out) {
    let msg = out.saved.length ? '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> ' + out.saved.length + ' Breedbase user' + (out.saved.length === 1 ? '' : 's') + ' added to the list (not sent yet).</span>'
        : '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> Voting link sent to ' + out.sent.length + ' Breedbase user' + (out.sent.length === 1 ? '' : 's') + '.</span>';
    if (out.recent.length) msg += '<br/><span class="text-warning"><b>Not sent again</b>: sent less than 2 minutes ago (to avoid sending twice by mistake): ' + esc(out.recent.join(', ')) + '. Wait 2 minutes to send to them again.</span>';
    if (out.no_email.length) msg += '<br/><span class="text-danger">No e-mail in Breedbase (not sent): ' + esc(out.no_email.join(', ')) + '</span>';
    if (out.unknown.length) msg += '<br/><span class="text-danger">Not found: ' + esc(out.unknown.join(', ')) + '</span>';
    return msg;
}

// Breedbase users, then the people without an account
function inviteAll(voteId, ids, people, message, $status, send) {
    const res = { users: null, people: null };
    return (ids.length ? inviteUsers(voteId, ids, $status, send) : Promise.resolve(null))
        .then(u => { res.users = u; return people.length ? invitePeople(voteId, people, message, $status, send) : null; })
        .then(p => { res.people = p; return res; });
}

function allSummary(res, bad) {
    const parts = [];
    if (res.users) parts.push(usersSummary(res.users));
    if (res.people) parts.push(inviteSummary(res.people));
    if ((bad || []).length) parts.push('<span class="text-danger">Lines without an e-mail (not sent): ' + esc(bad.join(' | ')) + '</span>');
    return parts.join('<br/>');
}

function sendInvites(send) {
    const p = parsePeople($('#dvm_invite_emails').val());
    const ids = pickedIds('detail');
    if (!p.people.length && !ids.length) { $('#dvm_invite_status').html('<span class="text-danger">Choose Breedbase users or write people: Name, e-mail.</span>'); return; }
    const n = ids.length + p.people.length;
    if (send && !window.confirm('Send to ' + n + (n === 1 ? ' person' : ' people') + '?')) return;
    const voteId = S.detail.vote_id;
    $('.dvm-invite-go').prop('disabled', true);
    inviteAll(voteId, ids, p.people, $('#dvm_invite_message').val(), $('#dvm_invite_status'), send)
        .then(res => showDetail(voteId).then(() => {
            $('#dvm_invite_status').html(allSummary(res, p.bad));
            const invalid = res.people ? res.people.invalid : [];
            $('#dvm_invite_emails').val(p.people.filter(x => invalid.indexOf(x.email) >= 0).map(x => (x.name ? x.name + ', ' : '') + x.email).concat(p.bad).join('\n'));
        }))
        .catch(e => {
            $('#dvm_invite_status').html('<span class="text-danger">' + esc(e.message) + ((e.sent || []).length ? ' (' + e.sent.length + ' sent before the error)' : '') + '</span>');
            $('.dvm-invite-go').prop('disabled', false);
        });
}

// sends the invitations saved but not sent yet, in batches
function sendPending() {
    const voteId = S.detail.vote_id;
    const total = (S.detail.invites || []).filter(x => !x.sent).length;
    if (!window.confirm('Send the ' + total + ' invitation' + (total === 1 ? '' : 's') + ' not sent yet?')) return;
    $('#dvm_send_pending').prop('disabled', true);
    let sent = 0;
    let lastRemaining = Infinity;
    const next = () => call('POST', '/ajax/decision_vote/send_pending', { vote_id: voteId }).then(r => {
        sent += r.sent;
        $('#dvm_pending_status').html('<span class="glyphicon glyphicon-refresh"></span> Sending: ' + sent + ' of ' + total + '...');
        // stop when nothing moves (e.g. every remaining one was sent a moment ago)
        if (r.remaining > 0 && r.remaining < lastRemaining) { lastRemaining = r.remaining; return next(); }
        return r.remaining;
    });
    next()
        .then(remaining => showDetail(voteId).then(() => {
            $('#dvm_detail').prepend(alertHtml(remaining ? 'warning' : 'success', '<span class="glyphicon glyphicon-ok"></span> ' + sent + ' invitation' + (sent === 1 ? '' : 's') + ' sent.' +
                (remaining ? ' ' + remaining + ' could not be sent now; try again in a few minutes.' : '')));
            return loadVotesQuiet();
        }))
        .catch(e => { $('#dvm_pending_status').html('<span class="text-danger">' + esc(e.message) + ' (' + sent + ' sent before the error)</span>'); $('#dvm_send_pending').prop('disabled', false); });
}

// the cards again (counts), without touching the detail
function loadVotesQuiet() {
    return call('GET', '/ajax/decision_vote/list', { meeting_id: S.meeting.meeting_id }).then(r => { S.votes = r.votes || []; renderVotes(); }).catch(() => null);
}

function downloadCsv() {
    const v = S.detail;
    const ev = v.evidence;
    const traits = ev ? (ev.traits || []).map(t => t.trait) : [];
    const rows = (ev && ev.rows) || {};
    const q = x => { const s = x === null || x === undefined ? '' : String(x); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
    const head = ['place', 'accession', 'points', 'first_places', 'n_votes', 'average_place'].concat(traits).concat(ev && ev.index ? ['index', 'index_rank'] : []).concat(['notes']);
    const lines = [head.map(q).join(',')].concat(v.results.candidates.map(x => {
        const e = rows[x.accession] || {};
        return [x.place, x.accession, x.points, x.first, x.n_votes, x.mean_rank].concat(traits.map(t => (e.values || {})[t]))
            .concat(ev && ev.index ? [e.index, e.index_rank] : []).concat([(x.comments || []).join(' | ')]).map(q).join(',');
    }));
    (v.results.other_notes || []).forEach(x => {
        lines.push(['', x.accession, '', '', '', ''].concat(traits.map(() => '')).concat(ev && ev.index ? ['', ''] : []).concat(['(only for notes) ' + x.comments.join(' | ')]).map(q).join(','));
    });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([lines.join('\n') + '\n'], { type: 'text/csv' }));
    a.download = (v.name || 'vote').replace(/[^\w.-]+/g, '_') + '_results.csv';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
}

// ---------------------------------------------------------------- form

function ymd(d) { return d.toISOString().slice(0, 10); }

const PEOPLE_HELP = 'They receive their voting link by e-mail.';

function openForm(vote) {
    S.editing = vote ? vote.vote_id : null;
    $('#dvm_form_msg').empty();
    $('#dvm_form_title').text(vote ? 'Edit vote' : 'New variety vote');
    $('#dvm_save').html(vote ? '<span class="glyphicon glyphicon-ok"></span> Save changes' : '<span class="glyphicon glyphicon-send"></span> Send invitations now');
    $('#dvm_save_later, #dvm_save_hint').toggle(!vote);
    const today = new Date();
    $('#dvm_name').val(vote ? vote.name : '');
    $('#dvm_desc').val(vote ? vote.description || '' : '');
    $('#dvm_start').val(vote ? vote.start_date : ymd(today));
    $('#dvm_end').val(vote ? vote.end_date : ymd(new Date(today.getTime() + 14 * 86400000)));
    $('#dvm_candidates_part').toggle(!vote);
    if (!vote) { $('#dvm_people').val(''); $('#dvm_people_count').html(PEOPLE_HELP); S.picked.new = {}; renderPickers(); }
    $('#dvm_new').show();
    if (!vote) loadSources();
    $('#dvm_name').trigger('focus');
}

function loadSources() {
    const fill = () => {
        const r = S.analyses;
        const an = (r.analyses || []).filter(a => !a.hidden);
        $('#dvm_source').html(an.map(a => '<option value="' + a.analysis_id + '">Analysis: ' + esc(a.name || ('analysis ' + a.analysis_id)) + '</option>').join('') +
            '<option value="">The accessions of this meeting (no analysis)</option>');
        loadCandidates();
    };
    if (S.analyses) { fill(); return; }
    $('#dvm_candidates').html('<div style="padding:6px" class="dvm-muted">Loading...</div>');
    call('GET', '/ajax/script_factory/meetings/analyses', { meeting_id: S.meeting.meeting_id })
        .then(r => { S.analyses = r; fill(); })
        .catch(e => { S.analyses = { analyses: [], meeting: { accessions: [] } }; $('#dvm_form_msg').html(alertHtml('warning', esc(e.message))); fill(); });
}

function meetingAccessions() {
    const set = {};
    ((S.analyses && S.analyses.meeting && S.analyses.meeting.accessions) || []).forEach(a => { set[a] = true; });
    return set;
}

// what each accession is in the new vote: 'vote' (put in order), 'note' (only for notes) or '' (not in the vote)
function defaultRoles() {
    S.role = {};
    const hasIndex = S.candidates.some(x => x.index_rank);
    S.candidates.forEach(x => { S.role[x.accession] = !hasIndex || x.selected ? 'vote' : 'note'; });
}

function loadCandidates() {
    const id = $('#dvm_source').val();
    const inMeeting = meetingAccessions();
    if (!id) {
        S.candidates = Object.keys(inMeeting).sort().map(a => ({ accession: a, selected: true, in_meeting: true }));
        $('#dvm_check_selected').hide();
        defaultRoles();
        renderCandidates();
        return;
    }
    $('#dvm_check_selected').show();
    $('#dvm_candidates').html('<div style="padding:6px" class="dvm-muted"><span class="glyphicon glyphicon-refresh"></span> Reading the results of the analysis...</div>');
    call('GET', '/ajax/script_factory/decision_evidence', { analysis_id: id })
        .then(e => {
            if ($('#dvm_source').val() !== id) return;
            S.candidates = (e.rows || []).map(r => ({ accession: r.accession, selected: !!r.selected, index_rank: r.index_rank, index: r.index, in_meeting: !!inMeeting[r.accession] }))
                .sort((a, b) => (a.index_rank || 1e9) - (b.index_rank || 1e9) || a.accession.localeCompare(b.accession));
            $('#dvm_only_meeting').prop('checked', Object.keys(inMeeting).length > 0 && S.candidates.some(x => x.in_meeting));
            defaultRoles();
            renderCandidates();
        })
        .catch(err => $('#dvm_candidates').html('<div style="padding:6px">' + alertHtml('warning', esc(err.message)) + '</div>'));
}

function shownCandidates() {
    const only = $('#dvm_only_meeting').is(':checked');
    return S.candidates.filter(x => !only || x.in_meeting);
}

function renderCandidates() {
    const list = shownCandidates();
    const opt = (v, cur, label) => '<option value="' + v + '"' + (cur === v ? ' selected' : '') + '>' + label + '</option>';
    $('#dvm_candidates').html(list.length ? list.map(x => {
        const r = S.role[x.accession] || '';
        return '<label class="dvm-row dvm-' + (r || 'out') + '"><select class="input-sm dvm-role" data-acc="' + esc(x.accession) + '" style="margin-right:8px">' +
            opt('vote', r, 'Candidate') + opt('note', r, 'Only notes') + opt('', r, 'Not in the vote') + '</select>' + esc(x.accession) +
            (x.index_rank ? ' <span class="dvm-muted">index rank ' + x.index_rank + (x.selected ? ', selected' : '') + '</span>' : '') +
            (x.in_meeting && $('#dvm_source').val() ? ' <span class="label label-default">meeting</span>' : '') + '</label>';
    }).join('')
        : '<div style="padding:6px" class="dvm-muted">No accession.' + ($('#dvm_only_meeting').is(':checked') ? ' Uncheck "Only accessions of this meeting".' : '') + '</div>');
    countChecked();
}

// the accessions in the vote: only the ones shown (the filter of the meeting applies)
function chosen(role) { return shownCandidates().filter(x => S.role[x.accession] === role).map(x => x.accession); }

function countChecked() {
    const nv = chosen('vote').length;
    $('#dvm_n_checked').html('<b>' + nv + '</b> candidate' + (nv === 1 ? '' : 's') + ' &middot; <b>' + chosen('note').length + '</b> only notes' +
        ' <span class="dvm-muted">(of ' + shownCandidates().length + ' accessions)</span>');
}

function setShown(fn) { shownCandidates().forEach(x => { S.role[x.accession] = fn(x); }); renderCandidates(); }

function save(sendNow) {
    const data = { name: $('#dvm_name').val(), description: $('#dvm_desc').val(), start_date: $('#dvm_start').val(), end_date: $('#dvm_end').val() };
    let url;
    if (S.editing) {
        url = '/ajax/decision_vote/update';
        data.vote_id = S.editing;
    } else {
        url = '/ajax/decision_vote/create';
        const names = chosen('vote');
        const uniq = names.filter((x, i) => names.indexOf(x) === i);
        data.meeting_id = S.meeting.meeting_id;
        data.analysis_id = $('#dvm_source').val() || '';
        data.accessions = JSON.stringify(uniq);
        data.note_accessions = JSON.stringify(chosen('note').filter(x => uniq.indexOf(x) < 0));
    }
    const invite = S.editing ? { people: [], bad: [] } : parsePeople($('#dvm_people').val());
    const userIds = S.editing ? [] : pickedIds('new');
    if (invite.bad.length && !window.confirm(invite.bad.length + ' line(s) of "People to invite" have no e-mail and will be skipped:\n' + invite.bad.slice(0, 5).join('\n') + '\n\nContinue?')) return;
    $('#dvm_save, #dvm_save_later').prop('disabled', true);
    call('POST', url, data)
        .then(r => {
            if (r.vote_id) S.current = r.vote_id;
            if (!r.vote_id || (!invite.people.length && !userIds.length)) {
                $('#dvm_new').hide();
                return loadVotes();
            }
            // the vote is open: now the invitations
            return inviteAll(r.vote_id, userIds, invite.people, data.description, $('#dvm_form_msg'), sendNow)
                .then(res => {
                    $('#dvm_new').hide();
                    $('#dvm_people').val('');
                    S.picked.new = {};
                    const warn = (res.people && res.people.invalid.length) || (res.users && res.users.no_email.length) || invite.bad.length;
                    return loadVotes().then(() => $('#dvm_detail').prepend(alertHtml(warn ? 'warning' : 'success', 'The vote is open.<br/>' + allSummary(res, invite.bad) +
                        (sendNow ? '' : '<br/>Send the invitations when you are ready: <b>Send the invitations not sent yet</b>, below.'))));
                })
                .catch(e => {
                    $('#dvm_new').hide();
                    return loadVotes().then(() => $('#dvm_detail').prepend(alertHtml('danger', 'The vote is open, but sending the invitations stopped: ' + esc(e.message) +
                        ' (' + (e.sent || []).length + ' sent). Use "Invite more people" below to send the others.')));
                });
        })
        .catch(e => $('#dvm_form_msg').html(alertHtml('danger', esc(e.message))))
        .then(() => $('#dvm_save, #dvm_save_later').prop('disabled', false));
}

export function init() {
    $ = window.jQuery;
    if (!$('#dvm_body').length) return;
    $(document).on('change', '.dm-meeting-check', () => setTimeout(onMeetingChange, 0));
    $('#dvm_new_toggle').on('click', () => { if ($('#dvm_new').is(':visible') && !S.editing) $('#dvm_new').hide(); else openForm(null); });
    $('#dvm_cancel').on('click', () => $('#dvm_new').hide());
    $('#dvm_save, #dvm_save_later').on('click', function() { save(String($(this).data('send')) === '1'); });
    $(document).on('input', '.dvm-user-q', function() { searchUsers(this); });
    $(document).on('click', '.dvm-pick', function() {
        const key = $(this).closest('.dvm-users').data('key');
        S.picked[key] = S.picked[key] || {};
        S.picked[key][$(this).data('id')] = { name: $(this).attr('data-name') };
        renderPickers();
        $('.dvm-users[data-key="' + key + '"] .dvm-user-q').trigger('focus');
    });
    $(document).on('click', '.dvm-unpick', function() {
        const key = $(this).closest('.dvm-users').data('key');
        delete (S.picked[key] || {})[$(this).data('id')];
        renderPickers();
    });
    $(document).on('input', '#dvm_people, #dvm_invite_emails', updateTotals);
    $('#dvm_people').on('input', function() { $('#dvm_people_count').html(peopleCountText($(this).val()) || PEOPLE_HELP); });
    $('#dvm_source').on('change', loadCandidates);
    $('#dvm_only_meeting').on('change', renderCandidates);
    $('#dvm_check_selected').on('click', () => setShown(x => (x.selected ? 'vote' : 'note')));
    $('#dvm_check_all').on('click', () => setShown(() => 'note'));
    $('#dvm_check_none').on('click', () => setShown(() => ''));
    $('#dvm_candidates').on('change', '.dvm-role', function() {
        S.role[$(this).attr('data-acc')] = $(this).val();
        $(this).closest('label').attr('class', 'dvm-row dvm-' + ($(this).val() || 'out'));
        countChecked();
    });
    $('#dvm_votes').on('click', '.dvm-card', function(ev) {
        if ($(ev.target).closest('button, a').length) return;
        showDetail(Number($(this).data('id')));
    });
    $('#dvm_votes').on('click', '.dvm-edit', function() { openForm(S.votes.find(x => x.vote_id === Number($(this).data('id')))); });
    $('#dvm_votes').on('click', '.dvm-delete', function() {
        const v = S.votes.find(x => x.vote_id === Number($(this).data('id')));
        if (!v || !window.confirm('Delete the vote "' + v.name + '"? ' + (v.progress.registered ? 'Its ' + v.progress.registered + ' registration(s) and ' + v.progress.voted + ' vote(s) are deleted too, and the voting links stop working.' : 'The voting links stop working.'))) return;
        call('POST', '/ajax/decision_vote/delete', { vote_id: v.vote_id })
            .then(() => { if (S.current === v.vote_id) S.current = null; return loadVotes(); })
            .catch(e => $('#dvm_votes').prepend(alertHtml('danger', esc(e.message))));
    });
    $('#dvm_detail').on('click', '#dvm_csv', downloadCsv);
    $('#dvm_detail').on('click', '#dvm_show_results', function() {
        S.showResults = !S.showResults;
        $('#dvm_results_box').toggle(S.showResults);
        $(this).html('<span class="glyphicon glyphicon-stats"></span> ' + (S.showResults ? 'Hide results' : 'Show results'));
    });
    $('#dvm_detail').on('click', '.dvm-invite-go', function() { sendInvites(String($(this).data('send')) === '1'); });
    $('#dvm_detail').on('click', '#dvm_send_pending', sendPending);
    $('#dvm_detail').on('click', '.dvm-resend', function() {
        const btn = this;
        $(btn).prop('disabled', true);
        call('POST', '/ajax/decision_vote/resend_invite', { vote_id: S.detail.vote_id, invite_id: $(btn).data('invite') })
            .then(r => $(btn).html('<span class="glyphicon glyphicon-ok"></span> Sent'))
            .catch(e => { $(btn).prop('disabled', false); window.alert(e.message); });
    });
    setTimeout(onMeetingChange, 500);
}
