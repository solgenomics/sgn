=head1 NAME

t/unit/js/legacy/CXGN/Stock.t - Stock pedigree dialog with bundled jQuery

=head1 DESCRIPTION

Exercises the real dialog markup and JavaScript in jsdom: parent roles, explicit
cross types, preserved historical values, error recovery, one POST per save and
role-specific removal. Database and HTTP behavior have separate fixture tests.

=cut

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use JSON;
my $node = `which node 2>/dev/null`;
chomp $node;
plan skip_all => 'node is not installed' unless $node;
plan skip_all => 'jsdom is not installed (run npm install in js/)' unless -d 'js/node_modules/jsdom';
my ($fh, $path) = tempfile(SUFFIX => '.cjs', UNLINK => 1);
print $fh do { local $/; <DATA> };
close $fh;
open my $out, '-|', $node, $path, 'js', 'mason/pedigree/stock_pedigree.mas' or die "Cannot run node: $!";
my $output = do { local $/; <$out> };
close $out;
my $result = eval { decode_json($output) };
BAIL_OUT("Dialog harness failed: $output") unless ref($result) eq 'HASH';
for my $name (sort keys %$result) { ok($result->{$name}, $name); }
done_testing;

__DATA__
const fs = require('fs');
const path = require('path');
const js = path.resolve(process.argv[2]);
const { JSDOM, VirtualConsole } = require(path.join(js, 'node_modules', 'jsdom'));
const source = fs.readFileSync(process.argv[3], 'utf8');
const markup = source.substring(source.indexOf('<div class="modal fade" id="add_parent_dialog"'), source.indexOf('<& /util/import_javascript.mas'));
const dom = new JSDOM(markup + '<button id="add_parent_link"></button><div id="remove_parent_list"></div><div id="remove_parent_dialog"></div>', {
    runScripts: 'outside-only', url: 'http://localhost:3010', virtualConsole: new VirtualConsole()
});
const w = dom.window;
w.eval(fs.readFileSync(path.join(js, 'source/legacy/jquery.js'), 'utf8'));
const $ = w.jQuery;
$.fn.autocomplete = function(options) { return this.data('autocompleteOptions', options); };
$.fn.modal = function(action) { this.toggle(action === 'show'); return this; };
$.fn.dialog = function() { return this; };
w.alert = function() {};
w.confirm = function() { return true; };
let saved = [];
let loadError = false;
const requests = [];
$.getJSON = function(url) {
    const d = $.Deferred();
    if (url === '/ajax/stock/parents') {
        if (loadError) { d.reject(); } else { d.resolve({ relationships: saved }); }
    } else if (url === '/ajax/stock/population_autocomplete') {
        d.resolve(['Population A', 'Parent A'], 'success', {});
    } else {
        d.resolve(['Parent A', 'Parent B'], 'success', {});
    }
    return d.promise();
};
$.ajax = function(options) { requests.push(options); };
w.eval(fs.readFileSync(path.join(js, 'source/legacy/CXGN/Stock.js'), 'utf8'));
w.stock_pedigree_dialog_init('999');
const result = {};
const female = $('#add_parent_female');
const male = $('#add_parent_male');
const type = $('#add_parent_cross_type');
const save = $('#add_parent_submit');
const error = $('#add_parent_error');
function open(rows) { saved = rows || []; $('#add_parent_link').trigger('click'); }
function submit() { $('#add_parent_dialog_form').trigger('submit'); }
open();
result['three separate inputs replace the old role radios'] = female.length === 1 && male.length === 1 && type.length === 1 && $('input[name="parent_type"]').length === 0;
result['a new pedigree has no inferred default type'] = type.val() === '';
result['the simple dialog includes backcross and excludes bulk and generators'] = type.find('option[value="backcross"]').length === 1 && type.find('option[value="bulk"], option[value="reciprocal"], option[value="multicross"]').length === 0;
female.val('Parent A & B');
male.val('Parent B');
type.val('biparental').trigger('change');
result['biparental marks the male input as required'] = male.prop('required');
type.val('open').trigger('change');
result['open keeps the male field available and optional'] = !male.prop('required') && male.val() === 'Parent B';
type.val('self').trigger('change');
submit();
result['self with different parents does not send a request'] = requests.length === 0 && error.text().includes('same parent');
type.val('biparental').trigger('change');
submit();
submit();
result['one asynchronous POST saves both parents and blocks duplicate clicks'] = requests.length === 1 && requests[0].type === 'POST' && requests[0].url.endsWith('add_stock_parents') && requests[0].async !== false && save.prop('disabled');
result['parent names remain separate data fields for safe serialization'] = requests[0].data.female_parent === 'Parent A & B' && requests[0].data.male_parent === 'Parent B' && typeof requests[0].data === 'object';
requests[0].success({ error: '<script>invalid name</script>' });
requests[0].complete();
result['server errors are text and leave the form available for correction'] = error.text() === '<script>invalid name</script>' && error.find('script').length === 0 && !save.prop('disabled') && female.val() === 'Parent A & B';
open([{ parent_type: 'female', parent_name: 'Recorded mother', cross_type: 'derived' }]);
result['existing identities and nonstandard historical type are read-only'] = female.prop('readOnly') && !male.prop('readOnly') && type.val() === 'derived' && type.prop('disabled');
open([{ parent_type: 'female', parent_name: 'Recorded mother', cross_type: null }]);
result['unknown historical type stays unspecified and may be supplied explicitly'] = type.val() === '' && !type.prop('disabled') && type.find('option:selected').text().includes('Unspecified');
male.val('Recorded father');
submit();
result['completing an unknown pedigree does not invent biparental'] = requests[1].data.cross_type === '' && requests[1].data.female_parent === 'Recorded mother';
requests[1].error();
requests[1].complete();
result['network failure restores the save button'] = !save.prop('disabled') && error.text().includes('error occurred');
open([{ parent_type: 'male', parent_name: 'Recorded father', cross_type: 'old_value' }]);
result['male-only legacy record loads without inferring a type'] = !female.prop('readOnly') && male.prop('readOnly') && type.val() === '';
open([{ parent_type: 'female', parent_name: 'A', cross_type: 'open' }, { parent_type: 'female', parent_name: 'B', cross_type: 'open' }]);
result['duplicate saved roles block editing rather than choosing one'] = save.prop('disabled') && error.text().includes('More than one');
loadError = true;
open();
result['loading failure cannot submit an empty replacement pedigree'] = save.prop('disabled') && error.text().includes('Could not load');
loadError = false;
open();
let matches;
male.data('autocompleteOptions').source({ term: 'Parent' }, function(data) { matches = data; });
result['autocomplete combines standard accessions and populations without duplicates'] = JSON.stringify(matches) === JSON.stringify(['Parent A', 'Parent B', 'Population A']);
w.get_remove_parents_list('999');
const load = requests[requests.length - 1];
load.success({ relationships: [
    { parent_id: 10, parent_name: '<b>same parent</b>', parent_type: 'female' },
    { parent_id: 10, parent_name: '<b>same parent</b>', parent_type: 'male' }
] });
result['removal displays both roles and treats names as text'] = $('#remove_parent_list a').length === 2 && $('#remove_parent_list b').length === 0 && $('#remove_parent_list').text().includes('(female)') && $('#remove_parent_list').text().includes('(male)');
$('#remove_parent_list a').eq(1).trigger('click');
const removal = requests[requests.length - 1];
result['removal posts the chosen role even when the parent ID is identical'] = removal.type === 'POST' && removal.data.parent_id === 10 && removal.data.parent_type === 'male';
w.close();
process.stdout.write(JSON.stringify(result));
