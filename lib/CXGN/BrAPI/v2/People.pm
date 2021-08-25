package CXGN::BrAPI::v2::People;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
	my $c = shift;

    my $status = $self->status;

    my $first_name_arrayref = $params->{firstName} || ($params->{firstNames} || ());
    my $last_name_arrayref = $params->{lastName} || ($params->{lastNames} || ());
    my $person_ids_arrayref = $params->{personDbId} || ($params->{personDbIds} || ());
    my $user_ids_arrayref = $params->{userID} || ($params->{userIDs} || ());
    my $reference_ids_arrayref = $params->{externalReferenceID} || ($params->{externalReferenceIDs} || ());
    my $reference_sources_arrayref = $params->{externalReferenceSource} || ($params->{externalReferenceSources} || ());
    my $email_arrayref = $params->{emailAddress} || ($params->{emailAddresses} || ());
    my $mail_arrayref = $params->{mailingAddress} || ($params->{mailingAddresses} || ());
    my $middle_name_arrayref = $params->{middleName} || ($params->{middleNames} || ());
    my $phone_arrayref = $params->{phoneNumber} || ($params->{phoneNumbers} || ());

    if (($reference_ids_arrayref && scalar(@$reference_ids_arrayref)>0) || ($reference_sources_arrayref && scalar(@$reference_sources_arrayref)>0) ){
        push @$status, { 'error' => 'The following search parameters are not implemented: externalReferenceID, externalReferenceSources, middleName' };
    }

	my $page_size = $self->page_size;
	my $page = $self->page;
	my $start_index = $page*$page_size;
    my $end_index = $page*$page_size + $page_size - 1;
	my $counter = 0;
	my @data;

	my %query;

	foreach ( @$first_name_arrayref ) { 
	   push @{$query{"first_name"} }, { 'ilike' => '%'.$_ .'%' };
	}

    foreach ( @$last_name_arrayref ) { 
    	push @{$query{'last_name'} }, { 'ilike' => '%'.$_ .'%' };
	}
	foreach ( @$person_ids_arrayref ) { 
	    push @{$query{'sp_person_id'} }, { ' = ' => $_ };
	}
	foreach ( @$user_ids_arrayref ) { 
	    push @{$query{'username'} }, { 'ilike' => '%'. $_  .'%' };
	}
	foreach ( @$email_arrayref ) { 
	    push @{$query{'contact_email'} }, { 'ilike' => '%'. $_  .'%' };
	}
	foreach ( @$mail_arrayref ) { 
	    push @{$query{'address'} }, { 'ilike' => '%'. $_ .'%' };
	}
	foreach ( @$phone_arrayref ) { 
	    push @{$query{'phone_number'} }, { 'ilike' => '%'. $_  .'%' };
	}

 	my $rs2 = $c->dbic_schema("CXGN::People::Schema")->resultset("SpPerson")->search( { %query, disabled=>undef, censor => 0 }, { order_by => { -asc =>'sp_person_id'} } );


    while (my $p = $rs2->next()) { 
		if ($counter >= $start_index && $counter <= $end_index) {     
			my $id = $p->sp_person_id();
		    push @data , {
		        additionalInfo => {
		        	country => $p->country(),
		        	},
		        description => $p->organization() ? "Organization: ". $p->organization() : undef,
		        emailAddress => $p->contact_email(),
		        externalReferences => {
		        	referenceSource => $p->webpage(),
		        	referenceID => undef,
		        	},
		        firstName => $p->first_name(),
		        lastName => $p->last_name(),
		        mailingAddress => $p->address(),
		        middleName => undef,
		        personDbId => qq|$id|,
		        phoneNumber => $p->phone_number(),
		        userID => $p->username(),
		    };
		}
		$counter++;
    }

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'People result constructed');
}

sub detail {
	my $self = shift;
	my $list_id = shift;
	my $c = shift;
    my $status = $self->status;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $counter = 0;
	my %result;

	my %query;

	$query{'sp_person_id'} = { ' =' => $list_id  };

 	my $rs2 = $c->dbic_schema("CXGN::People::Schema")->resultset("SpPerson")->search( { %query, disabled=>undef, censor => 0 }, { page => $page, rows => $page_size, order_by => 'last_name' } );
	

    while (my $p = $rs2->next()) { 
    	my $id = $p->sp_person_id();
	    %result = (
	        additionalInfo => {
	        	country => $p->country(),
	        	},
	        description => "Organization: ". $p->organization(),
	        emailAddress => $p->contact_email(),
	        externalReferences => {
	        	referenceSource => $p->webpage(),
	        	referenceID => undef,
	        	},
	        firstName => $p->first_name(),
	        lastName => $p->last_name(),
	        mailingAddress => $p->address(),
	        middleName => undef,
	        personDbId => qq|$id|,
	        phoneNumber => $p->phone_number(),
	        userID => $p->username(),
	    );
	    $counter++;
    }

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'People result constructed');
}

1;
