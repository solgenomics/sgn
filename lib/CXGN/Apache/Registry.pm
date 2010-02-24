package CXGN::Apache::Registry;
use strict;
use warnings;

use base qw(ModPerl::RegistryPrefork);
use SGN::Context;

# add a global $c variable to the top of every script for the context
# object
my $cxgn_script_header = <<'EOC';
our $c = SGN::Context->instance;
EOC
sub get_mark_line {
    my $self = shift;
    return $cxgn_script_header.$self->SUPER::get_mark_line(@_);
}

sub read_script {
    my $self = shift;

    # keep site die handlers from interfering with proper 404 and 403
    # error handling
    local $SIG{__DIE__} = undef;

    return $self->SUPER::read_script(@_);
}


1;
__END__

=head1 NAME

CXGN::Apache::Registry - slightly customized subclass of L<ModPerl::RegistryPrefork>

=head1 DESCRIPTION

Adds a global

  our $c = SGN::Context->instance

to the beginning of every script.

Localizes C<$SIG{__DIE__}> when reading script files from disk, to
enable proper 404 and 403 handling in the presence of custom
C<$SIG{__DIE__}> handlers.

=head1 Authors

Robert Buels

=cut
