package CXGN::BrAPI::v1::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
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

sub observation_levels {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;
	my @available = (
		'plant','plot','all'
	);

	my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($available[$i]) {
			push @data, $available[$i];
		}
	}

	my $total_count = scalar(@available);
	my %result = (data=>\@data);
	push @$status, { 'success' => 'Observation Levels result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = { 
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub observation_variable_data_types {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;

	my @available;
	my $trait_format_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'trait_format', 'trait_property')->cvterm_id;
	my $rs = $self->bcs_schema->resultset('Cv::Cvtermprop')->search({type_id=>$trait_format_cvterm_id}, {select=>['value'], distinct=>1});
	while (my $r = $rs->next){
		push @available, $r->value;
	}

	my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($available[$i]) {
			push @data, $available[$i];
		}
	}

	my $total_count = scalar(@available);
	my %result = (data=>\@data);
	push @$status, { 'success' => 'Observation variable data types result constructed' };
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	my $response = {
		'status' => $status,
		'pagination' => $pagination,
		'result' => \%result,
		'datafiles' => []
	};
	return $response;
}

sub observation_variable_ontologies {
	my $self = shift;
	my $inputs = shift;
	my $name_spaces = $inputs->{name_spaces};
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @available;

	#Using code pattern from SGN::Controller::AJAX::Onto->roots_GET
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, dbxref.version, dbxref.description FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id=cvterm_relationship.subject_id) WHERE cvterm_relationship.subject_id IS NULL AND is_obsolete= 0 AND is_relationshiptype = 0 and db.name=?;";
	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	foreach (@$name_spaces){
		$sth->execute($_);
		while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $dbxref_accession, $dbxref_version, $dbxref_description) = $sth->fetchrow_array()) {
			my $info;
			if($dbxref_description){
				$info = decode_json($dbxref_description);
			}
			push @available, {
				ontologyDbId=>$db_name,
				ontologyName=>$cvterm_name,
				authors=>$info->{authors},
				version=>$dbxref_version,
				copyright=>$info->{copyright},
				licence=>$info->{licence}
			};
		}
	}

	my @data;
	my $start = $page_size*$page;
	my $end = $page_size*($page+1)-1;
	for( my $i = $start; $i <= $end; $i++ ) {
		if ($available[$i]) {
			push @data, $available[$i];
		}
	}

	my $total_count = scalar(@available);
	my %result = (data=>\@data);
	push @$status, { 'success' => 'Ontologies result constructed' };
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
