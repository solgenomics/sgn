package SGN::Feature::GBrowse::DataSource;
use Moose;
use namespace::autoclean;
use Carp;
use MooseX::Types::Path::Class;
use URI;
use URI::Escape;
use URI::FromHash qw/ uri /;

use Bio::Graphics::FeatureFile;

has 'name' => ( documentation => <<'',
name of the data source

    is  => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'description' => ( documentation => <<'',
short description of this data source - one line

    is => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'extended_description' => ( documentation => <<'',
fuller description of this data source, 1-2 sentences

    is => 'ro',
    isa => 'Maybe[Str]',
  );

has 'gbrowse' => ( documentation => <<'',
GBrowse Feature object this data source belongs to

    is => 'ro',
    required => 1,
    weak_ref => 1,
  );

has 'path' => ( documentation => <<'',
absolute path to the data source's config file

    is  => 'ro',
    isa => 'Path::Class::File',
    required => 1,
   );

has 'config' => ( documentation => <<'',
the parsed config of this data source, a Bio::Graphics::FeatureFile

    is  => 'ro',
    isa => 'Bio::Graphics::FeatureFile',
    lazy_build => 1,
   ); sub _build_config {
       Bio::Graphics::FeatureFile->new(
           -file => shift->path->stringify,
           -safe => 1,
          );
   }

has '_databases' => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    lazy_build => 1,
    handles => {
        databases => 'values',
        database  => 'get',
    },
   ); sub _build__databases {
       die 'database parsing not implemented for gbrowse 1.x';
   }


sub view_url {
    shift->_url( 'gbrowse', @_ );
}

sub image_url {
    my ( $self, $q ) = @_;
    $q ||= {};
    $q->{width}    ||= 600;
    $q->{keystyle} ||= 'between',
    $q->{grid}     ||= 'on',
    return $self->_url( 'gbrowse_img', $q );
}

sub _url {
    my ( $self, $script, $query ) = @_;
    return uri( path  => join( '', $self->gbrowse->cgi_url, '/', $script, '/', $self->name ),
                ($query ? (query => $query) : ()),
               );
}



__PACKAGE__->meta->make_immutable;
1;
