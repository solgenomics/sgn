
use strict;
use GCI;
use CXGN::DB::Connection;
use SGN::Image;

my $q = CGI->new();
my ($image_id, $size) = ($q->param("image_id"), $q->param("size"));

my $image = SGN::Image->new($dbh,$image_id);

my $html = $image->get_image_html($size);

return [ $html ];
