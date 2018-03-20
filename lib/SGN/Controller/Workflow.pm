use strict;

package SGN::Controller::Workflow;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub workflow :Path('/tools/workflow/')  :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/tools/workflow.mas';
}

1;
