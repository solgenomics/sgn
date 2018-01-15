package CXGN::BrAPI::v1::Studies;

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

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@sorted_years, $page_size, $page);
	foreach (@$data_window){
		my ($year, $season) = split '\|', $_->[0];
		push @data, {
			seasonsDbId=>$_->[1],
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
		push @data, {
			studyTypeDbId=>$_->[0],
			name=>$_->[1],
			description=>$_->[2],
		};
	}
	my %result = (data=>\@data);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'StudyTypes list result constructed');
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
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($data, $page_size, $page);
	#print STDERR Dumper $data_window;

	my @data_out;
	foreach (@$data_window){
		my %additional_info = (
			design => $_->{design},
			description => $_->{description},
		);
		my %data_obj = (
			studyDbId => $_->{trial_id},
			studyName => $_->{trial_name},
			trialDbId => $_->{folder_id},
			trialName => $_->{folder_name},
			studyType => $_->{trial_type},
			seasons => [$_->{year}],
			locationDbId => $_->{location_id},
			locationName => $_->{location_name},
			programDbId => $_->{breeding_program_id},
			programName => $_->{breeding_program_name},
			startDate => $_->{project_harvest_date},
			endDate => $_->{project_planting_date},
			active=>'',
			additionalInfo=>\%additional_info
		);
		push @data_out, \%data_obj;
	}

	my %result = (data=>\@data_out);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies-search result constructed');
}

sub studies_germplasm {
	my $self = shift;
	my $study_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $schema = $self->bcs_schema;

	my $total_count = 0;

	my $tl = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $study_id });
	my $accessions = $tl->get_accessions();
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($accessions, $page_size, $page);
	my @germplasm_data;

	foreach (@$data_window){
		my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$_->{stock_id}});
		push @germplasm_data, {
			germplasmDbId=>$_->{stock_id},
			germplasmName=>$_->{accession_name},
			entryNumber=>$stock_object->entryNumber,
			accessionNumber=>$stock_object->accessionNumber,
			germplasmPUI=>$stock_object->germplasmPUI,
			pedigree=>$stock_object->get_pedigree_string,
			seedSource=>$stock_object->germplasmSeedSource,
			synonyms=>$stock_object->synonyms,
		};
	}

	my %result = (
		studyDbId=>$study_id,
		studyName=>$tl->get_name,
		data =>\@germplasm_data
	);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies-germplasm result constructed');
}

sub studies_detail {
	my $self = shift;
	my $study_id = shift;
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

			my @years = ($t->get_year());
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
			my $planting_date = '';
			if ($t->get_planting_date()) {
				$planting_date = $t->get_planting_date();
				my $t = Time::Piece->strptime($planting_date, "%Y-%B-%d");
				$planting_date = $t->strftime("%Y-%m-%d");
			}
			my $harvest_date = '';
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
					email => $_->{email},
					type => $_->{user_type},
					orcid =>$_->{phone_number}
				};
			}
			my $location = CXGN::Trial::get_all_locations($self->bcs_schema, $location_id)->[0];
			%result = (
				studyDbId=>$t->get_trial_id(),
				studyName=>$t->get_name(),
				trialDbId=>$folder->project_parent->project_id(),
				trialName=>$folder->project_parent->name(),
				studyType=>$project_type,
				seasons=>\@years,
				locationDbId=>$location_id,
				locationName=>$location_name,
				programDbId=>$folder->breeding_program->project_id(),
				programName=>$folder->breeding_program->name(),
				startDate => $planting_date,
				endDate => $harvest_date,
				additionalInfo=>\%additional_info,
				active=>'',
				location=> {
					locationDbId => $location->[0],
					locationType=>$location->[8],
					name=> $location->[1],
					abbreviation=>$location->[9],
					countryCode=> $location->[6],
					countryName=> $location->[5],
					latitude=>$location->[2],
					longitude=>$location->[3],
					altitude=>$location->[4],
					additionalInfo=> $location->[7]
				},
				contacts=>$brapi_contacts
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

sub studies_observation_variables {
	my $self = shift;
	my $study_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $total_count = 0;
	my %result;
	$result{studyDbId} = $study_id;
	my @data;

	my $study_check = $self->bcs_schema->resultset('Project::Project')->find({project_id=>$study_id});
	if ($study_check) {
		my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $study_id });
		my $traits_assayed = $t->get_traits_assayed();
		my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($traits_assayed, $page_size, $page);

		foreach (@$data_window){
			my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$_->[0]});
			my $categories = $trait->categories;
			my @brapi_categories = split '/', $categories;
			push @data, {
				observationVariableDbId => $trait->cvterm_id,
				name => $trait->display_name,
				ontologyDbId => $trait->db_id,
				ontologyName => $trait->db,
				trait => {
					traitDbId => $trait->cvterm_id,
					name => $trait->name,
					description => $trait->definition,
				},
				method => {},
				scale => {
					scaleDbId =>'',
					name =>'',
					datatype=>$trait->format,
					decimalPlaces=>'',
					xref=>'',
					validValues=> {
						min=>$trait->minimum,
						max=>$trait->maximum,
						categories=>\@brapi_categories
					}
				},
				xref => $trait->term,
				defaultValue => $trait->default_value
			};
		}
		$result{data} = \@data;
		my @data_files;
		return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies observation variables result constructed');
	} else {
		return CXGN::BrAPI::JSONResponse->return_error($status, 'StudyDbId not found');
	}
}

