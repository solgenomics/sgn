use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
                                     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     tooltipped_text
    /;

use CXGN::Chado::Organism;

use CXGN::DB::DBICFactory;

use CXGN::Phylo::Tree;
use CXGN::Phylo::Node;



# Script to display the major data content of sgn
# Naama Menda, pril 2010
#


my $page = CXGN::Page->new("SGN data overview page", "Naama");
my ($force) = $page->get_encoded_arguments("force");
#my $root = $page->get_encoded_arguments("root");    


my $schema = CXGN::DB::DBICFactory
    ->open_schema( 'Bio::Chado::Schema',
                                  search_path => ['public'],
    );


$page->header("SGN data overview");
print  page_title_html("SGN data overview");


print <<EOF;
	<h3>SGN data overview</h3>
	    <p>
	    This page presents a summary of all currently available data on SGN sorted by species.
	    For a view of our database schema, go <a href="/data/schemas/index.html">here</a>
	    for more details about available maps, loci, libraries, ESTs, metabolic annotation and 
	    phenotypes accessions, see the species of interest.
	    </p>
    <b>List of species currently in the database</b><br /><br />

EOF

my $type = 'web visible'; # we want only the leaf organisms with 'web visible' organismprop
my $cvterm = $schema->resultset("Cv::Cvterm")->search( { name => $type } )->first();

my ($sol_species, $rub_species, $planta_species);


my $sol=();
my $rub=();
my $planta=();


if ($cvterm) {
    my $cvterm_id = $cvterm->get_column('cvterm_id');

    my @organisms= $schema->resultset("Organism::Organismprop")->search(
	{ type_id => $cvterm_id } )->search_related('organism');
   
    foreach my $organism(@organisms) {

	my $species = $organism->get_column('species');
	my $genus= $organism->get_column('genus');
	my $organism_id = $organism->get_column('organism_id');
	my $o=CXGN::Chado::Organism->new($schema, $organism_id);
	my $root_tax=$o->get_organism_by_tax('family');
	if ($root_tax) {
	    my $family = $root_tax->species();
	    $sol->{$species}= $organism_id if $family eq 'Solanaceae' ;
	    $rub->{$species}= $organism_id if $family eq  'Rubiaceae' ;
	    $planta->{$species}= $organism_id if $family eq  'Plantaginaceae' ;
	}
    }
}
##########

my ($sol_uri, $sol_image_map, $sol_map) = get_tree_uri('Solanaceae', $sol);
my ($rub_uri, $rub_image_map, $rub_map) = get_tree_uri('Rubiaceae' , $rub);
my ($planta_uri, $planta_image_map, $planta_map) = get_tree_uri('Plantaginaceae' , $planta);


print  info_section_html(title=>"Solanaceae", 
			 contents=> qq| <br><img src="$sol_uri" border="0" alt="tree_browser" USEMAP="#$sol_map"/><br> | . $sol_image_map,
			 collapsible => 1,
    );
print  info_section_html(title=>"Rubiaceae", 
			 contents=> qq| <br><img src="$rub_uri" border="0" alt="tree_browser" USEMAP="#$rub_map"/><br> | . $rub_image_map,
			 collapsible => 1,
    );

print  info_section_html(title=>"Plantaginaceae", 
			 contents=> qq| <br><img src="$planta_uri" border="0" alt="tree_browser" USEMAP="#$planta_map"/><br> | . $planta_image_map,
			 collapsible => 1,
    );



$page->footer();



sub get_tree_uri  {
    my $root= shift; #'Solanaceae';
    my $map_name = $root . "_map";
    my $species_hash=  shift;
    my $root_o = CXGN::Chado::Organism->new_with_species($schema, $root);
    my $root_o_id = $root_o->get_organism_id();
    
    my $organism_link =   "/chado/organism.pl?organism_id="; 
    
    my $nodes=();
    
    my $tree =  CXGN::Phylo::Tree->new(); #;
    
    my $root_node = $tree->get_root();#CXGN::Phylo::Node->new();

    
    foreach my $s (keys %$species_hash ) {
	
	my $o =  CXGN::Chado::Organism->new_with_species($schema, $s);
	if ($o) {
	    my $organism_id = $o->get_organism_id();
	    if ($organism_id != $species_hash->{$s} ) { 
		$c->throw(is_error=>1, 
			  title => 'Organism_id mismatch!',
			  message=>"Species $s has organism_id " . $species_hash->{$s} . ". CXGN::Chado::Organism returned organism_id $organism_id",
			  developer_message => '',
			  notify => 1,   
		    );
	    }
	    $nodes->{$organism_id}=$o;
	    $nodes = find_recursive_parent($o, $nodes);
	} else {
	    print STDERR "NO ORGANISM FOUND FOR SPECIES $s  !!!!!!!!!!!\n\n";
	}
    }
    
    
    
    recursive_children( $nodes,  $nodes->{$root_o_id}, $root_node , 1) ;
    
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
    
    
    $tree->standard_layout();
    
    my $renderer = CXGN::Phylo::PNG_tree_renderer->new($tree); 
    
    my $leaf_count= $tree->get_leaf_count();
    my $image_height =   $leaf_count*20 ; # > 160  ? $leaf_count*20  : 160 ;

    $tree->get_layout->set_image_height($image_height);
    $tree->get_layout->set_image_width(800);
    
    $tree->set_renderer($renderer);
    #$tree->get_layout->layout();
    $tree->get_renderer->render();
    my $image_map = $renderer->get_html_image_map($map_name, $filename, $filename);
    
    
    $tree->render_png($filename, 1);

    #print STDERR "FONT HEIGHT for tree $map_name is " . $renderer->get_font_height() . " . \n " ;
    return ($uri, $image_map, $map_name);
    
}


sub recursive_children {
    my $nodes=shift;
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
        
    my @cl=$n->get_children();
   
    
    my @children = $o->get_direct_children;
    foreach my $child (@children) {

	if ( exists( $nodes->{$child->get_organism_id() } ) && defined( $nodes->{$child->get_organism_id()} ) ) {
	    
	    my $new_node=$n->add_child();
	    recursive_children($nodes, $child, $new_node);
	}
    }
    if ($n->is_leaf()  ) { $n->set_hilited(1) ; }
    return $nodes;
}


sub find_recursive_parent {
    my $organism=shift ; 
    my $nodes= shift; # hash ref
    my $parent = $organism->get_parent;
    if ($parent) {
	my $id = $parent->get_organism_id();
	
	if (!$nodes->{$id} ) {
	    $nodes->{$id} = $parent ;
	    find_recursive_parent($parent, $nodes);
	} 
    }
    else { return; }
    return $nodes;
}


__END__
	
