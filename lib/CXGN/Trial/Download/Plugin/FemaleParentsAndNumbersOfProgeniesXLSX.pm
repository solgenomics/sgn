package CXGN::Trial::Download::Plugin::FemaleParentsAndNumbersOfProgeniesXLSX;

=head1 NAME

CXGN::Trial::Download::Plugin::FemaleParentsAndNumbersOfProgeniesXLSX

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
    my $schema = $self->bcs_schema;
    my $ss = Excel::Writer::XLSX->new($self->filename());
    my $ws = $ss->add_worksheet();

    my @header = ('Female Parent Name','Number of Progenies');

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $row_count = 1;
    my $cross_obj = CXGN::Cross->new({schema => $schema, parent_type => 'female_parent'});
    my $data = $cross_obj->get_parents_and_numbers_of_progenies();
    my @all_female_parents = @$data;
    my @all_rows;
    foreach my $each_row (@all_female_parents){
        my ($female_id, $female_name, $num_of_progenies) =@$each_row;
        push @all_rows,[$female_name, $num_of_progenies];
    }

    for my $k (0 .. $#all_rows) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $all_rows[$k][$l]);
        }
        $row_count++;
    }

}

1;
