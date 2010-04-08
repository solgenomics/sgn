package SGN::SiteFeatures::CrossReference::WithPreviewImage;
use Moose::Role;
use MooseX::Types::URI qw/ Uri /;

has 'preview_image_url' => ( is => 'ro', isa => Uri, coerce => 1 );


1;
