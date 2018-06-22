package CXGN::BrAPI::v1::Observations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::Search;
use CXGN::Stock;
use CXGN::Chado::Organism;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileRequest;
use utf8;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
);

has 'page_size' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'page' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'status' => (
    isa => 'ArrayRef[Maybe[HashRef]]',
    is => 'rw',
    required => 1,
);

sub observations_store {
    my $self = shift;
    my $search_params = shift;
    my $observations = $search_params->{observations} ? $search_params->{observations} : ();

    print STDERR "Observations type is  ". ref($observations) . "\n";
    print STDERR "Observations are ". Dumper($observations) . "\n";

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $user_id = $search_params->{user_id};
    my $user_type = $search_params->{user_type};
    my $archive_path = $search_params->{archive_path};

    print STDERR "OBSERVATIONS_MODULE: User id is $user_id and type is $user_type\n";

    # Use new CXGN::BrAPI::FileRequest module to create file from json and archive it

    my $archived_file = CXGN::BrAPI::FileRequest->new({
        user_id => $user_id,
        user_type => $user_type,
        archive_path => $archive_path,
        format => 'Fieldbook',  # use fieldbook database.csv format for observations data
        data => $observations
    });

    my $file = $archived_file->get_path();

    print STDERR "Archived File is in $file\n";

    my $total_count = 1;
    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations-search result constructed');


=comment
    # Parse file using CXGN::Phenotypes::ParseUpload

    $subdirectory = "brapi_phenotype_upload";
    $validate_type = "field book";
    $metadata_file_type = "brapi phenotype file";
    $timestamp_included = 1;
    # $upload = $c->req->upload('upload_fieldbook_phenotype_file_input');
    $data_level = $c->req->param('upload_fieldbook_phenotype_data_level') || 'plots';

    my $user_type = $user->get_object->get_user_type();
    if ($user_type ne 'submitter' && $user_type ne 'curator') {
        push @error_status, 'Must have submitter privileges to upload phenotypes! Please contact us!';
        return (\@success_status, \@error_status);
    }

    my $overwrite_values = $c->req->param('phenotype_upload_overwrite_values');
    if ($overwrite_values) {
        #print STDERR $user_type."\n";
        if ($user_type ne 'curator') {
            push @error_status, 'Must be a curator to overwrite values! Please contact us!';
            return (\@success_status, \@error_status);
        }
    }

    # my $upload_original_name = $upload->filename();
    # my $upload_tempfile = $upload->tempname;
    my %phenotype_metadata;
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
        return (\@success_status, \@error_status);
    } else {
        push @success_status, "File $upload_original_name saved in archive.";
    }
    unlink $upload_tempfile;

    my $validate_file = $parser->validate($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema);
    if (!$validate_file) {
        push @error_status, "Archived file not valid: $upload_original_name.";
        return (\@success_status, \@error_status);
    }
    if ($validate_file == 1){
        push @success_status, "File valid: $upload_original_name.";
    } else {
        if ($validate_file->{'error'}) {
            push @error_status, $validate_file->{'error'};
        }
        return (\@success_status, \@error_status);
    }

    ## Set metadata
    $phenotype_metadata{'archived_file'} = $archived_filename_with_path;
    $phenotype_metadata{'archived_file_type'} = $metadata_file_type;
    my $operator = $user->get_object()->get_username();
    $phenotype_metadata{'operator'} = $operator;
    $phenotype_metadata{'date'} = $timestamp;

    my $parsed_file = $parser->parse($validate_type, $archived_filename_with_path, $timestamp_included, $data_level, $schema);
    if (!$parsed_file) {
        push @error_status, "Error parsing file $upload_original_name.";
        return (\@success_status, \@error_status);
    }
    if ($parsed_file->{'error'}) {
        push @error_status, $parsed_file->{'error'};
    }
    my %parsed_data;
    my @plots;
    my @traits;
    if (scalar(@error_status) == 0) {
        if ($parsed_file && !$parsed_file->{'error'}) {
            %parsed_data = %{$parsed_file->{'data'}};
            @plots = @{$parsed_file->{'plots'}};
            @traits = @{$parsed_file->{'traits'}};
            push @success_status, "File data successfully parsed.";
        }
    }


    # - Store phenotypes using CXGN::Phenotypes::StorePhenotypes

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        bcs_schema=>$schema,
        metadata_schema=>$metadata_schema,
        phenome_schema=>$phenome_schema,
        user_id=>$user_id,
        stock_list=>$plots,
        trait_list=>$traits,
        values_hash=>$parsed_data,
        has_timestamps=>$timestamp_included,
        overwrite_values=>$overwrite,
        metadata_hash=>$phenotype_metadata,
        image_zipfile_path=>$image_zip
    );
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();

    if ($verified_error) {
    }
    if ($verified_warning) {
    }

    my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();

    if ($stored_phenotype_error) {
    }
    if ($stored_phenotype_success) {
    }

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
    my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});

    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations result constructed');
=cut
}

=comment
sub observations_search {
    my $self = shift;
    my $search_params = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my @collectors = $search_params->{collectors} ? @{$search_params->{collectors}} : ();
    my @observation_db_ids = $search_params->{observationDbIds} ? @{$search_params->{observationDbIds}} : ();
    my @observation_unit_db_ids = $search_params->{observationUnitDbIds} ? @{$search_params->{observationUnitDbIds}} : ();
    my @observation_variable_db_ids = $search_params->{observationVariableDbIds} ? @{$search_params->{observationVariableDbIds}} : ();

    #implement observation search here using stock search

    my @data;
    my %result = (data => \@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observations-search result constructed');
}
=cut

1;
