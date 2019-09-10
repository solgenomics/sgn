
package CXGN::Trial::Download::Plugin::GenotypingTrialLayoutIntertekXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::GenotypingTrialLayoutIntertekXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a genotyping plate's layout (as used from CXGN::Trial::Download->trial_download):

my $plugin = "GenotypingTrialLayoutIntertekXLS";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    trial_list => \@trial_id_list,
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

    my @trial_ids;
    if ($self->trial_id) {
        push @trial_ids, $self->trial_id;
    }
    if ($self->trial_list) {
        push @trial_ids, @{$self->trial_list};
    }

    print STDERR "DATALEVEL ".$self->data_level."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my @header = ('Sample ID', 'Plate ID', 'Well location', 'Subject Barcode', 'Plate Barcode', 'Comments');
    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }
    my $row_count = 1;
    foreach (@trial_ids) {
        my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $_ });
        my $trial_name = $trial->get_name();
        my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $self->bcs_schema, trial_id => $_, experiment_type => 'genotyping_layout'});
        my $design = $trial_layout->get_design();
        #print STDERR Dumper $design;
        no warnings 'uninitialized';
        foreach my $key (sort keys %$design){
            my $val = $design->{$key};
            my $comments = 'Notes: '.$val->{notes}.' AcquisitionDate: '.$val->{acquisition_date}.' Concentration: '.$val->{concentration}.' Volume: '.$val->{volume}.' TissueType: '.$val->{tissue_type}.' Person: '.$val->{dna_person}.' Extraction: '.$val->{extraction};
            my $sample_name = $val->{plot_name}."|||".$val->{accession_name};
            $ws->write($row_count, 0, $sample_name);
            $ws->write($row_count, 1, $trial_name);
            $ws->write($row_count, 2, $val->{plot_number});
            $ws->write($row_count, 3, $val->{source_observation_unit_name});
            $ws->write($row_count, 4, $trial_name);
            $ws->write($row_count, 5, $comments);
            $row_count++;
        }
    }

}

1;
