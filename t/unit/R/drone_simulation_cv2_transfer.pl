use strict;use warnings;use File::Slurp qw(read_file);use File::Copy qw(copy);use File::Basename qw(basename);use Data::Dumper;use Text::CSV;use CXGN::DroneImagery::NativeResults;
my($root,$case,$output)=@ARGV;mkdir$output if!-d$output;
my$source=read_file("$root/lib/CXGN/DroneImagery/DroneImageryAnalyticsRunSimulation.pm");
my$stats_out_tempfile="$case/polynomial.tsv.log";my@parameters=split/\n/,read_file("$case/parameters.txt");my@cov=grep{$parameters[$_]=~/^\(CO\)VARIANCES/}0..$#parameters;die'Expected two covariance blocks'if@cov!=2;
my($effects)=grep{$parameters[$_]=~/^NUMBER_OF_EFFECTS/}0..$#parameters;my$count=($parameters[$effects+1]-1)/2;die'Unsupported covariance dimensions'if$count!=int($count)||$count<1;my$legendre_order_number=$count-1;my$legendre_order_number_env_var_pos=$count+2;
my@param_file_rows_1=@parameters[2..$cov[0]-1];my@param_file_rows_3=@parameters[$cov[0]+$count+1..$cov[1]-1];my@param_file_rows_5=@parameters[$cov[1]+$count+1..$#parameters];my(@param_file_rows_6,@param_file_rows_7);
my@rr_coeff_genetic_covariance_original;my@rr_coeff_env_covariance_original;my@rr_coeff_genetic_correlation_original;my@rr_coeff_env_correlation_original;my$rr_residual_variance_original;
my($parameter_tempfile_cv1_2,$parameter_tempfile_cv2_2,$parameter_tempfile_cv3_2,$parameter_tempfile_cv4_2,$parameter_tempfile_cv5_2)=map{"$output/cv$_.params"}1..5;
# Default review is constructor-only. The explicit one-fold option consumes
# actual numeric fold data emitted by the owning Simulation constructor.
my$fold_input=$ENV{SGN_SIMULATION_CV2_RUN_ONE_FOLD}?"$case/cv1.data.dat":"$case/training.dat";
copy($fold_input,"$output/constructor-data.dat")or die"Actual owning fold data missing: $!";
my@param_file_rows_data_cv1=('DATAFILE','constructor-data.dat');my@param_file_rows_data_cv2=@param_file_rows_data_cv1;my@param_file_rows_data_cv3=@param_file_rows_data_cv1;my@param_file_rows_data_cv4=@param_file_rows_data_cv1;my@param_file_rows_data_cv5=@param_file_rows_data_cv1;
my@native_blup_options;
if(index($source,'@native_blup_options')>=0){require CXGN::DroneImagery::DesignFactors;@native_blup_options=(@{CXGN::DroneImagery::DesignFactors::native_solver_settings('blupf90_grm_random_regression_dap_blups')->{parameter_options}},'OPTION residual')}
my$parameter_tempfile="$case/parameters.txt";my$stats_tempfile_2="$case/training.dat";my$tmp_stats_dir=$case;
my$statistics_select=read_file($stats_out_tempfile)=~/AIREMLF90/ ? 'airemlf90_grm_random_regression_dap_blups':'blupf90_grm_random_regression_dap_blups';
my$protocol_id=$parameters[(grep{$parameters[$_]=~/^RANDOM_TYPE/}0..$#parameters)[0]+1]eq'diagonal'?0:1;
my$native_variance_options={kernel_origin=>($parameters[(grep{$parameters[$_]=~/^RANDOM_TYPE/}0..$#parameters)[0]+1]eq'diagonal'?'genotypic_identity':'unknown')};
my(%native_unit_metadata,%native_variance_summaries,%biological_id);
my$metadata="$case/../metadata.tsv";my$csv=Text::CSV->new({binary=>1,sep_char=>"\t"});
open(my$meta,'<:encoding(UTF-8)',$metadata)or die"Actual metadata input missing: $!";my$header=$csv->getline($meta);while(my$r=$csv->getline($meta)){my%d;@d{@$header}=@$r;$biological_id{$d{observationunit_stock_id}}=$d{germplasm_stock_id};}close$meta;
for my$line(split/\n/,read_file($stats_tempfile_2)){my@v=split' ',$line;$native_unit_metadata{$v[5]}={plot_id=>$v[1],genotype_factor=>$v[0],genotype_id=>$biological_id{$v[1]}};}
my$native_start=index($source,'my $status = system($cmd_f90);');my$start=index($source,'my @log_output_rows;',$native_start);my$end=index($source,'my $q_time =',$start);die'Actual CV2 constructor bounds missing'if$start<0||$end<0;
eval substr($source,$start,$end-$start);die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my@expected_g;my@expected_pe;
if($statistics_select=~/^airemlf90_/){my$log=read_file($stats_out_tempfile);my$final=rindex($log,'Final Estimates');die'No actual final estimates'if$final<0;my$tail=substr($log,$final);my($g)=$tail=~/Genetic variance\(s\) for effect\s+2\s+(.*?)correlations/s;my($pe)=$tail=~/Genetic variance\(s\) for effect\s+$legendre_order_number_env_var_pos\s+(.*?)correlations/s;@expected_g=split' ',$g;@expected_pe=split' ',$pe;}else{@expected_g=split' ',join(' ',@parameters[$cov[0]+1..$cov[0]+$count]);@expected_pe=split' ',join(' ',@parameters[$cov[1]+1..$cov[1]+$count]);}
for my$file($parameter_tempfile_cv1_2,$parameter_tempfile_cv2_2,$parameter_tempfile_cv3_2,$parameter_tempfile_cv4_2,$parameter_tempfile_cv5_2){my@p=split/\n/,read_file($file);my@c=grep{$p[$_]=~/^\(CO\)VARIANCES/}0..$#p;my@g=split' ',join(' ',@p[$c[0]+1..$c[0]+$count]);my@pe=split' ',join(' ',@p[$c[1]+1..$c[1]+$count]);die'Final covariance dimensions differ'if@g!=@expected_g||@pe!=@expected_pe;for my$i(0..$#g){die'Final genetic covariance transfer differs'if abs($g[$i]-$expected_g[$i])>1e-12*(1+abs($expected_g[$i]));die'Final permanent covariance transfer differs'if abs($pe[$i]-$expected_pe[$i])>1e-12*(1+abs($expected_pe[$i]));}my($r)=grep{$p[$_]=~/^RANDOM_RESIDUAL VALUES/}0..$#p;die'Residual comparison changed'if$p[$r+1]!=1;die'Data file missing'if$p[1]ne'constructor-data.dat';}
print"CONSTRUCTION ONLY: five actual CV2 files retain final AI or declared BLUP G/PE covariances, actual numeric data reference and homogeneous R1. No fold fit or same-heteroresidual-model claim.\n";


if($ENV{SGN_SIMULATION_CV2_RUN_ONE_FOLD}) {
    for my$name('grm-numeric.txt','permanent.txt') {copy("$case/$name","$output/$name")or die$! if-f"$case/$name";}
    my$parameter_tempfile_cv1_2_basename=basename($parameter_tempfile_cv1_2);
    my$tmp_stats_dir=$output;my$native_blup_selection='blupf90_grm_random_regression_dap_blups';
    my$stats_out_cv1_predict_tempfile="$output/constructor-data.dat";
    $stats_out_tempfile="$output/one-fold.log";
    my$fold_start=index($source,'my $cmd_f90_cv1_2 =');
    my$fold_end=index($source,"open(my \$fh_log_cv1_2,",$fold_start);
    die'Actual one-fold execution bounds missing'if$fold_start<0||$fold_end<0;
    my$failure=eval 'sub {'.substr($source,$fold_start,$fold_end-$fold_start).';return undef;}->()'; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
    die$@if$@;die$failure->{error}if ref($failure)eq'HASH';
    my$p=read_file($parameter_tempfile_cv1_2);
    die'CV2 BLUP solver role changed'if$p!~/^OPTION solv_method FSPAK$/m||$p=~/^OPTION hetres_/m;
    my$reference=$ENV{SGN_SIMULATION_CV2_REFERENCE_R} || "$root/t/unit/R/drone_simulation_cv2_reference.R";
    die'Independent CV2 reference script missing'if!-f$reference;
    system('Rscript',$reference,$output,$case)==0 or die'Independent actual fold reference failed';
    print"ACTUAL ONE FOLD: owning CV2 BLUP command completed with final main G/PE, FSPAK and homogeneous R1; no heterogeneous residual-function transfer claimed.\n";
}
