package CXGN::BrAPI::v2::Studies;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trial::Search;
use CXGN::Trial::TrialLayout;
use CXGN::Trait;
use CXGN::Stock;
use CXGN::Phenotypes::SearchFactory;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::FileResponse;
use CXGN::BrAPI::JSONResponse;
use JSON;

extends 'CXGN::BrAPI::v2::Common';

sub seasons {
    my $self = shift;
    my $year_filter = shift;
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
        my ($year, $season) = split '\|', $_;
        if ($year_filter){
            if ($year eq $year_filter){
                push @sorted_years, [$year, $season, $_];
            }
        } else {
            push @sorted_years, [$year, $season, $_];
        }
    }

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@sorted_years, $page_size, $page);
    foreach (@$data_window){
        my $year = $_->[0] ? $_->[0] : '';
        my $season = $_->[1] ? $_->[1] : '';
        my $projectprop_id = $_->[2] ? $_->[2] : '';
        push @data, {
            seasonDbId=>qq|$projectprop_id|,
            season=>$season,
            year=>$year
        };
    }
    my %result = (data=>\@data);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Seasons list result constructed');
}

sub study_types {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @data;
	my @data_files;
	my @project_type_ids = CXGN::Trial::get_all_project_types($self->bcs_schema());
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@project_type_ids, $page_size, $page);
	foreach (@$data_window){
		push @data, $_->[1];
	}
	my %result = (data=>\@data);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'StudyTypes list result constructed');
}

