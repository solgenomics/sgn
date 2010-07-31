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
use warnings FATAL => 'all';

use Carp;
use CGI ();
use Cwd ();
use File::Basename;
use File::Spec;
use File::Path ();
use namespace::autoclean;
use Scalar::Util qw/blessed/;
use Storable ();
use URI ();

use JSAN::ServerSide;


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
  Side Eff: dies on error, attempts to create the tempdir if it does
            not exist.
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
    JSAN::ServerSide->new( %{ shift->_jsan_params } );
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


=head2 req

  Usage: $c->req->param('foo')
  Desc : get a CGI-compatible query object for the current request
  Args : none
  Ret  : a CGI-compatible query object

=cut

sub req {
    CGI->new
}


with qw(
    SGN::Role::Site::Config
    SGN::Role::Site::DBConnector
    SGN::Role::Site::DBIC
    SGN::Role::Site::SiteFeatures
    SGN::Role::Site::ExceptionHandling
    SGN::Role::Site::Mason
);

__PACKAGE__->meta->make_immutable;


###
1;#do not remove
###
