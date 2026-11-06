package CXGN::Trial::ParseUpload::Plugin::TrialChangePlotAccessions;

use Moose::Role;
use CXGN::Stock::StockLookup;
use CXGN::File::Parse;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Trial;

my @REQUIRED_COLUMNS = qw|plot_name accession_name|;
my @OPTIONAL_COLUMNS = qw|new_plot_name not_planted rejected reject_reason seedlot_name type trial_name|;

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
        optional_columns => \@OPTIONAL_COLUMNS,
        column_aliases => {
            'plot_name' => ['plot name'],
            'new_plot_name' => ['new plot name'],
            'not_planted' => ['not planted'],
            'rejected' => ['reject', 'rejected plot', 'rejected_plot'],
            'reject_reason' => ['reject reason', 'rejection_reason', 'rejection reason'],
            'seedlot_name' => ['seedlot name', 'seedlot'],
            'trial_name' => ['trial name'],
            'accession_name' => ['accession name', 'accession', 'cross_unique_id', 'cross unique id', 'family_name', 'family name']
        },
        unique_only_columns => ['plot_name', 'new_plot_name']
    );

    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{'errors'} || [];
    my $parsed_data = $parsed->{'data'};

    my $trial = CXGN::Trial->new({
        bcs_schema => $schema,
        trial_id => $trial_id
    });

    # A planting order file (Download Plot Order) can be uploaded as it is: its
    # rows of borders, gaps, subplots and plants, and of other trials in the
    # same field, are skipped. Other values in a type column are read as plots.
    my %not_a_plot = map { $_ => 1 } qw(border gap subplot plant);
    my $trial_name = $trial->get_name();
    my $of_other_trial = sub { defined($_[0]->{trial_name}) && $_[0]->{trial_name} =~ /\S/ && $_[0]->{trial_name} ne $trial_name };
    my %skip_row = map { $_->{_row} => 1 } grep {
        (defined($_->{type}) && $not_a_plot{ lc($_->{type} =~ s/^\s+|\s+$//gr) }) || $of_other_trial->($_)
    } @{ $parsed_data || [] };
    if (@{ $parsed_data || [] } && !grep { !$skip_row{ $_->{_row} } } @$parsed_data) {
        my ($other) = map { $_->{trial_name} } grep { $of_other_trial->($_) } @$parsed_data;
        push @error_messages, "The file has no plots of this trial".($other ? " (it is a file of trial $other)" : "").".";
    }
    my %rows_of_other_trial;
    $rows_of_other_trial{ $_->{trial_name} }++ for grep { $of_other_trial->($_) } @{ $parsed_data || [] };
    if (%rows_of_other_trial) {
        $self->_set_parse_warnings({ warning_messages => [ map { "$rows_of_other_trial{$_} row(s) of trial $_ were skipped; upload the file in that trial too if it has corrections there." } sort keys %rows_of_other_trial ] });
    }
    # a place that was not planted keeps its planned accession, so its accession may be left empty
    my %no_accession_needed = map { $_->{_row} => 1 } grep { _flag_value($_->{not_planted}) eq '1' } @{ $parsed_data || [] };
    if (%skip_row || %no_accession_needed) {
        $parsed_errors = [ grep {
            my $error = $_;
            if ($error =~ /^Required column accession_name does not have a value in row (\d+)$/ && $no_accession_needed{$1}) {
                0;
            } elsif ($error =~ /does not have a value in row (\d+)$/) {
                !$skip_row{$1};
            } elsif ($error =~ /appears more than once in rows ([\d,]+)$/) {
                scalar(grep { !$skip_row{$_} } split(/,/, $1)) > 1;
            } else {
                1;
            }
        } @$parsed_errors ];
        $parsed_data = [ grep { !$skip_row{ $_->{_row} } } @$parsed_data ];
    }

    if (@$parsed_errors) {
        push @error_messages, join (". ", @$parsed_errors);
    }

    if (!$parsed_data) {
        $self->_set_parse_errors({ 'error_messages' => [ @error_messages ? @error_messages : "The file could not be read." ] });
        return 0;
    }

    # the values of the rows that are read
    my $values_of = sub {
        my $column = shift;
        my %seen;
        return grep { defined($_) && $_ =~ /\S/ && !$seen{$_}++ } map { $_->{$column} } @$parsed_data;
    };
    my @old_plot_names = $values_of->('plot_name');
    my @new_plot_names = $values_of->('new_plot_name');
    my $validator = CXGN::List::Validate->new();

    my %trial_plots = map {$_->[1] => 1} @{$trial->get_observation_units_direct('plot')};
    foreach my $old_plot_name (@old_plot_names) {
        if (!exists($trial_plots{$old_plot_name})) {
            push @error_messages, "Plot $old_plot_name does not exist in this trial.";
        }
    }

    # not_planted: 1 (or yes, true, x) marks the plot as not planted, 0 (or no,
    # false) as planted; an empty cell leaves it as it is
    foreach my $row (@$parsed_data) {
        my $value = $row->{'not_planted'};
        next if !defined($value) || $value !~ /\S/;
        if (_flag_value($value) eq '') {
            push @error_messages, "Plot $row->{'plot_name'}: not_planted must be 1 (not planted) or 0 (planted), not $value.";
        }
    }

    # rejected: 1 (or yes, true, x) rejects a planted plot, 0 (or no, false) takes
    # it back; an empty cell leaves it as it is; reject_reason only with rejected
    foreach my $row (@$parsed_data) {
        my $value = $row->{'rejected'};
        my $flag = (defined($value) && $value =~ /\S/) ? _flag_value($value) : undef;
        if (defined($flag) && $flag eq '') {
            push @error_messages, "Plot $row->{'plot_name'}: rejected must be 1 (rejected) or 0 (not rejected), not $value.";
        }
        my $reason = $row->{'reject_reason'};
        next if !defined($reason) || $reason !~ /\S/;
        if (defined($flag) && $flag eq '0') {
            push @error_messages, "Plot $row->{'plot_name'}: reject_reason is given but rejected is 0.";
        }
        (my $trimmed = $reason) =~ s/^\s+|\s+$//g;
        if (length($trimmed) > 500) {
            push @error_messages, "Plot $row->{'plot_name'}: reject_reason is longer than 500 characters.";
        }
    }

    # names of plots of this trial can be given to other plots of it (CXGN::Trial::AccessionChange checks them)
    @new_plot_names = grep { !$trial_plots{$_} } @new_plot_names;
    if (scalar(@new_plot_names) > 0) {
        my $validate_new_stocks = $validator->validate($schema, 'new_stocks', \@new_plot_names);
        foreach my $new_name (@{$validate_new_stocks->{invalid}}) { #new name is invalid if any stock, obsolete or not, is found in the db
            push @error_messages, "New plot name $new_name already exists as a stock in the database. ";
        }
    }

    if (scalar(@error_messages) > 0) {
        $self->_set_parse_errors({
            'error_messages' => \@error_messages
        });
        return 0;
    }

    $self->_set_parsed_data({ parsed => $parsed_data });

    return 1; #returns true if validation passed

}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $trial_id = $self->get_trial_id();

    my $parsed_entries = {};

    my $parsed_data = $self->_parsed_data()->{parsed};

    # the accessions are found by CXGN::Trial::AccessionChange, by the rule of the trial
    foreach my $row (@$parsed_data) {
        $parsed_entries->{$row->{'plot_name'}} = {
            'old_plot_name' => $row->{'plot_name'},
            'new_plot_name' => $row->{'new_plot_name'} // '',
            'new_accession_name' => $row->{'accession_name'} // '',
            'not_planted' => _flag_value($row->{'not_planted'}),
            'rejected' => _flag_value($row->{'rejected'}),
            'reject_reason' => do { (my $r = $row->{'reject_reason'} // '') =~ s/^\s+|\s+$//g; $r },
            'seedlot_name' => $row->{'seedlot_name'} // '',
        };
    }

    $self->_set_parsed_data($parsed_entries);
    return 1;
}

# 1, 0, '' for anything else (an empty cell included)
sub _flag_value {
    my $value = shift;
    return '' if !defined($value);
    $value =~ s/^\s+|\s+$//g;
    return 1 if $value =~ /^(1|yes|y|true|x)$/i;
    return 0 if $value =~ /^(0|no|n|false)$/i;
    return '';
}

1;
