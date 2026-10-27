'use strict';
// Execute the real current-upstream page script with vendored jQuery. Only
// transport and the DataTables plugin are controlled; no image job is started.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const root = path.resolve(__dirname, '../../..');
const I18N = require('../../../static/js/sgn-i18n.js');
const source = fs.readFileSync(path.join(root, 'mason/breeders_toolbox/image_analysis_run.mas'), 'utf8');
const script = source.match(/<script defer="defer">([\s\S]*?)<\/script>/)[1]
    .replace(/<% \$run_project_id %>/g, '73');
assert(!script.includes('<%'), 'All server expressions have explicit controlled inputs');
const hostile = '<img src=x onerror="window.injected=1"> & %{other}';
const labelHostile = hostile.replace('%{other}', 'literal');
const plain = x => JSON.parse(JSON.stringify(x));
function translator(locale) {
    const messages = {};
    for (const [context, english] of [
        ['image_analysis.run.source_image', 'Source Image'],
        ['image_analysis.run.no_overlay_image', 'No overlay image.'],
        ['image_analysis.run.loading_results', 'Loading results…'],
        ['image_analysis.run.could_not_load_the_image_list', 'Could not load the image list.'],
        ['image_analysis.run.could_not_load_results_for_this_image', 'Could not load results for this image.']
    ]) messages[context + '\x04' + english] = {plural:null, forms:[locale + ': ' + labelHostile]};
    return new I18N({locale, dir:locale === 'ar' ? 'rtl' : 'ltr', domain:'sgn', catalogs: locale === 'en' ? [] : [{
        schema:1, api:1, locale, direction:locale === 'ar' ? 'rtl' : 'ltr', sourceRevision:'0'.repeat(64),
        nplurals:1, pluralForms:'nplurals=1; plural=0;', pluralAst:I18N.parsePlural('nplurals=1; plural=0;').ast, messages
    }]});
}
function setup(locale) {
    const ids = ['run_images_summary_loading', 'per_image_results_loading', 'per_image_empty',
        'run_images_summary_table', 'run_image_count', 'run_sample_count', 'run_trial_links', 'per_image_accordion',
        'meta_pipeline_name', 'meta_pipeline_version', 'meta_job_id', 'meta_timestamp', 'meta_input_filename', 'meta_qc_json'];
    const dom = new JSDOM('<!doctype html><html><body>' + ids.map(id => id.endsWith('_table') ?
        '<table id="'+id+'"><tbody></tbody></table>' : '<div id="'+id+'"></div>').join('') +
        '<div id="analysis_info_json_data"></div></body></html>', {url:'https://example.invalid/image_analysis/run/73', runScripts:'outside-only'});
    const w = dom.window;
    w.eval(fs.readFileSync(path.join(root, 'js/source/legacy/jquery.js'), 'utf8'));
    const $ = w.jQuery, requests = [], tables = [];
    $.fn.ready = function (callback) { callback(); return this; };
    $.ajax = options => { requests.push(options); return {}; };
    $.fn.DataTable = function (options) { tables.push(options); return {}; };
    $.fn.DataTable.isDataTable = () => false;
    w.console.error = () => {};
    w.SGN = {i18n:translator(locale)};
    $('#analysis_info_json_data').text(JSON.stringify({analysis_metadata:{
        pipeline_name:hostile, pipeline_version:'1.2', job_id:'00073', timestamp:'2026-10-27T00:00:00Z',
        input_filename:'Жито_%{name}.tif', qc_json:{mean:'0.00', CV:'NA'}
    }}));
    w.eval(script);
    return {w, $, requests, tables, close:() => w.close()};
}
for (const locale of ['en', 'uk', 'es', 'ar']) {
    test(locale + ': current image request, identifiers, metadata and numeric values remain data', () => {
        const h = setup(locale);
        try {
            assert.equal(h.requests.length, 1);
            assert.equal(h.requests[0].url, '/ajax/image_analysis/run_images');
            assert.equal(h.requests[0].method, 'GET');
            assert.deepEqual(plain(h.requests[0].data), {run_project_id:'73'});
            assert.equal(h.$('#meta_pipeline_name').text(), hostile);
            assert.equal(h.$('#meta_job_id').text(), '00073');
            assert.equal(h.$('#meta_input_filename').text(), 'Жито_%{name}.tif');
            assert.equal(h.$('#meta_qc_json').text(), 'mean: 0.00\nCV: NA');
            h.requests[0].success({images:[{source_image_id:41, source_image_filename:hostile,
                source_stock_id:52, source_stock_name:hostile, tissue_sample_count:0,
                trial_id:63, trial_name:hostile}]});
            assert.equal(h.$('#run_image_count').text(), '1');
            assert.equal(h.$('#run_sample_count').text(), '0');
            assert.equal(h.$('#run_images_summary_table .jump-to-image').text(), hostile);
            assert.equal(h.$('#run_trial_links a').attr('href'), '/breeders/trial/63');
            assert.equal(h.$('#run_trial_links a').text(), hostile);
            assert.equal(h.requests.length, 2);
            assert.equal(h.requests[1].url, '/ajax/image_analysis/run_image_results');
            assert.deepEqual(plain(h.requests[1].data), {run_project_id:'73', source_image_id:41});
            const data = [{observationUnitName:hostile, observationVariableName:'CO_336:9990004', numberAnalyzed:0, value:'0.000'}];
            h.requests[1].success({table_data:data});
            assert.deepEqual(plain(h.tables[0].data), data);
            assert.deepEqual(plain(h.tables[0].columns.map(x=>x.data)), [null,'observationUnitName','observationVariableName','numberAnalyzed','value']);
            assert.equal(h.$('[onerror]').length, 0, 'Translated labels and data do not create HTML');
            assert.equal(h.w.injected, undefined);
        } finally { h.close(); }
    });
    test(locale + ': translated transport error remains plain text', () => {
        const h = setup(locale);
        try {
            h.requests[0].error({responseText:'controlled offline failure'});
            assert.equal(h.$('#per_image_empty').text(), locale === 'en' ? 'Could not load the image list.' : locale + ': ' + labelHostile);
            assert.equal(h.$('[onerror]').length, 0);
        } finally { h.close(); }
    });
}