sub studies_layout {
	my $self = shift;
	my $inputs = shift;
    my $study_id = $inputs->{study_id};
    my $format = $inputs->{format} || 'json';
	my $file_path = $inputs->{file_path};
	my $file_uri = $inputs->{file_uri};
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $tl = CXGN::Trial::TrialLayout->new({ schema => $self->bcs_schema, trial_id => $study_id });
	my $design = $tl->get_design();

	my $plot_data = [];
	my $formatted_plot = {};
	my %additional_info;
	my $check_id;
	my $type;
	my $count = 0;
	my $offset = $page*$page_size;
	my $limit = $page_size*($page+1)-1;
	foreach my $plot_number (sort keys %$design) {
		if ($count >= $offset && $count <= ($offset+$limit)){
			$check_id = $design->{$plot_number}->{is_a_control} ? 1 : 0;
			if ($check_id == 1) {
				$type = 'Check';
			} else {
				$type = 'Test';
			}
			if ($design->{$plot_number}->{plant_names}){
				$additional_info{plantNames} = $design->{$plot_number}->{plant_names};
			}
			if ($design->{$plot_number}->{plant_ids}){
				$additional_info{plantDbIds} = $design->{$plot_number}->{plant_ids};
			}
			$formatted_plot = {
				studyDbId => $study_id,
				observationUnitDbId => $design->{$plot_number}->{plot_id},
				observationUnitName => $design->{$plot_number}->{plot_name},
				observationLevel => 'plot',
				replicate => $design->{$plot_number}->{replicate} ? $design->{$plot_number}->{replicate} : '',
				blockNumber => $design->{$plot_number}->{block_number} ? $design->{$plot_number}->{block_number} : '',
				X => $design->{$plot_number}->{row_number} ? $design->{$plot_number}->{row_number} : '',
				Y => $design->{$plot_number}->{col_number} ? $design->{$plot_number}->{col_number} : '',
				entryType => $type,
				germplasmName => $design->{$plot_number}->{accession_name},
				germplasmDbId => $design->{$plot_number}->{accession_id},
				additionalInfo => \%additional_info
			};
			push @$plot_data, $formatted_plot;
		}
		$count++;
	}
	my %result;
    my @data_files;
    if ($format eq 'json'){
        %result = (data=>$plot_data);
    } elsif ($format eq 'tsv' || $format eq 'csv' || $format eq 'xls') {
       # if xls or csv or tsv, create tempfile name and place to save it

       my @header_row = ('studyDbId', 'observationUnitDbId', 'observationUnitName', 'observationLevel', 'replicate', 'blockNumber', 'X', 'Y', 'entryType', 'germplasmName', 'germplasmDbId');
       my @data_out;
       push @data_out, \@header_row;
       foreach (@$plot_data){
           my @row = ($_->{studyDbId}, $_->{observationUnitDbId}, $_->{observationUnitName}, $_->{observationLevel}, $_->{replicate}, $_->{blockNumber}, $_->{X}, $_->{Y}, $_->{entryType}, $_->{germplasmName}, $_->{germplasmDbId});
           push @data_out, \@row;
       }

       my $file_response = CXGN::BrAPI::FileResponse->new({
           absolute_file_path => $file_path,
           absolute_file_uri => $inputs->{main_production_site_url}.$file_uri,
           format => $format,
           data => \@data_out
       });
       @data_files = $file_response->get_datafiles();

    }
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies layout result constructed');
}


