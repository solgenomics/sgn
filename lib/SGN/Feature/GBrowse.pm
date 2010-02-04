package SGN::Feature::GBrowse;
use MooseX::Singleton;
use autodie ':all';
use namespace::autoclean;

use Try::Tiny;

use Cwd qw/ abs_path getcwd /;
use File::Path;
use File::Temp ();

use Path::Class;
use File::Spec::Functions qw/ catdir tmpdir file_name_is_absolute /;
use YAML::Any qw/ LoadFile /;

# our context object
has 'context'    => ( is => 'ro', isa => 'SGN::Context', required => 1 );
has 'conf_dir'   => ( is => 'ro', isa => 'Path::Class::Dir', lazy_build => 1 ); sub _build_conf_dir   { shift->feature_dir('gbrowse.conf')    }
has 'static_dir' => ( is => 'ro', isa => 'Path::Class::Dir', lazy_build => 1 ); sub _build_static_dir { shift->feature_dir('www')     }
has 'cgi_bin'    => ( is => 'ro', isa => 'Path::Class::Dir', lazy_build => 1 ); sub _build_cgi_bin    { shift->feature_dir('cgi-bin') }
has 'tmp_dir'    => ( is => 'ro', isa => 'Path::Class::Dir', lazy_build => 1 ); sub _build_tmp_dir    { shift->static_dir->subdir('tmp') }
has 'url_base'   => ( is => 'ro', isa => 'Str', default => '/gb'      );
has 'run_mode'   => ( is => 'ro', isa => 'Str', default => 'modperl'  );

sub feature_name {
    my $self = shift;
    my $name = ref( $self ) || $self;
    $name =~ s/.+:://;
    return lc $name;
}

sub feature_dir {
    my $self = shift;
    return dir( $self->context->path_to('features', $self->feature_name, @_ ) );
}

# called to install and configure GBrowse from svn or a downloaded tarball
sub install {
    my $self = shift;
    my @args = @_;
    try {
	$self->_install( @args );
	$self->is_installed or die "is_installed() returned false";
    } catch {
	# check that the installation was successful
	die "$_\n".$self->feature_name." feature installation failed.\n";
    }
}

sub _install {
    my ( $self, $build_dir ) = @_;

    if( $build_dir ) {
	-d $build_dir or croak "gbrowse build dir '$build_dir' does not exist";
    } else {
	# by default, svn co a copy of GBrowse svn stable branch (1.6x)
	$build_dir = File::Temp->newdir( CLEANUP => 1 );
	system qw| svn co http://gmod.svn.sourceforge.net/svnroot/gmod/Generic-Genome-Browser/branches/stable/ |, $build_dir;
    }

    # check the version of GBrowse we're about to install
    my $version = $self->_find_sources_version( $build_dir );
    $self->_valid_version( $version )
	  or die "automatic installation not compatible with GBrowse version '$version'\n";

    my %build_args =
	( 
	  CGIBIN    => _absolute( $self->cgi_bin ),
	  #tmp       => _absolute( $self->tmp_dir ),
	  GBROWSE_ROOT => '/',
	  HTDOCS    => _absolute( $self->static_dir ),
	  CONF      => _absolute( $self->conf_dir->parent ),
	  DO_XS     => 1,
	  APACHE    => _absolute( $self->static_dir->parent ),
	  #databases => _discard( 'databases' ),
	  #wwwuser   => $self->context->config->{'www_user'},
	 );

    my $curdir = getcwd;
    chdir $build_dir;

    system "make clean" if -e 'Makefile';
    system 'cpan', 'Bio::Graphics::Panel';
    system 'perl', 'Makefile.PL', map "$_=$build_args{$_}", keys %build_args;
    system "make";
    system "make install";

    chdir $curdir;

    # clean up unneeded files
    system 'rm', -rfv => $self->feature_dir->subdir('tutorial');
    system "find ".$self->feature_dir." -type d -and -name .svn | xargs rm -rf";
}

sub _absolute {
    my $d = shift;
    $d = catdir( getcwd, $d ) unless file_name_is_absolute( $d );
    return $d;
}

sub _find_sources_version {
    my ($self, $build_dir) = @_;

    my $meta = dir( $build_dir )->file('META.yml');
    -f $meta or die "no META.yml found in GBrowse build dir '$build_dir', aborting\n";

    $meta = eval { LoadFile( $meta ) }
	or die "could not parse META.yml in GBrowse build dir '$build_dir', aborting\n";

    return $meta->{version};
}

# returns boolean of whether the feature is installed in the current
# site.  will be part of plugin role
sub is_installed {
    my ( $self ) = @_;

    return
	-d $self->static_dir->subdir('js')
     && -f $self->cgi_bin->file('gbrowse')
     && require Bio::Graphics::Browser
     && $self->_valid_version( Bio::Graphics::Browser->VERSION );
}

# check that the given version number is valid for handling with this
# module
sub _valid_version {
    my ( $self, $version ) = @_;
    return $version > 0 && $version < 1.7;
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
    system
	"chmod",
	'0775',
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
