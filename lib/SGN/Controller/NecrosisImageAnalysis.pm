
package SGN::Controller::NecrosisImageAnalysis;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' };

sub home : Path('/tools/necrosis_image_analysis') Args(0) { 
    my $self = shift;
    my $c = shift;
    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }
    $c->stash->{template} = 'tools/necrosis_image_analysis.mas';
}

1;
