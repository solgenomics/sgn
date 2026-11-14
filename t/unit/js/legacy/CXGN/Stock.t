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
const jquery = fs.readFileSync(path.join(js, 'source/legacy/jquery.js'), 'utf8');
const stock = fs.readFileSync(path.join(js, 'source/legacy/CXGN/Stock.js'), 'utf8');
const result = {};
function harness() {
    const dom = new JSDOM(markup + '<button id="add_parent_link"></button><div id="remove_parent_list"></div><div id="remove_parent_dialog"></div>', {
        runScripts: 'outside-only', url: 'http://localhost:3010', virtualConsole: new VirtualConsole()
    });
    const w = dom.window;
    w.eval(jquery);
    const $ = w.jQuery;
    $.fn.autocomplete = function(options) {
        return typeof options === 'object' ? this.data('autocompleteOptions', options) : this;
    };
    $.fn.modal = function(action) {
        if (action === 'hide') { this.trigger('hide.bs.modal'); }
        return this.toggle(action === 'show');
    };
    $.fn.dialog = function() { return this; };
    const alerts = [], requests = [];
    w.alert = value => alerts.push(value);
    w.confirm = () => true;
    $.ajaxTransport('+*', function(options) {
        let record;
        return {
            send: function(headers, complete) { record = { options, complete, aborted: false }; requests.push(record); },
            abort: function() { if (record) { record.aborted = true; } }
        };
    });
    w.eval(stock);
    w.stock_pedigree_dialog_init('999');
    return {
        w, $, requests, alerts,
        open() { $('#add_parent_link').trigger('click'); },
        close() { $('#add_parent_dialog').modal('hide'); },
        submit() { $('#add_parent_dialog_form').trigger('submit'); },
        fill(female, male, type) {
            $('#add_parent_female').val(female).trigger('input');
            $('#add_parent_male').val(male).trigger('input');
            $('#add_parent_cross_type').val(type).trigger('change');
        },
        finish(index, value, contentType = 'application/json') {
            const text = contentType === 'application/json' ? JSON.stringify(value) : value;
            try { requests[index].complete(200, 'OK', {text}, 'Content-Type: ' + contentType); return null; }
            catch (error) { return String(error); }
        },
        fail(index) { requests[index].complete(0, 'error', {}, ''); },
        params(index) { return new URLSearchParams(requests[index].options.data); }
    };
}
const rows = [
    { parent_type: 'female', parent_id: 101, parent_name: 'Mother', cross_type: 'biparental' },
    { parent_type: 'male', parent_id: 202, parent_name: 'Father', cross_type: null }
];
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships: []});
    result['new pedigree has separate fields and no inferred cross type'] = $('#add_parent_female').length === 1 && $('#add_parent_male').length === 1 && $('#add_parent_cross_type').val() === '' && $('input[name="parent_type"]').length === 0;
    result['unchanged empty form does not offer a redundant save'] = $('#add_parent_submit').prop('disabled');
    result['simple pedigree types include backcross and exclude generators'] = $('#add_parent_cross_type option[value="backcross"]').length === 1 && $('#add_parent_cross_type option[value="bulk"], #add_parent_cross_type option[value="reciprocal"], #add_parent_cross_type option[value="multicross"]').length === 0;
    h.fill('Mother & A', 'Father', 'biparental');
    result['biparental requires the editable male field'] = $('#add_parent_male').prop('required');
    $('#add_parent_cross_type').val('open').trigger('change');
    result['open keeps a supplied male available and optional'] = !$('#add_parent_male').prop('required') && $('#add_parent_male').val() === 'Father';
    $('#add_parent_cross_type').val('self').trigger('change'); h.submit();
    result['unselected self names reach server resolution without parent inference'] = h.requests.length === 2 && h.params(1).get('female_parent') === 'Mother & A' && h.params(1).get('male_parent') === 'Father';
    h.finish(1, {error:'The resolved self parents must be the same stock.'});
    $('#add_parent_cross_type').val('biparental').trigger('change'); h.submit(); h.submit();
    result['double submit produces only one asynchronous paired POST'] = h.requests.length === 3 && h.requests[2].options.type === 'POST' && $('#add_parent_submit').prop('disabled');
    result['real jQuery serializes special characters in separate fields'] = h.params(2).get('female_parent') === 'Mother & A' && h.params(2).get('male_parent') === 'Father';
    h.finish(2, {error: '<script>invalid name</script>'});
    result['definitive server error preserves editable input and is escaped'] = $('#add_parent_error').text() === '<script>invalid name</script>' && $('#add_parent_error script').length === 0 && !$('#add_parent_submit').prop('disabled') && !$('#add_parent_female').prop('disabled') && $('#add_parent_female').val() === 'Mother & A';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.close(); h.open();
    result['closing aborts the obsolete parents GET'] = h.requests[0].aborted;
    h.finish(1, {relationships: [{parent_type:'female', parent_id:101, parent_name:'Current mother', cross_type:'open'}]});
    h.finish(0, {relationships: [{parent_type:'female', parent_id:10, parent_name:'Stale mother', cross_type:'self'}]});
    result['late old GET cannot replace a newer dialog identity or type'] = $('#add_parent_female').val() === 'Current mother' && $('#add_parent_cross_type').val() === 'open' && $('#add_parent_female').prop('readOnly');
    result['parents GET bypasses browser cache'] = h.requests[1].options.cache === false;
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships: []}); h.fill('Mother', 'Father', 'biparental'); h.submit();
    h.close(); h.open(); h.submit();
    result['pending save survives close without aborting its POST'] = !h.requests[1].aborted;
    result['reopening during save cannot load or submit another editable form'] = h.requests.length === 2 && $('#add_parent_female').prop('disabled') && $('#add_parent_submit').prop('disabled');
    h.finish(1, {success:1});
    result['old save success reconciles reopened dialog without old success alert'] = h.alerts.length === 0 && h.requests.length === 3 && h.requests[2].options.type === 'GET' && $('#add_parent_submit').prop('disabled');
    h.finish(2, {relationships:rows});
    result['reconciled complete record is readonly with no redundant save'] = $('#add_parent_female').prop('readOnly') && $('#add_parent_male').prop('readOnly') && $('#add_parent_cross_type').prop('disabled') && $('#add_parent_submit').prop('disabled');
    h.w.close();
}
for (const [name, body, mime] of [['null', null, 'application/json'], ['empty object', {}, 'application/json'], ['HTML', '<html>Login</html>', 'text/html']]) {
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships: []}); h.fill('Mother', 'Father', 'biparental'); h.submit();
    const thrown = h.finish(1, body, mime);
    result[name + ' save response is never a false success or callback exception'] = !thrown && h.alerts.length === 0;
    result[name + ' uncertain save forces a status GET before retry'] = h.requests.length === 3 && h.requests[2].options.type === 'GET' && $('#add_parent_submit').prop('disabled') && $('#add_parent_female').prop('disabled');
    h.finish(2, {relationships:rows});
    result[name + ' save already recorded on server is not submitted twice'] = $('#add_parent_submit').prop('disabled') && $('#add_parent_female').prop('readOnly') && $('#add_parent_error').text().includes('uncertain');
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships: []}); h.fill('Mother', 'Father', 'biparental'); h.submit();
    h.fail(1); h.fail(2); h.submit();
    result['failed status reload keeps retry blocked after an uncertain save'] = h.requests.length === 3 && $('#add_parent_submit').prop('disabled');
    h.open(); h.finish(3, {relationships: []}); h.fill('Mother', 'Father', 'biparental'); h.submit();
    result['retry becomes available only after authoritative status reload'] = h.requests.length === 5 && h.requests[4].options.type === 'POST';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); const thrown = h.finish(0, null);
    result['null load is a visible failure with disabled save and no exception'] = !thrown && $('#add_parent_submit').prop('disabled') && $('#add_parent_error').text().includes('Could not read');
    h.open(); h.finish(1, {relationships:[rows[0],rows[0]]});
    result['duplicate recorded roles cannot be silently selected'] = $('#add_parent_submit').prop('disabled') && $('#add_parent_error').text().includes('ambiguous');
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships: []});
    const femaleOptions = $('#add_parent_female').data('autocompleteOptions');
    const maleOptions = $('#add_parent_male').data('autocompleteOptions');
    let matches;
    femaleOptions.source({term:'Same'}, value => {matches=value;});
    maleOptions.source({term:'Father'}, () => {});
    result['autocomplete makes one role-specific request per field'] = h.requests.length === 3 && h.requests[1].options.url.includes('parent_type=female') && h.requests[2].options.url.includes('parent_type=male');
    const items = [{id:101,value:'Same',label:'Same (accession, crop A)'},{id:102,value:'Same',label:'Same (accession, crop B)'}];
    h.finish(1, items); h.finish(2, [{id:202,value:'Father',label:'Father'}]);
    result['ambiguous names retain distinct stock IDs and informative labels'] = matches.length === 2 && matches[0].id !== matches[1].id && matches[0].label !== matches[1].label;
    femaleOptions.select({}, {item:items[1]}); maleOptions.select({}, {item:{id:202,value:'Father'}});
    $('#add_parent_cross_type').val('biparental').trigger('change'); h.submit();
    result['autocomplete-selected IDs accompany names in POST'] = h.params(3).get('female_parent_id') === '102' && h.params(3).get('male_parent_id') === '202';
    h.finish(3, {error:'Review the chosen mother'});
    $('#add_parent_female').val('Different name').trigger('input'); h.submit();
    result['editing a selected name drops only that stale ID'] = !h.params(4).has('female_parent_id') && h.params(4).get('male_parent_id') === '202';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships:[{parent_type:'female',parent_id:301,parent_name:'Renamed recorded mother',cross_type:'derived'}]});
    result['historical type and readonly parent ID are preserved'] = $('#add_parent_cross_type').val() === 'derived' && $('#add_parent_cross_type').prop('disabled') && $('#add_parent_female').prop('readOnly') && $('#add_parent_submit').prop('disabled');
    $('#add_parent_male').val('Father').trigger('input'); h.submit();
    result['completing legacy pedigree posts authoritative stored identity'] = h.params(1).get('female_parent_id') === '301' && h.params(1).get('cross_type') === 'derived';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships:[{...rows[0],cross_type:null},rows[1]]});
    result['missing historical type stays unspecified without inventing biparental'] = $('#add_parent_cross_type').val() === '' && !$('#add_parent_cross_type').prop('disabled') && $('#add_parent_submit').prop('disabled');
    $('#add_parent_cross_type').val('biparental').trigger('change'); h.submit();
    result['explicit missing-type completion preserves both parent IDs'] = h.params(1).get('female_parent_id') === '101' && h.params(1).get('male_parent_id') === '202';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships:[{...rows[0],cross_type:'self'},rows[1]]}); h.submit();
    result['unchanged historical self with different locked parents needs no corrective save'] = h.requests.length === 1 && $('#add_parent_submit').prop('disabled') && !$('#add_parent_error').text();
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.w.get_remove_parents_list('999');
    h.finish(0, {relationships:[
        {parent_id:10,parent_name:'<b>Same</b>',parent_type:'female'},
        {parent_id:10,parent_name:'<b>Same</b>',parent_type:'male'}
    ]});
    result['removal lists both roles and escapes recorded names'] = $('#remove_parent_list a').length === 2 && !$('#remove_parent_list b').length;
    $('#remove_parent_list a').eq(1).trigger('click');
    result['role-specific removal expects JSON and posts selected role'] = h.requests[1].options.dataType === 'json' && h.params(1).get('parent_type') === 'male';
    h.finish(1, '<html>Login</html>', 'text/html');
    result['HTML removal cannot report success and reloads saved relationships'] = !h.alerts.includes('The parent has been removed.') && h.requests.length === 3 && h.requests[2].options.type === 'GET';
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    h.open(); h.finish(0, {relationships:[{parent_type:'female',parent_id:101,parent_name:'Previous name',cross_type:'self'}]});
    const maleOptions = $('#add_parent_male').data('autocompleteOptions');
    maleOptions.select({}, {item:{id:101,value:'Current name'}}); h.submit();
    result['self compares authoritative matching IDs despite differing labels'] = h.requests.length === 2 && h.params(1).get('female_parent_id') === '101' && h.params(1).get('male_parent_id') === '101' && h.params(1).get('female_parent') !== h.params(1).get('male_parent');
    h.finish(1, {error:'Review before retry'});
    maleOptions.select({}, {item:{id:202,value:'Previous name'}}); h.submit();
    result['self rejects differing selected IDs even when labels match'] = h.requests.length === 2 && $('#add_parent_error').text().includes('same parent');
    $('#add_parent_male').val('Alias for parent 101').trigger('input'); h.submit();
    result['self delegates an unselected alias to server identity resolution'] = h.requests.length === 3 && h.params(2).get('female_parent_id') === '101' && !h.params(2).has('male_parent_id') && h.params(2).get('male_parent') === 'Alias for parent 101';
    h.w.close();
}
{
    const h = harness();
    h.w.remove_parents('999', '10');
    result['legacy two-argument removal still omits an unspecified role'] = !h.params(0).has('parent_type');
    const thrown = h.finish(0, null);
    result['null removal never throws or reports success'] = !thrown && !h.alerts.includes('The parent has been removed.') && h.requests.length === 2;
    h.w.close();
}
{
    const h = harness(), $ = h.$;
    $('body').append('<select id="pedigree_level_select"><option value="Parents">Parents</option><option value="Grandparents">Grandparents</option></select><span id="pedigree_string">[loading...]</span>');
    const template = fs.readFileSync(path.join(path.dirname(process.argv[3]), 'stock_pedigree_string.mas'), 'utf8');
    const script = template.match(/<script>([\s\S]*?)<\/script>/)[1].replace(/<%\s*\$stock_id\s*%>/g, '999');
    const ready = $.fn.ready;
    $.fn.ready = function(callback) { callback($); return this; };
    h.w.eval(script);
    $.fn.ready = ready;
    const pedigree = '<b>Mother & A</b>/Father & B';
    h.finish(0, {pedigree_string:pedigree});
    result['actual pedigree string renderer treats markup and ampersands as literal names'] = $('#pedigree_string').text() === pedigree && $('#pedigree_string').children().length === 0;
    $('#pedigree_level_select').val('Grandparents').trigger('change');
    // jQuery moves GET data into the URL and removes options.data before transport.
    const request = new URL(h.requests[1].options.url, 'http://localhost:3010');
    result['pedigree string level change preserves loading and request contract'] = $('#pedigree_string').text() === '[loading...]' && h.requests[1].options.type === 'GET' && request.searchParams.get('level') === 'Grandparents';
    h.finish(1, {pedigree_string:pedigree});
    result['pedigree string remains plain text after changing ancestry level'] = $('#pedigree_string').text() === pedigree && $('#pedigree_string b').length === 0;
    h.w.close();
}
{
    const template = fs.readFileSync(path.join(path.dirname(process.argv[3]), '../breeders_toolbox/cross/add_progenies_dialogs.mas'), 'utf8');
    const start = template.indexOf("jQuery('#upload_cross_progenies_store').click(");
    const end = template.indexOf("jQuery('#dismiss_progenies_saved_dialog').click(", start);
    if (start < 0 || end < 0) { throw new Error('Could not locate the real cross upload store handler'); }
    function crossUpload() {
        const h = harness(), $ = h.$;
        $('body').append('<button id="upload_cross_progenies_store"></button><input id="cross_upload_overwrite_pedigrees" type="checkbox" checked><div id="working_modal" style="display:none"></div><div id="progenies_saved_dialog_message" style="display:none"></div>');
        h.w.archived_file_name = '/archive/cross_upload/verified & input.xls'; h.w.user_id = 41;
        h.w.eval(template.slice(start, end)); $('#upload_cross_progenies_store').trigger('click'); return h;
    }
    for (const kind of ['HTML', 'empty object', 'network failure']) {
        const h = crossUpload(), $ = h.$;
        if (kind === 'HTML') {
            result['actual cross-upload caller posts JSON with existing fields'] = h.requests[0].options.type === 'POST' && h.requests[0].options.dataType === 'json' && h.params(0).get('archived_file_name') === '/archive/cross_upload/verified & input.xls' && h.params(0).get('overwrite_pedigrees') === 'true' && h.params(0).get('user_id') === '41';
        }
        if (kind === 'network failure') { h.fail(0); }
        else { h.finish(0, kind === 'HTML' ? '<html>Login page</html>' : {}, kind === 'HTML' ? 'text/html' : 'application/json'); }
        result[kind + ' cross upload never claims success or that nothing was saved'] = $('#progenies_saved_dialog_message').css('display') === 'none' && $('#working_modal').css('display') === 'none' && h.alerts.length === 1 && h.alerts[0].includes('could not be confirmed') && !/none were uploaded|no progenies were saved/i.test(h.alerts[0]);
        h.w.close();
    }
    const good = crossUpload(); good.finish(0, {success:1});
    result['actual cross-upload success requires explicit confirmation'] = good.$('#progenies_saved_dialog_message').css('display') !== 'none' && good.alerts.length === 0; good.w.close();
    const rejected = crossUpload(); rejected.finish(0, {error:'Review the saved pedigree first.'});
    result['actual cross-upload domain error is displayed without success'] = rejected.$('#progenies_saved_dialog_message').css('display') === 'none' && rejected.alerts[0] === 'Review the saved pedigree first.'; rejected.w.close();
}
process.stdout.write(JSON.stringify(result));
