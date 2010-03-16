=head1 NAME

SGN::Feature::GBrowse - site feature object to provide GBrowse integration

=cut

package SGN::Feature::GBrowse;
use MooseX::Singleton;
use namespace::autoclean;

extends 'SGN::Feature';

use MooseX::Types::Path::Class;

has 'perl_inc' => ( documentation => 'arrayref of paths to set in PERL5LIB if running in fastcgi or cgi mode',
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
   );
has 'conf_dir' => ( documentation => 'directory where GBrowse will look for its conf files',
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    lazy_build => 1,
   ); sub _build_conf_dir   { shift->feature_dir('gbrowse.conf') }

has 'static_url' => ( documentation => 'URL base for GBrowse static files',
    is => 'ro',
    isa => 'Str',
    required => 1,
   );
has 'static_dir' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    required => 1,
   );
has 'cgi_url' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
   );
has 'cgi_bin' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    required => 1,
   );
has 'tmp_dir' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    required => 1,
   );
has 'run_mode' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
   );

# assembles a URI linking to gbrowse.
sub link_uri {
    my ( $self, $conf_name, $params ) = @_;

    my $uri = URI->new($self->cgi_url."/$conf_name/");
    $uri->query_form( %$params );
    return $uri;
}

# # returns a string of apache configuration to be included during
# # startup. will be part of plugin role
# sub apache_conf {
#     my ( $self ) = @_;
#     my $dir         = $self->static_dir;
#     my $conf        = $self->conf_dir;
#     my $cgibin      = $self->cgi_bin;
#     my $tmp         = $self->tmp_dir;
#     my $cgiroot     = basename($cgibin);
#     my $perl5lib    = $self->added_to_INC;
#     my $inc         = $perl5lib ? "SetEnv PERL5LIB \"$perl5lib\""   : '';
#     my $fcgi_inc    = $perl5lib ? "-initial-env PERL5LIB=$perl5lib" : '';
#     my $fcgid_inc   = $perl5lib ? "DefaultInitEnv PERL5LIB $perl5lib"        : '';
#     my $modperl_inc = $inc ? "Perl$inc" : '';
#     my $url_base    = $self->url_base;

#     my %runmode_conf = (
# 	modperl => <<"",
#    Alias /$url_base "$cgibin"
#    <Location /mgb2>
#      SetHandler perl-script
#      PerlResponseHandler ModPerl::Registry
#      PerlOptions +ParseHeaders
#      PerlSetEnv GBROWSE_CONF "$conf"
#      $modperl_inc
#    </Location>

# 	fcgi => <<"",
#   Alias /$url_base "$cgibin"
#   <Location /fgb2>
#     SetHandler   fcgid-script
#     Options      ExecCGI
#   </Location>
#   DefaultInitEnv GBROWSE_CONF $conf
#   $fcgid_inc

# 	fastcgi => <<"",
#   Alias /$url_base "$cgibin"
#   <Location /fgb2>
#     SetHandler   fastcgi-script
#     Options      ExecCGI
#   </Location>
#   FastCgiConfig $fcgi_inc -initial-env GBROWSE_CONF=$conf

# 	cgi => <<"",
# ScriptAlias  "/$url_base"   "$cgibin"
# <Directory "$cgibin">
#   $inc
#   SetEnv GBROWSE_CONF "$conf"
# </Directory>

#        );

#     my $runmode_conf = $runmode_conf{ $self->run_mode }
# 	or confess "invalid run mode '".$self->run_mode."'";

#     return <<EOC;
# Alias        "/$url_base/static/i/" "$tmp/images/"
# Alias        "/$url_base/static"    "$dir"

# <Directory "$dir">
#   Options -Indexes -MultiViews +FollowSymLinks
# </Directory>

# $runmode_conf
# EOC
# }

1;
