package CXGN::Trial::Download::Plugin::CrossEntriesXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::CrossEntriesXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Excel::Writer::XLSX;
use CXGN::Cross;

sub verify {
    return 1;
}

sub download {
    my $self = shift;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $self->filename() =~ /(\.[^.]+)$/;
    my $ss;

    if ($extension eq '.xlsx') {
        $ss = Excel::Writer::XLSX->new($self->filename());
    }
    else {
        $ss = Spreadsheet::WriteExcel->new($self->filename());
    }

    my $ws = $ss->add_worksheet();

    my @header = ('Cross Unique ID', 'Cross Type', 'Female Parent', 'Female Ploidy', 'Female Genome Structure', 'Male Parent', 'Male Ploidy', 'Male Genome Structure', 'Pollination Date', "Number of Seeds", 'Number of Progenies', 'Crossing Experiment', 'Description', 'Location');

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $cross_properties_ref = $self->field_crossing_data_order();
    my $row_count = 1;
    my $crosses = CXGN::Cross->new( {schema => $self->bcs_schema, field_crossing_data_order => $cross_properties_ref});

    my $cross_entries_ref = $crosses->get_all_cross_entries();
    my @cross_entries = @$cross_entries_ref;

    my @all_cross_entries = ();
    foreach my $each_cross (@cross_entries){
        my $cross_unique_id = $each_cross->[1];
        my $cross_type = $each_cross->[2];
        my $female_parent = $each_cross->[4];
        my $female_ploidy = $each_cross->[5];
        my $female_genome_structure = $each_cross->[6];
        my $male_parent = $each_cross->[8];
        my $male_ploidy = $each_cross->[9];
        my $male_genome_structure = $each_cross->[10];
        my $pollination_date = $each_cross->[11];
        my $number_of_seeds = $each_cross->[12];
        my $number_of_progenies = $each_cross->[13];
        my $crossing_experiment_name = $each_cross->[15];
        my $description = $each_cross->[16];
        my $location = $each_cross->[17];

        push @all_cross_entries, [$cross_unique_id, $cross_type, $female_parent, $female_ploidy, $female_genome_structure, $male_parent, $male_ploidy, $male_genome_structure, $pollination_date, $number_of_seeds, $number_of_progenies, $crossing_experiment_name, $description, $location];
    }
#    print STDERR "CROSSES ENTRIES =".Dumper(\@all_cross_entries)."\n";

    for my $k (0 .. $#all_cross_entries) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $all_cross_entries[$k][$l]);
        }
        $row_count++;
    }

}

1;
