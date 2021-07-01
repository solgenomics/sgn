package SGN::Controller::SequenceMetadata;

use Moose;

use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }


sub manage_sequence_metadata :Path("/breeders/sequence_metadata") Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	    $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
	    return;
    }

    $c->stash->{template} = '/breeders_toolbox/manage_sequence_metadata.mas';
}


sub search_sequence_metadata :Path("/search/sequence_metadata") Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = "/search/sequence_metadata.mas";
}

1;