sub search {
    my $self = shift;
    my $search_params = shift;
	my $c = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema;
    my $page_obj = CXGN::Page->new();
    my $main_production_site_url = $page_obj->get_hostname();

    my @program_dbids = $search_params->{programDbIds} ? @{$search_params->{programDbIds}} : ();
 	my @program_names = $search_params->{programNames} ? @{$search_params->{programNames}} : ();
	my @study_dbids = $search_params->{studyDbIds} ? @{$search_params->{studyDbIds}} : ();
	my @study_names = $search_params->{studyNames} ? @{$search_params->{studyNames}} : ();
	my @folder_dbids = $search_params->{trialDbIds} ? @{$search_params->{trialDbIds}} : ();
	my @folder_names = $search_params->{trialNames} ? @{$search_params->{trialNames}} : ();
	my @location_ids = $search_params->{locationDbIds} ? @{$search_params->{locationDbIds}} : ();
	my @location_names = $search_params->{studyLocationNames} ? @{$search_params->{studyLocationNames}} : ();
	my @study_type_list = $search_params->{studyType} ? @{$search_params->{studyTypes}} : ();
	my @germplasm_dbids = $search_params->{germplasmDbIds} ? @{$search_params->{germplasmDbIds}} : ();
	my @germplasm_names = $search_params->{germplasmNames} ? @{$search_params->{germplasmNames}} : ();
	my @years = $search_params->{seasonDbIds} ? @{$search_params->{seasonDbIds}} : ();
	my @obs_variable_ids = $search_params->{observationVariableDbIds} ? @{$search_params->{observationVariableDbIds}} : ();
	my @study_puis = $search_params->{studyPUI} ? @{$search_params->{studyPUIs}} : ();
	my @externalReferenceID = $search_params->{externalReferenceID} ? @{$search_params->{externalReferenceIDs}} : ();
	my @externalReferenceSource = $search_params->{externalReferenceSource} ? @{$search_params->{externalReferenceSources}} : ();
    my $crop = $search_params->{commonCropNames};
    my $active = $search_params->{active};
    my $sortBy = $search_params->{sortBy};
    my $sortOrder = $search_params->{sortOrder};

    if (scalar(@study_puis)>0 || scalar(@externalReferenceID)>0  || scalar(@externalReferenceSource)>0 ){
        push @$status, { 'error' => 'The following search parameters are not implemented: studyPUI, externalReferenceID, externalReferenceSource' };
    }

    #$self->bcs_schema->storage->debug(1);
    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$schema,
        location_list=>\@location_names,
        location_id_list=>\@location_ids,
        trial_type_list=>\@study_type_list,
        # trial_type_ids=>\@study_type_ids,
        trial_id_list=>\@study_dbids,
        trial_name_list=>\@study_names,
        trial_name_is_exact=>1,
        program_list=>\@program_names,
        program_id_list=>\@program_dbids,
        folder_id_list => \@folder_dbids,
        folder_name_list => \@folder_names,
        trait_list => \@obs_variable_ids,
        accession_list => \@germplasm_dbids,
        accession_name_list => \@germplasm_names,
        limit => $page_size,
        offset => $page_size*$page,
        field_trials_only => 1
    });
    my ($data, $total_count) = $trial_search->search();
    #print STDERR Dumper $data;

	my $supported_crop = $c->config->{"supportedCrop"};

    my @data_out;
    foreach (@$data){

        my %additional_info = (
            programDbId => qq|$_->{breeding_program_id}|,
			programName => $_->{breeding_program_name},
        );
		my @seasons = ( $_->{"year"} );

		my $planting_date;
		if ($_->{project_planting_date}) {
			$planting_date = format_date($_->{project_planting_date});
		}
		my $harvest_date;
		if ($_->{project_harvest_date}) {
			$harvest_date = format_date($_->{project_harvest_date});
		}

		my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $_->{trial_id} });
		my $contacts = $t->get_trial_contacts();print Dumper $contacts;
		my $brapi_contacts;
		foreach (@$contacts){
			push @$brapi_contacts, {
				contactDbId => $_->{sp_person_id},
				name => $_->{salutation}." ".$_->{first_name}." ".$_->{last_name},
                instituteName => $_->{organization},
				email => $_->{email},
				type => $_->{user_type},
				orcid => ''
			};
		}
		my $additional_files = $t->get_additional_uploaded_files();
        my @data_links;
        foreach (@$additional_files){
            push @data_links, {
                scientificType => 'Additional File',
                name => $_->[4],
                url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                provenance => undef,
                dataFormat => undef,
                description => undef,
                fileFormat => undef,
                version => undef
            };
        }

        my $phenotype_files = $t->get_phenotype_metadata();
        foreach (@$additional_files){
            push @data_links, {
                scientificType => 'Uploaded Phenotype File',
                name => $_->[4],
                url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                provenance => undef,
                dataFormat => undef,
                description => undef,
                fileFormat => undef,
                version => undef
            };
        }
        my $data_agreement = $t->get_data_agreement() ? $t->get_data_agreement() : '';

        my %data_obj = (
			active=>JSON::true,
			additionalInfo=>\%additional_info,
			commonCropName => $supported_crop,
			contacts => $brapi_contacts,
			culturalnmPractices => undef,
			dataLinks => \@data_links,
			documentationURL => "",
			endDate => $harvest_date ? $harvest_date :  undef ,
			environmentParameters => undef,
			experimentalDesign => qq|$_->{design}|,
			externalReferences => undef,
			growthFacility => undef,
			lastUpdate => undef,
			license => $data_agreement,
			locationDbId => $_->{location_id},
			locationName => $_->{location_name},
			observationLevels => undef,
			observationUnitsDescription => undef,
			seasons => \@seasons,
			startDate => $planting_date ? $planting_date : undef,
			studyCode => qq|$_->{trial_id}|,
            studyDbId => qq|$_->{trial_id}|,
            studyDescription => $_->{description},
			studyName => $_->{trial_name},
			studyPUI => undef,
			studyType => $_->{trial_type},
            trialDbId => qq|$_->{folder_id}|,
            trialName => $_->{folder_name},
        );
        push @data_out, \%data_obj;
    }

    my %result = (data=>\@data_out);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies search result constructed');
}

