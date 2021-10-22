use strict;

package SGN::Controller::AJAX::HighDimensionalPhenotypes;

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
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use CXGN::Phenotypes::HighDimensionalPhenotypesRelationshipMatrix;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub high_dimensional_phenotypes_nirs_upload_verify : Path('/ajax/highdimensionalphenotypes/nirs_upload_verify') : ActionClass('REST') { }
sub high_dimensional_phenotypes_nirs_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "spreadsheet nirs";
    my $metadata_file_type = "nirs spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_nirs_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_nirs_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_nirs_spreadsheet_protocol_desc');
    my $protocol_device_type = $c->req->param('upload_nirs_spreadsheet_protocol_device_type');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc)) {
        $c->stash->{rest} = {error => ["Please give a protocol name and description, or select a previous protocol!"]};
        $c->detach();
    }
    if ($protocol_name && !$protocol_device_type) {
        $c->stash->{rest} = {error => ["Please give a NIRS device type to save a new protocol!"]};
        $c->detach();
    }

    my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_nirs_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    if ($protocol_id) {
        my $protocol_prop_json = decode_json $schema->resultset('NaturalDiversity::NdProtocolprop')->search({nd_protocol_id=>$protocol_id, type_id=>$high_dim_nirs_protocol_prop_cvterm_id})->first->value;
        $protocol_device_type = $protocol_prop_json->{device_type};
    }

    my $data_level = $c->req->param('upload_nirs_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_nirs_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $archived_image_zipfile_with_path;
    my $nd_protocol_filename;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $nd_protocol_filename);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $nd_protocol_filename);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @wavelengths;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @wavelengths = @{$parsed_file->{'variables'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    my @filter_input;
    while (my ($stock_name, $o) = each %parsed_data) {
        my $spectras = $o->{nirs}->{spectra};
        foreach my $spectra (@$spectras) {
            push @filter_input, {
                "observationUnitId" => $stock_name,
                "device_type" => $protocol_device_type,
                "nirs_spectra" => $spectra,
            };
        }
    }

    my $nirs_dir = $c->tempfiles_subdir('/nirs_files');
    my $tempfile_string = $c->tempfile( TEMPLATE => 'nirs_files/fileXXXX');
    my $filter_json_filepath = $c->config->{basepath}."/".$tempfile_string."_input_json";
    my $output_csv_filepath = $c->config->{basepath}."/".$tempfile_string."_output.csv";
    my $output_raw_csv_filepath = $c->config->{basepath}."/".$tempfile_string."_output_raw.csv";
    my $output_outliers_filepath = $c->config->{basepath}."/".$tempfile_string."_output_outliers.csv";

    my $output_plot_filepath_string = $tempfile_string."_output_plot.png";
    my $output_plot_filepath = $c->config->{basepath}."/".$output_plot_filepath_string;

    my $json = JSON->new->utf8->canonical();
    my $filter_data_input_json = $json->encode(\@filter_input);
    open(my $F, '>', $filter_json_filepath);
        print STDERR Dumper $filter_json_filepath;
        print $F $filter_data_input_json;
    close($F);

    my $cmd_s = "Rscript ".$c->config->{basepath} . "/R/Nirs/nirs_upload_filter_aggregate.R '$filter_json_filepath' '$output_csv_filepath' '$output_raw_csv_filepath' '$output_plot_filepath' '$output_outliers_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    my $parsed_file_agg = $parser->parse($validate_type, $output_csv_filepath, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $nd_protocol_filename);
    if (!$parsed_file_agg) {
        push @error_status, "Error parsing aggregated file.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file_agg->{'error'}) {
        push @error_status, $parsed_file_agg->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data_agg;
    my @plots_agg;
    my @wavelengths_agg;
    if (scalar(@error_status) == 0) {
        if ($parsed_file_agg && !$parsed_file_agg->{'error'}) {
            %parsed_data_agg = %{$parsed_file_agg->{'data'}};
            @plots_agg = @{$parsed_file_agg->{'units'}};
            @wavelengths_agg = @{$parsed_file_agg->{'variables'}};
            push @success_status, "Aggregated file data successfully parsed.";
        }
    }

    my $pheno_dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots_agg,
        trait_list=>[],
        values_hash=>\%parsed_data_agg,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata
    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "Aggregated file data verified. Plot names and trait names are valid.";

    # print STDERR Dumper \@success_status;
    # print STDERR Dumper \@warning_status;
    # print STDERR Dumper \@error_status;
    # print STDERR Dumper $output_plot_filepath_string;
    $c->stash->{rest} = {success => \@success_status, warning => \@warning_status, error => \@error_status, figure => $output_plot_filepath_string};
}

sub high_dimensional_phenotypes_nirs_upload_store : Path('/ajax/highdimensionalphenotypes/nirs_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_nirs_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "spreadsheet nirs";
    my $metadata_file_type = "nirs spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_nirs_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_nirs_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_nirs_spreadsheet_protocol_desc');
    my $protocol_device_type = $c->req->param('upload_nirs_spreadsheet_protocol_device_type');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc)) {
        $c->stash->{rest} = {error => ["Please give a protocol name and description, or select a previous protocol!"]};
        $c->detach();
    }
    if ($protocol_name && !$protocol_device_type) {
        $c->stash->{rest} = {error => ["Please give a NIRS device type to save a new protocol!"]};
        $c->detach();
    }

    my $high_dim_nirs_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_nirs_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    if ($protocol_id) {
        my $protocol_prop_json = decode_json $schema->resultset('NaturalDiversity::NdProtocolprop')->search({nd_protocol_id=>$protocol_id, type_id=>$high_dim_nirs_protocol_prop_cvterm_id})->first->value;
        $protocol_device_type = $protocol_prop_json->{device_type};
    }

    my $data_level = $c->req->param('upload_nirs_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_nirs_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $archived_image_zipfile_with_path;
    my $nd_protocol_filename;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $nd_protocol_filename);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $nd_protocol_filename);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @wavelengths;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @wavelengths = @{$parsed_file->{'variables'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    my @filter_input;
    while (my ($stock_name, $o) = each %parsed_data) {
        my $spectras = $o->{nirs}->{spectra};
        foreach my $spectra (@$spectras) {
            push @filter_input, {
                "observationUnitId" => $stock_name,
                "device_type" => $protocol_device_type,
                "nirs_spectra" => $spectra
            };
        }
    }

    my $dir = $c->tempfiles_subdir('/nirs_files');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'nirs_files/fileXXXX');

    my $filter_json_filepath = $tempfile."_input_json";
    my $output_csv_filepath = $tempfile."_output.csv";
    my $output_raw_csv_filepath = $tempfile."_output_raw.csv";
    my $output_outliers_filepath = $tempfile."_output_outliers.csv";

    my $tempfile_string = $c->tempfile( TEMPLATE => 'nirs_files/fileXXXX');
    my $output_plot_filepath_string = $tempfile_string."_output_plot.png";
    my $output_plot_filepath = $c->config->{basepath}."/".$output_plot_filepath_string;

    my $json = JSON->new->utf8->canonical();
    my $filter_data_input_json = $json->encode(\@filter_input);
    open(my $F, '>', $filter_json_filepath);
        print STDERR Dumper $filter_json_filepath;
        print $F $filter_data_input_json;
    close($F);

    my $cmd_s = "Rscript ".$c->config->{basepath} . "/R/Nirs/nirs_upload_filter_aggregate.R '$filter_json_filepath' '$output_csv_filepath' '$output_raw_csv_filepath' '$output_plot_filepath' '$output_outliers_filepath' ";
    print STDERR $cmd_s;
    my $cmd_status = system($cmd_s);

    my %parsed_data_agg;

    # Just use one of the spectra:
    #while (my ($stock_name, $o) = each %parsed_data) {
    #    my $spectras = $o->{nirs}->{spectra};
    #    $parsed_data_agg{$stock_name}->{nirs}->{device_type} = $o->{nirs}->{device_type};
    #    $parsed_data_agg{$stock_name}->{nirs}->{spectra} = $spectras->[0];
    #}

    my $agg_file_name =  basename($output_csv_filepath);

    my $uploader_agg = CXGN::UploadFile->new({
        tempfile => $output_csv_filepath,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $agg_file_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_agg_filename_with_path = $uploader->archive();
    my $md5_agg = $uploader_agg->get_md5($archived_agg_filename_with_path);
    if (!$archived_agg_filename_with_path) {
        push @error_status, "Could not save file $agg_file_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $agg_file_name saved in archive.";
    }
    unlink $output_csv_filepath;

    # Using aggregated spectra:
    my $parsed_file_agg = $parser->parse($validate_type, $archived_agg_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $nd_protocol_filename);
    if (!$parsed_file_agg) {
        push @error_status, "Error parsing aggregated file.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file_agg->{'error'}) {
        push @error_status, $parsed_file_agg->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my @plots_agg;
    my @wavelengths_agg;
    if (scalar(@error_status) == 0) {
        if ($parsed_file_agg && !$parsed_file_agg->{'error'}) {
            %parsed_data_agg = %{$parsed_file_agg->{'data'}};
            @plots_agg = @{$parsed_file_agg->{'units'}};
            @wavelengths_agg = @{$parsed_file_agg->{'variables'}};
            push @success_status, "Aggregated file data successfully parsed.";
        }
    }

    if (!$protocol_id) {
        my %nirs_protocol_prop = (
            device_type => $protocol_device_type,
            header_column_names => \@wavelengths_agg,
            header_column_details => {}
        );

        my $protocol = $schema->resultset('NaturalDiversity::NdProtocol')->create({
            name => $protocol_name,
            type_id => $high_dim_nirs_protocol_cvterm_id,
            nd_protocolprops => [{type_id => $high_dim_nirs_protocol_prop_cvterm_id, value => encode_json \%nirs_protocol_prop}]
        });
        $protocol_id = $protocol->nd_protocol_id();

        my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
        my $dbh = $schema->storage->dbh()->prepare($desc_q);
        $dbh->execute($protocol_desc, $protocol_id);
    }

    my %parsed_data_agg_coalesced;
    while (my ($stock_name, $o) = each %parsed_data_agg) {
       my $spectras = $o->{nirs}->{spectra};
       $parsed_data_agg_coalesced{$stock_name}->{nirs}->{protocol_id} = $protocol_id;
       $parsed_data_agg_coalesced{$stock_name}->{nirs}->{device_type} = $protocol_device_type;
       $parsed_data_agg_coalesced{$stock_name}->{nirs}->{spectra} = $spectras->[0];
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_agg_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $pheno_dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots_agg,
        trait_list=>[],
        values_hash=>\%parsed_data_agg_coalesced,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata
    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "Aggregated file data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        push @error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status};
        $c->detach();
    }
    if ($stored_phenotype_success) {
        push @success_status, $stored_phenotype_success;
    }

    push @success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => \@success_status, error => \@error_status, figure => $output_plot_filepath_string, nd_protocol_id => $protocol_id};
}

sub high_dimensional_phenotypes_transcriptomics_upload_verify : Path('/ajax/highdimensionalphenotypes/transcriptomics_upload_verify') : ActionClass('REST') { }
sub high_dimensional_phenotypes_transcriptomics_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "highdimensionalphenotypes spreadsheet transcriptomics";
    my $metadata_file_type = "transcriptomics spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_transcriptomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_transcriptomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_transcriptomics_spreadsheet_protocol_desc');
    my $protocol_unit = $c->req->param('upload_transcriptomics_spreadsheet_protocol_unit');
    my $protocol_genome_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_genome');
    my $protocol_genome_annotation_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_annotation');


    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc || !$protocol_unit || !$protocol_genome_version || !$protocol_genome_annotation_version)) {
        $c->stash->{rest} = {error => ["Please give a protocol name, description, unit, genome and annotation version, or select a previous protocol!"]};
        $c->detach();
    }

    my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_transcriptomics_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $data_level = $c->req->param('upload_transcriptomics_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_transcriptomics_spreadsheet_file_input');
    my $transcript_metadata_upload = $c->req->upload('upload_transcriptomics_transcript_metadata_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $upload_transcripts_original_name = $transcript_metadata_upload->filename();
    my $upload_transcripts_tempfile = $transcript_metadata_upload->tempname;

    my $uploader_transcripts = CXGN::UploadFile->new({
        tempfile => $upload_transcripts_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_transcripts_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_transcripts_with_path = $uploader_transcripts->archive();
    my $md5_transcripts = $uploader_transcripts->get_md5($archived_filename_transcripts_with_path);
    if (!$archived_filename_transcripts_with_path) {
        push @error_status, "Could not save file $upload_transcripts_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_transcripts_original_name saved in archive.";
    }
    unlink $upload_transcripts_tempfile;

    my $archived_image_zipfile_with_path;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @transcripts;
    my %transcripts_details;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @transcripts = @{$parsed_file->{'variables'}};
            %transcripts_details = %{$parsed_file->{'variables_desc'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>[],
        values_hash=>\%parsed_data,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata
    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    # print STDERR Dumper \@success_status;
    # print STDERR Dumper \@warning_status;
    # print STDERR Dumper \@error_status;
    # print STDERR Dumper $output_plot_filepath_string;
    $c->stash->{rest} = {success => \@success_status, warning => \@warning_status, error => \@error_status};
}

sub high_dimensional_phenotypes_transcriptomics_upload_store : Path('/ajax/highdimensionalphenotypes/transcriptomics_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_transcriptomics_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "highdimensionalphenotypes spreadsheet transcriptomics";
    my $metadata_file_type = "transcriptomics spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_transcriptomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_transcriptomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_transcriptomics_spreadsheet_protocol_desc');
    my $protocol_unit = $c->req->param('upload_transcriptomics_spreadsheet_protocol_unit');
    my $protocol_genome_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_genome');
    my $protocol_genome_annotation_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_annotation');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc || !$protocol_unit || !$protocol_genome_version || !$protocol_genome_annotation_version)) {
        $c->stash->{rest} = {error => ["Please give a protocol name, description, unit, genome and annotation version, or select a previous protocol!"]};
        $c->detach();
    }

    my $high_dim_transcriptomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_transcriptomics_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $data_level = $c->req->param('upload_transcriptomics_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_transcriptomics_spreadsheet_file_input');
    my $transcript_metadata_upload = $c->req->upload('upload_transcriptomics_transcript_metadata_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $upload_transcripts_original_name = $transcript_metadata_upload->filename();
    my $upload_transcripts_tempfile = $transcript_metadata_upload->tempname;

    my $uploader_transcripts = CXGN::UploadFile->new({
        tempfile => $upload_transcripts_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_transcripts_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_transcripts_with_path = $uploader_transcripts->archive();
    my $md5_transcripts = $uploader_transcripts->get_md5($archived_filename_transcripts_with_path);
    if (!$archived_filename_transcripts_with_path) {
        push @error_status, "Could not save file $upload_transcripts_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_transcripts_original_name saved in archive.";
    }
    unlink $upload_transcripts_tempfile;

    my $archived_image_zipfile_with_path;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @transcripts;
    my %transcripts_details;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @transcripts = @{$parsed_file->{'variables'}};
            %transcripts_details = %{$parsed_file->{'variables_desc'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    if (!$protocol_id) {
        my %transcriptomics_protocol_prop = (
            expression_unit => $protocol_unit,
            genome_version => $protocol_genome_version,
            annotation_version => $protocol_genome_annotation_version,
            header_column_names => \@transcripts,
            header_column_details => \%transcripts_details
        );

        my $protocol = $schema->resultset('NaturalDiversity::NdProtocol')->create({
            name => $protocol_name,
            type_id => $high_dim_transcriptomics_protocol_cvterm_id,
            nd_protocolprops => [{type_id => $high_dim_transcriptomics_protocol_prop_cvterm_id, value => encode_json \%transcriptomics_protocol_prop}]
        });
        $protocol_id = $protocol->nd_protocol_id();

        my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
        my $dbh = $schema->storage->dbh()->prepare($desc_q);
        $dbh->execute($protocol_desc, $protocol_id);
    }

    my %parsed_data_agg_coalesced;
    while (my ($stock_name, $o) = each %parsed_data) {
        my $spectras = $o->{transcriptomics}->{transcripts};
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics} = $spectras->[0];
        $parsed_data_agg_coalesced{$stock_name}->{transcriptomics}->{protocol_id} = $protocol_id;
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $pheno_dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>[],
        values_hash=>\%parsed_data_agg_coalesced,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata

    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        push @error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status};
        $c->detach();
    }
    if ($stored_phenotype_success) {
        push @success_status, $stored_phenotype_success;
    }

    push @success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new({ dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname} });
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => \@success_status, error => \@error_status, nd_protocol_id => $protocol_id};
}

sub high_dimensional_phenotypes_metabolomics_upload_verify : Path('/ajax/highdimensionalphenotypes/metabolomics_upload_verify') : ActionClass('REST') { }
sub high_dimensional_phenotypes_metabolomics_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "highdimensionalphenotypes spreadsheet metabolomics";
    my $metadata_file_type = "metabolomics spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_metabolomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_metabolomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_desc');
    my $protocol_equipment_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_type');
    my $protocol_equipment_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_description');
    my $protocol_data_process_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_data_process_description');
    my $protocol_phenotype_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_type');
    my $protocol_phenotype_units = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_units');
    my $protocol_chromatography_system_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_system_brand');
    my $protocol_chromatography_column_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_column_brand');
    my $protocol_ms_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_brand');
    my $protocol_ms_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_type');
    my $protocol_ms_instrument_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_instrument_type');
    my $protocol_ms_ion_mode = $c->req->param('upload_metabolomics_spreadsheet_protocol_ion_mode');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc)) {
        $c->stash->{rest} = {error => ["Please give a protocol name and description, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_equipment_type || !$protocol_equipment_desc || !$protocol_data_process_desc || !$protocol_phenotype_type || !$protocol_phenotype_units)) {
        $c->stash->{rest} = {error => ["Please give all protocol equipment descriptions, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && $protocol_equipment_type eq 'MS' && (!$protocol_chromatography_system_brand || !$protocol_chromatography_column_brand || !$protocol_ms_brand || !$protocol_ms_type || !$protocol_ms_instrument_type || !$protocol_ms_ion_mode)) {
        $c->stash->{rest} = {error => ["If defining a MS protocol please give all information fields!"]};
        $c->detach();
    }

    my $high_dim_metabolomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_metabolomics_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_metabolomics_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $data_level = $c->req->param('upload_metabolomics_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_metabolomics_spreadsheet_file_input');
    my $metabolite_details_upload = $c->req->upload('upload_metabolomics_metabolite_details_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $upload_transcripts_original_name = $metabolite_details_upload->filename();
    my $upload_transcripts_tempfile = $metabolite_details_upload->tempname;

    my $uploader_transcripts = CXGN::UploadFile->new({
        tempfile => $upload_transcripts_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_transcripts_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_transcripts_with_path = $uploader_transcripts->archive();
    my $md5_transcripts = $uploader_transcripts->get_md5($archived_filename_transcripts_with_path);
    if (!$archived_filename_transcripts_with_path) {
        push @error_status, "Could not save file $upload_transcripts_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_transcripts_original_name saved in archive.";
    }
    unlink $upload_transcripts_tempfile;

    my $archived_image_zipfile_with_path;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @metabolites;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @metabolites = @{$parsed_file->{'variables'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    my $dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>[],
        values_hash=>\%parsed_data,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata
    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    # print STDERR Dumper \@success_status;
    # print STDERR Dumper \@warning_status;
    # print STDERR Dumper \@error_status;
    # print STDERR Dumper $output_plot_filepath_string;
    $c->stash->{rest} = {success => \@success_status, warning => \@warning_status, error => \@error_status};
}

sub high_dimensional_phenotypes_metabolomics_upload_store : Path('/ajax/highdimensionalphenotypes/metabolomics_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_metabolomics_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;
    my @warning_status;

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $validate_type = "highdimensionalphenotypes spreadsheet metabolomics";
    my $metadata_file_type = "metabolomics spreadsheet";
    my $subdirectory = "spreadsheet_phenotype_upload";
    my $timestamp_included;

    my $protocol_id = $c->req->param('upload_metabolomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_metabolomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_desc');
    my $protocol_equipment_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_type');
    my $protocol_equipment_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_description');
    my $protocol_data_process_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_data_process_description');
    my $protocol_phenotype_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_type');
    my $protocol_phenotype_units = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_units');
    my $protocol_chromatography_system_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_system_brand');
    my $protocol_chromatography_column_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_column_brand');
    my $protocol_ms_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_brand');
    my $protocol_ms_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_type');
    my $protocol_ms_instrument_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_instrument_type');
    my $protocol_ms_ion_mode = $c->req->param('upload_metabolomics_spreadsheet_protocol_ion_mode');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc)) {
        $c->stash->{rest} = {error => ["Please give a protocol name and description, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_equipment_type || !$protocol_equipment_desc || !$protocol_data_process_desc || !$protocol_phenotype_type || !$protocol_phenotype_units)) {
        $c->stash->{rest} = {error => ["Please give all protocol equipment descriptions, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && $protocol_equipment_type eq 'MS' && (!$protocol_chromatography_system_brand || !$protocol_chromatography_column_brand || !$protocol_ms_brand || !$protocol_ms_type || !$protocol_ms_instrument_type || !$protocol_ms_ion_mode)) {
        $c->stash->{rest} = {error => ["If defining a MS protocol please give all information fields!"]};
        $c->detach();
    }

    my $high_dim_metabolomics_protocol_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_metabolomics_protocol', 'protocol_type')->cvterm_id();
    my $high_dim_metabolomics_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    my $data_level = $c->req->param('upload_metabolomics_spreadsheet_data_level') || 'tissue_samples';
    my $upload = $c->req->upload('upload_metabolomics_spreadsheet_file_input');
    my $metabolite_details_upload = $c->req->upload('upload_metabolomics_metabolite_details_spreadsheet_file_input');

    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @error_status, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $upload_transcripts_original_name = $metabolite_details_upload->filename();
    my $upload_transcripts_tempfile = $metabolite_details_upload->tempname;

    my $uploader_transcripts = CXGN::UploadFile->new({
        tempfile => $upload_transcripts_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_transcripts_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type
    });
    my $archived_filename_transcripts_with_path = $uploader_transcripts->archive();
    my $md5_transcripts = $uploader_transcripts->get_md5($archived_filename_transcripts_with_path);
    if (!$archived_filename_transcripts_with_path) {
        push @error_status, "Could not save file $upload_transcripts_original_name in archive.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    } else {
        push @success_status, "File $upload_transcripts_original_name saved in archive.";
    }
    unlink $upload_transcripts_tempfile;

    my $archived_image_zipfile_with_path;
    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema, $archived_image_zipfile_with_path, $user_id, $c, $protocol_id, $archived_filename_transcripts_with_path);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    my %parsed_data;
    my @plots;
    my @metabolites;
    my %metabolites_details;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'units'}};
            @metabolites = @{$parsed_file->{'variables'}};
            %metabolites_details = %{$parsed_file->{'variables_desc'}};
            push @success_status, "File data successfully parsed.";
        }
    }

    if (!$protocol_id) {
        my %metabolomics_protocol_prop = (
            header_column_names => \@metabolites,
            header_column_details => %metabolites_details,
            equipment_type => $protocol_equipment_type,
            equipment_description => $protocol_equipment_desc,
            data_process_description => $protocol_data_process_desc,
            phenotype_type => $protocol_phenotype_type,
            phenotype_units => $protocol_phenotype_units
        );
        if ($protocol_equipment_type eq 'MS') {
            $metabolomics_protocol_prop{chromatography_system_brand} = $protocol_chromatography_system_brand;
            $metabolomics_protocol_prop{chromatography_column_brand} = $protocol_chromatography_column_brand;
            $metabolomics_protocol_prop{ms_brand} = $protocol_ms_brand;
            $metabolomics_protocol_prop{ms_type} = $protocol_ms_type;
            $metabolomics_protocol_prop{ms_instrument_type} = $protocol_ms_instrument_type;
            $metabolomics_protocol_prop{ms_ion_mode} = $protocol_ms_ion_mode;
        }

        my $protocol = $schema->resultset('NaturalDiversity::NdProtocol')->create({
            name => $protocol_name,
            type_id => $high_dim_metabolomics_protocol_cvterm_id,
            nd_protocolprops => [{type_id => $high_dim_metabolomics_protocol_prop_cvterm_id, value => encode_json \%metabolomics_protocol_prop}]
        });
        $protocol_id = $protocol->nd_protocol_id();

        my $desc_q = "UPDATE nd_protocol SET description=? WHERE nd_protocol_id=?;";
        my $dbh = $schema->storage->dbh()->prepare($desc_q);
        $dbh->execute($protocol_desc, $protocol_id);
    }

    my %parsed_data_agg;
    while (my ($stock_name, $o) = each %parsed_data) {
        my $spectras = $o->{metabolomics}->{metabolites};
        $parsed_data_agg{$stock_name}->{metabolomics} = $spectras->[0];
        $parsed_data_agg{$stock_name}->{metabolomics}->{protocol_id} = $protocol_id;
    }

    ## Set metadata
    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    $phenotype_metadata{'operator'} = $user_name;
    $phenotype_metadata{'date'} = $timestamp;

    my $pheno_dir = $c->tempfiles_subdir('/delete_nd_experiment_ids');
    my $temp_file_nd_experiment_id = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'delete_nd_experiment_ids/fileXXXX');

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
        basepath=>$c->config->{basepath},
        dbhost=>$c->config->{dbhost},
        dbname=>$c->config->{dbname},
        dbuser=>$c->config->{dbuser},
        dbpass=>$c->config->{dbpass},
        temp_file_nd_experiment_id=>$temp_file_nd_experiment_id,
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>\@plots,
        trait_list=>[],
        values_hash=>\%parsed_data_agg,
        has_timestamps=>0,
        metadata_hash=>\%phenotype_metadata
    });

    my $warning_status;
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    if ($verified_error) {
        push @error_status, $verified_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status };
        $c->detach();
    }
    if ($verified_warning) {
        push @warning_status, $verified_warning;
    }
    push @success_status, "File data verified. Plot names and trait names are valid.";

    my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
    if ($stored_phenotype_error) {
        push @error_status, $stored_phenotype_error;
        $c->stash->{rest} = {success => \@success_status, error => \@error_status};
        $c->detach();
    }
    if ($stored_phenotype_success) {
        push @success_status, $stored_phenotype_success;
    }

    push @success_status, "Metadata saved for archived file.";
    my $bs = CXGN::BreederSearch->new({ dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname} });
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    $c->stash->{rest} = {success => \@success_status, error => \@error_status, nd_protocol_id => $protocol_id};
}

sub high_dimensional_phenotypes_download_file : Path('/ajax/highdimensionalphenotypes/download_file') : ActionClass('REST') { }
sub high_dimensional_phenotypes_download_file_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my $error;

    my $dataset_id = $c->req->param('dataset_id');
    my $nd_protocol_id = $c->req->param('nd_protocol_id');
    my $high_dimensional_phenotype_type = $c->req->param('high_dimensional_phenotype_type');
    my $high_dimensional_download_type = $c->req->param('download_file_type');
    my $query_associated_stocks = $c->req->param('query_associated_stocks') eq 'yes' ? 1 : 0;

    my $ds = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
    });

    my $high_dimensional_phenotype_identifier_list = [];
    my ($data_matrix, $identifier_metadata, $identifier_names) = $ds->retrieve_high_dimensional_phenotypes(
        $nd_protocol_id,
        $high_dimensional_phenotype_type,
        $query_associated_stocks,
        $high_dimensional_phenotype_identifier_list
    );

    if ($data_matrix->{error}) {
        $c->stash->{rest} = {error => $data_matrix->{error}};
        $c->detach();
    }

    # print STDERR Dumper $data_matrix;
    # print STDERR Dumper $identifier_metadata;
    # print STDERR Dumper $identifier_names;

    if ($data_matrix->{error}) {
        $c->stash->{rest} = {error => $data_matrix->{error}};
        $c->detach();
    }

    my $dir = $c->tempfiles_subdir('/high_dimensional_phenotypes_download');
    my $download_file_link = $c->tempfile( TEMPLATE => 'high_dimensional_phenotypes_download/downloadXXXX');
    $download_file_link .= '.csv';
    my $download_file_tempfile = $c->config->{basepath}."/".$download_file_link;

    open(my $F, ">", $download_file_tempfile) || die "Can't open file ".$download_file_tempfile;

        if ($high_dimensional_phenotype_type eq 'NIRS') {

            #Old NIRS data were loaded without the protocol identifer_names saved
            if (!$identifier_names || scalar(@$identifier_names) == 0) {
                my @stock_ids = keys %$data_matrix;
                my @ids = keys %{$data_matrix->{$stock_ids[0]}->{spectra}};
                my @ids_stripped;
                foreach (@ids) {
                    my $s = substr $_, 1;
                    push @ids_stripped, $s;
                }
                $identifier_names = \@ids_stripped;
            }

            my @identifier_names_sorted = sort { $a <=> $b } @$identifier_names;

            if ($high_dimensional_download_type eq 'data_matrix') {
                my @header = ('stock_id', @identifier_names_sorted);
                my $header_string = join ',', @header;
                print $F $header_string."\n";

                while ( my ($stock_id, $o) = each %$data_matrix) {
                    my $spectra = $o->{spectra};
                    if ($spectra) {
                        my @row = ($stock_id);
                        foreach (@identifier_names_sorted) {
                            push @row, $spectra->{"X$_"};
                        }
                        my $line = join ',', @row;
                        print $F $line."\n";
                    }
                }
            }
            elsif ($high_dimensional_download_type eq 'identifier_metadata') {
                my $header_string = 'spectra';
                print $F $header_string."\n";

                foreach (@identifier_names_sorted) {
                    print $F "X$_\n";
                }
            }
        }
        elsif ($high_dimensional_phenotype_type eq 'Transcriptomics') {

            my @identifier_names_sorted = sort @$identifier_names;

            if ($high_dimensional_download_type eq 'data_matrix') {
                my @header = ('stock_id', @identifier_names_sorted);
                my $header_string = join ',', @header;
                print $F $header_string."\n";

                while ( my ($stock_id, $o) = each %$data_matrix) {
                    my $spectra = $o->{transcriptomics};
                    if ($spectra) {
                        my @row = ($stock_id);
                        foreach (@identifier_names_sorted) {
                            push @row, $spectra->{$_};
                        }
                        my $line = join ',', @row;
                        print $F $line."\n";
                    }
                }
            }
            elsif ($high_dimensional_download_type eq 'identifier_metadata') {
                my $header_string = 'transcript_name,chromosome,start_position,end_position,gene_description,notes';
                print $F $header_string."\n";

                foreach (@identifier_names_sorted) {
                    my $chromosome = $identifier_metadata->{$_}->{chr};
                    my $start_position = $identifier_metadata->{$_}->{start};
                    my $end_position = $identifier_metadata->{$_}->{end};
                    my $gene_description = $identifier_metadata->{$_}->{gene_desc};
                    my $notes = $identifier_metadata->{$_}->{notes};
                    print $F "$_,$chromosome,$start_position,$end_position,$gene_description,$notes\n";
                }
            }
        }
        elsif ($high_dimensional_phenotype_type eq 'Metabolomics') {

            my @identifier_names_sorted = sort @$identifier_names;

            if ($high_dimensional_download_type eq 'data_matrix') {
                my @header = ('stock_id', @identifier_names_sorted);
                my $header_string = join ',', @header;
                print $F $header_string."\n";

                while ( my ($stock_id, $o) = each %$data_matrix) {
                    my $spectra = $o->{metabolomics};
                    if ($spectra) {
                        my @row = ($stock_id);
                        foreach (@identifier_names_sorted) {
                            push @row, $spectra->{$_};
                        }
                        my $line = join ',', @row;
                        print $F $line."\n";
                    }
                }
            }
            elsif ($high_dimensional_download_type eq 'identifier_metadata') {
                my $header_string = 'metabolite_name,inchi_key,compound_name';
                print $F $header_string."\n";

                foreach (@identifier_names_sorted) {
                    my $inchi = $identifier_metadata->{$_}->{inchi_key};
                    my $compound = $identifier_metadata->{$_}->{compound_name};
                    print $F "$_,$inchi,$compound\n";
                }
            }
        }

    close($F);

    $c->stash->{rest} = {download_file_link => $download_file_link, error => $error};
}

