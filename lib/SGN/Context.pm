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

    my $basepath = $self->get_conf('basepath')
      or die "no base path conf variable defined";
    -d $basepath or die "base path '$basepath' does not exist!";

    return File::Spec->catfile( $basepath, @relpath );
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
    SGN::Role::Site::Files
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
