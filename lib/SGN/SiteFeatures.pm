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
has '_features' => (
    is         => 'ro',
    isa        => 'HashRef[SGN::Feature]',
    traits     => ['Hash'],
    lazy_build => 1,
    handles => {
        features => 'values',
        feature  => 'get',
    },
   ); sub _build__features {
       my $self = shift;
       my @feature_classes =
           Module::Pluggable::Object
               ->new( 'search_path' => ['SGN::Feature'],
                      'require' => 1,
                     )
               ->plugins;

       my %feature_objects;
       foreach my $class (@feature_classes) {
           my $cfg = $self->config->{feature}{$class} || {};
           if( $cfg->{enabled} ) {
               try {
                   my $f = $class->new( %$cfg,
                                        'context' => $self,
                                       );
                   $feature_objects{$f->feature_name} = $f;
               } catch {
                   warn "WARNING: failed to configure $class : $_";
               }
           }
       }

       return \%feature_objects;
   }

sub enabled_features {
    grep $_->enabled,
      shift->features
}
sub enabled_feature {
    my $f = shift->feature(shift)
        or return;
    return unless $f->enabled;
    return $f;
}

sub feature_xrefs {
    map $_->xrefs( @_ ),  shift->enabled_features
}


package SGN::SiteFeatures::CrossReference;
use Moose;
use MooseX::Types::URI 'Uri';

has 'url' => ( documentation => <<'',
the absolute or relative URL where the full resource can be accessed, e.g. /unigenes/search.pl?q=SGN-U12

    is  => 'ro',
    isa => Uri,
    required => 1,
    coerce => 1,
   );


has 'text' => ( documentation => <<'',
a short text description of the contents of the resource referenced, for example "6 SGN Unigenes"

    is  => 'ro',
    isa => 'Str',
    required => 1,
   );


has 'is_empty' => ( documentation => <<'',
true if the cross reference is empty, may be used as a rendering hint

    is  => 'ro',
    isa => 'Bool',
    default => 0,
   );

has 'feature' => ( documentation => <<'',
the site feature object this cross reference points to

    is => 'ro',
    required => 1,
   );

__PACKAGE__->meta->make_immutable;
1;

