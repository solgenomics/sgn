package CXGN::Phenotypes::Search::Native;

=head1 NAME

CXGN::Phenotypes::Search::Native - an object to handle searching phenotypes across database. called from factory CXGN::Phenotypes::SearchFactory. Processes phenotype search against cxgn schema.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'Native',    #can be either 'MaterializedView', or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        include_timestamp=>$include_timestamp,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        limit=>$limit,
        offset=>$offset
    }
);
my @data = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(plot, plant, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plant_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'trait_contains' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'phenotype_min_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'phenotype_max_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";
    my $rep_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'replicate', 'stock_property')->cvterm_id();
    my $block_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'block', 'stock_property')->cvterm_id();
    my $plot_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot number', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my %columns = (
      accession_id=> 'accession.stock_id',
      plot_id=> 'plot.stock_id',
      trial_id=> 'project.project_id',
      trait_id=> 'cvterm.cvterm_id',
      location_id=> 'location.value',
      year_id=> 'year.value',
      trait_name=> "(((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text",
      phenotype_value=> 'phenotype.value',
      trial_name=> 'project.name',
      plot_name=> 'plot.uniquename AS plot_name',
      accession_name=> 'accession.uniquename',
      location_name=> 'location.value',
      trial_design=> 'design.value',
      plot_type=> 'plot_type.name',
      from_clause=> " FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id)
      JOIN cvterm as plot_type ON (plot_type.cvterm_id = plot.type_id)
      JOIN stock as accession ON (object_id=accession.stock_id AND accession.type_id = $accession_type_id)
      LEFT JOIN stockprop AS rep ON (plot.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
      LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
      LEFT JOIN stockprop AS plot_number ON (plot.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
      JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id)
      JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN phenotype USING(phenotype_id)
      JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
      JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
      JOIN db USING(db_id)
      JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN project USING(project_id)
      LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
      LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
      LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)",
    );

    my $select_clause = "SELECT ".$columns{'year_id'}.", ".$columns{'trial_name'}.", ".$columns{'accession_name'}.", ".$columns{'location_name'}.", ".$columns{'trait_name'}.", ".$columns{'phenotype_value'}.", ".$columns{'plot_name'}.",
          rep.value, block_number.value, plot_number.value, ".$columns{'trait_id'}.", ".$columns{'trial_id'}.", ".$columns{'location_id'}.", ".$columns{'accession_id'}.", ".$columns{'plot_id'}.", phenotype.uniquename, ".$columns{'trial_design'}.", ".$columns{'plot_type'}.", phenotype.phenotype_id, count(phenotype.phenotype_id) OVER() AS full_count";

    my $from_clause = $columns{'from_clause'};

    my $order_clause = " ORDER BY 2,7,19 DESC";

    my @where_clause;

    if ($self->accession_list && scalar(@{$self->accession_list})>0) {
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        push @where_clause, $columns{'accession_id'}." in ($accession_sql)";
    }

    if (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_and_plant_sql)";
    } elsif ($self->plot_list && scalar(@{$self->plot_list})>0) {
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_sql)";
    } elsif ($self->plant_list && scalar(@{$self->plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'plot_id'}." in ($plant_sql)";
    }

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, $columns{'trial_id'}." in ($trial_sql)";
    }
    if ($self->trait_list && scalar(@{$self->trait_list})>0) {
        my $trait_sql = _sql_from_arrayref($self->trait_list);
        push @where_clause, $columns{'trait_id'}." in ($trait_sql)";
    }
    if ($self->location_list && scalar(@{$self->location_list})>0) {
        my $arrayref = $self->location_list;
        my $sql = join ("','" , @$arrayref);
        my $location_sql = "'" . $sql . "'";
        push @where_clause, $columns{'location_id'}." in ($location_sql)";
    }
    if ($self->year_list && scalar(@{$self->year_list})>0) {
        my $arrayref = $self->year_list;
        my $sql = join ("','" , @$arrayref);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, $columns{'year_id'}." in ($year_sql)";
    }
    if ($self->trait_contains && scalar(@{$self->trait_contains})>0) {
        foreach (@{$self->trait_contains}) {
            push @where_clause, $columns{'trait_name'}." like '%".lc($_)."%'";
        }
    }
    if ($self->phenotype_min_value && !$self->phenotype_max_value) {
        push @where_clause, $columns{'phenotype_value'}."::real >= ".$self->phenotype_min_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && !$self->phenotype_min_value) {
        push @where_clause, $columns{'phenotype_value'}."::real <= ".$self->phenotype_max_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }
    if ($self->phenotype_max_value && $self->phenotype_min_value) {
        push @where_clause, $columns{'phenotype_value'}."::real BETWEEN ".$self->phenotype_min_value." AND ".$self->phenotype_max_value;
        push @where_clause, $columns{'phenotype_value'}."~\'$numeric_regex\'";
    }

    if ($self->data_level ne 'all') {
      my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $self->data_level, 'stock_type')->cvterm_id();
      push @where_clause, "plot.type_id = $stock_type_id"; #ONLY plots or plants
    } else {
      push @where_clause, "(plot.type_id = $plot_type_id OR plot.type_id = $plant_type_id)"; #plots AND plants
    }

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my  $q = $select_clause . $from_clause . $where_clause . $order_clause . $limit_clause . $offset_clause;

    print STDERR "QUERY: $q\n\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my $result = [];

    while (my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $rep, $block_number, $plot_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename, $design, $stock_type_name, $phenotype_id, $full_count) = $h->fetchrow_array()) {
        my $timestamp_value;
        if ($include_timestamp) {
            if ($phenotype_uniquename){
                my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                if ($p2){
                    my ($timestamp, $p3) = split /  operator/, $p2;
                    if ( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                        $timestamp_value = $timestamp;
                    }
                }
            }
        }
        my $synonyms = $synonym_hash_lookup{$stock_name};
        push @$result, [ $year, $project_name, $stock_name, $location_id_lookup{$location_id}, $trait, $value, $plot_name, $rep, $block_number, $plot_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $timestamp_value, $synonyms, $design, $stock_type_name, $phenotype_id, $full_count ];
    }

    print STDERR "Search End:".localtime."\n";
    return $result;
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
