package CXGN::Apache::Registry;

use strict;
use warnings FATAL => 'all';

# we try to develop so we reload ourselves without die'ing on the warning
#no warnings qw(redefine); # XXX, this should go away in production!

use base qw(ModPerl::RegistryCooker);
use CXGN::Apache::Error;

sub handler : method {
    my $class = (@_ >= 2) ? shift : __PACKAGE__;
    my $r = shift;
    return $class->new($r)->default_handler();
}

my $parent = 'ModPerl::RegistryCooker';
# the following code:
# - specifies package's behavior different from default of $parent class
# - speeds things up by shortcutting @ISA search, so even if the
#   default is used we still use the alias
my %aliases = (
    new             => 'new',
    init            => 'init',
    default_handler => 'default_handler',
    run             => 'run',
    can_compile     => 'can_compile',
    make_namespace  => 'make_namespace',
    namespace_root  => 'namespace_root',
    namespace_from  => 'namespace_from_filename',
    is_cached       => 'is_cached',
    should_compile  => 'should_compile_if_modified',
    flush_namespace => 'NOP',
    cache_table     => 'cache_table_common',
    cache_it        => 'cache_it',
    read_script     => 'read_script',
    shebang_to_perl => 'shebang_to_perl',
    get_script_name => 'get_script_name',
    chdir_file      => 'NOP',
    get_mark_line   => 'get_mark_line',
    #compile         => 'compile',
    error_check     => 'error_check',
    strip_end_data_segment             => 'strip_end_data_segment',
    convert_script_to_compiled_handler => 'convert_script_to_compiled_handler',
);


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

# sub read_script {
#     my $self = shift;

#     my $sig_handlers_code = <<EOP;
# local \$main::SIG{__DIE__} = \\&CXGN::Apache::Error::Purgatory::cxgn_die_handler;
# EOP

#     $self->debug("reading $self->{FILENAME}") if ModPerl::RegistryCooker::DEBUG & ModPerl::RegistryCooker::D_NOISE;
#     $self->{CODE} = eval { my $code = $self->{REQ}->slurp_filename(0); $code = '{'.$sig_handlers_code.$$code.'}'; \$code }; # untainted
#     if ($@) {
#         $self->log_error("$@");

#         if (ref $@ eq 'APR::Error') {
#             return Apache2::Const::FORBIDDEN if APR::Status::is_EACCES($@);
#             return Apache2::Const::NOT_FOUND if APR::Status::is_ENOENT($@);
#         }

#         return Apache2::Const::SERVER_ERROR;
#     }

#     return Apache2::Const::OK;
# }


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



# in this module, all the methods are inherited from the same parent
# class, so we fixup aliases instead of using the source package in
# first place.
$aliases{$_} = $parent . "::" . $aliases{$_} for keys %aliases;

__PACKAGE__->install_aliases(\%aliases);

# Note that you don't have to do the aliases if you use defaults, it
# just speeds things up the first time the sub runs, after that
# methods are cached.
#
# But it's still handy, since you explicitly specify which subs from
# the parent package you are using
#

# META: if the ISA search results are cached on the first lookup, may
# be we need to alias only those methods that override the defaults?


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
