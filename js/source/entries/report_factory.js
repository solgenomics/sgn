/*
 * Report Factory - front end for /tools/report
 *
 * 1. Reports: the report scripts configured for the site (report_engine). The
 *    inputs each one takes are detected on the server from the script itself.
 * 2. Inputs: only the inputs the chosen reports use (date range, trial,
 *    accession and trait lists), with what each report needs.
 * 3. Run & results: runs the reports as a background job, follows it and shows
 *    the results (summary numbers, charts, tables) and the files to download.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

const INPUTS = ['dates', 'trials', 'accessions', 'traits'];
const LISTS = ['trials', 'accessions', 'traits'];
const LABELS = { dates: 'Date range', trials: 'Trial list', accessions: 'Accession list', traits: 'Trait list' };
const LIST_TYPES = { trials: 'trials', accessions: 'accessions', traits: 'traits' };

let opts = {};
let $ = null;
const state = {
    catalog: [],
    email: '',
    selected: [],
    lists: { trials: null, accessions: null, traits: null },    // list info from /list_info
    listErrors: {},
    step: 1,
    runId: '',
    poll: null,
};

function esc(s) {
    return String(s === undefined || s === null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function fmtNum(v) {
    if (typeof v === 'number' && isFinite(v)) {
        return Math.abs(v) >= 1000 ? v.toLocaleString() : (Number.isInteger(v) ? String(v) : v.toFixed(2));
    }
    return esc(v);
}

function fmtDate(epoch) {
    if (!epoch) return '';
    const d = new Date(epoch * 1000);
    const p = n => (n < 10 ? '0' : '') + n;
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
}

function isoDate(d) {
    const p = n => (n < 10 ? '0' : '') + n;
    return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
}

function selectedReports() {
    return state.catalog.filter(r => state.selected.indexOf(r.name) >= 0);
}

function uses(r, k) { return !!(r.inputs && r.inputs[k]); }

/* inputs a report must get at least one of: mirrors CXGN::Report::Catalog::validate_inputs.
   A report that takes a trial list needs it or the date range (accession and
   trait lists are then filters); any other report needs one of its inputs. */
function needed(r) {
    if (uses(r, 'trials')) return ['dates', 'trials'].filter(k => uses(r, k));
    return INPUTS.filter(k => uses(r, k));
}

function given() {
    const g = {};
    const s = $('#rf_start_date').val(), e = $('#rf_end_date').val();
    g.dates = !!(s && e && s <= e);
    LISTS.forEach(k => { g[k] = !!(state.lists[k] && state.lists[k].n_found > 0); });
    return g;
}

function article(label) { return (/^[aeiou]/i.test(label) ? 'an ' : 'a ') + label; }

function problems(r, g) {
    const n = needed(r);
    if (n.length && !n.some(k => g[k])) return ['needs ' + n.map(k => article(LABELS[k].toLowerCase())).join(' or ')];
    return [];
}

/* ---------------------------------------------------------------- step 1 */

function chips(r) {
    const used = INPUTS.filter(k => uses(r, k));
    if (!used.length) return '<span class="rf-chip rf-chip-none">no inputs</span>';
    return used.map(k => '<span class="rf-chip rf-chip-' + k + '">' + esc(LABELS[k]) + '</span>').join('');
}

function renderReports() {
    const filter = ($('#rf_report_search').val() || '').toLowerCase();
    if (!state.catalog.length) {
        $('#rf_reports').html('<div class="alert alert-warning">No report scripts are configured for this site (configuration key <code>report_engine</code>).</div>');
        return;
    }
    const html = state.catalog.filter(r => !filter || (r.title + ' ' + r.name + ' ' + r.description).toLowerCase().indexOf(filter) >= 0).map(r => {
        const on = state.selected.indexOf(r.name) >= 0;
        const off = !r.installed || !opts.is_curator;
        const why = !r.installed ? '<span class="rf-report-text text-danger">The script bin/Reports/' + esc(r.name) + '.pl is not installed on this server.</span>' : '';
        return '<label class="rf-report' + (on ? ' on' : '') + (off ? ' off' : '') + '">'
            + '<input type="checkbox" value="' + esc(r.name) + '"' + (on ? ' checked' : '') + (off ? ' disabled' : '') + ' />'
            + '<span class="rf-report-title">' + esc(r.title) + '</span>'
            + (r.description ? '<span class="rf-report-text">' + esc(r.description) + '</span>' : '')
            + why
            + '<div>' + chips(r) + '</div>'
            + '<span class="rf-report-name">' + esc(r.name) + '.pl</span>'
            + '</label>';
    }).join('');
    $('#rf_reports').html(html || '<span class="rf-muted">No report matches the filter.</span>');
}

