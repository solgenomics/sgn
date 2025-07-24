package CXGN::Stock::ParseUpload::Plugin::PropagationIdentifiersGeneric;

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

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'propagation_group_identifier', 'propagation_identifier'],
        optional_columns => [ 'rootstock', 'status_type', 'status_date', 'status_notes', 'status_updated_by', 'inventory_identifier'],
        column_aliases => {
            'propagation_group_identifier' => ['propagation group identifier'],
            'propagation_identifier' => ['propagation identifier'],
            'status_type' => ['status type'],
            'status_date' => ['status date'],
            'status_notes' => ['status notes'],
            'status_updated_by' => ['status updated by'],
            'inventory_identifier' => ['inventory identifier'],
        }
    );

    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

    # return if parsing error
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

    my %supported_status_types;
    $supported_status_types{'In Progress'} = 1;
    $supported_status_types{'Inventoried'} = 1;
    $supported_status_types{'Distributed'} = 1;
    $supported_status_types{'Planted in Trial'} = 1;
    $supported_status_types{'Dead'} = 1;
    $supported_status_types{'Disposed'} = 1;

    my $seen_propagation_group_identifiers = $parsed_values->{'propagation_group_identifier'};
    my $seen_propagation_identifiers = $parsed_values->{'propagation_identifier'};
    my $seen_rootstocks = $parsed_values->{'rootstock'};
    my $seen_status_types = $parsed_values->{'status_type'};
    my $seen_inventory_identifiers = $parsed_values->{'inventory_identifier'};

    my $propagation_group_id_validator = CXGN::List::Validate->new();
    my @propagation_group_ids_missing = @{$propagation_group_id_validator->validate($schema,'propagation_groups', $seen_propagation_group_identifiers)->{'missing'}};
    if (scalar(@propagation_group_ids_missing) > 0) {
        push @error_messages, "The following propagation group identifiers are not in the database: ".join(',',@propagation_group_ids_missing);
    }

    if (scalar(@$seen_rootstocks) > 0) {
        my $accession_validator = CXGN::List::Validate->new();
        my @accessions_missing = @{$accession_validator->validate($schema,'accessions', $seen_rootstocks)->{'missing'}};
        if (scalar(@accessions_missing) > 0) {
            push @error_messages, "The following rootstocks are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
        }
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_propagation_identifiers }
    });
    while (my $r=$rs->next){
        push @error_messages, "Propagation Identifier already exists in database: ".$r->uniquename;
    }

    my %duplicated_propagation_identifiers;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $propagation_identifier = $row->{'propagation_identifier'};

        if ($duplicated_propagation_identifiers{$propagation_identifier}) {
            push @error_messages, "Cell A$row_num: duplicate propagation identifier: $propagation_identifier. Propagation Identifier must be unique.";
        } else {
            $duplicated_propagation_identifiers{$propagation_identifier}++;
        }
    }

    if (scalar(@$seen_status_types) > 0) {
        foreach my $type (@$seen_status_types) {
            if (!exists $supported_status_types{$type}) {
                push @error_messages, "Status type not supported: $type. Status type should be 'In Progress', 'Inventoried', 'Distributed', 'Planted in Trial', 'Dead', 'Disposed'";
            }
        }
    }

    if (scalar(@$seen_inventory_identifiers) > 0) {
        my $inventory_rs = $schema->resultset("Stock::Stock")->search({
            'uniquename' => { -in => $seen_inventory_identifiers }
        });
        while (my $r=$inventory_rs->next){
            push @error_messages, "Inventory Identifier already exists in database: ".$r->uniquename;
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_parsed_data($parsed);
    return 1;

}


sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $propagation_identifier_info = {};

    foreach my $row (@$parsed_data) {
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'rootstock'} = $row->{'rootstock'};
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'status_type'} = $row->{'status_type'};
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'status_date'} = $row->{'status_date'};
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'status_notes'} = $row->{'status_notes'};
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'status_updated_by'} = $row->{'status_updated_by'};
        $propagation_identifier_info->{$row->{'propagation_group_identifier'}}->{$row->{'propagation_identifier'}}->{'inventory_identifier'} = $row->{'inventory_identifier'};

    }

    $self->_set_parsed_data($propagation_identifier_info);

    return 1;
}


1;
