
package CXGN::Trial::Download::Plugin::GenotypingTrialLayoutDartSeqXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::GenotypingTrialLayoutDartSeqXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a genotyping trial's layout (as used from CXGN::Trial::Download->trial_download):

my $plugin = "GenotypingTrialLayoutDartSeqXLS";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    filename => $tempfile,
    format => $plugin,
});
my $error = $download->download();
my $file_name = $trial_id . "_" . "$what" . ".$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;

sub verify { 
    return 1;
} 

sub download { 
    my $self = shift;

    print STDERR "DATALEVEL ".$self->data_level."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my @header = ('Plate ID', 'Row', 'Column', 'Organism', 'Species', 'Genotype', 'Tissue', 'Comments');
    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }
    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id });
    my $trial_name = $trial->get_name();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $self->bcs_schema, trial_id => $self->trial_id,, experiment_type => 'genotyping_layout'});
    my $design = $trial_layout->get_design();
    #print STDERR Dumper $design;
    my $row_count = 1;
    foreach my $key (sort keys %$design){
        my $val = $design->{$key};
        my $comments = 'Notes: '.$val->{notes}.' AcquisitionDate: '.$val->{acquisition_date}.' Concentration: '.$val->{concentration}.' Volume: '.$val->{volume}.' Person: '.$val->{dna_person}.' Extraction: '.$val->{extraction};
        $ws->write($row_count, 0, $trial_name);
        $ws->write($row_count, 1, $val->{row_number});
        $ws->write($row_count, 2, $val->{col_number});
        $ws->write($row_count, 3, $val->{species});
        $ws->write($row_count, 4, $val->{species});
        $ws->write($row_count, 5, $val->{source_observation_unit_name});
        $ws->write($row_count, 6, $val->{tissue_type});
        $ws->write($row_count, 7, $comments);
        $row_count++;
    }

}

1;
