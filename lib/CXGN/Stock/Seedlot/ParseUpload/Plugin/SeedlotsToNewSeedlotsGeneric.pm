package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotsToNewSeedlotsGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;
    my %missing_accessions;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'from_seedlot_name', 'operator_name', 'to_new_seedlot_name', 'new_seedlot_box_name'],
        optional_columns => ['amount', 'weight(g)', 'transaction_description', 'new_seedlot_description', 'new_seedlot_quality'],
        column_aliases => {
            'from_seedlot_name' => ['from seedlot name'],
            'operator_name' => ['operator name', 'operator'],
            'to_new_seedlot_name' => ['to new seedlot name'],
            'new_seedlot_box_name' => ['new seedlot box name'],
            'weight(g)' => ['weight_gram'],
            'transaction_description' => ['transaction description'],
            'new_seedlot_description' => ['new seedlot description'],
            'new_seedlot_quality' => ['new seedlot quality']
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

    my %check_new_seedlot_content;
    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $from_seedlot_name = $row->{'from_seedlot_name'};
        my $to_new_seedlot_name = $row->{'to_new_seedlot_name'};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight_gram'};

        if (defined $from_seedlot_name && defined $to_new_seedlot_name) {
            $check_new_seedlot_content{$to_new_seedlot_name}{$from_seedlot_name}++;
        }

        if ((!$amount || $amount eq '') && (!$weight || $weight eq '')) {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount.";
        }
    }

    my $seen_from_seedlot_names = $parsed_values->{'from_seedlot_name'};
    my $seen_to_new_seedlot_names = $parsed_values->{'to_new_seedlot_name'};

    my $validation = $existing_seedlot_validator->validate($schema,'seedlots', $seen_from_seedlot_name);
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


    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_to_new_seedlot_names }
    });

    while (my $seedlot_r=$seedlot_rs->next){
        push @error_messages, "New seedlot name already exists in database: ".$seedlot_r->uniquename;
    }

    foreach my $new_sl (keys %check_new_seedlot_content){
        my @check_info = ();
        my $stored_seedlots = $check_new_seedlot_content{$new_sl};
        my $number_of_associated_seedlots = keys %{$stored_seedlots};
        if ($number_of_associated_seedlots > 1) {
            my $content_error = CXGN::Stock::Seedlot->verify_all_seedlots_compatibility($schema, [$new_sl, $check_new_seedlot_content{$new_sl}]);
            if (exists($content_error->{error})){
                push @error_messages, $content_error->{error};
            }
        }
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
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my %parsed_seedlots;

    my $from_seedlot_names = $parsed_values->{'from_seedlot_name'};
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $from_seedlot_names },
        'type_id' => $seedlot_cvterm_id
    });

    my %seedlot_lookup;
    while (my $r = $seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    my @transactions;
    for my $row ( @$parsed_data ) {
        my $row_num;
        my $from_seedlot_name;
        my $to_seedlot_name;
        my $amount;
        my $weight;
        my $operator_name;
        my $description;

        $row_num = $row->{_row};
        $from_seedlot_name = $row->{'from_seedlot_name'};
        $amount = $row->{'amount'};
        $weight = $row->{'weight(g)'};
        $operator_name = $row->{'operator_name'};
        $transaction_description = $row->{'transaction_description'};
        $to_new_seedlot_name = $row->{'to_new_seedlot_name'};
        $new_seedlot_box_name = $row->{'new_seedlot_box_name'};
        $new_seedlot_description = $row->{'new_seedlot_description'};
        $new_seedlot_quality = $row->{'new_seedlot_quality'};

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        my $from_seedlot_id = $seedlot_lookup{$from_seedlot_name};
        my $content_id = CXGN::Stock::Seedlot->get_content_id($schema, $from_seedlot_id);

        push @transactions, {
            from_seedlot_name => $from_seedlot_name,
            from_seedlot_id => $from_seedlot_id,
            to_new_seedlot_name => $to_new_seedlot_name,
            amount => $amount,
            weight => $weight,
            transaction_description => $transaction_description,
            operator => $operator_name,
            new_seedlot_info => [$to_new_seedlot_name, $content_id, $new_seedlot_description, $new_seedlot_box_name, $new_seedlot_quality]
        }
    }

    $parsed_seedlots{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;

}


1;
