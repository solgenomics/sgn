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



