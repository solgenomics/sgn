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
use File::Temp qw | tempfile tempdir |;
use HTML::Mason::Interp;
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

my $component_root = tempdir(CLEANUP => 1);
open(my $component, '>', "$component_root/jbrowse_url.mas") or die "Cannot write component: $!";
print $component '<%args>' . "\n" . '$config' . "\n" . '$stock_id' . "\n" . '$uniquename' . "\n";
print $component '</%args><%perl>' . "\n";
print $component 'my $c = bless { config => $config }, "JBrowseTestContext";' . "\n";
print $component $setup;
print $component '</%perl><% $jbrowse_url %>';
close($component);
my $interp = HTML::Mason::Interp->new(
    comp_root => $component_root,
    data_dir => tempdir(CLEANUP => 1),
    autohandler_name => '',
);

sub stock_url {
    my ($config, $stock_id, $uniquename) = @_;
    my $url = '';
    $interp->make_request(
        comp => '/jbrowse_url.mas',
        args => [config => $config, stock_id => $stock_id, uniquename => $uniquename],
        out_method => \$url,
    )->exec();
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
    is(scalar @$results, 54, 'all JavaScript checks returned results');
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
    const fallback = '/jbrowse/?data=data/json%2Faccessions%2F7&tracks=DNA%2CLine_2026&highlight=';
    const link = conf => module.linkFor(conf, 'Accession_7', '/jbrowse/', fallback);
    const dataset = url => '[ datasets.Accession_7 ] # exact block\r\nurl = ' + url + '\r\n';
    check('dataset data, location, tracks and highlight override defaults',
        link(dataset('?data=data/json/Genome&loc=chr3:10..20&tracks=DNA,Line&highlight=chr3:12..13')),
        '/jbrowse/?data=data/json/Genome&loc=chr3:10..20&tracks=DNA,Line&highlight=chr3:12..13');
    check('dataset without tracks inherits the configured fallback tracks', link(dataset('?data=data/json/Genome')),
        '/jbrowse/?data=data/json/Genome&tracks=DNA%2CLine_2026&highlight=');
    check('explicit empty dataset tracks are retained', link(dataset('?data=data/json/Genome&tracks=')),
        '/jbrowse/?data=data/json/Genome&tracks=&highlight=');
    check('missing dataset has no link', link('[datasets.Accession_78]\nurl = ?data=other'), null);
    check('another section cannot supply the dataset URL', link('[datasets.Accession_7]\n[GENERAL]\nurl = ?data=other'), fallback);
    check('blank dataset URL keeps the native fallback', link(dataset('')), fallback);
    check('generator-style dataset URLs retain native track selection', link(dataset('?data=data/json/accessions/7')),
        '/jbrowse/?data=data/json/accessions/7&tracks=DNA%2CLine_2026&highlight=');
    check('a malformed section boundary cannot lend another dataset URL',
        link('[datasets.Accession_7]\n[datasets.Accession_78] ; comment\nurl = ?data=other'), fallback);
    const trialFallback = '/browser/?data=data/json%2Ftrials%2F22&tracks=DNA%2CGene%20exons%2C&cat=Diversity/NEXTGEN/Imputed&highlight=';
    check('a generated trial dataset retains native tracks and category',
        module.linkFor('[datasets.Trial_22]\nurl = ?data=data/json/trials/22', 'Trial_22', '/browser/', trialFallback),
        '/browser/?data=data/json/trials/22&tracks=DNA%2CGene%20exons%2C&cat=Diversity/NEXTGEN/Imputed&highlight=');
    check('an explicitly empty category overrides the native trial category',
        module.linkFor('[datasets.Trial_22]\nurl = ?data=data/json/Genome&cat=', 'Trial_22', '/browser/', trialFallback),
        '/browser/?data=data/json/Genome&cat=&tracks=DNA%2CGene%20exons%2C&highlight=');
    check('encoded parameter names override defaults without duplication', link(dataset('?data=Genome&tr%61cks=custom')),
        '/jbrowse/?data=Genome&tr%61cks=custom&highlight=');
    check('a bare tracks key is an explicit empty selection', link(dataset('?data=Genome&tracks')),
        '/jbrowse/?data=Genome&tracks&highlight=');
    for (const unsafe of ['https://example.invalid/', '//example.invalid/', 'javascript:alert(1)',
        '?data=bad"value', '?data=bad\\value', '?data=bad value', '?data=bad#fragment']) {
        check('unsafe or non-query URL retains fallback: ' + unsafe, link(dataset(unsafe)), fallback);
    }
    for (const [file, kind, id, placeholder] of [
        ['mason/stock/index.mas', 'Accession', 4204, 'stock_id'],
        ['mason/breeders_toolbox/trial/jbrowse_instance.mas', 'Trial', 22, 'trial_id'],
    ]) {
        const page = fs.readFileSync(file, 'utf8');
        const ajax = page.match(/jQuery\.ajax\(\{\s*url: "<% \$test_url %>",[\s\S]*?\n\s*\}\);/)[0];
        for (const outcome of ['exact', 'configured', 'prefix', 'error']) {
            const target = kind === 'Accession' ? 'jbrowse_check' : 'trial_jbrowse_check';
            const dom = new JSDOM('<p id="' + target + '">[loading...]</p>', { runScripts: 'outside-only' });
            const window = dom.window;
            window.eval(fs.readFileSync('js/source/legacy/jquery.js', 'utf8'));
            window.jsMod = { jbrowse_datasets: module };
            const href = kind === 'Accession' ? process.argv[2] : trialFallback;
            let requested;
            window.jQuery.ajax = options => { requested = options; };
            const script = ajax.replace(/<% \$test_url %>/g, '/browser/jbrowse.conf')
                .replace(new RegExp('<% \\$' + placeholder + ' %>', 'g'), String(id))
                .replace(/<% \$jbrowse_url %>/g, href)
                .replace(/<% \$basepath %>/g, 'browser');
            window.eval(script);
            check(kind + ' requests the configured dataset list (' + outcome + ')', requested.url, '/browser/jbrowse.conf');
            if (outcome === 'error') requested.error();
            else requested.success('[datasets.' + kind + '_' + id + (outcome === 'prefix' ? '8' : '') + ']' +
                (outcome === 'configured' ? '\nurl = ?data=data/json/Genome&tracks=custom&highlight=' : ''));
            const link = window.document.querySelector('a#jbrowse_link');
            check(kind + ' ' + outcome + ' link visibility', Boolean(link), outcome === 'exact' || outcome === 'configured');
            if (link) check(kind + ' preserves the URL (' + outcome + ')', link.getAttribute('href'),
                outcome === 'configured' ? '/browser/?data=data/json/Genome&tracks=custom&highlight=' +
                    (kind === 'Trial' ? '&cat=Diversity/NEXTGEN/Imputed' : '') : href);
            else check(kind + ' ' + outcome + ' explains missing data', window.document.getElementById(target).textContent,
                outcome === 'error' ? ' Jbrowse has not been set up for this database.' :
                    kind === 'Accession' ? ' This accession does not have any data in Jbrowse.' : ' This trial does not have a dataset in Jbrowse.');
            window.close();
        }
    }
    process.stdout.write(JSON.stringify(results));
})().catch(error => { console.error(error); process.exitCode = 1; });
