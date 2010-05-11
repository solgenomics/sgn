=head1 NAME

SGN::Context - configuration and context object, meant to export a
similar interface to the Catalyst context object, to help smooth our
transition to Catalyst.

=head1 SYNOPSIS

  my $c = SGN::Context->new;
  my $c = SGN::Context->instance; # new() and instance() do the same thing

  # Catalyst-compatible
  print "my_conf_variable is ".$c->get_conf('my_conf_variable');

=head1 DESCRIPTION

Note that this object is a singleton, based on L<MooseX::Singleton>.
There is only ever 1 instance of it.

=head1 ROLES

Does: L<SGN::SiteFeatures>, L<SGN::Site>

=head1 OBJECT METHODS

=cut

package SGN::Context;
use MooseX::Singleton;

use Carp;
use Cwd ();
use File::Basename;
use File::Spec;
use File::Path ();
use namespace::autoclean;
use Scalar::Util qw/blessed/;
use URI ();

use DBIx::Connector;
use JSAN::ServerSide;

use HTML::Mason::Interp;

use SGN::Config;

=head2 config

  Usage   : my $proj = $c->config->{bac_project_chr_11}
  Returns : config hashref
  Args    : none
  Side Eff: none

  Use this to fetch the full hashref of configuration variables.
  Compatible with Catalyst's $c->config function to help smooth
  our transition to Catalyst.

=cut

has 'config' => ( is => 'ro', isa => 'HashRef', default => \&_new_config );

sub _new_config {
    my $self = shift;
    my $cfg = SGN::Config->load( add_vals =>
                                 {
                                  basepath => $self->_basepath, #< basepath is the old-SGN-compatible name
                                  home     => $self->_basepath, #< home is the catalyst-compatible name
                                  project_name => 'SGN',
                                 }
                               );
    for (values %$cfg) {
        no warnings 'uninitialized';
        s|__HOME__|$self->path_to()|eg;
        s|__path_to\(([^\)]+\))__|$self->path_to( split /,/, $1) |eg;
    }
    return $cfg;
}

has '_basepath' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__basepath {
    # find the path on disk of this file, then find the basename from that
       my @basepath_strategies = (
           # 0. maybe somebody has set an SGN_SITE_ROOT environment variable
           sub {
               return $ENV{SGN_SITE_ROOT} || '';
           },
           # 1. search down the directory tree until we find a dir that contains ./sgn/cgi-bin
           sub {
               my $this_file = _path_to_this_pm_file();
               my $dir = File::Basename::dirname($this_file);
               until ( -d File::Spec->catdir( $dir, 'sgn', 'cgi-bin' ) ) {
                   $dir = File::Spec->catdir( $dir, File::Spec->updir );
               }
               $dir = File::Spec->catdir( $dir, 'sgn' );
               return $dir;
           },
          );

       my $basepath;
       foreach my $basepath_strategy ( @basepath_strategies ) {
           $basepath = $basepath_strategy->();
           last if -d File::Spec->catfile($basepath,'cgi-bin');
       }

       -d File::Spec->catfile( $basepath, 'cgi-bin' )
           or die "could not find basepath starting from this file ("._path_to_this_pm_file().")";

       return Cwd::abs_path( $basepath )
   }

sub _path_to_this_pm_file {
    (my $this_file = __PACKAGE__.".pm") =~ s{::}{/}g;
    $this_file = $INC{$this_file};
    -f $this_file or die "cannot find path to this file (tried '$this_file')";
    return $this_file;
}


=head2 get_conf

  Status  : public
  Usage   : $c->get_conf('my_conf_variable')
  Returns : the value of the variable, as loaded by the configuration
            objects
  Args    : a single configuration variable name
  Side Eff: B<DIES> if the variable is not defined, either in defaults or
            in the configuration file.
  Example:

     my $val = $c->get_conf('my_conf_variable');


It's probably best to use $c->get_conf('var') rather than
$c->config->{var} for most purposes, because get_conf() checks that
the variable is actually set, and dies if not.

