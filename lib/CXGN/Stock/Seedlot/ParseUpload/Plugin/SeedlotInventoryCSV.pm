package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotInventoryCSV;

use Moose::Role;
use JSON;
use Data::Dumper;
use Text::CSV;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $delimiter = ',';
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @columns;
    if ($csv->parse($header_row)) {
        @columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $num_cols = scalar(@columns);
    if ($num_cols != 5){
        push @error_messages, 'Header row must contain: "box_id","seed_id","inventory_date","inventory_person","weight_gram"';
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }


    my $box_id_head = $columns[0];
    $box_id_head =~ s/^\s+|\s+$//g;

    my $seed_id_head = $columns[1];
    $seed_id_head =~ s/^\s+|\s+$//g;

    my $inventory_date_head = $columns[2];
    $inventory_date_head =~ s/^\s+|\s+$//g;

    my $inventory_person_head = $columns[3];
    $inventory_person_head =~ s/^\s+|\s+$//g;

    my $weight_gram_head = $columns[4];
    $weight_gram_head =~ s/^\s+|\s+$//g;

    if ( $box_id_head ne "box_id" ||
        $seed_id_head ne "seed_id" ||
        $inventory_date_head ne "inventory_date" ||
        $inventory_person_head ne "inventory_person" ||
        $weight_gram_head ne "weight_gram" ) {
            push @error_messages, 'File contents incorrect. Header row must contain: "box_id","seed_id","inventory_date","inventory_person","weight_gram"';
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
    }

    my %seen_seedlot_names;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        if (scalar(@columns) != $num_cols){
            push @error_messages, 'All lines must have same number of columns as header! Error on row: '.$row;
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        if (!$columns[0] || $columns[0] eq ''){
            push @error_messages, 'The first column must contain a box_id on row: '.$row;
        }
        if (!$columns[1] || $columns[1] eq ''){
            push @error_messages, 'The second column must contain a seed_id on row: '.$row;
        } else {
            $columns[1] =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
            $seen_seedlot_names{$columns[1]}++;
        }
        if (!$columns[2] || $columns[2] eq ''){
            push @error_messages, 'The third column must contain an inventory_date on row: '.$row;
        }
        if (!$columns[3] || $columns[3] eq ''){
            push @error_messages, 'The fourth column must contain an inventory_person on row: '.$row;
        }
        if (!defined($columns[4]) || $columns[4] eq ''){
            push @error_messages, 'The fifth column must contain weight_gram on row: '.$row;
        }
    }

    my @seedlots = keys %seen_seedlot_names;
    my $seedlots_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlots_validator->validate($schema,'seedlots',\@seedlots)->{'missing'}};

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database or are marked as discarded: ".join(',',@seedlots_missing);
        $errors{'missing_seedlots'} = \@seedlots_missing;
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
    my $delimiter = ',';
    my %parse_result;
    my @error_messages;
    my %errors;

    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh, '<', $filename)
        or die "Could not open file '$filename' $!";

    if (!$fh) {
        push @error_messages, "Could not read file. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $header_row = <$fh>;
    my @header_columns;
    if ($csv->parse($header_row)) {
        @header_columns = $csv->fields();
    } else {
        push @error_messages, "Could not parse header row. Make sure it is a valid CSV file.";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my $num_cols = scalar(@header_columns);

    my %seen_seedlot_names;
    while ( my $row = <$fh> ){
        my @columns;
        if ($csv->parse($row)) {
            @columns = $csv->fields();
        } else {
            push @error_messages, "Could not parse row $row.";
            $errors{'error_messages'} = \@error_messages;
            $self->_set_parse_errors(\%errors);
            return;
        }

        my $box_id = $columns[0];
        my $seed_id = $columns[1];
        my $inventory_date = $columns[2];
        my $inventory_person = $columns[3];
        my $weight_gram = $columns[4];
        $seed_id =~ s/^\s+|\s+$//g; #trim whitespace from front and end...
        $seen_seedlot_names{$seed_id}++;

        $parse_result{$seed_id} = {
            box_id => $box_id,
            seedlot_name => $seed_id,
            inventory_date => $inventory_date,
            inventory_person => $inventory_person,
            weight_gram => $weight_gram
        };
    }

    my @seedlot_names = keys %seen_seedlot_names;
    my $seedlots_rs = $schema->resultset("Stock::Stock")->search({uniquename => {-in => \@seedlot_names}});
    while (my $r = $seedlots_rs->next){
        $parse_result{$r->uniquename}->{seedlot_id} = $r->stock_id;
    }

    $self->_set_parsed_data(\%parse_result);
    return 1;
}

1;
