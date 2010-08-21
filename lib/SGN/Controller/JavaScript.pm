package SGN::Controller::JavaScript;
use Moose;
use namespace::autoclean;

use Digest::MD5 'md5_hex';
use Storable qw/ nfreeze /;
use List::MoreUtils qw/uniq/;

BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config( path => File::Spec->catdir(qw( static js )));

has '_package_defs' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__package_defs {
       my $self = shift;

       my $cache = Cache::File->new(
           cache_root       => $self->_app->path_to( $self->_app->tempfiles_subdir('cache','js_packs') ),

           default_expires  => 'never',
           size_limit       => 50,
           removal_strategy => 'Cache::RemovalStrategy::LRU',

          );
   }

=head1 ACTIONS

=head2 js_package

Serve a minified, concatenated package of javascript, assembled and
stored on the previous request.

Args: package identifier (32-character hex)

=cut

sub js_package :Path('/js_pack') :Args(1) {
    my ( $self, $c, $key ) = @_;

    # NOTE: you might think that we should cache the minified
    # javascript too, but it turns out to not be much faster!

    $c->stash->{js} = $self->_package_defs->thaw( $key );
    $c->forward( 'View::JavaScript' );
}

=head1 REGULAR METHODS

=head2 action_for_js_package

  Usage: $controller->action_for_js_package( 'sgn', 'jquery' )
  Desc : get a list of (action,arguments) for getting a minified,
         concatenated set of javascript containing the given libraries.
  Args : list of JS libraries to include in the package
  Ret  : list of ( $action, @arguments )
  Side Effects: saves the list of js libs in a cache for subsequent
                requests
  Example:

      $c->uri_for( $c->controller('JavaScript')->action_for_js_package( 'sgn', 'jquery' ))

=cut

sub action_for_js_package {
    my $self = shift;
    my @files = uniq @_; #< do not sort, load order might be important

    my $key = md5_hex( join ' ', @files );

    # record files for this particular package of JS
    unless( $self->_package_defs->exists( $key ) ) {
        $self->_package_defs->freeze( $key => \@files );
    }

    return $self->action_for('js_package'),  $key;
}

__PACKAGE__->meta->make_immutable;
1;
