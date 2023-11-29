package CXGN::BrAPI::v2::Lists;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use CXGN::TimeUtils;
use SGN::Model::Cvterm;
use JSON;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;

	my $page_obj = CXGN::Page->new();
    my $hostname = $page_obj->get_hostname();
    my $status = $self->status;

    my $list_type = $params->{listType} || ($params->{listTypes});
    my $names_arrayref = $params->{listName} || ($params->{listNames} || ());
    my $list_ids_arrayref = $params->{listDbId} || ($params->{listDbIds} || ());
    my $list_source_arrayref = $params->{listSource} || ($params->{listSources} || ());
    my $reference_ids_arrayref = $params->{externalReferenceId} || $params->{externalReferenceID} || ($params->{externalReferenceIds} || $params->{externalReferenceIDs} || ());
    my $reference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());
	my $list_owner_array_refs = $params->{listOwnerPersonDbIds};
	my $user_id = shift || $list_owner_array_refs->[0];
	my $brapi_require_login = shift;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
	my $counter = 0;
	my @data;
	my $lists;

	my $list_type = convert_to_breedbase_type($list_type);
	if ($list_type) {
		my $q = "SELECT cvterm_id FROM cvterm WHERE name =?";
		my $h = $self->bcs_schema()->storage->dbh()->prepare($q);
		$h->execute($list_type);
		my ($cvterm_id) = $h->fetchrow_array();
		if (!$cvterm_id) {
			return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide a valid BrAPI list type: %s',$list_type), 400);
		}
	}

	if($brapi_require_login) {
		if ($user_id) {
			$lists = CXGN::List::available_lists($self->bcs_schema()->storage->dbh(), $user_id, $list_type);
		}
		else {
			$lists = CXGN::List::available_public_lists($self->bcs_schema()->storage->dbh(), $list_type);
		}
	} else {
		$lists = CXGN::List::all_lists($self->bcs_schema()->storage->dbh(),$user_id,$list_type);
	}

	my @list_ids;
	for (@$lists) {
		push @list_ids, $_->[0];
	}
	my $references = CXGN::BrAPI::v2::ExternalReferences->new({
		bcs_schema => $self->bcs_schema,
		table_name => 'sgn_people.list',
		table_id_key => 'list_id',
		id => \@list_ids
	});
	my $reference_result = $references->search();
	my $additional_info_cvterm_id = _fetch_additional_info_cvterm_id($self->bcs_schema);

	foreach (@$lists){
		my $name = $_->[1];
		my $id = $_->[0];
		my $create_date = $_->[-2];
		my $modified_date = $_->[-1];
		if ( $names_arrayref && ! grep { $_ eq $name } @{$names_arrayref} ) { next;};
		if ( $list_ids_arrayref && ! grep { $_ eq $id } @{$list_ids_arrayref} ) { next;};
		if ( $list_source_arrayref && ! grep { $_ eq $hostname } @{$list_source_arrayref} ) { next;};

		#Get external references
		my @references;
		my $match_found = $reference_ids_arrayref || $reference_sources_arrayref ? 0 : 1;
		my %externalRefIdMap = map { $_ => 1 } @$reference_ids_arrayref;
		my %externalRefSourceMap = map { $_ => 1 } @$reference_sources_arrayref;
		if (%$reference_result{$id}){
			foreach (@{%$reference_result{$id}}){
				push @references, $_;

				if(!$match_found) {
					my $source_found = %externalRefSourceMap ? 0 : 1;
					my $id_found = %externalRefIdMap ? 0 : 1;
					if (!$id_found) {
						$id_found = %externalRefIdMap{$_->{referenceID}} ? 1 : 0;
					}
					if (!$source_found) {
						$source_found = %externalRefSourceMap{$_->{referenceSource}} ? 1 : 0;
					}
					$match_found = $id_found && $source_found;
				}
			}
		}

		if(!$match_found) {
			next;
		}
		my $additional_info_json = _fetch_additional_info( $self->bcs_schema, $id, $additional_info_cvterm_id);

		if ($counter >= $start_index && $counter <= $end_index) {
			push @data , {
				additionalInfo      => $additional_info_json,
				dateCreated         => CXGN::TimeUtils::db_time_to_iso_utc($create_date),
				dateModified        => CXGN::TimeUtils::db_time_to_iso_utc($modified_date),
				listDbId            => qq|$id|,
				listDescription     => $_->[2],
				listName            => $name,
				listOwnerName       => $_->[6],
				listOwnerPersonDbId => undef,
				listSize            => $_->[3],
				listSource          => $hostname,
				listType            => convert_to_brapi_type($_->[5]),
				externalReferences  => \@references
			}
		}
		$counter++;
	}

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Lists result constructed');
}
sub _fetch_additional_info_cvterm_id{
	my $bcs_schema = shift;

	my $dbh = $bcs_schema->storage()->dbh();
	my $type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'list_additional_info', 'list_properties')->cvterm_id();

	return $type_id;
}

