=head1 NAME

t/unit/mason/stock/jbrowse.t - JBrowse dataset lookup and accession track selection

=head1 DESCRIPTION

Executes the URL setup from the stock page with synthetic site configurations.
Runs the actual JavaScript module and the accession/trial AJAX callbacks with
bundled jQuery in jsdom. No application server or database is required.

=cut

use strict;
use warnings;
use utf8;

use Test::More;
use File::Temp qw | tempfile |;
use JSON;
use Config::General;
use URI::Escape qw | uri_escape_utf8 |;

package main;
{
    package JBrowseTestContext;
    sub config { return $_[0]->{config}; }
}

open(my $source, '<', 'mason/stock/index.mas') or die "Cannot read stock page: $!";
my $page = do { local $/; <$source> };
close($source);
my ($setup) = $page =~ /(my \$jbrowse_path = .*?)(?=\n\n)/s;
die 'Cannot find the stock page JBrowse URL setup' unless defined $setup;

sub stock_url {
    my ($config, $stock_id, $uniquename) = @_;
    my $c = bless { config => $config }, 'JBrowseTestContext';
    my $url = eval "$setup\n\$jbrowse_url"; ## no critic (BuiltinFunctions::ProhibitStringyEval)
    die $@ if $@;
    return $url;
}

my %example = Config::General->new(-ConfigFile => 'sgn.conf')->getall;
is($example{jbrowse_accession_tracks}, 'DNA,Gene exons,{accession}_2015_V6_imputed',
    'the example site configuration parses the track template literally');
my %empty = Config::General->new(-String => 'jbrowse_accession_tracks ""')->getall;
is($empty{jbrowse_accession_tracks}, '', 'an explicitly empty setting parses as an empty string');

my $base = '/jbrowse_solgenomics/?data=data/json';
my $prefix = $base . '%2Faccessions%2F4204&tracks=';
my $default = $prefix . 'DNA%2CGene%20exons%2CLine_2015_V6_imputed&highlight=';
is(stock_url({ jbrowse_path => $base }, 4204, 'Line'), $default,
    'existing sites keep the original default link');
is(stock_url({ jbrowse_path => $base, jbrowse_accession_tracks => undef }, 4204, 'Line'), $default,
    'an undefined setting keeps the default');

my @cases = (
    ['DNA,genes,{accession}_2026', 'Line', 'DNA,genes,Line_2026', 'custom track names replace the old suffix'],
    ['{accession}_raw,{accession}_imputed', 'Line', 'Line_raw,Line_imputed', 'every placeholder is replaced'],
    ['DNA,reference', 'Line', 'DNA,reference', 'fixed tracks need no accession placeholder'],
    ['', 'Line', '', 'empty setting leaves track selection to JBrowse'],
    ['0', 'Line', '0', 'a false but defined setting is retained'],
    ['{accession}_2026', 'Line & "雪"/?#%+$\\', 'Line & "雪"/?#%+$\\_2026', 'special characters and Unicode are encoded once'],
    ['{accession}_raw', '{accession}$1\\', '{accession}$1\\_raw', 'replacement text is literal and is not expanded again'],
);
foreach my $case (@cases) {
    my ($template, $name, $expected, $description) = @$case;
    my $url = stock_url({ jbrowse_path => $base, jbrowse_accession_tracks => $template }, 4204, $name);
    is($url, $prefix . uri_escape_utf8($expected) . '&highlight=', $description);
}
is(stock_url({ jbrowse_path => '/custom/browser/?data=genome', jbrowse_accession_tracks => '{accession}' }, 7, 'A B'),
    '/custom/browser/?data=genome%2Faccessions%2F7&tracks=A%20B&highlight=',
    'site path and stock id are preserved');