sub detail {
	my $self = shift;
	my $study_id = shift;
    my $main_production_site_url = shift;
	my $supported_crop = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $total_count = 0;
	my %result;
	my $study_check = $self->bcs_schema->resultset('Project::Project')->find({project_id=>$study_id});
	if ($study_check) {
		my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $study_id });
		$total_count = 1;
		my $folder = CXGN::Trial::Folder->new( { folder_id => $study_id, bcs_schema => $self->bcs_schema } );
		if ($folder->folder_type eq 'trial') {

			my @season = ($t->get_year());

			my %additional_info = ();
			my $project_type = '';
			if ($t->get_project_type()) {
				$project_type = $t->get_project_type()->[1];
			}
			my $location_id = '';
			my $location_name = '';
			if ($t->get_location()) {
				$location_id = $t->get_location()->[0];
				$location_name = $t->get_location()->[1];
			}
			my $planting_date;
			if ($t->get_planting_date()) {
				$planting_date = $t->get_planting_date();
				my $t = Time::Piece->strptime($planting_date, "%Y-%B-%d");
				$planting_date = $t->strftime("%Y-%m-%d");
			}
			my $harvest_date;
			if ($t->get_harvest_date()) {
				$harvest_date = $t->get_harvest_date();
				my $t = Time::Piece->strptime($harvest_date, "%Y-%B-%d");
				$harvest_date = $t->strftime("%Y-%m-%d");
			}
			my $contacts = $t->get_trial_contacts();
			my $brapi_contacts;
			foreach (@$contacts){
				push @$brapi_contacts, {
					contactDbId => $_->{sp_person_id},
					name => $_->{salutation}." ".$_->{first_name}." ".$_->{last_name},
                    instituteName => $_->{organization},
					email => $_->{email},
					type => $_->{user_type},
					orcid => ''
				};
			}
			my $location = CXGN::Trial::get_all_locations($self->bcs_schema, $location_id)->[0];

            my $additional_files = $t->get_additional_uploaded_files();
            my @data_links;
            foreach (@$additional_files){
                push @data_links, {
                    scientificType => 'Additional File',
                    name => $_->[4],
                    url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                    provenance => undef,
                    dataFormat => undef,
                    description => undef,
                    fileFormat => undef,
                    version => undef
                };
            }

            my $phenotype_files = $t->get_phenotype_metadata();
            foreach (@$additional_files){
                push @data_links, {
                    scientificType => 'Uploaded Phenotype File',
                    name => $_->[4],
                    url => $main_production_site_url.'/breeders/phenotyping/download/'.$_->[0],
                    provenance => undef,
                    dataFormat => undef,
                    description => undef,
                    fileFormat => undef,
                    version => undef
                };
            }

            my $data_agreement = $t->get_data_agreement() ? $t->get_data_agreement() : '';
            my $study_db_id = $t->get_trial_id();
            my $folder_db_id = $folder->project_parent->project_id();
            my $breeding_program_id = $folder->breeding_program->project_id();
			%result = (
				active=>JSON::true,
				additionalInfo=>\%additional_info,
				commonCropName => $supported_crop,
				contacts => $brapi_contacts,
				culturalnmPractices => undef,
				dataLinks =>\@data_links,
				documentationURL => "",
				endDate => $harvest_date ? $harvest_date :  undef ,
				environmentParameters => undef,
				experimentalDesign => qq|$_->{design}|,
				externalReferences => undef,
				growthFacility => undef,
				lastUpdate => undef,
				license => $data_agreement,
				locationDbId => $_->{location_id},
				locationName => $_->{location_name},
				observationLevels => undef,
				observationUnitsDescription => undef,
				seasons => \@season,
				startDate => $planting_date ? $planting_date : undef,
				studyDbId=>qq|$study_db_id|,
				studyDescription=>$t->get_description(),
				studyName=>$t->get_name(),
				studyType=>$project_type,
				trialDbId=>qq|$folder_db_id|,
				trialName=>$folder->project_parent->name(),
				studyCode => qq|$study_db_id|,
				studyPUI => undef,
			);
		} else {
			return CXGN::BrAPI::JSONResponse->return_error($status, 'StudyDbId not a study');
		}
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'StudyDbId not found');
	}
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies detail result constructed');
}

sub format_date {

	my $str_date = shift;
	my $date;
	if ($str_date) {
		my  $formatted_time = Time::Piece->strptime($str_date, '%Y-%B-%d');
		$date =  $formatted_time->strftime("%Y-%m-%d");
	}

	return $date;
}

1;
