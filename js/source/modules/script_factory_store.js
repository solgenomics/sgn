/*
 * Analysis Pipeline - "Store analysis" form (mason/tools/script_factory/store_dialog.mas)
 *
 * Shared by the builder page (entries/script_factory.js) and the results
 * dashboard (entries/script_factory_results.js). The form is pre-filled from
 * the run; saving posts only the run id and the form fields to
 * /ajax/script_factory/store (the server takes the values and the files from
 * the run itself) and the dialog closes when the analysis is stored.
 *
 * Author: Chris Simoes <ccs263@cornell.edu>
 */

function esc(s) {
    return String(s === null || s === undefined ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// R writes single values as scalars: always work on arrays
function arr(x) {
    return x === null || x === undefined ? [] : Array.isArray(x) ? x : [x];
}

function alertBox(type, html) {
    return '<div class="alert alert-' + type + '" style="margin:10px 0 0">' + html + '</div>';
}

// default name and description of a run
//   res: results of the run (strategy, engine, genetic_model, value_label, summary, stage2)
//   ctx: { scriptName, datasetName, outlierMethod }
export function storeDefaults(res, ctx) {
    const d = new Date();
    const pad = n => String(n).padStart(2, '0');
    const stamp = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    const s = res.summary || {};
    const dsName = ctx.datasetName || 'dataset';
    const engine = res.engine === 'blupf90' ? 'BLUPF90+' : 'R';
    const genetic = { pedigree: 'pedigree (A matrix) breeding values', parents: 'mother and father effects' }[res.genetic_model] || '';
    const h2 = arr(res.stage2).filter(x => x.h2 !== null && x.h2 !== undefined && isFinite(x.h2)).map(x => x.trait + ' ' + Number(x.h2).toFixed(2));
    const desc = (ctx.scriptName ? 'Script "' + ctx.scriptName + '". ' : '') +
        (res.strategy === 'two_stage' ? 'Two-stage' : 'Single-stage') + ' analysis of dataset "' + dsName + '" (' +
        s.n_trials + ' trials, ' + s.n_accessions + ' accessions) with the Breedbase Analysis Pipeline: ' +
        (res.value_label || 'BLUP') + 's fitted with ' + engine + (genetic ? ', ' + genetic : '') +
        (ctx.outlierMethod && ctx.outlierMethod !== 'none' ? ', outliers removed by ' + String(ctx.outlierMethod).toUpperCase() : '') +
        '. Traits: ' + arr(s.traits).join(', ') + '.' + (h2.length ? ' Heritability: ' + h2.join(', ') + '.' : '');
    return { name: (ctx.scriptName || 'Analysis Pipeline') + ' - ' + dsName + ' - ' + stamp, description: desc, year: d.getFullYear() };
}

// Open the form.
//   opts.runId     run to store
//   opts.res       results of the run
//   opts.ctx       see storeDefaults()
//   opts.programs  [{id, name}] breeding programs of the dataset (first one preselected)
//   opts.onStored  function(analysis_id, name) called once stored
// run whose name and description are in the form
let lastRunId = null;

export function openStoreDialog(opts) {
    const $ = window.jQuery;
    const res = opts.res;
    const def = storeDefaults(res, opts.ctx || {});
    // name and description must be written by the user: the suggestions are
    // only placeholders. Text typed for this run is kept if the dialog is reopened.
    if (lastRunId !== opts.runId) {
        $('#sf_store_name').val('');
        $('#sf_store_description').val('');
        lastRunId = opts.runId;
    }
    $('#sf_store_name').attr('placeholder', 'e.g. ' + def.name).closest('.form-group').removeClass('has-error');
    $('#sf_store_description').attr('placeholder', 'e.g. ' + def.description).closest('.form-group').removeClass('has-error');
    $('#sf_store_year').val(def.year);
    $('#sf_store_message').html('');
    $('#sf_store_submit').prop('disabled', false).html('<span class="glyphicon glyphicon-floppy-disk"></span> Save');
    const st = res.store || {};
    const cnt = res.store_counts || {};
    const nAcc = st.accession_names ? arr(st.accession_names).length : (cnt.n_accessions || 0);
    const nTr = st.trait_names ? arr(st.trait_names).length : (cnt.n_traits || 0);
    $('#sf_store_summary').html('<p class="text-muted"><span class="glyphicon glyphicon-info-sign"></span> ' + nAcc + ' accessions &times; ' + nTr + ' trait(s) of ' +
        esc(res.value_label || 'BLUP') + 's will be stored. The script, the input phenotype file, the results and their tables' + (res.engine === 'blupf90' ? ', the BLUPF90+ files' : '') +
        ' are archived with it and can be downloaded from the analysis page (Model Details).</p>' +
        savedAsTable(res.saved_as));
    const blocked = arr(res.saved_as).some(r => r.error);

    // breeding programs: preselect the program of the dataset's trials
    const progs = arr(opts.programs);
    const want = progs.length ? String(progs[0].id) : '';
    $.ajax({ url: '/ajax/html/select/breeding_programs', data: { id: 'sf_store_program_tmp', name: 'sf_store_program_tmp' }, dataType: 'json' })
        .done(r => {
            const found = $('<div>' + ((r && r.select) || '') + '</div>').find('option');
            const sel = $('#sf_store_program').empty();
            if (!want) sel.append('<option value="">Please select a program</option>');
            found.each(function() { if ($(this).val() !== '') sel.append($('<option>').val($(this).val()).text($(this).text())); });
            if (want && sel.find('option[value="' + want + '"]').length) sel.val(want);
        })
        .fail(() => {
            $('#sf_store_program').html(progs.map(p => '<option value="' + esc(p.id) + '">' + esc(p.name) + '</option>').join('') || '<option value="">No breeding program found</option>');
        });

    $('#sf_store_submit').off('click.sfstore').on('click.sfstore', () => submit(opts)).prop('disabled', blocked);
    $('#sf_store_modal').modal('show');
}

// Stored values are not measurements of the trait: each trait is stored as a
// post-composed trait (trait + statistical term), chosen by the server.
//   rows: [{trait, statistical_term_name, saved_as, is_new, error}]
export function savedAsTable(rows) {
    rows = arr(rows);
    if (!rows.length) return '';
    const short = t => String(t || '').replace(/\|[^|]+$/, '');
    const body = rows.map(r => '<tr><td>' + esc(short(r.trait)) + '</td><td>' +
        (r.error
            ? '<span class="text-danger"><span class="glyphicon glyphicon-warning-sign"></span> ' + esc(r.error) + '</span>'
            : r.not_stored
            ? '<span class="text-muted">Not stored: ' + esc(r.not_stored) + '</span>'
            : '<b>' + esc(short(r.saved_as)) + '</b>' + (r.is_new ? ' <span class="label label-info">new trait</span>' : '')) +
        '</td></tr>').join('');
    return '<p style="margin-bottom:4px"><b>Values will be saved as</b> <span class="text-muted">(the trait combined with how its values were computed, so the measured trait is not changed)</span></p>' +
        '<table class="table table-condensed table-bordered" style="font-size:12px"><thead><tr><th>Trait</th><th>Saved as</th></tr></thead><tbody>' + body + '</tbody></table>';
}

function submit(opts) {
    const $ = window.jQuery;
    const name = $.trim($('#sf_store_name').val());
    const description = $.trim($('#sf_store_description').val());
    const program = $('#sf_store_program').val();
    const year = $.trim($('#sf_store_year').val());
    const msg = (type, h) => $('#sf_store_message').html(alertBox(type, h));
    $('#sf_store_name').closest('.form-group').toggleClass('has-error', !name);
    $('#sf_store_description').closest('.form-group').toggleClass('has-error', !description);
    if (!name || !description) {
        (!name ? $('#sf_store_name') : $('#sf_store_description')).trigger('focus');
        return msg('warning', 'Please write ' + (!name && !description ? 'a name and a description' : !name ? 'a name' : 'a description') + ' for the analysis (they identify it in Breedbase).');
    }
    if (!program) return msg('warning', 'Please choose a breeding program.');
    if (!/^\d{4}$/.test(year)) return msg('warning', 'Please give the year (e.g. ' + new Date().getFullYear() + ').');
    if (!opts.runId) return msg('danger', 'This run cannot be stored (no run id); please run the analysis again.');

    const button = $('#sf_store_submit');
    button.prop('disabled', true).html('<span class="glyphicon glyphicon-refresh"></span> Saving...');
    $.ajax({
        url: '/ajax/script_factory/store', type: 'POST', dataType: 'json',
        data: { run_id: opts.runId, name: name, description: description, year: year, breeding_program_id: program, is_public: $('#sf_store_public').val() }
    })
        .done(r => {
            if (r && r.error) { msg('danger', esc(r.error)); return; }
            $('#sf_store_modal').modal('hide');
            if (opts.onStored) opts.onStored(r.analysis_id, name);
        })
        .fail((xhr, status, err) => msg('danger', 'Server error: ' + esc(err || status)))
        .always(() => button.prop('disabled', false).html('<span class="glyphicon glyphicon-floppy-disk"></span> Save'));
}

// "Stored" notice with a link to the analysis
export function storedNotice(analysisId, name) {
    return alertBox('success', '<span class="glyphicon glyphicon-ok"></span> Stored as analysis <b>' + esc(name || '') + '</b>.' +
        (analysisId ? ' <a href="/analyses/' + encodeURIComponent(analysisId) + '" target="_blank">Open the analysis</a>' : ''));
}
