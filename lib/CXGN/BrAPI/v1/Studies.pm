package CXGN::BrAPI::v1::Studies;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;

has 'bcs_schema' => (
	isa => 'Bio::Chado::Schema',
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

sub seasons {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my @data;
    my $total_count = 0;
    my $year_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema,'project year', 'project_property')->cvterm_id();
    my $project_years_rs = $self->bcs_schema()->resultset("Project::Project")->search_related('projectprops', {'projectprops.type_id'=>$year_cvterm_id});
	my %unique_years;
    while (my $p_year = $project_years_rs->next()) {
		$unique_years{$p_year->value} = $p_year->projectprop_id;
    }
	my @sorted_years;
	foreach (sort keys %unique_years){
		push @sorted_years, [$_, $unique_years{$_}];
	}

	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($sorted_years[$i]) {
			push @data, {
	            seasonsDbId=>$sorted_years[$i]->[1],
	            season=>'',
	            year=>$sorted_years[$i]->[0]
	        };
		}
	}
    my %result = (data=>\@data);
    $total_count = scalar(@sorted_years);
	push @$status, { 'success' => 'Seasons result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub study_types {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;
	my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
    foreach (@project_type_ids){
        push @data, {
            studyTypeDbId=>$_->[0],
            name=>$_->[1],
            description=>$_->[2],
        }
    }
    my %result = (data=>\@data);
    my $total_count = scalar(@project_type_ids);
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

1;
