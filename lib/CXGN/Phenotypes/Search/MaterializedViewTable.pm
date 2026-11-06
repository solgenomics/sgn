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
use CXGN::DB::ReadSnapshot;
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

has 'observation_unit_names_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'xref_id_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'xref_source_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'observation_id_list' => (
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



# Read fixed layout vocabulary once per search, not once per observation.
sub _layout_terms {
    my ($schema) = @_;
    my @names = ('plot','plant','subplot','tissue_sample','accession','cross','family_name',
        'plot_of','plant_of','subplot_of','tissue_sample_of','block','plot number',
        'row_number','col_number','plant_index_number','is a control');
    my $rows = $schema->storage->dbh->selectall_arrayref(q{
        SELECT cv.name,t.name,t.cvterm_id FROM cvterm t JOIN cv USING(cv_id)
        WHERE cv.name IN ('stock_type','stock_relationship','stock_property')
          AND t.name=ANY(?) AND t.is_obsolete=0
    }, undef, \@names);
    my %terms;
    for my $row (@$rows) {
        my $key="$row->[0]/$row->[1]";
        die "Ambiguous layout vocabulary $key; correct its metadata before reading analytical data.\n"
            if exists($terms{$key}) && $terms{$key} != $row->[2];
        $terms{$key}=$row->[2];
    }
    return \%terms;
}

# Validate the complete requested scope, including rows beyond the output page.
# Accession/name scope uses cached OR live matches: a newly corrected identity
# must cause an explicit refresh error rather than disappearing in an old filter.
sub _assert_cached_layout_identity {
    my ($schema,$from,$where,$omitted,$accessions,$unit_names,$terms) = @_;
    my @scope = grep {!$omitted->{$_}} @$where;
    push @scope, "materialized_phenotype_jsonb_table.observationunit_type_name IN ('plot','plant','subplot','tissue_sample')";
    my @edges;
    for my $kind (qw(plot plant subplot tissue_sample)) {
        my $type=$terms->{"stock_type/$kind"} || 0;
        my $relationship=$terms->{"stock_relationship/${kind}_of"} || 0;
        push @edges,"(u.type_id=$type AND r.type_id=$relationship)";
    }
    my $primary=join(',',map {$terms->{"stock_type/$_"} || 0} qw(accession cross family_name));
    my @matching;my @bind;
    if ($accessions && @$accessions) {
        push @matching,'(cached_germplasm_id=ANY(?::integer[]) OR live_germplasm_ids && ?::integer[])';
        push @bind,$accessions,$accessions;
    }
    if ($unit_names && @$unit_names) {
        my $names=[map {lc($_)} @$unit_names];
        push @matching,'(lower(cached_unit_name)=ANY(?::text[]) OR lower(live_unit_name)=ANY(?::text[]))';
        push @bind,$names,$names;
    }
    my $matching=@matching ? join(' AND ',@matching).' AND ' : '';
    my $sql=q{
        WITH requested_cache AS (
            SELECT DISTINCT materialized_phenotype_jsonb_table.observationunit_stock_id AS unit_id,
                materialized_phenotype_jsonb_table.observationunit_uniquename AS cached_unit_name,
                materialized_phenotype_jsonb_table.observationunit_type_name AS cached_unit_type,
                materialized_phenotype_jsonb_table.germplasm_stock_id AS cached_germplasm_id,
                materialized_phenotype_jsonb_table.germplasm_uniquename AS cached_germplasm_name
    }.$from.' WHERE '.join(' AND ',@scope).q{
        ), live_identity AS (
            SELECT c.*,u.stock_id AS live_unit_id,u.uniquename AS live_unit_name,ut.name AS live_unit_type,
                count(g.stock_id) AS identity_count,min(g.stock_id) AS live_germplasm_id,
                min(g.uniquename) AS live_germplasm_name,
                array_agg(g.stock_id) FILTER (WHERE g.stock_id IS NOT NULL) AS live_germplasm_ids
            FROM requested_cache c
            LEFT JOIN stock u ON u.stock_id=c.unit_id
            LEFT JOIN cvterm ut ON ut.cvterm_id=u.type_id
            LEFT JOIN stock_relationship r ON r.subject_id=u.stock_id AND (}.join(' OR ',@edges).q{)
            LEFT JOIN stock g ON g.stock_id=r.object_id AND g.type_id IN (}.$primary.q{)
            GROUP BY c.unit_id,c.cached_unit_name,c.cached_unit_type,c.cached_germplasm_id,
                c.cached_germplasm_name,u.stock_id,u.uniquename,ut.name
        ) SELECT * FROM live_identity WHERE }.$matching.q{(
            live_unit_id IS NULL OR live_unit_type IS DISTINCT FROM cached_unit_type OR identity_count<>1
            OR cached_unit_name IS DISTINCT FROM live_unit_name
            OR cached_germplasm_id IS DISTINCT FROM live_germplasm_id
            OR cached_germplasm_name IS DISTINCT FROM live_germplasm_name
        ) ORDER BY unit_id LIMIT 1
    };
    my $row=$schema->storage->dbh->selectrow_hashref($sql,undef,@bind);
    return if !$row;
    if (defined($row->{live_unit_id}) && $row->{live_unit_type} eq $row->{cached_unit_type} && $row->{identity_count} != 1) {
        die "Observation unit $row->{unit_id} has missing or ambiguous live germplasm identity; correct its layout before refreshing analytical data.\n";
    }
    die "Analytical phenotype cache is stale for observation unit $row->{unit_id}; refresh analytical data before using this result.\n";
}