function updateStep1() {
    const n = state.selected.length;
    $('#rf_step1_next').prop('disabled', n === 0).text(n === 0 ? 'Choose a report' : 'Next: inputs (' + n + ' report' + (n > 1 ? 's' : '') + ')');
}

/* ---------------------------------------------------------------- step 2 */

function usageHtml(k, reports) {
    const users = reports.filter(r => uses(r, k));
    return users.map(r => {
        const n = needed(r);
        let tag;
        if (n.length === 1 && n[0] === k) tag = '<span class="label label-danger">required</span>';
        else if (n.indexOf(k) >= 0) tag = '<span class="label label-warning">needed if no ' + n.filter(x => x !== k).map(x => LABELS[x].toLowerCase()).join(' or ') + ' is given</span>';
        else tag = '<span class="label label-default">optional filter</span>';
        return esc(r.title) + ' ' + tag;
    }).join(' &nbsp; ');
}

function renderInputs() {
    const reports = selectedReports();
    let any = false;
    INPUTS.forEach(k => {
        const used = reports.some(r => uses(r, k));
        $('.rf-input[data-input="' + k + '"]').toggle(used);
        $('[data-usage-for="' + k + '"]').html(used ? usageHtml(k, reports) : '');
        if (used) any = true;
        if (used && LISTS.indexOf(k) >= 0) ensureListSelect(k);
    });
    $('#rf_no_inputs').toggle(!any);
    const notUsed = INPUTS.filter(k => !reports.some(r => uses(r, k)));
    $('#rf_inputs_note').html(any && notUsed.length
        ? '<p class="rf-help"><span class="glyphicon glyphicon-info-sign"></span> Not asked because no chosen report uses it: ' + notUsed.map(k => LABELS[k].toLowerCase()).join(', ') + '.</p>'
        : '');
    renderChecklist();
}

function ensureListSelect(k) {
    const div = 'rf_' + k + '_list';
    if ($('#' + div + ' select').length) return;
    let html = '';
    try {
        const lo = new window.CXGN.List();
        html = lo.listSelect(div + '_sel', [LIST_TYPES[k]].concat(k === 'trials' ? ['projects'] : []), 'No list (do not limit)', undefined, undefined);
    } catch (e) {
        html = '<span class="text-danger">Lists are not available.</span>';
    }
    $('#' + div).html(html);
    $('#' + div).on('change', 'select', function () { loadListInfo(k, $(this).val()); });
}

function loadListInfo(k, listId) {
    const msg = $('#rf_' + k + '_msg');
    state.lists[k] = null;
    delete state.listErrors[k];
    if (!listId || !/^\d+$/.test(listId)) {
        msg.html('');
        renderChecklist();
        return;
    }
    msg.html('<span class="rf-muted"><span class="glyphicon glyphicon-refresh rf-spin"></span> Checking the list...</span>');
    $.ajax({ url: '/ajax/report/list_info', data: { list_id: listId, kind: k }, dataType: 'json' }).done(r => {
        if (r.error) {
            state.listErrors[k] = r.error;
            msg.html('<span class="text-danger"><span class="glyphicon glyphicon-exclamation-sign"></span> ' + esc(r.error) + '</span>');
        } else {
            state.lists[k] = r;
            msg.html(listInfoHtml(k, r));
        }
        renderChecklist();
    }).fail(() => {
        state.listErrors[k] = 'Could not check the list.';
        msg.html('<span class="text-danger">Could not check the list.</span>');
        renderChecklist();
    });
}

