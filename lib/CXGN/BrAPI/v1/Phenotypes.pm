package CXGN::BrAPI::v1::Phenotypes;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::Phenotypes::SearchFactory;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

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
	my $search_type = $inputs->{search_type} || 'complete';
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
            include_row_and_column_numbers=>1
        }
    );
    my $data = $phenotypes_search->search();
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
				observationUnitDbId => $_->[16],
				observationLevel => $_->[20],
				observationLevels => $_->[20],
				plotNumber => $_->[9],
				plantNumber => '',
				blockNumber => $_->[8],
				replicate => $_->[7],
				observationUnitName => $_->[6],
				germplasmDbId => $_->[15],
				germplasmName => $_->[2],
				studyDbId => $_->[13],
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
					observationDbId => $_->[21],
					observationVariableDbId => $_->[12],
					observationVariableName => $_->[4],
					observationTimestamp => $_->[17],
					season => $_->[0],
					collector => '',
					value => $_->[5],
				}]
			};
		}
	}
	my $total_count = scalar(keys %obs_units);
	my $count = 0;
	my $offset = $page*$page_size;
	my $limit = $page_size*($page+1)-1;
	foreach my $obs_unit_id (sort keys %obs_units) {
		if ($count >= $offset && $count <= ($offset+$limit)){
			push @data_window, $obs_units{$obs_unit_id};
		}
        $count++;
	}
	my %result = (data=>\@data_window);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies observations result constructed');
}

1;
