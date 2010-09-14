=head1 NAME

CXGN::Apache::Error

Deprecated. Do not use in new code.

=cut

package CXGN::Apache::Error;
use strict;
use warnings;

use SGN::Context;

sub notify {
    SGN::Context->instance->throw( developer_message => join '', @_ );
}


###
1;#do not remove
###



