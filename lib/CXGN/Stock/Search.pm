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
    limit=>$limit,
    offset=>$offset,
    minimal_info=>o  #for only returning stock_id and uniquenames
    display_pedigree=>1 #to calculate and display pedigree
});
my ($result, $records_total) = $stock_search->search();

stockprops_values is a HashRef of ArrayRef of the form for example:
{
    'country of origin' => ['Uganda', 'Nigeria'],
    'ploidy' => ['2'],
    'introgression_start_position_bp' => ['10002'],
    'introgression_chromosome' => ['2']
}


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

has 'minimum_phenotype_value' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'maximum_phenotype_value' => (
    isa => 'Int|Undef',
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
    isa => 'HashRef[ArrayRef[Str]]|Undef',
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
    my @stock_ids_array = $self->stock_id_list ? @{$self->stock_id_list} : ();
    my $limit = $self->limit;
    my $offset = $self->offset;

    unless ($matchtype eq 'exactly') { #trim whitespace from both ends unless exact search was specified
        $any_name =~ s/^\s+|\s+$//g;
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

    if ($any_name) {
        $or_conditions = [
            { 'me.name'          => {'ilike' => $start.$any_name.$end} },
            { 'me.uniquename'    => {'ilike' => $start.$any_name.$end} },
            { 'me.description'   => {'ilike' => $start.$any_name.$end} },
            { 'stockprops.value'   => {'ilike' => $start.$any_name.$end} }
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
        $and_conditions->{'me.stock_id'} = { '-in' => \@stock_ids } ;
    }

    my $stock_join;
    my $nd_experiment_joins = [];

    if (scalar(@trait_name_array)>0 || $minimum_phenotype_value || $maximum_phenotype_value){
        push @$nd_experiment_joins, {'nd_experiment_phenotypes' => {'phenotype' => 'observable' }};
        foreach (@trait_name_array){
            if ($_){
                push @{$and_conditions->{ 'observable.name' }}, $_;
            }
        }
        if ($minimum_phenotype_value) {
            $and_conditions->{ 'phenotype.value' }  = { '>' => $minimum_phenotype_value };
        }
        if ($maximum_phenotype_value) {
            $and_conditions->{ 'phenotype.value' }  = { '<' => $maximum_phenotype_value };
        }
    }

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

    my @stockprop_filtered_stock_ids;
    my $using_stockprop_filter;
    if ($self->stockprops_values && scalar(keys %{$self->stockprops_values})>0){
        $using_stockprop_filter = 1;
        print STDERR Dumper $self->stockprops_values;
        my @stockprop_wheres;
        foreach my $term_name (keys %{$self->stockprops_values}){
            my $property_term = SGN::Model::Cvterm->get_cvterm_row($schema, $term_name, 'stock_property');
            if ($property_term){
                my $search_vals = $self->stockprops_values->{$term_name};
                #jsonb obj has any keys in $search_vals
                my $search_vals_sql = "'".join ("','" , @$search_vals)."'";
                push @stockprop_wheres, "\"$term_name\" \\?| array[$search_vals_sql]";
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

    if ($stock_type_search == $accession_cvterm_id){
        $stock_join = { stock_relationship_objects => { subject => { nd_experiment_stocks => { nd_experiment => $nd_experiment_joins }}}};
    } else {
        $stock_join = { nd_experiment_stocks => { nd_experiment => $nd_experiment_joins } };
    }

    #$schema->storage->debug(1);
    my $search_query = {
        'me.is_obsolete' => 'f',
        -and => [
            $or_conditions,
            $and_conditions,
        ],
    };
    if ($using_stockprop_filter || scalar(@stockprop_filtered_stock_ids)>0){
        $search_query->{'me.stock_id'} = {'in'=>\@stockprop_filtered_stock_ids};
    }

    my $rs = $schema->resultset("Stock::Stock")->search(
    $search_query,
    {
        join => ['type', 'organism', 'stockprops', $stock_join],
        '+select' => [ 'type.name' , 'organism.species' , 'organism.common_name', 'organism.genus'],
        '+as'     => [ 'cvterm_name' , 'species', 'common_name', 'genus'],
        order_by  => 'me.name',
        distinct=>1
    });

    my $records_total = $rs->count();
    if (defined($limit) && defined($offset)){
        $rs = $rs->slice($offset, $limit);
    }

    my $owners_hash;
    if (!$self->minimal_info){
        my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
        $owners_hash = $stock_lookup->get_owner_hash_lookup();
    }

    my @result;
    my %result_hash;
    my @result_stock_ids;
    while (my $a = $rs->next()) {
        my $uniquename  = $a->uniquename;
        my $stock_id    = $a->stock_id;
        push @result_stock_ids, $stock_id;

        if (!$self->minimal_info){
            my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$stock_id});
            my @owners = $owners_hash->{$stock_id} ? @{$owners_hash->{$stock_id}} : ();
            my $type_id     = $a->type_id ;
            my $type        = $a->get_column('cvterm_name');
            my $organism_id = $a->organism_id;
            my $species    = $a->get_column('species');
            my $stock_name  = $a->name;
            my $common_name = $a->get_column('common_name');
            my $genus       = $a->get_column('genus');

            $result_hash{$uniquename} = {
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
                pedigree=>$self->display_pedigree ? $stock_object->get_pedigree_string('Parents') : 'DISABLED',
                synonyms=> $stock_object->synonyms,
                speciesAuthority=>$stock_object->get_species_authority,
                subtaxa=>$stock_object->get_subtaxa,
                subtaxaAuthority=>$stock_object->get_subtaxa_authority,
                donors=>$stock_object->donors,
            };
        } else {
            $result_hash{$uniquename} = {
                stock_id => $stock_id,
                uniquename => $uniquename
            };
        }
    }
    #print STDERR Dumper \%result_hash;

    if ($self->stockprop_columns_view && scalar(keys %{$self->stockprop_columns_view})>0 && scalar(@result_stock_ids)>0){
        my @stockprop_view = keys %{$self->stockprop_columns_view};
        my $result_stock_ids_sql = join ",", @result_stock_ids;
        my $stockprop_where = "WHERE stock_id IN ($result_stock_ids_sql)";

        my $stockprop_select_sql .= ', "' . join '","', @stockprop_view;
        $stockprop_select_sql .= '"';

        my $stockprop_query = "SELECT uniquename $stockprop_select_sql FROM materialized_stockprop $stockprop_where;";
        my $h = $schema->storage->dbh()->prepare($stockprop_query);
        $h->execute();
        while (my ($uniquename, @stockprop_select_return) = $h->fetchrow_array()) {
            for my $s (0 .. scalar(@stockprop_view)-1){
                my $stockprop_vals = $stockprop_select_return[$s] ? decode_json $stockprop_select_return[$s] : {};
                my @stockprop_vals_string;
                foreach (sort { $stockprop_vals->{$a} cmp $stockprop_vals->{$b} } (keys %$stockprop_vals) ){
                    push @stockprop_vals_string, $_;
                }
                my $stockprop_vals_string = join ',', @stockprop_vals_string;
                $result_hash{$uniquename}->{$stockprop_view[$s]} = $stockprop_vals_string;
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

1;