=cut

sub get_conf {
  my ( $self, $n ) = @_;

  croak "conf variable '$n' not set, and no default provided"
      unless exists $self->config->{$n};

  return $self->config->{$n};
}

=head2 generated_file_uri

  Usage: my $dir = $c->generated_file_uri('align_viewer','temp-aln-foo.png');
  Desc : get a URI for a file in this site's web-server-accessible
         tempfiles directory, relative to the site's base dir.  Use
         $c->path_to() to convert it to an absolute path if
         necessary
  Args : path components to append to the base temp dir, just
         like the args taken by File::Spec->catfile()
  Ret : path to the file relative to the site base dir.  includes the
        leading slash.
  Side Effects: attempts to create requested directory if does not
                exist.  dies on error

  Example:

    my $temp_rel = $c->generated_file_uri('align_viewer','foo.txt')
    # might return
    /documents/tempfiles/align_viewer/foo.txt
    # and then you might do
    $c->path_to( $temp_rel );
    # to get something like
    /data/local/cxgn/core/sgn/documents/tempfiles/align_viewer/foo.txt

=cut

sub generated_file_uri {
  my ( $self, @components ) = @_;

  @components
      or croak 'must provide at least one path component to generated_file_uri';

  my $filename = pop @components;

  my $dir = $self->tempfiles_subdir( @components );

  return URI->new( "$dir/$filename" );
}


=head2 tempfile

  Usage   : $c->tempfile( TEMPLATE => 'align_viewer/bar-XXXXXX',
                          UNLINK => 0 );
  Desc    : a wrapper for File::Temp->new(), to make web-accessible temp
            files.  Just runs the TEMPLATE argument through
            $c->generated_file_uri().  TEMPLATE can be either just a
            filename, or an arrayref of path components.
  Returns : a L<File::Temp> object
  Args    : same arguments as File::Temp->new(), except:

              - TEMPLATE is relative to the site tempfiles base path,
                  and can be an arrayref of path components,
              - UNLINK defaults to 0, which means that by default
                  this temp file WILL NOT be automatically deleted
                  when it goes out of scope

  Side Eff: dies on error
  Example :

    my ($aln_file, $aln_uri) = $c->tempfile( TEMPLATE =>
                                               ['align_viewer',
                                                'aln-XXXXXX'
                                               ],
                                             SUFFIX   => '.png',
                                           );
    render_image( $aln_file );
    print qq|Alignment image: <img src="$aln_uri" />|;

=cut

sub tempfile {
  my ( $self, %args ) = @_;

  $args{UNLINK} = 0 unless exists $args{UNLINK};

  my @path_components = ref $args{TEMPLATE} ? @{$args{TEMPLATE}}
                                            : ($args{TEMPLATE});

  $args{TEMPLATE} = '' . $self->path_to( $self->generated_file_uri( @path_components ) );
  return File::Temp->new( %args );
}

=head2 tempfiles_subdir

  Usage: my $dir = $page->tempfiles_subdir('some','dir');
  Desc : get a URI for this site's web-server-accessible tempfiles directory.
  Args : (optional) one or more directory names to append onto the tempdir root
  Ret  : path to dir, relative to doc root, include the leading slash
  Side Effects: attempts to create requested directory if does not exist.  dies on error
  Example:

    $page->tempfiles_subdir('foo')
    # might return
    /documents/tempfiles/foo

=cut

sub tempfiles_subdir {
  my ( $self, @dirs ) = @_;

  my $temp_base = $self->get_conf('tempfiles_subdir')
      or die 'no tempfiles_subdir conf var defined!';

  my $dir =  File::Spec->catdir( $temp_base, @dirs );

  my $abs = $self->path_to($dir);
  -d $abs
      or $self->make_generated_dir( $abs )
      or confess "tempfiles dir '$abs' does not exist, and could not create ($!)";

  -w $abs
      or $self->chown_generated_dir( $abs )
      or confess "could not change permissions of tempdir abs, and '$abs' is not writable. aborting.";

  $dir = "/$dir" unless $dir =~ m!^/!;

  return $dir;
}

