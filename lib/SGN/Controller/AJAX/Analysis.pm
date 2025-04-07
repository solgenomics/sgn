package SGN::Controller::AJAX::Analysis;

use Moose;

use File::Slurp;
use Data::Dumper;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Trial::TrialDesign;
use CXGN::Analysis::AnalysisCreate;
use CXGN::AnalysisModel::GetModel;
use URI::FromHash 'uri';
use JSON;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );



sub ajax_analysis : Chained('/') PathPart('ajax/analysis') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;

    $c->stash->{analysis_id} = $analysis_id;
}

sub store_analysis_json : Path('/ajax/analysis/store/json') ActionClass("REST") Args(0) {}

sub store_analysis_json_POST {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    print STDERR Dumper $c->req->params();
    my $analysis_to_save_boolean = $c->req->param("analysis_to_save_boolean");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_description = $c->req->param("analysis_description");
    my $analysis_year = $c->req->param("analysis_year");
    my $analysis_breeding_program_id = $c->req->param("analysis_breeding_program_id");
    my $analysis_protocol = $c->req->param("analysis_protocol");
    my $analysis_dataset_id = $c->req->param("analysis_dataset_id");
    my $analysis_accession_names = $c->req->param("analysis_accession_names") ? decode_json $c->req->param("analysis_accession_names") : [];
    my $analysis_result_stock_names = $c->req->param("analysis_result_stock_names") ? decode_json $c->req->param("analysis_result_stock_names") : [];
    my $is_analysis_result_stock_type = $c->req->param("is_analysis_result_stock_type");
    my $analysis_trait_names = $c->req->param("analysis_trait_names") ? decode_json $c->req->param("analysis_trait_names") : [];
    my $analysis_statistical_ontology_term = $c->req->param('analysis_statistical_ontology_term');
    my $analysis_precomputed_design_optional = $c->req->param("analysis_precomputed_design_optional") ? decode_json $c->req->param("analysis_precomputed_design_optional") : undef;
    my $analysis_result_values = $c->req->param("analysis_result_values") ? decode_json $c->req->param("analysis_result_values") : {};
    my $analysis_result_values_type = $c->req->param("analysis_result_values_type");
    my $analysis_result_summary = $c->req->param("analysis_result_summary") ? decode_json $c->req->param("analysis_result_summary") : {};
    my $analysis_result_trait_compose_info = $c->req->param("analysis_result_trait_compose_info") ? decode_json $c->req->param("analysis_result_trait_compose_info") : {};
    my $analysis_model_id = $c->req->param("analysis_model_id") ? $c->req->param("analysis_model_id") : undef;
    my $analysis_model_name = $c->req->param("analysis_model_name");
    my $analysis_model_description = $c->req->param("analysis_model_description");
    my $analysis_model_is_public = $c->req->param("analysis_model_is_public");
    my $analysis_model_language = $c->req->param("analysis_model_language");
    my $analysis_model_type = $c->req->param("analysis_model_type");
    my $analysis_model_properties = $c->req->param("analysis_model_properties") ? decode_json $c->req->param("analysis_model_properties") : {};
    my $analysis_model_application_name = $c->req->param("analysis_model_application_name");
    my $analysis_model_application_version = $c->req->param("analysis_model_application_version");
    my $analysis_model_file = $c->req->param("analysis_model_file");
    my $analysis_model_file_type = $c->req->param("analysis_model_file_type");
    my $analysis_model_training_data_file = $c->req->param("analysis_model_training_data_file");
    my $analysis_model_training_data_file_type = $c->req->param("analysis_model_training_data_file_type");
    my $analysis_model_auxiliary_files = $c->req->param("analysis_model_auxiliary_files") ? decode_json $c->req->param("analysis_model_auxiliary_files") : [];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if ($analysis_to_save_boolean eq 'yes' && !$analysis_name) {
        $c->stash->{rest} = {error => "You are trying to save an analysis, but no name was given."};
        return;
    }
    if ($analysis_name) {
        my $check_name = $schema->resultset("Project::Project")->find({ name => $analysis_name });
        if ($check_name) {
            $c->stash->{rest} = {error => "An analysis with name $analysis_name already exists in the database. Please choose another name."};
            return;
        }
    }

    $self->store_data($c,
        $analysis_to_save_boolean,
        $analysis_name, $analysis_description, $analysis_year, $analysis_breeding_program_id, $analysis_protocol, $analysis_dataset_id, $analysis_accession_names, $analysis_trait_names, $analysis_statistical_ontology_term, $analysis_precomputed_design_optional, $analysis_result_values, $analysis_result_values_type, $analysis_result_summary, $analysis_result_trait_compose_info,
        $analysis_model_id, $analysis_model_name, $analysis_model_description, $analysis_model_is_public, $analysis_model_language, $analysis_model_type, $analysis_model_properties, $analysis_model_application_name, $analysis_model_application_version, $analysis_model_file, $analysis_model_file_type, $analysis_model_training_data_file, $analysis_model_training_data_file_type, $analysis_model_auxiliary_files,
        $user_id, $user_name, $user_role, $analysis_result_stock_names, $is_analysis_result_stock_type
    );
}

