
use strict;

use CXGN::Page;
use SGN::Context;
use CXGN::DB::Connection;

print STDERR "Create page object...\n";
my $page = CXGN::Page->new("", "");

my $dbh;
print STDERR "Creating DB connection...\n";
my $dbh = CXGN::DB::Connection->new();

print STDERR "Retrieving page arguments...\n";
 my ($center_map, $center_map_version_id, $show_physical, $show_ruler, $show_IL, $left_map, $left_map_version_id, $right_map, $right_map_version_id, $color_model)
     = $page->get_encoded_arguments("center_map", "center_map_version_id", "show_physical", "show_ruler", "show_IL", "left_map", "left_map_version_id",  "right_map", "right_map_version_id", "color_model");

print STDERR "Marker 2\n";

my $c = SGN::Context->new();
print STDERR "forwarding to mason view...\n";
$c->forward_to_mason_view('/cview/map/comparison.mas',
			  dbh=>$dbh,
			  center_map=>$center_map, 
			  center_map_version_id=>$center_map_version_id, 
			  show_physical=>$show_physical, 
			  show_ruler=>$show_ruler,
			  show_IL=>$show_IL, 
			  left_map=>$left_map, 
			  left_map_version_id=>$left_map_version_id, 
			  right_map=>$right_map, 
			  right_map_version_id=>$right_map_version_id, 
			  color_model=>$color_model,
    );

print STDERR "This statement is never executed.\n";
			  

