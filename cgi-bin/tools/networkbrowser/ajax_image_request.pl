
use strict;

use File::Temp;
use File::Spec;
use CXGN::DB::Connection;
use CXGN::Scrap::AjaxPage;
use CXGN::Sunshine::Browser;
use CXGN::Sunshine::Node;
use CXGN::VHost;
use CXGN::Tools::WebImageCache;

my $ajax_page = CXGN::Scrap::AjaxPage->new("Sunshine", "Lukas");

my $dbh = CXGN::DB::Connection->new();

my ($name, $type, $level, $force, $hide_relationships, $hilite) = $ajax_page->get_arguments("name", "type", "level", "force", "hide", "hilite");

my $vh = CXGN::VHost->new();
my $temp_dir = File::Spec->catfile( 
					 $vh ->get_conf("tempfiles_subdir"),
					 "sunshine");

# my $tempfile = File::Temp->new( TEMPLATE=> "tempXXXX",
# 				DIR => $temp_image_dir,
# 				SUFFIX=> '.png');





my $image_url = ""; #File::Spec->catfile($vh->get_conf("$tempfile"));

my $b = CXGN::Sunshine::Browser->new($dbh);

if ($level) { 
    $b->set_level_depth($level);
}

my @hide_relationships = split /\s+/, $hide_relationships;
$b->set_hide_relationships(@hide_relationships);
$b->set_hilited_nodes($hilite);
$b->set_ref_node_name($name);
$b->set_ref_node_type($type);
$b->build_graph();

my $ref_node = $b->get_node("$name");
if (!$ref_node) { 
    print "Content-Type: text/xml\n\n<ajax><error>The node selected is not defined</error></ajax>";
    exit();
}

if ($b->set_reference_node($ref_node)) { 
    #$page->message_page("The node ".$ref_node->get_name()." does not exist in the graph. Sorry!");
}

$b->layout();


my $mapname = "clickmap".time(); # create some unique string so that it reloads on Safari
my $cache = CXGN::Tools::WebImageCache->new();
$cache->set_key($name."-".$type."-".$level."-".(join ":", @hide_relationships));
$cache->set_expiration_time(86400); # seconds, this would be a day.
$cache->set_map_name($mapname); # what's in the <map name='map_name' tag.o
$cache->set_temp_dir($temp_dir);
$cache->set_basedir($vh->get_conf("basepath")); # would get this from VHost...
$force = 1; # always force because the map name has to be unique (no caching is possible... unfortunately)
if (! $cache->is_valid() || $force) {
    # generate the image and associated image map.
    #
    my $systime = time();
    my $img_data = $b->render_string();
    my $img_map_data = $b->get_image_map($mapname);
    $cache->set_image_data($img_data);
    print STDERR "Generated image map: $img_map_data\n";
    $cache->set_image_map_data($img_map_data);
}

my $contents = "Content-Type: text/xml\n\n<ajax>".$cache->get_image_html()."</ajax>\n";


$ajax_page->header();

print $contents;

$ajax_page->footer();

#print STDERR "Sent: $contents\n";