sub store_analysis_spreadsheet : Path('/ajax/analysis/store/spreadsheet') ActionClass("REST") Args(0) {}

sub store_analysis_spreadsheet_POST {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    print STDERR Dumper $c->req->params();
    my $analysis_to_save_boolean = "yes";
    my $analysis_name = $c->req->param("upload_new_analysis_name");
    my $analysis_description = $c->req->param("upload_new_analysis_description");
    my $analysis_year = $c->req->param("upload_new_analysis_year");
    my $analysis_breeding_program_id = $c->req->param("upload_new_analysis_breeding_program_id");
    my $analysis_protocol = $c->req->param("upload_new_analysis_protocol");
    my $analysis_dataset_id = $c->req->param("upload_new_analysis_dataset_id");
    my $analysis_result_file = $c->req->upload("upload_new_analysis_file");
    # my $analysis_accession_names = $c->req->param("analysis_accession_names") ? decode_json $c->req->param("analysis_accession_names") : [];
    # my $analysis_trait_names = $c->req->param("analysis_trait_names") ? decode_json $c->req->param("analysis_trait_names") : [];
    my $analysis_statistical_ontology_term = $c->req->param('upload_new_analysis_statistical_ontology_term');
    # my $analysis_precomputed_design_optional = $c->req->param("analysis_precomputed_design_optional") ? decode_json $c->req->param("analysis_precomputed_design_optional") : undef;
    # my $analysis_result_values = $c->req->param("analysis_result_values") ? decode_json $c->req->param("analysis_result_values") : {};
    my $analysis_result_values_type = $c->req->param("upload_new_analysis_result_values_type");
    my $analysis_result_summary_string = $c->req->param("upload_new_analysis_result_summary_string");
    my $analysis_result_trait_compose_info_string = $c->req->param("upload_new_analysis_result_trait_compose_info_string");
    my $analysis_model_id = $c->req->param("upload_new_analysis_model_id") ? $c->req->param("upload_new_analysis_model_id") : undef;
    my $analysis_model_name = $c->req->param("upload_new_analysis_model_name");
    my $analysis_model_description = $c->req->param("upload_new_analysis_model_description");
    my $analysis_model_is_public = $c->req->param("upload_new_analysis_model_is_public");
    my $analysis_model_language = $c->req->param("upload_new_analysis_model_language");
    my $analysis_model_type = 'uploaded_generic_analysis_model';
    my $analysis_model_properties_string = $c->req->param("upload_new_analysis_model_properties_string");
    my $analysis_model_application_name = $c->req->param("upload_new_analysis_model_application_name");
    my $analysis_model_application_version = $c->req->param("upload_new_analysis_model_application_version");
    my $analysis_model_file_upload = $c->req->upload("upload_new_analysis_model_file");
    my $analysis_model_file_type = $c->req->param("upload_new_analysis_model_file_type");
    my $analysis_model_training_data_file_upload = $c->req->upload("upload_new_analysis_model_training_data_file");
    my $analysis_model_training_data_file_type = $c->req->param("upload_new_analysis_model_training_data_file_type");
    my $analysis_model_auxiliary_file_1 = $c->req->upload("upload_new_analysis_model_auxiliary_file_1");
    my $analysis_model_auxiliary_file_type_1 = $c->req->param("upload_new_analysis_model_auxiliary_file_type_1");
    my $analysis_model_auxiliary_file_2 = $c->req->upload("upload_new_analysis_model_auxiliary_file_2");
    my $analysis_model_auxiliary_file_type_2 = $c->req->param("upload_new_analysis_model_auxiliary_file_type_2");
    my $analysis_model_auxiliary_file_3 = $c->req->upload("upload_new_analysis_model_auxiliary_file_3");
    my $analysis_model_auxiliary_file_type_3 = $c->req->param("upload_new_analysis_model_auxiliary_file_type_3");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my @error_status;

    my $check_name = $schema->resultset("Project::Project")->find({ name => $analysis_name });
    if ($check_name) {
        $c->stash->{rest} = {error => "An analysis with name $analysis_name already exists in the database. Please choose another name."};
        $c->detach();
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'upload_analysis_generic';

    my $analysis_model_auxiliary_files;
    if ($analysis_model_auxiliary_file_1 && $analysis_model_auxiliary_file_type_1) {
        my $upload_original_name = $analysis_model_auxiliary_file_1->filename();
        my $upload_tempfile = $analysis_model_auxiliary_file_1->tempname;

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
            $c->detach();
        }
        unlink $upload_tempfile;
        
        push @$analysis_model_auxiliary_files, {
            auxiliary_model_file_archive_type => $analysis_model_auxiliary_file_type_1,
            auxiliary_model_file => $archived_filename_with_path
        };
    }
    if ($analysis_model_auxiliary_file_2 && $analysis_model_auxiliary_file_type_2) {
        my $upload_original_name = $analysis_model_auxiliary_file_2->filename();
        my $upload_tempfile = $analysis_model_auxiliary_file_2->tempname;

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
            $c->detach();
        }
        unlink $upload_tempfile;

        push @$analysis_model_auxiliary_files, {
            auxiliary_model_file_archive_type => $analysis_model_auxiliary_file_type_2,
            auxiliary_model_file => $archived_filename_with_path
        };
    }
    if ($analysis_model_auxiliary_file_3 && $analysis_model_auxiliary_file_type_3) {
        my $upload_original_name = $analysis_model_auxiliary_file_3->filename();
        my $upload_tempfile = $analysis_model_auxiliary_file_3->tempname;

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
            $c->detach();
        }
        unlink $upload_tempfile;

        push @$analysis_model_auxiliary_files, {
            auxiliary_model_file_archive_type => $analysis_model_auxiliary_file_type_3,
            auxiliary_model_file => $archived_filename_with_path
        };
    }

    my $analysis_model_file;
    if ($analysis_model_file_upload && $analysis_model_file_type) {
        my $upload_original_name = $analysis_model_file_upload->filename();
        my $upload_tempfile = $analysis_model_file_upload->tempname;

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
            $c->detach();
        }
        unlink $upload_tempfile;

        $analysis_model_file = $archived_filename_with_path;
    }

    my $analysis_model_training_data_file;
    if ($analysis_model_training_data_file_upload && $analysis_model_training_data_file_type) {
        my $upload_original_name = $analysis_model_training_data_file_upload->filename();
        my $upload_tempfile = $analysis_model_training_data_file_upload->tempname;

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
            $c->detach();
        }
        unlink $upload_tempfile;

        $analysis_model_training_data_file = $archived_filename_with_path;
    }

    my $data_level;
    if ($analysis_result_values_type eq 'analysis_result_values_match_precomputed_design') {
        $data_level = 'plot';
    }
    elsif ($analysis_result_values_type eq 'analysis_result_values_match_accession_names'){
        $data_level = 'accession';
    }
    else {
        $c->stash->{rest} = {error => "Analysis result type not accepted!"};
        $c->detach();
    }

    my @analysis_result_summary_array = split ',', $analysis_result_summary_string;
    my $analysis_result_summary;
    foreach (@analysis_result_summary_array) {
        my ($key, $value) = split ':', $_;
        $analysis_result_summary->{$key} = $value;
    }

    my @analysis_result_trait_compose_info_array = split ',', $analysis_result_trait_compose_info_string;
    my $analysis_result_trait_compose_info;
    foreach (@analysis_result_trait_compose_info_array) {
        my ($key, $value) = split '\|\|\|\|', $_;
        $analysis_result_trait_compose_info->{$key} = [$value];
    }

    my @analysis_model_properties_array = split ',', $analysis_model_properties_string;
    my $analysis_model_properties;
    foreach (@analysis_model_properties_array) {
        my ($key, $value) = split ':', $_;
        $analysis_model_properties->{$key} = $value;
    }

    my $upload_original_name = $analysis_result_file->filename();
    my $upload_tempfile = $analysis_result_file->tempname;

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive."};
        $c->detach();
    }
    unlink $upload_tempfile;
    #print STDERR "Archived Phenotype File: $archived_filename_with_path\n";

    my $validate_type = 'analysis phenotype spreadsheet csv';
    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, undef, $data_level, $schema, undef, undef);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {error_messages => \@error_status};
        $c->detach();
    }
    if ($validate_file == 1){
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {error_messages => \@error_status};
        $c->detach();
    }

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, undef, $data_level, $schema, undef, $user_id, $c, undef);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {error_messages => \@error_status};
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {error_messages => \@error_status};
        $c->detach();
    }
    my $analysis_result_values;
    my @stocks;
    my $analysis_trait_names;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            $analysis_result_values = $parsed_file->{'data'};
            @stocks = @{$parsed_file->{'units'}};
            $analysis_trait_names = $parsed_file->{'variables'};
        }
    }

    my $analysis_accession_names;
    my $analysis_precomputed_design_optional;
    if ($analysis_result_values_type eq 'analysis_result_values_match_precomputed_design') {

        my %seen_stocks = map {$_ => 1} @stocks;
        my $plot_names_string = join '\',\'', @stocks;
        my $field_trial_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
        my $q = "SELECT project_id
            FROM nd_experiment_project
            JOIN nd_experiment ON(nd_experiment.nd_experiment_id = nd_experiment_project.nd_experiment_id and nd_experiment.type_id=$field_trial_experiment_cvterm_id)
            JOIN nd_experiment_stock ON(nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN stock USING(stock_id)
            WHERE stock.uniquename IN ('$plot_names_string');";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my %unique_field_trials;
        while( my ($field_trial_id) = $h->fetchrow_array()) {
            $unique_field_trials{$field_trial_id}++;
        }
        foreach my $field_trial_id (keys %unique_field_trials) {
            my $field_trial_design_full = CXGN::Trial->new({bcs_schema => $schema, trial_id=>$field_trial_id})->get_layout()->get_design();
            while (my($plot_number, $plot_obj) = each %$field_trial_design_full) {
                my $plot_name = $plot_obj->{plot_name};
                if (exists($seen_stocks{$plot_name})) {
                    my $plot_number_unique = $field_trial_id."_".$plot_number;
                    $analysis_precomputed_design_optional->{$plot_number_unique} = {
                        stock_name => $plot_obj->{accession_name},
                        block_number => $plot_obj->{block_number},
                        col_number => $plot_obj->{col_number},
                        row_number => $plot_obj->{row_number},
                        plot_name => $plot_name,
                        plot_number => $plot_number_unique,
                        rep_number => $plot_obj->{rep_number},
                        is_a_control => $plot_obj->{is_a_control}
                    };
                }
            }
        }
    }
    elsif ($analysis_result_values_type eq 'analysis_result_values_match_accession_names') {
        $analysis_accession_names = \@stocks;
    }

    $self->store_data($c,
        $analysis_to_save_boolean,
        $analysis_name, $analysis_description, $analysis_year, $analysis_breeding_program_id, $analysis_protocol, $analysis_dataset_id, $analysis_accession_names, $analysis_trait_names, $analysis_statistical_ontology_term, $analysis_precomputed_design_optional, $analysis_result_values, $analysis_result_values_type, $analysis_result_summary, $analysis_result_trait_compose_info,
        $analysis_model_id, $analysis_model_name, $analysis_model_description, $analysis_model_is_public, $analysis_model_language, $analysis_model_type, $analysis_model_properties, $analysis_model_application_name, $analysis_model_application_version, $analysis_model_file, $analysis_model_file_type, $analysis_model_training_data_file, $analysis_model_training_data_file_type, $analysis_model_auxiliary_files,
        $user_id, $user_name, $user_role
    );
}

