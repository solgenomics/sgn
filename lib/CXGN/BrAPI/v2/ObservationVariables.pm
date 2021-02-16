package CXGN::BrAPI::v2::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;
use CXGN::BrAPI::v2::ExternalReferences;
use CXGN::BrAPI::v2::Methods;
use CXGN::BrAPI::v2::Scales;
use CXGN::BrAPI::Exceptions::NotFoundException;

extends 'CXGN::BrAPI::v2::Common';

has 'trait_ontology_cv_id' => (
    isa => 'Int',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $context = SGN::Context->new;
        my $cv_name = $context->get_conf('trait_ontology_cv_name');
        # get cv_id for external references
        my $cv_id = $self->bcs_schema->resultset("Cv::Cv")->find(
            {
                name => $cv_name
            },
            { key => 'cv_c1' }
        )->get_column('cv_id');
        return $cv_id;
    }
);

sub observation_levels {
    my $self = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my @data_window;
    push @data_window, ({
            levelName => 'replicate',
            levelOrder => 0 }, 
        {
            levelName => 'block',
            levelOrder => 1 },
        {
            levelName => 'plot',
            levelOrder => 2 },
        {
            levelName => 'subplot',
            levelOrder => 3 },
        {
            levelName => 'plant',
            levelOrder => 4 },
        {
            levelName => 'tissue_sample',
            levelOrder => 5 
         });

    my $total_count = 6;

    my @data_files;
    my %result = (data=>\@data_window);
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$total_count,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observation Levels result constructed');   
}

