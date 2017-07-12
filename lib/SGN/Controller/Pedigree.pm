=head1 NAME

SGN::Controller::Pedigree - Catalyst controller for pages dealing with
pedigrees.

=head1 DESCRIPTION

Builds pedigrees from related stocks

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::Pedigree;

use Moose;
#use GraphViz2;
use CXGN::Stock;
use Bio::Chado::NaturalDiversity::Reports;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;
use SVG;
use IPC::Run3;
use Data::Dumper;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub stock_pedigree :  Path('/pedigree/svg')  Args(1) {
  my ($self, $c, $stock_id) = @_;

  my $stock = CXGN::Stock->new( schema => $self->schema, stock_id => $stock_id);
  $c->stash->{stock} = $stock;
  my $stock_ancestor_hash = $stock->get_ancestor_hash();

  #print STDERR "STOCK ANCESTORS: ". Dumper($stock_ancestor_hash);
  my $stock_pedigree_svg = $self->_view_pedigree($stock_ancestor_hash);
  print STDERR "SVG: $stock_pedigree_svg\n\n";
  $c->response->content_type('image/svg+xml');
  if ($stock_pedigree_svg) {
    $c->response->body($stock_pedigree_svg);
  } else {
    my $blank_svg = SVG->new(width=>1,height=>1);
    my $blank_svg_xml = $blank_svg->xmlify();
    $c->response->body($blank_svg_xml);
  }
}

sub stock_descendants :  Path('/descendants/svg')  Args(1) {
  my ($self, $c, $stock_id) = @_;
  my $stock = CXGN::Stock->new( schema=> $self->schema, stock_id => $stock_id);
  $c->stash->{stock} = $stock;

  my $stock_descendant_hash = $stock->get_descendant_hash();
  #print STDERR "STOCK DESCENDANTS: ". Dumper($stock_descendant_hash);
  my $stock_descendants_svg = $self->_view_descendants($stock_descendant_hash);
  $c->response->content_type('image/svg+xml');
  if ($stock_descendants_svg) {
    $c->response->body($stock_descendants_svg);
  } else {
    my $blank_svg = SVG->new(width=>1,height=>1);
    my $blank_svg_xml = $blank_svg->xmlify();
    $c->response->body($blank_svg_xml);
  }
}

sub _traverse_pedigree {
  my $pedigree_reference = shift;
  my %pedigree=%$pedigree_reference;
  my $current_node_id = $pedigree{'id'};
  my $current_node_name = $pedigree{'name'};
  my %nodes;
  my %node_shapes;
  my %node_links;
  my %joins;
  my %joints;
  my %selfs;
  my %invisible_joins;
  my $female_parent_name;
  my $male_parent_name;
  my $female_parent_id;
  my $male_parent_id;
  if (keys %{$pedigree{'female_parent'}}) {
    my %female_parent =  %{$pedigree{'female_parent'}};
    $female_parent_id = $female_parent{'id'};
    if ($female_parent{'name'}) {
      $female_parent_name = $female_parent{'name'};
    } else {
      $female_parent_name = '';
    }
    my $female_parent_link = $female_parent{'link'};
    my ($returned_nodes,$returned_node_links,$returned_node_shapes,$returned_joins,$returned_selfs, $returned_invisible_joins) = _traverse_pedigree(\%female_parent);
    @nodes{keys %$returned_nodes} = values %$returned_nodes;
    @node_links{keys %$returned_node_links} = values %$returned_node_links;
    @node_shapes{keys %$returned_node_shapes} = values %$returned_node_shapes;
    @joins{keys %$returned_joins} = values %$returned_joins;
    @invisible_joins{keys %$returned_invisible_joins} = values %$returned_invisible_joins;
    @selfs{keys %$returned_selfs} = values %$returned_selfs;
    $nodes{$female_parent_id} = $female_parent_name;
    $node_shapes{$female_parent_id} = 'female';
    $node_links{$female_parent_id} = $female_parent_link;
    $joins{$female_parent_id} = $current_node_id;
  }
  if (keys %{$pedigree{'male_parent'}}) {
    my %male_parent =  %{$pedigree{'male_parent'}};
    $male_parent_id = $male_parent{'id'};
    if ($male_parent{'name'}) {
      $male_parent_name = $male_parent{'name'};
    } else {
      $male_parent_name = '';
    }
    my $male_parent_link = $male_parent{'link'};
    my ($returned_nodes,$returned_node_links,$returned_node_shapes,$returned_joins,$returned_selfs, $returned_invisible_joins) = _traverse_pedigree(\%male_parent);
    @nodes{keys %$returned_nodes} = values %$returned_nodes;
    @node_shapes{keys %$returned_node_shapes} = values %$returned_node_shapes;
    @node_links{keys %$returned_node_links} = values %$returned_node_links;
    @joins{keys %$returned_joins} = values %$returned_joins;
    @invisible_joins{keys %$returned_invisible_joins} = values %$returned_invisible_joins;
    @selfs{keys %$returned_selfs} = values %$returned_selfs;
    $nodes{$male_parent_id} = $male_parent_name;
    $node_shapes{$male_parent_id} = 'male';
    $node_links{$male_parent_id} = $male_parent_link;
    $joins{$male_parent_id} = $current_node_id;
  }
  if ($female_parent_id && $male_parent_id) {
    $invisible_joins{$female_parent_id} = $male_parent_id;
  }
  if ($female_parent_id && $male_parent_id) {
    if ($female_parent_id eq $male_parent_id) {
      $selfs{$female_parent_id}=1;
    }
  }
  return (\%nodes,\%node_links,\%node_shapes,\%joins,\%selfs,\%invisible_joins);
}

