package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotFromAccessionGeneric;

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
    my %missing_accessions;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'seedlot_name', 'accession_name', 'operator_name', 'box_name' ],
        optional_columns => ['description', 'quality', 'source', 'amount', 'weight(g)'],
        column_aliases => {
            'seedlot_name' => ['seedlot name'],
            'accession_name' => ['accession name', 'accession'],
            'operator_name' => ['operator name', 'operator'],
            'box_name' => ['box name'],
        },
    );

    my $parsed = $parser->parse();
    print STDERR "PARSED =".Dumper($parsed)."\n";
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my $additional_columns = $parsed->{additional_columns};

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

    my $seen_seedlot_names = $parsed_value->{'seedlot_name'};
    my $seen_accession_names = $parsed_value->{'accession_name'};
    my $seed_source_names = $parsed_value->{'source'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',$seen_accession_names)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
    }

    if ($seen_source_names) {
        my $source_validator = CXGN::List::Validate->new();
        my @source_missing = @{$source_validator->validate($schema,'plots_or_subplots_or_plants',$seen_source_names)->{'missing'}};

        if (scalar(@source_missing) > 0) {
            push @error_messages, "The following source are not in the database: ".join(',',@source_missing);
        }

    }



    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # cache parsed data for _parse_with_plugin function
    $self->_set_parsed_data($parsed);

    return 1; #returns true if validation is passed

}


1;
