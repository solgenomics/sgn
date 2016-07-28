
package SGN::Controller::BrAPIClient;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/brapihome/') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/home.mas';
}

sub index : Path('/brapiclient/comparegenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/comparegenotypes.mas';
}

1;