# The materialized view stores these stockprop values as text (db/00203).
# Keep exact zero, leading zeros and NULL; row/column use only rank zero.
sub _project_live_layout_fields {
    my ($schema,$result,$terms) = @_;
    return if !@$result;
    my %columns=('block'=>'obsunit_block','plot number'=>'obsunit_plot_number',
        'row_number'=>'obsunit_row_number','col_number'=>'obsunit_col_number',
        'plant_index_number'=>'obsunit_plant_number','is a control'=>'obsunit_is_a_control');
    my %by_type=map {defined($terms->{"stock_property/$_"}) ? ($terms->{"stock_property/$_"}=>$_) : ()} keys %columns;
    my %ids=map {$_->{observationunit_stock_id}=>1} @$result;
    my %values=map {$_=>{map {$_=>undef} values %columns}} keys %ids;
    my $rows=$schema->storage->dbh->selectall_arrayref(
        'SELECT stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) AND type_id=ANY(?) ORDER BY stock_id,type_id,rank',
        undef,[keys %ids],[keys %by_type]);
    my %seen;
    for my $row (@$rows) {
        my ($id,$type,$value,$rank)=@$row;my $name=$by_type{$type};
        next if ($name eq 'row_number' || $name eq 'col_number') && $rank != 0;
        my $key=$columns{$name};
        if ($seen{$id}{$key}++ &&
            (defined($values{$id}{$key}) != defined($value) ||
             (defined($value) && $values{$id}{$key} ne $value))) {
            die "Observation unit $id has ambiguous live layout property $name; correct its metadata before using analytical data.\n";
        }
        $values{$id}{$key}=$value;
    }
    for my $row (@$result) {
        my $live=$values{$row->{observationunit_stock_id}};
        $row->{$_}=$live->{$_} for values %columns;
    }
}

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    print STDERR "Search Start:".localtime."\n";

    my $include_timestamp = $self->include_timestamp;
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';

    my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );
    my %synonym_hash_lookup = %{$stock_lookup->get_synonym_hash_lookup()};

    my $phenotype_outlier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotype_outlier', 'phenotype_property')->cvterm_id();
    
    my $phenotypeprop_sql = '';
    my $observations_column = 'materialized_phenotype_jsonb_table.observations';
    if ($self->exclude_phenotype_outlier) {
        $phenotypeprop_sql = " LEFT JOIN LATERAL (
            SELECT COALESCE(jsonb_agg(o.value), '[]'::jsonb) AS observations
            FROM jsonb_array_elements(materialized_phenotype_jsonb_table.observations) o
            WHERE NOT EXISTS (
                SELECT 1 FROM phenotypeprop pp
                WHERE pp.phenotype_id = (o.value->>'phenotype_id')::integer
                  AND pp.type_id = $phenotype_outlier_type_id
            )
        ) phenotype_qc ON true ";
        $observations_column = 'phenotype_qc.observations';
    }

    my $select_clause = "SELECT observationunit_stock_id, observationunit_uniquename, observationunit_type_name, germplasm_uniquename, germplasm_stock_id, rep, block, plot_number, row_number, col_number, plant_number, is_a_control, notes, trial_id, trial_name, trial_description, plot_width, plot_length, field_size, field_trial_is_planned_to_be_genotyped, field_trial_is_planned_to_cross, breeding_program_id, breeding_program_name, breeding_program_description, year, design, location_id, planting_date, harvest_date, folder_id, folder_name, folder_description, seedlot_transaction, seedlot_stock_id, seedlot_uniquename, seedlot_current_weight_gram, seedlot_current_count, seedlot_box_name, available_germplasm_seedlots, treatments, $observations_column, count(observationunit_stock_id) OVER() AS full_count, intercrop_germplasm";
    my $from_clause = " FROM materialized_phenotype_jsonb_table
                         LEFT JOIN (
                            select stock.stock_id, array_agg(db.name)::text[] as xref_sources, array_agg(dbxref.accession)::text[] as xref_ids
                            from stock
                            join stock_dbxref sd on stock.stock_id = sd.stock_id
                            join dbxref on sd.dbxref_id = dbxref.dbxref_id
                            join db on dbxref.db_id = db.db_id 
                            group by stock.stock_id
                         ) xref on xref.stock_id = materialized_phenotype_jsonb_table.observationunit_stock_id
                         $phenotypeprop_sql
                        ";
    my $order_clause = $self->order_by ? " ORDER BY ".$self->order_by : " ORDER BY trial_name, observationunit_uniquename";
    

    my @where_clause;
    my %identity_omitted;

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
    } elsif ($self->xref_id_list && scalar(@{$self->xref_id_list})>0) {
        my $xref_id_sql = _sql_from_arrayref($self->xref_id_list);
        push @where_clause, "xref.xref_ids && '{$xref_id_sql}'";
    } elsif ($self->xref_source_list && scalar(@{$self->xref_source_list})>0) {
        my $xref_source_sql = _sql_from_arrayref($self->xref_source_list);
        push @where_clause, "xref.xref_sources && '{$xref_source_sql}'";
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
        my $predicate="germplasm_stock_id in ($accession_sql)";
        push @where_clause,$predicate;
        $identity_omitted{$predicate}=1;
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
        push @where_clause, "observationunit_type_name = ".$schema->storage->dbh()->quote($self->data_level); #ONLY plot or plant or subplot or tissue_sample
    } else {
        push @where_clause, "(observationunit_type_name = 'plot' OR observationunit_type_name = 'plant' OR observationunit_type_name = 'subplot' OR observationunit_type_name = 'tissue_sample' OR observationunit_type_name = 'analysis_instance')"; #plots AND plants AND subplots AND tissue_samples AND analysis_instance
    }
    # TODO: Should use placeholders or DBI query api to protect against sql injection
    if ($self->observation_unit_names_list && scalar(@{$self->observation_unit_names_list})>0) {
        my @arrayref;
        my $dbh = $schema->storage->dbh();
        for my $name (@{$self->observation_unit_names_list}) {push @arrayref, $dbh->quote(lc $name);}
        my $sql = join ("," , @arrayref);
        my $predicate="LOWER(observationunit_uniquename) in ($sql)";
        push @where_clause,$predicate;
        $identity_omitted{$predicate}=1;
    }

    my @or_clause;

    my %trait_list_check;
    my $filter_trait_ids;
    my @trait_ids_or;
    if ($self->trait_list && scalar(@{$self->trait_list})>0) {
        print STDERR "A trait list was included\n";
        foreach (@{$self->trait_list}){
            if ($_){
                #print STDERR "Working on trait $_\n";
                push @trait_ids_or, "$observations_column @> '[{\"trait_id\" : $_}]'";
                $trait_list_check{$_}++;
                $filter_trait_ids = 1;
            }
        }
        if($filter_trait_ids) {
            push @where_clause, "(".join(" OR ", @trait_ids_or).")";
        }
    }

    my $filter_trait_names;
    my @trait_names_or;
    if ($self->trait_contains && scalar(@{$self->trait_contains})>0) {
        foreach (@{$self->trait_contains}) {
            if ($_){
                push @trait_names_or, "$observations_column @> '[{\"trait_name\" : \"$_\"}]'";
                $filter_trait_names = 1;
            }
        }
        if($filter_trait_names) {
            push @where_clause, "(".join(" OR ", @trait_names_or).")";
        }
    }

    my $filter_observation_ids;
    my @observation_ids_or;
    if ($self->observation_id_list && scalar(@{$self->observation_id_list})>0) {
        foreach (@{$self->observation_id_list}) {
            if ($_){
                push @observation_ids_or, "$observations_column @> '[{\"phenotype_id\" : $_}]'";
                $filter_observation_ids = 1;
            }
        }
        if($filter_observation_ids) {
            push @where_clause, "(".join(" OR ", @observation_ids_or).")";
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

    if ($self->exclude_phenotype_outlier) {
        push @where_clause, "jsonb_array_length($observations_column) > 0"
    };

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

    


    my $layout_terms=_layout_terms($schema);
    my $assert_identity=sub {
        _assert_cached_layout_identity($schema,$from_clause,\@where_clause,\%identity_omitted,
            $self->accession_list,$self->observation_unit_names_list,$layout_terms);
    };
    $assert_identity->();
    my $q = $select_clause . $from_clause . $where_clause . $or_clause . $order_clause . $limit_clause . $offset_clause;

    # print STDERR "QUERY: $q\n\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();
    my %location_id_lookup;
    while( my $r = $location_rs->next()){
        $location_id_lookup{$r->nd_geolocation_id} = $r->description;
    }

    # Get the trait ontology CVs
    my $type_cvterm = $schema->resultset("Cv::Cvterm")->search(
        {
            'me.name' => { -in => ['trait_ontology', 'composed_trait_ontology'] },
            'cv.name' => 'composable_cvtypes'
        },
        { join => 'cv' }
    );
    my @type_ids = $type_cvterm->get_column('cvterm_id')->all();
    my $trait_cv = $schema->resultset("Cv::Cvprop")->search({ type_id => { -in => \@type_ids } });
    my @trait_cv_ids = $trait_cv->get_column('cv_id')->all();

    # Create a map of trait cvterm_ids -> synonyms
    my %trait_synonyms;
    my $cvtermsynonym_rs = $schema->resultset("Cv::Cvtermsynonym")->search(
        { 
            'cvterm.cv_id' => { -in => \@trait_cv_ids }
        },
        {
            select => [ 'cvterm.cvterm_id', { min => 'synonym', -as => 'synonym' } ],
            as => ['cvterm_id', 'synonym'],
            join => 'cvterm',
            group_by => [ 'cvterm.cvterm_id' ]
        }
    );
    while ( my $r = $cvtermsynonym_rs->next() ) {
        my $cvterm_id = $r->get_column('cvterm_id');
        my $synonym = $r->get_column('synonym');
        $trait_synonyms{$cvterm_id} = $synonym;
    }

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;

    my $calendar_funcs = CXGN::Calendar->new({});
    my %unique_traits;

    while (my ($observationunit_stock_id, $observationunit_uniquename, $observationunit_type_name, $germplasm_uniquename, $germplasm_stock_id, $rep, $block, $plot_number, $row_number, $col_number, $plant_number, $is_a_control, $notes, $trial_id, $trial_name, $trial_description, $plot_width, $plot_length, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $planting_date, $harvest_date, $folder_id, $folder_name, $folder_description, $seedlot_transaction, $seedlot_stock_id, $seedlot_uniquename, $seedlot_current_weight_gram, $seedlot_current_count, $seedlot_box_name, $available_germplasm_seedlots, $treatments_json, $observations_json, $full_count, $intercrop_germplasm) = $h->fetchrow_array()) {
        my $harvest_date_value = $calendar_funcs->display_start_date($harvest_date);
        my $planting_date_value = $calendar_funcs->display_start_date($planting_date);
        my $synonyms = $synonym_hash_lookup{$germplasm_uniquename};
        my $location_name = $location_id ? $location_id_lookup{$location_id} : '';
        my $observations = JSON::XS->new->decode($observations_json);
        my $treatments = JSON::XS->new->decode($treatments_json);
        my $available_germplasm_seedlots = JSON::XS->new->decode($available_germplasm_seedlots);
        my $seedlot_transaction = $seedlot_transaction ? JSON::XS->new->decode($seedlot_transaction) : {};
        my $intercrop_germplasm = $intercrop_germplasm ? JSON::XS->new->decode($intercrop_germplasm) : [];

        my %ordered_observations;
        foreach (@$observations){
            $ordered_observations{$_->{phenotype_id}} = $_;
        }

        my @return_observations;
	my @observations_per_trait;
        foreach my $pheno_id (sort keys %ordered_observations){
	    
	    my $o = $ordered_observations{$pheno_id};

	    ###print STDERR "O: ".Dumper($o);
	    
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
	    
	    if ($filter_observation_ids){
		my $skip;
		foreach (@{$self->observation_id_list}){
		    if (index($o->{phenotype_id}, $_) == -1) {
			$skip = 1;
		    }
		}
		if ($skip){
		    next;
		}
	    }
	    
	    
	    
	    my $phenotype_uniquename = $o->{uniquename};
	    $unique_traits{$trait_name} = $o->{trait_id};
	    if ($include_timestamp){

		my $timestamp_value;
		my $operator_value;
		if ($phenotype_uniquename){
		    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
		    if ($p2){
			my ($timestamp, $operator_value) = split /  operator = /, $p2;
			# this regex won't work for timestamps saved in ISO 8601 format
			if ( $timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
			    $timestamp_value = $timestamp;
			}
		    }
		}
		$o->{timestamp} = $timestamp_value;
		
	    }
	    if (!defined($o->{operator}) || $o->{operator} eq '') {
		if ($phenotype_uniquename){
		    my ($p1, $p2) = split /date: /, $phenotype_uniquename;
		    if ($p2){
			my ($timestamp, $operator_value) = split /  operator = /, $p2;
			$o->{operator} = $operator_value;
		    }
		}
	    }

	    $o->{trait_synonym} = $trait_synonyms{$o->{trait_id}};

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
            intercrop_germplasm => $intercrop_germplasm
        };
    }
    #print STDERR Dumper \@result;

    _project_live_layout_fields($schema,\@result,$layout_terms);
    print STDERR "Search End:".localtime."\n";
    return (\@result, \%unique_traits, \%trait_synonyms);
}

sub _sql_from_arrayref {
    my $arrayref = shift;
    my $sql = join ("," , @$arrayref);
    return $sql;
}


# Identity and later live enrichment belong to the same read snapshot. The
# shared helper leaves a surrounding caller-owned transaction unchanged.
around 'search' => sub {
    my ($next,$self,@args)=@_;
    return CXGN::DB::ReadSnapshot::run($self->bcs_schema, sub {$next->($self,@args)});
};


1;