sub search {
    my $self = shift;
    my $inputs = shift;
    my $c = shift;
    my $status = $self->status;
    my @classes = $inputs->{traitClasses} ? @{$inputs->{traitClasses}} : ();
    my @cvterm_names = $inputs->{observationVariableNames} ? @{$inputs->{observationVariableNames}} : ();
    my @datatypes = $inputs->{datatypes} ? @{$inputs->{datatypes}} : ();
    my @db_ids = $inputs->{ontologyDbIds} ? @{$inputs->{ontologyDbIds}} : ();
    my @dbxref_ids = $inputs->{externalReferenceIDs} ? @{$inputs->{externalReferenceIDs}} : ();
    my @dbxref_terms = $inputs->{externalReferenceSources} ? @{$inputs->{externalReferenceSources}} : ();
    my @method_ids = $inputs->{methodDbIds} ? @{$inputs->{methodDbIds}} : ();
    my @scale_ids = $inputs->{scaleDbIds} ? @{$inputs->{scaleDbIds}} : ();
    my @study_ids = $inputs->{studyDbId} ? @{$inputs->{studyDbIds}} : ();
    my @trait_dbids = $inputs->{traitDbIds} ? @{$inputs->{traitDbIds}} : ();
    my @trait_ids = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();

    if (scalar(@classes)>0 || scalar(@method_ids)>0 || scalar(@scale_ids)>0 || scalar(@study_ids)>0){
        push @$status, { 'error' => 'The following parameters are not implemented: scaleDbId, studyDbId, traitClasses, methodDbId' };
    }
   
    my $join = '';
    my @and_wheres;

    # only get cvterms for the cv for the configured trait ontology
    push @and_wheres, "cvterm.cv_id=".$self->trait_ontology_cv_id;


    if (scalar(@trait_ids)>0){
        my $trait_ids_sql = join ',', @trait_ids;
        push @and_wheres, "cvterm.cvterm_id IN ($trait_ids_sql)";
    }
    if (scalar(@trait_dbids)>0){
        my $trait_ids_sql = join ',', @trait_dbids;
        push @and_wheres, "cvterm.cvterm_id IN ($trait_ids_sql)";
    }
    if (scalar(@db_ids)>0){
        foreach (@db_ids){
            push @and_wheres, "db.db_id = '$_'";
        }
    }

    # External reference id and reference source search
    if (scalar(@dbxref_ids) > 0 || scalar(@dbxref_terms)>0) {
        my $cv_id = $self->trait_ontology_cv_id;

        my @sub_and_wheres;
        push @sub_and_wheres, "cvterm.cv_id = $cv_id";
        push @sub_and_wheres, "reltype.name='VARIABLE_OF'";
        if (scalar(@dbxref_ids)>0){
            # TODO: Should this be OR?
            foreach (@dbxref_ids) {
                push @sub_and_wheres, "reference_id_prop.value = '$_'";
            }
        }
        if (scalar(@dbxref_terms)>0) {
            foreach (@dbxref_terms) {
                push @sub_and_wheres, "reference_source_prop.value = '$_'";
            }
        }

        my $sub_and_where_clause = join ' AND ', @sub_and_wheres;

        $join = "JOIN (" .
            "select cvterm_id, json_agg(json_build_object(" .
                "'referenceSource', references_query.reference_source, " .
                "'referenceID', references_query.reference_id " .
            ")) AS externalReferences " .
            "from " .
            "(" .
            "select cvterm.cvterm_id, reference_source_prop.value as reference_source, reference_id_prop.value as reference_id " .
            "FROM " .
            "cvterm " .
            "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) " .
            "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) " .
            "JOIN dbxrefprop reference_source_prop ON cvterm.dbxref_id = reference_source_prop.dbxref_id " .
            "JOIN cvterm reference_source_term " .
                "ON reference_source_term.cvterm_id = reference_source_prop.type_id and reference_source_term.name = 'reference_source' " .
            "JOIN dbxrefprop reference_id_prop " .
            "ON cvterm.dbxref_id = reference_id_prop.dbxref_id and reference_id_prop.rank = reference_source_prop.rank " .
            "JOIN cvterm reference_id_term " .
                "ON reference_id_term.cvterm_id = reference_id_prop.type_id and reference_id_term.name = 'reference_id' " .
            "where $sub_and_where_clause " .
            ") as references_query " .
            "group by cvterm_id " .
        ") as external_references on external_references.cvterm_id = cvterm.cvterm_id "
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

    $self->get_query($c, $and_where_clause, $join, 1);

}

sub detail {
    my $self = shift;
    my $trait_id = shift;
    my $c = shift;

    my $join = '';
    my $and_where;

    # only get cvterms for the cv for the configured trait ontology
    $and_where = "cvterm.cv_id=".$self->trait_ontology_cv_id;

    if ($trait_id){
        $and_where = $and_where." AND cvterm.cvterm_id IN ($trait_id)";
    }

    $self->get_query($c, $and_where, $join, 0);

}

sub get_query {
    my $self = shift;
    my $c = shift;
    my $and_where = shift;
    my $join = shift;
    my $array = shift;
    #my $page_size = $self->page_size;
    my $page_size = 1000; # ignore page size for now
    my $page = $self->page;
    my $status = $self->status;

    my @variables;
    my %result;
    my $limit = $page_size;
    my $offset = $page*$page_size;
    my $total_count = 0;
    #TODO: Can try a pivot to speed up this function so we retrieve all at once;
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, db.url, dbxref.dbxref_id, dbxref.accession, array_agg(cvtermsynonym.synonym) filter (where cvtermsynonym.synonym is not null), cvterm.is_obsolete, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm ".
        "JOIN dbxref USING(dbxref_id) ".
        "JOIN db using(db_id) ".
        "LEFT JOIN cvtermsynonym using(cvterm_id) ". # left join to include non-synoynm variables, may break field book due to bug
        "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) ".
        "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) $join ".
        "WHERE $and_where " .
        "GROUP BY cvterm.cvterm_id, db.name, db.db_id, dbxref.dbxref_id, dbxref.accession ".
        "ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset; "  ;

    my $sth = $self->bcs_schema->storage->dbh->prepare($q);
    $sth->execute();
    while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $db_url, $dbxref_id, $accession, $synonym, $obsolete, $count) = $sth->fetchrow_array()) {
        $total_count = $count;

        #TODO: This is running many queries each time, can make one big query above if need be
        # Retrieve the trait, which retrieves its scales and methods
        my $trait = CXGN::Trait->new({
            bcs_schema => $self->bcs_schema,
            cvterm_id  => $cvterm_id,
            dbxref_id  => $dbxref_id,
            db_id      => $db_id,
            db         => $db_name,
            accession  => $accession
        });

        push @variables, $self->_construct_variable_response($c, $trait);
    }

    my $pagination;
    my %result;
    my @data_files;

    if ($array) {
        my $data_window;
        ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@variables, $page_size, $page);
        %result = (data => $data_window);
        return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
    } else {
        $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
        return CXGN::BrAPI::JSONResponse->return_success(@variables[0], $pagination, \@data_files, $status, 'Observationvariable search result constructed');
    }

}

