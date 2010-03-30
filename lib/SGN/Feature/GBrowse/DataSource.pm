package SGN::Feature::GBrowse::DataSource;
use Moose;
use MooseX::Types::Path::Class;

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


__PACKAGE__->meta->make_immutable;
1;
