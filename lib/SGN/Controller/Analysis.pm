
package SGN::Controller::Analysis;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub view_analyses :Path('/analyses') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/analyses/index.mas';
}

1;
    