sub store_data {
    my $self = shift;
    my ($c, $analysis_to_save_boolean, $analysis_name, $analysis_description, $analysis_year, 
    $analysis_breeding_program_id, $analysis_protocol, $analysis_dataset_id, 
    $analysis_accession_names, $analysis_trait_names, 
    $analysis_statistical_ontology_term, $analysis_precomputed_design_optional, 
    $analysis_result_values, $analysis_result_values_type, $analysis_result_summary, 
    $analysis_result_trait_compose_info, $analysis_model_id, $analysis_model_name, 
    $analysis_model_description, $analysis_model_is_public, 
    $analysis_model_language, $analysis_model_type, $analysis_model_properties, 
    $analysis_model_application_name, $analysis_model_application_version, 
    $analysis_model_file, $analysis_model_file_type, $analysis_model_training_data_file, 
    $analysis_model_training_data_file_type, $analysis_model_auxiliary_files, 
    $user_id, $user_name, $user_role, $analysis_result_stock_names, $is_analysis_result_stock_type) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $m = CXGN::Analysis::AnalysisCreate->new({
        bcs_schema=>$bcs_schema,
        people_schema=>$people_schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        archive_path=>$c->config->{archive_path},
        tempfile_for_deleting_nd_experiment_ids=>$temp_file_nd_experiment_id,
        base_path=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        analysis_to_save_boolean=>$analysis_to_save_boolean,
        analysis_name=>$analysis_name,
        analysis_description=>$analysis_description,
        analysis_year=>$analysis_year,
        analysis_breeding_program_id=>$analysis_breeding_program_id,
        analysis_protocol=>$analysis_protocol,
        analysis_dataset_id=>$analysis_dataset_id,
        analysis_accession_names=>$analysis_accession_names,
        analysis_result_stock_names=>$analysis_result_stock_names,
        is_analysis_result_stock_type=>$is_analysis_result_stock_type,
        analysis_trait_names=>$analysis_trait_names,
        analysis_statistical_ontology_term=>$analysis_statistical_ontology_term,
        analysis_precomputed_design_optional=>$analysis_precomputed_design_optional,
        analysis_result_values=>$analysis_result_values,
        analysis_result_values_type=>$analysis_result_values_type,
        analysis_result_summary=>$analysis_result_summary,
        analysis_result_trait_compose_info_time=>$analysis_result_trait_compose_info,
        analysis_model_id=>$analysis_model_id,
        analysis_model_name=>$analysis_model_name,
        analysis_model_description=>$analysis_model_description,
        analysis_model_is_public=>$analysis_model_is_public,
        analysis_model_language=>$analysis_model_language,
        analysis_model_type=>$analysis_model_type,
        analysis_model_properties=>$analysis_model_properties,
        analysis_model_application_name=>$analysis_model_application_name,
        analysis_model_application_version=>$analysis_model_application_version,
        analysis_model_file=>$analysis_model_file,
        analysis_model_file_type=>$analysis_model_file_type,
        analysis_model_training_data_file=>$analysis_model_training_data_file,
        analysis_model_training_data_file_type=>$analysis_model_training_data_file_type,
        analysis_model_auxiliary_files=>$analysis_model_auxiliary_files,
        allowed_composed_cvs=>\@allowed_composed_cvs,
        composable_cvterm_delimiter=>$composable_cvterm_delimiter,
        composable_cvterm_format=>$composable_cvterm_format,
        user_id=>$user_id,
        user_name=>$user_name,
        user_role=>$user_role
    });
    my $saved_analysis_object = $m->store();

    $c->stash->{rest} = $saved_analysis_object;
}