sub observation_units {
	my $self = shift;
	my $inputs = shift;
	my $study_id = $inputs->{study_id};
	my $data_level = $inputs->{data_level} || 'plot';
	my @trait_ids_array = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $study_id });
	my $phenotype_data;
	if ($data_level eq 'all') {
		$phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'all', ['plot_of','plant_of'], 'accession', 'subject');
	} elsif ($data_level eq 'plot') {
		$phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'plot', ['plot_of'], 'accession', 'subject');
	} elsif ($data_level eq 'plant') {
		$phenotype_data = $t->get_stock_phenotypes_for_traits(\@trait_ids_array, 'plant', ['plant_of'], 'accession', 'subject');
	}
	#print STDERR Dumper $phenotype_data;

	my %unique_observation_units;
	my %obs_unit_hash;
	foreach (@$phenotype_data){
		$unique_observation_units{$_->[1]}++;
		$obs_unit_hash{$_->[1]} = $_;
	}

	my %obs_hash;
	my $total_count = scalar(keys %unique_observation_units);
	my $count = 0;
	my $offset = $page*$page_size;
	my $limit = $page_size*($page+1)-1;
	foreach my $obs_unit_id (sort keys %unique_observation_units) {
		if ($count >= $offset && $count <= ($offset+$limit)){
			my $o = $obs_unit_hash{$obs_unit_id};
			my $pheno_uniquename = $o->[5];
			my ($part1 , $part2) = split( /date: /, $pheno_uniquename);
			my ($timestamp , $operator) = split( /\ \ operator = /, $part2);

			if(exists($obs_hash{$o->[0]})){
				my $observations = $obs_hash{$o->[0]}->{observations};
				push @$observations, {
					observationDbId => $o->[4],
					observationVariableDbId => $o->[2],
					observationVariableName => $o->[3],
					collector => $operator,
					observationTimeStamp => $timestamp,
					value => $o->[7]
				};
				 $obs_hash{$o->[0]}->{observations} = $observations;
			} else {
				my $prop_hash = $self->get_stockprop_hash($o->[0]);
				$obs_hash{$o->[0]} = {
					observationUnitDbId => $o->[0],
					observationUnitName => $o->[1],
					germplasmDbId => $o->[8],
					germplasmName => $o->[9],
					pedigree => $self->germplasm_pedigree_string($o->[8]),
					entryNumber => $prop_hash->{'entry number'} ? join ',', @{$prop_hash->{'entry number'}} : '',
					entryType => $prop_hash->{'is a control'} ? 'Check' : 'Test',
					plotNumber => $prop_hash->{'plot number'} ? join ',', @{$prop_hash->{'plot number'}} : '',
					plantNumber => '',
					blockNumber => $prop_hash->{'block'} ? join ',', @{$prop_hash->{'block'}} : '',,
					X => $prop_hash->{'row_number'} ? join ',', @{$prop_hash->{'row_number'}} : '',
					Y=> $prop_hash->{'col_number'} ? join ',', @{$prop_hash->{'col_number'}} : '',
					replicate=> $prop_hash->{'replicate'} ? join ',', @{$prop_hash->{'replicate'}} : '',
					observations => [{
						observationDbId => $o->[4],
						observationVariableDbId => $o->[2],
						observationVariableName => $o->[3],
						collector => $operator,
						observationTimeStamp => $timestamp,
						value => $o->[7]
					}],
				}
			}
		}
		$count++;
	}

	my @data_out;
	foreach (sort keys %obs_hash){
		push @data_out, $obs_hash{$_};
	}

	my %result = (data=>\@data_out);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies observations result constructed');
}

