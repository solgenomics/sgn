package TestApp::Controller::Root;

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

sub path_class : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(affe => 'tiger');
    $ctx->stash( template => 'index' );
    $ctx->forward( 'View::PathClass' );
}

sub enc_utf8 : Local Args(0) {
    my ($self, $ctx) = @_;
    use utf8;
    $ctx->stash( template => 'enc/utf8', verb => 'flüsterte' );
}

sub globals : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(
      maus => 'grau',
      horde => [ 'foo', 'bar' ],
      stamm => { 'chef' => 'ich' },
    );
    $ctx->forward( 'View::Global' );
}

sub no_globals : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash( template => 'globals' );
    $ctx->forward( 'View::Global' );
}


sub mixed_globals : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(
      maus => 'grau',
      stamm => [ 'totally' => 'wrong' ],
      horde => 'me too!',
    );
    $ctx->stash( template => 'globals' );
    $ctx->forward( 'View::Global' );
}

sub xpackage_globals : Local Args(0) {
    my ($self, $ctx) = @_;
    $ctx->stash(affe => 'tiger');
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;

1;
