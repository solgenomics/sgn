package CXGN::Stock::ParseUpload::Plugin::PropagationGroupIdentifiersGeneric;

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
        required_columns => [ 'propagation_group_identifier', 'purpose' 'accession_name', 'material_type', 'date', 'description', 'operator_name' ],
        optional_columns => [ 'source_type', 'source_name', 'sub_location' ],
        column_aliases => {
            'propagation_group_identifier' => ['propagation group identifier'],
            'accession_name' => ['accession name'],
            'material_type' => ['material type'],
            'source_type' => ['source type'],
            'source_name' => ['source_name'],
            'sub_location' => ['sub-location', 'sub location'],
            'operator_name' => ['operator name'],

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

    my %supported_material_types;
    $supported_material_types{'plant'} = 1;
    $supported_material_types{'seed'} = 1;
    $supported_material_types{'budwood'} = 1;
    $supported_material_types{'tissue_culture'} = 1;

    my $seen_propagation_group_identifiers = $parsed_values->{'propagation_group_identifier'};
    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_source_names = $parsed_values->{'source_name'};
    my $seen_material_types = $parsed_values->{'material_relationship_type'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions', $seen_accession_names)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
    }

    if ($seen_source_names) {
        my $source_name_validator = CXGN::List::Validate->new();
        my @source_names_missing = @{$source_name_validator->validate($schema,'plots_or_subplots_or_plants_or_tissue_samples', $seen_source_names)->{'missing'}};
        if (scalar(@source_names_missing) > 0) {
            push @error_messages, "The following source names are not in the database, or are not in the database as uniquenames: ".join(',',@source_names_missing);
        }
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_propagation_group_identifiers }
    });
    while (my $r=$rs->next){
        push @error_messages, "Propagation Group Identifier already exists in database: ".$r->uniquename;
    }

    my %duplicated_propagation_group_identifiers;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $propagation_group_identifier = $row->{'propagation_group_identifier'};

        if ($duplicated_propagation_group_identifiers{$propagation_group_identifier}) {
            push @error_messages, "Cell A$row_num: duplicate propagation group identifier: $propagation_group_identifier. Propagation Group Identifier must be unique.";
        } else {
            $duplicated_propagation_group_identifiers{$propagation_group_identifier}++;
        }
    }

    foreach my $type (@$seen_material_types) {
        if (!exists $supported_material_types{$type}) {
            push @error_messages, "Material type not supported: $type. Material type should be plant, seed, budwood or tissue_culture ";
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
    my %identifier_info;

    foreach my $row (@$parsed_data) {
        my $row_number = $row->{'_row'};
        $identifier_info{$row_number}{'propagation_group_identifier'} = $row->{'propagation_group_identifier'};
        $identifier_info{$row_number}{'purpose'} = $row->{'purpose'};        
        $identifier_info{$row_number}{'accession_name'} = $row->{'accession_name'};
        $identifier_info{$row_number}{'material_type'} = $row->{'material_type'};
        $identifier_info{$row_number}{'date'} = $row->{'date'};
        $identifier_info{$row_number}{'description'} = $row->{'description'};
        $identifier_info{$row_number}{'operator_name'} = $row->{'operator_name'};
        $identifier_info{$row_number}{'material_source_type'} = $row->{'source_type'};
        $identifier_info{$row_number}{'source_name'} = $row->{'source_name'};
        $identifier_info{$row_number}{'sub_location'} = $row->{'sub_location'};
    }

    $self->_set_parsed_data(\%identifier_info);

    return 1;
}


1;
