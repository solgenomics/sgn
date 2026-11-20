use strict;
use warnings;

# R/spatial_correlation_check.R (first step of the spatial correction) on a trait with more than 5000 measured
# plots: shapiro.test() takes 3 to 5000 values, so the script used to stop and the trial page answered HTTP 500.
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use IPC::Run qw(run);

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;
plan skip_all => 'Rscript is not installed' unless $rscript;
my $directory = tempdir('SpatialCorrelationCheckXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $script = File::Spec->rel2abs('R/spatial_correlation_check.R');

# a randomized trial: blocks of 20 columns, accessions shuffled in each, a smooth field trend plus noise
sub write_trial {
    my ($file, $rows, $columns, $accessions) = @_;
    srand(20261120);
    my @lines = ("germplasmName\treplicate\trowNumber\tcolNumber\tyield");
    for my $replicate (1 .. $columns / 20) {
        my @entries = map { 1 + ($_ % $accessions) } 0 .. $rows * 20 - 1;
        for my $i (reverse 1 .. $#entries) { my $j = int rand($i + 1); @entries[$i, $j] = @entries[$j, $i]; }
        my $k = 0;
        for my $column (($replicate - 1) * 20 + 1 .. $replicate * 20) {
            for my $row (1 .. $rows) {
                my $accession = $entries[$k++];
                push @lines, join("\t", "G$accession", $replicate, $row, $column,
                    sprintf('%.3f', 10 + 0.02 * $row + 0.01 * $column + 0.003 * $accession + rand(2)));
            }
        }
    }
    write_file($file, join("\n", @lines) . "\n");
}

sub summary {
    my ($file) = @_;
    my ($out, $err) = ('', '');
    run([$rscript, $script, $file, 'yield'], '>', \$out, '2>', \$err);
    my $result = "$file.spatial_correlation_summary";
    return (undef, $err) unless -e $result;
    my @rows = map { [ map { s/^"|"$//gr } split /\t/ ] } grep { length } split /\n/, read_file($result);
    my %column; @column{ @{ $rows[0] } } = 0 .. $#{ $rows[0] };
    return ({ map { $_ => $rows[1][ $column{$_} ] } keys %column }, $err);
}

write_trial("$directory/large.tsv", 60, 100, 500);
my ($large, $err) = summary("$directory/large.tsv");
ok($large, '6000 measured plots: the script writes its summary') or diag($err);
like($large->{quality} // '', qr/\(normality tested on 5000 of 6000 values drawn at random\)$/, '6000 plots: the quality says the normality test used a sample');
like($large->{Moran_pvalue} // '', qr/^[0-9.e-]+$/, '6000 plots: the spatial pattern is still tested on every plot');
my ($again) = summary("$directory/large.tsv");
is($again->{quality}, $large->{quality}, '6000 plots: the same answer on a second run');

write_trial("$directory/small.tsv", 15, 40, 50);
my ($small, $small_err) = summary("$directory/small.tsv");
ok($small, '600 measured plots: the script writes its summary') or diag($small_err);
unlike($small->{quality} // '', qr/normality tested on/, '600 plots: every value tested, no note');

done_testing();
