package CXGN::BrAPI::v1::Phenotypes;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use Try::Tiny;
use CXGN::Phenotypes::PhenotypeMatrix;

extends 'CXGN::BrAPI::v1::Common';

sub search_table_csv_or_tsv {
    my $self = shift;
    my $inputs = shift;
    my $format = $inputs->{format} || 'json';
       my $file_path = $inputs->{file_path};
       my $file_uri = $inputs->{file_uri};
    my $data_level = $inputs->{data_level} || 'all';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>'MaterializedViewTable',
        trial_list=>\@study_ids_array,
        trait_list=>\@trait_ids_array,
        include_timestamp=>1,
        year_list=>\@years_array,
        location_list=>\@location_ids_array,
        accession_list=>\@accession_ids_array,
        exclude_phenotype_outlier=>$exclude_phenotype_outlier
    );
    my @data;
    try {
        @data = $phenotypes_search->get_phenotype_matrix();
    }
    catch {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'An Error Occured During Phenotype Search CSV');
    }

    my %result;
    my $total_count = 0;

    my $file_response = CXGN::BrAPI::FileResponse->new({
        absolute_file_path => $file_path,
        absolute_file_uri => $inputs->{main_production_site_url}.$file_uri,
        format => $format,
        data => \@data
    });
    my @data_files = $file_response->get_datafiles();
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype-search csv result constructed');
}

1;
