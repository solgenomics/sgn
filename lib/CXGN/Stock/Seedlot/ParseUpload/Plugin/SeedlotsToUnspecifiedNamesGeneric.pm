package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotsToUnspecifiedNamesGeneric;

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
        required_columns => [ 'from_seedlot_name', 'operator_name', 'transaction_description'],
        optional_columns => ['amount', 'weight(g)'],
        column_aliases => {
            'from_seedlot_name' => ['from seedlot name'],
            'operator_name' => ['operator name', 'operator'],
            'weight(g)' => ['weight_gram'],
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

    my @from_seedlot_to_seedlot_pairs;
    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight_gram'};

        if ((!$amount || $amount eq '') && (!$weight || $weight eq '')) {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount.";
        }

    }

    my $seen_from_seedlot_names = $parsed_values->{'from_seedlot_name'};

    my $from_seedlots_validator = CXGN::List::Validate->new();
    my @from_seedlots_missing = @{$from_seedlots_validator->validate($schema,'seedlots',$seen_from_seedlot_names)->{'missing'}};

    if (scalar(@from_seedlots_missing) > 0) {
        push @error_messages, "The following from seedlot names are not in the database as uniquenames: ".join(',',@from_seedlots_missing);
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
        my $amount;
        my $weight;
        my $operator_name;
        my $description;

        $row_num = $row->{_row};
        $from_seedlot_name = $row->{'from_seedlot_name'};
        $amount = $row->{'amount'};
        $weight = $row->{'weight_gram'};
        $operator_name = $row->{'operator_name'};
        $description = $row->{'transaction_description'};

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        my $from_seedlot_id = $seedlot_lookup{$from_seedlot_name};

        push @transactions, {
            from_seedlot_name => $from_seedlot_name,
            from_seedlot_id => $from_seedlot_id,
            to_seedlot_name => $from_seedlot_name,
            to_seedlot_id => $from_seedlot_id,
            amount => $amount,
            weight => $weight,
            transaction_description => $description,
            operator => $operator_name,
            factor => -1
        }
    }

    $parsed_seedlots{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;

}


1;
