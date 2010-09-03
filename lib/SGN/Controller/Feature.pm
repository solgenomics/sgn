package SGN::Controller::Feature;

=head1 NAME

SGN::Controller::Organism - Catalyst controller for pages dealing with
features

=cut

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';


sub search :Path('/feature/search') Args(0) {
    my ( $self, $c ) = @_;
}

__PACKAGE__->meta->make_immutable;
1;
