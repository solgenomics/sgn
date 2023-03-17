package CXGN::Trial::Download::Plugin::AccessionsWithPedigreeXLSX;

=head1 NAME

CXGN::Trial::Download::Plugin::AccessionsWithPedigreeXLSX

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

    my @header = ('Accession Name','Female Parent','Male Parent','Cross Type');

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $row_count = 1;
    my $info_ref = CXGN::Cross->get_progeny_info($schema);
    my @all_rows;
    foreach my $each_info (@$info_ref){
        my ($female_id, $female_name, $male_id, $male_name, $accession_id, $accession_name, $cross_type) =@$each_info;
        push @all_rows,[$accession_name, $female_name, $male_name, $cross_type];
    }

    for my $k (0 .. $#all_rows) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $all_rows[$k][$l]);
        }
        $row_count++;
    }

}

1;
