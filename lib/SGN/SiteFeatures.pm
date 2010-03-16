=head1 NAME

SGN::SiteFeatures - role for a context class that lets it find, load, and configure SGN::Feature objects

=cut

package SGN::SiteFeatures;
use Moose::Role;

use Module::Pluggable::Object;
use namespace::autoclean;
use Try::Tiny;


requires 'config';

# lazy accessor, returns arrayref of instantiated and configured
# SGN::Feature objects
has 'features' => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
   ); sub _build_features {
       my $self = shift;
       my @feature_classes =
           Module::Pluggable::Object
               ->new( 'search_path' => ['SGN::Feature'],
                      'require' => 1,
                     )
               ->plugins;

       my @feature_objects;
       foreach my $class (@feature_classes) {
           my $cfg = $self->config->{$class} || {};
           if( $cfg->{enabled} ) {
               try {
                   my $f = $class->new( %$cfg,
                                        'context' => $self,
                                       );
                   push @feature_objects, $f;
                   $self->_feature_map->{ $f->feature_name } = $f;
               } catch {
                   warn "WARNING: failed to configure $class : $_";
               }
           }
       }

       return \@feature_objects;
   }

sub enabled_features {
    [ grep $_->enabled, @{ shift->features } ]
}

has '_feature_map' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

sub feature {
    shift->_feature_map->{ +shift }
}

1;
