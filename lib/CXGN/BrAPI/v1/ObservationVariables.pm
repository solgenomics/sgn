package CXGN::BrAPI::v1::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;

extends 'CXGN::BrAPI::v1::Common';

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
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation variable data types result constructed');
}

sub observation_variable_ontologies {
    my $self = shift;
	my $inputs = shift;
	my $name_spaces = $inputs->{name_spaces} || [];
	my $cvprop_types = $inputs->{cvprop_type_names} || ['trait_ontology','method_ontology','unit_ontology','composed_trait_ontology','object_ontology','attribute_ontology','time_ontology'];
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
	my @available;

    my @composable_cv_prop_types;
    foreach (@$cvprop_types) {
        my $composable_cv_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $_, 'composable_cvtypes')->cvterm_id();
        push @composable_cv_prop_types, $composable_cv_type_cvterm_id;
    }
    my $composable_cv_prop_sql;
    if (scalar(@composable_cv_prop_types)>0) {
        $composable_cv_prop_sql = join ("," , @composable_cv_prop_types);
        $composable_cv_prop_sql = " cvprop.type_id IN ($composable_cv_prop_sql)";
    }

    # Add db name spaces for databases tagged as trait_ontology, method_ontology, etc for the cvprop_type_names being queried. This added name spaces onto those taken from onto_root_namespaces conf key. When using the "add ontology web interface", ontologies are tagged with a cvprop type; however, when loading obo file ontologies, the cvprop must be added afterward.
    my $q1 = "SELECT distinct(db.name) FROM db JOIN dbxref ON(db.db_id = dbxref.db_id) JOIN cvterm ON(cvterm.dbxref_id = dbxref.dbxref_id) JOIN cv ON(cvterm.cv_id = cv.cv_id) JOIN cvprop ON(cvprop.cv_id=cv.cv_id) WHERE $composable_cv_prop_sql;";
    my $sth1 = $self->bcs_schema->storage->dbh->prepare($q1);
    $sth1->execute();
    while (my ($db_name) = $sth1->fetchrow_array()) {
        push @$name_spaces, $db_name;
    }

	#Using code pattern from SGN::Controller::AJAX::Onto->roots_GET
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, dbxref.version, dbxref.description, cv.cv_id, cv.name, cv.definition FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) JOIN cv USING(cv_id) JOIN cvprop USING(cv_id) LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id=cvterm_relationship.subject_id) WHERE cvterm_relationship.subject_id IS NULL AND is_obsolete= 0 AND is_relationshiptype = 0 and db.name=? AND $composable_cv_prop_sql;";
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
                ontologyName=>$db_name,
                description=>$cvterm_name,
                authors=>$info->{authors} ? $info->{authors} : '',
                version=>$dbxref_version,
                copyright=>$info->{copyright} ? $info->{copyright} : '',
                licence=>$info->{licence} ? $info->{licence} : '',
                ontologyDbxrefAccession=>$dbxref_accession,
			};
		}
	}

	my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@available,$page_size,$page);
	my %result = (data=>$data_window);
	my @data_files;
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Ontologies result constructed');
}

