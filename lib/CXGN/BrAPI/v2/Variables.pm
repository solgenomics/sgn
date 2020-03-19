package CXGN::BrAPI::v2::ObservationVariables;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $supported_crop = $inputs->{supportedCrop};
    my @classes = $inputs->{traitClasses} ? @{$inputs->{traitClasses}} : ();
    my @cvterm_names = $inputs->{observationVariableNames} ? @{$inputs->{observationVariableNames}} : ();
    my @datatypes = $inputs->{datatypes} ? @{$inputs->{datatypes}} : ();
    my @db_ids = $inputs->{ontologyDbIds} ? @{$inputs->{ontologyDbIds}} : ();
    my @dbxref_ids = $inputs->{externalReferenceIDs} ? @{$inputs->{externalReferenceIDs}} : ();
    my @dbxref_terms = $inputs->{externalReferenceSources} ? @{$inputs->{externalReferenceSources}} : ();
    my @method_ids = $inputs->{methodDbIds} ? @{$inputs->{methodDbIds}} : ();
    my @scale_ids = $inputs->{scaleDbIds} ? @{$inputs->{scaleDbIds}} : ();
    my @study_ids = $inputs->{studyDbId} ? @{$inputs->{studyDbId}} : ();
    my @trait_dbids = $inputs->{traitDbIds} ? @{$inputs->{traitDbIds}} : ();
    my @trait_ids = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();

    if (scalar(@classes)>0 || scalar(@method_ids)>0 || scalar(@scale_ids)>0 || scalar(@study_ids)>0){
        push @$status, { 'error' => 'The following parameters are not implemented: scaleDbId, studyDbId, traitClasses, methodDbId' };
    }
   
    my $join = '';
    my @and_wheres;
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
    if (scalar(@dbxref_ids)>0){
        my @db_names;
        my @dbxref_accessions;
        foreach (@dbxref_ids){
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
    if (scalar(@dbxref_terms)>0){
        my @db_names;
        foreach (@dbxref_terms){
            my ($db_name, $accession) = split ':', $_;
            push @db_names, $db_name;
        }
        foreach (@db_names){
            push @and_wheres, "db.name = '$_'";
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
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, db.url, dbxref.accession, cvtermsynonym.synonym, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm ". 
        "JOIN dbxref USING(dbxref_id) ".
        "JOIN db using(db_id) ".
        "JOIN cvtermsynonym using(cvterm_id) ".
        "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) ".
        "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) $join ".
        "WHERE $and_where_clause ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset;";

    my $sth = $self->bcs_schema->storage->dbh->prepare($q);
    $sth->execute();
    while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $db_url, $accession, $synonym, $count) = $sth->fetchrow_array()) {
        $total_count = $count;
        my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
        my $categories = $trait->categories;
        my @brapi_categories = split '/', $categories;
        push @data, {
            additionalInfo => undef,
            commonCropName => $supported_crop,
            contextOfUse => undef,
            defaultValue => $trait->default_value,
            documentationURL => undef,
            externalReferences => $db_name.":".$accession,
            growthStage => undef,
            institution  => undef,
            language => 'eng',
            method => {
                # additionalInfo
                # bibliographicalReference
                # description
                # externalReferences
                # formula
                # methodClass
                # methodDbId
                # methodName
                # ontologyReference => {
                #         documentationLinks
                #         ontologyDbId
                #         ontologyName
                #         version
                #     }
                },
            observationVariableDbId => qq|$cvterm_id|,
            observationVariableName => $cvterm_name."|".$db_name.":".$accession,
            ontologyReference => {
                documentationLinks => $db_url,
                ontologyDbId => qq|$db_id|,
                ontologyName => $db_name,
                version => undef,
            },
            scale => {
                datatype => $trait->format,
                decimalPlaces => undef,
                externalReferences => '',
                ontologyReference => {
                #         documentationLinks
                #         ontologyDbId
                #         ontologyName
                #         version
                },
                scaleDbId => undef,
                scaleName => undef,
                validValues => {
                    min =>$trait->minimum ? $trait->minimum : undef,
                    max =>$trait->maximum ? $trait->maximum : undef,
                    categories => \@brapi_categories,
                },

            },
            scientist => undef,
            status => undef,
            submissionTimestamp => undef,
            synonyms => $synonym,
            trait => {
                alternativeAbbreviations => undef,
                attribute => undef,
                entity => undef,
                externalReferences => undef,
                mainAbbreviation => undef,
                ontologyReference => {
                        documentationLinks => $trait->uri ? $trait->uri : undef,
                        ontologyDbId => $trait->db_id ? $trait->db_id : undef,
                        ontologyName => $trait->db ? $trait->db : undef,
                        version => undef,
                    },
                status => undef,
                synonyms => undef,
                traitClass => undef,
                traitDescription => $cvterm_definition,
                traitDbId => qq|$cvterm_id|,
                traitName => $cvterm_name,
            },
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
    my $c = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $supported_crop = $c->config->{'supportedCrop'};
   
    my $join = '';
    my $and_where;
    if ($trait_id){
        $and_where = "cvterm.cvterm_id IN ($trait_id)";
    }

    my @data;
    my $limit = $page_size;
    my $offset = $page*$page_size;
    my $total_count = 0;
    my $q = "SELECT cvterm.cvterm_id, cvterm.name, cvterm.definition, db.name, db.db_id, db.url, dbxref.accession, cvtermsynonym.synonym, count(cvterm.cvterm_id) OVER() AS full_count FROM cvterm ". 
        "JOIN dbxref USING(dbxref_id) ".
        "JOIN db using(db_id) ".
        "JOIN cvtermsynonym using(cvterm_id) ".
        "JOIN cvterm_relationship as rel on (rel.subject_id=cvterm.cvterm_id) ".
        "JOIN cvterm as reltype on (rel.type_id=reltype.cvterm_id) $join ".
        "WHERE $and_where ORDER BY cvterm.name ASC LIMIT $limit OFFSET $offset;";

    my $sth = $self->bcs_schema->storage->dbh->prepare($q);
    $sth->execute();
    while (my ($cvterm_id, $cvterm_name, $cvterm_definition, $db_name, $db_id, $db_url, $accession, $synonym, $count) = $sth->fetchrow_array()) {
        $total_count = $count;
        my $trait = CXGN::Trait->new({bcs_schema=>$self->bcs_schema, cvterm_id=>$cvterm_id});
        my $categories = $trait->categories;
        my @brapi_categories = split '/', $categories;
        push @data, {
            additionalInfo => undef,
            commonCropName => $supported_crop,
            contextOfUse => undef,
            defaultValue => $trait->default_value,
            documentationURL => undef,
            externalReferences => $db_name.":".$accession,
            growthStage => undef,
            institution  => undef,
            language => 'eng',
            method => {
                # additionalInfo
                # bibliographicalReference
                # description
                # externalReferences
                # formula
                # methodClass
                # methodDbId
                # methodName
                # ontologyReference => {
                #         documentationLinks
                #         ontologyDbId
                #         ontologyName
                #         version
                #     }
                },
            observationVariableDbId => qq|$cvterm_id|,
            observationVariableName => $cvterm_name."|".$db_name.":".$accession,
            ontologyReference => {
                documentationLinks => $db_url,
                ontologyDbId => qq|$db_id|,
                ontologyName => $db_name,
                version => undef,
            },
            scale => {
                datatype => $trait->format,
                decimalPlaces => undef,
                externalReferences => '',
                ontologyReference => {
                #         documentationLinks
                #         ontologyDbId
                #         ontologyName
                #         version
                },
                scaleDbId => undef,
                scaleName => undef,
                validValues => {
                    min =>$trait->minimum ? $trait->minimum : undef,
                    max =>$trait->maximum ? $trait->maximum : undef,
                    categories => \@brapi_categories,
                },

            },
            scientist => undef,
            status => undef,
            submissionTimestamp => undef,
            synonyms => $synonym,
            trait => {
                alternativeAbbreviations => undef,
                attribute => undef,
                entity => undef,
                externalReferences => undef,
                mainAbbreviation => undef,
                ontologyReference => {
                        documentationLinks => $trait->uri ? $trait->uri : undef,
                        ontologyDbId => $trait->db_id ? $trait->db_id : undef,
                        ontologyName => $trait->db ? $trait->db : undef,
                        version => undef,
                    },
                status => undef,
                synonyms => undef,
                traitClass => undef,
                traitDescription => $cvterm_definition,
                traitDbId => qq|$cvterm_id|,
                traitName => $cvterm_name,
            },
        };
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
}

1;
