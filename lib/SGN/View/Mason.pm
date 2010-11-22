package SGN::View::Mason;
use Moose;
extends 'Catalyst::View::HTML::Mason';
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    globals => ['$c'],
    template_extension => '.mas',
);

# must late-compute our interp_args
sub interp_args {
    my $self = shift;
    return {
        comp_root => [
            ( map [ $_->feature_name, $_->path_to('mason')], $self->_app->features ),
            [ main => $self->_app->path_to('mason') ],
           ],
    };
}

=head1 NAME

SGN::View::Mason - Mason View Component for SGN

=head1 DESCRIPTION

Mason View Component for SGN. This extends Catalyst::View::HTML::Mason.

=head1 FUNCTIONS

=head2 $self->component_exists($component)

Check if a Mason component exists. Returns 1 if the component exists, otherwise 0.


=cut

sub component_exists {
    my ( $self, $component ) = @_;

    return $self->interp->comp_exists( $component ) ? 1 : 0;
}

=head1 SEE ALSO

L<SGN>, L<HTML::Mason>, L<Catalyst::View::HTML::Mason>

=head1 AUTHORS

Robert Buels, Jonathan "Duke" Leto

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

__PACKAGE__->meta->make_immutable;
1;