sub list_analyses_by_user_table :Path('/ajax/analyses/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $analysis_model_type = $c->req->param('analysis_model_type');

    my @analyses = CXGN::Analysis->retrieve_analyses_by_user($schema, $people_schema, $metadata_schema, $phenome_schema, $user_id, $analysis_model_type);

    my @table;
    foreach my $a (@analyses) {
        my $saved_model = $a->saved_model();
        my $model_type = $saved_model->{model_type_name} ? $saved_model->{model_type_name} : '';
        my $protocol = $saved_model->{model_properties}->{protocol} ? $saved_model->{model_properties}->{protocol} : '';
        my $application_name = $saved_model->{model_properties}->{application_name} ? $saved_model->{model_properties}->{application_name} : '';
        my $application_version = $saved_model->{model_properties}->{application_version} ? $saved_model->{model_properties}->{application_version} : '';
        my $model_language = $saved_model->{model_properties}->{model_language} ? $saved_model->{model_properties}->{model_language} : '';
        push @table, [
            '<a href="/analyses/'.$a->get_trial_id().'">'.$a->name()."</a>",
            $a->description(),
            $model_type,
            $protocol,
            $application_name.":".$application_version,
            $model_language,
        ];
    }

    #print STDERR Dumper(\@table);
    $c->stash->{rest} = { data => \@table };
}