sub _fetch_additional_info {
	my $bcs_schema = shift;
	my $list_id = shift;
	my $cvterm_id = shift;

	my $dbh = $bcs_schema->storage()->dbh();

	my $sql = "SELECT value FROM sgn_people.listprop WHERE list_id = ? AND type_id = ?";
	my $sth = $dbh->prepare($sql);
	$sth->execute($list_id, $cvterm_id);
	my ($additional_info_value) = $sth->fetchrow_array();

	# Convert JSON String ($additional_info_value) to JSON object ($additional_info_json)
	my $additional_info_json;
	if ($additional_info_value) {
		$additional_info_json = JSON::XS::decode_json($additional_info_value);
	}
	else{
		$additional_info_json = {};
	}
	return $additional_info_json;
}

sub convert_to_brapi_type {
	my $type = shift;
	if ($type eq 'accessions') {
		return 'germplasm';
	}
	if ($type eq 'traits') {
		return 'observationVariables';
	}
	return $type;
}

sub convert_to_breedbase_type {
	my $type = shift;
	return $type if !$type;
	if ('germplasm' eq $type) {
		return 'accessions';
	}
	if ('observationVariables' eq $type) {
		return 'traits';
	}
	return $type;
}

sub detail {
	my $self = shift;
	my $list_id = shift;
	my $user_id = shift;
	my $page_obj = CXGN::Page->new();
    my $hostname = $page_obj->get_hostname();
    my $status = $self->status;

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $dbh = $self->bcs_schema()->storage()->dbh();
	my $people_schema = $self->people_schema();

	my $list;
	my %result;

	eval{
		$list = CXGN::List->new( { dbh => $dbh, list_id=>$list_id });
	};

	if ($list){

		my $list_elements_with_ids = $list->retrieve_elements_with_ids($list_id);

		my %query;
		$query{'sp_person_id'} = { ' =' => $list->{owner} };

	 	my $rs = $people_schema->resultset("SpPerson")->search( { %query });
		my $owner_name;

		while (my $p = $rs->next()) {
			$owner_name = $p->first_name() . " " . $p->last_name();
		}


		my @data = $list->{elements};
		my $size = scalar(@{$list->{elements}});;

		my $references = CXGN::BrAPI::v2::ExternalReferences->new({
			bcs_schema => $self->bcs_schema,
			table_name => 'sgn_people.list',
			table_id_key => 'list_id',
			id => [$list_id]
		});
		my $reference_result = $references->search();
		my @references;
		if (%$reference_result{$list_id}){
			foreach (@{%$reference_result{$list_id}}){
				push @references, $_;
			}
		}
		my $additional_info_cvterm_id = _fetch_additional_info_cvterm_id($self->bcs_schema);
		my $additional_info_json = _fetch_additional_info( $self->bcs_schema, $list_id, $additional_info_cvterm_id );
		%result = (
			additionalInfo      => $additional_info_json,
			dateCreated         => $list->{create_date},
			dateModified        => undef,
			listDbId            => qq|$list_id|,
			listDescription     => $list->{description},
			listName            => $list->{name},
			listOwnerName       => $owner_name,
			listOwnerPersonDbId => qq|$list->{owner}|,
			listSize            => $size,
			listSource          => $hostname,
			listType            => convert_to_brapi_type($list->{type}),
			data                => @data,
			externalReferences  => \@references
			);
	}
    my $counter = %result;
    $counter = 1 if ($counter > 1);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Lists result constructed');
}

