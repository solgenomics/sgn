=head1 NAME

SGN::Context - deprecated, do not use in new code

=cut

# =head1 NAME

# SGN::Context - configuration and context object, meant to export a
# similar interface to the Catalyst context object, to help smooth our
# transition to Catalyst.

# =head1 SYNOPSIS

#   my $c = SGN::Context->new;
#   my $c = SGN::Context->instance; # new() and instance() do the same thing

#   # Catalyst-compatible
#   print "my_conf_variable is ".$c->get_conf('my_conf_variable');

# =head1 DESCRIPTION

# Note that this object is a singleton, based on L<MooseX::Singleton>.
# There is only ever 1 instance of it.

# =head1 ROLES

# Does: L<SGN::SiteFeatures>, L<SGN::Site>

# =head1 OBJECT METHODS

# =cut

package SGN::Context;
use Moose;
use warnings FATAL => 'all';

use Carp;
use CatalystX::GlobalContext '$c';

sub new      { $c || croak 'CXGN::VHost / SGN::Context backward-compatibility not available, please use the appropriate context object' }
sub instance { shift->new }


with qw(
    SGN::Role::Site::Config
);

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );


###
1;#do not remove
###
