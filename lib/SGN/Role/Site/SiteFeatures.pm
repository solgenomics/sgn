=head1 NAME

SGN::Role::Site::SiteFeatures - role for a context class that lets it find, load, and configure SGN::Feature objects

=cut

package SGN::Role::Site::SiteFeatures;
use 5.10.0;

use Moose::Role;

use Module::Pluggable::Object;
use namespace::autoclean;
use Try::Tiny;

requires 'config';

after 'setup_finalize' => sub {
	my $class = shift;
	$class->_features; #< build features
	$class->setup_features;
};

# lazy accessor, returns arrayref of instantiated and configured
# SGN::Feature objects
sub _features {
    my $class = shift;
    $class = ref $class if ref $class;
    state %feature_objects;
    $feature_objects{$class} ||= do {
        $class->_build__features;
    };
}

sub features {
    values %{ shift->_features }
}

sub feature {
    shift->_features->{+shift};
}

sub site_name {
    shift->config->{name};
}

sub _build__features {
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
        if ( $cfg->{enabled} ) {
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

sub setup_features {
    my $class = shift;
    $_->setup( $class ) for $class->enabled_features;
}

sub enabled_features {
    grep $_->enabled,
      shift->features
}
sub enabled_feature {
    my $f = shift->feature(lc shift)
        or return;
    return unless $f->enabled;
    return $f;
}

sub feature_xrefs {
    my ( $c, $query, $args ) = @_;
    $args ||= {};
    my @f = $c->enabled_features;
    if( my $ex = $args->{exclude} ) {
        $ex = [ $ex ] unless ref $ex;
        my %ex = map { $_ => 1 } @$ex;
        @f = grep !$ex{$_->feature_name}, @f;
    }
    return map $_->xrefs( $query, $args ),  @f;
}

1;