sub make_generated_dir {
    my ( $self, $tempdir ) = @_;

    mkdir $tempdir or return;

    return $self->chown_generated_dir( $tempdir );
}

# takes one argument, a path in the filesystem, and chowns it appropriately
# intended only to be used here, and in SGN::Apache2::Startup
sub chown_generated_dir {
    my ( $self, $temp ) = @_;
    # NOTE:  $temp can be either a dir or a file

    my $www_uid = $self->_www_uid; #< this will warn if group is not set correctly
    my $www_gid = $self->_www_gid; #< this will warn if group is not set correctly

    return unless $www_uid && $www_gid;

    chown -1, $www_gid, $temp
        or return;

    # 02775 = sticky group bit (makes files created in that dir belong to that group),
    #         rwx for user,
    #         rwx for group,
    #         r-x for others

    # to avoid version control problems, site maintainers should just
    # be members of the www-data group
    chmod 02775, $temp
        or return;

    return 1;
}
sub _www_gid {
    my $self = shift;
    my $grname = $self->config->{www_group};
    $self->{www_gid} ||= (getgrnam $grname )[2]
        or warn "WARNING: www_group '$grname' does not exist, please check configuration\n";
    return $self->{www_gid};
}
sub _www_uid {
    my $self = shift;
    my $uname = $self->config->{www_user};
    $self->{www_uid} ||= (getpwnam( $uname ))[2]
        or warn "WARNING: www_user '$uname' does not exist, please check configuration\n";
    return $self->{www_uid};
}


=head2 path_to

  Usage: $page->path_to('/something/somewhere.txt');
         #or
         $page->path_to('something','somewhere.txt');
  Desc : get the full path to a file relative to the
         base path of the web server
  Args : file path relative to the site root
  Ret  : absolute file path
  Side Effects: dies on error

  This is intended to be compatible with Catalyst's
  very important $c->path_to() method, to smooth
  our transition to Catalyst.

=cut

sub path_to {
    my ( $self, @relpath ) = @_;

    @relpath = map "$_", @relpath; #< stringify whatever was passed

    my $basepath = $self->_basepath
      or die "no base path conf variable defined";
    -d $basepath or die "base path '$basepath' does not exist!";

    return File::Spec->catfile( $basepath, @relpath );
}

=head2 uri_for_file

  Usage: $page->uri_for_file( $absolute_file_path );
  Desc : for a file on the filesystem, get the URI for clients to
         access it
  Args : absolute file path in the filesystem
  Ret  : L<URI> object
  Side Effects: dies on error

  This is intended to be similar to Catalyst's $c->uri_for() method,
  to smooth our transition to Catalyst.

=cut

sub uri_for_file {
    my ( $self, @abs_path ) = @_;

    my $abs = File::Spec->catfile( @abs_path );
    $abs = Cwd::realpath( $abs );

    my $basepath = $self->get_conf('basepath')
      or die "no base path conf variable defined";
    -d $basepath or die "base path '$basepath' does not exist!";
    $basepath = Cwd::realpath( $basepath );

    $abs =~ s/^$basepath//;
    $abs =~ s!\\!/!g;

    return URI->new($abs);
}


=head2 forward_to_mason_view

  Usage: $c->forward_to_mason_view( '/some/thing', foo => 'bar' );
  Desc : call a Mason view with the given arguments and exit
  Args : mason component name (with or without .mas extension),
         hash-style list of arguments for the mason component
  Ret  : nothing.  terminates the program afterward.
  Side Effects: exits after calling the component

  This replaces CXGN::MasonFactory->new->exec( ... )

=cut

