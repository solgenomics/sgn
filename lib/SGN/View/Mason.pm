package SGN::View::Mason;

use strict;
use warnings;

use parent 'Catalyst::View::Mason';

__PACKAGE__->config(
    use_match => 0,
    comp_root => SGN->path_to('mason'),
   );

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
