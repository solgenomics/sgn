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
        optional_columns => [ 'is_a_control', 'existing_accession', 'number_of_insertions' ],
        column_aliases => {
            'accession_name' => ['accession name'],
            'vector_construct' => ['vector construct'],
            'batch_number' => ['batch number'],
            'is_a_control' => ['is a control'],
            'existing_accession' => ['existing accession'],
            'number_of_insertions' => ['number of insertions'],
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
    my $seen_vector_constructs = $parsed_values->{'vector_construct'};
    my $is_existing_accessions = $parsed_values->{'existing_accession'};

    my $vector_construct_validator = CXGN::List::Validate->new();
    my @vector_constructs_missing = @{$vector_construct_validator->validate($schema,'vector_constructs', $seen_vector_constructs)->{'missing'}};
    if (scalar(@vector_constructs_missing) > 0) {
        push @error_messages, "The following vector constructs are not in the database, or are not in the database as uniquenames: ".join(',',@vector_constructs_missing);
    }

    my $accession_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
    my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'male_parent', 'stock_relationship')->cvterm_id();

    if ($is_existing_accessions) {
        if (scalar(@$is_existing_accessions) > 0) {
            my $accession_validator = CXGN::List::Validate->new();
            my @accessions_missing = @{$accession_validator->validate($schema,'not_obsoleted_and_obsoleted_accessions', $seen_accession_names)->{'missing'}};
            if (scalar(@accessions_missing) > 0) {
                push @error_messages, "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
            }

            foreach my $row (@$parsed_data) {
                my $accession_name = $row->{'accession_name'};
                my $vector_construct = $row->{'vector_construct'};

                my $accession_stock = $schema->resultset("Stock::Stock")->find ({
                    uniquename => $accession_name,
                    type_id => $accession_type_id,
                });

                if ($accession_stock) {
                    my $accession_vector_construct_relationship = $schema->resultset("Stock::StockRelationship")->find ({
                        object_id => $accession_stock->stock_id(),
                        type_id => $male_parent_type_id,
                    });

                    if ($accession_vector_construct_relationship) {
                        my $vector_construct_stock = $schema->resultset("Stock::Stock")->find ({
                            stock_id => $accession_vector_construct_relationship->subject_id(),
                            type_id => $vector_construct_type_id,
                        });

                        if (!$vector_construct_stock) {
                            push @error_messages, "Error retrieving vector construct for previously stored accession: $accession_name!";
                        } else {
                            my $stored_vector_construct = $vector_construct_stock->uniquename();
                            if ($stored_vector_construct ne $vector_construct) {
                                push @error_messages, "Previously stored accession: $accession_name has vector construct: $stored_vector_construct, but the vector construct in the file is $vector_construct";
                            }
                        }
                    } else {
                        push @error_messages, "Previously stored accession: $accession_name is not linked to any vector construct in the database";
                    }
                }
            }
        }
    } else {
        my $rs = $schema->resultset("Stock::Stock")->search({
            'uniquename' => { -in => $seen_accession_names }
        });
        while (my $r=$rs->next){
            push @error_messages, "Accession name already exists in database: ".$r->uniquename;
        }
    }

    my %duplicated_accession_names;
    foreach my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        my $accession_name = $row->{'accession_name'};

        if ($duplicated_accession_names{$accession_name}) {
            push @error_messages, "Cell A$row_num: duplicate accession name: $accession_name. Accession name must be unique.";
        } else {
            $duplicated_accession_names{$accession_name}++;
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
        my $accession_type;
        if ($row->{'is_a_control'}) {
            $type = 'control';
        } else {
            $type = 'transformant';
        }

        if ($row->{'existing_accession'}) {
            $accession_type = 'existing_accession';
        } else {
            $accession_type = 'new';
        }

        $transgenic_data->{$row->{'batch_number'}}->{$row->{'vector_construct'}}->{$type}->{$accession_type}->{$row->{'accession_name'}}->{'number_of_insertions'} = $row->{'number_of_insertions'};
    }

    $self->_set_parsed_data($transgenic_data);

    return 1;
}


1;
