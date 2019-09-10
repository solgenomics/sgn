package SGN::Controller::EPG;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SGN::Controller::MetabolomicsHost - show metabolomics data for the host citrus on CG.org. add subroutines for other pages in menu

=cut


sub metabolomics_host_index :Path('/metabolomics_host/index') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/metabolomics_host/index.mas';
}

sub metabolomics_host_chin_csinensis_2019 :Path('/metabolomics_host/chin_csinensis_2019') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/metabolomics_host/chin_csinensis_2019.mas';
}

sub metabolomics_host_ramsey_climon_2019 :Path('/metabolomics_host/ramsey_climon_2019') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/metabolomics_host/ramsey_climon_2019.mas';
}

1;
