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
        subplot_list=>$subplot_list,
        exclude_phenotype_outlier=>0,
        include_timestamp=>$include_timestamp,
        include_row_and_column_numbers=>0,
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
use CXGN::Trial::TrialLayout;

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

has 'subplot_list' => (
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

has 'exclude_phenotype_outlier' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_row_and_column_numbers' => (
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
    my $row_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'row_number', 'stock_property')->cvterm_id();
    my $col_number_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'col_number', 'stock_property')->cvterm_id();
    my $year_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();
    my $design_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $planting_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_planting_date', 'project_property')->cvterm_id();
    my $havest_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_harvest_date', 'project_property')->cvterm_id();
    my $breeding_program_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program', 'project_property')->cvterm_id();
    my $project_location_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $subplot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my $design_layout_sql = '';
    my $design_layout_select = '';
    my $phenotypeprop_sql = '';
    my %design_layout_hash;
    my $using_layout_hash;
    #For performance reasons the number of joins to stock can be reduced if a trial is given. If trial(s) given, use the cached layout from TrialLayout instead.
    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        $using_layout_hash = 1;
        foreach (@{$self->trial_list}){
            my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $_, experiment_type=>'field_layout'});
            my $tl = $trial_layout->get_design();
            while(my($key,$val) = each %$tl){
                $design_layout_hash{$val->{plot_id}} = $val;
                if($val->{plant_ids}){
                    foreach my $p (@{$val->{plant_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }
                if($val->{subplot_ids}){
                    foreach my $p (@{$val->{subplot_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }
                if($val->{tissue_sample_ids}){
                    foreach my $p (@{$val->{tissue_sample_ids}}){
                        $design_layout_hash{$p} = $val;
                    }
                }
            }
            #For performace reasons it is faster to include specific stock_ids in the query.
            if ($self->data_level eq 'plot'){
                if (!$self->plot_list){
                    $self->plot_list([]);
                }
                my $plots = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_plots();
                foreach (@$plots){
                    push @{$self->plot_list}, $_->[0];
                }
            }
            if ($self->data_level eq 'plant'){
                if (!$self->plant_list){
                    $self->plant_list([]);
                }
                my $plants = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_plants();
                foreach (@$plants){
                    push @{$self->plant_list}, $_->[0];
                }
            }
            if ($self->data_level eq 'subplot'){
                if (!$self->subplot_list){
                    $self->subplot_list([]);
                }
                my $subplots = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $_ })->get_subplots();
                foreach (@$subplots){
                    push @{$self->subplot_list}, $_->[0];
                }
            }
        }
    } else {
        if ($self->include_row_and_column_numbers){
            $design_layout_sql = " LEFT JOIN stockprop AS rep ON (plot.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
            LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
            LEFT JOIN stockprop AS plot_number ON (plot.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id)
            LEFT JOIN stockprop AS row_number ON (plot.stock_id=row_number.stock_id AND row_number.type_id = $row_number_type_id)
            LEFT JOIN stockprop AS col_number ON (plot.stock_id=col_number.stock_id AND col_number.type_id = $col_number_type_id) ";
            $design_layout_select = " ,rep.value, block_number.value, plot_number.value, row_number.value, col_number.value";
        } else {
            $design_layout_sql = " LEFT JOIN stockprop AS rep ON (plot.stock_id=rep.stock_id AND rep.type_id = $rep_type_id)
            LEFT JOIN stockprop AS block_number ON (plot.stock_id=block_number.stock_id AND block_number.type_id = $block_number_type_id)
            LEFT JOIN stockprop AS plot_number ON (plot.stock_id=plot_number.stock_id AND plot_number.type_id = $plot_number_type_id) ";
            $design_layout_select = " ,rep.value, block_number.value, plot_number.value";
        }
    }

    if ($self->exclude_phenotype_outlier){
        $phenotypeprop_sql = " LEFT JOIN phenotypeprop ON (phenotype.phenotype_id = phenotypeprop.phenotype_id AND phenotypeprop.type_id = $phenotype_outlier_type_id)";
    }

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
      planting_date => 'plantingDate.value',
      harvest_date => 'harvestDate.value',
      breeding_program => 'program.value',
      plot_type=> 'plot_type.name',
      from_clause=> " FROM stock as plot JOIN stock_relationship ON (plot.stock_id=subject_id)
      JOIN cvterm as plot_type ON (plot_type.cvterm_id = plot.type_id)
      JOIN stock as accession ON (object_id=accession.stock_id AND accession.type_id = $accession_type_id)
      $design_layout_sql
      JOIN nd_experiment_stock ON(nd_experiment_stock.stock_id=plot.stock_id)
      JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN phenotype USING(phenotype_id)
      $phenotypeprop_sql
      JOIN cvterm ON (phenotype.cvalue_id=cvterm.cvterm_id)
      JOIN dbxref ON (cvterm.dbxref_id = dbxref.dbxref_id)
      JOIN db USING(db_id)
      JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id=nd_experiment.nd_experiment_id)
      JOIN project USING(project_id)
      LEFT JOIN projectprop as year ON (project.project_id=year.project_id AND year.type_id = $year_type_id)
      LEFT JOIN projectprop as design ON (project.project_id=design.project_id AND design.type_id = $design_type_id)
      LEFT JOIN projectprop as location ON (project.project_id=location.project_id AND location.type_id = $project_location_type_id)
      LEFT JOIN projectprop as plantingDate ON (project.project_id=plantingDate.project_id AND plantingDate.type_id = $planting_date_type_id)
      LEFT JOIN projectprop as harvestDate ON (project.project_id=harvestDate.project_id AND harvestDate.type_id = $havest_date_type_id)
      LEFT JOIN projectprop as program ON (project.project_id=program.project_id AND program.type_id = $breeding_program_type_id)",
    );

    my $select_clause = "SELECT ".$columns{'year_id'}.", ".$columns{'trial_name'}.", ".$columns{'accession_name'}.", ".$columns{'location_name'}.", ".$columns{'trait_name'}.", ".$columns{'phenotype_value'}.", ".$columns{'plot_name'}.", ".$columns{'trait_id'}.", ".$columns{'trial_id'}.", ".$columns{'location_id'}.", ".$columns{'accession_id'}.", ".$columns{'plot_id'}.", phenotype.uniquename, ".$columns{'trial_design'}.", ".$columns{'plot_type'}.", ".$columns{'planting_date'}.", ".$columns{'harvest_date'}.", ".$columns{'breeding_program'}.", phenotype.phenotype_id, count(phenotype.phenotype_id) OVER() AS full_count ".$design_layout_select;

    my $from_clause = $columns{'from_clause'};

    my $order_clause = " ORDER BY 2,7,16 DESC";

    my @where_clause;

    if ($self->accession_list && scalar(@{$self->accession_list})>0) {
        my $accession_sql = _sql_from_arrayref($self->accession_list);
        push @where_clause, $columns{'accession_id'}." in ($accession_sql)";
    }

    if (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_plant_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_and_plant_and_subplot_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_and_plant_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_and_subplot_sql)";
    } elsif (($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plant_and_subplot_sql = _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, $columns{'plot_id'}." in ($plant_and_subplot_sql)";
    } elsif ($self->plot_list && scalar(@{$self->plot_list})>0) {
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, $columns{'plot_id'}." in ($plot_sql)";
    } elsif ($self->plant_list && scalar(@{$self->plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($self->plant_list);
        push @where_clause, $columns{'plot_id'}." in ($plant_sql)";
    } elsif ($self->subplot_list && scalar(@{$self->subplot_list})>0) {
        my $subplot_sql = _sql_from_arrayref($self->subplot_list);
        push @where_clause, $columns{'plot_id'}." in ($subplot_sql)";
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
      push @where_clause, "plot.type_id = $stock_type_id"; #ONLY plots or plants or subplots
    } else {
      push @where_clause, "(plot.type_id = $plot_type_id OR plot.type_id = $plant_type_id OR plot.type_id = $subplot_type_id)"; #plots AND plants AND subplots
    }

    if ($self->exclude_phenotype_outlier){
        push @where_clause, "phenotypeprop.value IS NULL";
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

    while (my ($year, $project_name, $stock_name, $location, $trait, $value, $plot_name, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $phenotype_uniquename, $design, $stock_type_name, $planting_date, $harvest_date, $breeding_program, $phenotype_id, $full_count, $rep_select, $block_number_select, $plot_number_select, $row_number_select, $col_number_select) = $h->fetchrow_array()) {
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
        my $rep;
        my $block_number;
        my $plot_number;
        my $row_number;
        my $col_number;
        if ($using_layout_hash){
            $rep = $design_layout_hash{$plot_id}->{rep_number};
            $block_number = $design_layout_hash{$plot_id}->{block_number};
            $plot_number = $design_layout_hash{$plot_id}->{plot_number};
            $row_number = $design_layout_hash{$plot_id}->{row_number};
            $col_number = $design_layout_hash{$plot_id}->{col_number};
        } else {
            $rep = $rep_select;
            $block_number = $block_number_select;
            $plot_number = $plot_number_select;
            $row_number = $row_number_select;
            $col_number = $col_number_select;
        }
        my $synonyms = $synonym_hash_lookup{$stock_name};
        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        if ($self->data_level eq 'metadata'){
          push @$result, [ $year, $project_name, $location_name, $design, $breeding_program, $planting_date, $harvest_date ];
        }
        else{
          push @$result, [ $year, $project_name, $stock_name, $location_name, $trait, $value, $plot_name, $rep, $block_number, $plot_number, $row_number, $col_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $timestamp_value, $synonyms, $design, $stock_type_name, $phenotype_id, $full_count ];
        }
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
