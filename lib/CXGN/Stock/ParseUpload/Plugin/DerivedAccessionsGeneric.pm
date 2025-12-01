package CXGN::Stock::ParseUpload::Plugin::DerivedAccessionsGeneric;

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
        required_columns => [ 'original_name', 'derived_accession_name', 'description'],
        optional_columns => [],
        column_aliases => {
            'original_name' => ['original name', 'Original Name'],
            'derived_accession_name' => ['derived accession name', 'Derived Accession Name'],
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

    my $seen_original_names = $parsed_values->{'original_name'};
    my $seen_derived_accession_names = $parsed_values->{'derived_accession_name'};

    my $original_names_validator = CXGN::List::Validate->new();
    my @original_names_missing = @{$original_names_validator->validate($schema,'accessions_or_plants_or_tissue_samples',$seen_original_names)->{'missing'}};

    if (scalar(@original_names_missing) > 0) {
        push @error_messages, "The following accessions or plants or tissue samples are not in the database: ".join(',',@original_names_missing);
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_derived_accession_names }
    });

    while (my $r=$rs->next){
        push @error_messages, "Derived accession name already exists in database: ".$r->uniquename;
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
    my @derived_accession_info;

    foreach my $row (@$parsed_data) {
        my $original_name = $row->{'original_name'};
        my $derived_accession_name = $row->{'derived_accession_name'};
        my $description = $row->{'description'};
        push @derived_accession_info, {
            'stock_name' => $original_name,
            'derived_accession_name' => $derived_accession_name,
            'accession_description' => $description,
        }
    }

    $parsed_result{'derived_accession_info'} = \@derived_accession_info;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
