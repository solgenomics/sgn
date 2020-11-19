package CXGN::Stock::Search;

=head1 NAME

CXGN::Stock::Search - an object to handle searching for stocks (accessions,plots,plants,etc) given criteria

=head1 USAGE

my $stock_search = CXGN::Stock::Search->new({
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
    minimum_phenotype_value=>$minimum_phenotype_value,
    maximum_phenotype_value=>$maximum_phenotype_value,
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
    isa => 'ArrayRef[Int]|Undef',
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

has 'minimum_phenotype_value' => (
    isa => 'Num|Undef',
    is => 'rw',
);

has 'maximum_phenotype_value' => (
    isa => 'Num|Undef',
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

sub search {
    my $self = shift;
    print STDERR "CXGN::Stock::Search search start\n";
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
    my $phenome_schema = $self->phenome_schema;
    my $matchtype = $self->match_type || 'contains';
    my $any_name = $self->match_name;
    my $organism_id = $self->organism_id;
    my $stock_type_id = $self->stock_type_id;
    my $stock_type_name = $self->stock_type_name;
    my $owner_first_name = $self->owner_first_name;
    my $owner_last_name = $self->owner_last_name;
    my $minimum_phenotype_value = $self->minimum_phenotype_value;
    my $maximum_phenotype_value = $self->maximum_phenotype_value;
    my @uniquename_array = $self->uniquename_list ? @{$self->uniquename_list} : ();
    my @trait_name_array = $self->trait_cvterm_name_list ? @{$self->trait_cvterm_name_list} : ();
    my @trial_name_array = $self->trial_name_list ? @{$self->trial_name_list} : ();
    my @trial_id_array = $self->trial_id_list ? @{$self->trial_id_list} : ();
    my @location_name_array = $self->location_name_list ? @{$self->location_name_list} : ();
    my @year_array = $self->year_list ? @{$self->year_list} : ();
    my @program_id_array = $self->breeding_program_id_list ? @{$self->breeding_program_id_list} : ();
    my @genus_array = $self->genus_list ? @{$self->genus_list} : ();
    my @species_array = $self->species_list ? @{$self->species_list} : ();
    my @crop_name_array = $self->crop_name_list ? @{$self->crop_name_list} : ();
    my @stock_ids_array = $self->stock_id_list ? @{$self->stock_id_list} : ();
    my $limit = $self->limit;
    my $offset = $self->offset;

    unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
        $any_name =~ s/^\s+|\s+$//g;
    }

    my @sql_or_conditions;
    my @sql_and_conditions;

    push @sql_and_conditions, "stock.stock_id > 0";

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
        push @sql_or_conditions, (
            "stock.name ilike '".$start.$any_name.$end."'",
            "stock.uniquename ilike '".$start.$any_name.$end."'",
            "stock.description ilike '".$start.$any_name.$end."'",
            "(stockprop.value ilike '".$start.$any_name.$end."' AND stockprop.type_id = $stock_synonym_cvterm_id)"
        );
    }

    my @uniquename_array_filtered;
    foreach (@uniquename_array){
        if ($_){
            if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
                $_ =~ tr/*?/%_/;
            }
            push @uniquename_array_filtered, "stock.uniquename ilike '".$start.$_.$end."'";
        }
    }
    if (scalar(@uniquename_array_filtered)>0) {
        push @sql_and_conditions, "(".join(' OR ', @uniquename_array_filtered).")";
    }

    if (scalar(@stock_ids_array)>0) {
        push @sql_and_conditions, "stock.stock_id in (".join(',', @stock_ids_array).")";
    }

    if ($organism_id) {
        push @sql_and_conditions, "stock.organism_id = $organism_id";
    }

    if ($stock_type_name){
        $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type_name, 'stock_type')->cvterm_id();
    }

    my $stock_type_search = 0;
    if ($stock_type_id) {
        push @sql_and_conditions, "stock.type_id = $stock_type_id";
        $stock_type_search = $stock_type_id;
    }
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

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
        my $stock_ids_sql = join ',', @stock_ids;
        push @sql_and_conditions, "stock.stock_id in ($stock_ids_sql)";
    }

    my $nd_experment_phenotype_join = '';

    if (scalar(@trait_name_array)>0 || $minimum_phenotype_value || $maximum_phenotype_value){

        my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
        push @sql_and_conditions, "phenotype.value~\'$numeric_regex\'";

        if ($stock_type_search == $accession_cvterm_id){
            $nd_experment_phenotype_join = "JOIN nd_experiment_phenotype_bridge ON(plot.stock_id = nd_experiment_phenotype_bridge.stock_id)
                JOIN phenotype ON(nd_experiment_phenotype_bridge.phenotype_id = phenotype.phenotype_id)
                JOIN cvterm AS observable ON(observable.cvterm_id = phenotype.observable_id)";
        }
        else {
            $nd_experment_phenotype_join = "JOIN nd_experiment_phenotype_bridge ON(stock.stock_id = nd_experiment_phenotype_bridge.stock_id)
                JOIN phenotype ON(nd_experiment_phenotype_bridge.phenotype_id = phenotype.phenotype_id)
                JOIN cvterm AS observable ON(observable.cvterm_id = phenotype.observable_id)";
        }
        my @trait_name_filtered;
        foreach (@trait_name_array){
            if ($_){
                push @trait_name_filtered, "observable.name = '$_'";
            }
        }
        if (scalar(@trait_name_filtered)>0) {
            push @sql_and_conditions, "(".join(' OR ', @trait_name_filtered).")";
        }

        if ($minimum_phenotype_value) {
            push @sql_and_conditions, "phenotype.value::decimal > $minimum_phenotype_value";
        }
        if ($maximum_phenotype_value) {
            push @sql_and_conditions, "phenotype.value::decimal < $maximum_phenotype_value";
        }
    }

    if (scalar(@location_name_array)>0){
        my @location_name_filtered;
        foreach (@location_name_array){
            if ($_){
                push @location_name_filtered, "nd_geolocation.description ilike '$_'";
            }
        }
        if (scalar(@location_name_filtered)>0) {
            push @sql_and_conditions, "(".join(' OR ', @location_name_filtered).")";
        }
    }

    my $nd_experiment_project_join = '';
    if (scalar(@trial_name_array)>0 || scalar(@trial_id_array)>0 || scalar(@year_array)>0 || scalar(@program_id_array)>0){
        $nd_experiment_project_join = "JOIN nd_experiment_project ON(nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
            JOIN project ON(nd_experiment_project.project_id = project.project_id)
            JOIN projectprop ON (projectprop.project_id = project.project_id)
            JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id)";

        my @filtered_name_array;
        foreach (@trial_name_array){
            if ($_){
                push @filtered_name_array, "project.name ilike '$_'";
            }
        }
        if (scalar(@filtered_name_array)>0) {
            push @sql_and_conditions, "(".join(' OR ', @filtered_name_array).")";
        }

        if (scalar(@trial_id_array)>0) {
            push @sql_and_conditions, "project.project_id in (".join(',', @trial_id_array).")";
        }

        my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id;
        my @year_array_filtered;
        foreach (@year_array){
            if ($_){
                push @year_array_filtered, "projectprop.value ilike '$_'";
            }
        }
        if (scalar(@year_array_filtered)>0) {
            push @sql_and_conditions, "(".join(' OR ', @year_array_filtered).")";
            push @sql_and_conditions, "projectprop.type_id = $year_type_id";
        }

        if (scalar(@program_id_array)>0) {
            push @sql_and_conditions, "project_relationship.object_project_id in (".join(',', @program_id_array).")";
        }
    }

    my @genus_array_filtered;
    foreach (@genus_array){
        if ($_){
            push @genus_array_filtered, "organism.genus ilike '$_'";
        }
    }
    if (scalar(@genus_array_filtered)>0) {
        push @sql_and_conditions, "(".join(' OR ', @genus_array_filtered).")";
    }

    my @species_array_filtered;
    foreach (@species_array){
        if ($_){
            push @species_array_filtered, "organism.species ilike '$_'";
        }
    }
    if (scalar(@species_array_filtered)>0) {
        push @sql_and_conditions, "(".join(' OR ', @species_array_filtered).")";
    }

    my @crop_name_array_filtered;
    foreach (@crop_name_array){
        if ($_){
            push @crop_name_array_filtered, "organism.common_name ilike '$_'";
        }
    }
    if (scalar(@species_array_filtered)>0) {
        push @sql_and_conditions, "(".join(' OR ', @species_array_filtered).")";
    }

    my @stockprop_filtered_stock_ids;
    my $using_stockprop_filter;
    if ($self->stockprops_values && scalar(keys %{$self->stockprops_values})>0){
        $using_stockprop_filter = 1;
        #print STDERR Dumper $self->stockprops_values;

        my @stockprop_terms = keys %{$self->stockprops_values}; 
        $self->_refresh_materialized_stockprop(\@stockprop_terms);

        my @stockprop_wheres;
        foreach my $term_name (keys %{$self->stockprops_values}){
            my $property_term = SGN::Model::Cvterm->get_cvterm_row($schema, $term_name, 'stock_property');
            if ($property_term){
                my $matchtype = $self->stockprops_values->{$term_name}->{'matchtype'};
                my $value = $self->stockprops_values->{$term_name}->{'value'};

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
                my $search = "'$start$value$end'";
                if ($matchtype eq 'contains'){ #for 'wildcard' matching it replaces * with % and ? with _
                    $search =~ tr/*?/%_/;
                }

                if ( $matchtype eq 'one of' ) {
                    my @values = split ',', $value;
                    my $search_vals_sql = "'".join ("','" , @values)."'";
                    push @stockprop_wheres, "\"".$term_name."\"::text \\?| array[$search_vals_sql]";
                } else {
                    push @stockprop_wheres, "\"".$term_name."\"::text ilike $search";
                }

            } else {
                print STDERR "Stockprop $term_name is not in this database! Only use stock_property in system_cvterms.txt!\n";
            }
        }
        my $stockprop_where = 'WHERE ' . join ' AND ', @stockprop_wheres;

        my $stockprop_query = "SELECT stock_id FROM materialized_stockprop $stockprop_where;";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();
        while (my $stock_id = $h->fetchrow_array()) {
            push @stockprop_filtered_stock_ids, $stock_id;
        }
    }

    my $stock_join = '';
    if ($stock_type_search == $accession_cvterm_id){
        $stock_join = "LEFT JOIN stock_relationship ON(stock.stock_id = stock_relationship.object_id)
            LEFT JOIN stock AS plot ON(plot.stock_id = stock_relationship.subject_id)
            LEFT JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id = plot.stock_id)
            LEFT JOIN nd_experiment ON(nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
            LEFT JOIN nd_geolocation ON (nd_geolocation.nd_geolocation_id = nd_experiment.nd_geolocation_id)";
    } else {
        $stock_join = "LEFT JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id = stock.stock_id)
            LEFT JOIN nd_experiment ON(nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
            LEFT JOIN nd_geolocation ON (nd_geolocation.nd_geolocation_id = nd_experiment.nd_geolocation_id)";
    }

    if (!$self->include_obsolete) {
        push @sql_and_conditions, "stock.is_obsolete = 'f'";
    }
    if ($using_stockprop_filter){
        if (scalar(@stockprop_filtered_stock_ids)>0) {
            push @sql_and_conditions, "stock.stock_id in (".join(',', @stockprop_filtered_stock_ids).")";
        }
        else {
            push @sql_and_conditions, "stock.stock_id in (0)";
        }
    }

    my $limit_offset = '';
    if (defined($limit) && defined($offset)) {
        my $limit_sql = $limit - $offset + 1;
        $limit_offset = "LIMIT $limit_sql OFFSET $offset";
    }

    if (scalar(@sql_or_conditions)>0) {
        push @sql_and_conditions, "(".join(' OR ', @sql_or_conditions).")";
    }
    my $where_clause = join ' AND ', @sql_and_conditions;

    my $stock_search_q = "SELECT stock.stock_id, stock.uniquename, stock.name, stock.type_id, stock_type.name, stock.organism_id, organism.species, organism.common_name, organism.genus, count(stock.stock_id) OVER()
        FROM stock
        $stock_join
        $nd_experment_phenotype_join
        $nd_experiment_project_join
        JOIN cvterm AS stock_type ON(stock.type_id = stock_type.cvterm_id)
        LEFT JOIN organism ON(stock.organism_id = organism.organism_id)
        LEFT JOIN stockprop ON(stock.stock_id = stockprop.stock_id)
        WHERE $where_clause
        GROUP BY stock.stock_id, stock.uniquename, stock.name, stock.type_id, stock_type.name, stock.organism_id, organism.species, organism.common_name, organism.genus
        ORDER BY stock.name
        $limit_offset;";
    print STDERR $stock_search_q."\n";
    my $stock_search_h = $schema->storage->dbh()->prepare($stock_search_q);
    $stock_search_h->execute();

    my $owners_hash;
    if (!$self->minimal_info){
        my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
        $owners_hash = $stock_lookup->get_owner_hash_lookup();
    }

    my $records_total = 0;
    my @result;
    my %result_hash;
    my @result_stock_ids;
    while (my ($stock_id, $uniquename, $stock_name, $type_id, $type, $organism_id, $species, $common_name, $genus, $result_count) = $stock_search_h->fetchrow_array()) {
        $records_total = $result_count;
        push @result_stock_ids, $stock_id;
        if (!$self->minimal_info){
            # my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$stock_id});
            my @owners = $owners_hash->{$stock_id} ? @{$owners_hash->{$stock_id}} : ();

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
                # pedigree=>$self->display_pedigree ? $stock_object->get_pedigree_string('Parents') : 'DISABLED',
                # synonyms=> $stock_object->synonyms,
                # speciesAuthority=>$stock_object->get_species_authority,
                # subtaxa=>$stock_object->get_subtaxa,
                # subtaxaAuthority=>$stock_object->get_subtaxa_authority,
                # donors=>$stock_object->donors,
            };
        } else {
            $result_hash{$stock_id} = {
                stock_id => $stock_id,
                uniquename => $uniquename
            };
        }
    }
    #print STDERR Dumper \%result_hash;
    
    # Comma separated list of query placeholders for the result stock ids
    my $id_ph = scalar(@result_stock_ids) > 0 ? join ",", ("?") x @result_stock_ids : "NULL";

    # Get additional organism properties (species authority, subtaxa, subtaxa authority)
    my $organism_query = "SELECT op.organism_id, cvterm.name, op.value, op.rank
        FROM organismprop AS op
        LEFT JOIN cvterm ON (op.type_id = cvterm.cvterm_id)
        WHERE op.organism_id IN (SELECT DISTINCT(organism_id) FROM stock WHERE stock_id IN ($id_ph))
        AND cvterm.name IN ('species authority', 'subtaxa', 'subtaxa authority')
        ORDER BY organism_id ASC;";
    my $organism_sth = $schema->storage()->dbh()->prepare($organism_query);
    $organism_sth->execute(@result_stock_ids);

    # Parse organism properties into hash $organism_props->organism_id->prop_type (cvterm name)->prop values (array)
    my %organism_props;
    while ( my @r = $organism_sth->fetchrow_array() ) {
        my $organism_id = $r[0];
        my $prop_type = $r[1];
        my $prop_value = $r[2];

        if ( !defined($organism_props{$organism_id}) ) {
            $organism_props{$organism_id} = {
                organism_id => $organism_id
            };
        }
        if ( !defined($organism_props{$organism_id}->{$prop_type}) ) {
            $organism_props{$organism_id}->{$prop_type} = ();
        }

        push @{$organism_props{$organism_id}->{$prop_type}}, $prop_value;
    }
    
    # Get additional stock properties (pedigree, synonyms, donor info)
    my $stock_query = "SELECT stock.stock_id, stock.uniquename, stock.organism_id,
               mother.uniquename AS female_parent, father.uniquename AS male_parent, m_rel.value AS cross_type,
               props.stock_synonym, props.donor, props.\"donor institute\", props.\"donor PUI\"
        FROM stock
        LEFT JOIN stock_relationship m_rel ON (stock.stock_id = m_rel.object_id AND m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
        LEFT JOIN stock mother ON (m_rel.subject_id = mother.stock_id)
        LEFT JOIN stock_relationship f_rel ON (stock.stock_id = f_rel.object_id AND f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
        LEFT JOIN stock father ON (f_rel.subject_id = father.stock_id)
        LEFT JOIN materialized_stockprop props ON (stock.stock_id = props.stock_id)
        WHERE stock.stock_id IN ($id_ph);";
    my $sth = $schema->storage()->dbh()->prepare($stock_query);
    $sth->execute(@result_stock_ids);
    
    # Add additional organism and stock properties to the result hash for each stock
    while (my @r = $sth->fetchrow_array()) {
        my $stock_id = $r[0];
        my $organism_id = $r[2];
        my $mother = $r[3] || 'NA';
        my $father = $r[4] || 'NA';
        my $syn_json = $r[6] ? decode_json(encode("utf8",$r[6])) : {};
        my @synonyms = sort keys %{$syn_json};
        my $donor_json = $r[7] ? decode_json(encode("utf8",$r[7])) : {};
        my $donor_inst_json = $r[8] ? decode_json(encode("utf8",$r[8])) : {};
        my $donor_pui_json = $r[8] ? decode_json(encode("utf8",$r[8])) : {};
        my @donor_accessions = keys %{$donor_json};
        my @donor_institutes = keys %{$donor_inst_json};
        my @donor_puis = keys %{$donor_pui_json};

        # add stock props to the result hash
        $result_hash{$stock_id}{pedigree} = $self->display_pedigree ? $mother . '/' . $father : 'DISABLED';
        $result_hash{$stock_id}{synonyms} = \@synonyms;
        my @donor_array;
        if (scalar(@donor_accessions)>0 && scalar(@donor_institutes)>0 && scalar(@donor_puis)>0 && scalar(@donor_accessions) == scalar(@donor_institutes) && scalar(@donor_accessions) == scalar(@donor_puis)){
            for (0 .. scalar(@donor_accessions)-1){
                push @donor_array, {
                    'donorGermplasmName'=>$donor_accessions[$_],
                    'donorAccessionNumber'=>$donor_accessions[$_],
                    'donorInstituteCode'=>$donor_institutes[$_],
                    'germplasmPUI'=>$donor_puis[$_]
                };
            }
        }
        $result_hash{$stock_id}{donors} = \@donor_array;

        # add organism props for each stock
        $result_hash{$stock_id}{speciesAuthority} = defined($organism_props{$organism_id}) ? $organism_props{$organism_id}->{'species authority'} : undef;
        $result_hash{$stock_id}{subtaxa} = defined($organism_props{$organism_id}) ? $organism_props{$organism_id}->{'subtaxa'} : undef;
        $result_hash{$stock_id}{subtaxaAuthority} = defined($organism_props{$organism_id}) ? $organism_props{$organism_id}->{'subtaxa authority'} : undef;
    }

    if ($self->stockprop_columns_view && scalar(keys %{$self->stockprop_columns_view})>0 && scalar(@result_stock_ids)>0){
        my @stockprop_view = keys %{$self->stockprop_columns_view};
        my $result_stock_ids_sql = join ",", @result_stock_ids;
        my $stockprop_where = "WHERE stock_id IN ($result_stock_ids_sql)";

        $self->_refresh_materialized_stockprop(\@stockprop_view);

        my $stockprop_select_sql .= ', "' . join ('","', @stockprop_view) . '"';
        my $stockprop_query = "SELECT stock_id $stockprop_select_sql FROM materialized_stockprop $stockprop_where;";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();
        while (my ($stock_id, @stockprop_select_return) = $h->fetchrow_array()) {
            for my $s (0 .. scalar(@stockprop_view)-1){
                # my $stockprop_vals = $stockprop_select_return[$s] ? decode_json $stockprop_select_return[$s] : {};
                my $stockprop_vals = $stockprop_select_return[$s] ? decode_json(encode("utf8",$stockprop_select_return[$s])) : {};
                my @stockprop_vals_string;
                foreach (sort { $stockprop_vals->{$a} cmp $stockprop_vals->{$b} } (keys %$stockprop_vals) ){
                    push @stockprop_vals_string, $_;
                }
                my $stockprop_vals_string = join ',', @stockprop_vals_string;
                $result_hash{$stock_id}->{$stockprop_view[$s]} = $stockprop_vals_string;
            }
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

    #print STDERR Dumper \@result;
    print STDERR "CXGN::Stock::Search search end\n";
    return (\@result, $records_total);
}

sub _refresh_materialized_stockprop {
    my $self = shift;
    my $stockprop_view = shift;
    my $schema = $self->bcs_schema;

    eval {
        my $stockprop_select_sql .= ', "' . join ('","', @$stockprop_view) . '"';
        my $stockprop_query = "SELECT stock_id $stockprop_select_sql FROM materialized_stockprop;";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();
    };
    if ($@) {
        my @stock_props = ('block', 'col_number', 'igd_synonym', 'is a control', 'location_code', 'organization', 'plant_index_number', 'subplot_index_number', 'tissue_sample_index_number', 'plot number', 'plot_geo_json', 'range', 'replicate', 'row_number', 'stock_synonym', 'T1', 'T2', 'variety',
        'notes', 'state', 'accession number', 'PUI', 'donor', 'donor institute', 'donor PUI', 'seed source', 'institute code', 'institute name', 'biological status of accession code', 'country of origin', 'type of germplasm storage code', 'entry number', 'acquisition date', 'current_count', 'current_weight_gram', 'crossing_metadata_json', 'ploidy_level', 'genome_structure',
        'introgression_parent', 'introgression_backcross_parent', 'introgression_map_version', 'introgression_chromosome', 'introgression_start_position_bp', 'introgression_end_position_bp', 'is_blank', 'concentration', 'volume', 'extraction', 'dna_person', 'tissue_type', 'ncbi_taxonomy_id', 'seedlot_quality');
        my %stockprop_check = map { $_ => 1 } @stock_props;
        my @additional_terms;
        foreach (@$stockprop_view) {
            if (!exists($stockprop_check{$_})) {
                push @additional_terms, $_;
            }
        }
        print STDERR Dumper \@additional_terms;

        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);

        my $stockprop_refresh_q = "
        DROP EXTENSION IF EXISTS tablefunc CASCADE;
        CREATE EXTENSION tablefunc;

        DROP MATERIALIZED VIEW IF EXISTS public.materialized_stockprop CASCADE;
        CREATE MATERIALIZED VIEW public.materialized_stockprop AS
        SELECT *
        FROM crosstab(
        'SELECT stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id, jsonb_object_agg(stockprop.value, ''RANK'' || stockprop.rank) FROM public.stockprop JOIN public.stock USING(stock_id) JOIN public.cvterm as stock_cvterm ON (stock_cvterm.cvterm_id=stock.type_id) GROUP BY (stockprop.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, stock.organism_id, stockprop.type_id) ORDER by stockprop.stock_id ASC',
        'SELECT type_id FROM (VALUES ";
        my @stockprop_ids_sql;
        foreach (@stock_props) {
            push @stockprop_ids_sql, "(''".SGN::Model::Cvterm->get_cvterm_row($schema, $_, 'stock_property')->cvterm_id()."'')";
        }
        my $stockprop_ids_sql_joined = join ',', @stockprop_ids_sql;
        $stockprop_refresh_q .= $stockprop_ids_sql_joined;
        foreach (@additional_terms) {
            $h->execute($_, 'stock_property');
            my ($cvterm_id) = $h->fetchrow_array();
            if (!$cvterm_id) {
                my $new_term = $schema->resultset("Cv::Cvterm")->create_with({
                   name => $_,
                   cv => 'stock_property'
                });
                $cvterm_id = $new_term->cvterm_id();
            }
            
            $stockprop_refresh_q .= ",(''".$cvterm_id."'')";
        }

        $stockprop_refresh_q .= ") AS t (type_id);'
        )
        AS (stock_id int,
        \"uniquename\" text,
        \"stock_type_id\" int,
        \"stock_type_name\" text,
        \"organism_id\" int,";
        my @stockprop_names_sql;
        foreach (@stock_props) {
            push @stockprop_names_sql, "\"$_\" jsonb";
        }
        my $stockprop_names_sql_joined = join ',', @stockprop_names_sql;
        $stockprop_refresh_q .= $stockprop_names_sql_joined;
        foreach (@additional_terms) {
            $stockprop_refresh_q .= ",\"$_\" jsonb ";
        }
        $stockprop_refresh_q .= ");
        CREATE UNIQUE INDEX materialized_stockprop_stock_idx ON public.materialized_stockprop(stock_id) WITH (fillfactor=100);
        ALTER MATERIALIZED VIEW public.materialized_stockprop OWNER TO web_usr;

        CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop() RETURNS VOID AS '
        REFRESH MATERIALIZED VIEW public.materialized_stockprop;'
        LANGUAGE SQL;

        ALTER FUNCTION public.refresh_materialized_stockprop() OWNER TO web_usr;

        CREATE OR REPLACE FUNCTION public.refresh_materialized_stockprop_concurrently() RETURNS VOID AS '
        REFRESH MATERIALIZED VIEW CONCURRENTLY public.materialized_stockprop;'
        LANGUAGE SQL;

        ALTER FUNCTION public.refresh_materialized_stockprop_concurrently() OWNER TO web_usr;

        ";
        $schema->storage->dbh()->do($stockprop_refresh_q);
    }
}

1;