sub list_analyses_models_by_user_table :Path('/ajax/analyses/models/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $analysis_model_type = $c->req->param('analysis_model_type');

    my $analysis_models_by_user = CXGN::AnalysisModel::GetModel::get_models_by_user($schema, $user_id, $analysis_model_type);
    #print STDERR Dumper $analysis_models_by_user;

    my @table;
    foreach my $saved_model (values %$analysis_models_by_user) {
        my $model_type = $saved_model->{model_type_name} ? $saved_model->{model_type_name} : '';
        my $protocol = $saved_model->{model_properties}->{protocol} ? $saved_model->{model_properties}->{protocol} : '';
        my $application_name = $saved_model->{model_properties}->{application_name} ? $saved_model->{model_properties}->{application_name} : '';
        my $application_version = $saved_model->{model_properties}->{application_version} ? $saved_model->{model_properties}->{application_version} : '';
        my $model_language = $saved_model->{model_properties}->{model_language} ? $saved_model->{model_properties}->{model_language} : '';
        push @table, [
            '<a href="/analyses_model/'.$saved_model->{model_id}.'">'.$saved_model->{model_name}."</a>",
            $saved_model->{model_description},
            $model_type,
            $protocol,
            $application_name.":".$application_version,
            $model_language,
        ];
    }
    #print STDERR Dumper(\@table);
    $c->stash->{rest} = { data => \@table };
}

