package CXGN::Phenotypes::Search::MaterializedViewTable;

=head1 NAME

CXGN::Phenotypes::Search::MaterializedViewTable - an object to handle searching phenotypes across database. called from factory CXGN::Phenotypes::SearchFactory. Processes phenotype search against cxgn schema.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'MaterializedViewTable',    #can be either 'MaterializedViewTable' or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        program_list=>$program_list,
        folder_list=>$folder_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        subplot_list=>$subplot_list,
        exclude_phenotype_outlier=>0,
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
use CXGN::Trial::TrialLayout;
use CXGN::Calendar;
use JSON::XS;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(plot, plant, subplot, tissue_sample, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'program_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'folder_list' => (
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

has 'order_by' => (
    isa => 'Str|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";

    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my $select_clause = "SELECT observationunit_stock_id, observationunit_uniquename, observationunit_type_name, germplasm_uniquename, germplasm_stock_id, rep, block, plot_number, row_number, col_number, plant_number, is_a_control, notes, trial_id, trial_name, trial_description, plot_width, plot_length, field_size, field_trial_is_planned_to_be_genotyped, field_trial_is_planned_to_cross, breeding_program_id, breeding_program_name, breeding_program_description, year, design, location_id, planting_date, harvest_date, folder_id, folder_name, folder_description, seedlot_transaction, seedlot_stock_id, seedlot_uniquename, seedlot_current_weight_gram, seedlot_current_count, seedlot_box_name, available_germplasm_seedlots, treatments, observations, count(observationunit_stock_id) OVER() AS full_count FROM materialized_phenotype_jsonb_table ";
    my $order_clause = $self->order_by ? " ORDER BY ".$self->order_by : " ORDER BY trial_name, observationunit_uniquename";

    my @where_clause;

    if (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_plant_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_plant_and_subplot_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->plant_list && scalar(@{$self->plant_list})>0)) {
        my $plot_and_plant_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->plant_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_plant_sql)";
    } elsif (($self->plot_list && scalar(@{$self->plot_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plot_and_subplot_sql = _sql_from_arrayref($self->plot_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit_stock_id in ($plot_and_subplot_sql)";
    } elsif (($self->plant_list && scalar(@{$self->plant_list})>0) && ($self->subplot_list && scalar(@{$self->subplot_list})>0)) {
        my $plant_and_subplot_sql = _sql_from_arrayref($self->plant_list) .",". _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit_stock_id in ($plant_and_subplot_sql)";
    } elsif ($self->plot_list && scalar(@{$self->plot_list})>0) {
        my $plot_sql = _sql_from_arrayref($self->plot_list);
        push @where_clause, "observationunit_stock_id in ($plot_sql)";
    } elsif ($self->plant_list && scalar(@{$self->plant_list})>0) {
        my $plant_sql = _sql_from_arrayref($self->plant_list);
        push @where_clause, "observationunit_stock_id in ($plant_sql)";
    } elsif ($self->subplot_list && scalar(@{$self->subplot_list})>0) {
        my $subplot_sql = _sql_from_arrayref($self->subplot_list);
        push @where_clause, "observationunit_stock_id in ($subplot_sql)";
    }

    if ($self->trial_list && scalar(@{$self->trial_list})>0) {
        my $trial_sql = _sql_from_arrayref($self->trial_list);
        push @where_clause, "trial_id in ($trial_sql)";
    }
    if ($self->program_list && scalar(@{$self->program_list})>0) {
        my $program_sql = _sql_from_arrayref($self->program_list);
        push @where_clause, "breeding_program_id in ($program_sql)";
    }
    if ($self->folder_list && scalar(@{$self->folder_list})>0) {
        my $folder_sql = _sql_from_arrayref($self->folder_list);
        push @where_clause, "folder_id in ($folder_sql)";
    }
    if ($self->accession_list && scalar(@{$self->accession_list})>0) {
        my $arrayref = $self->accession_list;
        my $sql = join ("','" , @$arrayref);
        my $accession_sql = "'" . $sql . "'";
        push @where_clause, "germplasm_stock_id in ($accession_sql)";
    }
    if ($self->location_list && scalar(@{$self->location_list})>0) {
        my $arrayref = $self->location_list;
        my $sql = join ("','" , @$arrayref);
        my $location_sql = "'" . $sql . "'";
        push @where_clause, "location_id in ($location_sql)";
    }
    if ($self->year_list && scalar(@{$self->year_list})>0) {
        my $arrayref = $self->year_list;
        my $sql = join ("','" , @$arrayref);
        my $year_sql = "'" . $sql . "'";
        push @where_clause, "year in ($year_sql)";
    }
    if ($self->data_level ne 'all') {
        push @where_clause, "observationunit_type_name = '".$self->data_level."'"; #ONLY plot or plant or subplot or tissue_sample
    } else {
        push @where_clause, "(observationunit_type_name = 'plot' OR observationunit_type_name = 'plant' OR observationunit_type_name = 'subplot' OR observationunit_type_name = 'tissue_sample' OR observationunit_type_name = 'analysis_instance')"; #plots AND plants AND subplots AND tissue_samples AND analysis_instance
    }

    my %trait_list_check;
    my $filter_trait_ids;
    my @or_clause;
    if ($self->trait_list && scalar(@{$self->trait_list})>0) {
        print STDERR "A trait list was included\n";
        foreach (@{$self->trait_list}){
            if ($_){
                #print STDERR "Working on trait $_\n";
                push @or_clause, "observations @> '[{\"trait_id\" : $_}]'";
                $trait_list_check{$_}++;
                $filter_trait_ids = 1;
            }
        }
    }
    my $filter_trait_names;
    if ($self->trait_contains && scalar(@{$self->trait_contains})>0) {
        foreach (@{$self->trait_contains}) {
            if ($_){
                push @or_clause, "observations @> '[{\"trait_name\" : \"$_\"}]'";
                $filter_trait_names = 1;
            }
        }
    }
    #if ($self->phenotype_min_value && !$self->phenotype_max_value) {
    #    push @where_clause, 'JSON_EXISTS(observations, \'$[*] ? (@.value >= '.$self->phenotype_min_value.')\')';
    #}
    # if ($self->phenotype_max_value && !$self->phenotype_min_value) {
    #     push @where_clause, 'JSON_EXISTS(observations, \'$[*] ? (@.value <= '.$self->phenotype_max_value.')\')';
    # }
    # if ($self->phenotype_max_value && $self->phenotype_min_value) {
    #     push @where_clause, 'JSON_EXISTS(observations, \'$[*] ? (@.value >= '.$self->phenotype_min_value.' && @.value <= '.$self->phenotype_max_value.')\')';
    # }
    #
    #if ($self->exclude_phenotype_outlier){
    #    push @where_clause, "observations !@> '[{\"outlier\" : 1}]'";;
    #}

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
    my $or_clause = '';
    if (scalar(@or_clause) > 0){
        $or_clause = " AND ( " . (join (" OR " , @or_clause)) . " ) ";
    }

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".$self->limit;
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".$self->offset;
    }

    my  $q = $select_clause . $where_clause . $or_clause . $order_clause . $limit_clause . $offset_clause;

    print STDERR "QUERY: $q\n\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});
    my %unique_traits;

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $germplasm_uniquename, $germplasm_stock_id, $rep, $block, $plot_number, $row_number, $col_number, $plant_number, $is_a_control, $notes, $trial_id, $trial_name, $trial_description, $plot_width, $plot_length, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $planting_date, $harvest_date, $folder_id, $folder_name, $folder_description, $seedlot_transaction, $seedlot_stock_id, $seedlot_uniquename, $seedlot_current_weight_gram, $seedlot_current_count, $seedlot_box_name, $available_germplasm_seedlots, $treatments, $observations, $full_count) = $h->fetchrow_array()) {
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);
        my $synonyms = $synonym_hash_lookup{$germplasm_uniquename};
        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        my $observations = JSON::XS->new->decode($observations);
        my $treatments = JSON::XS->new->decode($treatments);
        my $available_germplasm_seedlots = JSON::XS->new->decode($available_germplasm_seedlots);
        my $seedlot_transaction = $seedlot_transaction ? JSON::XS->new->decode($seedlot_transaction) : {};

        my %ordered_observations;
        foreach (@$observations){
            $ordered_observations{$_->{phenotype_id}} = $_;
        }

        my @return_observations;;
        foreach my $pheno_id (sort keys %ordered_observations){
            my $o = $ordered_observations{$pheno_id};
            my $trait_name = $o->{trait_name};
            if ($filter_trait_names){
                my $skip;
                foreach (@{$self->trait_contains}){
                    if (index($trait_name, $_) == -1) {
                        $skip = 1;
                    }
                }
                if ($skip){
                    next;
                }
            }
            if ($filter_trait_ids){
                if (!$trait_list_check{$o->{trait_id}}){
                    next;
                }
            }
            my $phenotype_uniquename = $o->{uniquename};
            $unique_traits{$trait_name}++;
            if ($include_timestamp){
                my $timestamp_value;
                my $operator_value;
                if ($phenotype_uniquename){
                    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                    if ($p2){
                        my ($timestamp, $operator_value) = split /  operator = /, $p2;
                        if ( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                            $timestamp_value = $timestamp;
                        }
                    }
                }
                $o->{timestamp} = $timestamp_value;
            }
            if (!$o->{operator}){
                if ($phenotype_uniquename){
                    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
                    if ($p2){
                        my ($timestamp, $operator_value) = split /  operator = /, $p2;
                        $o->{operator} = $operator_value;
                    }
                }
            }
            push @return_observations, $o;
        }

        no warnings 'uninitialized';
        
        if ($notes) { $notes =~ s/\R//g; }
        if ($trial_description) { $trial_description =~ s/\R//g; }
        if ($breeding_program_description) { $breeding_program_description =~ s/\R//g };
        if ($folder_description) { $folder_description =~ s/\R//g };

        my $seedlot_transaction_description = $seedlot_transaction->{description};
        if ($seedlot_transaction_description) { $seedlot_transaction_description =~ s/\R//g; }

        push @result, {
            observationunit_stock_id => $observationunit_stock_id,
            observationunit_uniquename => $observationunit_uniquename,
            observationunit_type_name => $observationunit_type_name,
            germplasm_uniquename => $germplasm_uniquename,
            germplasm_stock_id => $germplasm_stock_id,
            germplasm_synonyms => $synonyms,
            obsunit_rep => $rep,
            obsunit_block => $block,
            obsunit_plot_number => $plot_number,
            obsunit_row_number => $row_number,
            obsunit_col_number => $col_number,
            obsunit_plant_number => $plant_number,
            obsunit_is_a_control => $is_a_control,
            notes => $notes,
            trial_id => $trial_id,
            trial_name => $trial_name,
            trial_description => $trial_description,
            plot_width => $plot_width,
            plot_length => $plot_length,
            field_size => $field_size,
            field_trial_is_planned_to_be_genotyped => $field_trial_is_planned_to_be_genotyped,
            field_trial_is_planned_to_cross => $field_trial_is_planned_to_cross,
            breeding_program_id => $breeding_program_id,
            breeding_program_name => $breeding_program_name,
            breeding_program_description => $breeding_program_description,
            year => $year,
            design => $design,
            trial_location_id => $location_id,
            trial_location_name => $location_name,
            planting_date => $planting_date_value,
            harvest_date => $harvest_date_value,
            folder_id => $folder_id,
            folder_name => $folder_name,
            folder_description => $folder_description,
            seedlot_transaction_amount => $seedlot_transaction->{amount},
            seedlot_transaction_weight_gram => $seedlot_transaction->{weight_gram},
            seedlot_transaction_timestamp => $seedlot_transaction->{timestamp},
            seedlot_transaction_operator => $seedlot_transaction->{operator},
            seedlot_transaction_description => $seedlot_transaction_description,
            seedlot_stock_id => $seedlot_stock_id,
            seedlot_uniquename => $seedlot_uniquename,
            seedlot_current_count => $seedlot_current_count,
            seedlot_current_weight_gram => $seedlot_current_weight_gram,
            seedlot_box_name => $seedlot_box_name,
            available_germplasm_seedlots => $available_germplasm_seedlots,
            treatments => $treatments,
            observations => \@return_observations,
            full_count => $full_count,
        };
    }
    #print STDERR Dumper \@result;

    print STDERR "Search End:".localtime."\n";
    return (\@result, \%unique_traits);
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


1;
