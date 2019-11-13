package CXGN::BrAPI::v1::Variables;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Trait;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use SGN::Model::Cvterm;

extends 'CXGN::BrAPI::v1::Common';

sub search {
    my $self = shift;
    my $inputs = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my @trait_ids = $inputs->{observationVariableDbIds} ? @{$inputs->{observationVariableDbIds}} : ();
    my @db_names = $inputs->{ontology_db_names} ? @{$inputs->{ontology_db_names}} : ();
    my @db_ids = $inputs->{ontologyDbIds} ? @{$inputs->{ontologyDbIds}} : ();
    my @dbxref_terms = $inputs->{observationVariableXrefs} ? @{$inputs->{observationVariableXrefs}} : ();
    my @method_ids = $inputs->{methodDbIds} ? @{$inputs->{methodDbIds}} : ();
    my @scale_ids = $inputs->{scaleDbIds} ? @{$inputs->{scaleDbIds}} : ();
    my @scalexref_terms = $inputs->{scaleXrefs} ? @{$inputs->{scaleXrefs}} : ();
    my @cvterm_names = $inputs->{observationVariableNames} ? @{$inputs->{observationVariableNames}} : ();
    my @datatypes = $inputs->{datatypes} ? @{$inputs->{datatypes}} : ();
    my @classes = $inputs->{traitClasses} ? @{$inputs->{traitClasses}} : ();
    my @trait_dbids = $inputs->{traitDbIds} ? @{$inputs->{traitDbIds}} : ();
    my @traitxref_terms = $inputs->{traitXrefs} ? @{$inputs->{traitXrefs}} : ();
   
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
    if (scalar(@db_ids)>0){
        foreach (@db_ids){
            push @and_wheres, "db.db_id = '$_'";
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
            observationVariableName => $cvterm_name."|".$db_name.":".$accession,
            ontologyDbId => qq|$db_id|,
            ontologyName => $db_name,
            ontologyReference => undef,
            trait => {
                traitDbId => qq|$cvterm_id|,
                traitName => $cvterm_name,
                description => $cvterm_definition,
                class => undef,
                alternativeAbbreviations => undef,
                attribute => undef,
                entity => undef,
                mainAbbreviation => undef,
                ontologyReference => {},
                status => undef,
                synonyms => undef,
                xref => undef
            },
            method => {},
            scale => {
                scaleDbId =>undef,
                scaleName =>undef,
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
            defaultValue => $trait->default_value,
            contextOfUse => undef,
            crop => undef,
            date => undef,
            documentationURL => undef,
            growthStage => undef,
            institution  => undef,
            language => undef,
            scientist => undef,
            status => undef,
            submissionTimestamp => undef,
            synonyms => undef
        };
    }

    my %result = (data=>\@data);
    my @data_files;
    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count,$page_size,$page);
    return CXGN::BrAPI::JSONResponse->return_success(\%result, $pagination, \@data_files, $status, 'Observationvariable search result constructed');
}


1;