sub search {
	my $self = shift;
	my $inputs = shift;
	my $c = shift;
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
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, array_agg(cvtermsynonym.synonym ORDER BY CHAR_LENGTH(cvtermsynonym.synonym)), count(cvterm.cvterm_id) OVER() AS full_count
		FROM cvterm JOIN dbxref USING(dbxref_id)
		JOIN db using(db_id) JOIN cvtermsynonym using(cvterm_id)
		JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id)
		JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id)
		$join WHERE $and_where_clause
		GROUP BY cvterm.cvterm_id, db.name, db.db_id, dbxref.accession
		ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset;";

	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	$sth->execute();

	# Get values from our config
	my $supported_crop = $c->config->{'supportedCrop'};
	my $production_url = $c->config->{'main_production_site_url'};

	while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $accession, $synonym, $count) = $sth->fetchrow_array()) {
		$total_count = $count;
		my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
		my $categories = $trait->categories;
		my @brapi_categories = split '/', $categories;

        my %ontologyReference = (
            ontologyDbId => qq|$db_id|,
            ontologyName => $db_name,
            version => '',
            documentationURL => {
				URL  => '',
				type => ''
			}
		);

		# Convert our breedbase data types to BrAPI data types.
		my $trait_format = $self->convert_datatype_to_brapi($trait->format, scalar(@brapi_categories));

		# Note: Breedbase does not have a concept of 'methods'.
		# Note: Breedbase does not have a concept of 'scale'. The values populated in scale are values from cvprop.
		# Note: Breedbase does not have a created date stored from ontology variables.

		push @data, {
		    contextOfUse => [],
		    crop => $supported_crop,
		    defaultValue => $trait->default_value,
		    documentationURL => $trait->uri,
		    growthStage => '',
		    institution => $production_url,
		    language => '',
		    method => {
		        class => '',
		        description => '',
		        formula => '',
		        methodDbId => '',
		        methodName => '',
		        name => '',
		        ontologyReference => \%ontologyReference,
                reference => ''
		    },
		    name => $cvterm_name."|".$db_name.":".$accession, #$cvterm_name,
			observationVariableDbId => $cvterm_id,
			observationVariableName => $cvterm_name,
			ontologyDbId => qq|$db_id|,
			ontologyName => $db_name,
			ontologyReference => \%ontologyReference,
            scale => {
                dataType=>$trait_format,
                decimalPlaces=>undef,
                name =>'',
                ontologyReference => \%ontologyReference,
                scaleDbId =>'',
                scaleName => '',
                validValues => {
                    categories=>\@brapi_categories,
                    max=>$trait->maximum ? $trait->maximum : undef,
                    min=>$trait->minimum ? $trait->minimum : undef,
                },
                xref=>'',
            },
            scientist => '',
            status => JSON::true,
            submissionTimestamp => undef,
            synonyms => $synonym,
			trait => {
			    alternativeAbbreviations => [],
			    attribute => $cvterm_name,
                class => '',
                description => $cvterm_definition,
                entity => '',
                mainAbbreviations => '',
                name => $cvterm_name,
                ontologyReference => \%ontologyReference,
                status => '',
                synonyms => $synonym,
				traitDbId => $trait->term, #qq|$cvterm_id|,
				traitName => $cvterm_name,
				xref => $db_name.":".$accession
			},
			xref => $db_name.":".$accession,
		};
	}

	my %result = (data=>\@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
}

sub detail {
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
        my $trait_id = $trait->cvterm_id;
        my $trait_db_id = $trait->db_id;
		%result = (
			observationVariableDbId => $trait_id,
			name => $trait->display_name,
			ontologyDbId => qq|$trait_db_id|,
			ontologyName => $trait->db,
			trait => {
				traitDbId => $trait->term,
				name => $trait->name,
				description => $trait->definition,
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

sub convert_datatype_to_brapi {
	#If we find a type we want to convert, convert it.
	# If there is a type, but we have no conversion for it, let it pass.
	my $self = shift;
	my $trait_format = shift;
	my $num_brapi_categories = shift;

	if ($num_brapi_categories > 0) {
		# If the trait has categories, convert to Ordinal. Better to assume ordering,
		# than lack of ordering.
		$trait_format = "Ordinal";
	}
	elsif ($trait_format eq "qualitative") {
		# If the trait is qualitative convert to Text
		$trait_format = "Text";
	}
	elsif ($trait_format eq "" || $trait_format eq "numeric" || ! defined $trait_format){
		# If the trait is numeric or the data type is unspecified, convert to Numerical
		$trait_format = "Numerical";
	}

	# Return our processed trait format
	return $trait_format;
}

1;
