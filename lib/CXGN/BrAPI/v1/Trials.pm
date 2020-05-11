package CXGN::BrAPI::v1::Trials;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial::Folder;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v1::Common';

sub search {
	my $self = shift;
	my $search_params = shift;
	my $schema = $self->bcs_schema;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $data;
    my $status = $self->status();
    #my $auth = _authenticate_user($c);

    my @location_dbids = $search_params->{locationDbIds} ? @{$search_params->{locationDbIds}} : ();
    my @program_dbids = $search_params->{programDbIds} ? @{$search_params->{programDbIds}} : ();

    my %location_id_list;
    if (scalar(@location_dbids)>0){
        %location_id_list = map { $_ => 1} @location_dbids;
    }

    my %program_id_list;
    if (scalar(@program_dbids)>0){
        %program_id_list = map { $_ => 1} @program_dbids;
    }

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $schema  } );
    my $programs = $p->get_breeding_programs();

    foreach my $program (@$programs) {
        unless (%program_id_list && !exists($program_id_list{$program->[0]})) { # for each program not excluded, retrieve folders and studies
            $program = { "id" => $program->[0], "name" => $program->[1], "program_id" => $program->[0], "program_name" => $program->[1] };
            $data = _get_folders($program, $schema, $data, \%location_id_list, 'breeding_program');
        }
    }
    my $total_count = scalar @{$data};
    my %result = (data => $data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$self->page_size,$self->page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $self->status, 'Trials-search result constructed');
}

sub details {
	my $self = shift;
	my $folder_id = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $schema = $self->bcs_schema;
	my $trial_check = $schema->resultset('Project::Project')->find({project_id=>$folder_id});
	if ($trial_check){
		my $folder = CXGN::Trial::Folder->new(bcs_schema=>$self->bcs_schema(), folder_id=>$folder_id);
		if ($folder->is_folder) {
			my $total_count = 1;
			my @folder_studies;
			my %additional_info;
			my $children = $folder->children();
			foreach (@$children) {
				push @folder_studies, {
					studyDbId=>$_->folder_id,
					studyName=>$_->name,
					locationDbId=>$_->location_id,
                    locationName=>$_->location_name
				};
			}
            my $folder_id = $folder->folder_id;
            my $breeding_program_id = $folder->breeding_program->project_id();
			my %result = (
				trialDbId=>qq|$folder_id|,
				trialName=>$folder->name,
				programDbId=>qq|$breeding_program_id|,
				programName=>$folder->breeding_program->name(),
				startDate=>'',
				endDate=>'',
				active=>undef,
				studies=>\@folder_studies,
				additionalInfo=>\%additional_info,
                commonCropName=>undef,
                documentationURL=>undef
			);
			my @data_files;
			my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
			return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Trial detail result constructed');
		} else {
			return CXGN::BrAPI::JSONResponse->return_error($status, 'The given trialDbId does not match an actual trial.');
		}
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'The given trialDbId not found.');
	}
}

sub _get_folders {
	my $self = shift;
    my $schema = shift;
    my $data = shift;
    my $location_id_list = shift;
    my $parent_type = shift;
    my %location_id_list = %{$location_id_list};
    my %additional_info;
    my @folder_studies;

	my $studies = _get_studies($self, $schema, $parent_type);
    my %studies = %{$studies};
	if (%studies) {
        foreach my $study (sort keys %studies) {

			if ($studies{$study}->{'folder_for_trials'}) { # it's a folder, recurse a layer deeper
                $data = _get_folders($studies{$study}, $schema, $data, \%location_id_list, 'folder');
            }
            elsif (!$studies{$study}->{'folder_for_crosses'} && !$studies{$study}->{'folder_for_trials'} && $studies{$study}->{'trial_folder'}) { # it's a folder, recurse a layer deeper
                $data = _get_folders($studies{$study}, $schema, $data, \%location_id_list, 'folder');
            }
            elsif ($studies{$study}->{'design'}) { # it's a study, add it to studies array

                my $passes_search = 1;
                if (%location_id_list) {
                	if (!exists($location_id_list{ $studies{$study}->{'project location'}}) ) {
                		$passes_search = 0;
                	}
                }
        		if ($passes_search){
                    my $location_name = '';
                    my $location = $schema->resultset("NaturalDiversity::NdGeolocation")->find({nd_geolocation_id=>$studies{$study}->{'project location'}});
                    if ($location){
                        $location_name = $location->description;
                    }
        			push @folder_studies, {
        				studyDbId=>qq|$studies{$study}->{'id'}|,
        				studyName=>$studies{$study}->{'name'},
        				#locationDbId=>$studies{$study}->{'project location'},
                        locationName=>$location_name
        			};
        		}
			}
		}
	}

    unless (%location_id_list && scalar @folder_studies < 1) { #skip empty folders if call was issued with search paramaters
        push @{$data}, {
    					trialDbId=>qq|$self->{'id'}|,
    					trialName=>$self->{'name'},
    					programDbId=>qq|$self->{'program_id'}|,
    					programName=>$self->{'program_name'},
    					startDate=>'',
    					endDate=>'',
    					active=>undef,
    					studies=>\@folder_studies,
    					additionalInfo=>\%additional_info
    				};
    }

	return $data;

}

sub _get_studies {

    my $self = shift;
    my $schema = shift;
    my $parent_type = shift;
    my (@folder_contents, %studies);

    if ($parent_type eq 'breeding_program') {
        my $rs = $schema->resultset("Project::Project")->search_related(
            'project_relationship_subject_projects',
            {   'type.name' => 'trial_folder'
            },
            {   join => 'type'
            });
        @folder_contents = map { $_->subject_project_id() } $rs->all();
    }

    my $rs = $schema->resultset("Project::Project")->search_related(
        'project_relationship_subject_projects',
        {   object_project_id => $self->{'id'},
            subject_project_id => { 'not in' => \@folder_contents }
        },
        {   join      => { subject_project => { projectprops => 'type' } },
            '+select' => ['subject_project.name', 'projectprops.value', 'type.name'],
            '+as'     => ['project_name', 'project_value', 'project_type']
        }
     );

    while (my $row = $rs->next) {
        my $name = $row->get_column('project_name');
        $studies{$name}{'name'} = $name;
        $studies{$name}{'id'} = $row->subject_project_id();
        $studies{$name}{'program_name'} = $self->{'program_name'};
        $studies{$name}{'program_id'} = $self->{'program_id'};
        $studies{$name}{$row->get_column('project_type')} = $row->get_column('project_value');
    }

    return \%studies
}

1;
