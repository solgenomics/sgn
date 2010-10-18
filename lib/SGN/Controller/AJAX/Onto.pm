
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


sub children : Local : ActionClass('REST') { }
sub parents  : Local : ActionClass('REST') { }
sub roots    : Local : ActionClass('REST') { }
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
    
    my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc()->dbh(), $c->request->param('node') );
    
    my @parent_nodes = $cvterm->get_recursive_parents();
    foreach my $p (@parent_nodes) { 
	$self->{parent_nodes}->{$p->[0]->get_full_accession()}=$p;
    }
    my @roots = CXGN::Chado::Cvterm::get_roots($c->dbc()->dbh(), $cvterm->get_db_name());

    $self->recursive_cache($c, @roots);

    $c->{stash}->{rest} = $self->{cache_list};
    
}

sub recursive_cache :Private  {
    my $self = shift;
    my $c = shift;
    my @nodes = @_;
    foreach my $n (@nodes) { 
	if (exists($self->{parent_nodes}->{$n->get_full_accession()})) { 
	    my @children = $n->get_children();
	    map { $self->add_cache_list($c, $n->get_full_accession(), $_->[0] ); } @children;
	    if (@children) { $self->recursive_cache($c, map { $_->[0] } @children); }
	}
	
    }
}

sub add_cache_list :Private { 
    my $self = shift;
    my $c = shift;
    my $parent = shift;
    my $child  = shift;
    my $empty_cvterm   = CXGN::Chado::Cvterm->new($c->dbc()->dbh());
    my $hashref = $self->nodes2list($child, $empty_cvterm);
    $hashref->{parent} = $parent;
    print STDERR "Adding to cache list: parent=$parent. child=$child\n";
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
      relationship => $node->get_cvterm_name()
    };
    
    return $hashref;
}

#sub end :ActionClass('Serialize') {}


1;
