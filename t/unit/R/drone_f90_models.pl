use strict;
use warnings;
use Data::Dumper;
use JSON::PP;
use JSON;
use Text::CSV;
use File::Basename qw(basename);
use CXGN::DroneImagery::DesignFactors;
use CXGN::DroneImagery::NativeResults;
{package NativeDriverContext;sub stash {$_[0]}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
my $c=bless {},'NativeDriverContext';
my ($root,$directory,$backend,$recorded_study_design)=@ARGV;
die "Unsupported native backend\n" unless $backend eq 'blupf90' || $backend eq 'airemlf90';
my $source;
{open(my $in,'<',"$root/lib/SGN/Controller/AJAX/DroneImagery/DroneImagery.pm") or die $!;local $/;$source=<$in>;close $in;}
my $csv=Text::CSV->new({sep_char=>"\t",binary=>1});
my @metadata;
{open(my $in,'<:encoding(UTF-8)',"$directory/metadata.tsv") or die $!;my $header=$csv->getline($in);while(my $row=$csv->getline($in)){my %d;@d{@$header}=@$row;push @metadata,\%d;}close $in;}
my $data=\@metadata;
my $input_directory=$directory;
$directory=CXGN::DroneImagery::DesignFactors::working_directory($directory,$backend.'_grm_random_regression_dap_blups');
open(my $directory_manifest,'>',"$input_directory/working-directory.txt") or die $!;
print $directory_manifest $directory,"\n";close $directory_manifest;
my @sorted_trait_names=(10,20,30,40);
my $legendre_order_number=1;
my $time_min=10;my $time_max=40;
my $sorted_trait_names_scaled_string=join(',',map {($_-$time_min)/($time_max-$time_min)} @sorted_trait_names);
my @sorted_scaled_ln_times=map {log(($_-$time_min)/($time_max-$time_min)+.0001)} @sorted_trait_names[0..$legendre_order_number];
my $stats_prep_tempfile="$directory/prep.csv";
my $stats_prep_factor_tempfile="$directory/prep-factors.tsv";
my $stats_out_tempfile="$directory/polynomial.tsv";
my $stats_tempfile_2="$directory/training.dat";
my $stats_prep2_tempfile="$directory/phenotype-matrix.csv";
my $stats_out_param_tempfile="$directory/start-covariance.tsv";
my $grm_file="$input_directory/grm.tsv";
my $grm_rename_tempfile="$directory/grm-numeric.txt";
my $permanent_environment_structure_tempfile="$directory/permanent.txt";
my $parameter_tempfile="$directory/parameters.txt";
my $tmp_stats_dir=$directory;
my $protocol_id=($ENV{SGN_F90_KERNEL_MODE} // 'identity') eq 'covariance' ? 1 : 0;
my $permanent_environment_structure='identity';
my $tolparinv=1e-6;
my $statistics_select=$backend.'_grm_random_regression_dap_blups';
my @executed_protocols;
my ($native_residual_initial_coefficients,$native_residual_initial_variance_range,$native_residual_basis_rows);
my $fragment=sub {
    my ($start_marker,$end_marker,$offset)=@_;
    my $start=index($source,$start_marker,$offset||0);die "Missing start: $start_marker\n" if $start<0;
    my $end=index($source,$end_marker,$start);die "Missing end: $end_marker\n" if $end<0;
    return substr($source,$start,$end-$start);
};
my $polynomial_start=index($source,'my $sorted_trait_names_scaled_string =');
my $polynomial_code=$fragment->("my \$cmd = 'R -e",'my $status = system(',$polynomial_start);
my $command=eval "$polynomial_code\n\$cmd;";die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
system("($command) > '$directory/polynomial.log' 2>&1")==0 or die "Native polynomial preparation failed\n";
my $prep_start=index($source,'open(my $F_prep, ">:encoding(UTF-8)", $stats_prep_tempfile)');
my $prep_end=index($source,'close($F_prep);',$prep_start)+length('close($F_prep);');
eval substr($source,$prep_start,$prep_end-$prep_start);die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my $factor_code=$fragment->("my \$cmd_factor = 'R -e",'my $status_factor = system(',$prep_start);
$command=eval "$factor_code\n\$cmd_factor;";die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
system("($command) > '$directory/factor.log' 2>&1")==0 or die "Native factor preparation failed\n";
my (%factor_map,%fixed_time,%accession_id_factor_map,%plots,%genotypes);
my %recorded_tag=map {$_->{observationunit_stock_id} => (defined($_->{obsunit_rep}) ? $_->{obsunit_rep} : '')} @metadata;
{open(my $in,'<:encoding(UTF-8)',$stats_prep_factor_tempfile) or die $!;$csv->getline($in);while(my $row=$csv->getline($in)){
    my ($accession,$accession_factor,$plot,$plot_factor,$rep,$time,$rep_time,$individual)=@$row;
    die "F90 category preparation changed a literal recorded tag.\n" unless (defined($rep)?$rep:'') eq $recorded_tag{$plot};
    $factor_map{$plot}{$time}=[$accession_factor,$plot_factor,$rep_time];
    $accession_id_factor_map{$accession}=$accession_factor;$fixed_time{$rep_time}=1;$plots{$plot_factor}=1;$genotypes{$accession}=1;
}close $in;}
my (%polynomials,%polynomial_map);
{open(my $in,'<',$stats_out_tempfile) or die $!;$csv->getline($in);my $i=0;while(my $row=$csv->getline($in)){$polynomials{$sorted_trait_names[$i]}=$row;$polynomial_map{$sorted_trait_names[$i++]}=$row;}close $in;}
$native_residual_basis_rows=[map {$polynomial_map{$_}} @sorted_trait_names];
my %responses;
{open(my $in,'<',"$input_directory/responses.tsv") or die $!;$csv->getline($in);while(my $row=$csv->getline($in)){$responses{$row->[0]}{$row->[1]}=$row->[2];}close $in;}
my $group_codes=CXGN::DroneImagery::DesignFactors::category_codes([map {CXGN::DroneImagery::DesignFactors::group_key($recorded_study_design,$_->{obsunit_rep},$_->{obsunit_block})} @metadata]);
my (@data_matrix,@data_matrix_phenotypes);
for my $row (@metadata) {
    my $plot=$row->{observationunit_stock_id};
    my $group=CXGN::DroneImagery::DesignFactors::numeric_group_code($recorded_study_design,$row->{obsunit_rep},$row->{obsunit_block},$group_codes);
    my @phenotypes=map {defined($responses{$plot}{$_}) && length($responses{$plot}{$_}) ? CXGN::DroneImagery::DesignFactors::native_observation($responses{$plot}{$_}) : 'NA'} @sorted_trait_names;
    for my $time (@sorted_trait_names) {
        my ($genotype,$individual,$fixed) = @{$factor_map{$plot}{$time}};
        push @data_matrix,[$genotype,$plot,$group,$time,$fixed,$individual,@{$polynomials{$time}},CXGN::DroneImagery::DesignFactors::native_observation($responses{$plot}{$time})];
        # The owning builder retains the complete time vector once per time
        # record. Preserve that existing covariance-initialization contract.
        push @data_matrix_phenotypes,\@phenotypes;
    }
}
my $writer_start=index($source,'open(my $F, ">", $stats_tempfile_2)');
my $writer_end=index($source,'close($F2);',$writer_start)+length('close($F2);');
eval substr($source,$writer_start,$writer_end-$writer_start);die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
my @rep_time_factors=sort keys %fixed_time;
my @unique_accession_names=sort keys %genotypes;
my @ind_rep_factors=sort keys %plots;
my $parameter_code=$fragment->('my $pheno_var_pos = $legendre_order_number+1;',"my \$command_name = '';");
eval $parameter_code;die $@ if $@;die $c->stash->{rest}{error} if $c->stash->{rest}{error}; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
if ($ENV{SGN_F90_DIAGNOSTIC_CONVERGENCE}) {
    open(my $parameters,'<',$parameter_tempfile) or die $!;
    my @lines=<$parameters>;close $parameters;
    s/^OPTION conv_crit .*/OPTION conv_crit 1e-12/ for @lines;
    open(my $strict,'>',$parameter_tempfile) or die $!;print $strict @lines;close $strict;
    print "DIAGNOSTIC ONLY: parameter copy uses standard native conv_crit 1e-12; owning app builder remains unchanged.\n";
}
if ($ENV{SGN_F90_DIAGNOSTIC_RESIDUAL_START}) {
    open(my $parameters,'<',$parameter_tempfile) or die $!;
    my @lines=<$parameters>;close $parameters;
    for my $line (@lines) {
        if ($line =~ /^OPTION hetres_pol\s+(.*)/) {
            my @coefficients=split /\s+/,$1;
            my $initial=$ENV{SGN_F90_DIAGNOSTIC_RESIDUAL_VALUE} // 0;
            $line='OPTION hetres_pol '.join(' ',map {$initial} @coefficients)."\n";
        }
    }
    open(my $constant,'>',$parameter_tempfile) or die $!;print $constant @lines;close $constant;
    print "DIAGNOSTIC ONLY: copied initial log-residual coefficients use the explicit diagnostic value; estimated parameter status must be checked.\n";
}
if (($ENV{SGN_F90_DIAGNOSTIC_SOLVER} // '') eq 'FSPAK' && $backend eq 'blupf90') {
    open(my $direct,'>>',$parameter_tempfile) or die $!;print $direct "OPTION solv_method FSPAK\n";close $direct;
    print "DIAGNOSTIC ONLY: copied parameters select the original provided BLUPF90 FSPAK solver.\n";
}
my $runner_code=$fragment->("my \$command_name = '';",'print STDERR Dumper $cmd;',index($source,'my $pheno_var_pos = $legendre_order_number+1;'));
$command=eval "$runner_code\n\$cmd;";die $@ if $@; ## no critic (ProhibitStringyEval) -- Execute the owning source fragment in this regression test; errors are checked below.
open(my $out,'>',"$directory/command.txt") or die $!;print $out $command,"\n";close $out;
my $measure='import json,resource,subprocess,sys,time; started=time.monotonic(); result=subprocess.run(["/bin/sh","-c",sys.argv[2]],timeout=60); usage=resource.getrusage(resource.RUSAGE_CHILDREN); open(sys.argv[1],"w").write(json.dumps({"exit_code":result.returncode,"elapsed_seconds":time.monotonic()-started,"maximum_rss_kb":usage.ru_maxrss})); sys.exit(result.returncode)';
my $status=system('python3','-c',$measure,"$directory/resources.json",$command);
print "owning_solver=$backend design=$recorded_study_design exit=".($status>>8)."\n";
exit($status>>8) if $status;
if(CXGN::DroneImagery::DesignFactors->can('native_fit_error')) {
    my $error=CXGN::DroneImagery::DesignFactors::native_fit_error($statistics_select,$parameter_tempfile,$stats_tempfile_2,$stats_out_tempfile,$tmp_stats_dir);
    if($error){print "NATIVE_NAMED_REFUSAL: $error\n";exit 1;}
}else{
    die "Final immutable native qualification requires the owning result-validation helper.\n" unless $ENV{SGN_F90_DIAGNOSTIC_CONVERGENCE} || $ENV{SGN_F90_DIAGNOSTIC_RESIDUAL_START} || $ENV{SGN_F90_DIAGNOSTIC_SOLVER};
    print "DIAGNOSTIC ONLY: candidate app predates result-validation helper; final variance evidence is inspected separately.\n";
}
my %unit_metadata;
for my $row (@metadata) {
    my $plot=$row->{observationunit_stock_id};
    my ($genotype,$unit)=@{$factor_map{$plot}{$sorted_trait_names[0]}};
    $unit_metadata{$unit}={plot_id=>$plot,genotype_id=>$row->{germplasm_stock_id},genotype_factor=>$genotype};
}
my $summary=CXGN::DroneImagery::NativeResults::summarize(
    parameter_file=>$parameter_tempfile,data_file=>$stats_tempfile_2,log_file=>$stats_out_tempfile,
    cwd=>$tmp_stats_dir,backend=>$backend,time_scale=>'DAP',
    kernel_origin=>$protocol_id ? 'additive_marker' : 'genotypic_identity',unit_metadata=>\%unit_metadata);
open(my $summary_file,'>',"$directory/native-summary.json") or die $!;
print $summary_file JSON::PP->new->canonical->encode($summary);close $summary_file;
exit 0;