function listInfoHtml(k, r) {
    let h = '';
    const noun = { trials: 'trials', accessions: 'accessions', traits: 'traits' }[k];
    if (r.n_found === 0) {
        h += '<span class="text-danger"><span class="glyphicon glyphicon-exclamation-sign"></span> None of the ' + r.n_items + ' items were found in the database: this list cannot be used.</span>';
    } else {
        h += '<span class="text-success"><span class="glyphicon glyphicon-ok"></span> ' + r.n_found + ' ' + noun + ' found</span>';
        if (r.n_missing > 0) {
            h += ' <span class="text-warning">&middot; ' + r.n_missing + ' not found and left out'
                + (r.missing && r.missing.length ? ': ' + r.missing.slice(0, 8).map(esc).join(', ') + (r.n_missing > 8 ? ', ...' : '') : '') + '</span>';
        }
    }
    const f = r.facts;
    if (f && r.n_found > 0) {
        const facts = [];
        if (f.year_from) facts.push('Years ' + esc(f.year_from) + (f.year_to && f.year_to !== f.year_from ? '&ndash;' + esc(f.year_to) : ''));
        if (f.n_locations) facts.push(esc(f.n_locations) + ' location' + (f.n_locations > 1 ? 's' : ''));
        if (f.n_traits !== undefined && f.n_traits !== null) facts.push(esc(f.n_traits) + ' traits observed');
        if (f.n_observations !== undefined && f.n_observations !== null) facts.push(fmtNum(Number(f.n_observations)) + ' observations');
        if (f.created_from) facts.push('Created ' + esc(f.created_from) + (f.created_to && f.created_to !== f.created_from ? ' to ' + esc(f.created_to) : ''));
        if (facts.length) h += '<div class="rf-facts">' + facts.map(x => '<span>' + x + '</span>').join('') + '</div>';
        if (Number(f.n_observations) === 0) h += '<div class="text-warning">These trials have no phenotypes yet; phenotype reports will be empty.</div>';
    }
    return h;
}

function renderChecklist() {
    const reports = selectedReports();
    const g = given();
    const items = [];
    const s = $('#rf_start_date').val(), e = $('#rf_end_date').val();
    let datesMsg = '';
    if ((s && !e) || (!s && e)) datesMsg = '<span class="text-warning">Give both dates, or neither.</span>';
    else if (s && e && s > e) datesMsg = '<span class="text-danger">The start date is after the end date.</span>';
    else if (g.dates && g.trials) datesMsg = '<span class="rf-muted">Only the trials of the list created in this range are used.</span>';
    else if (!g.dates && g.trials && reports.some(r => uses(r, 'dates') && uses(r, 'trials'))) datesMsg = '<span class="rf-muted">Not needed: the trial list already says which trials to use.</span>';
    $('#rf_dates_msg').html(datesMsg);

    reports.forEach(r => {
        const p = problems(r, g);
        const usedGiven = INPUTS.filter(k => uses(r, k) && g[k]).map(k => LABELS[k].toLowerCase());
        if (p.length) {
            items.push('<li class="bad"><span class="glyphicon glyphicon-remove-sign"></span> <b>' + esc(r.title) + '</b> ' + esc(p.join('; ')) + '.</li>');
        } else if (!INPUTS.some(k => uses(r, k))) {
            items.push('<li class="ok"><span class="glyphicon glyphicon-ok-sign"></span> <b>' + esc(r.title) + '</b> runs on the whole database.</li>');
        } else {
            items.push('<li class="ok"><span class="glyphicon glyphicon-ok-sign"></span> <b>' + esc(r.title) + '</b> will use: ' + esc(usedGiven.join(', ')) + '.</li>');
        }
        LISTS.forEach(k => {
            if (g[k] && !uses(r, k)) items.push('<li class="info"><span class="glyphicon glyphicon-info-sign"></span> ' + esc(r.title) + ' does not read the ' + LABELS[k].toLowerCase() + '; it is ignored for this report.</li>');
        });
    });
    Object.keys(state.listErrors).forEach(k => {
        if (reports.some(r => uses(r, k))) items.push('<li class="bad"><span class="glyphicon glyphicon-remove-sign"></span> ' + esc(LABELS[k]) + ': ' + esc(state.listErrors[k]) + '</li>');
    });
    $('#rf_checklist').html(items.join(''));
    const ok = canRun();
    $('#rf_step2_next').prop('disabled', !ok).text(ok ? 'Next: run' : 'Fill the inputs first');
    renderFlow();
}

function canRun() {
    const reports = selectedReports();
    if (!reports.length) return false;
    const s = $('#rf_start_date').val(), e = $('#rf_end_date').val();
    if ((s && !e) || (!s && e) || (s && e && s > e)) return false;
    if (Object.keys(state.listErrors).some(k => reports.some(r => uses(r, k)))) return false;
    const g = given();
    return reports.every(r => problems(r, g).length === 0);
}

