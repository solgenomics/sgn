package CXGN::Stock::ParseUpload::Plugin::TransformationIdentifiersGeneric;

use SGN::I18N ();

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

sub _validate_with_plugin {
    my $self = shift;
    my SGN::I18N $ui__validate_with_plugin_i18n = SGN::I18N::translate($self);

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
        i18n => $ui__validate_with_plugin_i18n,
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
            (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.the_following_columns_are_not_recognized_value1_please_check_the_spr', 'The following columns are not recognized: %{value1}. Please check the spreadsheet format for the allowed columns.', {value1 => ("" . (join(', ', @$additional_columns)))}))];
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $seen_transformation_identifiers = $parsed_values->{'transformation_identifier'};
    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_vector_constructs = $parsed_values->{'vector_construct'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions', $seen_accession_names)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.the_following_accessions_are_not_in_the_database_or_are_not_in_the_d', 'The following accessions are not in the database, or are not in the database as uniquenames: %{value1}', {value1 => ("" . (join(',',@accessions_missing)))}));
    }

    my $vector_construct_validator = CXGN::List::Validate->new();
    my @vector_constructs_missing = @{$vector_construct_validator->validate($schema,'vector_constructs', $seen_vector_constructs)->{'missing'}};
    if (scalar(@vector_constructs_missing) > 0) {
        push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.the_following_vector_constructs_are_not_in_the_database_or_are_not_i', 'The following vector constructs are not in the database, or are not in the database as uniquenames: %{value1}', {value1 => ("" . (join(',',@vector_constructs_missing)))}));
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_transformation_identifiers }
    });
    while (my $r=$rs->next){
        push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.transformation_identifier_already_exists_in_database_value1', 'Transformation Identifier already exists in database: %{value1}', {value1 => ("" . ($r->uniquename))}));
    }

    my %duplicated_transformation_ids;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $transformation_id = $row->{'transformation_identifier'};

        if ($duplicated_transformation_ids{$transformation_id}) {
            push @error_messages, (SGN::I18N::translate($ui__validate_with_plugin_i18n, 'transformation.helper.cell_a_row_num_duplicate_transformation_identifier_transformation_id', 'Cell A%{row_num}: duplicate transformation identifier: %{transformation_id}. Transformation Identifier must be unique.', {row_num => ("" . ("$row_num")), transformation_id => ("" . ("$transformation_id"))}));
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
