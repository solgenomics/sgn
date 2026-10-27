package CXGN::Stock::ParseUpload::Plugin::PropagationIdentifierStatusUpdate;

use Moose::Role;
use SGN::I18N ();
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my SGN::I18N $ui_i18n = SGN::I18N::translate($self);

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
        i18n => $ui_i18n,
        file => $filename,
        required_columns => ['propagation_identifier', 'status_type', 'status_date', 'status_updated_by'],
        optional_columns => ['status_notes', 'inventory_identifier'],
        column_aliases => {
            'propagation_identifier' => ['propagation identifier', 'Propagation Identifier'],
            'status_type' => ['status type', 'Status Type'],
            'status_date' => ['status date', 'Status Date'],
            'status_updated_by' => ['status updated by', 'Status Updated by'],
            'status_notes' => ['status notes', 'Status Notes'],
            'inventory_identifier' => ['inventory identifier', 'Inventory Identifier'],

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
            (SGN::I18N::translate($ui_i18n, "seedlot.server.the_following_columns_are_not_recognized_names_please", "The following columns are not recognized: %{names}. Please check the spreadsheet format for the allowed columns.", {names => "" . (join(', ', @$additional_columns))}))
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $seen_propagation_identifiers = $parsed_values->{'propagation_identifier'};
    my $seen_inventory_identifiers = $parsed_values->{'inventory_identifier'};
    my $seen_status_types = $parsed_values->{'status_type'};
    my $seen_status_dates = $parsed_values->{'status_date'};

    my $propagation_identifier_validator = CXGN::List::Validate->new();
    my @propagation_identifiers_missing = @{$propagation_identifier_validator->validate($schema,'propagation',$seen_propagation_identifiers)->{'missing'}};

    if (scalar(@propagation_identifiers_missing) > 0) {
        push @error_messages, (SGN::I18N::translate($ui_i18n, "seedlot.server.the_following_propagation_identifiers_are_not_in_the", "The following propagation identifiers are not in the database: %{names}", {names => "" . (join(',',@propagation_identifiers_missing))}));
    }

    if (scalar(@$seen_inventory_identifiers) > 0) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            'uniquename' => { -in => $seen_inventory_identifiers }
        });

        while (my $r=$rs->next){
            push @error_messages, (SGN::I18N::translate($ui_i18n, "seedlot.server.inventory_identifier_already_exists_in_database_name", "Inventory Identifier already exists in database: %{name}", {name => "" . ($r->uniquename)}));
        }
    }

    my %supported_status_types;
    $supported_status_types{'inventoried'} = 1;
    $supported_status_types{'in trial'} = 1;
    $supported_status_types{'distributed'} = 1;
    $supported_status_types{'dead'} = 1;
    $supported_status_types{'disposed'} = 1;

    foreach my $type (@$seen_status_types) {
        if (!exists $supported_status_types{$type}) {
            push @error_messages, (SGN::I18N::translate($ui_i18n, "seedlot.server.status_type_not_supported_b_type_b_status", "Status type not supported: <b>%{type}</b>. Status type should be inventoried, in trial, distribued, dead or disposed ", {type => "" . ($type)}));
        }
    }

    foreach my $date (@$seen_status_dates) {
        if (! ($date =~ m/(\d{4})\-(\d{2})\-(\d{2})/)) {
            push @error_messages, (SGN::I18N::translate($ui_i18n, "seedlot.server.invalid_date_format_date_dates_need_to_be", "Invalid date format: %{date}. Dates need to be YYYY-MM-DD format", {date => "" . ($date)}));
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
    my %parsed_result;
    my %propagation_identifier_status;

    foreach my $row (@$parsed_data) {
        my $propagation_identifier = $row->{'propagation_identifier'};
        $propagation_identifier_status{$propagation_identifier}{'status_type'} = $row->{'status_type'};
        $propagation_identifier_status{$propagation_identifier}{'status_date'} = $row->{'status_date'};
        $propagation_identifier_status{$propagation_identifier}{'status_notes'} = $row->{'status_notes'};
        $propagation_identifier_status{$propagation_identifier}{'status_updated_by'} = $row->{'status_updated_by'};
        $propagation_identifier_status{$propagation_identifier}{'inventory_identifier'} = $row->{'inventory_identifier'};
    }

    $self->_set_parsed_data(\%propagation_identifier_status);

    return 1;

}


1;
