package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotInventoryGeneric;

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
    my %missing_seedlots;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'box_id', 'seed_id', 'inventory_date', 'inventory_person'],
        optional_columns => ['weight_gram', 'amount'],
        column_aliases => {
            'box_id' => ['box id', 'box name', 'box_name'],
            'seed_id' => ['seed id', 'seedlot_name', 'seedlot name'],
            'inventory_date' => ['inventory date'],
            'inventory_person' => ['inventory person'],
            'weight_gram' => ['weight(g)', 'weight gram'],
            'amount' => ['count'],

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
        my $seedlot_name = $row->{'seedlot_id'};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight_gram'};

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount.";
        }
    }

    my $seen_seedlot_names = $parsed_values->{'seedlot_id'};

    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',$seen_seedlot_names)->{'missing'}};

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database as uniquenames: ".join(',',@seedlots_missing);
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
    my %parsed_result;
    my %seen_seedlot_names;

    my $accession_names = $parsed_values->{'accession_name'};
    my $seedlot_names = $parsed_values->{'seedlot_name'};

    for my $row (@$parsed_data) {
        my $row_num;
        my $seed_id;
        my $box_id;
        my $inventory_date;
        my $inventory_person;
        my $weight;
        my $amount;
        $row_num = $row->{_row};
        $seed_id = $row->{'seed_id'};
        $box_id = $row->{'box_id'};
        $inventory_date = $row->{'inventory_date'};
        $inventory_person = $row->{'inventory_person'};
        $weight = $row->{'weight_gram'};
        $amount = $row->{'amount'};
        $seen_seedlot_names{$seed_id}++;

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        $parsed_result{$seed_id} = {
            box_id => $box_id,
            seedlot_name => $seed_id,
            inventory_date => $inventory_date,
            inventory_person => $inventory_person,
            weight_gram => $weight,
            amount => $amount
        };
    }

    my @seedlot_names = keys %seen_seedlot_names;
    my $seedlots_rs = $schema->resultset("Stock::Stock")->search({uniquename => {-in => \@seedlot_names}});
    while (my $r = $seedlots_rs->next){
        $parsed_result{$r->uniquename}{seedlot_id} = $r->stock_id;
    }
    
    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
