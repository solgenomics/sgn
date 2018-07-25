use strict;

package SGN::Controller::DataExplorer;

use Moose;
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }

sub data_explorer :Path('/tools/dataexplorer') {
    my $self =shift;
    my $c = shift;
    $c->stash->{template} = '/tools/data_explorer.mas';
}
1;
