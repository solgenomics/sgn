package CXGN::BrAPI::v2::Events;

use Moose;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use CXGN::Trial;
use CXGN::BrAPI::Pagination;
use CXGN::BrAPI::JSONResponse;
use Time::Piece;

extends 'CXGN::BrAPI::v2::Common';

sub search {
    my $self = shift;
    my $params = shift;
    my $page_size = $self->page_size;
    my $page = $self->page;
    my $status = $self->status;
    my $schema = $self->bcs_schema;

    my $studydbid_arrayref   = $params->{studyDbId}          || ($params->{studyDbIds}          || ());
    my $obsunitdbid_arrayref = $params->{observationUnitDbId} || ($params->{observationUnitDbIds} || ());
    my $eventdbid_arrayref   = $params->{eventDbId}           || ($params->{eventDbIds}           || ());
    my $eventtypedbid_arrayref = $params->{eventType}         || ($params->{eventTypes}           || ());

    my $field_layout_type_cvterm_id  = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout',      'experiment_type' )->cvterm_id();
    my $management_regime_cvterm_id  = SGN::Model::Cvterm->get_cvterm_row($schema, 'management_regime', 'project_property')->cvterm_id();
    my $project_year_cvterm_id       = SGN::Model::Cvterm->get_cvterm_row($schema, 'project year',      'project_property')->cvterm_id();

    # Resolve observationUnitDbIds to study IDs
    if ($obsunitdbid_arrayref && scalar(@$obsunitdbid_arrayref) > 0) {
        my $stock_string = join ',', map { int($_) } @$obsunitdbid_arrayref;
        my $q0 = "SELECT DISTINCT nep.project_id
            FROM nd_experiment_project nep
            JOIN nd_experiment ne USING(nd_experiment_id)
            JOIN nd_experiment_stock nes USING(nd_experiment_id)
            WHERE ne.type_id = $field_layout_type_cvterm_id
            AND nes.stock_id IN ($stock_string)";
        my $h0 = $schema->storage->dbh()->prepare($q0);
        $h0->execute();
        while (my ($trial_id) = $h0->fetchrow_array()) {
            push @$studydbid_arrayref, $trial_id;
        }
    }

    unless ($studydbid_arrayref && scalar(@$studydbid_arrayref) > 0) {
        my $pagination = CXGN::BrAPI::Pagination->pagination_response(0, $page_size, $page);
        return CXGN::BrAPI::JSONResponse->return_success({ data => [] }, $pagination, [], $status, 'Event search result constructed');
    }

    my $study_id_string = join ',', map { int($_) } @$studydbid_arrayref;

    # Study metadata
    my %study_meta;
    my $q_study = "SELECT project.project_id, project.name, project.description, project.create_date, pp.value
        FROM project
        LEFT JOIN projectprop pp ON project.project_id = pp.project_id AND pp.type_id = $project_year_cvterm_id
        WHERE project.project_id IN ($study_id_string)";
    my $h_study = $schema->storage->dbh()->prepare($q_study);
    $h_study->execute();
    while (my ($pid, $pname, $pdesc, $pcreate, $pyear) = $h_study->fetchrow_array()) {
        $study_meta{$pid} = { name => $pname, description => $pdesc, create_date => $pcreate, year => $pyear };
    }

    # All stocks per study (used for management factor observationUnitDbIds)
    my %study_stocks;
    my $q_stocks = "SELECT DISTINCT nep.project_id, nes.stock_id
        FROM nd_experiment_project nep
        JOIN nd_experiment ne USING(nd_experiment_id)
        JOIN nd_experiment_stock nes USING(nd_experiment_id)
        WHERE ne.type_id = $field_layout_type_cvterm_id
        AND nep.project_id IN ($study_id_string)";
    my $h_stocks = $schema->storage->dbh()->prepare($q_stocks);
    $h_stocks->execute();
    while (my ($pid, $sid) = $h_stocks->fetchrow_array()) {
        push @{$study_stocks{$pid}}, "$sid";
    }

    # Treatments from the phenotype table
    # Unique treatment = (trial_id, db.name:dbxref.accession, phenotype.value)
    my %treatment_groups;
    my $q_treatments = "SELECT
        nep.project_id,
        db.name,
        db.name || ':' || dbxref.accession,
        cvterm.definition,
        phenotype.value,
        phenotype.collect_date::text,
        nes.stock_id
        FROM phenotype
        JOIN nd_experiment_phenotype USING(phenotype_id)
        JOIN nd_experiment_stock nes USING(nd_experiment_id)
        JOIN nd_experiment_project nep USING(nd_experiment_id)
        JOIN cvterm ON phenotype.cvalue_id = cvterm.cvterm_id
        JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id
        JOIN db ON dbxref.db_id = db.db_id
        WHERE db.name LIKE '\%TREATMENT\%'
        AND nep.project_id IN ($study_id_string)";
    my $h_treatments = $schema->storage->dbh()->prepare($q_treatments);
    $h_treatments->execute();
    while (my ($trial_id, $treatment_db, $treatment_id_str, $treatment_def, $treatment_value, $treatment_ts, $stock_id) = $h_treatments->fetchrow_array()) {
        my $key = "$trial_id\0$treatment_id_str\0$treatment_value";
        my $tg = $treatment_groups{$key} //= {
            trial_id         => $trial_id,
            treatment_db     => $treatment_db,
            treatment_id_str => $treatment_id_str,
            treatment_def    => $treatment_def,
            treatment_value  => $treatment_value,
            stock_ids        => {},
            timestamps       => {},
        };
        $tg->{stock_ids}{"$stock_id"} = 1;
        $tg->{timestamps}{$treatment_ts} = 1 if defined $treatment_ts && $treatment_ts ne '';
    }

    # Management factors from management regime json 
    my @mgmt_factor_rows;
    my $q_mgmt = "SELECT project_id, value FROM projectprop WHERE type_id = $management_regime_cvterm_id AND project_id IN ($study_id_string)";
    my $h_mgmt = $schema->storage->dbh()->prepare($q_mgmt);
    $h_mgmt->execute();
    while (my ($trial_id, $json_value) = $h_mgmt->fetchrow_array()) {
        my $factors = eval { decode_json($json_value) } // [];
        for my $factor (@$factors) {
            push @mgmt_factor_rows, { trial_id => $trial_id, factor => $factor };
        }
    }

    my @data;

    # Treatment events — one event per unique (trial, treatment ID, value) combination
    for my $key (sort keys %treatment_groups) {
        my $tg      = $treatment_groups{$key};
        my $trial_id = $tg->{trial_id};
        my $meta    = $study_meta{$trial_id} // {};

        my @discrete_dates = map { _format_timestamp($_) } sort keys %{$tg->{timestamps}};
        my @stock_ids      = sort keys %{$tg->{stock_ids}};

        push @data, {
            additionalInfo => {
                year             => $meta->{year},
                studyDescription => $meta->{description},
                eventCreateDate  => undef,
                studyCreateDate  => $meta->{create_date},
            },
            date => {
                discreteDates => \@discrete_dates,
                endDate       => undef,
                startDate     => undef,
            },
            eventDbId            => $tg->{treatment_id_str},
            eventDescription     => $tg->{treatment_def} // $tg->{treatment_id_str},
            eventParameters      => [ { value => $tg->{treatment_value} } ],
            eventType            => 'treatment',
            eventTypeDbId        => $tg->{treatment_db},
            observationUnitDbIds => \@stock_ids,
            studyDbId            => qq|$trial_id|,
            studyName            => $meta->{name},
        };
    }

    # Management factor events — one event per factor
    for my $mf (@mgmt_factor_rows) {
        my $trial_id   = $mf->{trial_id};
        my $factor     = $mf->{factor};
        my $meta       = $study_meta{$trial_id} // {};
        my $all_stocks = $study_stocks{$trial_id} // [];
        my $factor_type = $factor->{type} // '';

        my @discrete_dates = map { _format_timestamp($_) } @{$factor->{completions} // []};

        push @data, {
            additionalInfo => {
                year             => $meta->{year},
                studyDescription => $meta->{description},
                eventCreateDate  => undef,
                studyCreateDate  => $meta->{create_date},
            },
            date => {
                discreteDates => \@discrete_dates,
                endDate       => $factor->{end_date},
                startDate     => $factor->{start_date},
            },
            eventDbId            => 'ManagementFactor',
            eventDescription     => $factor->{description},
            eventParameters      => [],
            eventType            => $factor_type,
            eventTypeDbId        => $factor_type,
            observationUnitDbIds => $all_stocks,
            studyDbId            => qq|$trial_id|,
            studyName            => $meta->{name},
        };
    }

    # Post-filter by eventDbId
    if ($eventdbid_arrayref && scalar(@$eventdbid_arrayref) > 0) {
        my %filter = map { $_ => 1 } @$eventdbid_arrayref;
        @data = grep { $filter{$_->{eventDbId}} } @data;
    }

    # Post-filter by eventType
    if ($eventtypedbid_arrayref && scalar(@$eventtypedbid_arrayref) > 0) {
        my %filter = map { $_ => 1 } @$eventtypedbid_arrayref;
        @data = grep { $filter{$_->{eventType}} } @data;
    }

    my $total_count = scalar(@data);
    my $start_index = $page * $page_size;
    my $end_index   = $start_index + $page_size - 1;
    $end_index = $#data if $total_count > 0 && $end_index > $#data;
    my @paged_data  = ($total_count > 0 && $start_index <= $#data) ? @data[$start_index .. $end_index] : ();

    my $pagination = CXGN::BrAPI::Pagination->pagination_response($total_count, $page_size, $page);
    return CXGN::BrAPI::JSONResponse->return_success({ data => \@paged_data }, $pagination, [], $status, 'Event search result constructed');
}


sub _format_timestamp {
    my $str = shift;
    unless (defined $str && $str ne '') {
        return;
    }

    my $tp;
    for my $fmt ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d') {
        eval { $tp = Time::Piece->strptime($str, $fmt); };
        last unless $@;
    }
    return $tp ? $tp->strftime('%Y-%m-%dT%H:%M:%SZ') : $str;
}


1;
