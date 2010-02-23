package CXGN::Apache::Registry;
use strict;
use warnings FATAL => 'all';

use base qw(ModPerl::RegistryPrefork);
use SGN::Context;

my $cxgn_script_header = <<'EOC';
our $c = SGN::Context->instance;
EOC
sub get_mark_line {
    my $self = shift;
    return $cxgn_script_header.$self->SUPER::get_mark_line(@_);
}

1;
__END__

=head1 NAME

CXGN::Apache::Registry - slightly altered version of L<ModPerl::Registry>

Only altered to use CXGN::Apache::RegistryCooker as base class

=head1 Authors

Robert Buels, after an earlier set of modifications by John Binns

=head1 See Also

C<L<ModPerl::Registry|docs::2.0::api::ModPerl::Registry>>,
C<L<ModPerl::RegistryCooker|docs::2.0::api::ModPerl::RegistryCooker>>,
C<L<ModPerl::RegistryBB|docs::2.0::api::ModPerl::RegistryBB>> and
C<L<ModPerl::PerlRun|docs::2.0::api::ModPerl::PerlRun>>.

=cut
