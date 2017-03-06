package SGN::Controller::Accession_usage;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub accession_usage : Path('/accession_usage') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/stock/accession_usage.mas';

}

1;
