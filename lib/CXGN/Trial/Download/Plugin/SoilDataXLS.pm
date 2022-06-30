package CXGN::Trial::Download::Plugin::SoilDataXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::SoilDataXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;

sub verify {
    return 1;
}

sub download {
    my $self = shift;
    my $trial_id = $self->trial_id;
    my $prop_id = $self->prop_id;

    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();


}

1;
