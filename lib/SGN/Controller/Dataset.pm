
package SGN::Controller::Dataset;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub dataset :Path('dataset') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = shift;
    
    $c->stash->{dataset_id} = $dataset_id;
    $c->stash->{template} = '/dataset/index.mas';
    
}
