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
use Bio::Chado::Schema;

use CXGN::Phylo::Tree;
use CXGN::Phylo::Node;

my $page   =  CXGN::Page->new("SOL100 sequencing project","Naama");
my $dbh = CXGN::DB::Connection->new();

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() },
					  { on_connect_do => ['SET search_path TO public'],
					  },);

my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium',  'Solanum galapagense');
my $info;
my @details;
my $root= 'Solanaceae';
my $root_o = CXGN::Chado::Organism->new_with_species($schema, $root);
my $root_o_id = $root_o->get_organism_id();

my $organism_link =   "/chado/organism.pl?organism_id="; 

our %nodes={};
my @unique_nodes=();

my $tree =  CXGN::Phylo::Tree->new(); #;

my $root_node = $tree->get_root();#CXGN::Phylo::Node->new();


foreach my $s (@species ) {
    
    my $o =  CXGN::Chado::Organism->new_with_species($schema, $s);
    if ($o) {
	my $organism_id = $o->get_organism_id();
	$nodes{$organism_id}=$o;
	find_recursive_parent($o);
	
	push @details,
	[
	 map { $_ } (
	     "<a href=\"$organism_link" . $organism_id . "\">$s</a> " ,  "PERSON/GROUP INFO",
	     "PROJECT METADATA",
	 )
	];
	
	
    } else {
	print STDERR "NO ORGANISM FOUND FOR SPECIES $s  !!!!!!!!!!!\n\n";
    }
}

@unique_nodes = values %nodes;
foreach (keys %nodes) { 
    if ($nodes{$_} ) {
    }
}


recursive_children( $nodes{$root_o_id}, $root_node , 1) ;


#$tree->get_root()->recursive_implicit_names();   ##
#$tree->get_root()->recursive_implicit_species();
$tree->set_show_labels(1);
#$tree->set_show_species_in_label(1);

#$tree->update_label_names();


$root_node->set_name($root_o->get_species());
$root_node->set_link($organism_link . $root_o_id);
$tree->set_root($root_node);

print STDERR "FOUND organism " . $nodes{$root_o_id} . " root node: " .  $root_node->get_name() . "\n\n";

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

$info = columnar_table_html(
    headings => [
	'Species', 'Sequencer', 'Project',
    ],
    data         => \@details,
    __alt_freq   => 2,
    __alt_width  => 1,
    __alt_offset => 3,
    );

$page->header();

print page_title_html("SOL100 sequencing project\n");

#print info_section_html(
#    title       => 'Species',
#    contents     => $info ,
#    collapsible => 1,
#    );

print info_section_html(
    title       => 'Tree',
    subtitle    => 'Click on the node name to see more details',
    contents     =>   qq| <br><img src="$uri" border="0" alt="tree_browser" USEMAP="#tree_map"/><br> | . $image_map,
    collapsible => 1,
    );

$page->footer();


sub recursive_children {
    my $o= shift; #CXGN::Chado::Organism object
    my $n = shift; # CXGN::Phylo::Node object
    my $is_root=shift;
   
    $n->set_name($o->get_species());
    $n->get_label()->set_link("/chado/organism.pl?organism_id=" . $o->get_organism_id());
    $n->get_label()->set_name($n->get_name());
    $n->set_tooltip($n->get_name);
    $n->set_species($n->get_name());
	    
    $n->set_hide_label(0);
    $n->get_label()->set_hidden(0);
    #if (!$is_root) {
    
    my @cl=$n->get_children();
   
    print STDERR "is_root = $is_root, node = " . $n->get_name() . " tree = " . $n->get_tree() . "\n" if $is_root; 
    my @children = $o->get_direct_children;
    foreach my $child (@children) {

	if ( exists( $nodes{$child->get_organism_id() } ) && defined( $nodes{$child->get_organism_id()} ) ) {
	    
	    my $new_node=$n->add_child();
	   #  $new_node->set_name($o->get_species());
# 	    $new_node->get_label()->set_link("/chado/organism.pl?organism_id=" . $o->get_organism_id());
# 	    $new_node->get_label()->set_name($new_node->get_name());
	    
# 	    $new_node->set_species($new_node->get_name());
	    
# 	    $new_node->set_hide_label(0);
# 	    $new_node->get_label()->set_hidden(0);
	    # }
	    
	    
	   # print STDERR " !! Child node is " . $child->get_species() . "\n"; 
	    print STDERR "Found child id " . $child->get_organism_id() . " name = " . $child->get_species() . " for parent node " . $n->get_name() . "\n\n";
	    
	    recursive_children($child, $new_node);
	}
    }
    if ($n->is_leaf() ) { $n->set_hilited(1) ; }
}


sub find_recursive_parent {
    my $organism=shift ; 
    my $parent = $organism->get_parent;
    if ($parent) {
	my $id = $parent->get_organism_id();
	
	if (!$nodes{$id} ) {
	    #print STDERR "Found parent id $id for organism " . $parent->get_species() . "\n";
	    $nodes{$id} = $parent ;
	    find_recursive_parent($parent);
	} 
    }
    else { 
	#print STDERR "NO PARENT FOR ORGANISM " . $organism->get_species() . " This must be the root of your tree :-) \n\n";
	return;
    }
    
}
