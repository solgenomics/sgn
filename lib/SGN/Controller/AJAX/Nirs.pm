use strict;

package SGN::Controller::AJAX::Nirs;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
# use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Tools::Run;
use CXGN::Tools::List qw/distinct evens/;
use Cwd qw(cwd);
use JSON::XS;
use List::Util qw(shuffle);
use CXGN::AnalysisModel::GetModel;
use CXGN::UploadFile;
use DateTime;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use CXGN::Phenotypes::StorePhenotypes;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub generate_spectral_plot : Path('/ajax/Nirs/generate_spectral_plot') : ActionClass('REST') { }
sub generate_spectral_plot_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $dataset_id = $c->req->param('dataset_id');
    my $nd_protocol_id = $c->req->param('nd_protocol_id');
    my $query_associated_stocks = $c->req->param('query_associated_stocks') eq 'yes' ? 1 : 0;

    my $ds = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
    });

    my $high_dimensional_phenotype_identifier_list = [];
    my ($data_matrix, $identifier_metadata, $identifier_names) = $ds->retrieve_high_dimensional_phenotypes(
        $nd_protocol_id,
        'NIRS',
        $query_associated_stocks,
        $high_dimensional_phenotype_identifier_list
    );
    # print STDERR Dumper $data_matrix;

    if ($data_matrix->{error}) {
        $c->stash->{rest} = {error => $data_matrix->{error}};
        $c->detach();
    }

    my @training_data_input;
    while ( my ($stock_id, $o) = each %$data_matrix) {
        my $spectra = $o->{spectra};
        if ($spectra) {
            push @training_data_input, {
                "observationUnitId" => $stock_id,
                "nirs_spectra" => $spectra,
                "device_type" => $o->{device_type}
            };
        }
    }
    # print STDERR Dumper \@training_data_input;

    if (scalar(@training_data_input) < 5) {
        $c->stash->{rest} = { error => "Not enough data! Need atleast 5 samples with a phenotype and spectra! Maybe choose a different device type?"};
        $c->detach();
    }

    my $nirs_dir = $c->tempfiles_subdir('/nirs_files');
    my $tempfile_string = $c->tempfile( TEMPLATE => 'nirs_files/fileXXXX');
    my $filter_json_filepath = $c->config->{basepath}."/".$tempfile_string."_input_json";

    my $output_plot_filepath_string = $tempfile_string."_output_plot.png";
    my $output_plot_filepath = $c->config->{basepath}."/".$output_plot_filepath_string;

    my $json = JSON->new->utf8->canonical();
    my $training_data_input_json = $json->encode(\@training_data_input);
    open(my $train_json_outfile, '>', $filter_json_filepath);
        print STDERR Dumper $filter_json_filepath;
        print $train_json_outfile $training_data_input_json;
    close($train_json_outfile);

    my $cmd_s = "Rscript ".$c->config->{basepath} . "/R/Nirs/nirs_visualize_spectra.R '$filter_json_filepath' '$output_plot_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    $c->stash->{rest} = {figure => $output_plot_filepath_string};
}

