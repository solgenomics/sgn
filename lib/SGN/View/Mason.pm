package SGN::View::Mason;
use Moose;
extends 'Catalyst::View::HTML::Mason';

use File::Spec;

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

=head1 NAME

SGN::View::Mason - Mason View Component for SGN

=head1 DESCRIPTION

Mason View Component for SGN

=head1 SEE ALSO

L<SGN>, L<HTML::Mason>

=head1 AUTHOR

Robert Buels,,,

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
