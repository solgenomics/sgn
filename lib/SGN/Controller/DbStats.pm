
package SGN::Controller::DbStats;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub dbstats :Path('/breeders/dbstats') Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/breeders_toolbox/db_stats.mas';
}

1;
