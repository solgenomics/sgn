use strict;use warnings;use File::Slurp qw(read_file);use CXGN::DroneImagery::DesignFactors;use Text::CSV;
my($root,$dir,$family,$design)=@ARGV;
my$source=read_file("$root/lib/CXGN/DroneImagery/DroneImageryAnalyticsRunSimulation.pm");
my$statistics_select=$family eq'multi_spatial'?'sommer_grm_spatial_genetic_blups':$family eq'multi_pure'?'sommer_grm_spatial_pure_2dspl_genetic_blups':$family eq'uni_spatial'?'sommer_grm_univariate_spatial_genetic_blups':'sommer_grm_univariate_spatial_pure_2dspl_genetic_blups';
my$section=$family=~/^multi/?index($source,"if (\$statistics_select eq 'sommer_grm_spatial_genetic_blups'"):index($source,"elsif (\$statistics_select eq 'sommer_grm_univariate_spatial_genetic_blups'");die'missing owning branch'if$section<0;
my$start=index($source,"\$statistics_cmd_reading = 'R -e",$section);die'missing owning reader'if$start<0;
my$end=index($source,$family=~/^multi/?'my $encoded_trait_cv_string_1':"\$statistics_cmd_cv_1 = ''",$start);die'missing owning model boundary'if$end<0;
my$fragment=substr($source,$start,$end-$start);
my$statistics_cmd_reading;my$statistics_cmd_model;my$drone_sommer_compat_file="$root/R/drone_sommer_compat.R";
my$fixed_effect_type=$ENV{SGN_SIMULATION_FIXED_TYPE} || 'replicate';
my$replicate_is_quantitative=$fixed_effect_type eq 'fixed_effect_trait' ? 'TRUE':'FALSE';
my$recorded_study_design=$design;
my($design_assignment)=$source=~/^    (my \$design_fixed_terms=[^\n]+;)/m;die'Missing actual design dispatch'if!$design_assignment;
my$design_fixed_terms=eval "$design_assignment\n\$design_fixed_terms;";die$@if$@;
my$stats_tempfile="$dir/input.csv";my$grm_file="$dir/grm.tsv";my$stats_out_tempfile="$dir/genotype.tsv";my$stats_out_tempfile_row="$dir/row.tsv";my$stats_out_tempfile_col="$dir/col.tsv";my$stats_out_tempfile_residual="$dir/residual.tsv";my$stats_out_tempfile_varcomp="$dir/variance.tsv";my$stats_out_tempfile_2dspl="$dir/spatial.tsv";
my@encoded_traits=$family=~/^multi/?('t1','t2'):('t1');my$cbind_string=$family=~/^multi/?'cbind(t1,t2)':'t1';my$number_traits=@encoded_traits;my$t='t1';my$trait_name_encoder={'t1'=>'t1'};my%trait_name_encoder=('t1'=>'t1');my$tolparinv=1e-6;my$tolparinv_10=1e-5;
# The owning method always runs these preparation programs before its fit,
# even when fold fitting is disabled. Execute the actual builders here too.
my$prep_start;
$prep_start=index($source,"\$prepare_file_cv_cmd = 'R -e",$section);
my$prepare_file_cv_cmd;my$prepare_file_cv2_cmd;
my$preparers=eval substr($source,$prep_start,$start-$prep_start)."\n[\$prepare_file_cv_cmd,\$prepare_file_cv2_cmd];";die$@if$@;
my$i=0;for my$preparer(@$preparers){next if!defined$preparer||!length$preparer;$i++;system("($preparer) > '$dir/preparation-$i.log' 2>&1")==0 or die"Actual CV preparation failed ($i)";}
my$cmd=eval "$fragment\n\$statistics_cmd_reading.\$statistics_cmd_model;";die$@if$@;
open(my$f,'>',"$dir/command.txt")or die$!;print {$f} $cmd;close$f;
my$status=system("($cmd) > '$dir/actual-command.log' 2>&1");print"family=$family design=$design status=".($status>>8)."\n";exit($status>>8);
