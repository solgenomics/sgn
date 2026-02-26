package CXGN::Stock::SearchVector;

=head1 NAME

CXGN::Stock::SearchVector - an object to handle searching for stocks (accessions,plots,plants,etc) given criteria

=head1 USAGE

my $stock_search = CXGN::Stock::SearchVector->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    phenome_schema=>$phenome_schema,
    match_type=>$match_type,
    match_name=>$match_name,
    uniquename_list=>\@uniquename_list,
    genus_list=>\@genus_list,
    species_list=>\@species_list,
    crop_name_list=>\@crop_name_list,
    stock_id_list=>\@stock_id_list,
    organism_id=>$organism_id,
    stock_type_id=>$stock_type_id,
    stock_type_name=>$stock_type_name,
    owner_first_name=>$owner_first_name,
    owner_last_name=>$owner_last_name,
    trait_cvterm_name_list=>\@trait_cvterm_name_list,
    trial_id_list=>\@trial_id_list,
    trial_name_list=>\@trial_name_list,
    breeding_program_id_list=>\@breeding_program_id_list,
    location_name_list=>\@location_name_list,
    year_list=>\@year_list,
    stockprops_values=>\%stockprops_values,
    stockprop_columns_view=>\%stockprop_columns_view,
    limit=>$limit,
    offset=>$offset,
    minimal_info=>o  #for only returning stock_id and uniquenames
    display_pedigree=>1 #to calculate and display pedigree
});
my ($result, $records_total) = $stock_search->search();

--------------------------

To search for stocks with combinations of stockprops, use "stockprops_values".
stockprops_values is a HashRef of ArrayRef of the form for example:
{
    'country of origin' => ['Uganda', 'Nigeria'],
    'ploidy_level' => ['2'],
    'introgression_start_position_bp' => ['10002'],
    'introgression_chromosome' => ['2']
}
The keys must come from system_cvterms.txt in the cv for "stock_property".
The query will do an AND between keys and an OR between comma separated values for the same key.

--------------------------

To return stockprop values in your result, use "stockprop_columns_view".
stockprop_columns_view is a HashRef of the form for example:
{
    'country of orogin' => 1,
    'ploidy_level' => 1
}
This example would include these keys in each resulting hashref for each stock that is returned.
The keys must come from system_cvterms.txt in the cv for "stock_property".
If there is no value for the stockprop for the stock, then the result will still show the key, but will have '' as the value.


=head1 DESCRIPTION


=head1 AUTHORS

 With code adapted from SGN::Controller::AJAX::Search::Stock

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Chado::Stock;
use CXGN::Chado::Organism;
use JSON;
use utf8;
use Encode;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'people_schema' => ( isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
);

has 'phenome_schema' => ( isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
);

#can be 'exactly, starts_with, ends_with, contains'
has 'match_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'match_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'operator' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'uniquename_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'genus_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'species_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'crop_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'stock_id_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'organism_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'stock_type_id' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'stock_type_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'owner_first_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'owner_last_name' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'trait_cvterm_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'trial_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'breeding_program_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'stockprops_values' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'stockprop_columns_view' => (
    isa => 'HashRef|Undef',
    is => 'rw',
);

has 'search_vectorprop' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'include_obsolete' => (
    isa => 'Bool',
    is => 'rw',
    default => 0
);

has 'minimal_info' => (
    isa => 'Bool',
    is => 'rw',
	default => 0
);

has 'display_pedigree' => (
    isa => 'Bool',
    is => 'rw',
	default => 0
);

has 'stockprops' => (
    isa => 'ArrayRef',
    is => 'rw',
);

