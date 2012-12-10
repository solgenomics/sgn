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
use CXGN::Chado::Stock;
use Bio::Chado::NaturalDiversity::Reports;
use SGN::View::Stock qw/stock_link stock_organisms stock_types/;
use SVG;
use IPC::Run3;
use Data::Dumper;

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
  my $stock = CXGN::Chado::Stock->new($self->schema, $stock_id);
  $c->stash->{stock} = $stock;
  my $stock_row = $self->schema->resultset('Stock::Stock')
    ->find({ stock_id => $stock_id });
  my $stock_pedigree = $self->_get_pedigree($stock_row);
  print STDERR "STOCK PEDIGREE: ". Data::Dumper::Dumper($stock_pedigree);
  my $stock_pedigree_svg = $self->_view_pedigree($stock_pedigree);
  print STDERR "SVG: $stock_pedigree_svg\n\n";
  my $is_owner = $self->_check_role($c);
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
  my $stock = CXGN::Chado::Stock->new($self->schema, $stock_id);
  $c->stash->{stock} = $stock;
  my $stock_row = $self->schema->resultset('Stock::Stock')
    ->find({ stock_id => $stock_id });
  my $stock_descedants = $self->_get_descendants($stock_row);
  my $stock_descendants_svg = $self->_view_descendants($stock_descedants);
  my $is_owner = $self->_check_role($c);
  $c->response->content_type('image/svg+xml');
  if ($stock_descendants_svg) {
    $c->response->body($stock_descendants_svg);
  } else {
    my $blank_svg = SVG->new(width=>1,height=>1);
    my $blank_svg_xml = $blank_svg->xmlify();
    $c->response->body($blank_svg_xml);
  }
}

sub _check_role  {
  my ( $self, $c) = @_;
  my $logged_user = $c->user;
  my $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
  my $curator   = $logged_user->check_roles('curator') if $logged_user;
  my $submitter = $logged_user->check_roles('submitter') if $logged_user;
  my $sequencer = $logged_user->check_roles('sequencer') if $logged_user;
  my $dbh = $c->dbc->dbh;
  ##################
  ###Check if a stock page can be printed###
  my $stock = $c->stash->{stock};
  my $stock_id = $stock ? $stock->get_stock_id : undef ;
  my $stock_type = $stock->get_object_row ? $stock->get_object_row->type->name : undef ;
  my $type = 1 if $stock_type && !$stock_type=~ m/population/;
  # print message if stock_id is not valid
  unless ( ( $stock_id =~ m /^\d+$/ )  ) {
    $c->throw_404( "No stock/accession exists for that identifier." );
  }
  unless ( $stock->get_object_row || !$stock_id ) {
    $c->throw_404( "No stock/accession exists for that identifier." );
  }
  my $props = $self->_stockprops($stock);
  # print message if the stock is visible only to certain user roles
  my @logged_user_roles = $logged_user->roles if $logged_user;
  my @prop_roles = @{ $props->{visible_to_role} } if  ref($props->{visible_to_role} );
  my $lc = List::Compare->new( {
				lists    => [\@logged_user_roles, \@prop_roles],
				unsorted => 1,
			       } );
  my @intersection = $lc->get_intersection;
  if ( !$curator && @prop_roles  && !@intersection) { # if there is no match between user roles and stock visible_to_role props
    $c->throw(is_client_error => 0,
	      title             => 'Restricted page',
	      message           => "Stock $stock_id is not visible to your user!",
	      developer_message => 'only logged in users of certain roles can see this stock' . join(',' , @prop_roles),
	      notify            => 0, #< does not send an error email
	     );
  }
  # print message if the stock is obsolete
  my $obsolete = $stock->get_is_obsolete();
  if ( $obsolete  && !$curator ) {
    $c->throw(is_client_error => 0,
	      title             => 'Obsolete stock',
	      message           => "Stock $stock_id is obsolete!",
	      developer_message => 'only curators can see obsolete stock',
	      notify            => 0, #< does not send an error email
	     );
  }
  # print message if stock_id does not exist
  if ( !$stock ) {
    $c->throw_404('No stock exists for this identifier');
  }
  ####################
  my $is_owner;
  my $owner_ids = $c->stash->{owner_ids} || [] ;
  if ( $stock && ($curator || $person_id && ( grep /^$person_id$/, @$owner_ids ) ) ) {
    $is_owner = 1;
  }
  return $is_owner;
}

