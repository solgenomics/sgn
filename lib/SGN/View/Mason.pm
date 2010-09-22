package SGN::View::Mason;
use Moose;
extends 'Catalyst::View::HTML::Mason';

use File::Spec;


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

    my $cr = $self->interp_args->{comp_root}
        or return 0;
    $cr = [['main' => $cr ]] unless ref $cr;
    for ( @$cr ) {
        my (undef, $path) = @$_;
        my $p =  File::Spec->catfile( $path, $component );
        return 1 if -f $p;
    }
    return 0;
}

=head1 SEE ALSO

L<SGN>, L<HTML::Mason>, L<Catalyst::View::HTML::Mason>

=head1 AUTHORS

Robert Buels, Jonathan "Duke" Leto

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