sub store {
	my $self = shift;
	my $data = shift;
	my $user_id = shift;
	if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }
	my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;
    my $counter = 0;
	my @new_lists_ids;
	my $additional_info_cvterm_id = _fetch_additional_info_cvterm_id($self->bcs_schema);
	foreach my $params (@$data){
		my $date_created = $params->{dateCreated} || undef; #not supported
		my $date_modified = $params->{dateModified} || undef; #not supported
		my $owner_name = $params->{listOwnerName} || undef; #not supported
		my $list_size = $params->{listSize} || undef; #not supported, counted from data
		my $list_source = $params->{listSource} || undef;  #not supported, db name
		my $additional_info_hash_ref = $params->{additionalInfo} || undef;
		my $externalReferences = $params->{externalReferences} || undef;
		my $list_name = $params->{listName} || undef;
		my $list_type = $params->{listType} || undef;
		my $list_description = $params->{listDescription} || undef;
		my $owner_id = $params->{listOwnerPersonDbId} || $user_id;
		my $data = $params->{data} || undef;

		$list_type = convert_to_breedbase_type($list_type);
		#verify if list exists
		my $check_list_id = CXGN::List::exists_list($dbh, $list_name, $owner_id);
		if ($check_list_id->{list_id}){
        	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('List name %s already exist in the database!',$list_name), 409);
		}
	    #check entries
		if (!$list_type || !$data) {
        	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide list type and data!'), 400);
		}

		my $q = "SELECT cvterm_id FROM cvterm WHERE name =?";
		my $h = $dbh->prepare($q);
		$h->execute($list_type);
		my ($cvterm_id) = $h->fetchrow_array();
		if (!$cvterm_id) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide a valid BrAPI list typee: %s',$list_type));
		}

	    #validate
	    my $lv = CXGN::List::Validate->new();
	    my $validated = $lv->validate($schema, $list_type, $data);
	    my $missing = scalar(@{$validated->{missing}});
	    if ($missing > 0){
		    return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Data must have valid items existing in the database!'));
	    }
		#create list
    	my $new_list_id = CXGN::List::create_list($dbh, $list_name, $list_description, $owner_id);
	    my $list = CXGN::List->new( { dbh=>$dbh, list_id => $new_list_id });

    	#add list type
		my $error = $list->type($list_type);
		if (!$error) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error ocurred with type!'));
		}

		#add elements
    	if ($data){
		    my $response = $list->add_bulk($data);
		    if ($response->{error}) {
		    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error ocurred!'));
		    }
		}

		# Store external references
		if ($externalReferences && scalar $externalReferences > 0) {
			my $references = CXGN::BrAPI::v2::ExternalReferences->new({
				bcs_schema => $self->bcs_schema,
				table_name => 'sgn_people.list',
				table_id_key => 'list_id',
				external_references => $externalReferences,
				id => $new_list_id
			});
			my $reference_result = $references->store();
		}
		# Store additional Info
		if( $additional_info_hash_ref ) {
			my $dbh = $self->bcs_schema->storage()->dbh();
			my $sql = "INSERT INTO sgn_people.listprop (list_id, type_id, value ) VALUES ( ?, ?, ?)";
			my $sth = $dbh->prepare($sql);

			my $additional_info_json_str = to_json( $additional_info_hash_ref );
			$sth->execute($new_list_id, $additional_info_cvterm_id, $additional_info_json_str);
		}

	    $counter++;
		push @new_lists_ids, $new_list_id;

	}

  	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	my $params;
	$params->{listDbIds} = \@new_lists_ids;
	return $self->search($params);
}

