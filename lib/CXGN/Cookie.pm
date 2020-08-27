package CXGN::Cookie;
use strict;
use warnings;

use CatalystX::GlobalContext '$c';

=head1 CXGN::Cookie

 Functions for using CXGN cookies.  Deprecated.

=cut

sub get_cookie {
    my $cookie = $c->req->cookie(shift)
        or return;
    return $cookie->value;
}

sub set_cookie {
    my ( $name, $value ) = @_;
    $value = '' unless defined $value;
    $c->response->cookies->{$name} = {
        value => $value,
        samesite => 'Strict'
    };
}

1;
