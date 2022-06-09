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
    field_crossing_data_order => \@field_crossing_data_order
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

    my @header = ('Cross Unique ID', 'Cross Combination', 'Cross Type', 'Female Parent', 'Female Ploidy', 'Male Parent', 'Male Ploidy', 'Female Plot', 'Male Plot', 'Female Plant', 'Male Plant', 'Seedlot Name', 'Family Name', 'Number of Progenies');
    my $field_crossing_data_order = $self->field_crossing_data_order;
    my @field_crossing_data_header = @$field_crossing_data_order;
    push @header, @field_crossing_data_header;

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my %cross_id_hash;
    my $row_count = 1;
    foreach my $id(@trial_ids) {
        my $crosses = CXGN::Cross->new( {schema => $self->bcs_schema, trial_id => $id });
        my $cross_parent_info_ref = $crosses->get_crosses_and_details_in_crossingtrial();
        my @cross_parent_info = @$cross_parent_info_ref;
        foreach my $each_parent_info (@cross_parent_info) {
            my @each_row_parent_info = ();
            my $parent_cross_id = $each_parent_info->[0];
            @each_row_parent_info = ($each_parent_info->[1], $each_parent_info->[2], $each_parent_info->[3], $each_parent_info->[5], $each_parent_info->[6], $each_parent_info->[8], $each_parent_info->[9], $each_parent_info->[11], $each_parent_info->[13], $each_parent_info->[15], $each_parent_info->[17]);
            $cross_id_hash{$parent_cross_id}{'parent_info'} = \@each_row_parent_info;
        }

        my $seedlot_info_ref = $crosses->get_seedlots_from_crossingtrial();
        my @seedlot_info = @$seedlot_info_ref;
        foreach my $each_seedlot_info (@seedlot_info) {
            my @each_row_seedlot_info = ();
            my $seedlot_cross_id = $each_seedlot_info->[0];
            @each_row_seedlot_info = ($each_seedlot_info->[3]);
            $cross_id_hash{$seedlot_cross_id}{'seedlot_info'} = \@each_row_seedlot_info;
        }

        my $progeny_info_ref = $crosses->get_cross_progenies_trial();
        my @progeny_info = @$progeny_info_ref;
        foreach my $each_progeny_info (@progeny_info) {
            my @each_row_progeny_info = ();
            my $progeny_cross_id = $each_progeny_info->[0];
            @each_row_progeny_info = ($each_progeny_info->[4], $each_progeny_info->[5]);
            $cross_id_hash{$progeny_cross_id}{'progeny_info'} = \@each_row_progeny_info;
        }

        my @all_field_data;
        my $field_info_ref = $crosses->get_cross_properties_trial();
        my @field_info = @$field_info_ref;
        foreach my $each_field_info (@field_info){
            my @each_row_field_info = ();
            my $field_info_cross_id = $each_field_info->[0];
            my $field_info_hash = $each_field_info->[3];
            foreach my $field_info_key (@field_crossing_data_header) {
                push @each_row_field_info, $field_info_hash->{$field_info_key};
            }
            $cross_id_hash{$field_info_cross_id}{'field_info'} = \@each_row_field_info
        }
    }

    my @cross_ids = keys %cross_id_hash;
    my @all_rows;
    foreach my $cross_id (sort keys %cross_id_hash) {
        my @each_row = ();
        my $parents = $cross_id_hash{$cross_id}{'parent_info'};
        push @each_row, @$parents;
        my $seedlots = $cross_id_hash{$cross_id}{'seedlot_info'};
        push @each_row, @$seedlots;
        my $progenies = $cross_id_hash{$cross_id}{'progeny_info'};
        push @each_row, @$progenies;
        my $field_info = $cross_id_hash{$cross_id}{'field_info'};
        push @each_row, @$field_info;

        push @all_rows, [@each_row];
    }

    for my $k (0 .. $#cross_ids) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $all_rows[$k][$l]);
        }
        $row_count++;
    }

}

1;
