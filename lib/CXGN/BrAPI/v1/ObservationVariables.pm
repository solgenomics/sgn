package CXGN::BrAPI::v1::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

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
		'plant','plot','tissue_sample','all'
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
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation Levels result constructed');
}

sub observation_variable_data_types {
	my $self = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;

	my $status = $self->status;

	my @available;
	my $trait_format_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'trait_format', 'cvterm_property')->cvterm_id;
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
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation variable data types result constructed');
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
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, dbxref.version, dbxref.description, cv.cv_id, cv.name, cv.definition FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) JOIN cv USING(cv_id) LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id=cvterm_relationship.subject_id) WHERE cvterm_relationship.subject_id IS NULL AND is_obsolete= 0 AND is_relationshiptype = 0 and db.name=?;";
	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	foreach (@$name_spaces){
		$sth->execute($_);
		while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $dbxref_accession, $dbxref_version, $dbxref_description, $cv_id, $cv_name, $cv_definition) = $sth->fetchrow_array()) {
			my $info;
			if($dbxref_description){
				$info = decode_json($dbxref_description);
			}
			push @available, {
                ontologyDbId=>qq|$db_id|,
                ontologyName=>$db_name." (".$cv_name.")",
                description=>$cvterm_name,
                authors=>$info->{authors} ? $info->{authors} : '',
                version=>$dbxref_version,
                copyright=>$info->{copyright} ? $info->{copyright} : '',
                licence=>$info->{licence} ? $info->{licence} : ''
			};
		}
	}

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@available,$page_size,$page);
	my %result = (data=>$data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Ontologies result constructed');
}

sub observation_variable_search {
	my $self = shift;
	my $inputs = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @trait_ids = $inputs->{observationvariable_db_ids} ? @{$inputs->{observationvariable_db_ids}} : ();
	my @db_names = $inputs->{ontology_db_names} ? @{$inputs->{ontology_db_names}} : ();
	my @dbxref_terms = $inputs->{ontology_dbxref_terms} ? @{$inputs->{ontology_dbxref_terms}} : ();
	my @method_ids = $inputs->{method_db_ids} ? @{$inputs->{method_db_ids}} : ();
	my @scale_ids = $inputs->{scale_db_ids} ? @{$inputs->{scale_db_ids}} : ();
	my @cvterm_names = $inputs->{observationvariable_names} ? @{$inputs->{observationvariable_names}} : ();
	my @datatypes = $inputs->{observationvariable_datatypes} ? @{$inputs->{observationvariable_datatypes}} : ();
	my @classes = $inputs->{observationvariable_classes} ? @{$inputs->{observationvariable_classes}} : ();

	my $join = '';
	my @and_wheres;
	if (scalar(@trait_ids)>0){
		my $trait_ids_sql = join ',', @trait_ids;
		push @and_wheres, "cvterm.id IN ($trait_ids_sql)";
	}
	if (scalar(@db_names)>0){
		foreach (@db_names){
			push @and_wheres, "db.name = '$_'";
		}
	}
	if (scalar(@dbxref_terms)>0){
		my @db_names;
		my @dbxref_accessions;
		foreach (@dbxref_terms){
			my ($db_name, $accession) = split ':', $_;
			push @db_names, $db_name;
			push @dbxref_accessions, $accession;
		}
		foreach (@db_names){
			push @and_wheres, "db.name = '$_'";
		}
		foreach (@dbxref_accessions){
			push @and_wheres, "dbxref.accession = '$_'";
		}
	}
	if (scalar(@cvterm_names)>0){
		foreach (@cvterm_names){
			push @and_wheres, "cvterm.name = '$_'";
		}
	}
	if (scalar(@datatypes)>0){
		$join = 'JOIN cvtermprop on (cvterm.cvterm_id=cvtermprop.cvterm_id)';
		foreach (@datatypes){
			push @and_wheres, "cvtermprop.value = '$_'";
		}
	}

	push @and_wheres, "reltype.name='VARIABLE_OF'";

	my $and_where_clause = join ' AND ', @and_wheres;

	my @data;
	my $limit = $page_size;
	my $offset = $page*$page_size;
	my $total_count = 0;
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db using(db_id) JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) $join WHERE $and_where_clause ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset;";
	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	$sth->execute();
	while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $accession, $count) = $sth->fetchrow_array()) {
		$total_count = $count;
		my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
		my $categories = $trait->categories;
		my @brapi_categories = split '/', $categories;
		push @data, {
			observationVariableDbId => qq|$cvterm_id|,
			name => $cvterm_name."|".$db_name.":".$accession,
			ontologyDbId => qq|$db_id|,
			ontologyName => $db_name,
			trait => {
				traitDbId => qq|$cvterm_id|,
				name => $cvterm_name,
				description => $cvterm_definition,
                class => ''
			},
			method => {},
			scale => {
				scaleDbId =>'',
				name =>'',
				datatype=>$trait->format,
				decimalPlaces=>undef,
				xref=>'',
				validValues=> {
					min=>$trait->minimum ? $trait->minimum : undef,
					max=>$trait->maximum ? $trait->maximum : undef,
					categories=>\@brapi_categories
				}
			},
			xref => $db_name.":".$accession,
			defaultValue => $trait->default_value
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
}

sub observation_variable_detail {
	my $self = shift;
	my $trait_id = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my %result;
	my @data_files;
	my $total_count = 0;
	my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$trait_id});
	if ($trait->display_name){
		my $categories = $trait->categories;
		my @brapi_categories = split '/', $categories;
		%result = (
			observationVariableDbId => qq|$trait->cvterm_id|,
			name => $trait->display_name,
			ontologyDbId => qq|$trait->db_id|,
			ontologyName => $trait->db,
			trait => {
				traitDbId => qq|$trait->cvterm_id|,
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
		);
	}
	$total_count = 1;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable detail result constructed');
}


1;