function setPreset(p) {
    const today = new Date();
    if (p === 'clear') { $('#rf_start_date, #rf_end_date').val(''); }
    else if (p === 'year') { $('#rf_start_date').val(today.getFullYear() + '-01-01'); $('#rf_end_date').val(isoDate(today)); }
    else {
        const from = new Date(today.getTime() - Number(p) * 86400000);
        $('#rf_start_date').val(isoDate(from)); $('#rf_end_date').val(isoDate(today));
    }
    renderChecklist();
}

/* ---------------------------------------------------------------- summary */

function inputSummary() {
    const g = given();
    const out = {};
    if (g.dates) out.dates = $('#rf_start_date').val() + ' to ' + $('#rf_end_date').val();
    LISTS.forEach(k => { if (g[k]) out[k] = state.lists[k].name + ' (' + state.lists[k].n_found + ')'; });
    return out;
}

function renderFlow() {
    const reports = selectedReports();
    const s = inputSummary();
    const items = [];
    items.push('<li' + (reports.length ? '' : ' class="off"') + '><b>Reports</b>' + (reports.length ? reports.map(r => esc(r.title)).join('<br>') : 'none chosen') + '</li>');
    INPUTS.forEach(k => {
        if (!reports.some(r => uses(r, k))) return;
        items.push('<li' + (s[k] ? '' : ' class="off"') + '><b>' + esc(LABELS[k]) + '</b>' + (s[k] ? esc(s[k]) : 'not given') + '</li>');
    });
    items.push('<li' + (state.runId ? '' : ' class="off"') + '><b>Run</b>' + (state.runId ? esc(state.runId) : 'not started') + '</li>');
    $('#rf_flow').html(items.join(''));
}

/* ---------------------------------------------------------------- steps */

function goto(step) {
    if (step === 2 && !state.selected.length) return;
    if (step === 3 && !canRun() && !state.runId) return;
    state.step = step;
    $('.rf-step').hide();
    $('.rf-step[data-step="' + step + '"]').show();
    $('#rf_stepper li').each(function () {
        const n = Number($(this).data('step'));
        $(this).toggleClass('active', n === step).toggleClass('done', n < step);
    });
    if (step === 2) renderInputs();
    if (step === 3) renderReview();
    renderFlow();
}

function renderReview() {
    const reports = selectedReports();
    const s = inputSummary();
    const cells = ['<div><b>Reports</b>' + (reports.map(r => esc(r.title)).join('<br>') || '&ndash;') + '</div>'];
    INPUTS.forEach(k => { if (s[k]) cells.push('<div><b>' + esc(LABELS[k]) + '</b>' + esc(s[k]) + '</div>'); });
    $('#rf_review').html(cells.join(''));
    $('#rf_run_btn').prop('disabled', !canRun() || !opts.is_curator);
    $('#rf_email_hint').text(state.email ? '(' + state.email + ')' : '(no email address in your account)');
    $('#rf_notify').prop('disabled', !state.email);
}

/* ---------------------------------------------------------------- run */

function startRun() {
    if (!canRun()) return;
    const g = given();
    const data = {
        reports: state.selected.slice(),
        start_date: g.dates ? $('#rf_start_date').val() : '',
        end_date: g.dates ? $('#rf_end_date').val() : '',
        trial_list_id: g.trials ? state.lists.trials.id : '',
        accession_list_id: g.accessions ? state.lists.accessions.id : '',
        trait_list_id: g.traits ? state.lists.traits.id : '',
        notify: $('#rf_notify').is(':checked') ? 1 : 0,
        title: $('#rf_title').val(),
    };
    $('#rf_run_btn').prop('disabled', true);
    $('#rf_run_msg').html('<span class="rf-muted"><span class="glyphicon glyphicon-refresh rf-spin"></span> Starting...</span>');
    $.ajax({ url: '/ajax/report/run', type: 'POST', data: { reportData: JSON.stringify(data) }, dataType: 'json' }).done(r => {
        if (r.error) {
            $('#rf_run_msg').html('<span class="text-danger" style="white-space:pre-wrap">' + esc(r.error) + '</span>');
            $('#rf_run_btn').prop('disabled', false);
            return;
        }
        $('#rf_run_msg').html('<span class="text-success">Started. You can leave this page: the report keeps running' + (data.notify ? ' and you will get an email' : '') + '. Find it later under <b>My reports</b>.</span>');
        openRun(r.run_id);
        loadHistory();
    }).fail(xhr => {
        $('#rf_run_msg').html('<span class="text-danger">Could not start the report (' + esc(xhr.status) + ').</span>');
        $('#rf_run_btn').prop('disabled', false);
    });
}

