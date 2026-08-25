use strict;

package SGN::Controller::AJAX::HighDimensionalPhenotypes;

use Moose;
use Data::Dumper;
use Try::Tiny;
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
use CXGN::File;
use CXGN::Job;
use CXGN::Login;
use CXGN::People::Person;
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

    $self->_upload_nirs($c, 'verify');
}

sub high_dimensional_phenotypes_nirs_upload_store : Path('/ajax/highdimensionalphenotypes/nirs_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_nirs_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    $self->_upload_nirs($c, 'store');
}

=head2 _upload_nirs($c, $mode)

Archives an uploaded NIRS spreadsheet and hands it to the background script that reads it. Shared by
the verify and store endpoints, which differ only in what the script is asked to do with the file:
"verify" reports on the file without saving anything, "store" saves the spectra in it.

The upload manager archives the file before calling here and follows the job itself, so it gets an
answer as soon as the job has been submitted. The upload dialog posts the file directly and shows
the outcome when the request comes back, so it waits for the job to finish before it is answered.

=cut

sub _upload_nirs {
    my $self = shift;
    my $c = shift;
    my $mode = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;

    my $subdirectory = "spreadsheet_phenotype_upload";
    my $ignore_warnings = $c->req->param('ignore_warnings') ? 1 : 0;

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

    my $high_dim_nirs_protocol_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_protocol_properties', 'protocol_property')->cvterm_id();

    # A previously saved protocol already knows what device it was recorded on, and the uploader is
    # not asked again, so the device type has to be read back off it.
    if ($protocol_id) {
        my $protocol_prop_json = decode_json $schema->resultset('NaturalDiversity::NdProtocolprop')->search({nd_protocol_id=>$protocol_id, type_id=>$high_dim_nirs_protocol_prop_cvterm_id})->first->value;
        $protocol_device_type = $protocol_prop_json->{device_type};
    }

    my $data_level = $c->req->param('upload_nirs_spreadsheet_data_level') || 'tissue_samples';
    my $archived_file_id = $c->req->param('archived_file_id') || undef;

    # The upload manager archives a file before calling here, so a file that is already in the
    # archive is one it is going to follow the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my ($archived_filename_with_path, $upload_original_name, $main_file_id) = _archive_high_dim_file($c, {
        archived_file_id => $archived_file_id,
        upload_field => 'upload_nirs_spreadsheet_file_input',
        subdirectory => $subdirectory,
        file_type => 'nirs',
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
        metadata_schema => $metadata_schema,
        success_status => \@success_status,
        error_status => \@error_status
    });
    $archived_file_id = $main_file_id;

    # Everything that describes the upload goes on the job rather than on the command line, since
    # most of it is text the uploader typed, which does not belong in a shell string.
    my $upload_params = {
        archived_filename => $archived_filename_with_path,
        archived_file_id => $archived_file_id,
        upload_original_name => $upload_original_name,
        protocol_id => $protocol_id,
        protocol_name => $protocol_name,
        protocol_desc => $protocol_desc,
        protocol_device_type => $protocol_device_type,
        data_level => $data_level,
        ignore_warnings => $ignore_warnings,
        user_id => $user_id,
        user_name => $user_name,
        user_role => $user_type,
        timestamp => $timestamp,
        success_messages => \@success_status
    };

    my $additional_args = {
        file_type => 'nirs',
        user_name => $user_name,
        file_id => $archived_file_id,
        upload_params => $upload_params
    };

    if ($mode eq 'verify') {
        $additional_args->{is_validation} = 1;
        $additional_args->{ignore_warnings} = $ignore_warnings;
        # The upload manager reads these back off a validation job to build the request that stores
        # the file once someone has looked at the validation.
        $additional_args->{protocol_params} = {
            upload_nirs_spreadsheet_protocol_id => $protocol_id,
            upload_nirs_spreadsheet_protocol_name => $protocol_name,
            upload_nirs_spreadsheet_protocol_desc => $protocol_desc,
            upload_nirs_spreadsheet_protocol_device_type => $protocol_device_type,
            upload_nirs_spreadsheet_data_level => $data_level
        };
    } else {
        $additional_args->{final_upload} = 1;
    }

    my $job_name = basename($archived_filename_with_path).($mode eq 'verify' ? " nirs validation" : " nirs upload");

    _submit_high_dim_upload($c, {
        script => 'upload_nirs_phenotypes.pl',
        mode => $mode,
        entity => 'NIRS',
        schema => $schema,
        people_schema => $people_schema,
        user_id => $user_id,
        job_name => $job_name,
        additional_args => $additional_args,
        from_upload_manager => $from_upload_manager,
        success_status => \@success_status,
        error_status => \@error_status
    });
}