# TODO: Make validation errors better
sub store {

    my $self = shift;
    my $data = shift;
    my $user_id = shift;
    my $c = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $schema = $self->bcs_schema();

    my @variable_ids;

    my @result;

    foreach my $params (@{$data}) {
        my $cvterm_id = $params->{observationVariableDbId} || undef;
        my $name = $params->{observationVariableName};
        my $ontology_id = $params->{ontologyReference}{ontologyDbId};
        my $description = $params->{trait}{traitDescription};
        my $synonyms = $params->{synonyms};
        my $active = $params->{status} ne "archived";

        #TODO: Parse this when it initially comes into the brapi controller
        my $scale = CXGN::BrAPI::v2::Scales->new({
            bcs_schema => $self->bcs_schema,
            scale => $params->{scale}
        });
        my $method = CXGN::BrAPI::v2::Methods->new({
            bcs_schema => $self->bcs_schema,
            method => $params->{method}
        });
        my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
            bcs_schema => $self->bcs_schema,
            external_references => $params->{externalReferences} || [],
            table_name => "Cv::Dbxrefprop",
            base_id_key => "dbxref_id"
        });
        my $trait = CXGN::Trait->new({ bcs_schema => $self->bcs_schema,
            cvterm_id                             => $cvterm_id,
            name                                  => $name,
            ontology_id                           => $ontology_id,
            definition                            => $description,
            synonyms                              => $synonyms,
            external_references                   => $external_references,
            method                                => $method,
            scale                                 => $scale
        });
        $trait->{active} = $active;

        my $variable = $trait->store();
        push @result, $self->_construct_variable_response($c, $variable);
    }

    my $count = scalar @variable_ids;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    my %data_result = (data => \@result);
    return CXGN::BrAPI::JSONResponse->return_success( \%data_result, $pagination, undef, $self->status(), $count . " Variables were saved.");
}

sub update {

    my $self = shift;
    my $data = shift;
    my $user_id = shift;
    my $c = shift;

    my $schema = $self->bcs_schema();

    # Check that cvterm that was passed in exists
    #TODO: This can go away once trait parsed in controller
    if ($data->{observationVariableDbId}){
        my ($existing_cvterm) = $schema->resultset("Cv::Cvterm")->find({ cvterm_id => $data->{observationVariableDbId} });
        if (!defined($existing_cvterm)) {
            warn "An observationVariableId is required for variable update.";
            CXGN::BrAPI::Exceptions::NotFoundException->throw({message => 'observationVariableId not specified.'});
        }
    }

    #TODO: Add a check for these required values
    my $cvterm_id = $data->{observationVariableDbId} || undef;
    my $name = $data->{observationVariableName};
    my $ontology_id = $data->{ontologyReference}{ontologyDbId};
    my $description = $data->{trait}{traitDescription};
    my $synonyms = $data->{synonyms};
    my $active = $data->{status} ne "archived";

    my $scale = CXGN::BrAPI::v2::Scales->new({
        bcs_schema => $self->bcs_schema,
        scale => $data->{scale}
    });
    my $method = CXGN::BrAPI::v2::Methods->new({
        bcs_schema => $self->bcs_schema,
        method => $data->{method}
    });
    my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
        bcs_schema => $self->bcs_schema,
        external_references => $data->{externalReferences} || [],
        table_name => "Cv::Dbxrefprop",
        base_id_key => "dbxref_id"
    });
    my $trait = CXGN::Trait->new({ bcs_schema => $self->bcs_schema,
        cvterm_id                             => $cvterm_id,
        name                                  => $name,
        ontology_id                           => $ontology_id,
        definition                            => $description,
        synonyms                              => $synonyms,
        external_references                   => $external_references,
        method                                => $method,
        scale                                 => $scale
    });
    $trait->{active} = $active;

    my $variable = $trait->update();
    my $pagination = CXGN::BrAPI::Pagination->pagination_response(1,1,1);
    my $response = $self->_construct_variable_response($c, $variable);
    return CXGN::BrAPI::JSONResponse->return_success($response, $pagination, undef, $self->status(), "Variable was updated.");
}

