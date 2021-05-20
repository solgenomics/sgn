package CXGN::BrAPI::v2::Locations;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::BrAPI::v2::ExternalReferences;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
    my $params = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $abbreviations_arrayref = $params->{abbreviations} || ($params->{abbreviations} || ());
	my $altitude_max = $params->{altitudeMax}->[0] || undef;
	my $altitude_min = $params->{altitudeMin}->[0] || undef;
	my $coordinates = $params->{coordinates} || ($params->{coordinates} || ());
	my $country_codes_arrayref = $params->{countryCodes} || ($params->{countryCodes} || ());
	my $country_names_arrayref = $params->{countryNames} || ($params->{countryNames} || ());
	my $externalreference_ids_arrayref = $params->{externalReferenceID} || ($params->{externalReferenceIDs} || ());
	my $externalreference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());
	my $institute_addresses_arrayref = $params->{instituteAddresses} || ($params->{instituteAddresses} || ());
	my $institute_names_arrayref = $params->{instituteNames} || ($params->{instituteNames} || ());
	my $location_ids_arrayref = $params->{locationDbIds} || ($params->{locationDbIds} || ());
	my $location_names_arrayref  = $params->{locationNames } || ($params->{locationNames } || ());
	my $location_types_arrayref = $params->{locationType} || ($params->{locationTypes} || ());

    if (($institute_names_arrayref && scalar($institute_names_arrayref)>0) || ($coordinates && scalar($coordinates)>0 )){
        push @$status, { 'error' => 'The following search parameters are not implemented: instituteNames, coordinates'};
    }

	my %location_ids_arrayref;
    if ($location_ids_arrayref && scalar(@$location_ids_arrayref)>0){
        %location_ids_arrayref = map { $_ => 1} @$location_ids_arrayref;
    }

    my %abbreviations_arrayref;
    if ($abbreviations_arrayref && scalar(@$abbreviations_arrayref)>0){
        %abbreviations_arrayref = map { $_ => 1} @$abbreviations_arrayref;
    }

    my %country_codes_arrayref;
    if ($country_codes_arrayref && scalar(@$country_codes_arrayref)>0){
        %country_codes_arrayref = map { $_ => 1} @$country_codes_arrayref;
    }

    my %country_names_arrayref;
    if ($country_names_arrayref && scalar(@$country_names_arrayref)>0){
        %country_names_arrayref = map { $_ => 1} @$country_names_arrayref;
    }

    my %institute_addresses_arrayref;
    if ($institute_addresses_arrayref && scalar(@$institute_addresses_arrayref)>0){
        %institute_addresses_arrayref = map { $_ => 1} @$institute_addresses_arrayref;
    }

    # my %institute_names_arrayref;
    # if ($institute_names_arrayref && scalar(@$institute_names_arrayref)>0){
    #     %institute_names_arrayref = map { $_ => 1} @$institute_names_arrayref;
    # }

    my %location_names_arrayref;
    if ($location_names_arrayref && scalar(@$location_names_arrayref)>0){
        %location_names_arrayref = map { $_ => 1} @$location_names_arrayref;
    }
        
    my %location_types_arrayref;
    if ($location_types_arrayref && scalar(@$location_types_arrayref)>0){
        %location_types_arrayref = map { $_ => 1} @$location_types_arrayref;
    }

	my %externalreference_ids_arrayref;
	if ($externalreference_ids_arrayref && scalar(@$externalreference_ids_arrayref)>0){
		%externalreference_ids_arrayref = map { $_ => 1} @$externalreference_ids_arrayref;
	}

	my %externalreference_sources_arrayref;
	if ($externalreference_sources_arrayref && scalar(@$externalreference_sources_arrayref)>0){
		%externalreference_sources_arrayref = map { $_ => 1} @$externalreference_sources_arrayref;
	}

	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema ); #, $location_id);

	my @available;

	foreach (@$locations){
		if ( (%location_ids_arrayref && !exists($location_ids_arrayref{$_->[0]}))) { next; }
		if ( (%abbreviations_arrayref && !exists($abbreviations_arrayref{$_->[9]}))) { next; }
        if ( (%country_codes_arrayref && !exists($country_codes_arrayref{$_->[6]}))) { next; }
        if ( (%country_names_arrayref && !exists($country_names_arrayref{$_->[5]}))) { next; }
        if ( (%institute_addresses_arrayref && !exists($institute_addresses_arrayref{$_->[10]}))) { next; }
        # if ( (%institute_names_arrayref && !exists($institute_names_arrayref{$_->[]}))) { next; }
        if ( (%location_names_arrayref && !exists($location_names_arrayref{$_->[1]}))) { next; }
        if ( (%location_types_arrayref && !exists($location_types_arrayref{$_->[8]}))) { next; }
        if ( $altitude_max && $_->[4] > $altitude_max ) { next; } 
        if ( $altitude_min && $_->[4] < $altitude_min ) { next; }

		# combine referenceID and referenceSource into AND check as used by bi-api filter
		# won't work with general search but wasn't implemented anyways
		my $passes_search = 0;

		# if location has external references
		if ($_->[11]) { #
			# see if any of the references match search parameters
			foreach my $reference (@{$_->[11]}) {
				my $ref_id = $reference->{'referenceID'};
				my $ref_source = $reference->{'referenceSource'};
				if (exists($externalreference_ids_arrayref{$ref_id}) && exists($externalreference_sources_arrayref{$ref_source})) {
					$passes_search = 1;
				}
			}
		}

		if (!$passes_search && %externalreference_ids_arrayref && %externalreference_sources_arrayref) { next; }
		push @available, $_;

	}

	$self->get_response(\@available, 1);
}

