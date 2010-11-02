
=head1 NAME

SGN::Controller::AJAX::Onto - a REST controller class to provide the backend for the SGN ontology browser

=head1 DESCRIPTION

Essentially provides four services: roots, children, parents, and cache, that the SGN ontology browser relies on. Output is JSON, as a list of hashes, that has the following keys: accession, has_children, cvterm_name, cvterm_id, and for some functions, parent.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS: 

=cut

package SGN::Controller::AJAX::Onto;

use Moose;
use CXGN::Chado::Cvterm;
use CXGN::DB::Connection;

use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }


__PACKAGE__->config( 
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


=head2 children

 Usage:
 Desc:         provides a list of children as hashes in json
 Ret:          a list of hashes, in json, with the following keys:
               accession, cvterm_name, cvterm_id, has_children, relationship
 Args:
 Side Effects:
 Example:

=cut

sub children : Local : ActionClass('REST') { }

=head2 parents

 Usage:
 Desc:         returns a list of hashes with parents information in json
 Ret:          a list of hashes, with the keys:
               accession, relationship, has_children, cvterm_id and cvterm_name.
 Args:
 Side Effects:
 Example:

=cut

sub parents  : Local : ActionClass('REST') { }


=head2 roots

 Usage: 
 Desc:         provides the default roots for drawing the ontology browser
 Ret:          
 Args:         optional: a string with namespace definitions, separated by white
               space (for example, "PO SP SO"). This overrides the standard 
               namespaces provided when called without arguments.
 Side Effects:
 Example:

=cut

sub roots    : Local : ActionClass('REST') { }


=head2 cache

 Usage:        Dispatched by catalyst
 Desc:         provides a list of parents and their direct children in a 
               denormalized list. The parameter node is used to determine all 
               the children that need to be cached for the parentage view to 
               render fast (without having to call the children ajax function). 
 Ret:          JSON data structure
 Args:
 Side Effects:
 Example:

=cut

sub cache    : Local : ActionClass('REST') { }



sub children_GET { 
    my ($self, $c) = @_;
    $self->children_POST($c);
}
 
sub children_POST {
    my ( $self, $c ) = @_;

    my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc->dbh(), $c->request->param('node') );

    my @response_nodes = $cvterm->get_children();
    my @response_list = ();
    foreach my $e (@response_nodes) { 
	my $responsehash = $self->nodes2list($e->[0], $e->[1]);
	push @response_list, $responsehash;
    }
    $c->{stash}->{rest} = \@response_list;
}

sub parents_GET { 
    my $self = shift;
    $self->parents_POST(@_);
}

    
sub parents_POST { 
    my ($self, $c) = @_;
    my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc()->dbh(), $c->request->param('node') );
    
    my @response_nodes = $cvterm->get_recursive_parents();
    my @response_list = ();
    foreach my $e (@response_nodes) { 
	print STDERR "processing parent: ".$e->[0]->get_full_accession()."\n";
	my $response_hash = $self->nodes2list($e->[0], $e->[1]);
	push @response_list, $response_hash;
    }
    
    $c->{stash}->{rest} = \@response_list;
}

sub cache_GET { 
    my $self = shift;
    $self->cache_POST(@_);
}



sub cache_POST { 
    my $self =shift;
    my $c = shift;

    $self->{duplicates} = {};
    $self->{cache_list} = [];
    my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc()->dbh(), $c->request->param('node') );
    
    my @parent_nodes = $cvterm->get_recursive_parents();
    foreach my $p (@parent_nodes) { 
	#$self->{parent_nodes}->{$p->[0]->get_full_accession()}=$p;
	foreach my $child ($p->[0]->get_children()) { 
	    $self->add_cache_list($p->[0],  $child->[0], $child->[1] );
	    
	}
    }
    $c->{stash}->{rest} = $self->{cache_list};    
}

# sub recursive_cache :Private  {
#     my $self = shift;
#     my $c = shift;
#     my @nodes = @_;
#     foreach my $n (@nodes) { 
# 	#if (exists($self->{parent_nodes}->{$n->get_full_accession()})) { 
# 	my @children = $n->get_children();
# 	map { $self->add_cache_list($c, $n->get_full_accession(), $_->[0], $_->[1] ); } @children;
# 	if (@children) { $self->recursive_cache($c, map { $_->[0] } @children); }
#     }
    
# }


=head2 add_cache_list

 Usage:
 Desc:         adds an entry to the cache list
 Ret:
 Args:         3 CXGN::Chado::Cvterm objects: Parent, child, relationship
 Side Effects:
 Example:

=cut

sub add_cache_list :Private { 
    my $self = shift;
    my $parent = shift; # object
    my $child  = shift; # object
    my $relationship = shift; #object

    my $unique_hashkey = $parent." ".$child;
    if (exists($self->{duplicates}->{$unique_hashkey})) { 
	return;
    }
    
    $self->{duplicates}->{$unique_hashkey}++;

    my $hashref = $self->nodes2list($child, $relationship);
    $hashref->{parent} = $parent->get_full_accession();
    ##print STDERR "Adding to cache list: parent=$parent. child=$child\n";
    push @{$self->{cache_list}}, $hashref;
    
}

sub roots_GET { 
    my $self = shift;
    $self->roots_POST(@_);
}

sub roots_POST { 
    my $self = shift;
    my $c = shift;
    
    my $namespaces = $c->request->param('nodes');
    my @namespaces = ();

    my @response_nodes = ();
    my $empty_cvterm   = CXGN::Chado::Cvterm->new($c->dbc()->dbh());
    if (!$namespaces) { 
	@namespaces = ( 'GO', 'PO', 'SP', 'SO', 'PATO' );
    }
    else { 
	@namespaces = split /\s+/, $namespaces;
    }
    my @roots = ();
    foreach (@namespaces) {
        push @roots, CXGN::Chado::Cvterm::get_roots( $c->dbc->dbh(), $_ );
    }
    foreach (@roots) { push @response_nodes, [ $_, $empty_cvterm ] }

    my @response_list = ();

    foreach my $e (@response_nodes) { 
	my $hashref = $self->nodes2list($e->[0], $e->[1]);
	push @response_list, $hashref;
    }
    $c->{stash}->{rest}= \@response_list;
}
 
=head2 nodes2list

 Usage:
 Desc:         serializes CXGN::Chado::Cvterm objects to a list form convenient
               for processing to json.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub nodes2list :Private { 
    my $self = shift;
    my $node = shift;
    my $relationship_node = shift;

    #print STDERR "Dealing with ".$n->[0]->get_accession()."\n";
    my $has_children = 0;
    if ( $node->count_children() > 0 ) { $has_children = 1; }
    my $hashref = 
    { accession    => $node->get_full_accession(), 
      cvterm_name  => $node->get_cvterm_name(),
      cvterm_id    => $node->get_cvterm_id(),
      has_children => $has_children,
      relationship => $relationship_node->get_cvterm_name()
    };
    
    return $hashref;
}

#sub end :ActionClass('Serialize') {}


1;
