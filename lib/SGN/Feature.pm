package SGN::Feature;
use MooseX::Singleton;

use namespace::autoclean;

# our context object
has 'context' => ( documentation => 'our context object',
    is => 'ro',
    isa => 'SGN::Context',
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

# has 'feature_dir' => (
#     is => 'ro',
#     isa => 'Path::Class::Dir',
#     coerce => 1,
#     lazy_build => 1,
#    ); sub _build_feature_dir {
#        my $self = shift;
#        return  $self->context->path_to('features', $self->feature_name, @_ );
#    }

# called on apache restart
sub setup {
    my ( $self ) = @_;
}

sub apache_conf {
    return ''
}

1;