sub generate_results : Path('/ajax/Nirs/generate_results') : ActionClass('REST') { }
sub generate_results_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $format_id = $c->req->param('format');
    my $cv_scheme = $c->req->param('cv');
    my $train_dataset_id = $c->req->param('train_dataset_id');
    my $test_dataset_id = $c->req->param('test_dataset_id');
    my $train_id = $c->req->param('train_id');
    my $test_id = $c->req->param('test_id');
    my $trait_id = $c->req->param('trait_id');
    my $niter_id = $c->req->param('niter');
    my $algo_id =$c->req->param('algorithm');
    my $preprocessing_boolean = $c->req->param('preprocessing');
    my $tune_id = $c->req->param('tune');
    my $rf_var_imp = $c->req->param('rf');

    if ($preprocessing_boolean == 0){
        $preprocessing_boolean = "FALSE";
    } else {
        $preprocessing_boolean = "TRUE";
    }

    if ($rf_var_imp == 0){
        $rf_var_imp = "FALSE";
    } else {
        $rf_var_imp = "TRUE";
    }

    $c->tempfiles_subdir("nirs_files");
    my $nirs_tmp_output = $c->config->{cluster_shared_tempdir}."/nirs_files";
    mkdir $nirs_tmp_output if ! -d $nirs_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
        "nirs_download_XXXXX",
        DIR=> $nirs_tmp_output,
    );

    my $train_json_filepath = $tempfile."_train_json";
    my $test_json_filepath = $tempfile."_test_json";

    my $output_table_filepath = $tempfile."_table_results.csv";
    my $output_figure_filepath = $tempfile."_figure_results.png";
    my $output_table2_filepath = $tempfile."_table2_results.txt";
    my $output_figure2_filepath = $tempfile."_figure2_results.png";
    my $output_model_filepath = $tempfile."_model.Rds";

    my $training_dataset = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $train_dataset_id,
    });
    my ($training_pheno_data, $train_unique_traits) = $training_dataset->retrieve_phenotypes_ref();

    my %training_pheno_data;
    my $seltrait;
    foreach my $d (@$training_pheno_data) {
        my $obsunit_id = $d->{observationunit_stock_id};
        my $germplasm_name = $d->{germplasm_uniquename};
        foreach my $o (@{$d->{observations}}) {
            my $t_id = $o->{trait_id};
            my $t_name = $o->{trait_name};
            my $value = $o->{value};
            if ($trait_id == $t_id) {
                $seltrait = $t_name;
                $training_pheno_data{$obsunit_id} = {
                    value => $value,
                    trait_id => $t_id,
                    trait_name => $t_name,
                    germplasm_name => $germplasm_name
                };
            }
        }
    }
    # print STDERR Dumper \%training_pheno_data;

    my %testing_pheno_data;
    if ($test_dataset_id) {
        my $test_dataset = CXGN::Dataset->new({
            people_schema => $people_schema,
            schema => $schema,
            sp_dataset_id => $test_dataset_id,
        });
        my ($test_pheno_data, $test_unique_traits) = $test_dataset->retrieve_phenotypes_ref();
        # print STDERR Dumper $test_pheno_data;

        foreach my $d ($test_pheno_data) {
            my $obsunit_id = $d->{observationunit_stock_id};
            my $germplasm_name = $d->{germplasm_uniquename};
            foreach my $o (@{$d->{observations}}) {
                my $t_id = $o->{trait_id};
                my $t_name = $o->{trait_name};
                my $value = $o->{value};
                if ($trait_id == $t_id) {
                    $testing_pheno_data{$obsunit_id} = {
                        value => $value,
                        trait_id => $t_id,
                        trait_name => $t_name,
                        germplasm_name => $germplasm_name
                    };
                }
            }
        }

        if (scalar(keys %testing_pheno_data) == 0 ) {
            $c->stash->{rest} = { error => "Not enough data! Are you sure phenotypes were uploaded for the trait in your testing dataset?"};
            $c->detach();
        }
    }
    # else { #waves package will do random split if the input JSON = 'NULL'
    #     my @full_training_plots = keys %training_pheno_data;
    #     my $cutoff = int(scalar(@full_training_plots)*0.2);
    #     my @random_plots = shuffle(@full_training_plots);
    #
    #     my @testing_plots = @random_plots[0..$cutoff];
    #     my @training_plots = @random_plots[$cutoff+1..scalar(@full_training_plots)-1];
    #
    #     my %training_pheno_data_split;
    #     my %testing_pheno_data_split;
    #     foreach (@training_plots) {
    #         $training_pheno_data_split{$_} = $training_pheno_data{$_};
    #     }
    #     foreach (@testing_plots) {
    #         $testing_pheno_data_split{$_} = $training_pheno_data{$_};
    #     }
    #     %training_pheno_data = %training_pheno_data_split;
    #     %testing_pheno_data = %testing_pheno_data_split;
    # }

    if (scalar(keys %training_pheno_data) == 0 ) {
        $c->stash->{rest} = { error => "Not enough data! Are you sure phenotypes were uploaded for the trait in your training dataset?"};
        $c->detach();
    }

    my @all_plot_ids = (keys %training_pheno_data, keys %testing_pheno_data);
    my $stock_ids_sql = join ',', @all_plot_ids;
    my $nirs_training_q = "SELECT stock.uniquename, stock.stock_id, metadata.md_json.json->>'spectra'
        FROM stock
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN phenome.nd_experiment_md_json USING(nd_experiment_id)
        JOIN metadata.md_json USING(json_id)
        WHERE stock.stock_id IN ($stock_ids_sql) AND metadata.md_json.json_type = 'nirs_spectra' AND metadata.md_json.json->>'device_type' = ? ;";
    print STDERR Dumper $nirs_training_q;
    my $nirs_training_h = $dbh->prepare($nirs_training_q);
    $nirs_training_h->execute($format_id);
    while (my ($stock_uniquename, $stock_id, $spectra) = $nirs_training_h->fetchrow_array()) {
        $spectra = decode_json $spectra;
        if (exists($training_pheno_data{$stock_id})) {
            $training_pheno_data{$stock_id}->{spectra} = $spectra;
        }
        if (exists($testing_pheno_data{$stock_id})) {
            $testing_pheno_data{$stock_id}->{spectra} = $spectra;
        }
    }
    # print STDERR Dumper \%training_pheno_data;
    # print STDERR Dumper \%testing_pheno_data;

    my @training_data_input;
    while ( my ($stock_id, $o) = each %training_pheno_data) {
        my $trait_name = $o->{trait_name};
        my $value = $o->{value};
        my $spectra = $o->{spectra};
        my $germplasm_name = $o->{germplasm_name};
        if ($spectra && defined($value)) {
            push @training_data_input, {
                "observationUnitId" => $stock_id,
                "germplasmName" => $germplasm_name,
                "trait" => {$trait_name => $value},
                "nirs_spectra" => $spectra
            };
        }
    }
    # print STDERR Dumper \@training_data_input;

    if (scalar(@training_data_input) < 10) {
        $c->stash->{rest} = { error => "Not enough data! Need atleast 10 samples with a phenotype and spectra! Maybe choose a different device type?"};
        $c->detach();
    }

    my $json = JSON->new->utf8->canonical();
    my $training_data_input_json = $json->encode(\@training_data_input);
    open(my $train_json_outfile, '>', $train_json_filepath);
        print STDERR Dumper $train_json_filepath;
        print $train_json_outfile $training_data_input_json;
    close($train_json_outfile);

    my @testing_data_input;
    while ( my ($stock_id, $o) = each %testing_pheno_data) {
        my $trait_name = $o->{trait_name};
        my $value = $o->{value};
        my $spectra = $o->{spectra};
        my $germplasm_name = $o->{germplasm_name};
        if ($spectra && defined($value)) {
            push @testing_data_input, {
                "observationUnitId" => $stock_id,
                "germplasmName" => $germplasm_name,
                "trait" => {$trait_name => $value},
                "nirs_spectra" => $spectra
            };
        }
    }
    my $testing_data_input_json;
    if (scalar(@testing_data_input) == 0) {
        # $testing_data_input_json = 'NULL';
        $test_json_filepath = 'NULL';
    }
    else {
        $testing_data_input_json = $json->encode(\@testing_data_input);

        open(my $test_json_outfile, '>', $test_json_filepath);
            print STDERR Dumper $test_json_filepath;
            print $test_json_outfile $testing_data_input_json;
        close($test_json_outfile);
    }

    my $trial1_filepath = '';
    my $trial2_filepath = '';
    my $trial3_filepath = '';

    # my $cmd = CXGN::Tools::Run->new({
    #         backend => $c->config->{backend},
    #         temp_base => $c->config->{cluster_shared_tempdir} . "/nirs_files",
    #         queue => $c->config->{'web_cluster_queue'},
    #         do_cleanup => 0,
    #         # don't block and wait if the cluster looks full
    #         max_cluster_jobs => 1_000_000_000,
    #     });
    #
    #     # print STDERR Dumper $pheno_filepath;
    #
    # # my $job;
    # $cmd->run_cluster(
    #         "Rscript ",
    #         $c->config->{basepath} . "/R/Nirs/nirs.R",
    #         $seltrait, # args[1]
    #         $preprocessing_boolean, # args[2]
    #         $niter_id, # args[3]
    #         $algo_id, # args[4]
    #         $tune_id, # args[5]
    #         $rf_var_imp, # args[6]
    #         $cv_scheme, # args[7]
    #         $train_json_filepath, # args[8]
    #         $test_json_filepath, # args[9]
    #         $trial1_filepath, # args[10]
    #         $trial2_filepath, # args[11]
    #         $trial3_filepath, # args[12]
    #         $output_result_filepath # args[13]
    # );
    # $cmd->alive;
    # $cmd->is_cluster(1);
    # $cmd->wait;

    my $cmd_s = "Rscript ".$c->config->{basepath} . "/R/Nirs/nirs.R '$seltrait' '$preprocessing_boolean' '$niter_id' '$algo_id' '$tune_id' '$rf_var_imp' '$cv_scheme' '$train_json_filepath' '$test_json_filepath' 'TRUE' '$output_model_filepath' '$output_table2_filepath' '$output_figure2_filepath' '$output_table_filepath' '$output_figure_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    my @aux_files = (
        {
            auxiliary_model_file_archive_type => "jennasrwaves_V1.01_waves_nirs_spectral_predictions_performance_output",
            auxiliary_model_file => $output_table_filepath
        }
    );
    if ($test_json_filepath ne 'NULL') {
        push @aux_files, {
            auxiliary_model_file_archive_type => "jennasrwaves_V1.01_waves_nirs_spectral_predictions_testing_data_file",
            auxiliary_model_file => $test_json_filepath
        };
    }

    my $performance_output = '';
    open(my $fh, '<', $output_table_filepath)
        or die "Could not open file '$output_table_filepath' $!";

        print STDERR "Opened $output_table_filepath\n";
        while(my $l = <$fh>) {
            $performance_output .= $l;
        }
    close($fh);

    $c->stash->{rest} = {
        train_dataset_id => $train_dataset_id,
        model_properties => {
            'trait_id' => $trait_id,
            'trait_name' => $seltrait,
            'preprocessing_boolean' => $preprocessing_boolean,
            'niter' => $niter_id,
            'algorithm' => $algo_id,
            'tune' => $tune_id,
            'random_forest_importance' => $rf_var_imp,
            'cross_validation' => $cv_scheme,
            'format' => $format_id,
            'protocol' => 'R waves'
        },
        model_file => $output_model_filepath,
        model_file_type => "jennasrwaves_V1.01_waves_nirs_spectral_predictions_weights_file",
        training_data_file => $train_json_filepath,
        training_data_file_type => "jennasrwaves_V1.01_waves_nirs_spectral_predictions_training_data_file",
        model_aux_files => \@aux_files,
        performance_output => $performance_output
    };
}

