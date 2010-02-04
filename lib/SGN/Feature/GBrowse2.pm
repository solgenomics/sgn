package SGN::Feature::GBrowse2;
use MooseX::Singleton;
use namespace::autoclean;
extends 'SGN::Feature::GBrowse';

use Cwd;
use Carp;
use File::Spec::Functions qw/ tmpdir catdir file_name_is_absolute /;
use Path::Class;

# our context object
sub _build_conf_dir   { shift->feature_dir('conf') }
has '+url_base'   => ( default => '/gb2' );
sub _build_tmp_dir{ dir( tmpdir(), 'gbrowse2' ) }
has '_min_ver' => ( is => 'ro', default => 1.99 );

sub _install {
    my ( $self, $build_dir ) = @_;

    if( $build_dir ) {
	-d $build_dir or croak "gbrowse build dir '$build_dir' does not exist";
    } else {
	# by default, svn co a copy of GBrowse 2.00
	$build_dir = File::Temp->newdir( CLEANUP => 1 );
	system qw| svn co http://gmod.svn.sourceforge.net/svnroot/gmod/Generic-Genome-Browser/tags/release-2_00/ |, $build_dir;
    }

    # check the version of GBrowse we're about to install
    my $version = $self->_find_sources_version( $build_dir );
    unless( $version >= $self->_min_ver ) {
	die "automatic installation not compatible with GBrowse version '$version'\n";
    }

    sub _discard { catdir( tmpdir(), 'gbrowse_discard', @_ ) }
    my %build_args =
	( conf      => _discard( 'conf' ), #< there is a conf dir
	  htdocs    => _absolute( $self->static_dir ),
	  cgibin    => _absolute( $self->cgi_bin ),
	  tmp       => _absolute( $self->tmp_dir ),
	  databases => _discard( 'databases' ),
	  wwwuser   => $self->context->config->{'www_user'},
	 );

    my $curdir = getcwd;
    chdir $build_dir;

    system "./Build clean" if -x 'Build';
    system 'perl', 'Build.PL', map "--$_=$build_args{$_}", keys %build_args;
    system "yes n | ./Build installdeps";
    system "yes n | ./Build install";

    chdir $curdir;

    # clean up unneeded files
    system 'rm', -rf => _discard();
    system 'rm', -rfv => $self->static_dir->subdir('tutorial')->stringify;

    mkdir $self->conf_dir or die "$! creating ".$self->conf_dir." dir.\n";

}

sub _absolute {
    my $d = shift;
    $d = catdir( getcwd, $d ) unless file_name_is_absolute( $d );
    return $d;
}

# returns boolean of whether the feature is installed in the current
# site.  will be part of plugin role
sub is_installed {
    my ( $self ) = @_;

    return
	-d $self->static_dir->subdir('js')
     && -f $self->cgi_bin->file('gbrowse')
     && require Bio::Graphics::Browser2
     && Bio::Graphics::Browser2->VERSION >= $self->_min_ver;
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

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
1;
