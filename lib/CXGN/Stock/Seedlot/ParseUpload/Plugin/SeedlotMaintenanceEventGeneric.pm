package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotMaintenanceEventGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Onto;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $event_ontology_root = $self->get_event_ontology_root();

    # Errors in validation
    my @error_messages;
    my %errors;
    my %missing_seedlots;
    my %unknown_event_types;

    # Get cvterm_id of ontology root
    if ( !$event_ontology_root || $event_ontology_root eq '' ) {
        push(@error_messages, "Seedlot Maintenance Event ontology not set!");
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ($db_name, $accession) = split ":", $event_ontology_root;
    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
    my $root_cvterm = $dbxref->cvterm;
    my $root_cvterm_id = $root_cvterm->cvterm_id;

    # Get valid events from ontology
    my %valid_events;
    my $onto = CXGN::Onto->new({ schema => $schema });
    my $ontology = $onto->get_children($root_cvterm_id);
    foreach my $category (@$ontology) {
        my $events = $category->{children};
        foreach my $event (@$events) {
            $valid_events{$event->{name}} = 1;
        }
    }

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'seedlot', 'type', 'value', 'operator', 'timestamp'],
        optional_columns => ['notes'],
        column_aliases => {
            'seedlot' => ['seedlot_name', 'seedlot name'],
            'operator' => ['operator_name', 'operator name'],
        },
    );

    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [
            "The following columns are not recognized: " . join(', ', @$additional_columns) . ". Please check the spreadsheet format for the allowed columns."
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $seedlot = $row->{'seedlot'};
        if ($seedlot =~ /\s/ || $seedlot =~ /\// || $seedlot =~ /\\/) {
            push(@error_messages, "Row: $row_num: seedlot must not contain spaces or slashes.");
        }

        my $timestamp = $row->{'timestamp'};
        if ( $timestamp !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/ ) {
            push(@error_messages, "Row: $row_num: timestamp not valid format [YYYY-MM-DD HH:MM:SS]");
        }

    }

    my $seen_seedlot_names = $parsed_values->{'seedlot'};
    my $existing_seedlot_validator = CXGN::List::Validate->new();
    my $validation = $existing_seedlot_validator->validate($schema,'seedlots', $seen_from_seedlot_names);
    my @all_seedlots_missing = @{$validation->{missing}};
    my @seedlots_discarded = @{$validation->{discarded}};
    my @seedlots_missing;
    my %discarded_lookup = map {$_ => 1} @seedlot_discarded;
    foreach my $seedlot (@all_seedlots_missing) {
        if ($discarded_lookup{$seedlot}) {
            next;
        } else {
            push @seedlots_missing, $seedlot;
        }
    }

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database: ".join(',',@seedlots_missing);
    }

    if (scalar(@seedlots_discarded) > 0) {
        push @error_messages, "The following seedlots are marked as DISCARDED: ".join(',',@seedlots_discarded);
    }

    my $seen_events = $parsed_values->{'type'};
    my @events_missing = ();
    foreach my $event (@seen_events) {
        if ( !exists $valid_events{$event} ) {
            push(@events_missing, $event);
        }
    }
    if (scalar(@events_missing) > 0) {
        push(@error_messages, "The following events are not valid: ".join(',',@events_missing));
        $errors{'missing_events'} = \@events_missing;
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    } else {
        $self->_set_parsed_data($parsed);
    }

    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $event_ontology_root = $self->get_event_ontology_root();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my %parsed_result;
    my %seen_seedlot_names;

    my $seedlot_names = $parsed_values->{'seedlot_name'};

    # Generate lookup of event name -> cvterm id
    my %event_lookup;
    my ($db_name, $accession) = split ":", $event_ontology_root;
    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
    my $root_cvterm = $dbxref->cvterm;
    my $root_cvterm_id = $root_cvterm->cvterm_id;
    my $onto = CXGN::Onto->new({ schema => $schema });
    my $ontology = $onto->get_children($root_cvterm_id);
    foreach my $category (@$ontology) {
        my $events = $category->{children};
        foreach my $event (@$events) {
            $event_lookup{$event->{name}} = $event->{cvterm_id};
        }
    }

    # Generate lookup of seedlot name -> stock id
    my %seedlot_lookup;

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $seedlot_names },
        'type_id' => $seedlot_cvterm_id
    });
    while (my $r=$seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    # Process the events
    my %events_by_seedlot;
    for my $row (@$parsed_data) {
        my $row_num;
        my $seedlot;
        my $type;
        my $value;
        my $operator;
        my $timestamp;
        my $notes;
        my $seedlot_id;
        $row_num = $row->{_row};
        $seedlot = $row->{'seedlot'};
        $type = $row->{'type'};
        $value = $row->{'value'};
        $operator = $row->{'operator'};
        $timestamp = $row->{'timestamp'};
        $notes = $row->{'notes'};
        $seedlot_id = $seedlot_lookup{$seedlot};
        my %event = (
            cvterm_id => $event_lookup{$type},
            value => $value,
            notes => $notes,
            operator => $operator,
            timestamp => $timestamp
        );
        push( @{$events_by_seedlot{$seedlot_id}}, \%event );
    }
    $self->_set_parsed_data(\%events_by_seedlot);
    return 1;

}


1;
