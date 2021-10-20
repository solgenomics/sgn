package CXGN::Trial::Download::Plugin::CrossingExperimentXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::CrossingExperimentXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading crosses in a crossing EXPERIMENT (as used from CXGN::Trial::Download->trial_download):

my $plugin = "CrossingExperimentXLS";

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
use CXGN::Cross;

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

    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my @header = ('Cross Unique ID', 'Cross Combination', 'Cross Type', 'Female Parent', 'Female Ploidy', 'Male Parent', 'Male Ploidy', 'Female Plot', 'Male Plot', 'Female Plant', 'Male Plant', 'Family Name', 'Number of Progenies');
    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $field_crossing_data_order = $self->field_crossing_data_order;
    my @field_crossing_data_header = @$field_crossing_data_order;
    print STDERR "FIELD DATA ORDER =".Dumper(\@field_crossing_data_header)."\n";
    push @header, @field_crossing_data_header;
#    print STDERR "COMBINED HEADER =".Dumper(\@header)."\n";

    my $row_count = 1;
    foreach my $id(@trial_ids) {
        my $crosses = CXGN::Cross->new( {schema => $self->bcs_schema, trial_id => $id });
        my $cross_info_ref = $crosses->get_crosses_and_details_in_crossingtrial();
        my @cross_info = @$cross_info_ref;
        my $progeny_info_ref = $crosses->get_cross_progenies_trial();
        my @progeny_info = @$progeny_info_ref;

        my @field_data;
        my $crossing_data = $crosses->get_cross_properties_trial();

        foreach my $cross (@$crossing_data){
            my @row = ();
            my $field_crossing_data_hash = $cross->[3];
            foreach my $cross_prop (@field_crossing_data_header) {
                push @row, $field_crossing_data_hash->{$cross_prop};
            }
            push @field_data, \@row;
        }
#        print STDERR "CROSSES IN EXPERIMENT =".Dumper(\@cross_info)."\n";
#        print STDERR "PROGENIES IN EXPERIMENT =".Dumper(\@progeny_info)."\n";

        for my $i (0 .. $#cross_info) {
            $ws->write($row_count, 0, $cross_info[$i][1]);
            $ws->write($row_count, 1, $cross_info[$1][2]);
            $ws->write($row_count, 2, $cross_info[$i][3]);
            $ws->write($row_count, 3, $cross_info[$i][5]);
            $ws->write($row_count, 4, $cross_info[$i][6]);
            $ws->write($row_count, 5, $cross_info[$i][8]);
            $ws->write($row_count, 6, $cross_info[$i][9]);
            $ws->write($row_count, 7, $cross_info[$i][11]);
            $ws->write($row_count, 8, $cross_info[$i][13]);
            $ws->write($row_count, 9, $cross_info[$i][15]);
            $ws->write($row_count, 10, $cross_info[$i][17]);
            $ws->write($row_count, 11, $progeny_info[$i][4]);
            $ws->write($row_count, 12, $progeny_info[$i][5]);
            $row_count++;
        }
    }

}

1;
