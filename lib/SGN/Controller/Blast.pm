
package SGN::Controller::Blast;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/tools/new-blast/') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $db_id = $c->req->param('db_id');
    my $seq = $c->req->param('seq');

    

    my @datasets = ();

    $c->stash->{db_id} = $db_id;
    $c->stash->{seq} = $seq;
    $c->stash->{datasets} = \@datasets;
    $c->stash->{programs} = [ 'blastn', 'blastp', 'blastx', 'tblastx' ];
    $c->stash->{template} = '/tools/blast/index.mas';

}

1;
