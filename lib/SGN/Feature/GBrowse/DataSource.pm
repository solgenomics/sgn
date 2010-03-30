package SGN::Feature::GBrowse::DataSource;
use Moose;
use namespace::autoclean;
use MooseX::Types::Path::Class;
use MooseX::Types::URI qw/ Uri /;
use URI;

use Bio::Graphics::FeatureFile;

has 'name' => ( documentation => <<'',
name of the data source, case sensitive

    is  => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'description' => ( documentation => <<'',
plaintext description of this data source, interpolated into the gbrowse conf

    is => 'ro',
    isa => 'Str',
    required => 1,
  );

has 'gbrowse' => ( documentation => <<'',
GBrowse Feature object this data source belongs to

    is => 'ro',
    required => 1,
  );

has 'url' => ( documentation => <<'',
the base URL for this GBrowse data source, usually cgi_url/datasource_name/

     is         => 'ro',
     isa        => Uri,
     coerce     => 1,
     lazy_build => 1,
   ); sub _build_url {
       my $self = shift;
       URI->new( $self->gbrowse->cgi_url.'/gbrowse/'.$self->name )
   }

__PACKAGE__->meta->make_immutable;
1;