sub list_analyses_by_model_table :Path('/ajax/analyses/by_model') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $model_id = $c->req->param('model_id');
    my $analysis_by_model = CXGN::AnalysisModel::GetModel::get_analyses_by_model($schema, $model_id);
    print STDERR Dumper $analysis_by_model;

    my @table;
    foreach my $a (@$analysis_by_model) {
        push @table, [
            '<a href="/analyses/'.$a->{analysis_id}.'">'.$a->{analysis_name}."</a>",
            $a->{description},
        ];
    }
    #print STDERR Dumper(\@table);
    $c->stash->{rest} = { data => \@table };
}

=head1 retrieve_analysis_data()

Chained from ajax_analysis
URL = /ajax/analysis/<analysis_id>/retrieve
returns data for the analysis_id in the following json structure:
{ 
    analysis_name
    analysis_description
    analysis_result_type
    dataset
    analysis_protocol
    accession_names
    data
}

=cut

sub retrieve_analysis_data :Chained("ajax_analysis") PathPart('retrieve') :Args(0)  {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $a = CXGN::Analysis->new({
            bcs_schema => $bcs_schema,
            people_schema => $people_schema,
            metadata_schema => $metadata_schema,
            phenome_schema => $phenome_schema,
            trial_id => $c->stash->{analysis_id}
    });

    my $dataset_id = "";
    my $dataset_name = "";
    my $dataset_description = "";

    if ($a->metadata()->dataset_id()) {
        my $ds = CXGN::Dataset->new({ schema => $bcs_schema, people_schema => $people_schema, sp_dataset_id => $a->metadata()->dataset_id() });
        $dataset_id = $ds->sp_dataset_id();
        $dataset_name = $ds->name();
        $dataset_description = $ds->description();
    }

    my $matrix = $a->get_phenotype_matrix();
    # print STDERR "Matrix: ".Dumper($matrix);
    my $dataref = [];

    # format table body with links but exclude header
    my $header = shift @$matrix;
    $header = [ @$header[18, 39..scalar(@$header)-1 ]];

    foreach my $row (@$matrix) {
        my ($stock_id, $stock_name, @values) =  @$row[17,18,39..scalar(@$row)-1];
        # print STDERR "NEW ROW: $stock_id, $stock_name, ".join(",", @values)."\n";
        push @$dataref, [
            "<a href=\"/stock/$stock_id/view\">$stock_name</a>",
            @values
        ];
    }

    unshift @$dataref, $header;

    # print STDERR "TRAITS : ".Dumper($a->traits());
    my $resultref = {
        analysis_name => $a->name(),
        analysis_description => $a->description(),
        dataset => {
            dataset_id => $dataset_id,
            dataset_name => $dataset_name,
            dataset_description => $dataset_description,
        },
        #accession_ids => $a ->accession_ids(),
        analysis_protocol => $a->metadata()->analysis_protocol(),
        create_timestamp => $a->metadata()->create_timestamp(),
        accession_names => $a->accession_names(),
        traits => $a->traits(),
        data => $dataref,
        model_info => $a->saved_model()
    };

    $c->stash->{rest} = $resultref;
}

