package SGN::Feature::GBrowse;
use MooseX::Singleton;
use autodie ':all';
use namespace::autoclean;

use Cwd;
use File::ShareDir ();
use File::Path;
use Path::Class;
use File::Spec::Functions qw/ catdir tmpdir /;
use YAML::Any qw/ LoadFile /;

# our context object
has 'context'    => ( is => 'ro', isa => 'SGN::Context', required => 1 );
has 'conf_dir'   => ( is => 'ro', isa => 'Str', lazy_build => 1 ); sub _build_conf_dir   { shift->feature_dir('conf')    }
has 'static_dir' => ( is => 'ro', isa => 'Str', lazy_build => 1 ); sub _build_static_dir { shift->feature_dir('www')     }
has 'cgi_bin'    => ( is => 'ro', isa => 'Str', lazy_build => 1 ); sub _build_cgi_bin    { shift->feature_dir('cgi-bin') }
has 'tmp_dir'    => ( is => 'ro', isa => 'Str', default => catdir( tmpdir(), 'gbrowse2' ) );
has 'url_base'   => ( is => 'ro', isa => 'Str', default => '/gb2'                         );
has 'run_mode'   => ( is => 'ro', isa => 'Str', default => 'modperl'                      );

sub feature_name {
    my $self = shift;
    my $name = ref( $self ) || $self;
    $name =~ s/.+::$//;
    return $name;
}

sub feature_dir {
    my $self = shift;
    local $SIG{__DIE__} = \&Carp::confess;
    return $self->context->path_to('features', $self->feature_name, @_ );
}

# called to install and configure GBrowse from svn or a downloaded tarball
sub install {
    my ( $self, $build_dir ) = @_;
    $build_dir    or croak 'must provide path to a GBrowse source dir';
    -d $build_dir or croak "gbrowse build dir '$build_dir' does not exist";

    # check the version of GBrowse we're about to install
    my $version = $self->_gbrowse_version( $build_dir );
    unless( $version >= 1.99 ) {
	die "automatic installation not compatible with GBrowse version '$version'\n";
    }

    sub _discard { catdir( tmpdir(), 'gbrowse_discard', @_ ) }
    my %build_args =
	( conf      => _discard( 'conf' ), #< there is a conf dir
	  htdocs    => $self->static_dir,
	  cgibin    => $self->cgi_bin,
	  tmp       => $self->tmp_dir,
	  databases => _discard( 'databases' ),
	  wwwuser   => $self->context->config->{'www_user'},
	 );

    my $curdir = getcwd;
    chdir $build_dir;

    system 'perl', 'Build.PL', map "--$_=$build_args{$_}", keys %build_args;
    system "yes n | ./Build installdeps";
    system "./Build install";
    rmtree( _discard() );

    chdir $curdir;
}

sub _gbrowse_version {
    my ($self, $build_dir) = @_;

    my $meta = dir( $build_dir )->file('META.yml');
    -f $meta or die "no META.yml found in GBrowse build dir '$build_dir', aborting\n";

    $meta = eval { LoadFile( $meta ) }
	or die "could not parse META.yml in GBrowse build dir '$build_dir', aborting\n";

    return $meta->{version};
}

# assembles a URI linking to gbrowse.  part of plugin role
sub link_uri {
    my ( $self,$conf_name, $params ) = @_;

    my $uri = URI->new('/'.$self->url_base."/$conf_name/");
    $uri->query_form( %$params );
    return $uri;
}

# called on apache restart - should eventually be part of plugin role
sub setup {
    my ( $self ) = @_;
    system
	"chown",
	-R => $self->context->config->{'www_user'}.'.'.$self->config->{'www_group'},
	$self->tmp_dir;
}

# returns a string of apache configuration to be included during
# startup. will be part of plugin role
sub apache_conf {
    my ( $self ) = @_;
    my $dir         = $self->static_dir;
    my $conf        = $self->conf_dir;
    my $cgibin      = $self->cgi_bin;
    my $tmp         = $self->tmp_dir;
    my $cgiroot     = basename($cgibin);
    my $perl5lib    = $self->added_to_INC;
    my $inc         = $perl5lib ? "SetEnv PERL5LIB \"$perl5lib\""   : '';
    my $fcgi_inc    = $perl5lib ? "-initial-env PERL5LIB=$perl5lib" : '';
    my $fcgid_inc   = $perl5lib ? "DefaultInitEnv PERL5LIB $perl5lib"        : '';
    my $modperl_inc = $inc ? "Perl$inc" : '';
    my $url_base    = $self->url_base;

    my %runmode_conf = (
	modperl => <<"",
   Alias /$url_base "$cgibin"
   <Location /mgb2>
     SetHandler perl-script
     PerlResponseHandler ModPerl::Registry
     PerlOptions +ParseHeaders
     PerlSetEnv GBROWSE_CONF "$conf"
     $modperl_inc
   </Location>

	fcgid => <<"",
  Alias /$url_base "$cgibin"
  <Location /fgb2>
    SetHandler   fcgid-script
    Options      ExecCGI
  </Location>
  DefaultInitEnv GBROWSE_CONF $conf
  $fcgid_inc

	fastcgi => <<"",
  Alias /$url_base "$cgibin"
  <Location /fgb2>
    SetHandler   fastcgi-script
    Options      ExecCGI
  </Location>
  FastCgiConfig $fcgi_inc -initial-env GBROWSE_CONF=$conf

	cgi => <<"",
ScriptAlias  "/$url_base"   "$cgibin"
<Directory "$cgibin">
  $inc
  SetEnv GBROWSE_CONF "$conf"
</Directory>

);

    my $runmode_conf = $runmode_conf{ $self->run_mode }
	or confess "invalid run mode '".$self->run_mode."'";

    return <<EOC;
Alias        "/$url_base/static/i/" "$tmp/images/"
Alias        "/$url_base/static"    "$dir"

<Directory "$dir">
  Options -Indexes -MultiViews +FollowSymLinks
</Directory>

$runmode_conf
EOC
}

__PACKAGE__->meta->make_immutable;
1;