sub high_dimensional_phenotypes_download_relationship_matrix_file : Path('/ajax/highdimensionalphenotypes/download_relationship_matrix_file') : ActionClass('REST') { }
sub high_dimensional_phenotypes_download_relationship_matrix_file_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my $error;

    my $dataset_id = $c->req->param('dataset_id');
    my $nd_protocol_id = $c->req->param('nd_protocol_id');
    my $high_dimensional_phenotype_type = $c->req->param('high_dimensional_phenotype_type');
    my $query_associated_stocks = $c->req->param('query_associated_stocks') eq 'yes' ? 1 : 0;

    my $ds = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $schema,
        sp_dataset_id => $dataset_id,
    });

    my $dir = $c->tempfiles_subdir('/high_dimensional_phenotypes_relationship_matrix_download');
    my $temp_data_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'high_dimensional_phenotypes_relationship_matrix_download/downloadXXXX');
    my $download_file_link = $c->tempfile( TEMPLATE => 'high_dimensional_phenotypes_relationship_matrix_download/downloadXXXX');
    $download_file_link .= '.csv';
    my $download_file_tempfile = $c->config->{basepath}."/".$download_file_link;

    my ($relationship_matrix_data, $data_matrix, $identifier_metadata, $identifier_names) = $ds->retrieve_high_dimensional_phenotypes_relationship_matrix(
        $nd_protocol_id,
        $high_dimensional_phenotype_type,
        $query_associated_stocks,
        $temp_data_file,
        $download_file_tempfile
    );
    # print STDERR Dumper $relationship_matrix_data;
    # print STDERR Dumper $data_matrix;
    # print STDERR Dumper $identifier_metadata;
    # print STDERR Dumper $identifier_names;

    $c->stash->{rest} = {download_file_link => $download_file_link, error => $error};
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

1;
