use strict;use warnings;use Data::Dumper;use JSON;use Text::CSV;use File::Basename qw(basename);use File::Copy qw(copy);use File::Slurp qw(read_file);use CXGN::DroneImagery::DesignFactors;use CXGN::DroneImagery::NativeResults;
my($root,$directory,$backend,$recorded_study_design)=@ARGV;
die'Unsupported backend'if$backend!~/^(?:blupf90|airemlf90)$/;
my$analytics=read_file("$root/lib/SGN/Controller/AJAX/DroneImagery/DroneImageryAnalytics.pm");
my$simulation=read_file("$root/lib/CXGN/DroneImagery/DroneImageryAnalyticsRunSimulation.pm");
sub fragment{my($source,$start_marker,$end_marker,$offset)=@_;my$start=index($source,$start_marker,$offset||0);die"Missing source start $start_marker"if$start<0;my$end=index($source,$end_marker,$start);die"Missing source end $end_marker"if$end<0;return substr($source,$start,$end-$start)}
my$writer=fragment($simulation,'my $model_csv_writer=','sub perform_drone_imagery_analytics');
eval 'package CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;'.$writer;die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my$csv=Text::CSV->new({binary=>1,sep_char=>"\t"});my@metadata;
{open(my$in,'<:encoding(UTF-8)',"$directory/metadata.tsv")or die$!;my$h=$csv->getline($in);while(my$r=$csv->getline($in)){my%d;@d{@$h}=@$r;push@metadata,\%d}close$in}
my(@unique_plot_names,%stock_name_row_col,%stock_row_col,%phenotype_data_original,%plot_rep_time_factor_map,%accession_id_factor_map,%polynomial_map,%genotypes,%individuals,%fixed_times);
for my$r(@metadata){my$plot=$r->{observationunit_stock_id};my$name="P$plot";push@unique_plot_names,$name;$stock_name_row_col{$name}={rep=>$r->{obsunit_rep},block=>$r->{obsunit_block},germplasm_stock_id=>$r->{germplasm_stock_id},germplasm_name=>"G$r->{germplasm_stock_id}",obsunit_stock_id=>$plot,row_number=>1,col_number=>1}}
my$input_directory=$directory;
$directory=CXGN::DroneImagery::DesignFactors::working_directory($directory,$backend.'_grm_random_regression_dap_blups');
open(my$manifest,'>',"$input_directory/working-directory.txt")or die$!;print {$manifest} $directory,"\n";close$manifest;
my@sorted_trait_names=(10,20,30,40);my$legendre_order_number=1;my$time_min=10;my$time_max=40;my$fixed_effect_type=$ENV{SGN_SIMULATION_FIXED_TYPE} || 'replicate';my$fixed_effect_trait_data={map {$_->{observationunit_stock_id}=>($_->{fixed_effect_trait_binned}//0)} @metadata};my$use_area_under_curve=0;
my$sorted_trait_names_scaled_string=join(',',map{($_-$time_min)/($time_max-$time_min)}@sorted_trait_names);
my@sorted_scaled_ln_times=map{log(($_-$time_min)/($time_max-$time_min)+.0001)}@sorted_trait_names[0..$legendre_order_number];
my$stats_prep_tempfile="$directory/prep.csv";my$stats_prep_factor_tempfile="$directory/prep-factors.tsv";my$stats_out_tempfile="$directory/polynomial.tsv";my$stats_tempfile_2="$directory/training.dat";my$stats_prep2_tempfile="$directory/phenotype-matrix.csv";my$stats_out_param_tempfile="$directory/start-covariance.tsv";
my$grm_file="$input_directory/grm.tsv";my$grm_rename_tempfile="$directory/grm-numeric.txt";my$permanent_environment_structure_tempfile="$directory/permanent.txt";my$parameter_tempfile="$directory/parameters.txt";my$tmp_stats_dir=$directory;my$drone_sommer_compat_file="$root/R/drone_sommer_compat.R";
my$protocol_id=($ENV{SGN_F90_KERNEL_MODE}//'identity')eq'covariance'?1:0;my$permanent_environment_structure='identity';my$tolparinv=1e-6;my$time_kind=$ENV{SGN_SIMULATION_TIME_KIND} || 'dap';die'Unknown temporal unit'if$time_kind!~/^(?:dap|gdd)$/;my$statistics_select=$backend.'_grm_random_regression_'.$time_kind.'_blups';
my$polynomial_start=index($analytics,'my $sorted_trait_names_scaled_string =');
my$poly_code=fragment($analytics,"my \$cmd = 'R -e",'my $status = system(',$polynomial_start);
my$command=eval"$poly_code\n\$cmd;";die$@if$@;system("($command) > '$directory/polynomial.log' 2>&1")==0 or die'Polynomial preparation failed'; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my$prep_start=index($analytics,'open(my $F_prep, ">", $stats_prep_tempfile)');my$prep_end=index($analytics,'close($F_prep);',$prep_start)+length('close($F_prep);');
eval substr($analytics,$prep_start,$prep_end-$prep_start);die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my$factor_code=fragment($analytics,"my \$cmd_factor = 'R -e",'my $status_factor = system(',$prep_start);
$command=eval"$factor_code\n\$cmd_factor;";die$@if$@;system("($command) > '$directory/factor.log' 2>&1")==0 or die'Factor preparation failed'; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my%raw=map{$_->{observationunit_stock_id}=>$_->{obsunit_rep}}@metadata;
{open(my$in,'<:encoding(UTF-8)',$stats_prep_factor_tempfile)or die$!;$csv->getline($in);while(my$r=$csv->getline($in)){my($g,$gf,$plot,$pf,$rep,$time,$fixed,$individual)=@$r;die'Literal metadata tag changed'if($rep//'')ne($raw{$plot}//'');die'Physical individuals merged'if$pf!=$individual;$accession_id_factor_map{$g}=$gf;$plot_rep_time_factor_map{$plot}{$rep}{$time}=$fixed;$stock_row_col{$plot}{plot_id_factor}=$pf;$genotypes{$g}=1;$individuals{$pf}=1;$fixed_times{$fixed}=1}close$in}
{open(my$in,'<',$stats_out_tempfile)or die$!;$csv->getline($in);my$i=0;while(my$r=$csv->getline($in)){$polynomial_map{$sorted_trait_names[$i++]}=$r}close$in}
{open(my$in,'<',"$input_directory/responses.tsv")or die$!;$csv->getline($in);while(my$r=$csv->getline($in)){$phenotype_data_original{"P$r->[0]"}{$r->[1]}=$r->[2]}close$in}
my$c; # Valid fixtures must never need the controller error branch.
my$f90_group_codes;
my(@data_matrix_original,@data_matrix_phenotypes_original,@phenotype_header,@legs_header);my$F;
my$factor_maps_end=index($analytics,'@ind_rep_factors = sort keys %seen_ind_reps;',$prep_start);
my$category_start=index($analytics,'$f90_group_codes=',$factor_maps_end);my$category_end=index($analytics,'} @unique_plot_names]);',$category_start)+length('} @unique_plot_names]);');
eval substr($analytics,$category_start,$category_end-$category_start);die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my$rows_start=index($analytics,'foreach my $p (@unique_plot_names)',$factor_maps_end);my$rows_end=index($analytics,'@phenotype_header =',$rows_start);
eval substr($analytics,$rows_start,$rows_end-$rows_start);die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my$numeric_writer_start=index($analytics,'open($F, ">", $stats_tempfile_2)',$rows_end);my$numeric_writer_end=index($analytics,'close($F2);',$numeric_writer_start)+length('close($F2);');
eval substr($analytics,$numeric_writer_start,$numeric_writer_end-$numeric_writer_start);die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my@rep_time_factors=sort keys%fixed_times;my@unique_accession_names=sort keys%genotypes;my@ind_rep_factors=sort keys%individuals;
my(@param_file_rows_data,@param_file_rows_data_cv1,@param_file_rows_data_cv2,@param_file_rows_data_cv3,@param_file_rows_data_cv4,@param_file_rows_data_cv5,@param_file_rows_1,@param_file_rows_2,@param_file_rows_3,@param_file_rows_4,@param_file_rows_5);my$statistics_cmd;my$cmd_f90;
my($parameter_tempfile_cv1,$parameter_tempfile_cv2,$parameter_tempfile_cv3,$parameter_tempfile_cv4,$parameter_tempfile_cv5,$parameter_tempfile_cv1_2,$parameter_tempfile_cv2_2,$parameter_tempfile_cv3_2,$parameter_tempfile_cv4_2,$parameter_tempfile_cv5_2)=map{"$directory/cv$_.params"}1..10;
my($stats_out_cv1_predict_tempfile,$stats_out_cv2_predict_tempfile,$stats_out_cv3_predict_tempfile,$stats_out_cv4_predict_tempfile,$stats_out_cv5_predict_tempfile,$stats_out_cv1_2_predict_tempfile,$stats_out_cv2_2_predict_tempfile,$stats_out_cv3_2_predict_tempfile,$stats_out_cv4_2_predict_tempfile,$stats_out_cv5_2_predict_tempfile)=map{"$directory/cv$_.data"}1..10;
# Use the owning constructor, including its ordinary bounded fold-data
# preparation. No fold fit is requested by this main-model driver.
my$param_start=index($simulation,'my $pheno_var_pos = $legendre_order_number+1;');
my$param_end=index($simulation,"my \$command_name = '';",$param_start);
my$init_start=index($simulation,'my $native_declared_residual_variance=1;');
my$init_end=index($simulation,'my @plot_ids_ordered =',$init_start);
die'Final immutable native qualification requires the owning native initializer'if$init_start<0||$init_end<0;
my$param_code=substr($simulation,$init_start,$init_end-$init_start).substr($simulation,$param_start,$param_end-$param_start);
eval$param_code;die$@if$@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
# Verify the actual producer keeps observed zero and original absence distinct.
my@native_input;
{open(my$in,'<',$stats_tempfile_2)or die$!;while(my$line=<$in>){my@v=split' ',$line;die'Native producer emitted an incomplete row'if@v!=9;my$expected=$phenotype_data_original{"P$v[1]"}{$v[3]};my$encoded=CXGN::DroneImagery::DesignFactors::native_observation($expected);die'Native producer changed measured zero/value or original missingness'if$v[-1]!=$encoded;push@native_input,\@v;}close$in;}
for my$file($stats_out_cv1_predict_tempfile,$stats_out_cv2_predict_tempfile,$stats_out_cv3_predict_tempfile,$stats_out_cv4_predict_tempfile,$stats_out_cv5_predict_tempfile){open(my$in,'<',$file)or die$!;my$i=0;while(my$line=<$in>){my@v=split' ',$line;die'Median experiment filled an originally missing observation'if$native_input[$i][-1]==CXGN::DroneImagery::DesignFactors::native_missing_value()&&$v[-1]!=$native_input[$i][-1];$i++;}close$in;die'Native fold changed input row count'if$i!=@native_input;}
print"Actual native producer preserves observed zero/values, missingness and fold row alignment.\n";
my$runner=fragment($simulation,"my \$command_name = '';",'print STDERR Dumper $cmd_f90;',$param_end);
$command=eval"$runner\n\$cmd_f90;";die$@if$@;open(my$out,'>',"$directory/command.txt")or die$!;print {$out} $command,"\n";close$out; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
if($ENV{SGN_SIMULATION_F90_CONSTRUCTION_ONLY}){print "CONSTRUCTION ONLY: actual inputs and parameters built; native fit was not run.\n";exit 77;}
my$measure='import json,resource,subprocess,sys,time; started=time.monotonic(); result=subprocess.run(["/bin/sh","-c",sys.argv[2]],timeout=60); usage=resource.getrusage(resource.RUSAGE_CHILDREN); open(sys.argv[1],"w").write(json.dumps({"exit_code":result.returncode,"elapsed_seconds":time.monotonic()-started,"maximum_rss_kb":usage.ru_maxrss})); sys.exit(result.returncode)';
my$status=system('python3','-c',$measure,"$directory/resources.json",$command);
print"owning_simulation_solver=$backend design=$recorded_study_design exit=".($status>>8)."\n";
exit($status>>8)if$status;
my$error=CXGN::DroneImagery::DesignFactors::native_fit_error($statistics_select,$parameter_tempfile,$stats_tempfile_2,$stats_out_tempfile,$tmp_stats_dir);
if($error){print"NATIVE_NAMED_REFUSAL: $error\n";exit 1;}
my%native_unit_metadata=map {my$r=$_;my$plot=$r->{observationunit_stock_id};$stock_row_col{$plot}{plot_id_factor}=>{plot_id=>$plot,genotype_id=>$r->{germplasm_stock_id},genotype_factor=>$accession_id_factor_map{$r->{germplasm_stock_id}}}} @metadata;
my$summary=CXGN::DroneImagery::NativeResults::summarize(parameter_file=>$parameter_tempfile,data_file=>$stats_tempfile_2,log_file=>$stats_out_tempfile,cwd=>$tmp_stats_dir,backend=>$backend,time_scale=>uc($time_kind),kernel_origin=>$protocol_id?'additive_marker':'genotypic_identity',unit_metadata=>\%native_unit_metadata);
open(my$summary_out,'>',"$directory/native-summary.json")or die$!;print {$summary_out} encode_json($summary);close$summary_out;
print"Native summary archived ".scalar(@{$summary->{reference_units}})." physical units at ".scalar(@{$summary->{by_time}})." dates with ".$summary->{quantity_label}."\n";
exit 0;
