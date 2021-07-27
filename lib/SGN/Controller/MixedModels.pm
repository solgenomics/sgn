
package SGN::Controller::MixedModels;

use Moose;
use URI::FromHash qw | uri |;

BEGIN { extends 'Catalyst::Controller' };


sub mixed_model_index :Path('/tools/mixedmodels') Args(0) { 

    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }
    
    $c->stash->{template} = '/tools/mixedmodels.mas';
}

1;
