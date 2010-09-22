=head1 NAME

CXGN::Apache::Error

Deprecated. Do not use in new code.

=cut

package CXGN::Apache::Error;
use strict;
use warnings;

use CatalystX::GlobalContext '$c';

sub _context {
    return $c if $c;
    require SGN::Context;
    return SGN::Context->instance;
}
sub notify {
    _context()->throw( notify => 1, developer_message => join '', @_ );
}


###
1;#do not remove
###