sub detail {
	my $self = shift;
	my $location_id = shift;
	my $locations = CXGN::Trial::get_all_locations($self->bcs_schema , $location_id);

	$self->get_response($locations, 0);
}

sub get_response {
	my $self = shift;
	my $locations = shift;
	my $array = shift;

	my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my @data;

	my @locations = @{$locations};

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@locations,$page_size,$page);

	foreach (@$data_window){

		my $coordinates = undef;

		# if lat & lon exist
		if ($_->[2] && $_->[3]) {
			my @coords;
			push @coords, $_->[3]; # lon
			push @coords, $_->[2]; # lat
			if ($_->[4]) {
				push @coords, $_->[4]; #alt
			}

			$coordinates = {
				geometry=>{
					coordinates=>\@coords,
					type=>'Point'
				},
				type=>'Feature'
			};
		}

		my $references = CXGN::BrAPI::v2::ExternalReferences->new({
			bcs_schema => $self->bcs_schema,
			table_name => 'NaturalDiversity::NdGeolocationprop',
			base_id_key => 'nd_geolocation_id',
			base_id => $_->[0]
		});
		my $external_references = $references->references_db();
		push @data, {
			locationDbId => qq|$_->[0]|,
			locationType=> $_->[8],
			locationName=> $_->[1],
			abbreviation=>$_->[9],
			countryCode=> $_->[6],
			countryName=> $_->[5],
			instituteName=>'',
			instituteAddress=>$_->[10],
			additionalInfo=> $_->[7],
			documentationURL=> undef,
			siteStatus => undef,
			exposure => undef,
			slope => undef,
			coordinateDescription => undef,
			environmentType => undef,
			coordinates=>$coordinates,
			topography => undef,
			coordinateUncertainty => undef,
			externalReferences=> $external_references
		};
	}

	my @data_files;

	if ($array) {
		my %result = (data => \@data);
		return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Locations list result constructed');
	} else {
		$pagination = CXGN::BrAPI::Pagination->pagination_response(1,$page_size,$page);
		return CXGN::BrAPI::JSONResponse->return_success(@data[0], $pagination, \@data_files, $status, 'Locations object result constructed');
	}

}

sub store {
	my $self = shift;
	my $data = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema();
    my @location_ids;

	foreach my $params (@{$data}) {
		my $id = $params->{locationDbId} || undef;
		my $name = $params->{locationName};
		my $abbreviation =  $params->{abbreviation} || undef;
		my $country_name =  $params->{countryName} || undef;
		my $country_code =  $params->{countryCode} || undef;
		my $program_id =  $params->{additionalInfo}->{programDbId}  || undef;
		my $type =  $params->{locationType} || undef;
		my $geo_coordinates = $params->{coordinates}->{geometry}->{coordinates} || undef;
		my $latitude = $geo_coordinates->[1] || undef;
		my $longitude = $geo_coordinates->[0] || undef;
		my $altitude  = $geo_coordinates->[2]|| undef;
		my $noaa_station_id    = $params->{additionalInfo}->{noaaStationId} || undef;
		my $external_references = $params->{externalReferences};
		my $program_name;

		if ($id) {
			my $location = $schema->resultset('NaturalDiversity::NdGeolocation')->find({nd_geolocation_id => $id});
			if (!$location) {
				my $err_string = sprintf('Location %s does not exist.',$id);
				warn $err_string;
				return CXGN::BrAPI::JSONResponse->return_error($self->status, $err_string, 404);
			}
		}

		my $existing_name_count = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count();
		if ($existing_name_count > 0) {
			my $err_string = sprintf('Location name %s already exists.', $name );
			warn $err_string;
			return CXGN::BrAPI::JSONResponse->return_error($self->status, $err_string, 409);
		}

		if ($program_id) {
			my $program = $schema->resultset('Project::Project')->find({project_id => $program_id});
			if (!$program) {
				my $err_string = sprintf('Program %s does not exist.',$program_id);
				warn $err_string;
				return CXGN::BrAPI::JSONResponse->return_error($self->status, $err_string, 404);
			}
			$program_name = $program->name();
		}

		print STDERR "Creating location object\n";

		my $location = CXGN::Location->new( {
			bcs_schema => $schema,
			nd_geolocation_id => $id,
			name => $name,
			abbreviation => $abbreviation,
			country_name => $country_name,
			country_code => $country_code,
			breeding_programs => $program_name,
			location_type => $type,
			latitude => $latitude,
			longitude => $longitude,
			altitude => $altitude,
			noaa_station_id => $noaa_station_id,
			external_references => $external_references
		});

		my $store = $location->store_location();

		if ($store->{'error'}) {
			my $err_string = $store->{'error'};
			warn $err_string;
			return CXGN::BrAPI::JSONResponse->return_error($self->status, $err_string, 500);
		} else {
			push @location_ids, $store->{'nd_geolocation_id'};
		}
	}
	my %result;
	my $count = scalar @location_ids;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success( \%result, $pagination, undef, $self->status(), $count . " Locations were saved.");
}

1;