sub high_dimensional_phenotypes_transcriptomics_upload_verify : Path('/ajax/highdimensionalphenotypes/transcriptomics_upload_verify') : ActionClass('REST') { }
sub high_dimensional_phenotypes_transcriptomics_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    $self->_upload_transcriptomics($c, 'verify');
}

sub high_dimensional_phenotypes_transcriptomics_upload_store : Path('/ajax/highdimensionalphenotypes/transcriptomics_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_transcriptomics_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    $self->_upload_transcriptomics($c, 'store');
}

=head2 _upload_transcriptomics($c, $mode)

Archives an uploaded transcriptomics spreadsheet and the transcript details file that goes with it,
and hands them to the background script that reads them. Shared by the verify and store endpoints,
which differ only in what the script is asked to do with the file.

=cut

sub _upload_transcriptomics {
    my $self = shift;
    my $c = shift;
    my $mode = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;

    my $subdirectory = "spreadsheet_phenotype_upload";
    my $ignore_warnings = $c->req->param('ignore_warnings') ? 1 : 0;

    my $protocol_id = $c->req->param('upload_transcriptomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_transcriptomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_transcriptomics_spreadsheet_protocol_desc');
    my $protocol_unit = $c->req->param('upload_transcriptomics_spreadsheet_protocol_unit');
    my $protocol_genome_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_genome');
    my $protocol_genome_annotation_version = $c->req->param('upload_transcriptomics_spreadsheet_protocol_annotation');
    my $protocol_instrument_model = $c->req->param('upload_transcriptomics_spreadsheet_protocol_instrument_model');
    my $protocol_layout = $c->req->param('upload_transcriptomics_spreadsheet_protocol_layout');
    my $protocol_library_method = $c->req->param('upload_transcriptomics_spreadsheet_protocol_library_method');
    my $protocol_library_comments = $c->req->param('upload_transcriptomics_spreadsheet_protocol_library_comments');
    my $protocol_mapping_software = $c->req->param('upload_transcriptomics_spreadsheet_protocol_mapping_software');
    my $protocol_sequencing_center = $c->req->param('upload_transcriptomics_spreadsheet_protocol_sequencing_center');
    my $protocol_sequencing_platform = $c->req->param('upload_transcriptomics_spreadsheet_protocol_sequencing_platform');
    my $protocol_read_length = $c->req->param('upload_transcriptomics_spreadsheet_protocol_read_length');
    my $protocol_nucleic_acid_extraction_method = $c->req->param('upload_transcriptomics_spreadsheet_protocol_nucleic_acid_extraction_method');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc || !$protocol_unit || !$protocol_genome_version || !$protocol_genome_annotation_version)) {
        $c->stash->{rest} = {error => ["Please give a protocol name, description, unit, genome and annotation version, or select a previous protocol!"]};
        $c->detach();
    }

    my $data_level = $c->req->param('upload_transcriptomics_spreadsheet_data_level') || 'tissue_samples';
    my $archived_file_id = $c->req->param('archived_file_id') || undef;
    my $archived_metadata_file_id = $c->req->param('archived_metadata_file_id') || undef;

    # The upload manager archives a file before calling here, so a file that is already in the
    # archive is one it is going to follow the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my ($archived_filename_with_path, $upload_original_name, $main_file_id) = _archive_high_dim_file($c, {
        archived_file_id => $archived_file_id,
        upload_field => 'upload_transcriptomics_spreadsheet_file_input',
        subdirectory => $subdirectory,
        file_type => 'transcriptomics',
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
        metadata_schema => $metadata_schema,
        success_status => \@success_status,
        error_status => \@error_status
    });
    $archived_file_id = $main_file_id;

    my ($archived_filename_transcripts_with_path, $upload_transcripts_original_name, $transcripts_file_id) = _archive_high_dim_file($c, {
        archived_file_id => $archived_metadata_file_id,
        upload_field => 'upload_transcriptomics_transcript_metadata_spreadsheet_file_input',
        subdirectory => $subdirectory,
        file_type => 'transcriptomics',
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
        metadata_schema => $metadata_schema,
        success_status => \@success_status,
        error_status => \@error_status
    });
    $archived_metadata_file_id = $transcripts_file_id;

    # Everything that describes the upload goes on the job rather than on the command line, since
    # most of it is text the uploader typed, which does not belong in a shell string.
    my $upload_params = {
        archived_filename => $archived_filename_with_path,
        archived_file_id => $archived_file_id,
        archived_metadata_filename => $archived_filename_transcripts_with_path,
        upload_original_name => $upload_original_name,
        protocol_id => $protocol_id,
        protocol_name => $protocol_name,
        protocol_desc => $protocol_desc,
        protocol_unit => $protocol_unit,
        protocol_genome_version => $protocol_genome_version,
        protocol_genome_annotation_version => $protocol_genome_annotation_version,
        protocol_instrument_model => $protocol_instrument_model,
        protocol_layout => $protocol_layout,
        protocol_library_method => $protocol_library_method,
        protocol_library_comments => $protocol_library_comments,
        protocol_mapping_software => $protocol_mapping_software,
        protocol_sequencing_center => $protocol_sequencing_center,
        protocol_sequencing_platform => $protocol_sequencing_platform,
        protocol_read_length => $protocol_read_length,
        protocol_nucleic_acid_extraction_method => $protocol_nucleic_acid_extraction_method,
        data_level => $data_level,
        ignore_warnings => $ignore_warnings,
        user_id => $user_id,
        user_name => $user_name,
        user_role => $user_type,
        timestamp => $timestamp,
        success_messages => \@success_status
    };

    my $additional_args = {
        file_type => 'transcriptomics',
        user_name => $user_name,
        file_id => $archived_file_id,
        metadata_file_id => $archived_metadata_file_id,
        upload_params => $upload_params
    };

    if ($mode eq 'verify') {
        $additional_args->{is_validation} = 1;
        $additional_args->{ignore_warnings} = $ignore_warnings;
        # The upload manager reads these back off a validation job to build the request that stores
        # the file once someone has looked at the validation.
        $additional_args->{protocol_params} = {
            upload_transcriptomics_spreadsheet_protocol_id => $protocol_id,
            upload_transcriptomics_spreadsheet_protocol_name => $protocol_name,
            upload_transcriptomics_spreadsheet_protocol_desc => $protocol_desc,
            upload_transcriptomics_spreadsheet_protocol_unit => $protocol_unit,
            upload_transcriptomics_spreadsheet_protocol_genome => $protocol_genome_version,
            upload_transcriptomics_spreadsheet_protocol_annotation => $protocol_genome_annotation_version,
            upload_transcriptomics_spreadsheet_data_level => $data_level
        };
    } else {
        $additional_args->{final_upload} = 1;
    }

    my $job_name = basename($archived_filename_with_path).($mode eq 'verify' ? " transcriptomics validation" : " transcriptomics upload");

    _submit_high_dim_upload($c, {
        script => 'upload_transcriptomics_phenotypes.pl',
        mode => $mode,
        entity => 'transcriptomics',
        schema => $schema,
        people_schema => $people_schema,
        user_id => $user_id,
        job_name => $job_name,
        additional_args => $additional_args,
        from_upload_manager => $from_upload_manager,
        success_status => \@success_status,
        error_status => \@error_status
    });
}

