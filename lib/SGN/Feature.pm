package SGN::Feature;
use MooseX::Singleton;

use namespace::autoclean;
use File::Spec;

# our context object
has 'context' => ( documentation => 'our context class',
    is => 'ro',
    isa => 'ClassName',
    required => 1,
   );
has 'enabled' => ( documentation => 'boolean flag, whether this feature is enabled',
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

sub feature_name {
    my $self = shift;
    my $name = ref( $self ) || $self;
    $name =~ s/.+:://;
    return lc $name;
}

has 'feature_dir' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    lazy_build => 1,
   ); sub _build_feature_dir {
       my $self = shift;
       return $self->context->path_to('features', $self->feature_name, @_ );
   }

sub path_to {
    my $self = shift;
    return File::Spec->catfile( $self->feature_dir, @_ );
}

# called on apache restart
sub setup {
    #my ( $self ) = @_;
}

# return one or more SGN::SiteFeature::CrossReference objects for the
# given input (input can be anything) or nothing if the query is not
# handled by this Feature.  note that a CrossReference object should
# always be returned, it just might be empty
sub xrefs {
    return unless shift->enabled;
}

sub apache_conf {
    return ''
}

1;
