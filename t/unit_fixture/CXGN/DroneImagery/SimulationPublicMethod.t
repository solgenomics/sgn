use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Spec ();

# The original-F90 integration is optional in the ordinary Breedbase image.
# Run this before fixture/application imports so an unavailable optional engine
# cannot cause either database work or a missing future module during startup.
BEGIN {
    my %executables;
    my $missing;
    for my $name (qw(blupf90 R Rscript)) {
        for my $directory (File::Spec->path) {
            my $candidate=File::Spec->catfile($directory,$name);
            if (-f $candidate && -x $candidate) {$executables{$name}=$candidate;last;}
        }
        if (!$executables{$name}) {
            $missing="Required optional native-integration executable $name was not found in PATH.";
            last;
        }
    }
    if (!defined($missing)) {
        my $r_code='required<-c("data.table","dplyr","sommer","orthopolynom"); missing<-required[!vapply(required,function(p)suppressWarnings(suppressMessages(requireNamespace(p,quietly=TRUE))),logical(1))]; if(length(missing)){cat("Missing optional native-preparation R packages: ",paste(missing,collapse=", "),"\n",sep="");quit(status=1L)}';
        if (open(my $check,'-|',$executables{Rscript},'--vanilla','-e',$r_code)) {
            my $message=do {local $/;<$check>} // '';
            my $available=close($check);
            if (!$available) {
                $message =~ s/\s+$//;
                $missing=length($message) ? $message : 'The optional native-preparation R package check failed.';
            }
        } else {
            $missing='Unable to run the optional native-preparation R package check.';
        }
    }
    if (defined($missing)) {
        # Numerical qualification explicitly requires execution rather than SKIP.
        Test::More::BAIL_OUT("Required native integration is not configured: $missing")
            if $ENV{SGN_REQUIRE_NATIVE_INTEGRATION};
        Test::More::plan(skip_all=>"Optional original-F90 integration is not configured: $missing");
    }
    Test::More::diag('Original BLUPF90 integration prerequisites are configured; executing the real public-method fixture.');
}

use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Slurp qw(read_file);
use JSON qw(encode_json decode_json);
use Text::CSV;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;
use CXGN::DroneImagery::DesignFactors;
use Statistics::Descriptive;

