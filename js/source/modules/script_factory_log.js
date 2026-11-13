/*
 * Analysis Pipeline - analysis log
 *
 * The R pipeline reports every adaptation it makes to the data (design
 * factors left out, SpATS replaced by the design model, trials without an
 * error variance, zero variance components ...) as a flat list of
 * "warnings". Most of them are routine and expected, so they are not shown
 * as an alarming alert: they go to a separate, calm "Analysis log", grouped
 * by kind with a plain-language explanation. Only messages that change what
 * was analysed (a model that failed, a trial or trait left out, a software
 * fallback) are surfaced next to the results as "needs your attention".
 *
 * Shared by the builder page (entries/script_factory.js) and the results
 * dashboard (entries/script_factory_results.js).
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function arr(x) {
    return x === null || x === undefined ? [] : Array.isArray(x) ? x : [x];
}

// kinds of messages, in display order. `match` decides the group, `split`
// turns a message into { where, detail } for a compact table (the full
// message is kept as the row tooltip and in the downloaded log).
const GROUPS = [
    {
        key: 'attention', attention: true,
        title: 'Needs your attention',
        help: 'These change what was analysed: a model that could not be fitted, data that were skipped or a software fallback.',
        match: m => /could not be fitted \(|the model failed|model could not be fitted|not installed|treated as unrelated|was skipped|were skipped|index skipped|could not be packed|requires an enabled|needs at least|from the formula|cannot fit .*lme4 was used|all accessions were used instead|zones rest on only|model could not be used \(|genotypes of the genotyping protocol could not be retrieved|no marker passed/i.test(m) && !/accessions have no genotypes in /.test(m) && !/AI-REML|EM-REML/.test(m) && !/^SpATS could not be fitted for/.test(m)
    },
    {
        key: 'design', title: 'Design factors not used in the model',
        help: 'The field layout of these trials does not support the factor (for example, test entries appear in one replicate only), so it was left out. This is normal for augmented and unreplicated designs.',
        match: m => /: not used as model factor\(s\): /.test(m),
        split: m => { const r = /^(.+?): not used as model factor\(s\): (.+?)\.?$/.exec(m); return r && { where: r[1], detail: r[2] }; }
    },
    {
        key: 'fallback', title: 'Model replaced by a simpler one',
        help: 'The spatial (SpATS) model could not separate the field trend from the genotypes in these trials, usually because of the layout. The trial was analysed with its design model instead, so it is still in the results.',
        match: m => /^SpATS could not be fitted for |^BLUPF90\+ could not fit .*lme4 was used|: SpATS does not model repeated measurements|^SpATS \(an R package\) is not part of the BLUPF90\+ engine|could not be fitted by BLUPF90\+ .*a simpler model was used/.test(m),
        split: m => {
            let r = /^SpATS could not be fitted for (.+?) \(.*\); the (.+?) model was used instead\.?$/.exec(m);
            if (r) return { where: r[1], detail: r[2] + ' model used' };
            if (/^SpATS \(an R package\)/.test(m)) return { where: 'trials with rows and columns', detail: 'BLUPF90+ engine: row / column effects and linear trends instead of SpATS' };
            r = /^Stage 1, (.+?): the (.+?) model could not be fitted by BLUPF90\+/.exec(m);
            if (r) return { where: r[1], detail: r[2] + ' model failed; simpler model used' };
            r = /^(.+?): SpATS does not model repeated measurements/.exec(m);
            if (r) return { where: r[1], detail: 'repeated measurements: design model with date and plot effects in stage 1' };
            r = /^BLUPF90\+ could not fit (.+?) \(.*\); lme4 was used/.exec(m);
            return r && { where: r[1], detail: 'lme4 used instead of BLUPF90+' };
        }
    },
    {
        key: 'noerror', title: 'Trials without an error estimate',
        help: 'Too few replicated plots to estimate the residual variance. The accession means of these trials were used, without standard errors (they get an average weight in stage 2).',
        match: m => /no error variance can be estimated/.test(m),
        split: m => { const r = /^(.+?): no error variance can be estimated \((.+)\); /.exec(m); return r && { where: r[1], detail: r[2] }; }
    },
    {
        key: 'convergence', title: 'Convergence notes',
        help: 'How the variance estimation (REML) of some fits ended. Reaching the round limit with settled estimates is harmless; a fit that did not settle was refitted with EM-REML first, which is steadier when a variance is close to zero (a replicate or block effect the trial hardly has).',
        match: m => /AI-REML|EM-REML/.test(m),
        split: m => {
            const r = /^(.+?): (.+?)\.?$/.exec(m);
            if (!r) return null;
            const d = r[2];
            const detail = /already settled/.test(d) ? 'round limit reached with settled estimates: reliable'
                : /which converged/.test(d) ? 'refitted with EM-REML first: converged'
                : /still changing/.test(d) ? 'still changing after the EM-REML refit: variance estimates approximate'
                : /before full convergence/.test(d) ? 'stopped at the round limit (run before this check was added)' : d;
            return { where: r[1], detail: detail };
        }
    },
    {
        key: 'variance', title: 'Model terms simplified',
        help: 'Terms that the data could not estimate (zero variance, confounded or constant) have no effect on the results and were dropped or reported here.',
        match: m => /zero variance|confounded|left out of the model|left out \(|varies within trial|not supported by the data|cannot be separated|Stage [12], /i.test(m) && !/without a covariate value/.test(m),
        split: m => { const r = /^(Stage [12], .+?|[^:]+): (.+?)\.?$/.exec(m); return r && { where: r[1], detail: r[2] }; }
    },
    {
        key: 'data', title: 'Data left out',
        help: 'Records that could not be used by a step (missing values, non-plot observations, treatments listed as traits).',
        match: m => /left out of the|were ignored|is a treatment, not a trait|without values|left out for this trait|without a covariate value|accessions have no genotypes in /i.test(m)
    },
    { key: 'other', title: 'Other notes', help: '', match: () => true }
];

function classify(warnings) {
    const groups = GROUPS.map(g => ({ g: g, items: [] }));
    arr(warnings).forEach(w => {
        const m = String(w);
        const hit = groups.find(x => x.g.match(m));
        hit.items.push(m);
    });
    return groups.filter(x => x.items.length);
}

function groupBody(x) {
    const rows = x.items.map(m => x.g.split ? x.g.split(m) : null);
    if (rows.every(r => r)) {
        return '<table class="table table-condensed sf-log-table"><tbody>' + rows.map((r, i) =>
            '<tr title="' + esc(x.items[i]) + '"><td class="sf-log-where">' + esc(r.where) + '</td><td>' + esc(r.detail) + '</td></tr>').join('') + '</tbody></table>';
    }
    return '<ul class="sf-log-list">' + x.items.map(m => '<li>' + esc(m) + '</li>').join('') + '</ul>';
}

const STYLE = '<style id="sf_log_style">' +
    '.sf-log-intro { color:#4b5563; font-size:13px; margin:0 0 10px; }' +
    '.sf-log-group { border:1px solid #e5e7eb; border-radius:8px; margin-bottom:8px; background:#fff; }' +
    '.sf-log-group.sf-log-attention { border-color:#f0c36d; background:#fffbf0; }' +
    '.sf-log-head { display:flex; align-items:center; gap:8px; padding:8px 12px; cursor:pointer; color:#1f2937; text-decoration:none !important; }' +
    '.sf-log-head .badge { background:#9ca3af; }' +
    '.sf-log-attention .sf-log-head .badge { background:#d97706; }' +
    '.sf-log-head .caret { margin-left:auto; }' +
    '.sf-log-help { color:#6b7280; font-size:12.5px; margin:0 12px 6px; }' +
    '.sf-log-table { margin:0 0 6px; font-size:12.5px; } .sf-log-table td { border-top-color:#f1f1f1 !important; }' +
    '.sf-log-where { white-space:nowrap; font-family:monospace; color:#374151; width:1%; padding-left:12px !important; }' +
    '.sf-log-list { font-size:12.5px; margin:0 12px 8px; padding-left:18px; }' +
    '.sf-log-summary { color:#4b5563; font-size:13px; margin:10px 0 0; }' +
    '</style>';

function ensureStyle() {
    if (typeof document !== 'undefined' && !document.getElementById('sf_log_style')) document.head.insertAdjacentHTML('beforeend', STYLE);
}

// the full log: grouped, collapsible, with a download of the raw messages
//   prefix: unique id prefix for the collapsible parts
export function analysisLogHtml(warnings, prefix) {
    ensureStyle();
    const w = arr(warnings);
    if (!w.length) return '<p class="sf-log-intro"><span class="glyphicon glyphicon-ok" style="color:#2b7a4b"></span> The analysis ran without any notes.</p>';
    const groups = classify(w);
    const txt = 'data:text/plain;charset=utf-8,' + encodeURIComponent(w.join('\n') + '\n');
    let h = '<p class="sf-log-intro">How the analysis adapted to the data. Most of these notes are routine: the results already take them into account. ' +
        '<a href="' + txt + '" download="analysis_log.txt" style="white-space:nowrap"><span class="glyphicon glyphicon-download-alt"></span> Download log</a></p>';
    groups.forEach((x, i) => {
        const id = prefix + '_log_' + x.g.key;
        const open = x.g.attention;
        h += '<div class="sf-log-group' + (x.g.attention ? ' sf-log-attention' : '') + '">' +
            '<a class="sf-log-head" data-toggle="collapse" href="#' + id + '">' +
            (x.g.attention ? '<span class="glyphicon glyphicon-exclamation-sign" style="color:#d97706"></span>' : '<span class="glyphicon glyphicon-info-sign" style="color:#9ca3af"></span>') +
            '<b>' + esc(x.g.title) + '</b> <span class="badge">' + x.items.length + '</span><span class="caret"></span></a>' +
            '<div id="' + id + '" class="collapse' + (open ? ' in' : '') + '">' +
            (x.g.help ? '<p class="sf-log-help">' + esc(x.g.help) + '</p>' : '') + groupBody(x) + '</div></div>';
    });
    return h;
}

// the short line next to the results: only messages that need attention are
// shown in full, the rest is a count with a link to the log
//   the "Analysis log" link has class sf-open-log: the page decides where it goes
export function analysisLogSummaryHtml(warnings) {
    ensureStyle();
    const w = arr(warnings);
    if (!w.length) return '';
    const groups = classify(w);
    const att = groups.filter(x => x.g.attention);
    const nAtt = att.reduce((a, x) => a + x.items.length, 0);
    const nRoutine = w.length - nAtt;
    let h = '';
    if (nAtt) {
        h += '<div class="alert alert-warning" style="margin:10px 0 0"><b><span class="glyphicon glyphicon-exclamation-sign"></span> ' + nAtt + ' note(s) need your attention:</b>' +
            '<ul style="margin:4px 0 0">' + att.map(x => x.items.map(m => '<li>' + esc(m) + '</li>').join('')).join('') + '</ul></div>';
    }
    if (nRoutine) {
        const kinds = groups.filter(x => !x.g.attention).map(x => x.g.title.toLowerCase() + ' (' + x.items.length + ')');
        h += '<p class="sf-log-summary"><span class="glyphicon glyphicon-info-sign" style="color:#9ca3af"></span> ' +
            '<a href="#" class="sf-open-log">Analysis log</a>: ' + nRoutine + ' routine note(s) on how the model adapted to the data &ndash; ' + esc(kinds.join(', ')) + '.</p>';
    }
    return h;
}