sub _traverse_descendants {
  my $descendants_reference = shift;
  my %descendants=%$descendants_reference;
  my $current_node_id = $descendants{'id'};
  my $current_node_name = $descendants{'name'};
  my $current_node_link = $descendants{'link'};
  my %nodes;
  my %node_links;
  my %joins;
  my %joints;
  my %selfs;
  my $progeny_name;
  my $progeny_id;
  if ($descendants{'descendants'}) {
    my $progeny_hashref =  $descendants{'descendants'};
    my %progeny = %$progeny_hashref;
    foreach my $progeny_stock_key (keys %progeny) {
      my $progeny_stock_hashref = $progeny{$progeny_stock_key};
      my %progeny_stock = %$progeny_stock_hashref;
      my $progeny_id = $progeny_stock{'id'};
      my $progeny_name = $progeny_stock{'name'};
      my $progeny_link = $progeny_stock{'link'};
      if ($progeny_stock{'descendants'}) {
	my ($returned_nodes,$returned_node_links,$returned_joins,$returned_selfs) = _traverse_descendants(\%progeny_stock);
	@nodes{keys %$returned_nodes} = values %$returned_nodes;
	@node_links{keys %$returned_node_links} = values %$returned_node_links;
	@joins{keys %$returned_joins} = values %$returned_joins;
	@selfs{keys %$returned_selfs} = values %$returned_selfs;
	$nodes{$progeny_id} = $progeny_name;
	$node_links{$progeny_id} = $progeny_link;
	$joins{$progeny_id} = $current_node_id;
      }
    }
  }
  return (\%nodes,\%node_links,\%joins,\%selfs);
}

######################################################

