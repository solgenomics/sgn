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
        optional_columns => ['description', 'quality', 'source', 'amount', 'weight_gram'],
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

    my %duplicated_seedlot_names;
    my @accession_source_pairs;
    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $seedlot_name = $row->{'seedlot_name'};
        my $accession_name = $row->{'accession_name'};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight(g)'};
        my $seedlot_source = $row->{'source'};

        if ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_num: seedlot_name must not contain spaces or slashes.";
        }

        if ($duplicated_seedlot_names{$seedlot_name}) {
            push @error_messages, "Cell A$row_num: duplicate seedlot_name at cell A".$duplicated_seedlot_names{$seedlot_name}.": $seedlot_name";
        }

        if (!$amount && !$weight) {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount.";
        }

        if ($seedlot_source) {
            push @accession_source_pairs, [$accession_name, $seedlot_source];
        }
    }

    my $seen_seedlot_names = $parsed_values->{'seedlot_name'};
    my $seen_accession_names = $parsed_values->{'accession_name'};
    my $seen_source_names = $parsed_values->{'source'};

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'accessions',$seen_accession_names)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following accessions are not in the database as uniquenames or synonyms: ".join(',',@accessions_missing);
    }

    if ($seen_source_names) {
        my $source_validator = CXGN::List::Validate->new();
        my @source_missing = @{$source_validator->validate($schema,'seedlots_or_plots_or_subplots_or_plants_or_crosses_or_accessions',$seen_source_names)->{'missing'}};

        if (scalar(@source_missing) > 0) {
            push @error_messages, "The following source are not in the database: ".join(',',@source_missing);
        }
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_seedlot_names }
    });

    while (my $r = $rs->next) {
        if ( $r->type->name ne 'seedlot' ) {
            push @error_messages, "Seedlot name already exists in database: ".$r->uniquename.".  The seedlot name must be unique.";
        }
    }

    if (scalar(@accession_source_pairs) >=1) {
        my $pairs_error = CXGN::Stock::Seedlot->verify_accession_content_source_compatibility($schema, \@accession_source_pairs);
        if (exists($pairs_error->{error})){
            push @error_messages, $pairs_error->{error};
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
    my $parsed_values = $parsed->{values};

    my $accession_names = $parsed_values->{'accession_name'};
    my $seedlot_names = $parsed_values->{'seedlot_name'};

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();

    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $accession_names },
        'type_id' => $accession_cvterm_id,
    });
    my %accession_lookup;
    while (my $r = $rs->next) {
        $accession_lookup{$r->uniquename} = $r->stock_id;
    }
    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => $accession_names},
        'me.type_id' => $accession_cvterm_id,
        'stockprops.type_id' => $synonym_cvterm_id
    }, {join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});

    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }

    my %parsed_seedlots;
    $self->_set_parsed_data(\%parsed_seedlots);

    return 1;

}


1;
