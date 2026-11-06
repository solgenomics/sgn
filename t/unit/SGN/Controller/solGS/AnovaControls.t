use strict;
use warnings;

use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir tempfile);
use HTML::Mason::Interp;
use HTML::TreeBuilder;
use JSON qw(encode_json decode_json);

# Render the real ANOVA component. Only surrounding presentation components
# are stubs; no Catalyst application, database, or browser is started.
my $stub_root = tempdir(CLEANUP => 1);
my $data_dir = tempdir(CLEANUP => 1);
my %stubs = (
    'util/import_css.mas' => '',
    'util/import_javascript.mas' => '',
    'page/info_section.mas' => '<% $m->content %>',
    'solgs/spinner/spinner.mas' => '',
);
for my $path (keys %stubs) {
    my $file = "$stub_root/$path";
    (my $parent = $file) =~ s{/[^/]+\z}{};
    make_path($parent);
    open(my $handle, '>', $file) or die "Cannot write $file: $!";
    print $handle $stubs{$path};
    close($handle) or die "Cannot close $file: $!";
}
my $interp = HTML::Mason::Interp->new(
    comp_root => [[stubs => $stub_root], [main => abs_path('mason')]],
    data_dir => $data_dir, autohandler_name => '', preamble => 'use utf8;',
);

# Execute the existing click handler, using IDs extracted from rendered HTML.
# The jQuery stand-in models event registration and records the AJAX request;
# it does not model styling, a browser DOM, or a successful server response.
my $node = `which node 2>/dev/null`;
chomp $node;
my ($js_handle, $harness) = tempfile(SUFFIX => '.js', UNLINK => 1);
print $js_handle do { local $/; <DATA> };
close($js_handle);
my $script = abs_path('js/source/legacy/solGS/clearCache.js');

for my $case (
    ['trial', {trial_id => 101}, '101'],
    ['training population fallback', {training_pop_id => 202}, '202'],
) {
    my ($name, $arguments, $expected_id) = @$case;
    subtest $name => sub {
        my $output = '';
        my $rendered = eval {
            $interp->make_request(
                comp => '/solgs/tools/anova/analysis.mas', args => [%$arguments],
                out_method => \$output,
            )->exec;
            1;
        };
        ok($rendered, 'the actual Mason component renders') or diag $@;
        my $tree = HTML::TreeBuilder->new_from_content($output);
        my $clear = $tree->look_down(id => 'clear_cache_anova');
        ok($clear, 'Clear cache is present before an ANOVA result exists');
        ok($clear && !defined($clear->attr('hidden'))
                && ($clear->attr('class') || '') !~ /(?:^|\s)hidden(?:\s|$)/
                && ($clear->attr('style') || '') !~ /display\s*:\s*none/i,
            'Clear cache is initially visible in component markup');
        ok($clear && !defined($clear->attr('disabled')), 'Clear cache is enabled');
        ok($tree->look_down(id => 'run_anova'), 'Run ANOVA remains present');
        my $trial = $tree->look_down(id => 'trial_id');
        is($trial ? $trial->attr('type') : undef, 'hidden', 'the action identifier remains a hidden input');
        my $rendered_id = $trial ? $trial->attr('value') : undef;
        is($rendered_id, $expected_id, 'the hidden identifier uses the trial or training population');

        SKIP: {
            skip 'node is not installed; click-handler execution unavailable', 5 unless $node;
            my $inputs = encode_json({
                '#analysis_type' => 'anova', '#data_structure' => 'trial',
                '#trial_id' => $rendered_id || '', '#dataset_id' => '',
            });
            open(my $result, '-|', $node, $harness, $script, $inputs,
                $clear ? $clear->attr('id') : '') or die "Cannot start node: $!";
            my $json = do { local $/; <$result> };
            my $finished = close($result);
            my $request = eval { decode_json($json) };
            ok($finished && $request, 'the real clearCache.js click handler executes') or diag($json || $@);
            $request ||= {};
            is($request->{url}, '/solgs/cache/clear', 'the click uses the existing clear endpoint');
            is($request->{type}, 'POST', 'the click sends POST');
            is($request->{data}{analysis_types}, 'anova', 'the request clears only ANOVA outputs');
            is($request->{data}{trials}, $expected_id, 'the request targets the rendered trial identifier');
        }
        $tree->delete;
    };
}

done_testing();

__DATA__
const fs = require('fs');
const vm = require('vm');
const [script, encodedInputs, buttonId] = process.argv.slice(2);
const values = JSON.parse(encodedInputs);
const document = {};
let click;
let request;
function jQuery(selector) {
    if (selector === document) return { ready: callback => callback() };
    return {
        val: () => values[selector],
        click: callback => { click = callback; }
    };
}
jQuery.ajax = options => {
    request = {url: options.url, type: options.type, data: {...options.data}};
};
vm.runInNewContext(fs.readFileSync(script, 'utf8'), {jQuery, document});
if (!click) throw new Error('Clear-cache click handler was not registered');
click({target: {id: buttonId}});
process.stdout.write(JSON.stringify(request));
