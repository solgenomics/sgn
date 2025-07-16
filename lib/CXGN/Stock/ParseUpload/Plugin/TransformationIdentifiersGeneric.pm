package CXGN::Stock::ParseUpload::Plugin::TransformationIdentifiersGeneric;

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
        required_columns => [ 'transformation_identifier', 'accession_name', 'vector_construct' ],
        optional_columns => [ 'notes', 'is_a_control' ],
        column_aliases => {
            'transformation_identifier' => ['transformation identifier'],
            'accession_name' => ['accession name'],
            'vector_construct' => ['vector construct'],
            'is_a_control' => ['is a control'],
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

    my $seen_transformation_identifiers = $parsed_values->{'transformation_identifier'};
    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_vector_constructs = $parsed_values->{'vector_construct'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions', $seen_accession_names)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
    }

    my $vector_construct_validator = CXGN::List::Validate->new();
    my @vector_constructs_missing = @{$vector_construct_validator->validate($schema,'vector_constructs', $seen_vector_constructs)->{'missing'}};
    if (scalar(@vector_constructs_missing) > 0) {
        push @error_messages, "The following vector constructs are not in the database, or are not in the database as uniquenames: ".join(',',@vector_constructs_missing);
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_transformation_identifiers }
    });
    while (my $r=$rs->next){
        push @error_messages, "Transformation Identifier already exists in database: ".$r->uniquename;
    }

    my %duplicated_transformation_ids;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $transformation_id = $row->{'transformation_identifier'};

        if ($duplicated_transformation_ids{$transformation_id}) {
            push @error_messages, "Cell A$row_num: duplicate transformation identifier: $transformation_id. Transformation Identifier must be unique.";
        } else {
            $duplicated_transformation_ids{$transformation_id}++;
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
    my %transformation_id_info;

    foreach my $row (@$parsed_data) {
        my $row_number = $row->{'_row'};
        my $transformation_identifier = $row->{'transformation_identifier'};
        my $accession_name = $row->{'accession_name'};
        my $vector_construct = $row->{'vector_construct'};
        my $notes = $row->{'notes'};
        my $is_a_control = $row->{'is_a_control'};
        $transformation_id_info{$row_number}{'transformation_identifier'} = $transformation_identifier;
        $transformation_id_info{$row_number}{'accession_name'} = $accession_name;
        $transformation_id_info{$row_number}{'vector_construct'} = $vector_construct;
        $transformation_id_info{$row_number}{'notes'} = $notes;
        $transformation_id_info{$row_number}{'is_a_control'} = $is_a_control;
    }

    $self->_set_parsed_data(\%transformation_id_info);

    return 1;
}


1;
