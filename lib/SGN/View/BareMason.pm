package SGN::View::BareMason;
use Moose;
extends 'SGN::View::Mason';

around 'interp_args' => sub {
    my $orig = shift;
    my $args = shift->$orig( @_ );
    $args->{autohandler_name} = '';
    return $args;
};

=head1 NAME

SGN::View::BareMason - like the Mason view, except with no autohandlers

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
