package CXGN::Trial::ParseUpload::Plugin::TrialSpatialLayoutGeneric;

use Moose::Role;
use List::MoreUtils qw(uniq);
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use CXGN::List::Validate;
use CXGN::Stock;

my @REQUIRED_COLUMNS = qw|plot_name row_number col_number|;
my @OPTIONAL_COLUMNS = qw||;
# Any additional columns are unsupported and will return an error

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # List validator
    my $validator = CXGN::List::Validate->new();

    # Encountered Error and Warning Messages
    my %errors;
    my @error_messages;
    my %warnings;
    my @warning_messages;

    # Read and parse the upload file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => \@REQUIRED_COLUMNS,
        optional_columns => \@OPTIONAL_COLUMNS
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{'errors'};
    my $parsed_data = $parsed->{'data'};
    my $parsed_values = $parsed->{'values'};
    my $additional_columns = $parsed->{'additional_columns'};

    # Return file parsing errors
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Unsupported column headers
    if ( $additional_columns && scalar(@$additional_columns) > 0 ) {
        $errors{'error_messages'} = [ 'The following column headers are not supported: ' . join(', ', @$additional_columns) ];
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Maps to track row/col positions
    my %seen_positions;    # check that each row_number/col_number pair is used only once

    foreach my $data (@$parsed_data) {
        my $row = $data->{'_row'};
        my $plot_name = $data->{'plot_name'};
        my $row_number = $data->{'row_number'};
        my $col_number = $data->{'col_number'};

        # Row Number: must be a positive integer
        if (!($row_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: row_number <strong>$row_number</strong> must be a positive integer.";
        }

        # Col Number: must be a positive integer
        if (!($col_number =~ /^\d+?$/)) {
            push @error_messages, "Row $row: col_number <strong>$col_number</strong> must be a positive integer.";
        }

        # Track row/col positions to check for duplicates
        my $position_key = "$row_number-$col_number";
        if ( !exists $seen_positions{$position_key} ) {
            $seen_positions{$position_key} = [$plot_name];
        }
        else {
            push @{$seen_positions{$position_key}}, $plot_name;
        }
    }

    # Plot Names: must exist in the database as plots
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my @plot_names = @{$parsed_values->{'plot_name'}};
    my @missing_plots;
    my %plot_trial_map;  # map of plot_name => trial_id

    foreach my $plot_name (@plot_names) {
        my $rs = $schema->resultset("Stock::Stock")->search({
            'me.uniquename' => $plot_name,
            'me.type_id' => $plot_cvterm_id,
            'me.is_obsolete' => { '!=' => 't' }
        });

        if ($rs->count() == 0) {
            push @missing_plots, $plot_name;
        }
        else {
            # Get the trial that this plot belongs to
            my $plot_stock = $rs->first();
            my $plot_id = $plot_stock->stock_id();

            # Get trial from plot
            my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
            my $project_rs = $schema->resultset("Project::Project")->search({
                'nd_experiment_stocks.stock_id' => $plot_id,
                'nd_experiment_projects.nd_experiment_id' => { -ident => 'nd_experiment_stocks.nd_experiment_id' }
            }, {
                join => { 'nd_experiment_projects' => { 'nd_experiment' => 'nd_experiment_stocks' } }
            });

            if ($project_rs->count() > 0) {
                my $trial = $project_rs->first();
                my $trial_id = $trial->project_id();
                $plot_trial_map{$plot_name} = $trial_id;
            }
        }
    }

    # Report missing plots
    if (scalar(@missing_plots) > 0) {
        push @error_messages, "Plot name(s) <strong>".join(', ',@missing_plots)."</strong> do not exist in the database as plots.";
    }

    # Check that all plots belong to the same trial
    my @trial_ids = uniq values %plot_trial_map;
    if (scalar(@trial_ids) > 1) {
        push @error_messages, "All plots must belong to the same trial. Found plots from multiple trials.";
    }
    elsif (scalar(@trial_ids) == 0 && scalar(@missing_plots) == 0) {
        push @error_messages, "Could not determine trial for the provided plots.";
    }

    # Check for unique row/col positions
    foreach my $position_key (keys %seen_positions) {
        my $plots = $seen_positions{$position_key};
        my $count = scalar(@$plots);
        if ( $count > 1 ) {
            my @pos = split('-', $position_key);
            push @error_messages, "Position row=" . $pos[0] . " col=" . $pos[1] . " is assigned to multiple plots: <strong>" . join(', ', @$plots) . "</strong>. Each position can only be occupied once.";
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $self->_set_validated_data($parsed);
    return 1; #returns true if validation is passed
}

sub _parse_with_plugin {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $parsed = $self->_get_validated_data();
    my $data = $parsed->{'data'};

    # Get plot stock type cvterm
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();

    my %spatial_layout_data;

    foreach my $d (@$data) {
        my $plot_name = $d->{'plot_name'};
        my $row_number = $d->{'row_number'};
        my $col_number = $d->{'col_number'};

        # Get plot stock_id from plot_name
        my $rs = $schema->resultset("Stock::Stock")->search({
            'uniquename' => $plot_name,
            'type_id' => $plot_cvterm_id,
            'is_obsolete' => { '!=' => 't' }
        });

        if ($rs->count() > 0) {
            my $plot_stock = $rs->first();
            my $plot_id = $plot_stock->stock_id();

            # Store the spatial layout information
            $spatial_layout_data{$plot_id} = {
                plot_name => $plot_name,
                row_number => $row_number,
                col_number => $col_number
            };
        }
    }


    $self->_set_parsed_data(\%spatial_layout_data);

    return 1;
}

1;