sub search {
    my $self = shift;
    print STDERR "CXGN::Stock::SearchVector search start\n";
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
    my $phenome_schema = $self->phenome_schema;
    my $matchtype = $self->match_type || 'contains';
    my $any_name = $self->match_name;
    my $default_operator = $self->operator;
    my $organism_id = $self->organism_id;
    my $owner_first_name = $self->owner_first_name;
    my $owner_last_name = $self->owner_last_name;
    my @uniquename_array = $self->uniquename_list ? @{$self->uniquename_list} : ();
    my @trial_name_array = $self->trial_name_list ? @{$self->trial_name_list} : ();
    my @trial_id_array = $self->trial_id_list ? @{$self->trial_id_list} : ();
    my @location_name_array = $self->location_name_list ? @{$self->location_name_list} : ();
    my @year_array = $self->year_list ? @{$self->year_list} : ();
    my @program_id_array = $self->breeding_program_id_list ? @{$self->breeding_program_id_list} : ();
    my @genus_array = $self->genus_list ? @{$self->genus_list} : ();
    my @species_array = $self->species_list ? @{$self->species_list} : ();
    my @crop_name_array = $self->crop_name_list ? @{$self->crop_name_list} : ();
    my @stock_ids_array = $self->stock_id_list ? @{$self->stock_id_list} : ();
    my $using_vectorprop_filter = $self->search_vectorprop || 0;
    my $limit = $self->limit;
    my $offset = $self->offset;

    my $stock_type_name = 'vector_construct';
    my $stock_type_id;

    unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
        if ($any_name) { $any_name =~ s/^\s+|\s+$//g; }
    }

    my ($or_conditions, $and_conditions);
    $and_conditions->{'me.stock_id'} = { '>' => 0 };

    my $start = '%';
    my $end = '%';
    if ( $matchtype eq 'exactly' ) {
        $start = '';
        $end = '';
    } elsif ( $matchtype eq 'starts_with' ) {
        $start = '';
    } elsif ( $matchtype eq 'ends_with' ) {
        $end = '';
    }

    my $stock_synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    if ($any_name) {
	$or_conditions = [
	    { 'me.name'          => {'ilike' => $start.$any_name.$end} },
	    { 'me.uniquename'    => {'ilike' => $start.$any_name.$end} },
	    { 'me.description'   => {'ilike' => $start.$any_name.$end} },
	    { -and => [
		   'stockprops.value'  => {'ilike' => $start.$any_name.$end},
		   'stockprops.type_id' => $stock_synonym_cvterm_id,
		  ],},
	    ];
    } else {
        $or_conditions = [ { 'me.uniquename' => { '!=' => undef } } ];
    }

    foreach (@uniquename_array){
        if ($_){
            if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
                $_ =~ tr/*?/%_/;
            }
            push @{$and_conditions->{'me.uniquename'}}, {'ilike' => $start.$_.$end };
        }
    }

    foreach (@stock_ids_array){
        if ($_){
            if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
                $_ =~ tr/*?/%_/;
            }
            push @{$and_conditions->{'me.stock_id::varchar(255)'}}, {'ilike' => $_ };
        }
    }

    if ($organism_id) {
        $and_conditions->{'me.organism_id'} = $organism_id;
    }

    if ($stock_type_name){
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type_name, 'stock_type')->cvterm_id();
    }

    my $stock_type_search = 0;
    if ($stock_type_id) {
        $and_conditions->{'me.type_id'} = $stock_type_id;
        $stock_type_search = $stock_type_id;
    }

    if ( $owner_first_name || $owner_last_name ){
        my %person_params;
        if ($owner_first_name) {
            $owner_first_name =~ s/\s+//g;
            $person_params{first_name} = {'ilike' => '%'.$owner_first_name.'%'};
        }
        if ($owner_last_name) {
            $owner_last_name =~ s/\s+//g;
            $person_params{last_name} = {'ilike' => '%'.$owner_last_name.'%'};
        }

        #$people_schema->storage->debug(1);
        my $p_rs = $people_schema->resultset("SpPerson")->search(\%person_params);

        my $stock_owner_rs = $phenome_schema->resultset("StockOwner")->search({
            sp_person_id => { -in  => $p_rs->get_column('sp_person_id')->as_query },
        });
        my @stock_ids;
        while ( my $o = $stock_owner_rs->next ) {
            push @stock_ids, $o->stock_id;
        }
        $and_conditions->{'me.stock_id'} = { '-in' => \@stock_ids } ;
    }

    my $stock_join;
    my $nd_experiment_joins = [];


    if (scalar(@location_name_array)>0){
        push @$nd_experiment_joins, 'nd_geolocation';
        foreach (@location_name_array){
            if ($_){
                push @{$and_conditions->{ 'lower(nd_geolocation.description)' }}, { -like  => lc($_) };
            }
        }
    }

    if (scalar(@trial_name_array)>0 || scalar(@trial_id_array)>0 || scalar(@year_array)>0 || scalar(@program_id_array)>0){
        push @$nd_experiment_joins, { 'nd_experiment_projects' => { 'project' => ['projectprops', 'project_relationship_subject_projects' ] } };
        foreach (@trial_name_array){
            if ($_){
                push @{$and_conditions->{ 'lower(project.name)' }}, { -like  => lc($_) } ;
            }
        }
        foreach (@trial_id_array){
            if ($_){
                push @{$and_conditions->{ 'project.project_id' }}, $_ ;
            }
        }
        my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id;
        foreach (@year_array){
            if ($_){
                $and_conditions->{ 'projectprops.type_id'} = $year_type_id;
                push @{$and_conditions->{ 'lower(projectprops.value)' }}, { -like  => lc($_) } ;
            }
        }
        foreach (@program_id_array){
            if ($_){
                push @{$and_conditions->{ 'project_relationship_subject_projects.object_project_id' }}, $_ ;
            }
        }
    }

    foreach (@genus_array){
        if ($_){
            push @{$and_conditions->{ 'lower(organism.genus)' }}, { -like  => lc($_) } ;
        }
    }

    foreach (@species_array){
        if ($_){
            push @{$and_conditions->{ 'lower(organism.species)' }}, { -like  => lc($_) } ;
        }
    }

    foreach (@crop_name_array){
        if ($_){
            push @{$and_conditions->{ 'lower(organism.common_name)' }}, { -like  => lc($_) } ;
        }
    }

    my @vectorprop_filtered_stock_ids;

    if ($self->stockprops_values && scalar(keys %{$self->stockprops_values})>0){
	my @where_clauses;

        my @stockprop_wheres;
        foreach my $term_name (keys %{$self->stockprops_values}){

	    print STDERR "PROCESSING TERM $term_name\n";
            my $property_term = SGN::Model::Cvterm->get_cvterm_row($schema, $term_name, 'stock_property');
            if ($property_term){

		my $type_id = $property_term->cvterm_id();
                my $matchtype = $self->stockprops_values->{$term_name}->{'matchtype'};
                my $value = $self->stockprops_values->{$term_name}->{'value'};

                my $start = '%';
                my $end = '%';
                if ( $matchtype eq 'exactly' ) {
                    $start = '%"';
                    $end = '"%';
                } elsif ( $matchtype eq 'starts_with' ) {
                    $start = '';
                } elsif ( $matchtype eq 'ends_with' ) {
                    $end = '';
                }
                my $search = "'$start$value$end'";
                if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
                    $search =~ tr/*?/%_/;
                }

                if ( $matchtype eq 'one of' ) {
		    print STDERR "ONE OF...\n";
                    my @values = split ',', $value;

		    push @where_clauses, " (type_id = $type_id and value in ('", join("'", @values).") ) ";
#                    push @stockprop_wheres, "\"".$term_name."\"::text \\?| array[$search_vals_sql]";

                } else {
		    print STDERR "ANY...\n";
                    #push @stockprop_wheres, "\"".$term_name."\"::text ilike $search";
		    push @where_clauses, "  (type_id = $type_id and value ilike '$start$value$end') ";
                }

            } else {
                print STDERR "Stockprop $term_name is not in this database! Only use stock_property in sgn_local configuration!\n";
            }
        }
        my $stockprop_where = 'WHERE ' . join ' OR ', @stockprop_wheres;

	my $where_clause = join(" or ", @where_clauses);
        my $stockprop_query = "SELECT stock_id FROM stockprop where $where_clause";
	print STDERR "QUERY: $stockprop_query\n";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();
        while (my $stock_id = $h->fetchrow_array()) {
            push @vectorprop_filtered_stock_ids, $stock_id;
        }
	print STDERR "RETRIEVED ".scalar(@vectorprop_filtered_stock_ids)." stocks\n";
    }



    if ($stock_type_search == $stock_type_id){
        $stock_join = { stock_relationship_objects => { subject => { nd_experiment_stocks => { nd_experiment => $nd_experiment_joins }}}};
    } else {
        $stock_join = { nd_experiment_stocks => { nd_experiment => $nd_experiment_joins } };
    }

    #$schema->storage->debug(1);
    my $operator = $default_operator ? $default_operator : (scalar(@vectorprop_filtered_stock_ids)>0 ? "or" : "and");
    my $search_query = {
        -$operator => [
            $or_conditions,
            $and_conditions,
        ],
    };
    if (!$self->include_obsolete) {
        $search_query->{'me.is_obsolete'} = 'f';
    }

    if ( scalar(@vectorprop_filtered_stock_ids)>0){
        $search_query->{'me.stock_id'} = {'in'=>\@vectorprop_filtered_stock_ids};
    }

    #skip rest of query if no results
    my @result;
    my $records_total = 0;
    my %result_hash;
    my @result_stock_ids;

    if ($using_vectorprop_filter == 0 || ($using_vectorprop_filter = 1 && scalar(@vectorprop_filtered_stock_ids)>0 )){

        my $rs = $schema->resultset("Stock::Stock")->search(
        $search_query,
        {
            join => ['type', 'organism', 'stockprops', $stock_join],
            '+select' => [ 'type.name' , 'organism.species' , 'organism.common_name', 'organism.genus'],
            '+as'     => [ 'cvterm_name' , 'species', 'common_name', 'genus'],
            order_by  => 'me.name',
            distinct=>1
        });

        $records_total = $rs->count();
        if (defined($limit) && defined($offset)){
            $rs = $rs->slice($offset, $limit);
        }

        my $owners_hash;
        if (!$self->minimal_info){
            my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
            $owners_hash = $stock_lookup->get_owner_hash_lookup();
        }

        while (my $a = $rs->next()) {
            my $uniquename  = $a->uniquename;
            my $stock_id    = $a->stock_id;
            push @result_stock_ids, $stock_id;

            if (!$self->minimal_info){
                # my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$stock_id});
                my @owners = $owners_hash->{$stock_id} ? @{$owners_hash->{$stock_id}} : ();
                my $type_id     = $a->type_id ;
                my $type        = $a->get_column('cvterm_name');
                my $organism_id = $a->organism_id;
                my $species    = $a->get_column('species');
                my $stock_name  = $a->name;
                my $common_name = $a->get_column('common_name');
                my $genus       = $a->get_column('genus');

                $result_hash{$stock_id} = {
                    stock_id => $stock_id,
                    uniquename => $uniquename,
                    stock_name => $stock_name,
                    stock_type => $type,
                    stock_type_id => $type_id,
                    species => $species,
                    genus => $genus,
                    common_name => $common_name,
                    organism_id => $organism_id,
                    owners => \@owners,
                };
            } else {
                $result_hash{$stock_id} = {
                    stock_id => $stock_id,
                    uniquename => $uniquename
                };
            }
        }
    }

    # Comma separated list of query placeholders for the result stock ids
    #
    my $id_ph = scalar(@result_stock_ids) > 0 ? join ",", ("?") x @result_stock_ids : "NULL";

    my $stock_query = "SELECT stock_id, uniquename, organism_id, stockprop.value from stock join stockprop using(stock_id) where stockprop.type_id=? and stock.stock_id in ($id_ph)";

    print STDERR "STOCK QUERY: $stock_query\n";

    my $sth = $schema->storage()->dbh()->prepare($stock_query);
    $sth->execute($stock_synonym_cvterm_id, @result_stock_ids);

    # Add additional organism and stock properties to the result hash for each stock
    while (my @r = $sth->fetchrow_array()) {
	print STDERR "RESULT: ".Dumper(\@r);
        my $stock_id = $r[0];
        my $organism_id = $r[2];
	#        my $syn_json = $r[3] ; #? decode_json(encode("utf8",$r[3])) : {};
	my $syn = $r[3];
        #my @synonyms = sort keys %{$syn_json};
	my @synonyms;
	push @synonyms, $syn;

        # add stock props to the result hash
        $result_hash{$stock_id}{synonyms} = \@synonyms;
    }

    if ($self->stockprop_columns_view && scalar(keys %{$self->stockprop_columns_view})>0 && scalar(@result_stock_ids)>0){
        my @stockprop_view = keys %{$self->stockprop_columns_view};
        my $result_stock_ids_sql = join ",", @result_stock_ids;
        my $stockprop_where = "WHERE stock_id IN ($result_stock_ids_sql)";

	print STDERR "STOCKPROP VIEW: ".Dumper(\@stockprop_view);
        my $stockprop_select_sql = "'" . join ("'", @stockprop_view) . "'";

	my $stockprop_query = "SELECT stock_id, cvterm.name, value FROM stockprop join cvterm on (cvterm.cvterm_id = stockprop.type_id) WHERE cvterm.name in ($stockprop_select_sql)";

	print STDERR "NEXT STOCKPROP QUERY: $stockprop_query\n";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();

	my @stockprop_values;
	while (my ($stock_id, $prop, $value) = $h->fetchrow_array()) {
	    print STDERR "RETRIEVED VALUE $value FOR $prop\n";
	    push @stockprop_values, $value;

	    my $stockprop_vals_string = join ',', @stockprop_values;
	    $result_hash{$stock_id}->{$prop} = $stockprop_vals_string;
        }

        while (my ($uniquename, $info) = each %result_hash){
            foreach (@stockprop_view){
                if (!$info->{$_}){
                    $info->{$_} = '';
                }
            }
        }
    }

    foreach (sort keys %result_hash){
        push @result, $result_hash{$_};
    }


    print STDERR "CXGN::Stock::SearchVector search end\n";
    return (\@result, $records_total);
}

# sub _refresh_materialized_stockprop {
#     my $self = shift;
#     my $stockprop_view = shift;

#     print STDERR "REFRESH MATERIALIZED STOCKPROP VIEW ".Dumper($stockprop_view)."\n";

#     my $schema = $self->bcs_schema;

#     eval {
#         my $stockprop_select_sql .= ', "' . join ('","', @$stockprop_view) . '"';
#         my $stockprop_query = "SELECT stock_id $stockprop_select_sql FROM materialized_stockprop;";
#         my $h = $schema->storage->dbh()->prepare($stockprop_query);
#         $h->execute();
#     };
#     if ($@) {
#         my @stock_props = $self->stockprops();
# #	    ('block', 'col_number', 'igd_synonym', 'is a control', 'location_code', 'organization', 'plant_index_number', 'subplot_index_number', 'tissue_sample_index_number', 'plot number', 'plot_geo_json', 'range', 'replicate', 'row_number', 'stock_synonym', 'T1', 'T2', 'variety', 'transgenic',
# #        'notes', 'state', 'accession number', 'PUI', 'donor', 'donor institute', 'donor PUI', 'seed source', 'institute code', 'institute name', 'biological status of accession code', 'country of origin', 'type of germplasm storage code', 'entry number', 'acquisition date', 'current_count', 'current_weight_gram', 'crossing_metadata_json', 'ploidy_level', 'genome_structure',
# #        'introgression_parent', 'introgression_backcross_parent', 'introgression_map_version', 'introgression_chromosome', 'introgression_start_position_bp', 'introgression_end_position_bp', 'is_blank', 'concentration', 'volume', 'extraction', 'dna_person', 'tissue_type', 'ncbi_taxonomy_id', 'seedlot_quality', 'SelectionMarker', 'CloningOrganism', 'CassetteName','Strain', 'InherentMarker', 'Backbone', 'VectorType', 'Gene', 'Promotors', 'Terminators', 'PlantAntibioticResistantMarker', 'BacterialResistantMarker');

#         my %stockprop_check = map { $_ => 1 } @stock_props;
#         my @additional_terms;
#         foreach (@$stockprop_view) {
#             if (!exists($stockprop_check{$_})) {
#                 push @additional_terms, $_;
#             }
#         }

#         my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
#         my $h = $schema->storage->dbh()->prepare($q);

#         my $stockprop_refresh_q = "
#         DROP EXTENSION IF EXISTS tablefunc CASCADE;
#         CREATE EXTENSION tablefunc;

#         DROP MATERIALIZED VIEW IF EXISTS public.materialized_stockprop CASCADE;
#         CREATE MATERIALIZED VIEW public.materialized_stockprop AS
#         SELECT *
#         FROM crosstab(
#         'SELECT stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id, jsonb_object_agg(stockprop.value, stockprop.rank) FROM public.stockprop JOIN public.stock USING(stock_id) JOIN public.cvterm as stock_cvterm ON (stock_cvterm.cvterm_id=stock.type_id) GROUP BY (stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id) ORDER by stockprop.stock_id ASC',
#         'SELECT type_id FROM (VALUES ";
#         my @stockprop_ids_sql;
#         foreach (@stock_props) {
#             push @stockprop_ids_sql, "(''".SGN::Model::Cvterm->get_cvterm_row($schema, $_, 'stock_property')->cvterm_id()."'')";
#         }
#         my $stockprop_ids_sql_joined = join ',', @stockprop_ids_sql;
#         $stockprop_refresh_q .= $stockprop_ids_sql_joined;
#         foreach (@additional_terms) {
#             $h->execute($_, 'stock_property');
#             my ($cvterm_id) = $h->fetchrow_array();
#             if (!$cvterm_id) {
#                 my $new_term = $schema->resultset("Cv::Cvterm")->create_with({
#                    name => $_,
#                    cv => 'stock_property'
#                 });
#                 $cvterm_id = $new_term->cvterm_id();
#             }

#             $stockprop_refresh_q .= ",(''".$cvterm_id."'')";
#         }

#         $stockprop_refresh_q .= ") AS t (type_id);'
#         )
#         AS (stock_id int,
#         \"uniquename\" text,
#         \"stock_type_id\" int,
#         \"stock_type_name\" text,
#         \"organism_id\" int,";
#         my @stockprop_names_sql;
#         foreach (@stock_props) {
#             push @stockprop_names_sql, "\"$_\" jsonb";
#         }
#         my $stockprop_names_sql_joined = join ',', @stockprop_names_sql;
#         $stockprop_refresh_q .= $stockprop_names_sql_joined;
#         foreach (@additional_terms) {
#             $stockprop_refresh_q .= ",\"$_\" jsonb ";
#         }
#         $stockprop_refresh_q .= ");
#         CREATE UNIQUE INDEX materialized_stockprop_stock_idx ON public.materialized_stockprop(stock_id) WITH (fillfactor=100);
#         ALTER MATERIALIZED VIEW public.materialized_stockprop OWNER TO web_usr;

#         CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop() RETURNS VOID AS '
#         REFRESH MATERIALIZED VIEW public.materialized_stockprop;'
#         LANGUAGE SQL;

#         ALTER FUNCTION public.refresh_materialized_stockprop() OWNER TO web_usr;

#         CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop_concurrently() RETURNS VOID AS '
#         REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_stockprop;'
#         LANGUAGE SQL;

#         ALTER FUNCTION public.refresh_materialized_stockprop_concurrently() OWNER TO web_usr;

#         ";
#         $schema->storage->dbh()->do($stockprop_refresh_q);
#     }
# }

1;
