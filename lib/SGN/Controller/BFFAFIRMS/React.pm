package SGN::Controller::BFFAFIRMS::React;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub react_page : Path('/react/page') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/react/index.html';
}

sub react_table : Path('/react/table') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/react/table/index.html';
}

sub react_breeding_programs : Path('/react/breeders/manage_programs') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/react/breeders/manage_programs/index.html';
}

sub react_basic : Path('/react/basic') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/react/basic/index.html';
}

1;