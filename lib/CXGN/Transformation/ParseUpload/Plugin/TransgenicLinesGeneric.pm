package CXGN::Transformation::ParseUpload::Plugin::TransgenicLinesGeneric;

use Moose::Role;
use CXGN::File::Parse;
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
        required_columns => [ 'transformation_identifier', 'transgenic_line_name' ],
        column_aliases => {
            'transformation_identifier' => ['transformation identifier', 'transformation_ID', 'transformation ID'],
            'transgenic_line_name' => ['transgenic line name', 'transgenic line', 'transgenic name', 'transformant'],
        },
        unique_only_columns => ['transgenic_line_name'],
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
    my $seen_transgenic_line_names = $parsed_values->{'transgenic_line_name'};

    my $transformation_identifier_validator = CXGN::List::Validate->new();
    my @transformation_identifiers_missing = @{$transformation_identifier_validator->validate($schema,'transformation_identifiers', $seen_transformation_identifiers)->{'missing'}};
    if (scalar(@transformation_identifiers_missing) > 0) {
        push @error_messages, "The following transformation identifiers are not in the database: ".join(',',@transformation_identifiers_missing);
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_transgenic_line_names }
    });
    while (my $r=$rs->next){
        push @error_messages, "Transgenic Line name already exists in database: ".$r->uniquename;
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
    my %transgenic_line_info;

    foreach my $row (@$parsed_data) {
        my $transformation_identifier = $row->{'transformation_identifier'};
        my $transgenic_line = $row->{'transgenic_line_name'};
        $transgenic_line_info{$transformation_identifier}{$transgenic_line} = 1;
    }

    $self->_set_parsed_data(\%transgenic_line_info);

    return 1;
}


1;
