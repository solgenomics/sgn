package CXGN::Transformation::ParseUpload::Plugin::RelativeExpressionData;

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

    my $genes = $self->get_vector_construct_genes();
    my %vector_construct_genes;
    foreach my $gene (@$genes) {
        $vector_construct_genes{$gene} = 1;
    }

    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'accession_name', 'gene', 'relative_expression' ],
        optional_columns => [ ],
        column_aliases => {
            'accession_name' => ['accession name'],
            'relative_expression' => ['relative expression'],
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

    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_genes = $parsed_values->{'gene'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames', $seen_accession_names)->{'missing'}};
    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
    }

    foreach my $gene_name (@$seen_genes) {
        if (!exists $vector_construct_genes{$gene_name}) {
            push @error_messages, "Gene not in this vector construct: $gene_name.";
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
    my %relative_expression_data;

    foreach my $row (@$parsed_data) {
        my $row_number = $row->{'_row'};
        my $accession_name = $row->{'accession_name'};
        my $gene_name = $row->{'gene'};
        my $relative_expression = $row->{'relative_expression'};
        $relative_expression_data{$accession_name}{$gene} = $relative_expression;
    }

    $self->_set_parsed_data(\%relative_expression_data);

    return 1;
}


1;
