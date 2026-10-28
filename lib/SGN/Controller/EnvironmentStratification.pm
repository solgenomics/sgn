package SGN::Controller::EnvironmentStratification;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path('/tools/environment_stratification') :Args(0) {
  my $self = shift;
  my $c = shift;
  if (! $c->user) {
    $c->res->redirect($c->uri_for('/user/login', { goto_url => $c->req->uri->path_query }));
    return;
  }

  $c->stash->{template} = '/tools/environment_stratification.mas';
}

1;
