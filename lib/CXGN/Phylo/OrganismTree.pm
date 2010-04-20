=head1 NAME

CXGN::Phylo::OrgnanismTree - an object to handle SGN organism  trees

=head1 USAGE

 my $tree = CXGN::Phylo::OrganismTree->new();
 my $root = $tree->get_root();
 my $node = $root->add_child();
 $node->set_name("I'm a child node");
 $node->set_link("http://solgenomics.net/");
 my $child_node = $node->add_child();
 $child_node->set_name("I'm a grand-child node");
 print $tree->generate_newick();

=head1 DESCRIPTION

This is a subcass of L<CXGN::Phylo::Tree>



=head1 AUTHORS

 Naama Menda (nm249@cornell.edu)


=cut

use strict;

use CXGN::DB::DBICFactory;
use CXGN::Chado::Organism;

package CXGN::Phylo::OrganismTree;

use base qw / CXGN::Phylo::Tree / ;

=head2 function new()

  Synopsis:	my $t = CXGN::Phylo::OrganismTree->new($schema)
  Arguments:	$schema object
  Returns:	an instance of a Tree object.
  Side effects:	creates the object and initializes some parameters.
  Description:	

=cut

sub new {
    my $class = shift;
    my $schema = shift || CXGN::DB::DBICFactory
	->open_schema( 'Bio::Chado::Schema');
    
    my $self = $class->SUPER::new();
    return $self;
}



#######

=head2 get_tree_uri

 Usage: $self->get_tree_uri($root, $species_hash)
 Desc:  function for generating a tree file uri
 Ret:   ($uri, $image_map, $map_name)
 Args:  root node name (from the organism table), hashref of species names (keys), values = organism ids
 Side Effects:
 Example:

=cut




=head2 recursive_children

 Usage: recursive_children($nodes_hashref, $organism, $node, $is_root)
 Desc:  recursively add child nodes starting from root.
 Ret:   nothing
 Args:  $nodes_hashref (organism_id => CXGN::Chado::Organism), $organism object for your root, $node object for your root, 1 (boolean)
 Side Effects: sets name, label, link, tooltip for nodes, highlites leaf nodes.
 Example:

=cut


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
}


=head2 find_recursive_parent

 Usage: find_recursive_parent($organism, $nodes_hashref)
 Desc:  populate $nodes_hashref  (organism_id=> CXGN::Chado::organism) with recursive parent organisms 
 Ret:   $nodes_hashref
 Args:  $organism object, $nodes_hashref
 Side Effects: none
 Example:

=cut



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


##########
return 1##
##########
