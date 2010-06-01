
use strict;
use warnings;

use CGI;
use JSON;
use CXGN::DB::Connection;
use SGN::Image;


my $dbh = CXGN::DB::Connection->new();

eval { 
    my $q = CGI->new();
    my ($image_id, $size) = ($q->param("image_id"), $q->param("size"));
    
    my $image = SGN::Image->new($dbh, $image_id);
    
    my $html = $image->get_img_src_tag($size);
    
    print "Content-Type: text/plain\n\n";
    print  to_json({ html=>$html });

};

if ($@) { 
    print "Content-Type: text/plain\n\nerror: $@\n\n";
}