function openRun(runId) {
    state.runId = runId;
    if (state.poll) { clearTimeout(state.poll); state.poll = null; }
    try { window.history.replaceState(null, '', '/tools/report?run_id=' + encodeURIComponent(runId)); } catch (e) { /* ignore */ }
    renderFlow();
    loadResults();
}

function loadResults() {
    const runId = state.runId;
    $.ajax({ url: '/ajax/report/results', data: { run_id: runId }, dataType: 'json' }).done(r => {
        if (runId !== state.runId) return;
        if (r.error) {
            $('#rf_results').html('<div class="alert alert-danger">' + esc(r.error) + '</div>');
            return;
        }
        renderResults(r);
        const st = r.state || 'waiting';
        if (st === 'waiting' || st === 'running') {
            $.ajax({ url: '/ajax/report/status', data: { run_id: runId }, dataType: 'json' }).done(s => {
                if (s && s.state === 'failed' && s.error && !(r.reports || []).some(x => x.state !== 'waiting')) {
                    $('#rf_results').html('<div class="rf-card rf-result failed"><h3>' + esc(r.run.title) + '</h3><div class="rf-error">' + esc(s.error) + '</div></div>');
                    return;
                }
                if (s && s.progress) $('#rf_progress_text').text(s.progress);
                state.poll = setTimeout(loadResults, 3000);
            }).fail(() => { state.poll = setTimeout(loadResults, 5000); });
        } else {
            loadHistory();
        }
    }).fail(() => {
        $('#rf_results').html('<div class="alert alert-danger">Could not load the report.</div>');
    });
}

function dl(runId, file) {
    return '/ajax/report/download?run_id=' + encodeURIComponent(runId) + '&file=' + encodeURIComponent(file);
}

function fileIcon(f) {
    if (/\.xlsx$/i.test(f)) return 'glyphicon-th';
    if (/\.csv$/i.test(f)) return 'glyphicon-list';
    if (/\.zip$/i.test(f)) return 'glyphicon-compressed';
    return 'glyphicon-file';
}

function renderResults(r) {
    const run = r.run || {};
    const st = r.state || 'waiting';
    let h = '<div class="rf-card">'
        + '<div class="rf-result-head"><div><h3>' + esc(run.title) + ' <span class="rf-state rf-state-' + esc(st) + '">' + esc(st) + '</span></h3>'
        + '<div class="rf-help">Started ' + esc(fmtDate(run.created)) + (run.finished ? ' &middot; finished ' + esc(fmtDate(run.finished)) : '') + ' &middot; <span class="rf-report-name">' + esc(run.run_id) + '</span></div></div>'
        + '<div>' + (run.zip ? '<a class="btn btn-primary btn-sm" href="' + dl(run.run_id, run.zip) + '"><span class="glyphicon glyphicon-download-alt"></span> Download all (zip)</a>' : '') + '</div></div>';
    const inp = run.inputs || {};
    const cells = [];
    if (inp.start_date) cells.push('<div><b>Date range</b>' + esc(inp.start_date) + ' to ' + esc(inp.end_date) + '</div>');
    LISTS.forEach(k => { if (inp[k]) cells.push('<div><b>' + esc(LABELS[k]) + '</b>' + esc(inp[k].name) + ' (' + esc(inp[k].n) + ')</div>'); });
    if (cells.length) h += '<div class="rf-review">' + cells.join('') + '</div>';
    if (st === 'waiting' || st === 'running') {
        h += '<p class="rf-progress"><span class="glyphicon glyphicon-refresh rf-spin"></span> <span id="rf_progress_text">' + (st === 'waiting' ? 'Waiting in the job queue' : 'Running') + '</span></p>';
    }
    h += '</div>';

    (r.reports || []).forEach((rep, i) => { h += reportHtml(run, rep, i); });
    $('#rf_results').html(h);
    $('#rf_results table.rf-dt').each(function () {
        if ($.fn.DataTable && !$.fn.DataTable.isDataTable(this)) {
            $(this).DataTable({ pageLength: 25, scrollX: true, order: [], deferRender: true });
        }
    });
    $('#rf_results a[data-toggle="tab"]').on('shown.bs.tab', () => {
        if ($.fn.DataTable) $.fn.dataTable.tables({ visible: true, api: true }).columns.adjust();
    });
}

