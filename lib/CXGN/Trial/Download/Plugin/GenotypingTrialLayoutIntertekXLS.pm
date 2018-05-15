
package CXGN::Trial::Download::Plugin::GenotypingTrialLayoutIntertekXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::GenotypingTrialLayoutIntertekXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a trial's layout (as used from CXGN::Trial::Download->trial_download):

A trial's layout can optionally include treatment and phenotype summary
information, mapping to treatment_project_ids and trait_list, selected_trait_names.
These keys can be ignored if you don't need them in the layout.

my $plugin = "GenotypingTrialLayoutIntertekXLS";

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

    my @header = ('Sample ID', 'Plate ID', 'Well location', 'Subject Barcode', 'Plate Barcode', 'Comments');
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
    while (my ($key, $val) = each (%$design)){
        $ws->write($row_count, 0, $val->{plot_name});
        $ws->write($row_count, 1, $trial_name);
        $ws->write($row_count, 2, $val->{plot_number});
        $ws->write($row_count, 3, $val->{source_observation_unit_name});
        $ws->write($row_count, 4, $trial_name);
        $ws->write($row_count, 5, $val->{notes});
        $row_count++;
    }

}

1;
