package CXGN::BrAPI::v2::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
use Try::Tiny;
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
            levelName => 'rep',
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
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $inputs = shift;
    my $c = shift;
    my $status = $self->status;
    my @classes = $inputs->{traitClasses} ? @{$inputs->{traitClasses}} : ();
    my @cvterm_names = $inputs->{observationVariableNames} ? @{$inputs->{observationVariableNames}} : ();
    my @datatypes = $inputs->{datatypes} ? @{$inputs->{datatypes}} : ();
    my @db_ids = $inputs->{ontologyDbIds} ? @{$inputs->{ontologyDbIds}} : ();
    my @dbxref_ids = $inputs->{externalReferenceIds} ? @{$inputs->{externalReferenceIds}} : ();
    my @dbxref_terms = $inputs->{externalReferenceSources} ? @{$inputs->{externalReferenceSources}} : ();
    my @method_ids = $inputs->{methodDbIds} ? @{$inputs->{methodDbIds}} : ();
    my @scale_ids = $inputs->{scaleDbIds} ? @{$inputs->{scaleDbIds}} : ();
    my @study_ids = $inputs->{studyDbIds} ? @{$inputs->{studyDbIds}} : ();
    my @trait_dbids = $inputs->{traitDbIds} ? @{$inputs->{traitDbIds}} : ();
    my @trait_ids = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();

    if (scalar(@classes)>0 || scalar(@method_ids)>0 || scalar(@scale_ids)>0){
        push @$status, { 'error' => 'The following search parameters are not implemented yet: scaleDbId, traitClasses, methodDbId' };
        my %result;
        my @data_files;
        my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,$page_size,$page);
        return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
    }

    my $join = '';
    my @and_wheres;

    if (scalar(@trait_ids)>0){
        my $trait_ids_sql = join ',', @trait_ids;
        push @and_wheres, "cvterm.cvterm_id IN ($trait_ids_sql)";
    }
    if (scalar(@cvterm_names)>0){
        my @quotedNames;
        my $dbh = $self->bcs_schema->storage->dbh();
        for my $name (@cvterm_names) {push @quotedNames, $dbh->quote($name);}
        my $cvterm_names_sql = join ("," , @quotedNames);
        push @and_wheres, "cvterm.name IN ($cvterm_names_sql)";
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
        my @sub_and_wheres;
        my @dbxrefid_where;
        if (scalar(@dbxref_ids)>0){
            foreach (@dbxref_ids) {
                my ($db_name,$acc) = split(/:/, $_); 
                push @dbxrefid_where, "dbxref.accession = '$acc'";
                push @dbxrefid_where, "db.name = '$db_name'";
            }
        }
        if(scalar(@dbxrefid_where)>0) {
            my $dbxref_id_where_str = '('. (join ' AND ', @dbxrefid_where) . ')';
            push @sub_and_wheres, $dbxref_id_where_str;
        }

        my @dbxref_term_where;
        if (scalar(@dbxref_terms)>0) {
            foreach (@dbxref_terms) {
                push @dbxref_term_where, "db.name = '$_'";
                push @dbxref_term_where, "db.description = '$_'";
                push @dbxref_term_where, "db.url = '$_'";
            }
        }
        if(scalar(@dbxref_term_where)>0) {
            my $dbxref_term_where_str = '('. (join ' OR ', @dbxref_term_where) . ')';
            push @sub_and_wheres, $dbxref_term_where_str;
        }

        @and_wheres = @sub_and_wheres;
        # my $sub_and_where_clause = join ' AND ', @sub_and_wheres;

        # $join = "JOIN (" .
        #     "select cvterm_id, json_agg(json_build_object(" .
        #         "'referenceSource', references_query.reference_source, " .
        #         "'referenceID', references_query.reference_id " .
        #     ")) AS externalReferences " .
        #     "from " .
        #     "(" .
        #     "select cvterm.cvterm_id, db.name as reference_source, dbxref.accession as reference_id " .
        #     "FROM " .
        #     "cvterm " .
        #     "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) " .
        #     "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) " .
        #     "JOIN cvterm_dbxref on cvterm.cvterm_id = cvterm_dbxref.cvterm_id " .
        #     "JOIN dbxref on cvterm_dbxref.dbxref_id = dbxref.dbxref_id " .
        #     "JOIN db on dbxref.db_id = db.db_id " .
        #     "where $sub_and_where_clause " .
        #     ") as references_query " .
        #     "group by cvterm_id " .
        # ") as external_references on external_references.cvterm_id = cvterm.cvterm_id "
    }

    if (scalar(@datatypes)>0){
        $join = 'JOIN cvtermprop on (cvterm.cvterm_id=cvtermprop.cvterm_id)';
        foreach (@datatypes){
            push @and_wheres, "cvtermprop.value = '$_'";
        }
    }

    if (scalar(@study_ids)>0){
        my $trait_ids_sql;

        foreach my $study_id (@study_ids){
            my $study_check = $self->bcs_schema->resultset('Project::Project')->find({project_id=>$study_id});
            if ($study_check) {
                my $t = CXGN::Trial->new({ bcs_schema => $self->bcs_schema, trial_id => $study_id });
                my $traits_assayed = $t->get_traits_assayed();

                foreach (@$traits_assayed){
                    $trait_ids_sql .= ',' . $_->[0] ;
                }
            }
        }

        $trait_ids_sql =~ s/^,//g;
        if ($trait_ids_sql){
            push @and_wheres, "cvterm.cvterm_id IN ($trait_ids_sql)";
        } else {
            my @data_files;
            my $pagination = CXGN::BrAPI::Pagination->pagination_response(0,$page_size,$page);
            return CXGN::BrAPI::JSONResponse->return_success({data => []}, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
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

    if ($trait_id){
        $and_where = $and_where." cvterm.cvterm_id IN ($trait_id)";
    }

    $self->get_query($c, $and_where, $join, 0);

}

sub get_query {
    my $self = shift;
    my $c = shift;
    my $and_where = shift;
    my $join = shift;
    my $array = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;

    my @variables;
    my %result;
    my $limit = $page_size;
    my $offset = $page*$page_size;
    my $total_count = 0;

    my $additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'cvterm_additional_info', 'trait_property')->cvterm_id();

    #TODO: Can try a pivot to speed up this function so we retrieve all at once;
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, db.url, dbxref.dbxref_id, dbxref.accession, array_agg(cvtermsynonym.synonym ORDER BY CHAR_LENGTH(cvtermsynonym.synonym)) filter (where cvtermsynonym.synonym is not null), cvterm.is_obsolete, additional_info.value, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm ".
        "JOIN dbxref USING(dbxref_id) ".
        "JOIN db using(db_id) ".
        "LEFT JOIN cvtermsynonym using(cvterm_id) ". # left join to include non-synoynm variables, may break field book due to bug
        "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) ".
        "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) $join ".
        "LEFT JOIN cvtermprop as additional_info on (cvterm.cvterm_id = additional_info.cvterm_id and additional_info.type_id = $additional_info_type_id) ".
        "WHERE $and_where " .
        "GROUP BY cvterm.cvterm_id, db.name, db.db_id, dbxref.dbxref_id, dbxref.accession, additional_info.value ".
        "ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset; "  ;


    my $sth = $self->bcs_schema->storage->dbh->prepare($q);
    $sth->execute();
    while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $db_url, $dbxref_id, $accession, $synonym, $obsolete, $additional_info_string, $count) = $sth->fetchrow_array()) {
        $total_count = $count;
        foreach (@$synonym){
            $_ =~ s/ EXACT \[\]//;
            $_ =~ s/\"//g;
        }

        # Get the external references
        my @references_cvterms = ($cvterm_id);
        my $references = CXGN::BrAPI::v2::ExternalReferences->new({
            bcs_schema => $self->bcs_schema,
            table_name => 'cvterm',
            table_id_key => 'cvterm_id',
            id => \@references_cvterms
        });

        my $additional_info;
        if (defined $additional_info_string) {
            $additional_info = decode_json $additional_info_string;
        }
        #TODO: This is running many queries each time, can make one big query above if need be
        # Retrieve the trait, which retrieves its scales and methods
        my $trait = CXGN::Trait->new({
            bcs_schema          => $self->bcs_schema,
            cvterm_id           => $cvterm_id,
            dbxref_id           => $dbxref_id,
            db_id               => $db_id,
            db                  => $db_name,
            accession           => $accession,
            name                => $cvterm_name,
            external_references => $references,
            additional_info     => $additional_info,
            synonyms            => $synonym
        });

        push @variables, $self->_construct_variable_response($c, $trait);
    }

    my $pagination;
    my %result;
    my @data_files;

    if ($array) {
        %result = (data => \@variables);
        $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
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
    my $c = shift;

    my $page_size = $self->page_size;
    my $page = $self->page;
    my $schema = $self->bcs_schema();

    my @variable_ids;

    my @result;

    my $coderef = sub {
        foreach my $params (@{$data}) {
            my $cvterm_id = $params->{observationVariableDbId} || undef;
            my $name = $params->{observationVariableName};
            my $ontology_id = $params->{ontologyReference}{ontologyDbId};
            my $description = $params->{trait}{traitDescription};
            my $entity = $params->{trait}{entity};
            my $attribute = $params->{trait}{attribute};
            my $synonyms = $params->{synonyms};
            my $active = $params->{status} ne "archived";
            my $additional_info = $params->{additionalInfo} || undef;

            #TODO: Parse this when it initially comes into the brapi controller
            my $scale = CXGN::BrAPI::v2::Scales->new({
                bcs_schema => $self->bcs_schema,
                scale      => $params->{scale}
            });
            my $method = CXGN::BrAPI::v2::Methods->new({
                bcs_schema => $self->bcs_schema,
                method     => $params->{method}
            });
            my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
                bcs_schema          => $self->bcs_schema,
                external_references => $params->{externalReferences} || [],
                table_name          => "cvterm",
                table_id_key        => "cvterm_id",
                id                  => $cvterm_id
            });
            my $trait = CXGN::Trait->new({ bcs_schema => $self->bcs_schema,
                cvterm_id                             => $cvterm_id,
                name                                  => $name,
                ontology_id                           => $ontology_id,
                definition                            => $description,
                entity                                => $entity,
                attribute                             => $attribute,
                synonyms                              => $synonyms,
                external_references                   => $external_references,
                method                                => $method,
                scale                                 => $scale,
                additional_info                       => $additional_info
            });
            $trait->{active} = $active;

            my $variable = $trait->store();
            push @result, $self->_construct_variable_response($c, $variable);
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        throw $_;
    };

    my $count = scalar @variable_ids;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($count,$page_size,$page);
    my %data_result = (data => \@result);
    return CXGN::BrAPI::JSONResponse->return_success( \%data_result, $pagination, undef, $self->status(), $count . " Variables were saved.");
}

