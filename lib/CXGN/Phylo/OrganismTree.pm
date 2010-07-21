package CXGN::Phylo::OrganismTree;

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
use warnings;

use CXGN::DB::DBICFactory;
use CXGN::Chado::Organism;
use CXGN::Tools::WebImageCache;
use CXGN::Phylo::Node;

use base qw / CXGN::Phylo::Tree /;

=head2 function new()

  Synopsis:	my $t = CXGN::Phylo::OrganismTree->new($schema)
  Arguments:	$schema object
  Returns:	an instance of a Tree object.
  Side effects:	creates the object and initializes some parameters.
  Description:	

=cut

sub new {
    my $class = shift;
    my $schema = shift || die "NO SCHEMA OBJECT PROVIDED!!\n";

    my $self = $class->SUPER::new();

    $self->set_schema($schema);

    return $self;
}

#######

=head2 recursive_children

 Usage: $self->recursive_children($nodes_hashref, $organism, $node, $is_root)
 Desc:  recursively add child nodes starting from root.
 Ret:   nothing
 Args:  $nodes_hashref (organism_id => CXGN::Chado::Organism), $organism object for your root, $node object for your root, 1 (boolean)
 Side Effects: sets name, label, link, tooltip for nodes, highlites leaf nodes.
 Example:

=cut

sub recursive_children {
    my ( $self, $nodes, $o, $n, $species_cache, $is_root ) = @_;

    # $o is a CXGN::Chado::Organism object
    # $n is a CXGN::Phylo::Node object

    $n->set_name( $o->get_species() );
    my $orgkey = "" . $o->get_organism_id() . "";
    $n->get_label()
      ->set_link( "/chado/organism.pl?organism_id=" . $o->get_organism_id() );
    my $content = $species_cache ? $species_cache->get($orgkey) : '';
    $content ||= '';

    $content =~ s/\?/<br\/>/g;
    $n->set_tooltip( $n->get_name() );
    $n->set_onmouseover(
        "javascript:showPopUp('popup','$content','<b>.$o->get_species()</b>')");
    $n->set_onmouseout("javascript:hidePopUp('popup');");
    $n->get_label()->set_name( " " . $o->get_species() );
    $n->get_label()
      ->set_onmouseover( "javascript:showPopUp('popup','" 
          . $content 
          . "','<b>"
          . $o->get_species()
          . "</b>')" );
    $n->get_label()->set_onmouseout("javascript:hidePopUp('popup');");
    $n->set_species( $n->get_name() );
    $n->set_hide_label(0);
    $n->get_label()->set_hidden(0);

    my @cl = $n->get_children();

    my @children = $o->get_direct_children;
    foreach my $child (@children) {

        if ( exists( $nodes->{ $child->get_organism_id() } )
            && defined( $nodes->{ $child->get_organism_id() } ) )
        {

            my $new_node = $n->add_child();
            $self->recursive_children( $nodes, $child, $new_node,
                $species_cache );
        }
    }
    if ( $n->is_leaf() ) { $n->set_hilited(1); }
}

=head2 find_recursive_parent

 Usage: $self->find_recursive_parent($organism, $nodes_hashref)
 Desc:  populate $nodes_hashref  (organism_id=> CXGN::Chado::organism) with recursive parent organisms 
 Ret:   $nodes_hashref
 Args:  $organism object, $nodes_hashref
 Side Effects: none
 Example:

=cut

sub find_recursive_parent {
    my $self     = shift;
    my $organism = shift;
    my $nodes    = shift;    # hash ref

    my $parent = $organism->get_parent;
    if ($parent) {
        my $id = $parent->get_organism_id();

        if ( !$nodes->{$id} ) {
            $nodes->{$id} = $parent;
            $self->find_recursive_parent( $parent, $nodes );
        }
    }
    else { return; }
    return $nodes;
}

=head2 build_tree

 Usage:  $self->build_tree($root_species_name, $species_hashref,$speciesinfo_cache)
 Desc:   builds an organism tree starting from $root with a list of species
 Ret:    a newick representation of the tree
 Args:   $root_species_name, $species_hashref
 Side Effects:  sets tree nodes names and lables, and renders the tree  (see L<CXGN::Phylo::Renderer> )
                calls $tree->generate_newick($root_node, 1)
 Example:

=cut

sub build_tree {
    my ( $self, $root, $species_hash, $species_cache ) = @_;
    my $schema    = $self->get_schema();
    my $root_o    = CXGN::Chado::Organism->new_with_species( $schema, $root );
    my $root_o_id = $root_o->get_organism_id();
    my $organism_link = "/chado/organism.pl?organism_id=";
    my $nodes         = ();
    my $root_node = $self->get_root();    #CXGN::Phylo::Node->new();

    foreach my $s ( keys %$species_hash ) {
        my $o = CXGN::Chado::Organism->new_with_species( $schema, $s );
        if ($o) {
            my $organism_id = $o->get_organism_id();
            $nodes->{$organism_id} = $o;
            $nodes = $self->find_recursive_parent( $o, $nodes );
        }
        else {
            $self->d("NO ORGANISM FOUND FOR SPECIES $s  !!!!!!!!!!!\n\n");
        }
    }

    $self->recursive_children( $nodes, $nodes->{$root_o_id}, $root_node,
        $species_cache, 1 );

    $self->set_show_labels(1);

    $root_node->set_name( $root_o->get_species() );
    $root_node->set_link( $organism_link . $root_o_id );
    $self->set_root($root_node);

    $self->d( "FOUND organism "
          . $nodes->{$root_o_id}
          . " root node: "
          . $root_node->get_name()
          . "\n\n" );

    my $newick = $self->generate_newick( $root_node, 1 );

    $self->standard_layout();

    my $renderer     = CXGN::Phylo::PNG_tree_renderer->new($self);
    my $leaf_count   = $self->get_leaf_count();
    my $image_height = $leaf_count * 20 > 120 ? $leaf_count * 20 : 120;

    $self->get_layout->set_image_height($image_height);
    $self->get_layout->set_image_width(800);
    $self->get_layout->set_top_margin(20);
    $self->set_renderer($renderer);

    #$tree->get_layout->layout();
    $self->get_renderer->render();

    return $newick;
}

1;
