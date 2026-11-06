use strict;
use warnings;
use Data::Dumper;
use CXGN::DroneImagery::DesignFactors;
my ($root,$directory,$kind,$design)=@ARGV;
open(my $source_file,'<',"$root/lib/SGN/Controller/AJAX/DroneImagery/DroneImagery.pm") or die $!;
local $/;my $source=<$source_file>;close $source_file;
my %markers=(
  lmer=>"if (\$statistics_select eq 'lmer_germplasmname_replicate') {",
  grm=>"elsif (\$statistics_select eq 'sommer_grm_genetic_blups') {",
  spatial=>"elsif (\$statistics_select eq 'sommer_grm_spatial_genetic_blups') {",
  temporal=>"elsif (\$statistics_select eq 'sommer_grm_temporal_random_regression_dap_genetic_blups' || \$statistics_select eq 'sommer_grm_temporal_random_regression_gdd_genetic_blups') {",
  temporal_genetic=>"elsif (\$statistics_select eq 'sommer_grm_genetic_only_random_regression_dap_genetic_blups' || \$statistics_select eq 'sommer_grm_genetic_only_random_regression_gdd_genetic_blups') {"
);
my $section=$kind eq 'f90' ? 0 : index($source,$markers{$kind});die 'missing model branch' if $section<0;
my $start=index($source,$kind eq 'f90' ? "my \$cmd_factor = 'R -e" : "my \$cmd = 'R -e",$section);die 'missing owning command' if $start<0;
my $end=index($source,$kind eq 'f90' ? 'my $status_factor = system(' : 'my $status = system(',$start);die 'missing owning execution' if $end<0;
my $fragment=substr($source,$start,$end-$start);
my $drone_sommer_compat_file="$root/R/drone_sommer_compat.R";
my $stats_tempfile="$directory/input.csv";my $grm_file="$directory/grm.tsv";
my $stats_out_tempfile="$directory/genotype.tsv";
my $stats_out_tempfile_row="$directory/row.tsv";
my $stats_out_tempfile_col="$directory/col.tsv";
my $stats_out_tempfile_2dspl="$directory/spatial.tsv";
my $stats_out_tempfile_residual="$directory/residual.tsv";
my $stats_out_tempfile_genetic="$directory/genetic-coefficients.tsv";
my $stats_out_tempfile_permanent_environment="$directory/permanent-coefficients.tsv";
my $stats_prep_tempfile="$directory/prep.csv";
my $stats_prep_factor_tempfile="$directory/prep-factors.tsv";
my @executed_protocols;
my %trait_name_encoder=(Yield=>'t1');my $t='Yield';
my @encoded_traits=('t1');my $cbind_string='t1';my $number_traits=1;my $tolparinv=$ENV{SGN_DRONE_TOL_PAR_INV} || 1e-6;my $legendre_order_number=1;
my $design_fixed_terms=$kind eq 'f90' ? '' : CXGN::DroneImagery::DesignFactors::fixed_terms($design);
my $expression=$kind eq 'f90' ? '$cmd_factor' : '$cmd';
my $cmd=eval "$fragment\n$expression;";die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.

if ($ENV{SGN_DRONE_DIAGNOSTIC_ORDER}) {
    $cmd =~ s/order\(time\)/order(mat_long\\\$time)/g;
}
if ($ENV{SGN_DRONE_SAVE_FIT}) {
    $cmd =~ s/#gen_cor/saveRDS(mix,file='$directory\/diagnostic-fit.rds'); #gen_cor/;
}
open(my $command_file,'>',"$directory/command.txt") or die $!;print $command_file $cmd;close $command_file;
my $status=system("($cmd) > '$directory/actual-command.log' 2>&1");
print "owning_model=$kind design=$design exit=".($status>>8)."\n";
exit($status>>8);
