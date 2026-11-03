use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);

my $rscript;
for my $directory (split /:/, $ENV{PATH}) {
    my $candidate = "$directory/Rscript";
    if (-x $candidate) { $rscript = $candidate; last; }
}
plan skip_all => 'Rscript is not installed' unless $rscript;
my $output = tempdir('sgn-model-regression-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $result = system($rscript, 't/unit/R/model_consumers.R', getcwd(), $output);
is($result, 0, 'actual statistical consumers preserve design factors and plot identity');
done_testing();
