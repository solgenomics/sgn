package CXGN::Trial::ParseUpload::Plugin::TrialUsedSeedlotsGeneric;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;

sub _validate_with_plugin {
    my $self = shift;

    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_stock_type = $self->get_trial_stock_type();

    my @error_messages;
    my %errors;
    my %missing_seedlots;

    my $parser = CXGN::File::Parse->new (
        file => $filename,
        required_columns => [ 'seedlot_name', 'plot_name'],
        optional_columns => ['num_seed_per_plot', 'weight_gram_seed_per_plot', 'description'],
        column_aliases => {
            'seedlot_name' => ['seedlot name'],
            'plot_name' => ['plot name'],
            'num_seed_per_plot' => ['num seed per plot'],
            'weight_gram_seed_per_plot' => ['weight gram seed per plot'],
        },
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
            "The following columns are not recognized: " . join(', ', @$additional_columns) . ". Please check the spreadsheet format for the allowed columns."
        ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    my @pairs;
    for my $row ( @$parsed_data ) {
        my $row_num = $row->{_row};
        my $seedlot_name = $row->{'seedlot_name'};
        my $plot_name = $row->{'plot_name'};
        my $amount = $row->{'num_seed_per_plot'};
        my $weight = $row->{'weight_gram_seed_per_plot'};
        push @pairs, [$seedlot_name, $plot_name];

        if (!defined $amount && !defined $weight) {
            push @error_messages, "On row:$row_num you must provide either a weight in grams or a seed count amount per plot.";
        }
    }

    my $seen_seedlot_names = $parsed_values->{'seedlot_name'};
    my $seen_plot_names = $parsed_values->{'plot_name'};

    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',$seen_seedlot_names)->{'missing'}};
    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database as uniquenames: ".join(',',@seedlots_missing);
    }

    my $plot_validator = CXGN::List::Validate->new();
    my @plot_missing = @{$plot_validator->validate($schema,'plots',$seen_plot_names)->{'missing'}};
    if (scalar(@plot_missing) > 0) {
        push @error_messages, "The following plots are not in the database as uniquenames: ".join(',',@plots_missing);
    }

    my $validate_seedlot_plot_compatibility;
    if ($trial_stock_type eq 'family_name') {
        $validate_seedlot_plot_compatibility = CXGN::Stock::Seedlot->verify_seedlot_family_plot_compatibility($schema, \@pairs);
    } else {
        $validate_seedlot_plot_compatibility = CXGN::Stock::Seedlot->verify_seedlot_plot_compatibility($schema, \@pairs);
    }
    if (exists($validate_seedlot_plot_compatibility->{error})){
        push @error_messages, $validate_seedlot_plot_compatibility->{error};
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
    my %parsed_result;

    my $seedlot_names = $parsed_values->{'seedlot_name'};
    my $plot_names = $parsed_values->{'plot_name'};

    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $seedlot_names }
    });

    my %seedlot_lookup;
    while (my $seedlot = $seedlot_rs->next){
        $seedlot_lookup{$seedlot->uniquename} = $seedlot->stock_id;
    }

    my $plot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => $plot_names }
    });

    my %plot_lookup;
    while (my $plot=$plot_rs->next){
        $plot_lookup{$plot->uniquename} = $plot->stock_id;
    }

    for my $row (@$parsed_data) {
        my $row_num;
        my $seedlot_name;
        my $plot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;

        $row_num = $row->{_row};
        $seedlot_name = $row->{'seedlot_name'};
        $plot_name = $row->{'plot_name'};
        $weight = $row->{'weight_gram_seed_per_plot'};
        $amount = $row->{'num_seed_per_plot'};
        $description = $row->{'description'};

        $parsed_entries{$row} = {
            seedlot_name => $seedlot_name,
            seedlot_stock_id => $seedlot_lookup{$seedlot_name},
            plot_stock_id => $plot_lookup{$plot_name},
            plot_name => $plot_name,
            amount => $amount,
            weight_gram => $weight,
            description => $description
        };
    }

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}


1;