my $node = `which node 2>/dev/null`;
chomp($node);
SKIP: {
    skip 'node or jsdom is not installed (run npm install in js/)', 1
        if !$node || !-d 'js/node_modules/jsdom';
    my ($fh, $harness) = tempfile(SUFFIX => '.js', UNLINK => 1);
    print $fh do { local $/; <DATA> };
    close($fh);
    my $browser_url = stock_url({ jbrowse_path => $base, jbrowse_accession_tracks => 'DNA,{accession}_2026' }, 4204, 'A & \"雪\"');
    open(my $out, '-|', $node, $harness, $browser_url) or die "Cannot run node: $!";
    my $output = do { local $/; <$out> };
    close($out);
    my $status = $?;
    is($status, 0, 'dataset module and real page callbacks execute successfully');
    my $results = eval { decode_json($output) } || [];
    is(scalar @$results, 29, 'all JavaScript checks returned results');
    foreach my $result (@$results) {
        is_deeply($result->{actual}, $result->{expected}, $result->{name});
    }
}

done_testing();

__DATA__
const fs = require('fs');
const path = require('path');
const { JSDOM } = require(path.resolve('js/node_modules/jsdom'));
(async () => {
    const source = fs.readFileSync('js/source/entries/jbrowse_datasets.js', 'utf8');
    const module = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
    const conf = '[datasets.Accession_42048]\r\nname = other\r\n[ datasets.Accession_7 ] # comment\r\n[datasets.Trial_221]\r\n';
    const results = [];
    const check = (name, actual, expected) => results.push({ name, actual, expected });
    for (const [id, expected] of [
        ['Accession_42048', true], ['Accession_4204', false], ['Accession_420', false],
        ['Accession_4', false], ['Accession_420480', false], ['Accession_7', true],
        ['Trial_221', true], ['Trial_22', false],
    ]) check('exact dataset lookup: ' + id, module.hasDataset(conf, id), expected);
    for (const value of ['', null, '# [datasets.Accession_7]\nurl = Accession_7']) {
        check('no dataset in ' + JSON.stringify(value), module.hasDataset(value, 'Accession_7'), false);
    }
    for (const [file, kind, id, placeholder] of [
        ['mason/stock/index.mas', 'Accession', 4204, 'stock_id'],
        ['mason/breeders_toolbox/trial/jbrowse_instance.mas', 'Trial', 22, 'trial_id'],
    ]) {
        const page = fs.readFileSync(file, 'utf8');
        const ajax = page.match(/jQuery\.ajax\(\{\s*url: "<% \$test_url %>",[\s\S]*?\n\s*\}\);/)[0];
        for (const outcome of ['exact', 'prefix', 'error']) {
            const target = kind === 'Accession' ? 'jbrowse_check' : 'trial_jbrowse_check';
            const dom = new JSDOM('<p id="' + target + '">[loading...]</p>', { runScripts: 'outside-only' });
            const window = dom.window;
            window.eval(fs.readFileSync('js/source/legacy/jquery.js', 'utf8'));
            window.jsMod = { jbrowse_datasets: module };
            const href = kind === 'Accession' ? process.argv[2] : '/browser/?data=' + kind + '_' + id + '&tracks=DNA%2CA%26B';
            let requested;
            window.jQuery.ajax = options => { requested = options; };
            const script = ajax.replace(/<% \$test_url %>/g, '/browser/jbrowse.conf')
                .replace(new RegExp('<% \\$' + placeholder + ' %>', 'g'), String(id))
                .replace(/<% \$jbrowse_url %>/g, href);
            window.eval(script);
            check(kind + ' requests the configured dataset list (' + outcome + ')', requested.url, '/browser/jbrowse.conf');
            if (outcome === 'error') requested.error();
            else requested.success('[datasets.' + kind + '_' + id + (outcome === 'prefix' ? '8' : '') + ']');
            const link = window.document.querySelector('a#jbrowse_link');
            check(kind + ' ' + outcome + ' link visibility', Boolean(link), outcome === 'exact');
            if (link) check(kind + ' preserves the URL', link.getAttribute('href'), href);
            else check(kind + ' ' + outcome + ' explains missing data', window.document.getElementById(target).textContent,
                outcome === 'error' ? ' Jbrowse has not been set up for this database.' :
                    kind === 'Accession' ? ' This accession does not have any data in Jbrowse.' : ' This trial does not have a dataset in Jbrowse.');
            window.close();
        }
    }
    process.stdout.write(JSON.stringify(results));
})().catch(error => { console.error(error); process.exitCode = 1; });
