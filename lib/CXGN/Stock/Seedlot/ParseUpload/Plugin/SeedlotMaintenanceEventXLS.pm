package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotMaintenanceEventXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::Onto;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $event_ontology_root = $self->get_event_ontology_root();
    my $parser = Spreadsheet::ParseExcel->new();

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

    # Open the excel file
    my $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        push(@error_messages, $parser->error());
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Get the first worksheet
    my $worksheet = ( $excel_obj->worksheets() )[0];
    if ( !$worksheet ) {
        push(@error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file");
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Get row/col counts
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min) != 5 || ($row_max - $row_min) < 1 ) { 
        push(@error_messages, "Spreadsheet is missing header or contains no rows");
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Get column headers
    my $seedlot_head;
    my $type_head;
    my $value_head;
    my $notes_head;
    my $operator_head;
    my $timestamp_head;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $type_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $value_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $notes_head  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $operator_head  = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $timestamp_head  = $worksheet->get_cell(0,5)->value();
    }

    if (!$seedlot_head || $seedlot_head ne 'seedlot' ) {
        push @error_messages, "Cell A1: seedlot is missing from the header";
    }
    if (!$type_head || $type_head ne 'type') {
        push @error_messages, "Cell B1: type is missing from the header";
    }
    if (!$value_head || $value_head ne 'value') {
        push @error_messages, "Cell C1: value is missing from the header";
    }
    if (!$operator_head || $operator_head ne 'operator') {
        push @error_messages, "Cell D1: operator is missing from the header";
    }
    if (!$timestamp_head || $timestamp_head ne 'timestamp') {
        push @error_messages, "Cell E1: timestamp is missing from the header";
    }


    # Check rows for valid seedlot names, event names, values, operators, and timestamps
    my %seen_seedlot_names;
    my %seen_event_types;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot;
        my $type;
        my $value;
        my $notes = '';
        my $operator;
        my $timestamp;

        if ($worksheet->get_cell($row,0)) {
            $seedlot = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $type = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $value = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $notes =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $operator =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $timestamp =  $worksheet->get_cell($row,5)->value();
        }

        if (!$seedlot || $seedlot eq '') {
            push(@error_messages, "Cell A$row_name: seedlot missing.");
        }
        elsif ($seedlot =~ /\s/ || $seedlot =~ /\// || $seedlot =~ /\\/) {
            push(@error_messages, "Cell A$row_name: seedlot must not contain spaces or slashes.");
        }
        else {
            $seen_seedlot_names{$seedlot}=1;
        }
        if (!$type || $type eq '') {
            push(@error_messages, "Cell B$row_name: type missing.");
        }
        else {
            $seen_event_types{$type}=1;
        }
        if (!$value || $value eq '') {
            push(@error_messages, "Cell C$row_name: value missing.");
        }
        if (!$operator || $operator eq '') {
            push(@error_messages, "Cell E$row_name: operator missing.");
        }
        if (!$timestamp || $timestamp eq '') {
            push(@error_messages, "Cell F$row_name: timestamp missing.");
        }
        elsif ( $timestamp !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/ ) {
            push(@error_messages, "Cell F$row_name: timestamp not valid format [YYYY-MM-DD HH:MM:SS]");
        }
    }

    # Check validity of seedlot names
    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($schema, 'seedlots', \@seedlots)->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        push(@error_messages, "The following seedlots are not in the database: ".join(',',@seedlots_missing));
        $errors{'missing_seedlots'} = \@seedlots_missing;
    }

    # Check validity of event types
    my @events = keys %seen_event_types;
    my @events_missing = ();
    foreach my $event (@events) {
        if ( !exists $valid_events{$event} ) {
            push(@events_missing, $event);
        }
    }
    if (scalar(@events_missing) > 0) {
        push(@error_messages, "The following events are not valid: ".join(',',@events_missing));
        $errors{'missing_events'} = \@events_missing;
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1;
}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $event_ontology_root = $self->get_event_ontology_root();
    my $parser = Spreadsheet::ParseExcel->new();

    print STDERR "===> PARSE SME FILE: $filename\n";

    # Get Excel file and worksheet
    my $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }
    my $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

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
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        if ($worksheet->get_cell($row,0)) {
            my $seedlot = $worksheet->get_cell($row,0)->value();
            $seedlot =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$seedlot}=1;
        }
    }
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seedlots },
        'type_id' => $seedlot_cvterm_id
    });
    while (my $r=$seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    # Process the events
    my %events_by_seedlot;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot;
        my $type;
        my $value;
        my $notes = '';
        my $operator;
        my $timestamp;

        if ($worksheet->get_cell($row,0)) {
            $seedlot = $worksheet->get_cell($row,0)->value();
            $seedlot =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $type = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $value = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $notes =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $operator =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $timestamp =  $worksheet->get_cell($row,5)->value();
        }

        my $seedlot_id = $seedlot_lookup{$seedlot};
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