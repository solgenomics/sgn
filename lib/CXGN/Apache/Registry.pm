package CXGN::Apache::Registry;

use strict;
use warnings FATAL => 'all';

use base qw(ModPerl::RegistryPrefork);
use CXGN::Apache::Error;
use SGN::Context;

# #########################################################################
# # func: error_check
# # dflt: error_check
# # desc: checks $@ for errors and prints a pretty error page if present
# # args: $self - registry blessed object
# # rtrn: Apache2::Const::SERVER_ERROR if $@ is set, Apache2::Const::OK otherwise
# #########################################################################

# sub error_check {
#     my $self = shift;

#     require CXGN::Apache::Error;

#     # ModPerl::Util::exit() throws an exception object whose rc is
#     # ModPerl::EXIT
#     # (see modperl_perl_exit() and modperl_errsv() C functions)
#     if ($@ && !(ref $@ eq 'APR::Error' && $@ == ModPerl::EXIT)) {
#         $self->log_error($@);
# 	CXGN::Apache::Error::Purgatory::cxgn_die_handler('general error', $@ );
#         return Apache2::Const::SERVER_ERROR;
#     }
#     return Apache2::Const::OK;
# }


# #########################################################################
# # func: read_script
# # dflt: read_script
# # desc: reads the script in
# # args: $self - registry blessed object
# # rtrn: Apache2::Const::OK on success, some other code on failure
# # efct: initializes the CODE field with the source script
# #########################################################################

    my $cxgn_script_header = <<'EOC';
my $c = SGN::Context->instance;
EOC
sub read_script {
    my $self = shift;

    $self->{CODE} = eval { my $c = $cxgn_script_header.${$self->{REQ}->slurp_filename(0)}; \$c };
    if ($@) {
        $self->log_error("$@");

        if (ref $@ eq 'APR::Error') {
            return Apache2::Const::FORBIDDEN if APR::Status::is_EACCES($@);
            return Apache2::Const::NOT_FOUND if APR::Status::is_ENOENT($@);
        }

        return Apache2::Const::SERVER_ERROR;
    }

    return Apache2::Const::OK;
}


sub compile {
    my ($self, $eval) = @_;

    ModPerl::Global::special_list_register(END => $self->{PACKAGE});
    ModPerl::Global::special_list_clear(   END => $self->{PACKAGE});

    {
        # let the code define its own warn and strict level
        no strict;
        no warnings FATAL => 'all'; # because we use FATAL
        eval $$eval;
    }
    if($@) {
	CXGN::Apache::Error::compile_error_notify($@);
    }

    return $self->error_check;
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
