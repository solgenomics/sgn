use strict;

package SGN::Controller::Styleguide;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub workflow :Path('/styleguide')  :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/util/styleguide.mas';
}

1;