sub _view_pedigree {
  my ($self, $pedigree_hashref) = @_;
  my %pedigree = %$pedigree_hashref;
  #my($graph) = GraphViz2 -> new
  #  (
  #   edge       => {color => 'black', constraint => 'true'},
  #   global => {directed => 0},
  #   graph      => {rankdir => 'TB', bgcolor => '#FAFAFA', ranksep => ".4", nodesep => 1, size => 6},
  #   node       => {color => 'black', fontsize => 10, fontname => 'Helvetica', height => 0},
  #  );
  #graphviz input header
  my $graphviz_input = 'graph Pedigree'."\n".'{'."\n".'graph [ bgcolor="transparent" nodesep=".4" rankdir="TB" ranksep="1" center="true" pad=".2" viewPort="700,400"]'."\n".'node [ color="black" fontname="Helvetica" fontsize="10" ]'."\n".
    'edge [ color="black" constraint="true" ]'."\n";
  my %nodes;
  my %node_shape;
  my %node_links;
  my %joins;
  my %joints;
  my %invisible_joins;
  my %selfs;
  my $current_node_id = $pedigree{'id'};
  my $current_node_name = $pedigree{'name'};
  my $female_parent_name;
  my $male_parent_name;
  my $female_parent_id;
  my $male_parent_id;
  $nodes{$current_node_id} = $current_node_name;
  $node_shape{$current_node_id} = 'root';
  if ($pedigree{'female_parent'}) {
    my %female_parent =  %{$pedigree{'female_parent'}};
    $female_parent_id = $female_parent{'id'};
    if ($female_parent{'name'}) {
      $female_parent_name = $female_parent{'name'};
    } else {
      $female_parent_name = '';
    }
    my $female_parent_link = $female_parent{'link'};
    my ($returned_nodes,$returned_node_links,$returned_node_shapes,$returned_joins,$returned_selfs,$returned_invisible_joins) = _traverse_pedigree(\%female_parent);
    @nodes{keys %$returned_nodes} = values %$returned_nodes;
    @node_links{keys %$returned_node_links} = values %$returned_node_links;
    @node_shape{keys %$returned_node_shapes} = values %$returned_node_shapes;
    @joins{keys %$returned_joins} = values %$returned_joins;
    @invisible_joins{keys %$returned_invisible_joins} = values %$returned_invisible_joins;
    @selfs{keys %$returned_selfs} = values %$returned_selfs;
    $nodes{$female_parent_id} = $female_parent_name;
    $node_links{$female_parent_id} = $female_parent_link;
    $node_shape{$female_parent_id} = 'female';
    $joins{$female_parent_id} = $current_node_id;
  }
  if ($pedigree{'male_parent'}) {
    my %male_parent =  %{$pedigree{'male_parent'}};
    $male_parent_id = $male_parent{'id'};
    if ($male_parent{'name'}) {
      $male_parent_name = $male_parent{'name'};
    } else {
      $male_parent_name = '';
    }
    my $male_parent_link = $male_parent{'link'};
    my ($returned_nodes,$returned_node_links,$returned_node_shapes,$returned_joins,$returned_selfs,$returned_invisible_joins) = _traverse_pedigree(\%male_parent);
    @nodes{keys %$returned_nodes} = values %$returned_nodes;
    @node_links{keys %$returned_node_links} = values %$returned_node_links;
    @node_shape{keys %$returned_node_shapes} = values %$returned_node_shapes;
    @joins{keys %$returned_joins} = values %$returned_joins;
    @invisible_joins{keys %$returned_invisible_joins} = values %$returned_invisible_joins;
    @selfs{keys %$returned_selfs} = values %$returned_selfs;
    $nodes{$male_parent_id} = $male_parent_name;
    $node_links{$male_parent_id} = $male_parent_link;
    $node_shape{$male_parent_id} = 'male';
    $joins{$male_parent_id} = $current_node_id;
  }
  if ($female_parent_id && $male_parent_id) {
    $invisible_joins{$female_parent_id} = $male_parent_id;
  }
  #Quick way to stop making duplicate node declarations in the Graphviz file.
  my %hashcheck;
  #Makes node declarations in the Graphviz file.
  my $graphviz_input_female_nodes;
  my $graphviz_input_male_nodes;
  foreach my $node_key (keys %nodes) {
    unless ($hashcheck{$nodes{$node_key}}) {
      $hashcheck{$nodes{$node_key}} = $nodes{$node_key};
      #get link to stock id
      my $stock_link = $node_links{$node_key};
      unless ($nodes{$node_key}) {
	next;
      }
      if ($node_shape{$node_key} eq 'female') {
	#$graph -> add_node(name => $nodes{$node_key},  href => $stock_link, shape=>'oval', target=>"_top");
	$graphviz_input_female_nodes .= "\"".$nodes{$node_key}.'" [ color="black" shape="oval" href="'.$stock_link.'" target="_top" ] '."\n";
      } elsif ($node_shape{$node_key} eq 'male') {
	#$graph -> add_node(name => $nodes{$node_key},  href => $stock_link, shape=>'box', target=>"_top");
	$graphviz_input_male_nodes .= "\"".$nodes{$node_key}.'" [ color="black" shape="box" href="'.$stock_link.'" target="_top" ] '."\n";
      } else {
	#$graph -> add_node(name => $nodes{$node_key},  href => $stock_link, shape=>'house', color => 'blue', target=>"_top");
	$graphviz_input .= "\"".$nodes{$node_key}.'" [ color="blue" shape="house" target="_top" ] '."\n";
      }
    }
  }
  #add females to the graphviz input first so that they are displayed on the left.
  $graphviz_input .= $graphviz_input_female_nodes;
  $graphviz_input .= $graphviz_input_male_nodes;
  # Hash that stores selfing edges already added in the loop
  my %self_joins;
  foreach my $join_key (keys %joins) {
    #my $tailport;
    #if ($node_shape{$join_key} eq 'female') { $tailport = 'e'; } else {$tailport = 'w';}
    unless ($nodes{$join_key} && $nodes{$joins{$join_key}}) {
      next;
    }
    # Checks if an edge is a selfing-edge.
    if (($selfs{$nodes{$join_key}}) && ($selfs{$nodes{$join_key}} eq $nodes{$joins{$join_key}})) {
      my $edge_combo = $nodes{$join_key}.$nodes{$joins{$join_key}};
      # Checks if a selfing edge was already added for two nodes. Selfing edges are denoted with a double line.
      unless ($self_joins{$edge_combo}) {
	#$graph ->add_edge(from => $nodes{$join_key}, to => $nodes{$joins{$join_key}}, color=>'black:black');
	$graphviz_input .= "\"".$nodes{$join_key}."\" -- \"".$nodes{$joins{$join_key}}."\" [color=>\"black:black\"\n";
	$self_joins{$nodes{$join_key}.$nodes{$joins{$join_key}}} = 1;
      }
    }
    # Else it is just a normal edge with a child comprised of two different parents.
    else {
      #$graph ->add_edge(from => $nodes{$join_key}, to => $nodes{$joins{$join_key}});
      $graphviz_input .= "\"".$nodes{$join_key}."\" -- \"".$nodes{$joins{$join_key}}."\"\n";
    }
  }
  $graphviz_input .= "}";
  if ($pedigree{'male_parent'} || $pedigree{'female_parent'}) {
    my @command = qw(dot -Tsvg);
    my $graphviz_out = '';
    run3 \@command, \$graphviz_input, \$graphviz_out;
    return $graphviz_out;
  } else {
    return undef;
  }
}

