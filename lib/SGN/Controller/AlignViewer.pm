
package SGN::Controller::AlignViewer;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub align_viewer_input :Path('/tools/align_viewer/input') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $seq_data = $c->req->param("seq_data");
    my $id_data = $c->req->param("id_data");
    my $maxiters = $c->req->param("maxiters");
    my $type = $c->req->param("type");

    $c->stash->{seq_data} = $seq_data;
    $c->stash->{id_data} = $id_data;
    $c->stash->{maxiters} = $maxiters;
    $c->stash->{type} = $type;

    $c->stash->{template} = '/tools/align_viewer.mas';
}

1;
