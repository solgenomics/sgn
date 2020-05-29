package CXGN::BrAPI::v2::Lists;

use Moose;
use Data::Dumper;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub search {
	my $self = shift;
	my $params = shift;
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

	my $lists = CXGN::List::available_public_lists($self->bcs_schema()->storage->dbh(),$types_arrayref->[0]);

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
				externalReferences => undef,
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
	my $page_obj = CXGN::Page->new();
    my $hostname = $page_obj->get_hostname();
    my $status = $self->status;
    my $counter = 0;

	my $page_size = $self->page_size;
	my $page = $self->page;

	my %result;
	my $lists = CXGN::List::available_public_lists($self->bcs_schema()->storage->dbh());

	foreach (@$lists){
		my $name = $_->[1];
		my $id = $_->[0];

		if ( $list_id eq $id ){

			%result = (
				additionalInfo => {},
				dateCreated => undef,
				dateModified => undef,
				externalReferences => undef,
				listDbId => qq|$id|,
				listDescription => $_->[2],
				listName => $name,
				listOwnerName => $_->[6],
				listOwnerPersonDbId => undef,
				listSize => $_->[3],
				listSource => $hostname,
				listType => $_->[5],
			);
		$counter++;
		}
	}

	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($counter,$page_size,$page);

	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Lists result constructed');
}

1;