sub analysis_model_delete :Path('/ajax/analysis_model/delete') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c, 'curator');

    my $model_id = $c->req->param('model_id');
    my $analysis_by_model = CXGN::AnalysisModel::GetModel::get_analyses_by_model($schema, $model_id);
    if (scalar(@$analysis_by_model) > 0) {
        $c->stash->{rest} = {error=>'This model still has analyses associated! Please delete the analyses before deleting this model!'};
        $c->detach();
    }

    my $m = CXGN::AnalysisModel::GetModel->new({
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        nd_protocol_id=>$model_id
    });
    my $saved_model_object = $m->get_model();
    my $nd_experiment_id = $saved_model_object->{model_experiment_id};
    my $file_ids = $saved_model_object->{model_file_ids};

    my $q1 = "DELETE FROM nd_experiment WHERE nd_experiment_id=?;";
    my $h1 = $schema->storage->dbh()->prepare($q1);
    $h1->execute($nd_experiment_id);

    my $q2 = "DELETE FROM nd_protocol WHERE nd_protocol_id=?;";
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute($model_id);

    $c->stash->{rest} = { success => 1 };
}

sub _check_user_login {
    my $c = shift;
    my $role_check = shift;
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
    if ($role_check && $user_role ne $role_check) {
        $c->stash->{rest} = {error=>'You must have permission to do this! Please contact us!'};
        $c->detach();
    }
    return ($user_id, $user_name, $user_role);
}

1;
