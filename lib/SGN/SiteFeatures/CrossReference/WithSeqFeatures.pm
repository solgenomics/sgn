package SGN::SiteFeatures::CrossReference::WithSeqFeatures;
use Moose::Role;

has 'seqfeatures' => (
    is        => 'ro',
    isa       => 'ArrayRef',
    predicate => 'has_seqfeatures',
   );

1;