sub observation_variable_ontologies {
    my $self = shift;
    my $inputs = shift;
    my $name_spaces = $inputs->{name_spaces};
    my $ontology_id = $inputs->{ontologyDbId};
    my $cvprop_types = $inputs->{cvprop_type_names} || [];
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @available;

    my @composable_cv_prop_types;
    foreach (@$cvprop_types) {
        my $composable_cv_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, $_, 'composable_cvtypes')->cvterm_id();
        push @composable_cv_prop_types, $composable_cv_type_cvterm_id;
    }
    my $composable_cv_prop_sql  = "";
    if (scalar(@composable_cv_prop_types)>0) {
        $composable_cv_prop_sql = join ("," , @composable_cv_prop_types);
        $composable_cv_prop_sql = " AND cvprop.type_id IN ($composable_cv_prop_sql)";
    }

    #Using code pattern from SGN::Controller::AJAX::Onto->roots_GET
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, dbxref.accession, dbxref.version, dbxref.description, cv.cv_id, cv.name, cv.definition FROM cvterm JOIN dbxref USING(dbxref_id) JOIN db USING(db_id) JOIN cv USING(cv_id) JOIN cvprop USING(cv_id) LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id=cvterm_relationship.subject_id) WHERE cvterm_relationship.subject_id IS NULL AND is_obsolete= 0 AND is_relationshiptype = 0 and db.name=? $composable_cv_prop_sql;";
    my $sth = $self->bcs_schema->storage->dbh->prepare($q);
    foreach (@$name_spaces){
        $sth->execute($_);
        while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $dbxref_accession, $dbxref_version, $dbxref_description, $cv_id, $cv_name, $cv_definition) = $sth->fetchrow_array()) {
            if ( $ontology_id &&  $ontology_id ne $db_id) { next; }
            my $info;
            if($dbxref_description){
                $info = decode_json($dbxref_description);
            }
            push @available, {
                additionalInfo=>{},
                ontologyDbId=>qq|$db_id|,
                ontologyName=>$db_name,
                description=>$cvterm_name,
                authors=>$info->{authors} ? $info->{authors} : '',
                version=>$dbxref_version,
                copyright=>$info->{copyright} ? $info->{copyright} : '',
                licence=>$info->{licence} ? $info->{licence} : '',
                documentationURL=>$dbxref_accession,
            };
        }
    }

    my ($data_window, $pagination) = CXGN::BrAPI::Pagination->paginate_array(\@available,$page_size,$page);
    my %result = (data=>$data_window);
    my @data_files;
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Ontologies result constructed');
}

sub _construct_variable_response {
    my $self = shift;
    my $c = shift;
    my $variable = shift;

    my $external_references_json;
    if (defined($variable->external_references)) { $external_references_json = $variable->external_references->references_db();}
    my $method_json;
    if (defined($variable->method)) { $method_json = $variable->method->method_db();}
    my $scale_json;
    if (defined($variable->scale)) { $scale_json = $variable->scale->scale_db();}
    my @synonyms = $variable->synonyms;

    return {
        additionalInfo => undef,
        commonCropName => $c->config->{'supportedCrop'},
        contextOfUse => undef,
        defaultValue => $variable->default_value,
        documentationURL => $variable->uri,
        externalReferences => $external_references_json,
        growthStage => undef,
        institution  => undef,
        language => 'eng',
        method => $method_json,
        observationVariableDbId => $variable->cvterm_id,
        observationVariableName => $variable->name,
        ontologyReference => {
            documentationLinks => $variable->uri ? $variable->uri : undef,
            ontologyDbId => $variable->db_id ? $variable->db_id : undef,
            ontologyName => $variable->db ? $variable->db : undef,
            version => undef,
        },
        scale => $scale_json,
        scientist => undef,
        status => $variable->get_active_string(),
        submissionTimestamp => undef,
        synonyms => @synonyms,
        trait => {
            alternativeAbbreviations => undef,
            attribute => undef,
            entity => undef,
            externalReferences => $external_references_json,
            mainAbbreviation => undef,
            ontologyReference => {
                documentationLinks => $variable->uri ? $variable->uri : undef,
                ontologyDbId => $variable->db_id ? $variable->db_id : undef,
                ontologyName => $variable->db ? $variable->db : undef,
                version => undef,
            },
            status => $variable->get_active_string(),
            synonyms => @synonyms,
            traitClass => undef,
            traitDescription => $variable->definition,
            traitDbId => $variable->cvterm_id,
            traitName => $variable->name,
        }
    }
}

1;
