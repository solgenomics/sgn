package CXGN::Stock::Seedlot::ParseUpload::Plugin::AccessionsCrossesToExistingSeedlotsGeneric;

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
        required_columns => [ 'from_content_name', 'to_seedlot_name', 'operator_name'],
        optional_columns => ['amount', 'weight_gram', 'transaction_description'],
        column_aliases => {
            'from_stockcontent_name' => ['from content name', 'content_name', 'content name', 'accession_name', 'accession name', 'accession', 'from_accession_name', 'from accession name', 'cross_unique_id', 'cross unique id', 'cross', 'from_cross_unique_id', 'from cross unique is'],
            'to_seedlot_name' => ['to seedlot name', 'seedlot_name', 'seedlot name'],
            'operator_name' => ['operator name', 'operator'],
            'weight_gram' => ['weight(g)'],
            'transaction_description' => ['transaction description', 'description'],
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

    my @seedlot_content_pairs;
    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $content_name = $row->{'from_content_name'};
        my $seedlot_name = $row->{'to_seedlot_name'};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight_gram'};

        if ((!$amount || $amount eq '') && (!$weight || $weight eq '')) {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount.";
        }

        push @seedlot_content_pairs, [$seedlot_name, $content_name];
    }

    my $seen_content_names = $parsed_values->{'from_content_name'};
    my $seen_seedlot_names = $parsed_values->{'to_seedlot_name'};

    my $accessions_crosses_validator = CXGN::List::Validate->new();
    my @accessions_crosses_missing = @{$accessions_crosses_validator->validate($schema,'accessions_or_crosses',$seen_content_names)->{'missing'}};

    if (scalar(@accessions_crosses_missing) > 0) {
        push @error_messages, "The following accessions or cross unique ids are not in the database as uniquenames: ".join(',',@accessions_crosses_missing);
    }

    my $seedlots_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlots_validator->validate($schema,'seedlots',$seen_seedlot_names)->{'missing'}};

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database as uniquenames: ".join(',',@seedlots_missing);
    }

    my $pairs_error = CXGN::Stock::Seedlot->verify_seedlot_accessions_crosses($schema, \@seedlot_content_pairs);
    if (exists($pairs_error->{error})){
        push @error_messages, $pairs_error->{error};
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

    my $content_names = $parsed_values->{'from_content_name'};
    my $seedlot_names = $parsed_values->{'to_seedlot_name'};

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my $content_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $content_names },
        'type_id' => [$accession_cvterm_id, $cross_cvterm_id]
    });

    my %content_lookup;
    while (my $r = $content_rs->next){
        $content_lookup{$r->uniquename} = $r->stock_id;
    }

    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $seedlot_names },
        'type_id' => $seedlot_cvterm_id
    });

    my %seedlot_lookup;
    while (my $r = $seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    my @transactions;
    for my $row ( @$parsed_data ) {
        my $row_num;
        my $content_name;
        my $seedlot_name;
        my $amount;
        my $weight;
        my $operator_name;
        my $description;

        $row_num = $row->{_row};
        $content_name = $row->{'from_content_name'};
        $seedlot_name = $row->{'to_seedlot_name'};
        $amount = $row->{'amount'};
        $weight = $row->{'weight_gram'};
        $operator_name = $row->{'operator_name'};
        $description = $row->{'transaction_description'};

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        my $content_stock_id = $content_lookup{$content_name};
        my $seedlot_stock_id = $seedlot_lookup{$seedlot_name};

        push @transactions, {
            from_stock_name => $content_name,
            from_stock_id => $content_stock_id,
            to_seedlot_name => $seedlot_name,
            to_seedlot_id => $seedlot_stock_id,
            amount => $amount,
            weight => $weight,
            transaction_description => $description,
            operator => $operator_name
        }
    }

    $parsed_seedlots{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;

}


1;
