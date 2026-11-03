const fs = require('node:fs');
const vm = require('node:vm');
const test = require('node:test');
const assert = require('node:assert/strict');

const source = fs.readFileSync('mason/breeders_toolbox/trial/download_layout_interface_dialog.mas', 'utf8');
function section(start, end) {
    const a = source.indexOf(start);
    const b = source.indexOf(end, a);
    assert.ok(a >= 0 && b > a, 'owning Mason JavaScript section exists');
    return source.slice(a, b).replaceAll('<% $download_type %>', 'Check');
}
const defaults = section('    // The accession label counter is an independent', '    included_html_<% $download_type %> += \'<h2 id="fieldbook_columns_synonyms_');
const mutations = section('function do_not_include_column_', '% if ($download_type eq \'Fieldbook\')');

test('native layout column controls keep the counter independently selectable', () => {
    const context = {
        selected_columns_Check: {rep_number: 1},
        not_selected_columns_Check: {},
        included_html_Check: '',
        console: {log() {}},
        jQuery: () => ({hide() {}, show() {}, html() {}}),
    };
    vm.createContext(context);
    vm.runInContext(defaults + mutations, context);
    assert.equal(context.selected_columns_Check.accession_occurrence, 1, 'native rich defaults include the independent counter');
    assert.match(context.included_html_Check, /fieldbook_columns_accession_occurrence_Check/, 'the column has an actual visible/removable native control');
    context.do_not_include_column_Check('accession_occurrence');
    assert.equal(context.selected_columns_Check.accession_occurrence, undefined, 'removing counter remains an exact explicit choice');
    assert.equal(context.selected_columns_Check.rep_number, 1, 'counter removal preserves physical design selection');
    context.include_column_Check('accession_occurrence');
    context.do_not_include_column_Check('rep_number');
    assert.equal(context.selected_columns_Check.accession_occurrence, 1, 'counter can remain selected independently of physical replication');
    assert.equal(context.selected_columns_Check.rep_number, undefined, 'including counter does not add physical replication back');
});
