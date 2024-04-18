package CXGN::BrAPI::v2::Traits;

use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;

extends 'CXGN::BrAPI::v2::Common';

sub list {
	my $self = shift;
    my $inputs = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;
# traitDbId=&observationVariableDbId=&externalReferenceID=&externalReferenceSource
    my $names = $inputs->{names};
    my $trait_ids = $inputs->{trait_ids};

    my $where_clause = '';
    if($names && scalar(@$names)>0){
    	my $where_clause = ' WHERE ';
        my $sql = join ("','" , @$names);
        my $name_sql = "'" . $sql . "'";
        $where_clause .= " AND cvterm.name in ($name_sql)";
    }
    if($trait_ids && scalar(@$trait_ids)>0){
        my $sql = join ("," , @$trait_ids);
        $where_clause .= " AND cvterm.cvterm_id in ($sql)";
    }

	my $limit = $page_size;
	my $offset = $page*$page_size;
	my $total_count = 0;
	my @data;
	my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, array_agg(cvtermsynonym.synonym ORDER BY CHAR_LENGTH(cvtermsynonym.synonym)) filter (where cvtermsynonym.synonym is not null), cvterm.is_obsolete, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db using(db_id) JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) LEFT JOIN cvtermsynonym on(cvtermsynonym.cvterm_id=cvterm.cvterm_id) $where_clause group by cvterm.cvterm_id, db.name, db.db_id, dbxref.accession ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset;";

	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	$sth->execute();
	while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $accession, $synonym, $obsolete, $count) = $sth->fetchrow_array()) {
		$total_count = $count;
		foreach (@$synonym){
            $_ =~ s/ EXACT \[\]//;
            $_ =~ s/\"//g;
        }
		my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});

		my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
			bcs_schema          => $self->bcs_schema,
			external_references => [],
			table_name          => "cvterm",
			table_id_key        => "cvterm_id",
			id                  => $cvterm_id
		});
		my $external_references_json= $external_references->search()->{$cvterm_id};
		if($c->config->{'brapi_include_CO_xref'}) {
			push @{ $external_references_json }, {
				referenceId => "http://www.cropontology.org/terms/".$db_name.":".$accession . "/",
				referenceSource => "Crop Ontology"
			};
		}

		my $documentation_links;
		if($trait->uri){
			push @$documentation_links, {
				"URL" => $trait->uri ? $trait->uri : undef,
				"type" => undef
			};
		}

		push @data, {
			additionalInfo => {},
			alternativeAbbreviations => undef,
			attribute => undef,
			attributePUI => undef,
			entity => undef,
			entityPUI => undef,
			externalReferences => $external_references_json,
			mainAbbreviation => undef,
			ontologyReference => {
				documentationLinks => $documentation_links,
				ontologyDbId => $trait->db_id ? $trait->db_id : undef,
				ontologyName => $trait->db ? $trait->db : undef,
				version => undef,
			},
			status => $obsolete = 0 ? "archived" : "active",
			synonyms => $synonym,
			traitClass => undef,
			traitDbId => qq|$cvterm_id|,
			traitDescription => $cvterm_definition,
			traitName => $cvterm_name,
			traitPUI => undef
		};
	}

	my %result = (data => \@data);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Traits list result constructed');
}

sub detail {
	my $self = shift;
	my $cvterm_id = shift;
	my $c = shift;
	my $page_size = $self->page_size;
	my $page = $self->page;
	my $status = $self->status;

	my $total_count = 0;
	my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
	if ($trait->name){
		$total_count = 1;
	}
	my $trait_id = $trait->cvterm_id;

	my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
		bcs_schema          => $self->bcs_schema,
		external_references => [],
		table_name          => "cvterm",
		table_id_key        => "cvterm_id",
		id                  => $cvterm_id
	});
	my $external_references_json= $external_references->search()->{$cvterm_id};
	if($c->config->{'brapi_include_CO_xref'}) {
		push @{ $external_references_json }, {
			referenceId => "http://www.cropontology.org/terms/".$trait->db.":".$trait->accession . "/",
			referenceSource => "Crop Ontology"
		};
	}

	my $documentation_links;
	if($trait->uri){
		push @$documentation_links, {
			"URL" => $trait->uri ? $trait->uri : undef,
			"type" => undef
		};
	}

	my %result = (
				additionalInfo => {},
		        alternativeAbbreviations => undef,
                attribute => undef,
				attributePUI => undef,
                entity => undef,
				entityPUI => undef,
                externalReferences => $external_references_json,
                mainAbbreviation => undef,
                ontologyReference => {
						documentationLinks => $documentation_links,
                        ontologyDbId => $trait->db_id ? $trait->db_id : undef,
                        ontologyName => $trait->db ? $trait->db : undef,
                        version => undef,
                    },
                status => $trait->active ? "active" : "archived",
                synonyms => $trait->synonyms,
                traitClass => undef,
                traitDescription => $trait->definition,
                traitDbId => qq|$trait_id|,
				traitName => $trait->name,
				traitPUI => undef
	);
	my @data_files;
	my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
	return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Trait detail result constructed');
}

1;