sub _stockprops {
  my ($self,$stock) = @_;

  my $bcs_stock = $stock->get_object_row();
  my $properties ;
  if ($bcs_stock) {
    my $stockprops = $bcs_stock->search_related("stockprops");
    while ( my $prop =  $stockprops->next ) {
      push @{ $properties->{$prop->type->name} } ,   $prop->value ;
    }
  }
  return $properties;
}

sub _get_pedigree {
  my ($self,$bcs_stock) = @_;
  my %pedigree;
  $pedigree{'id'} = $bcs_stock->stock_id();
  $pedigree{'name'} = $bcs_stock->name();
  $pedigree{'female_parent'} = undef;
  $pedigree{'male_parent'} = undef;
  $pedigree{'link'} = "/stock/$pedigree{'id'}/view";
  #get cvterms for parent relationships
  my $cvterm_female_parent = $self->schema->resultset("Cv::Cvterm")->create_with(
										 { name   => 'female_parent',
										   cv     => 'stock relationship',
										   db     => 'null',
										   dbxref => 'female_parent',
										 });
  my $cvterm_male_parent = $self->schema->resultset("Cv::Cvterm")->create_with(
									       { name   => 'male_parent',
										 cv     => 'stock relationship',
										 db     => 'null',
										 dbxref => 'male_parent',
									       });
  #get the stock relationships for the stock, find stock relationships for types "female_parent" and "male_parent", and get the corresponding subject stock IDs and stocks.
  my $stock_relationships = $bcs_stock->search_related("stock_relationship_objects",undef,{ prefetch => ['type','subject'] });
  my $female_parent_relationship = $stock_relationships->find({type_id => $cvterm_female_parent->cvterm_id()});
  if ($female_parent_relationship) {
    my $female_parent_stock_id = $female_parent_relationship->subject_id();
    if ($female_parent_stock_id) {
      my $female_parent_stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $female_parent_stock_id});
      if ($female_parent_stock) {
	$pedigree{'female_parent'} = _get_pedigree($self,$female_parent_stock);
      }
    }
  }
  my $male_parent_relationship = $stock_relationships->find({type_id => $cvterm_male_parent->cvterm_id()});
  if ($male_parent_relationship) {
    my $male_parent_stock_id = $male_parent_relationship->subject_id();
    if ($male_parent_stock_id) {
      my $male_parent_stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $male_parent_stock_id});
      if ($male_parent_stock) {
	$pedigree{'male_parent'} = _get_pedigree($self,$male_parent_stock);
      }
    }
  }
  return \%pedigree;
}

sub _get_descendants {
  my ($self,$bcs_stock) = @_;
  my %descendants;
  my %progeny;
  $descendants{'id'} = $bcs_stock->stock_id();
  $descendants{'name'} = $bcs_stock->name();
  $descendants{'link'} = "/stock/$descendants{'id'}/view";
  #get cvterms for parent relationships
  my $cvterm_female_parent = $self->schema->resultset("Cv::Cvterm")->create_with(
										 { name   => 'female_parent',
										   cv     => 'stock relationship',
										   db     => 'null',
										   dbxref => 'female_parent',
										 });
  my $cvterm_male_parent = $self->schema->resultset("Cv::Cvterm")->create_with(
									       { name   => 'male_parent',
										 cv     => 'stock relationship',
										 db     => 'null',
										 dbxref => 'male_parent',
									       });
  #get the stock relationships for the stock, find stock relationships for types "female_parent" and "male_parent", and get the corresponding subject stock IDs and stocks.
  my $descendant_relationships = $bcs_stock->search_related("stock_relationship_subjects",undef,{ prefetch => ['type','object'] });
  if ($descendant_relationships) {
    while (my $descendant_relationship = $descendant_relationships->next) {
      my $descendant_stock_id = $descendant_relationship->object_id();
      if ($descendant_stock_id && (($descendant_relationship->type_id() == $cvterm_female_parent->cvterm_id()) || ($descendant_relationship->type_id() == $cvterm_male_parent->cvterm_id()))) {
  	my $descendant_stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $descendant_stock_id});
  	if ($descendant_stock) {
  	  $progeny{$descendant_stock_id} = _get_descendants($self,$descendant_stock);
  	}
      }
    }
    $descendants{'descendants'} = \%progeny;
    return \%descendants;
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
  if ($pedigree{'female_parent'}) {
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
  if ($pedigree{'male_parent'}) {
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
