package SGN::Feature::GBrowse2::DataSource;
use Moose;
use namespace::autoclean;
use Path::Class ();
use URI::Escape;

extends 'SGN::Feature::GBrowse::DataSource';

has 'path' => ( documentation => <<'',
absolute path to the data source's config file

    is  => 'ro',
    isa => 'Path::Class::File',
    required => 1,
   );


# has 'config' => ( documentation => <<'',
# Bio::Graphics::FeatureFile object for this data source's conf file, from which settings can be 

#     is => 'ro',
#     isa => 'Bio::Graphics::FeatureFile',
#     lazy_build => 1,
#   ); sub _build_config {
#       my ($self) = @_;
#       return Bio::Graphics::FeatureFile->new( -file => $self->conf_dir->file( $self->path ) );
#   }

has 'discriminator' => (
    is => 'ro',
    isa => 'CodeRef',
    lazy_build => 1,
   ); sub _build_discriminator {
       my ( $self ) = @_;
       return $self->gbrowse->config_master->code_setting( $self->name => 'restrict_xrefs' )
              || sub { 1 }
   }


sub xref {
    my ($self, $q) = @_;

    return if ref $q;

    return unless $self->discriminator->($q);

    return SGN::SiteFeatures::CrossReference->new(
        text => qq|search for "$q" in GBrowse: |.$self->description,
        url  => $self->url.'/?name='.uri_escape($q),
        feature => $self->gbrowse,
       );
}


1;
