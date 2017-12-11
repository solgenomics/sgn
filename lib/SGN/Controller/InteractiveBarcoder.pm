package SGN::Controller::InteractiveBarcoder;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub interactive_barcoder_main :Path('/tools/InteractiveBarcoder') Args(0) {
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/tools/InteractiveBarcoder.mas';
}

return 1;
