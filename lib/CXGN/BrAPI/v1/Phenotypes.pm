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


sub search {
	my $self = shift;
	my $inputs = shift;
	my $data_level = $inputs->{data_level} || 'plot';
	my $search_type = $inputs->{search_type} || 'fast';
	my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
	my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
	my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
	my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
	my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
	my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $factory_type,    #can be either 'MaterializedView', or 'Native'
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$data_level,
            trial_list=>\@study_ids_array,
            trait_list=>\@trait_ids_array,
            include_timestamp=>1,
            year_list=>\@years_array,
            location_list=>\@location_ids_array,
            accession_list=>\@accession_ids_array,
            include_row_and_column_numbers=>1,
            exclude_phenotype_outlier=>$exclude_phenotype_outlier
        }
    );
    my $data;
    try {
        $data = $phenotypes_search->search();
    }
    catch {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'An Error Occured During Phenotype Search');
    }
    #print STDERR Dumper $data;
	my @data_window;
	my %obs_units;
	foreach (@$data){
		if (exists($obs_units{$_->[16]})){
			my $observations = $obs_units{$_->[16]}->{observations};
			push @$observations, {
				observationDbId => $_->[21],
				observationVariableDbId => $_->[12],
				observationVariableName => $_->[4],
				observationTimestamp => $_->[17],
				season => $_->[0],
				collector => '',
				value => $_->[5],
			};
			$obs_units{$_->[16]}->{observations} = $observations;
		} else {
			$obs_units{$_->[16]} = {
				observationUnitDbId => qq|$_->[16]|,
				observationLevel => $_->[20],
				observationLevels => $_->[20],
				plotNumber => $_->[9],
				plantNumber => '',
				blockNumber => $_->[8],
				replicate => $_->[7],
				observationUnitName => $_->[6],
				germplasmDbId => qq|$_->[15]|,
				germplasmName => $_->[2],
				studyDbId => qq|$_->[13]|,
				studyName => $_->[1],
				studyLocationDbId => $_->[14],
				studyLocation => $_->[3],
				programName => '',
				X => $_->[10],
				Y => $_->[11],
				entryType => '',
				entryNumber => '',
				treatments => [],
				observations => [{
					observationDbId => qq|$_->[21]|,
					observationVariableDbId => qq|$_->[12]|,
					observationVariableName => $_->[4],
					observationTimeStamp => $_->[17],
					season => $_->[0],
					collector => '',
					value => $_->[5],
				}]
			};
		}
	}
	my $total_count = scalar(keys %obs_units);
	my $count = 0;
	my $window_count = 0;
	my $offset = $page*$page_size;
	foreach my $obs_unit_id (sort keys %obs_units) {
		if ($count >= $offset && $window_count < $page_size){
			push @data_window, $obs_units{$obs_unit_id};
            $window_count++;
		}
        $count++;
	}
	my %result = (data=>\@data_window);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype search result constructed');
}

sub search_table {
    my $self = shift;
    my $inputs = shift;
    my $data_level = $inputs->{data_level} || 'plot';
    my $search_type = $inputs->{search_type} || 'fast';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>$factory_type,
        trial_list=>\@study_ids_array,
        trait_list=>\@trait_ids_array,
        include_timestamp=>1,
        year_list=>\@years_array,
        location_list=>\@location_ids_array,
        accession_list=>\@accession_ids_array,
        include_row_and_column_numbers=>1,
        exclude_phenotype_outlier=>$exclude_phenotype_outlier
    );
    my @data;
    try {
        @data = $phenotypes_search->get_phenotype_matrix();
    }
    catch {
        return CXGN::BrAPI::JSONResponse->return_error($status, 'An Error Occured During Phenotype Search Table');
    }

    my %result;
    my @data_files;
    my $total_count = scalar(@data)-1;
    my @header_names = $data[0];
    #print STDERR Dumper \@header_names;
    my @trait_names = @header_names[15 .. $#header_names];
    #print STDERR Dumper \@trait_names;
    my @header_ids;
    foreach my $t (@trait_names) {
        push @header_ids, SGN::Model::Cvterm->get_cvterm_row_from_trait_name($self->bcs_schema, $t)->cvterm_id();
    }

    my $start = $page_size*$page;
    my $end = $page_size*($page+1)-1;
    my @data_window;
    for (my $line = $start; $line < $end; $line++) {
        if ($data[$line]) {
            my $columns = $data[$line];
            push @data_window, $columns;
        }
    }

    #print STDERR Dumper \@data_window;

    %result = (
        headerRow => ['studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber'],
        observationVariableDbIds => \@header_ids,
        observationVariableNames => \@trait_names,
        data=>\@data_window
    );

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Phenotype-search table result constructed');
}

sub search_table_csv_or_tsv {
    my $self = shift;
    my $inputs = shift;
    my $format = $inputs->{format} || 'json';
       my $file_path = $inputs->{file_path};
       my $file_uri = $inputs->{file_uri};
    my $data_level = $inputs->{data_level} || 'plot';
    my $search_type = $inputs->{search_type} || 'fast';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
    my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
    my @accession_ids_array = $inputs->{accession_ids} ? @{$inputs->{accession_ids}} : ();
    my @study_ids_array = $inputs->{study_ids} ? @{$inputs->{study_ids}} : ();
    my @location_ids_array = $inputs->{location_ids} ? @{$inputs->{location_ids}} : ();
    my @years_array = $inputs->{years} ? @{$inputs->{years}} : ();
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my $factory_type;
    if ($search_type eq 'complete'){
        $factory_type = 'Native';
    }
    if ($search_type eq 'fast'){
        $factory_type = 'MaterializedView';
    }
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$self->bcs_schema,
        data_level=>$data_level,
        search_type=>$factory_type,
        trial_list=>\@study_ids_array,
        trait_list=>\@trait_ids_array,
        include_timestamp=>1,
        year_list=>\@years_array,
        location_list=>\@location_ids_array,
        accession_list=>\@accession_ids_array,
        include_row_and_column_numbers=>1,
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