has '_mason_interp' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__mason_interp {
       my $self = shift;
       my %params = @_;

       my $global_mason_root = $self->path_to( $self->get_conf('global_mason_lib') );
       my $site_mason_root  = $self->path_to( 'mason' );

       $params{comp_root} = [ [ "site", $site_mason_root     ],
                              [ "global", $global_mason_root ],
                             ];

       my $data_dir = $self->path_to( $self->tempfiles_subdir('data') );

       $params{data_dir}  = join ":", grep $_, ($data_dir, $params{data_dir});

       # have a global $self for the SGN::Context (later to be Catalyst object)
       my $interp = HTML::Mason::Interp->new( allow_globals => [qw[ $c ]],
                                              %params,
                                             );
       $interp->set_global( '$c' => $self );

       return $interp;
   }

sub forward_to_mason_view {
    my $self = shift;
    my @args = @_;
    $self->_trap_mason_error( sub { $self->_mason_interp->exec( @args ) } );
    exit;
}


=head2 render_mason

  Usage: my $string = $c->render_mason( '/page/page_title',
                                        title => 'My Page'  );
  Desc : call a Mason component without any autohandlers, just
         render the component and return its output as a string
  Args : mason component name (with or without .mas),
         hash-style list of component arguments
  Ret  : string of component's output
  Side Effects: none for this function, but the component could
                access the database, or whatnot
  Example :

     print '<div>Blah blah: '.$c->render_mason('/foo').'</div>';

=cut

my $render_mason_outbuf;
has '_bare_mason_interp' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__bare_mason_interp {
       return shift->_build__mason_interp(
           autohandler_name => '', #< turn off autohandlers
           out_method       => \$render_mason_outbuf,
          );
   }

sub render_mason {
    my $self = shift;
    my $view = shift;
    my @args = @_;

    $render_mason_outbuf = '';
    $self->_trap_mason_error( sub { $self->_bare_mason_interp->exec( $view, @args ) });

    return $render_mason_outbuf;
}

sub _trap_mason_error {
    my ( $self, $sub ) = @_;

    eval { $sub->() };
    if( $@ ) {
        if( ref $@ && $@->can('as_brief') ) {
            my $t = $@->as_text;
            # munge mason compilation errors for better backtraces on devel debug screens
            $t =~ s/^Error during compilation of[^\n]+\n// unless $self->get_conf('production_server');
            die $t;
        }
        die $@ if $@;
    }
}


=head2 dbc

  Usage: $c->dbc('profile_name')->dbh->do($sql)
  Desc : get a L<DBIx::Connector> connection for the
         given profile name, or from profile 'default' if not given
  Args : optional profile name
  Ret  : a L<DBIx::Connector> connection
  Side Effects: uses L<DBIx::Connector> to manage database connections.
                calling dbh() on the given connection will create a new
                database handle on the connection if necessary

  Example:

     # straightforward use of a dbh
     $c->dbc
       ->dbh
       ->do($sql);

     # faster way to do the same thing.  be careful though, read the
     # DBIx::Connector::run() documentation before doing this
     $c->dbc->run( fixup => sub { $_->do($sql) });

     # do something in a transaction
     $c->dbc->txn( ping  => sub {
         my $dbh = shift;
         # do some stuff...
     });

=cut

# after the context is first created, populate the 'default' profile
# with dbconn info from the legacy conf interface if necessary,
sub BUILD {
    my ($self) = @_;
    $self->config->{'DatabaseConnection'}->{'default'} ||= do {
	require CXGN::DB::Connection;
	my %conn;
	@conn{qw| dsn user password attributes |} = CXGN::DB::Connection->new_no_connect({ config => $self->config })
	                                                                ->get_connection_parameters;
	$conn{search_path} = $self->config->{'dbsearchpath'} || ['public'];
	\%conn
    };
}

