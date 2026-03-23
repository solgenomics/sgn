package CXGN::Trial::ParseUpload::Plugin::TrialChangePlotAccessions;

use Moose::Role;
use CXGN::Stock::StockLookup;
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::List::Transform;
use CXGN::Trial;

my @REQUIRED_COLUMNS = qw|plot_name accession_name|;
my @OPTIONAL_COLUMNS = qw|new_plot_name|;
my $parsed_accession_ids = {};

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_id = $self->get_trial_id();
    my @error_messages;
    my %errors;

    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => \@REQUIRED_COLUMNS,
        optional_columns => \@OPTIONAL_COLUMNS
    );

    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{'errors'};
    my $parsed_data = $parsed->{'data'};
    my $parsed_values = $parsed->{'values'};

    if (@$parsed_errors) {
        push @error_messages, join (". ", @$parsed_errors);
    }

    my @old_plot_names;
    my @accessions;
    my @new_plot_names;

    foreach my $row (@$parsed_data) {
        my $row_num = $row->{'_row'};
        if (!$row->{'plot_name'}) {
            push @error_messages, "Row $row_num is missing the plot name. ";
        }
        if (!$row->{'accession_name'}) {
            push @error_messages, "Row $row_num is missing an accession name. ";
        }
        push @old_plot_names, $row->{'plot_name'};
        push @accessions, $row->{'accession_name'};
        if ($row->{'new_plot_name'}) {
            push @new_plot_names, $row->{'new_plot_name'};
        }
    }

    my $validator = CXGN::List::Validate->new();

    my $validate = $validator->validate($schema, 'plots', \@old_plot_names);
    if (scalar(@{$validate->{'missing'}}) > 0) {
        push @error_messages, "The following plots were not found in the database: ".$validate->{'missing'};
    }

    my $transform = CXGN::List::Transform->new();
    $validate = $transform->transform($schema, 'stocks_2_stock_ids', \@accessions);
    if (scalar(@{$validate->{'missing'}}) > 0) {
        push @error_messages, "The following accessions were not found in the database: ".$validate->{'missing'};
    } else {
        foreach my $accession_id (@{$validate->{'transform'}}) {
            my $accession_name = shift(@accessions);
            $parsed_accession_ids->{$accession_name} = $accession_id;
        }
    }

    if (scalar(@new_plot_names) > 0) {
        $validate = $validator->validate($schema, 'plots', \@new_plot_names);
        my %valid_new_names = map { $_ => 1 } @{$validate->{'missing'}};
        foreach my $new_name (@new_plot_names) {
            if (!exists($valid_new_names{$new_name})) { # if the new name was NOT found in the missing list, then it must already be in the database. That's bad!
                push @error_messages, "New plot name $new_name already exists in the database. ";
            }
        }
    }

    if (scalar(@error_messages) > 0) {
        $self->_set_parse_errors({
            'error_messages' => \@error_messages
        });
        return 0;
    }

    return 1; #returns true if validation passed

}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_id = $self->get_trial_id();

    my $parsed_entries = {};

    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => \@REQUIRED_COLUMNS,
        optional_columns => \@OPTIONAL_COLUMNS
    );

    my $parsed = $parser->parse();
    my $parsed_data = $parsed->{'data'};

    foreach my $row (@$parsed_data) {
        $parsed_entries->{$row->{'plot_name'}} = {
            'old_plot_name' => $row->{'plot_name'},
            'new_plot_name' => $row->{'new_plot_name'} ? $row->{'new_plot_name'} : '',
            'new_accession_name' => $row->{'accession_name'},
            'new_accession_id' => $parsed_accession_ids->{$row->{'accession_name'}}
        };
    } 

    $self->_set_parsed_data($parsed_entries);
    return 1;
}


1;