sub _view_descendants {
  my $graphviz_input = 'graph Descendants'."\n".'{'."\n".'graph [ bgcolor="transparent" nodesep=".4" rankdir="BT" ranksep="1" center="true" pad=".2" viewPort="700,400"]'."\n".'node [ color="black" fontname="Helvetica" fontsize="10" ]'."\n".
    'edge [ color="black" constraint="true" ]'."\n";
  my ($self, $descendants_hashref) = @_;
  my %descendants = %$descendants_hashref;
  my %nodes;
  my %node_links;
  my %joins;
  my %joints;
  my %selfs;
  my %progeny;
  my $current_node_id = $descendants{'id'};
  my $current_node_name = $descendants{'name'};
  my $progeny_name;
  my $progeny_id;
  $nodes{$current_node_id} = $current_node_name;
  if ($descendants{'descendants'}) {
    my $progeny_hashref =  $descendants{'descendants'};
    %progeny = %$progeny_hashref;
    if ((scalar keys %progeny) >= 1) {
      foreach my $progeny_stock_key (keys %progeny) {
	my $progeny_stock_hashref = $progeny{$progeny_stock_key};
	my %progeny_stock = %$progeny_stock_hashref;
	my $progeny_id = $progeny_stock{'id'};
	my $progeny_name = $progeny_stock{'name'};
	my $progeny_link = $progeny_stock{'link'};
	if ($progeny_stock{'descendants'}) {
	  my ($returned_nodes,$returned_node_links,$returned_joins,$returned_selfs) = _traverse_descendants(\%progeny_stock);
	  @nodes{keys %$returned_nodes} = values %$returned_nodes;
	  @node_links{keys %$returned_node_links} = values %$returned_node_links;
	  @joins{keys %$returned_joins} = values %$returned_joins;
	  @selfs{keys %$returned_selfs} = values %$returned_selfs;
	  $nodes{$progeny_id} = $progeny_name;
	  $node_links{$progeny_id} = $progeny_link;
	  $joins{$progeny_id} = $current_node_id;
	}
      }
    }
  }


  #Quick way to stop making duplicate node declarations in the Graphviz file.
  my %hashcheck;
  #Makes node declarations in the Graphviz file.
  foreach my $node_key (keys %nodes) {
    unless ($hashcheck{$nodes{$node_key}}) {
      $hashcheck{$nodes{$node_key}} = $nodes{$node_key};
      #get link to stock id
      my $stock_link = $node_links{$node_key};
      unless ($nodes{$node_key}) {
	next;
      }
      if ($nodes{$node_key} eq $current_node_name) {
	$graphviz_input .= "\"".$nodes{$node_key}.'" [ color="blue" shape="invhouse" target="_top"] '."\n";
      } else {
	$graphviz_input .= "\"".$nodes{$node_key}.'" [ color="black" shape="oval" href="'.$stock_link.'" target="_top" ] '."\n";
      }
    }
  }
  # Hash that stores selfing edges already added in the loop
  my %self_joins;
  foreach my $join_key (keys %joins) {
    unless ($nodes{$join_key} && $nodes{$joins{$join_key}}) {
      next;
    }
    $graphviz_input .= "\"".$nodes{$join_key}."\" -- \"".$nodes{$joins{$join_key}}."\"\n";
  }
  $graphviz_input .= "}\n";
  #$graph -> run(driver => 'dot',format => 'svg');
  if ((scalar keys %progeny) >= 1) {
    #return $graph->dot_output();
    my @command = qw(dot -Tsvg);
    my $graphviz_out = '';
    run3 \@command, \$graphviz_input, \$graphviz_out;
    return $graphviz_out;
  } else {
    return undef;
  }
}

1;
