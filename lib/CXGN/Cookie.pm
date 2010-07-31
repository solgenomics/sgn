package CXGN::Cookie;
use strict;
use warnings;

=head1 CXGN::Cookie

 Functions for using CXGN cookies.  Deprecated.

=cut

sub get_cookie {
    CGI->new->cookie(shift);
}

sub set_cookie {
    die "set_cookie does not support multi-valued setting" unless @_ == 2;
    CGI->new->cookie( -name => shift, -value => @_ );
}

1;
