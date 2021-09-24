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

    print STDERR "\n\n\n\n=========> GENERATE ENTRY NUMBERS TEMPLATE FOR TRIALS:\n";
    print STDERR Dumper \@trial_ids;

    my $workbook = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $workbook->add_worksheet();

    # Add Column Headers
    my @column_headers = ('accession_name', 'trial_names', 'entry_number');
    for(my $n=0; $n<scalar(@column_headers); $n++) {
        $ws->write(0, $n, $column_headers[$n]);
    }


    $workbook->close();
}

1;