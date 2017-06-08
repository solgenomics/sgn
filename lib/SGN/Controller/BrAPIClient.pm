
package SGN::Controller::BrAPIClient;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/brapihome/') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/home.mas';
}

sub germplasm : Path('/brapihome/germplasm') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/germplasm_search.mas';
}

sub index : Path('/brapiclient/comparegenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/comparegenotypes.mas';
}

1;