sub generate_predictions : Path('/ajax/Nirs/generate_predictions') : ActionClass('REST') { }
sub generate_predictions_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $model_id = $c->req->param('model_id');
    my $dataset_id = $c->req->param('dataset_id');

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    print STDERR Dumper $saved_model_object;
    my $trait_name = $saved_model_object->{model_properties}->{trait_name};
    my $trait_id = $saved_model_object->{model_properties}->{trait_id};
    my $format_id = $saved_model_object->{model_properties}->{format};
    my $algorithm = $saved_model_object->{model_properties}->{algorithm};
    my $niter = $saved_model_object->{model_properties}->{niter};
    my $tune = $saved_model_object->{model_properties}->{tune};
    my $cross_validation = $saved_model_object->{model_properties}->{cross_validation};
    my $random_forest_importance = $saved_model_object->{model_properties}->{random_forest_importance};
    my $preprocessing_boolean = $saved_model_object->{model_properties}->{preprocessing_boolean};
    my $model_file = $saved_model_object->{model_files}->{"jennasrwaves_V1.01_waves_nirs_spectral_predictions_weights_file"};
    my $performance_file = $saved_model_object->{model_files}->{"jennasrwaves_V1.01_waves_nirs_spectral_predictions_performance_output"};

    my $training_dataset = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
    });
    my ($training_pheno_data, $train_unique_traits) = $training_dataset->retrieve_phenotypes_ref();
    # print STDERR Dumper $training_pheno_data;

    my $tissue_relationship_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $tissue_sample_plot_q = "SELECT plot.stock_id
        FROM stock AS plot
        JOIN stock_relationship ON (stock_relationship.object_id = plot.stock_id AND stock_relationship.type_id = $tissue_relationship_cvterm_id)
        WHERE plot.type_id = $plot_cvterm_id AND stock_relationship.subject_id = ?;";
    my $tissue_sample_plot_h = $dbh->prepare($tissue_sample_plot_q);

    my %training_pheno_data;
    my $obs_unit_type_name;
    my %seen_accessions;
    foreach my $d (@$training_pheno_data) {
        my $obsunit_id = $d->{observationunit_stock_id};
        my $obsunit_name = $d->{observationunit_uniquename};
        my $germplasm_name = $d->{germplasm_uniquename};
        $obs_unit_type_name = $d->{observationunit_type_name};

        my $plot_id;
        if ($obs_unit_type_name eq 'tissue_sample') {
            $tissue_sample_plot_h->execute($obsunit_id);
            my ($plot_id_ret) = $tissue_sample_plot_h->fetchrow_array();
            $plot_id = $plot_id_ret;
        }
        elsif ($obs_unit_type_name eq 'plot') {
            $plot_id = $obsunit_id;
        }
        else {
            next;
        }

        $seen_accessions{$germplasm_name}++;
        $training_pheno_data{$obsunit_id} = {
            germplasm_name => $germplasm_name,
            trial_id => $d->{trial_id},
            obsunit_name => $obsunit_name,
            plot_id => $plot_id
        };
    }

    my @all_obsunit_ids = keys %training_pheno_data;
    my $stock_ids_sql = join ',', @all_obsunit_ids;
    my $nirs_training_q = "SELECT stock.uniquename, stock.stock_id, metadata.md_json.json->>'spectra'
        FROM stock
        JOIN nd_experiment_stock USING(stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN phenome.nd_experiment_md_json USING(nd_experiment_id)
        JOIN metadata.md_json USING(json_id)
        WHERE stock.stock_id IN ($stock_ids_sql) AND metadata.md_json.json_type = 'nirs_spectra' AND metadata.md_json.json->>'device_type' = ? ;";
    my $nirs_training_h = $dbh->prepare($nirs_training_q);
    $nirs_training_h->execute($format_id);
    while (my ($stock_uniquename, $stock_id, $spectra) = $nirs_training_h->fetchrow_array()) {
        $spectra = decode_json $spectra;
        if (exists($training_pheno_data{$stock_id})) {
            $training_pheno_data{$stock_id}->{spectra} = $spectra;
        }
    }
    # print STDERR Dumper \%training_pheno_data;

    my %seen_field_trial_ids;
    my %seen_plot_ids;
    my @training_data_input;
    while ( my ($stock_id, $o) = each %training_pheno_data) {
        my $spectra = $o->{spectra};
        my $germplasm_name = $o->{germplasm_name};
        if ($spectra) {
            push @training_data_input, {
                "observationUnitId" => $stock_id,
                # "germplasmName" => $germplasm_name,
                "nirs_spectra" => $spectra
            };
            $seen_field_trial_ids{$o->{trial_id}}++;
            $seen_plot_ids{$training_pheno_data{$stock_id}->{plot_id}}++;
        }
    }
    my @field_trial_ids_seen = sort keys %seen_field_trial_ids;

    if (scalar(@training_data_input) == 0) {
        $c->stash->{rest} = { error => "There is no NIRs using $format_id and phenotype data for $trait_name through the dataset selected!" };
        $c->detach();
    }

    my %layout_obs;
    print STDERR Dumper $obs_unit_type_name;
    foreach (@field_trial_ids_seen) {
        my $field_layout = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_})->get_layout->get_design;
        while (my($plot_number, $o) = each %$field_layout) {
            if ($obs_unit_type_name eq 'plot' && exists($seen_plot_ids{$o->{plot_id}})) {
                $layout_obs{$o->{plot_name}} = $o;
            }
            elsif ($obs_unit_type_name eq 'tissue_sample' && exists($seen_plot_ids{$o->{plot_id}})) {
                foreach (@{$o->{tissue_sample_names}}) {
                    $layout_obs{$_} = $o;
                }
            }
        }
    }

    my %analysis_design;
    my $counter = 1;
    while (my ($k, $v) = each %layout_obs) {
        $analysis_design{$counter} = {
            stock_name => $v->{accession_name},
            plot_name => $k,
            plot_number => $counter,
            col_number => $v->{col_number},
            row_number => $v->{row_number},
            rep_number => $v->{rep_number},
            block_number => $v->{block_number},
            is_a_control => $v->{is_a_control}
        };
        $counter++;
    }

    $c->tempfiles_subdir("nirs_files");
    my $nirs_tmp_output = $c->config->{cluster_shared_tempdir}."/nirs_files";
    mkdir $nirs_tmp_output if ! -d $nirs_tmp_output;
    my ($tmp_fh, $tempfile) = tempfile(
        "nirs_download_XXXXX",
        DIR=> $nirs_tmp_output,
    );

    my $input_json_filepath = $tempfile."_prediction_input_json";
    my $output_results_filepath = $tempfile."_table_predictions_results.csv";
    my $output_figure_filepath = $tempfile."_figure_results.png";

    my $training_data_input_json = encode_json \@training_data_input;
    open(my $train_json_outfile, '>', $input_json_filepath);
        print STDERR Dumper $input_json_filepath;
        print $train_json_outfile $training_data_input_json;
    close($train_json_outfile);

    my $cmd_s = "Rscript ".$c->config->{basepath} . "/R/Nirs/predict_NIRS.R '$input_json_filepath' '$performance_file' '$model_file' $algorithm '$output_results_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    my $csv = Text::CSV->new({ sep_char => "," });
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my %result_predictions;
    my %seen_plot_names;
    open(my $fh, '<', $output_results_filepath) or die "Could not open file '$output_results_filepath' $!";
        print STDERR "Opened $output_results_filepath\n";
        my $header = <$fh>;
        my @header_cols;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }

        while (my $row = <$fh>) {
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $stock_id = $columns[0];
            my $stock_name = $training_pheno_data{$stock_id}->{obsunit_name};
            my $value = $columns[1];
            $result_predictions{$stock_name}->{$trait_name} = [$value, $timestamp, $user_name, '', ''];
            $seen_plot_names{$stock_name}++;
        }
    close($fh);

    my @unique_plot_names = sort keys %seen_plot_names;
    my @unique_accession_names = sort keys %seen_accessions;

    my $stat_term;
    if ($algorithm eq 'pls') {
        $stat_term = "Partial least squares regression (PLSR) as implemented with the pls package in R|SGNSTAT:0000014";
    }
    elsif ($algorithm eq 'rf') {
        $stat_term = "Random Forest Regression (RF)  as implemented with the RandomForest package in R|SGNSTAT:0000015";
    }
    elsif ($algorithm eq 'svmLinear') {
        $stat_term = "Support vector machine (SVM) with linear kernel as implemented with the kernLab package in R|SGNSTAT:0000016";
    }
    elsif ($algorithm eq 'svmRadial') {
        $stat_term = "Support vector machine (SVM) with radial kernel as implemented with the kernLab package in R|SGNSTAT:0000017";
    }

    my $protocol = "waves::SaveModel( df = train.ready, save.model = FALSE, autoselect.preprocessing = $preprocessing_boolean, preprocessing.method = $algorithm, model.save.folder = NULL, model.name = 'PredictionModel', best.model.metric = 'RMSE', tune.length = $tune, model.method = model.method, num.iterations = $niter, wavelengths = wls, stratified.sampling = stratified.sampling, cv.scheme = $cross_validation, trial1 = NULL, trial2 = NULL, trial3 = NULL)";

    $c->stash->{rest} = {
        success => 1,
        result_predictions => \%result_predictions,
        unique_traits => [$trait_name],
        unique_plots => \@unique_plot_names,
        unique_accessions => \@unique_accession_names,
        protocol => $protocol,
        stat_term => $stat_term,
        analysis_design => \%analysis_design,
        result_summary => {},
        training_data_file => $input_json_filepath,
        training_data_file_type => "jennasrwaves_V1.01_waves_nirs_spectral_predictions_training_data_file",
    };
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    if ($user_role ne 'submitter' && $user_role ne 'curator') {
        $c->stash->{rest} = {error=>'You do not have permission in the database to do this! Please contact us.'};
        $c->detach();
    }
    return ($user_id, $user_name, $user_role);
}

1
