package SGN::Feature;
use Moose;

use namespace::autoclean;
use File::Spec;

# our context object
has 'context' => (
    documentation => 'our context class',

    is => 'ro',
    does => 'SGN::Role::Site::SiteFeatures',
    required => 1,
    weak_ref => 1,
   );
has 'enabled' => (
    documentation => 'boolean flag, whether this feature is enabled',

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

has 'description' => (
    documentation => <<'',
short plaintext description of the feature, user-visible.  May be used in default views for crossreferences and so forth.

    is => 'ro',
    isa => 'Str',
    default => sub { ucfirst shift->feature_name },
   );

has 'feature_dir' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    coerce => 1,
    lazy_build => 1,
   ); sub _build_feature_dir {
       my $self = shift;
       return $self->context->path_to( 'features', $self->feature_name )->stringify;
   }

sub path_to {
    my $self = shift;
    return File::Spec->catfile( $self->feature_dir, @_ );
}

sub tmpdir {
    my $self = shift;
    return $self->context->tempfiles_base->subdir( 'features', $self->feature_name );
}

# called on application restart
sub setup {
}

# return one or more SGN::SiteFeature::CrossReference objects for the
# given input (input can be anything) or nothing if the query is not
# handled by this Feature.  note that a CrossReference object should
# always be returned, it just might be empty
sub xrefs {
}

sub apache_conf {
    return ''
}

__PACKAGE__->meta->make_immutable;
1;
