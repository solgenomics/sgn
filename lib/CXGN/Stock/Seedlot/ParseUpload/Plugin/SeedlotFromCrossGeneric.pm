package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotFromCrossGeneric;

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
    my %missing_accessions;

    my $parser = CXGN::File::Parse->new (
        i18n => $self->i18n,
        file => $filename,
        required_columns => [ 'seedlot_name', 'cross_unique_id', 'operator_name', 'box_name' ],
        optional_columns => ['description', 'quality', 'amount', 'weight_gram'],
        column_aliases => {
            'seedlot_name' => ['seedlot name'],
            'cross_unique_id' => ['cross unique id', 'cross name'],
            'operator_name' => ['operator name', 'operator'],
            'box_name' => ['box name'],
            'weight_gram' => ['weight(g)'],
        },
        unique_only_columns => [ 'seedlot_name' ]
    );

    my $parsed = $parser->parse();
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
            ($self->i18n ? $self->i18n->p('seedlots.parse.the_following_columns_are_not_recognized_columns_please_check_the_spread', 'The following columns are not recognized: %{columns}. Please check the spreadsheet format for the allowed columns.', {columns => join(', ', @$additional_columns)}) : "The following columns are not recognized: " . join(', ', @$additional_columns) . ". Please check the spreadsheet format for the allowed columns.")
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $seedlot_name = $row->{'seedlot_name'};
        my $amount = $row->{'amount'};
        my $weight = $row->{'weight_gram'};

        if ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, ($self->i18n ? $self->i18n->p('seedlots.parse.cell_cell_column_must_not_contain_spaces_or_slashes', 'Cell %{cell}: %{column} must not contain spaces or slashes.', {cell => "A$row_num", column => 'seedlot_name'}) : "Cell A$row_num: seedlot_name must not contain spaces or slashes.");
        }

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, ($self->i18n ? $self->i18n->p('seedlots.parse.on_row_row_you_must_provide_either_a_weight_in_grams_or_a_seed_count_amo.ea4edcb', 'On row:%{row} you must provide either a weight in grams or a seed count amount.', {row => '' . ($row_num)}) : "On row:$row_num you must provide either a weight in grams or a seed count amount.");
        }

    }

    my $seen_seedlot_names = $parsed_values->{'seedlot_name'};
    my $seen_cross_names = $parsed_values->{'cross_unique_id'};

    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',$seen_cross_names)->{'missing'}};

    if (scalar(@crosses_missing) > 0) {
        push @error_messages, ($self->i18n ? $self->i18n->p('seedlots.parse.the_following_cross_unique_ids_are_not_in_the_database_as_uniquenames_na', 'The following cross unique ids are not in the database as uniquenames: %{names}', {names => join(',', @crosses_missing)}) : "The following cross unique ids are not in the database as uniquenames: ".join(',',@crosses_missing));
    }

    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => $seen_seedlot_names }
    });

    while (my $r = $rs->next) {
        if ( $r->type->name ne 'seedlot' ) {
            push @error_messages, ($self->i18n ? $self->i18n->p('seedlots.parse.seedlot_name_already_exists_in_database_name_the_seedlot_name_must_be_un', 'Seedlot name already exists in database: %{name}.  The seedlot name must be unique.', {name => '' . ($r->uniquename)}) : "Seedlot name already exists in database: ".$r->uniquename.".  The seedlot name must be unique.");
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    } else {
        $self->_set_parsed_data($parsed);
    }

    return 1;

}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_parsed_data();
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};
    my %parsed_seedlots;

    my $cross_names = $parsed_values->{'cross_unique_id'};
    my $seedlot_names = $parsed_values->{'seedlot_name'};

    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my $cross_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $cross_names },
        'type_id' => $cross_cvterm_id
    });

    my %cross_lookup;
    while (my $r = $cross_rs->next){
        $cross_lookup{$r->uniquename} = $r->stock_id;
    }

    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $seedlot_names },
        'type_id' => $seedlot_cvterm_id
    });

    my %seedlot_lookup;
    while (my $r = $seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( @$parsed_data ) {
        my $row_num;
        my $seedlot_name;
        my $cross_name;
        my $operator_name;
        my $amount;
        my $weight;
        my $description;
        my $box_name;
        my $quality;

        $row_num = $row->{_row};
        $seedlot_name = $row->{'seedlot_name'};
        $cross_name = $row->{'cross_unique_id'};
        $operator_name = $row->{'operator_name'};
        $amount = $row->{'amount'};
        $weight = $row->{'weight_gram'};
        $description = $row->{'description'};
        $box_name = $row->{'box_name'};
        $quality = $row->{'quality'};

        if (!$amount || $amount eq '') {
            $amount = 'NA';
        } elsif (!$weight || $weight eq '') {
            $weight = 'NA';
        }

        $parsed_seedlots{$seedlot_name} = {
            seedlot_id => $seedlot_lookup{$seedlot_name}, #If seedlot name already exists, this will allow us to update information for the seedlot
            accession => undef,
            accession_stock_id => undef,
            cross_name => $cross_name,
            cross_stock_id => $cross_lookup{$cross_name},
            amount => $amount,
            weight_gram => $weight,
            description => $description,
            box_name => $box_name,
            operator_name => $operator_name
        };
    }

    $self->_set_parsed_data(\%parsed_seedlots);

    return 1;

}


1;
