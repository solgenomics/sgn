package SGN::Controller::Captcha;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub captcha :Path('/captcha') {
    my $self = shift;
    my $c = shift;

    $c->stash->{config} = $c->config->{captcha};
    $c->stash->{goto_url} = $c->req->param("goto_url");
    $c->stash->{template} = '/captcha.mas';
}

1;