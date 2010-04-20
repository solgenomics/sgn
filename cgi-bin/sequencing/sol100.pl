use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				      html_break_string
				    );
use CXGN::People;
use CXGN::Chado::Organism;
use CXGN::DB::DBICFactory;

use CXGN::Phylo::OrganismTree;


my $page   =  CXGN::Page->new("SOL100 sequencing project","Naama");

my $schema = CXGN::DB::DBICFactory
    ->open_schema( 'Bio::Chado::Schema' );

my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium',  'Solanum galapagense');
my $info;

my $root= 'Solanaceae';
my $root_o = CXGN::Chado::Organism->new_with_species($schema, $root);
my $root_o_id = $root_o->get_organism_id();

my $organism_link =   "/chado/organism.pl?organism_id="; 

my $nodes=();

my $tree =  CXGN::Phylo::OrganismTree->new($schema); #;

my $root_node = $tree->get_root();#CXGN::Phylo::Node->new();


foreach my $s (@species ) {
    
    my $o =  CXGN::Chado::Organism->new_with_species($schema, $s);
    if ($o) {
	my $organism_id = $o->get_organism_id();
	$nodes->{$organism_id}=$o;
	$nodes = CXGN::Phylo::OrganismTree::find_recursive_parent($o, $nodes);
	
    } else {
	print STDERR "NO ORGANISM FOUND FOR SPECIES $s  !!!!!!!!!!!\n\n";
    }
}


CXGN::Phylo::OrganismTree::recursive_children( $nodes, $nodes->{$root_o_id}, $root_node , 1) ;

$tree->set_show_labels(1);


$root_node->set_name($root_o->get_species());
$root_node->set_link($organism_link . $root_o_id);
$tree->set_root($root_node);

print STDERR "FOUND organism " . $nodes->{$root_o_id} . " root node: " .  $root_node->get_name() . "\n\n";

my $newick= $tree->generate_newick($root_node, 1);

#a File::Temp object
my $file = $c->tempfile( TEMPLATE =>'tree_browser/tree-XXXXX',
			 SUFFIX   => '.png',
			 UNLINK => 0,
    );



my $filename = $file->filename();
my $uri = $c->uri_for_file($file); 
$filename=$c->path_to($uri);


##print STDERR "\n\nfilename = $filename, uri = $uri\n\n";
$tree->standard_layout();

my $renderer = CXGN::Phylo::PNG_tree_renderer->new($tree); 
my $image_map = $renderer->get_html_image_map("tree_map", $filename, $filename);
$tree->set_renderer($renderer);

$tree->render_png($filename, 1);


my $tree_browser= qq|<a href="/tools/tree_browser/?file=$uri"><img src="$uri" border="0" alt="tree_browser" USEMAP="#tree_map"/><br> $image_map</a>|;



$page->header();

print page_title_html("SOL100 sequencing project\n");

#print info_section_html(
#    title       => 'Species',
#    contents     => $newick . $tree_browser ,
#    collapsible => 1,
#    );

print info_section_html(
    title       => 'Tree',
    subtitle    => 'Click on the node name to see more details',
    contents     =>   qq| <br><img src="$uri" border="0" alt="tree_browser" USEMAP="#tree_map"/><br> | . $image_map,
    collapsible => 1,
    );

$page->footer();


