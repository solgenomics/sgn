
package SGN::Controller::SOL2020;

use Moose;


BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/sol2020') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/sol2020.mas';
}

1;
