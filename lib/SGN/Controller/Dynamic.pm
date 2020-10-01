
package SGN::Controller::Dynamic;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub render_page : Path('/pages') Args(1) {
    my $self = shift;
    my $c = shift;
    my $mason = shift;
    
    $c->stash->{template} = '/dynamic/'.$mason.".mas";
}

1;
