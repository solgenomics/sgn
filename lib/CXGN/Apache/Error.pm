=head1 NAME

CXGN::Apache::Error

Deprecated. Do not use in new code.

=cut

package CXGN::Apache::Error;
use strict;
use warnings;

use SGN::Context;

sub cxgn_die_handler {
    SGN::Context->instance->error_notify('died',@_);
    die @_;
}

sub cxgn_warn_handler {
    warn @_;
}

sub notify {
    SGN::Context->instance->error_notify( @_ );
}


###
1;#do not remove
###



