package CXGN::BrAPI::v2::Lists;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $user_id = shift;

	my $page_obj = CXGN::Page->new();
    my $hostname = $page_obj->get_hostname();
    my $status = $self->status;

    my $types_arrayref = $params->{listType} || ($params->{listTypes} || ());
    my $names_arrayref = $params->{listName} || ($params->{listNames} || ());
    my $list_ids_arrayref = $params->{listDbId} || ($params->{listDbIds} || ());
    my $list_source_arrayref = $params->{listSource} || ($params->{listSources} || ());
    my $reference_ids_arrayref = $params->{externalReferenceID} || ($params->{externalReferenceIDs} || ());
    my $reference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());

    if (($reference_ids_arrayref && scalar(@$reference_ids_arrayref)>0) || ($reference_sources_arrayref && scalar(@$reference_sources_arrayref)>0) ){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSources' };
    }

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
	my $counter = 0;
	my @data;
	my $lists;

	if ($user_id){
		$lists = CXGN::List::available_lists($self->bcs_schema()->storage->dbh(),$user_id,$types_arrayref->[0]);
	} else {
		$lists = CXGN::List::available_public_lists($self->bcs_schema()->storage->dbh(),$types_arrayref->[0]);
	}

	foreach (@$lists){
		my $name = $_->[1];
		my $id = $_->[0];
		if ( $names_arrayref && ! grep { $_ eq $name } @{$names_arrayref} ) { next;};
		if ( $list_ids_arrayref && ! grep { $_ eq $id } @{$list_ids_arrayref} ) { next;};
		if ( $list_source_arrayref && ! grep { $_ eq $hostname } @{$list_source_arrayref} ) { next;};

		if ($counter >= $start_index && $counter <= $end_index) {
			push @data , {
				additionalInfo => {},
				dateCreated => undef,
				dateModified => undef,
				externalReferences => [],
				listDbId => qq|$id|,
				listDescription => $_->[2],
				listName => $name,
				listOwnerName => $_->[6],
				listOwnerPersonDbId => undef,
				listSize => $_->[3],
				listSource => $hostname,
				listType => $_->[5],
			}
		}
		$counter++;
	}

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Lists result constructed');
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

		%result = (
				additionalInfo => {},
				dateCreated => undef,
				dateModified => undef,
				externalReferences => [],
				listDbId => qq|$list_id|,
				listDescription => $list->{description},
				listName => $list->{name},
				listOwnerName => $owner_name,
				listOwnerPersonDbId => qq|$list->{owner}|,
				listSize => $size,
				listSource => $hostname,
				listType => $list->{type},
				data => @data,
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

	foreach my $params (@$data){
		my $additional_info = $params->{additionalInfo} || undef; #not supported
		my $date_created = $params->{dateCreated} || undef; #not supported
		my $date_modified = $params->{dateModified} || undef; #not supported
		my $owner_name = $params->{listOwnerName} || undef; #not supported
		my $list_size = $params->{listSize} || undef; #not supported, counted from data
		my $list_source = $params->{listSource} || undef;  #not supported, db name
		my $list_name = $params->{listName} || undef;
		my $list_type = $params->{listType} || undef;
		my $list_description = $params->{listDescription} || undef;
		my $owner_id = $params->{listOwnerPersonDbId} || undef;
		my $data = $params->{data} || undef;

		#verify if list exists
		my $check_list_id = CXGN::List::exists_list($dbh, $list_name, $owner_id);
		if ($check_list_id->{list_id}){
        	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('List name %s already exist in the database!',$list_name));		
		}

	    #check entries
		if (!$list_type || !$data) {
        	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide list type and data!'));		
		}

		my $q = "SELECT cvterm_id FROM cvterm WHERE name =?";
		my $h = $dbh->prepare($q);
		$h->execute($list_type);
		my ($cvterm_id) = $h->fetchrow_array();
		if (!$cvterm_id) {
	    	return CXGN::BrAPI::JSONResponse->return_error($self->status, sprintf('You must provide valid list type: %s',$list_type));
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
	    $counter++;

	}

  	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(1, $pagination, \@data_files, $status, $counter . ' Lists stored');
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

	my $additional_info = $params->{additionalInfo} || undef; #not supported
	my $date_created = $params->{dateCreated} || undef; #not supported
	my $date_modified = $params->{dateModified} || undef; #not supported
	my $owner_name = $params->{listOwnerName} || undef; #not supported
	my $list_size = $params->{listSize} || undef; #not supported, counted from data
	my $list_source = $params->{listSource} || undef;  #not supported, db name
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
	$list->description($list_description);

	#add list type
	if ($list_type ) {
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

  	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(1, $pagination, \@data_files, $status, $counter . ' Lists stored');

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

	return CXGN::BrAPI::JSONResponse->return_success(1, $pagination, \@data_files, $status,'Lists stored');

}
1;