sub update {

    my $self = shift;
    my $data = shift;
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
    my $entity = $data->{trait}{entity};
    my $attribute = $data->{trait}{attribute};
    my $synonyms = $data->{synonyms};
    my $active = $data->{status} ne "archived";
    my $additional_info = $data->{additionalInfo} || undef;

    my $scale = CXGN::BrAPI::v2::Scales->new({
        bcs_schema => $self->bcs_schema,
        scale => $data->{scale}
    });
    my $method = CXGN::BrAPI::v2::Methods->new({
        bcs_schema => $self->bcs_schema,
        method => $data->{method}
    });
    my $external_references = CXGN::BrAPI::v2::ExternalReferences->new({
        bcs_schema          => $self->bcs_schema,
        external_references => $data->{externalReferences} || [],
        table_name          => "cvterm",
        table_id_key        => "cvterm_id",
        id                  => $cvterm_id
    });
    my $trait = CXGN::Trait->new({ bcs_schema => $self->bcs_schema,
        cvterm_id                             => $cvterm_id,
        name                                  => $name,
        ontology_id                           => $ontology_id,
        definition                            => $description,
        entity                                => $entity,
        attribute                             => $attribute,
        synonyms                              => $synonyms,
        external_references                   => $external_references,
        method                                => $method,
        scale                                 => $scale,
        additional_info                      => $additional_info
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
    if (defined($variable->external_references)) {
        $external_references_json = $variable->external_references->search()->{$variable->cvterm_id};

        if($c->config->{'brapi_include_CO_xref'}) {
            push @{ $external_references_json }, {
                #referenceId => "http://www.cropontology.org/terms/".$variable->db.":".$variable->accession . "/",
                referenceId => $variable->db.":".$variable->accession,
                referenceSource => "Crop Ontology"
            };
        }
    }
    my $method_json;
    if (defined($variable->method)) { $method_json = $variable->method->method_db();}
    my $scale_json;
    if (defined($variable->scale)) { $scale_json = $variable->scale->scale_db();}
    my @synonyms = $variable->synonyms;
    my $variable_id = $variable->cvterm_id;
    my $variable_db_id = $variable->db_id ;

    my $documentation_links;
    if($variable->uri){
        push @$documentation_links, {
            "URL" => $variable->uri, 
            "type" => "OBO"
        };
    }

    return {
        additionalInfo => $variable->additional_info || {},
        commonCropName => $c->config->{'supportedCrop'},
        contextOfUse => undef,
        defaultValue => $variable->default_value,
        documentationURL => $variable->uri,
        externalReferences => $external_references_json,
        growthStage => undef,
        institution  => undef,
        language => 'eng',
        method => $method_json,
        observationVariableDbId => qq|$variable_id|,
        observationVariableName => $variable->name."|".$variable->db.":".$variable->accession,
        observationVariablePUI => $variable->db.":".$variable->accession,
        ontologyReference => {
            documentationLinks => $documentation_links,
            ontologyDbId => $variable->db_id ? qq|$variable_db_id| : undef,
            ontologyName => $variable->db ? $variable->db : undef,
            version => undef,
        },
        scale => $scale_json,
        scientist => undef,
        status => $variable->get_active_string(),
        submissionTimestamp => undef,
        synonyms => @synonyms,
        trait => {
            additionalInfo => {},
            alternativeAbbreviations => undef,
            attribute => $variable->attribute ? $variable->attribute : undef,
            attributePUI=> undef,
            entity => $variable->entity ? $variable->entity : undef,
            entityPUI=> undef,
            externalReferences => $external_references_json,
            mainAbbreviation => undef,
            ontologyReference => {
                documentationLinks => $documentation_links,
                ontologyDbId => $variable->db_id ? qq|$variable_db_id| : undef,
                ontologyName => $variable->db ? $variable->db : undef,
                version => undef,
            },
            status => $variable->get_active_string(),
            synonyms => @synonyms,
            traitClass => undef,
            traitDescription => $variable->definition,
            traitDbId => qq|$variable_id|,
            traitName => $variable->name,
            traitPUI => undef,
        }
    }
}

1;
