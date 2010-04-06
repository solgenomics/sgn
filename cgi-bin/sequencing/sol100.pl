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

my $tree =  CXGN::Phylo::Tree->new(); # $newick_string ) ;

my $root_node = $tree->get_root();#CXGN::Phylo::Node->new();
$root_node->set_name($root_o->get_species());
$root_node->set_link($organism_link . $root_o_id);
#$root_node->set_name('Solanaceae');
#$root_node->set_link($organism_link . $root_o_id);



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
	print STDERR "Found organism " . $nodes{$_}->get_species() . " (id = $_ ) \n" ; 
    }
}


recursive_children( $nodes{$root_o_id}, $root_node ) ;

#$tree->set_show_labels(1);
#$tree->set_show_species_in_label(1);


$tree->get_root()->recursive_implicit_names();    # needed?
$tree->get_root()->recursive_implicit_species();

$tree->update_label_names();
my $newick= $tree->generate_newick();

#a File::Temp object
my $file = $c->tempfile( TEMPLATE =>'tree_browser/tree-XXXXX',
			 SUFFIX   => '.png',
			 UNLINK => 0,
    );



my $filename = $file->filename();
my $uri = $c->uri_for_file($file); 
$filename=$c->path_to($uri);


##print STDERR "\n\nfilename = $filename, uri = $uri\n\n";

$tree->render_png($filename);

# foreach (@unique_nodes) {
    
#     my $node= CXGN::Phylo::Node->new();
#     $node->set_name( $_->get_species() );
#     $node->set_link($organism_link . $_->get_organism_id());
    
#     $node->set_tree($tree);
    
#     my $newick= $tree->generate_newick();
#     print STDERR $newick . "\n" ; 
# }


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

print info_section_html(
    title       => 'Species',
    contents     => $info ,
    collapsible => 1,
    );

print info_section_html(
    title       => 'Tree',
    contents     =>  $newick . qq| <br><img src="$uri" border="0" alt="tree_browser" />|,
    collapsible => 1,
    );

$page->footer();


sub recursive_children {
    my $o= shift; #CXGN::Chado::Organism object
    my $n = shift; # CXGN::Phylo::Node object
    $n->set_hide_label(0);
    my @children = $o->get_direct_children;
    $n->set_name($o->get_species());
    $n->get_label()->set_link("/chado/organism.pl?organism_id=" . $o->get_organism_id());
    $n->set_species($n->get_name());
    foreach my $child (@children) {
	
	if ( exists( $nodes{$child->get_organism_id() } ) && defined( $nodes{$child->get_organism_id()} ) ) {
	    my $new_node=$n->add_child();
	    # $new_node->set_tree($n->get_tree());
	    
	    print STDERR "Found child id " . $child->get_organism_id() . " name = " . $child->get_species() . " for parent node " . $n->get_name() . "\n\n";
	    #$new_node->set_name($child->get_species());
	    #$new_node->set_link("/chado/organism.pl?organism_id=" . $child->get_organism_id());
	    $new_node->set_hide_label(0);
	    $new_node->set_hilited(1);
	    recursive_children($child, $new_node);
	}
    }
    #if (scalar(@children) == 0 ) { $n->set_hilited(1) ; }
}


sub find_recursive_parent {
    my $organism=shift ; 
    my $parent = $organism->get_parent;
    if ($parent) {
	my $id = $parent->get_organism_id();
	
	if (!$nodes{$id} ) {
	    print STDERR "Found parent id $id for organism " . $parent->get_species() . "\n";
	    $nodes{$id} = $parent ;
	    find_recursive_parent($parent);
	} 
    }
    else { 
	print STDERR "NO PARENT FOR ORGANISM " . $organism->get_species() . " This must be the root of your tree :-) \n\n";
	return;
    }
    
}