# Actual public method, real PostgreSQL stock identities, original BLUPF90,
# all simulation stages, no fold fits. This is a software integration fixture.
my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
$schema->storage->auto_savepoint(1);
my $dbh=$schema->storage->dbh;
my $directory=$ENV{SGN_SIMULATION_PUBLIC_OUT} || tempdir('sgn_public_native_XXXXX',TMPDIR=>1,CLEANUP=>0);
make_path($directory) if !-d $directory;
my $prefix='audit_public_simulation_'.$$;
my ($trial,@plots);
sub term {SGN::Model::Cvterm->get_cvterm_row($schema,@_)->cvterm_id}
$schema->txn_begin;
my $ran=eval {
    my @germ=$schema->resultset('Stock::Stock')->search({type_id=>term('accession','stock_type')},{rows=>8,order_by=>'stock_id'})->all;
    die 'The native fixture needs eight real accession stocks' if @germ!=8;
    my %design;
    for my $i (1..24) {
        $design{$i}={plot_name=>"${prefix}_P$i",plot_number=>$i,stock_name=>$germ[($i-1)%8]->uniquename,rep_number=>int(($i-1)/8)+1,block_number=>1,row_number=>int(($i-1)/6)+1,col_number=>($i-1)%6+1};
    }
    my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$schema,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$prefix,trial_description=>'Rollback-only public native Simulation integration',trial_year=>2031,design_type=>'CRD',design=>\%design})->save_trial;
    $trial=$created->{trial_id};die encode_json($created) if !$trial;
    @plots=map {$schema->resultset('Stock::Stock')->find({uniquename=>"${prefix}_P$_"})}1..24;
    my $trait=70666;my $type=term('phenotyping_experiment','experiment_type');
    for my $i (0..$#plots) {
        my $e=$schema->resultset('NaturalDiversity::NdExperiment')->create({type_id=>$type,nd_geolocation_id=>$schema->resultset('NaturalDiversity::NdGeolocation')->first->nd_geolocation_id});
        $e->create_related('nd_experiment_projects',{project_id=>$trial});
        $e->create_related('nd_experiment_stocks',{stock_id=>$plots[$i]->stock_id,type_id=>$type});
        my $p=$schema->resultset('Phenotype::Phenotype')->create({uniquename=>$prefix.'_env_'.$i,cvalue_id=>$trait,observable_id=>$trait,value=>3+sin($i*.91)+$i*.3,collect_date=>'2031-01-01 10:00:00',operator=>'janedoe'});
        $e->create_related('nd_experiment_phenotypes',{phenotype_id=>$p->phenotype_id});
    }
    $dbh->do('SELECT refresh_materialized_phenotype_jsonb_table()');
    my (@metadata,@responses);
    for my $i (0..$#plots) {
        push @metadata,[$germ[$i%8]->stock_id,$plots[$i]->stock_id,$design{$i+1}{rep_number},1];
        for my $time (10,20,30,40) {
            push @responses,[$plots[$i]->stock_id,$time,50+($i%8)*1.7+sin(($i+1)*($time+3))*.8+cos($i*.73)*$time*.08];
        }
    }
    my $tsv=Text::CSV->new({binary=>1,sep_char=>"\t",eol=>"\n"});
    for my $spec (['metadata.tsv',[qw(germplasm_stock_id observationunit_stock_id obsunit_rep obsunit_block)],\@metadata],['responses.tsv',[qw(plot time value)],\@responses]) {
        open(my $out,'>:encoding(UTF-8)',"$directory/$spec->[0]")or die$!;$tsv->print($out,$spec->[1]);$tsv->print($out,$_)for@{$spec->[2]};close($out);
    }
    open(my $grm,'>',"$directory/grm.tsv")or die$!;
    for my $i(0..$#germ){for my $j($i..$#germ){print $grm join("\t",$germ[$i]->stock_id,$germ[$j]->stock_id,$i==$j?1:0),"\n";}}close($grm);
    {
        local $ENV{SGN_SIMULATION_F90_CONSTRUCTION_ONLY}=1;
        my $status=system($^X,'-Ilib','t/unit/R/drone_simulation_f90_models.pl','.', $directory,'blupf90','CRD');
        die 'Actual owning preparation failed' if($status>>8)!=77;
    }
    open(my $manifest,'<',"$directory/working-directory.txt")or die$!;chomp(my $working=<$manifest>);close($manifest);
    my $source=read_file('lib/CXGN/DroneImagery/DroneImageryAnalyticsRunSimulation.pm');
    my ($signature)=$source=~/sub perform_drone_imagery_analytics \{\s*my \((.*?)\) = \@_;/s;
    die 'Actual public positional signature missing' if !$signature;
    my @names=map {s/^\$//r}split /,\s*/,$signature;
    my %args=map {$_=>/_hash$/?{}:/_array$/?[]: /tempfile(?:_\w+)?$/ ? "$working/$_":undef} @names;
    my (%stock_info,%plot_id_map,%stock_name_row_col,%stock_row_col,%stock_row_col_id,%phenotypes,%acc_factor,%acc_reverse,%plot_reverse,%line_plot,%line_time,%rep_time,%poly,%seen_times,%trait_encoder,%trait_reverse,%trait_time);
    my @times=(10,20,30,40);my @plot_names=map {$_->uniquename}@plots;my @plot_ids=map {$_->stock_id}@plots;
    for my $i(0..$#germ){my$id=$germ[$i]->stock_id;$stock_info{$id}={uniquename=>$germ[$i]->uniquename};$acc_factor{$id}=$i+1;$acc_reverse{$i+1}=$germ[$i]->uniquename;}
    for my $i(0..$#plots){my$id=$plots[$i]->stock_id;my$name=$plots[$i]->uniquename;my$d=$design{$i+1};$plot_id_map{$id}=$name;$plot_reverse{$i+1}=$name;$stock_row_col{$id}={plot_id_factor=>$i+1};$stock_row_col_id{$d->{row_number}}{$d->{col_number}}=$id;$stock_name_row_col{$name}={obsunit_stock_id=>$id,germplasm_stock_id=>$germ[$i%8]->stock_id,germplasm_name=>$germ[$i%8]->uniquename,rep=>$d->{rep_number},block=>1,row_number=>$d->{row_number},col_number=>$d->{col_number},plot_id_factor=>$i+1};}
    for my $r(@responses){$phenotypes{$plot_id_map{$r->[0]}}{$r->[1]}=$r->[2];}
    for my $i(0..3){my$t=$times[$i];$poly{$t}=[1/sqrt(2),sqrt(3/2)*(2*($t-10)/30-1)];$seen_times{$t}='fixture NDVI day '.$t;$trait_encoder{$seen_times{$t}}=$t;$trait_reverse{$t}=$seen_times{$t};$trait_time{$seen_times{$t}}=$t;}
    open(my $input,'<',"$working/training.dat")or die$!;my $row=0;while(my$l=<$input>){my@v=split' ',$l;$line_plot{$row}=$plot_id_map{$v[1]};$line_time{$row}=$v[3];my$unit=$stock_name_row_col{$plot_id_map{$v[1]}};$acc_factor{$unit->{germplasm_stock_id}}=$v[0];$acc_reverse{$v[0]}=$unit->{germplasm_name};$stock_row_col{$v[1]}{plot_id_factor}=$v[5];$unit->{plot_id_factor}=$v[5];$plot_reverse{$v[5]}=$plot_id_map{$v[1]};$rep_time{$v[1]}{$stock_name_row_col{$plot_id_map{$v[1]}}{rep}}{$v[3]}=$v[4];$row++;}close($input);
    %args=(%args,schema=>$schema,a_env=>1,b_env=>1,ro_env=>.2,row_ro_env=>.2,env_variance_percent=>10,protocol_id=>0,statistics_select=>'blupf90_grm_random_regression_dap_blups',analytics_select=>'minimize_local_env_effect',tolparinv=>1e-6,use_area_under_curve=>0,legendre_order_number=>1,permanent_environment_structure=>'identity',trait_name_encoder_hash=>\%trait_encoder,trait_name_encoder_rev_hash=>\%trait_reverse,stock_info_hash=>\%stock_info,plot_id_map_hash=>\%plot_id_map,sorted_trait_names_array=>\@times,accession_id_factor_map_hash=>\%acc_factor,rep_time_factors_array=>[1..4],ind_rep_factors_array=>[1..24],unique_accession_names_array=>[map {$_->uniquename}@germ],plot_id_count_map_reverse_hash=>\%line_plot,sorted_scaled_ln_times_array=>[],time_count_map_reverse_hash=>\%line_time,accession_id_factor_map_reverse_hash=>\%acc_reverse,seen_times_hash=>\%seen_times,plot_id_factor_map_reverse_hash=>\%plot_reverse,trait_to_time_map_hash=>\%trait_time,unique_plot_names_array=>\@plot_names,stock_name_row_col_hash=>\%stock_name_row_col,phenotype_data_original_hash=>\%phenotypes,plot_rep_time_factor_map_hash=>\%rep_time,stock_row_col_hash=>\%stock_row_col,stock_row_col_id_hash=>\%stock_row_col_id,polynomial_map_hash=>\%poly,plot_ids_ordered_array=>\@plot_ids,csv=>Text::CSV->new({binary=>1,sep_char=>"\t"}),timestamp=>'2031-01-01 10:00:00',user_name=>'janedoe',grm_file=>"$directory/grm.tsv",grm_rename_tempfile=>"$working/grm-numeric.txt",tmp_stats_dir=>$working,stats_tempfile_2=>"$working/training.dat",stats_prep2_tempfile=>"$working/phenotype-matrix.csv",stats_out_param_tempfile=>"$working/start-covariance.tsv",parameter_tempfile=>"$working/parameters.txt",time_min=>10,time_max=>40,header_string=>'',min_row=>1,max_row=>4,min_col=>1,max_col=>6,mean_row=>2.5,sig_row=>5/3,mean_col=>3.5,sig_col=>3.5,sim_env_change_over_time=>'',correlation_between_times=>.5,field_trial_id_list=>[$trial],simulated_environment_real_data_trait_id=>$trait,fixed_effect_type=>'replicate',perform_cv=>0,native_variance_options=>{kernel_origin=>'genotypic_identity'});
    my $result=CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics(map {$args{$_}}@names);
    die encode_json($result) if ref($result) ne 'ARRAY';
    my $summary=$result->[-1];is($summary->{version},2,'actual whole public method returns appended versioned metadata without shifting legacy tuple');
    is(scalar(keys %{$summary->{stages}}),8,'actual native fits populate every original/altered/simulated stage summary');
    for my $stage(sort keys %{$summary->{stages}}){my$s=$summary->{stages}{$stage};is(scalar(@{$s->{reference_units}}),24,"$stage retains real physical stock IDs");is(scalar(@{$s->{by_time}}),4,"$stage retains all four actual dates");like($s->{quantity_label},qr/broad-sense genotypic H2/,"$stage biological origin is explicit");}
    ok(ref($result->[10])eq'HASH' && keys(%{$result->[10]}),'legacy original genetic result tuple position remains populated');
    open(my $out,'>',"$directory/public-native-result.json")or die$!;print $out encode_json($summary);close($out);diag("Actual full-method summary artifact: $directory/public-native-result.json");
    1;
};my$error=$@;
my$rolled=eval {$schema->txn_rollback;1};my$rollback_error=$@;
ok($ran,'actual public Simulation method completed')or diag($error);ok($rolled,'all private field/observation/ontology mutations rolled back')or diag($rollback_error);done_testing;
