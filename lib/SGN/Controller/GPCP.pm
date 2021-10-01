
package SGN::Controller::GPCP;

use Moose;
use Catalyst::Controller;

BEGIN { extends 'Catalyst::Controller'; }

sub gpcp_input :Path('/tools/gpcp') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/tools/gpcp/index.mas';
}

1;