sub update {
	my $self = shift;
    my $params = shift;
    my $user_id =shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

	my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;
    my $counter = 1;

	my $date_created = $params->{dateCreated} || undef; #not supported
	my $date_modified = $params->{dateModified} || undef; #not supported
	my $owner_name = $params->{listOwnerName} || undef; #not supported
	my $list_size = $params->{listSize} || undef; #not supported, counted from data
	my $list_source = $params->{listSource} || undef;  #not supported, db name
	my $additional_info_hash_ref = $params->{additionalInfo} || undef;
	my $externalReferences = $params->{externalReferences} || undef;
	my $list_id = $params->{listDbId} || undef;
	my $list_name = $params->{listName} || undef;
	my $list_type = $params->{listType} || undef;
	my $list_description = $params->{listDescription} || undef;
	my $owner_id = $params->{listOwnerPersonDbId} || undef;
	my $data = $params->{data} || undef;
    #Retrieve list
    my $list = CXGN::List->new( { dbh=>$dbh, list_id => $list_id });

    if (!$list_name || length($list_name) < 1) {
    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide valid list name.'));
    }
	$list->name($list_name);
	if ($list_description) {
		$list->description($list_description);
	}

	#add list type
	if ($list_type ) {
		$list_type = convert_to_breedbase_type($list_type);
		my $q = "SELECT cvterm_id FROM cvterm WHERE name =?";
		my $h = $dbh->prepare($q);
		$h->execute($list_type);
		my ($cvterm_id) = $h->fetchrow_array();
		if (!$cvterm_id) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide valid list type: %s',$list_type));
		}
		my $error = $list->type($list_type);
		if (!$error) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error ocurred with type!'));
		}
	}

	#add elements
	if ($data && $list_type){
		#validate first
	    my $lv = CXGN::List::Validate->new();
	    my $validated = $lv->validate($schema, $list_type, $data);
	    my $missing = scalar(@{$validated->{missing}});
	    if ($missing > 0){
		    return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Data must have valid items existing in the database!'));
	    }
	    my $response = $list->add_bulk($data);
	    if ($response->{error}) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error ocurred!'));
	    }
	}

	# Update external references
	if ($externalReferences && scalar $externalReferences > 0) {
		my $references = CXGN::BrAPI::v2::ExternalReferences->new({
			bcs_schema          => $self->bcs_schema,
			table_name          => 'sgn_people.list',
			table_id_key        => 'list_id',
			external_references => $externalReferences,
			id                  => $list_id
		});
		my $reference_result = $references->store();
	}
	# Update 'additional Info'
	if( $additional_info_hash_ref ) {
		my $dbh = $self->bcs_schema->storage()->dbh();
		my $sql = "DELETE FROM sgn_people.listprop WHERE list_id = ?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($list_id);

		$sql = "INSERT INTO sgn_people.listprop (list_id, type_id, value ) VALUES ( ?, ?, ?)";
		$sth = $dbh->prepare($sql);
		my $additional_info_cvterm_id = _fetch_additional_info_cvterm_id($self->bcs_schema);
		my $additional_info_json_str = to_json( $additional_info_hash_ref );
		$sth->execute($list_id, $additional_info_cvterm_id, $additional_info_json_str);
	}

  	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return $self->detail($list_id);

}

sub store_items {
	my $self = shift;
	my $list_id = shift;
    my $params = shift;
    my $user_id =shift;

    if (!$user_id){
        return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must be logged in to add a seedlot!'));
    }

	my $data;
	@$data = keys %$params;

	my $schema = $self->bcs_schema;
    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $page_size = $self->page_size;
    my $status = $self->status;
    my $page = $self->page;
    my $counter = 1;

    #Retrieve list
    my $list = CXGN::List->new( { dbh=>$dbh, list_id => $list_id });

    if (!$data) {
    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide valid data.'));
    }

	#validate first
    my $lv = CXGN::List::Validate->new();
    my $validated = $lv->validate($schema, $list->{type}, $data);
    my $missing = scalar(@{$validated->{missing}});
    if ($missing > 0){
	    return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('Data must have valid items existing in the database!'));
    }
    my $response = $list->add_bulk($data);
    if ($response->{error}) {
    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('An error ocurred!'));
    }

  	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

  	return $self->detail($list_id);


}
1;
