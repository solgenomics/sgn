#!/usr/bin/env perl
# The actual stability R script (AMMI and GGE) on a synthetic phenotype file
# as the dataset download writes it: free text with an apostrophe and a "#",
# a trait name with " - " and "/", and location names with "-" and ".".
# No database needed.
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use JSON::XS qw(decode_json);
use IPC::Run qw(run);

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;
plan skip_all => 'Rscript is not installed' unless $rscript;

my $directory = tempdir('StabilityRXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $script = File::Spec->catfile('R', 'stability', 'ammi_script.R');
my @locations = ('Site-A', 'St. Louis', 'Plain');
my @effects = ([0, 1.5, -1], [0.5, -1, 1.2], [-0.8, 0.4, 0.9], [1.1, 0.2, -1.4]);

my $content = join("\t", qw(studyDescription locationName germplasmName replicate entryType),
    'Yield - t/ha|CO_322:0000731', 'notes')."\n";
for my $genotype (0 .. 3) {
    for my $location (0 .. 2) {
        for my $replicate (1 .. 3) {
            my $value = 8 + $genotype + 2 * $location + $effects[$genotype][$location] + 0.1 * $replicate * (($genotype + $location) % 2 ? 1 : -1);
            $content .= join("\t", "The team's block, plot length 10 m", $locations[$location], 'G'.($genotype + 1),
                $replicate, 'test', $value, 'row #'.$replicate)."\n";
        }
    }
}
my $file = "$directory/phenotype.txt";
write_file($file, $content);

# The controller turns spaces and slashes of the trait name into dots.
my $trait = 'Yield.-.t.ha';

for my $method ('ammi', 'gge') {
    subtest $method => sub {
        my %out = map { $_ => "$directory/${method}_$_" } qw(json graph message summary);
        my ($stdout, $stderr);
        my $ran = eval { run([$rscript, $script, $file, $trait, 'imput_no', $method, @out{qw(json graph message summary)}], '>', \$stdout, '2>', \$stderr) };
        ok($ran, 'the stability R script completes') or diag($stderr || $@);
        ok(!-s $out{message}, 'no error message is written') or diag(scalar read_file($out{message}));
        ok(-s $out{json}, 'the result table is written') or return;
        my $rows = decode_json(decode_json(scalar read_file($out{json}))->[0]);
        is(scalar @$rows, 12, 'one row for each accession at each location');
        is_deeply([sort keys %{{ map { $_->{location} => 1 } @$rows }}], [sort @locations], 'location names are kept as they are');
        is(scalar(grep { !defined $_->{means} || $_->{means} eq 'NA' } @$rows), 0, 'every row has its mean');
    };
}

done_testing();