function reportHtml(run, rep, idx) {
    const st = rep.state || 'waiting';
    let h = '<div class="rf-card rf-result ' + esc(st) + '">'
        + '<div class="rf-result-head"><h3>' + esc(rep.title) + ' <span class="rf-state rf-state-' + esc(st) + '">' + esc(st) + '</span></h3>'
        + (rep.seconds !== undefined ? '<span class="rf-help">' + esc(rep.seconds) + ' s</span>' : '') + '</div>';
    if (rep.error) h += '<div class="rf-error">' + esc(rep.error) + '</div>';
    if (rep.warning) h += '<div class="alert alert-warning">' + esc(rep.warning) + '</div>';
    if (rep.files && rep.files.length) {
        h += '<div class="rf-files">' + rep.files.map(f => '<a class="btn btn-default btn-sm" href="' + dl(run.run_id, f) + '"><span class="glyphicon ' + fileIcon(f) + '"></span> ' + esc(f) + '</a>').join('') + '</div>';
    }
    const res = rep.results;
    if (res) {
        if (res.summary && res.summary.length) {
            h += '<div class="rf-stats">' + res.summary.map(s => '<div class="rf-stat"><div class="v">' + fmtNum(s.value) + '</div><div class="l">' + esc(s.label) + '</div>' + (s.hint ? '<div class="h">' + esc(s.hint) + '</div>' : '') + '</div>').join('') + '</div>';
        }
        if (res.charts && res.charts.length) {
            h += '<div class="rf-charts">' + res.charts.map(chartHtml).join('') + '</div>';
        }
        if (res.notes && res.notes.length) {
            h += '<ul class="rf-notes">' + res.notes.map(n => '<li>' + esc(n) + '</li>').join('') + '</ul>';
        }
        if (res.tables && res.tables.length) {
            const tid = 'rf_t' + idx;
            if (res.tables.length > 1) {
                h += '<ul class="nav nav-tabs">' + res.tables.map((t, j) => '<li' + (j === 0 ? ' class="active"' : '') + '><a href="#' + tid + '_' + j + '" data-toggle="tab">' + esc(t.name) + ' <span class="badge">' + fmtNum(t.total_rows) + '</span></a></li>').join('') + '</ul>';
                h += '<div class="tab-content rf-tab-content">' + res.tables.map((t, j) => '<div class="tab-pane' + (j === 0 ? ' active' : '') + '" id="' + tid + '_' + j + '">' + tableHtml(t) + '</div>').join('') + '</div>';
            } else {
                h += '<h4>' + esc(res.tables[0].name) + ' <span class="badge">' + fmtNum(res.tables[0].total_rows) + '</span></h4>' + tableHtml(res.tables[0]);
            }
        }
    }
    h += '</div>';
    return h;
}

function chartHtml(c) {
    const vals = (c.values || []).map(Number);
    const max = Math.max.apply(null, vals.concat([0])) || 1;
    const rows = (c.labels || []).map((l, i) => {
        const v = vals[i] || 0;
        return '<div class="rf-bar-row"><span class="lab" title="' + esc(l) + '">' + esc(l) + '</span><span class="track"><span class="bar" style="display:block;width:' + Math.max(0, (v / max) * 100).toFixed(1) + '%"></span></span><span class="val">' + fmtNum(v) + '</span></div>';
    }).join('');
    return '<div class="rf-chart"><h5>' + esc(c.title) + '</h5>' + (rows || '<span class="rf-muted">Nothing to show.</span>') + '</div>';
}

function tableHtml(t) {
    if (!t.rows || !t.rows.length) return '<p class="rf-muted">No rows.</p>';
    let h = '';
    if (t.description) h += '<p class="rf-help">' + esc(t.description) + '</p>';
    if (t.truncated) h += '<p class="rf-help">Showing the first ' + fmtNum(t.rows.length) + ' of ' + fmtNum(t.total_rows) + ' rows; download the file for all of them.</p>';
    h += '<div class="rf-table-wrap"><table class="table table-striped table-condensed rf-dt"><thead><tr>' + (t.columns || []).map(c => '<th>' + esc(c) + '</th>').join('') + '</tr></thead><tbody>';
    h += t.rows.map(row => '<tr>' + row.map(v => '<td>' + esc(v) + '</td>').join('') + '</tr>').join('');
    h += '</tbody></table></div>';
    return h;
}

/* ---------------------------------------------------------------- history */

