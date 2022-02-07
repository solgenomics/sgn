
package SGN::Controller::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub dataset :Path('dataset') Args(1) {
    my $self = shift;
    my $c = shift;

    $c->{template} = '/dataset/index.mas';
    
}
