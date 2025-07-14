package CXGN::Stock::ParseUpload::Plugin::TransgenicHistoricalDataGeneric;

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
        required_columns => [ 'accession_name', 'vector_construct', 'batch_number'],
        optional_columns => [ 'is_a_control' ],
        column_aliases => {
            'accession_name' => ['accession name'],
            'vector_construct' => ['vector construct'],
            'batch_number' => ['batch number'],
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

    my $seen_new_accession_names = $parsed_values->{'accession_name'};
    my $seen_vector_constructs = $parsed_values->{'vector_construct'};

    my $vector_construct_validator = CXGN::List::Validate->new();
    my @vector_constructs_missing = @{$vector_construct_validator->validate($schema,'vector_constructs', $seen_vector_constructs)->{'missing'}};
    if (scalar(@vector_constructs_missing) > 0) {
        push @error_messages, "The following vector constructs are not in the database, or are not in the database as uniquenames: ".join(',',@vector_constructs_missing);
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_new_accession_names }
    });
    while (my $r=$rs->next){
        push @error_messages, "Accession name already exists in database: ".$r->uniquename;
    }

    my %duplicated_new_accession_names;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $new_accession = $row->{'accession_name'};

        if ($duplicated_new_accession_names{$new_accession}) {
            push @error_messages, "Cell A$row_num: duplicate new accession name: $new_accession. Accession name must be unique.";
        } else {
            $duplicated_new_accession_names{$new_accession}++;
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
    my $transgenic_data = {};

    foreach my $row (@$parsed_data) {
        my $type;
        if ($row->{'is_a_control'}) {
            $type = 'control';
        } else {
            $type = 'transformant';
        }

        $transgenic_data->{$row->{'batch_number'}}->{$row->{'vector_construct'}}->{$type}->{$row->{'accession_name'}}++;
    }

    $self->_set_parsed_data($transgenic_data);

    return 1;
}


1;
