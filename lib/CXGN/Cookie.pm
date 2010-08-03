package CXGN::Cookie;
use strict;
use warnings;

use CatalystX::GlobalContext '$c';

=head1 CXGN::Cookie

 Functions for using CXGN cookies.  Deprecated.

=cut

sub get_cookie {
    $c->req->cookie(shift);
}

sub set_cookie {
    $c->response->cookies->{+shift} = { value => shift };
}

1;