function loadHistory() {
    $.ajax({ url: '/ajax/report/runs', dataType: 'json' }).done(r => {
        const runs = (r && r.runs) || [];
        if (!runs.length) {
            $('#rf_history').html('<span class="rf-muted">No reports yet.</span>');
            return;
        }
        let h = '<table class="table table-condensed rf-history"><thead><tr><th>Started</th><th>Report</th><th>Inputs</th><th>Status</th><th></th></tr></thead><tbody>';
        h += runs.map(x => {
            const inp = x.inputs || {};
            const parts = [];
            if (inp.start_date) parts.push(esc(inp.start_date) + ' to ' + esc(inp.end_date));
            LISTS.forEach(k => { if (inp[k]) parts.push(esc(LABELS[k]) + ': ' + esc(inp[k].name)); });
            return '<tr' + (x.run_id === state.runId ? ' class="info"' : '') + '><td>' + esc(fmtDate(x.created)) + '</td><td>' + esc(x.title) + '</td><td class="rf-muted">' + (parts.join('<br>') || '&ndash;') + '</td>'
                + '<td><span class="rf-state rf-state-' + esc(x.state) + '">' + esc(x.state) + '</span></td>'
                + '<td class="text-right" style="white-space:nowrap"><button class="btn btn-default btn-xs rf-open-run" data-run="' + esc(x.run_id) + '">Open</button> '
                + (x.zip ? '<a class="btn btn-default btn-xs" href="' + dl(x.run_id, x.zip) + '" title="Download all"><span class="glyphicon glyphicon-download-alt"></span></a> ' : '')
                + (x.state !== 'running' && x.state !== 'waiting' ? '<button class="btn btn-link btn-xs rf-del-run" data-run="' + esc(x.run_id) + '" title="Delete"><span class="glyphicon glyphicon-trash"></span></button>' : '')
                + '</td></tr>';
        }).join('');
        h += '</tbody></table>';
        $('#rf_history').html(h);
    }).fail(() => $('#rf_history').html('<span class="text-danger">Could not load your reports.</span>'));
}

/* ---------------------------------------------------------------- init */

function bind() {
    $('#rf_reports').on('change', 'input[type=checkbox]', function () {
        const name = $(this).val();
        if (this.checked) { if (state.selected.indexOf(name) < 0) state.selected.push(name); }
        else state.selected = state.selected.filter(n => n !== name);
        $(this).closest('.rf-report').toggleClass('on', this.checked);
        updateStep1();
        renderFlow();
    });
    $('#rf_report_search').on('input', renderReports);
    $('.rf-app').on('click', '.rf-next', function () { goto(Number($(this).data('goto'))); });
    $('#rf_stepper').on('click', 'li', function () { goto(Number($(this).data('step'))); });
    $('#rf_start_date, #rf_end_date').on('change input', renderChecklist);
    $('.rf-presets').on('click', 'button', function (e) { e.preventDefault(); setPreset(String($(this).data('preset'))); });
    $('#rf_run_btn').on('click', startRun);
    $('#rf_history_refresh').on('click', loadHistory);
    $('#rf_history').on('click', '.rf-open-run', function () {
        openRun($(this).data('run'));
        goto(3);
        $('html, body').animate({ scrollTop: $('#rf_results').offset().top - 70 }, 300);
    });
    $('#rf_history').on('click', '.rf-del-run', function () {
        const id = $(this).data('run');
        if (!window.confirm('Delete this report and its files?')) return;
        $.ajax({ url: '/ajax/report/delete', type: 'POST', data: { run_id: id }, dataType: 'json' }).done(r => {
            if (r.error) { window.alert(r.error); return; }
            if (id === state.runId) { state.runId = ''; $('#rf_results').html(''); }
            loadHistory();
        });
    });
}

export function init(options) {
    opts = options || {};
    $ = window.jQuery;
    bind();
    renderFlow();
    $.ajax({ url: '/ajax/report/catalog', dataType: 'json' }).done(r => {
        if (r.error) { $('#rf_reports').html('<div class="alert alert-danger">' + esc(r.error) + '</div>'); return; }
        state.catalog = r.reports || [];
        state.email = r.email || '';
        renderReports();
        updateStep1();
    }).fail(() => $('#rf_reports').html('<div class="alert alert-danger">Could not load the reports.</div>'));
    loadHistory();
    if (opts.run_id) {
        openRun(opts.run_id);
        goto(3);
    }
}