sub high_dimensional_phenotypes_metabolomics_upload_verify : Path('/ajax/highdimensionalphenotypes/metabolomics_upload_verify') : ActionClass('REST') { }
sub high_dimensional_phenotypes_metabolomics_upload_verify_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    $self->_upload_metabolomics($c, 'verify');
}

sub high_dimensional_phenotypes_metabolomics_upload_store : Path('/ajax/highdimensionalphenotypes/metabolomics_upload_store') : ActionClass('REST') { }
sub high_dimensional_phenotypes_metabolomics_upload_store_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    $self->_upload_metabolomics($c, 'store');
}

=head2 _upload_metabolomics($c, $mode)

Archives an uploaded metabolomics spreadsheet and the metabolite details file that goes with it,
and hands them to the background script that reads them. Shared by the verify and store endpoints,
which differ only in what the script is asked to do with the file.

=cut

sub _upload_metabolomics {
    my $self = shift;
    my $c = shift;
    my $mode = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my ($user_id, $user_name, $user_type) = _check_user_login($c);
    my @success_status;
    my @error_status;

    my $subdirectory = "spreadsheet_phenotype_upload";
    my $ignore_warnings = $c->req->param('ignore_warnings') ? 1 : 0;

    my $protocol_id = $c->req->param('upload_metabolomics_spreadsheet_protocol_id');
    my $protocol_name = $c->req->param('upload_metabolomics_spreadsheet_protocol_name');
    my $protocol_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_desc');

    my $protocol_equipment_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_type');
    my $protocol_target = $c->req->param('upload_metabolomics_spreadsheet_protocol_target');
    my $protocol_sample_collection = $c->req->param('upload_metabolomics_spreadsheet_protocol_sample_collection_protocol');
    my $protocol_sample_extraction = $c->req->param('upload_metabolomics_spreadsheet_protocol_sample_extraction_protocol');
    my $protocol_rawdata_transformation = $c->req->param('upload_metabolomics_spreadsheet_protocol_rawdata_transformation_protocol');
    my $protocol_metabolite_identification = $c->req->param('upload_metabolomics_spreadsheet_protocol_metabolite_identification_protocol');

    my $protocol_equipment_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_equipment_description');
    my $protocol_data_process_desc = $c->req->param('upload_metabolomics_spreadsheet_protocol_data_process_description');
    my $protocol_phenotype_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_type');
    my $protocol_phenotype_units = $c->req->param('upload_metabolomics_spreadsheet_protocol_phenotype_units');
    my $protocol_chromatography_system_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_system_brand');
    my $protocol_chromatography_column_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_column_brand');

    my $protocol_chromatography_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_type');
    my $protocol_chromatography_autosampler_model = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_AutoSampler_Model');
    my $protocol_chromatography_column_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_column_type');
    my $protocol_chromatography_protocol = $c->req->param('upload_metabolomics_spreadsheet_protocol_chromatography_protocol');
    my $protocol_mass_spectrometry_protocol = $c->req->param('upload_metabolomics_spreadsheet_protocol_mass_spectrometry_protocol');

    my $protocol_ms_brand = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_brand');
    my $protocol_ms_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_mass_analyzer');
    my $protocol_ms_instrument_type = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_scan_polarity');
    my $protocol_ms_ion_mode = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_ion_source');
    my $protocol_ms_scan_mz_range = $c->req->param('upload_metabolomics_spreadsheet_protocol_ms_scan_MZ_Range');
    my $protocol_publication = $c->req->param('upload_metabolomics_spreadsheet_protocol_publication');

    if ($protocol_id && $protocol_name) {
        $c->stash->{rest} = {error => ["Please give a protocol name or select a previous protocol, not both!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_name || !$protocol_desc)) {
        $c->stash->{rest} = {error => ["Please give a protocol name and description, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && (!$protocol_equipment_type || !$protocol_equipment_desc || !$protocol_data_process_desc || !$protocol_phenotype_type || !$protocol_phenotype_units || !$protocol_target || !$protocol_sample_collection || !$protocol_sample_extraction || !$protocol_rawdata_transformation || !$protocol_metabolite_identification)) {
        $c->stash->{rest} = {error => ["Please give all protocol equipment descriptions, or select a previous protocol!"]};
        $c->detach();
    }
    if (!$protocol_id && $protocol_equipment_type eq 'MS' && (!$protocol_chromatography_system_brand || !$protocol_chromatography_column_brand || !$protocol_ms_brand || !$protocol_ms_type || !$protocol_ms_instrument_type || !$protocol_ms_ion_mode || !$protocol_chromatography_type || !$protocol_chromatography_column_type || !$protocol_chromatography_protocol || !$protocol_mass_spectrometry_protocol || !$protocol_ms_scan_mz_range)) {
        $c->stash->{rest} = {error => ["If defining a MS protocol please give all information fields!"]};
        $c->detach();
    }

    my $data_level = $c->req->param('upload_metabolomics_spreadsheet_data_level') || 'tissue_samples';
    my $archived_file_id = $c->req->param('archived_file_id') || undef;
    my $archived_metadata_file_id = $c->req->param('archived_metadata_file_id') || undef;

    # The upload manager archives a file before calling here, so a file that is already in the
    # archive is one it is going to follow the job for itself.
    my $from_upload_manager = $archived_file_id ? 1 : 0;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my ($archived_filename_with_path, $upload_original_name, $main_file_id) = _archive_high_dim_file($c, {
        archived_file_id => $archived_file_id,
        upload_field => 'upload_metabolomics_spreadsheet_file_input',
        subdirectory => $subdirectory,
        file_type => 'metabolomics',
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
        metadata_schema => $metadata_schema,
        success_status => \@success_status,
        error_status => \@error_status
    });
    $archived_file_id = $main_file_id;

    my ($archived_filename_metabolites_with_path, $upload_metabolites_original_name, $metabolites_file_id) = _archive_high_dim_file($c, {
        archived_file_id => $archived_metadata_file_id,
        upload_field => 'upload_metabolomics_metabolite_details_spreadsheet_file_input',
        subdirectory => $subdirectory,
        file_type => 'metabolomics',
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
        metadata_schema => $metadata_schema,
        success_status => \@success_status,
        error_status => \@error_status
    });
    $archived_metadata_file_id = $metabolites_file_id;

    # Everything that describes the upload goes on the job rather than on the command line, since
    # most of it is text the uploader typed, which does not belong in a shell string.
    my $upload_params = {
        archived_filename => $archived_filename_with_path,
        archived_file_id => $archived_file_id,
        archived_metadata_filename => $archived_filename_metabolites_with_path,
        upload_original_name => $upload_original_name,
        protocol_id => $protocol_id,
        protocol_name => $protocol_name,
        protocol_desc => $protocol_desc,
        protocol_equipment_type => $protocol_equipment_type,
        protocol_target => $protocol_target,
        protocol_sample_collection => $protocol_sample_collection,
        protocol_sample_extraction => $protocol_sample_extraction,
        protocol_rawdata_transformation => $protocol_rawdata_transformation,
        protocol_metabolite_identification => $protocol_metabolite_identification,
        protocol_equipment_desc => $protocol_equipment_desc,
        protocol_data_process_desc => $protocol_data_process_desc,
        protocol_phenotype_type => $protocol_phenotype_type,
        protocol_phenotype_units => $protocol_phenotype_units,
        protocol_chromatography_system_brand => $protocol_chromatography_system_brand,
        protocol_chromatography_column_brand => $protocol_chromatography_column_brand,
        protocol_chromatography_type => $protocol_chromatography_type,
        protocol_chromatography_autosampler_model => $protocol_chromatography_autosampler_model,
        protocol_chromatography_column_type => $protocol_chromatography_column_type,
        protocol_chromatography_protocol => $protocol_chromatography_protocol,
        protocol_mass_spectrometry_protocol => $protocol_mass_spectrometry_protocol,
        protocol_ms_brand => $protocol_ms_brand,
        protocol_ms_type => $protocol_ms_type,
        protocol_ms_instrument_type => $protocol_ms_instrument_type,
        protocol_ms_ion_mode => $protocol_ms_ion_mode,
        protocol_ms_scan_mz_range => $protocol_ms_scan_mz_range,
        protocol_publication => $protocol_publication,
        data_level => $data_level,
        ignore_warnings => $ignore_warnings,
        user_id => $user_id,
        user_name => $user_name,
        user_role => $user_type,
        timestamp => $timestamp,
        success_messages => \@success_status
    };

    my $additional_args = {
        file_type => 'metabolomics',
        user_name => $user_name,
        file_id => $archived_file_id,
        metadata_file_id => $archived_metadata_file_id,
        upload_params => $upload_params
    };

    if ($mode eq 'verify') {
        $additional_args->{is_validation} = 1;
        $additional_args->{ignore_warnings} = $ignore_warnings;
        # The upload manager reads these back off a validation job to build the request that stores
        # the file once someone has looked at the validation.
        $additional_args->{protocol_params} = {
            upload_metabolomics_spreadsheet_protocol_id => $protocol_id,
            upload_metabolomics_spreadsheet_protocol_name => $protocol_name,
            upload_metabolomics_spreadsheet_protocol_desc => $protocol_desc,
            upload_metabolomics_spreadsheet_protocol_equipment_type => $protocol_equipment_type,
            upload_metabolomics_spreadsheet_protocol_target => $protocol_target,
            upload_metabolomics_spreadsheet_protocol_sample_collection_protocol => $protocol_sample_collection,
            upload_metabolomics_spreadsheet_protocol_sample_extraction_protocol => $protocol_sample_extraction,
            upload_metabolomics_spreadsheet_protocol_rawdata_transformation_protocol => $protocol_rawdata_transformation,
            upload_metabolomics_spreadsheet_protocol_metabolite_identification_protocol => $protocol_metabolite_identification,
            upload_metabolomics_spreadsheet_protocol_equipment_description => $protocol_equipment_desc,
            upload_metabolomics_spreadsheet_protocol_data_process_description => $protocol_data_process_desc,
            upload_metabolomics_spreadsheet_protocol_phenotype_type => $protocol_phenotype_type,
            upload_metabolomics_spreadsheet_protocol_phenotype_units => $protocol_phenotype_units,
            upload_metabolomics_spreadsheet_protocol_chromatography_system_brand => $protocol_chromatography_system_brand,
            upload_metabolomics_spreadsheet_protocol_chromatography_column_brand => $protocol_chromatography_column_brand,
            upload_metabolomics_spreadsheet_protocol_chromatography_type => $protocol_chromatography_type,
            upload_metabolomics_spreadsheet_protocol_chromatography_AutoSampler_Model => $protocol_chromatography_autosampler_model,
            upload_metabolomics_spreadsheet_protocol_chromatography_column_type => $protocol_chromatography_column_type,
            upload_metabolomics_spreadsheet_protocol_chromatography_protocol => $protocol_chromatography_protocol,
            upload_metabolomics_spreadsheet_protocol_mass_spectrometry_protocol => $protocol_mass_spectrometry_protocol,
            upload_metabolomics_spreadsheet_protocol_ms_brand => $protocol_ms_brand,
            upload_metabolomics_spreadsheet_protocol_ms_mass_analyzer => $protocol_ms_type,
            upload_metabolomics_spreadsheet_protocol_ms_scan_polarity => $protocol_ms_instrument_type,
            upload_metabolomics_spreadsheet_protocol_ms_ion_source => $protocol_ms_ion_mode,
            upload_metabolomics_spreadsheet_protocol_ms_scan_MZ_Range => $protocol_ms_scan_mz_range,
            upload_metabolomics_spreadsheet_protocol_publication => $protocol_publication,
            upload_metabolomics_spreadsheet_data_level => $data_level
        };
    } else {
        $additional_args->{final_upload} = 1;
    }

    my $job_name = basename($archived_filename_with_path).($mode eq 'verify' ? " metabolomics validation" : " metabolomics upload");

    _submit_high_dim_upload($c, {
        script => 'upload_metabolomics_phenotypes.pl',
        mode => $mode,
        entity => 'metabolomics',
        schema => $schema,
        people_schema => $people_schema,
        user_id => $user_id,
        job_name => $job_name,
        additional_args => $additional_args,
        from_upload_manager => $from_upload_manager,
        success_status => \@success_status,
        error_status => \@error_status
    });
}

=head2 _archive_high_dim_file($c, $args)

Archives one of the files an upload came with, or looks up one that the upload manager archived
already, and returns where it is on disk, the name to call it in messages, and its archived file id.

=cut

sub _archive_high_dim_file {
    my $c = shift;
    my $args = shift;

    my $archived_file_id = $args->{archived_file_id};

    if ($archived_file_id) {
        my $archived_file = CXGN::File->new({
            file_id => $archived_file_id,
            metadata_schema => $args->{metadata_schema},
            archive_path => $c->config->{archive_path}
        });
        my $archived_filename_with_path = $archived_file->get_path();

        return ($archived_filename_with_path, basename($archived_filename_with_path), $archived_file_id);
    }

    my $upload = $c->req->upload($args->{upload_field});
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $args->{subdirectory},
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $args->{timestamp},
        user_id => $args->{user_id},
        user_role => $args->{user_role},
        file_type => $args->{file_type},
        metadata_schema => $args->{metadata_schema}
    });
    my ($file_id, $archived_filename_with_path) = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        push @{$args->{error_status}}, "Could not save file $upload_original_name in archive.";
        $c->stash->{rest} = {success => $args->{success_status}, error => $args->{error_status} };
        $c->detach();
    } else {
        push @{$args->{success_status}}, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    return ($archived_filename_with_path, $upload_original_name, $file_id);
}

=head2 _submit_high_dim_upload($c, $args)

Submits the background script that reads a high dimensional phenotype file, and answers the request
with what it had to say. An upload that the upload manager is following is answered as soon as the
job has been submitted; one posted from an upload dialog is waited on.

=cut

sub _submit_high_dim_upload {
    my $c = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $people_schema = $args->{people_schema};

    my $dbhost = $c->config->{dbhost};
    my $dbname = $c->config->{dbname};
    my $dbuser = $c->config->{dbuser};
    my $dbpass = $c->config->{dbpass};
    my $basepath = $c->config->{basepath};
    my $archive_path = $c->config->{archive_path};
    my $tempfiles_subdir = $c->config->{tempfiles_subdir};

    # __SP_JOB_ID__ is filled in by CXGN::Job when the job is submitted, so that the script can
    # report its messages back to this job, and can read the upload it is to run off it.
    my $cmd = "perl \"$basepath/bin/".$args->{script}."\" -H \"$dbhost\" -D \"$dbname\" -U \"$dbuser\" -P \"$dbpass\" -w \"$basepath\" -ap \"$archive_path\" -tf \"$tempfiles_subdir\" -m \"".$args->{mode}."\" -j __SP_JOB_ID__";

    my $upload_job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $args->{user_id},
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
        basepath => $basepath,
        cmd => $cmd,
        name => $args->{job_name},
        job_type => 'upload',
        submit_page => ($c->req->referer ? $c->req->referer->as_string : undef),
        additional_args => $args->{additional_args}
    });

    my $submit_error;
    try {
        $upload_job->submit();
    } catch {
        $submit_error = $_;
    };
    if ($submit_error) {
        push @{$args->{error_status}}, "Could not submit the ".$args->{entity}." upload: $submit_error";
        $c->stash->{rest} = {success => $args->{success_status}, error => $args->{error_status} };
        $c->detach();
    }

    if ($args->{from_upload_manager}) {
        $c->stash->{rest} = {success => $args->{success_status}, error => $args->{error_status}, job_id => $upload_job->sp_job_id() };
        $c->detach();
    }

    $upload_job->wait();

    # The script reports its results by writing them to the job, so they have to be read back from
    # the database rather than from the object that submitted it. The answer the dialog gets is
    # recorded whole, so that a file that was waited on reads exactly the same as it used to.
    my $finished_job = CXGN::Job->new({
        sp_job_id => $upload_job->sp_job_id(),
        schema => $schema,
        people_schema => $people_schema
    });
    my $job_args = $finished_job->additional_args() || {};

    if (!$job_args->{result}) {
        # The job left the queue without recording an outcome, which happens if the script died
        # before it could report anything.
        push @{$args->{error_status}}, "The ".$args->{entity}." upload did not report a result. Check the status of upload job ".$upload_job->sp_job_id().".";
        $c->stash->{rest} = {success => $args->{success_status}, error => $args->{error_status} };
        $c->detach();
    }

    $c->stash->{rest} = $job_args->{result};
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
                my $header_string = 'gene_id,chromosome,pos_left,pos_right,functional_annotation,notes';
                print $F $header_string."\n";

                foreach (@identifier_names_sorted) {
                    my $chromosome = $identifier_metadata->{$_}->{chr};
                    my $pos_left = $identifier_metadata->{$_}->{start};
                    my $pos_right = $identifier_metadata->{$_}->{end};
                    my $functional_annotation = $identifier_metadata->{$_}->{gene_desc};
                    my $notes = $identifier_metadata->{$_}->{notes};
                    print $F "$_,$chromosome,$pos_left,$pos_right,$functional_annotation,$notes\n";
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
