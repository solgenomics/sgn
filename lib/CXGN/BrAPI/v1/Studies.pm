package CXGN::BrAPI::v1::Studies;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::BrAPI::Pagination;

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
	push @$status, { 'success' => 'StudyTypes result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub studies_search {
	my $self = shift;
	my $search_params = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $schema = $self->bcs_schema;
    #my $auth = _authenticate_user($c);

    my @program_dbids = $search_params->{programDbIds} ? @{$search_params->{programDbIds}} : ();
    my @program_names = $search_params->{programNames} ? @{$search_params->{programNames}} : ();
    my @study_dbids = $search_params->{studyDbIds} ? @{$search_params->{studyDbIds}} : ();
    my @study_names = $search_params->{studyNames} ? @{$search_params->{studyNames}} : ();
    my @location_ids = $search_params->{studyLocationDbIds} ? @{$search_params->{studyLocationDbIds}} : ();
    my @location_names = $search_params->{studyLocationNames} ? @{$search_params->{studyLocationNames}} : ();
    my @study_type_list = $search_params->{studyTypeName} ? @{$search_params->{studyTypeName}} : ();
    #my @germplasm_dbids = @{$search_params->{germplasmDbIds}};
    #my @germplasm_names = @{$search_params->{germplasmNames}};
    #my @obs_variable_ids = @{$search_params->{observationVariableDbIds}};
    #my @obs_variable_names = @{$search_params->{observationVariableNames}};
    #my $sort_by = $c->req->param("sortBy");
    #my $sort_order = $c->req->param("sortOrder");

	#$self->bcs_schema->storage->debug(1);
    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_list=>\@location_names,
        location_id_list=>\@location_ids,
        trial_type_list=>\@study_type_list,
        trial_id_list=>\@study_dbids,
        trial_name_list=>\@study_names,
        trial_name_is_exact=>1,
        program_list=>\@program_names,
        program_id_list=>\@program_dbids,
    });
    my $data = $trial_search->search();
    my @data_window;
    my $start = $page_size*$page;
    my $end = $page_size*($page+1)-1;
    for( my $i = $start; $i <= $end; $i++ ) {
        if (@$data[$i]) {
            my %additional_info = (
                design => @$data[$i]->{design},
                description => @$data[$i]->{description},
            );
            my %data_obj = (
                studyDbId => @$data[$i]->{trial_id},
                studyName => @$data[$i]->{trial_name},
                trialDbId => @$data[$i]->{folder_id},
                trialName => @$data[$i]->{folder_name},
                studyType => @$data[$i]->{trial_type},
                seasons => [@$data[$i]->{year}],
                locationDbId => @$data[$i]->{location_id},
                locationName => @$data[$i]->{location_name},
                programDbId => @$data[$i]->{breeding_program_id},
                programName => @$data[$i]->{breeding_program_name},
                startDate => @$data[$i]->{harvest_date},
                endDate => @$data[$i]->{planting_date},
                active=>'',
                additionalInfo=>\%additional_info
            );
            push @data_window, \%data_obj;
        }
    }
    #print STDERR Dumper \@data_window;

    my %result = (data=>\@data_window);
    my $total_count = scalar(@$data);
	push @$status, { 'success' => 'Studies-search result constructed' };
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