has '_connections' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
sub dbc {
    my ( $self, $profile_name ) = @_;
    $profile_name ||= 'default';

    my $profile = $self->_dbc_profile( $profile_name );

    my $conn = $self->_connections->{$profile_name} ||=
	SGN::Context::Connector->new( @{$profile}{qw| dsn user password attributes |} );

    return $conn;
}
sub _dbc_profile {
    my ( $self, $profile_name ) = @_;
    $profile_name ||= 'default';

    my $profile = $self->config->{'DatabaseConnection'}->{$profile_name}
	or croak "connection profile '$profile_name' not defined";

    # generate the string to set as the search path for this profile,
    # if necessary
    $profile->{'attributes'}{'private_search_path_string'}
	||= $profile->{search_path} ? join ',',map qq|"$_"|, @{$profile->{'search_path'}}  :
	                              'public';

    return $profile;
}
# called on database handles to make sure they are setting the right
# search path
sub _ensure_dbh_search_path_is_set {
    my ($dbh) = @_;
    return $dbh if $dbh->{private_search_path_is_set};

    $dbh->do("SET search_path TO $dbh->{private_search_path_string}");
    #warn "SET search_path TO $dbh->{private_search_path_string}";

    $dbh->{private_search_path_is_set} = 1;
    return $dbh;
}


=head2 dbic_schema

  Usage: my $schema = $c->dbic_schema( 'Schema::Package', 'connection_name' );
  Desc : get a L<DBIx::Class::Schema> with the proper connection
         parameters for the given connection name
  Args : L<DBIx::Class> schema package name,
         (optional) connection name to use
  Ret  : schema object
  Side Effects: dies on failure

=cut

sub dbic_schema {
    my ( $self, $schema_name, $profile_name ) = @_;

    $schema_name or croak "must provide a schema package name to dbic_schema";
    Class::MOP::load_class( $schema_name );

    my $profile = $self->_dbc_profile( $profile_name );

    return $schema_name->connect( @{$profile}{qw| dsn user password attributes |},
                                  { on_connect_call => sub { _ensure_dbh_search_path_is_set( shift->dbh ) } },
                                 );
}


=head2 new_jsan

  Usage: $c->new_jsan
  Desc : instantiates a new L<JSAN::ServerSide> object with the
         correct javascript dir and uri prefix for site-global javascript
  Args : none
  Ret  : a new L<JSAN::ServerSide> object

=cut
has _jsan_params => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );
sub _build__jsan_params {
  my ( $self ) = @_;
  my $js_dir = $self->path_to( $self->get_conf('global_js_lib') );
  -d $js_dir or die "configured global_js_dir '$js_dir' does not exist!\n";

  return { js_dir     => $js_dir,
	   uri_prefix => '/js',
	 };
}
sub new_jsan {
    SGN::Context::JSAN::ServerSide->new( %{ shift->_jsan_params } );
}

=head2 js_import_uris

  Usage: $c->js_import_uris('CXGN.Effects','CXGN.Phenome.Locus');
  Desc : generate a list of L<URI> objects to import the given
         JavaScript modules, with dependencies.
  Args : list of desired modules
  Ret  : list of L<URI> objects

=cut

sub js_import_uris {
    my $self = shift;
    my $j = $self->new_jsan;
    my @urls = @_;
    $j->add(my $m = $_) for @urls;
    return [ $j->uris ];
}


with 'SGN::SiteFeatures', 'SGN::Site';

__PACKAGE__->meta->make_immutable;


##############################################################################3

# tiny DBIx::Connector subclass that makes sure search paths are set
# on database handles before returning them
package SGN::Context::Connector;
use base 'DBIx::Connector';

sub dbh {
    my $dbh = shift->SUPER::dbh(@_);
    SGN::Context::_ensure_dbh_search_path_is_set( $dbh );
    return $dbh;
}

##############################################################################
# tiny JSAN::ServerSide subclass to add modtimes to JSAN::ServerSide URIs
package SGN::Context::JSAN::ServerSide;
use base 'JSAN::ServerSide';
use File::stat;

# add t=<modtime> to all the URIs generated
sub _class_to_uri {
    my ($self, $class) = @_;
    my $path = $self->SUPER::_class_to_file( $class );
    my $t = eval {stat($path)->mtime} || 0;
    my $uri  = $self->SUPER::_class_to_uri( $class );
    return "$uri?t=$t";
}

###
1;#do not remove
###
