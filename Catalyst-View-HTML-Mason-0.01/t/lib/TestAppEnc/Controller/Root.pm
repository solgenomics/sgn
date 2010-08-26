package TestAppEnc::Controller::Root;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace => '',
);

sub index : Path Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(affe => 'tiger');
}

sub enc_utf8 : Local Args(0) {
    my ($self, $ctx) = @_;
    use utf8;
    $ctx->stash( template => 'enc/utf8', verb => 'flüsterte' );
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;
