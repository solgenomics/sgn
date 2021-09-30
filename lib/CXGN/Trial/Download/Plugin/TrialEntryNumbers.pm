package CXGN::Trial::Download::Plugin::TrialEntryNumbers;

=head1 NAME

CXGN::Trial::Download::Plugin::TrialEntryNumbers

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a trial's xls spreadsheet for uploading entry numbers

my $rel_file = $c->tempfile( TEMPLATE => 'download/downloadXXXXX');
my $tempfile = $c->config->{basepath}."/".$rel_file.".xls";
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_list => \@trial_ids,
    filename => $tempfile,
    format => "TrialEntryNumbers"
});
$create_spreadsheet->download();
$c->stash->{rest} = { filename => $urlencode{$rel_file.".xls"} };

=head1 AUTHORS

David Waring <djw64@cornell.edu>

=cut

use Moose::Role;
use JSON;
use Data::Dumper;

sub verify {
    my $self = shift;
    return 1;
}


sub download {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my @trial_ids = @{$self->trial_list()};

    my $workbook = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $workbook->add_worksheet();

    # Add Column Headers
    my @column_headers = ('accession_name', 'trial_names', 'entry_number');
    for(my $n=0; $n<scalar(@column_headers); $n++) {
        $ws->write(0, $n, $column_headers[$n]);
    }

    # Parse each of the Trials to get Accessions
    my %accession_trial_map;  # Map of accession names -> trial names
    for my $trial_id (@trial_ids) {
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
        my $trial_name = $trial->get_name();
        my $stocks = $trial->get_accessions();
        my $existing_entry_numbers = $trial->get_entry_numbers();
        
        for my $stock (@$stocks) {
            my $stock_id = $stock->{'stock_id'};
            my $accession_name = $stock->{'accession_name'};
            my $value = -1;
            if ( $existing_entry_numbers && $existing_entry_numbers->{$stock_id} ) {
                $value = $existing_entry_numbers->{$stock_id};
            }
            $accession_trial_map{$accession_name}{$trial_name} = $value;
        }
    }

    # Add a row for each Accession
    my $row = 1;
    foreach my $accession_name (sort keys %accession_trial_map) {
        my @trial_names = sort(keys %{$accession_trial_map{$accession_name}});
        my @existing_entry_numbers;
        foreach my $trial_name (@trial_names) {
            my $e = $accession_trial_map{$accession_name}{$trial_name};
            if ( $e && $e != -1 ) {
                push(@existing_entry_numbers, $e);
            }
        }
        my @unique_existing_entry_numbers = _uniq(@existing_entry_numbers);
        $ws->write($row, 0, $accession_name);
        $ws->write($row, 1, join(',', @trial_names));
        $ws->write($row, 2, join(',', @unique_existing_entry_numbers));
        $row++;
    }

    $workbook->close();
}

sub _uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

1;