sub studies_table {
	my $self = shift;
	my $inputs = shift;
	my $study_id = $inputs->{study_id};
	my $data_level = $inputs->{data_level} || 'plot';
	my $search_type = $inputs->{search_type} || 'complete';
	my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
	my $format = $inputs->{format} || 'json';
	my $file_path = $inputs->{file_path};
	my $file_uri = $inputs->{file_uri};
	my @trait_ids_array = $inputs->{trait_ids} ? @{$inputs->{trait_ids}} : ();
	my @trial_ids_array = $inputs->{trial_ids} ? @{$inputs->{trial_ids}} : ();
	push @trial_ids_array, $study_id;
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
		search_type=>$factory_type,
		bcs_schema=>$self->bcs_schema,
		data_level=>$data_level,
		trial_list=>\@trial_ids_array,
		trait_list=>\@trait_ids_array,
		include_timestamp=>1,
        exclude_phenotype_outlier=>$exclude_phenotype_outlier
	);
	my @data = $phenotypes_search->get_phenotype_matrix();
	#print STDERR Dumper \@data;

	my %result;
	my @data_files;
	my $total_count = 0;
	if ($format eq 'json') {
		$total_count = scalar(@data)-1;
		my @header_names = @{$data[0]};
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
			studyDbId => $study_id,
			headerRow => ['studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber'],
			observationVariableDbIds => \@header_ids,
			observationVariableNames => \@trait_names,
			data=>\@data_window
		);

	} elsif ($format eq 'tsv' || $format eq 'csv' || $format eq 'xls') {
		# if xls or csv or tsv, create tempfile name and place to save it

		my $file_response = CXGN::BrAPI::FileResponse->new({
			absolute_file_path => $file_path,
			absolute_file_uri => $inputs->{main_production_site_url}.$file_uri,
			format => $format,
			data => \@data
		});
		@data_files = $file_response->get_datafiles();

	}
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies observations table result constructed');
}

sub observation_units_granular {
	my $self = shift;
	my $inputs = shift;
	my $study_id = $inputs->{study_id};
	my $data_level = $inputs->{data_level} || 'plot';
	my $search_type = $inputs->{search_type} || 'complete';
    my $exclude_phenotype_outlier = $inputs->{exclude_phenotype_outlier} || 0;
	my @trait_ids_array = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();
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
			trial_list=>[$study_id],
			trait_list=>\@trait_ids_array,
			include_timestamp=>1,
            exclude_phenotype_outlier=>$exclude_phenotype_outlier
		}
	);
	my $data = $phenotypes_search->search();
	#print STDERR Dumper $data;
	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array($data, $page_size, $page);
	my @data_out;
	foreach (@$data_window){
		push @data_out, {
			studyDbId => $_->[11],
			observationDbId => $_->[19],
			observationUnitDbId => $_->[14],
			observationUnitName => $_->[6],
			observationLevel => $_->[18],
			observationVariableDbId => $_->[10],
			observationVariableName => $_->[4],
			observationTimestamp => $_->[15],
			uploadedBy => '',
			operator => '',
			germplasmDbId => $_->[13],
			germplasmName => $_->[2],
			value => $_->[5],
		};
	}
	my %result = (data=>\@data_out);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Studies observations granular result constructed');
}


sub germplasm_pedigree_string {
	my $self = shift;
	my $stock_id = shift;
	my $s = CXGN::Stock->new( schema => $self->bcs_schema, stock_id => $stock_id);
	my $pedigree_string = $s->get_pedigree_string('Parents');
	return $pedigree_string;
}

sub get_stockprop_hash {
	my $self = shift;
	my $stock_id = shift;
	my $prop_rs = $self->bcs_schema->resultset('Stock::Stockprop')->search({'me.stock_id' => $stock_id}, {join=>['type'], +select=>['type.name', 'me.value'], +as=>['name', 'value']});
	my $prop_hash;
	while (my $r = $prop_rs->next()){
		push @{ $prop_hash->{$r->get_column('name')} }, $r->get_column('value');
	}
	#print STDERR Dumper $prop_hash;
	return $prop_hash;
}

1;
