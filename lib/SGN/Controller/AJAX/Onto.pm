
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


=head2 match

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub match    : Local : ActionClass('REST') { }

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
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my ($db_name, $accession) = split ":", $c->request->param('node');

    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
    
    my $cvterm = $dbxref->find_related('cvterm');

    my $cvrel_rs = $cvterm->children(); # returns a result set

    my @response_list = ();
    while (my $cvrel_row = $cvrel_rs->next()) { 
	my $relationship_node = $cvrel_row->type();
	my $child_node = $cvrel_row->subject();

	#only report back children of the same cv namespace
	if ($child_node->cv_id() != $cvterm->cv_id()) {  
	    next();
	}

	my $responsehash = $self->flatten_node($child_node, $relationship_node);
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

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    my ($db_name, $accession) = split ":", $c->request->param('node');
    
    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
    
    my $cvterm = $dbxref->find_related('cvterm');
    
    my $parents_rs = $cvterm->recursive_parents(); # returns a result set

    my @response_list = ();

    while (my $parent = $parents_rs->next()) { 
	#only report back children of the same cv namespace
	if ($parent->cv_id() != $cvterm->cv_id()) {  
	    next();
	}

	my $responsehash = $self->flatten_node($parent, undef);
	push @response_list, $responsehash;
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
    ###my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc()->dbh(), $c->request->param('node') );
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    my ($db_name, $accession) = split ":", $c->request->param('node');
    
    #print STDERR "TERM: $db_name:$accession\n";

    my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });
    
    my $cvterm = $dbxref->find_related('cvterm');

    my $parents_rs = $cvterm->recursive_parents(); # returns a result set

    while (my $p = $parents_rs->next()) { 
	my $children_rs = $p->children();
	while (my $rel_rs = $children_rs->next()) { # returns a list of cvterm rows
	    my $child = $rel_rs->subject();
	    $self->add_cache_list($p, $child, $rel_rs->type());
	}
	    
   }
    $c->{stash}->{rest} = $self->{cache_list};    
}


=head2 add_cache_list

 Usage:
 Desc:         adds an entry to the cache list
 Ret:
 Args:         3 cvterm row objects: Parent, child, relationship
 Side Effects:
 Example:

=cut

sub add_cache_list :Private { 
    my $self = shift;
    my $parent = shift; # object
    my $child  = shift; # object
    my $relationship = shift; #object

     my $unique_hashkey = $parent->cvterm_id()." ".$child->cvterm_id();
     if (exists($self->{duplicates}->{$unique_hashkey})) { 
 	return;
     }
    
     $self->{duplicates}->{$unique_hashkey}++;

    my $hashref = $self->flatten_node($child, $relationship);
    ###$hashref->{parent} = $parent->get_full_accession();

    my $dbxref = $parent->dbxref();
    my $parent_accession = $dbxref->db()->name().":".$dbxref->accession();
    $hashref->{parent} = $parent_accession;
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
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    my $namespaces = $c->request->param('nodes');
    my @namespaces = ();

    my @response_nodes = ();
    #my $empty_cvterm   = CXGN::Chado::Cvterm->new($c->dbc()->dbh());
    if (!$namespaces) { 
	@namespaces = ( 
	    'biological_process',
	    'cellular_component',
	    'molecular_function',
	    'plant growth and development stages',
	    'plant structure',
	    'Solanaceae phenotype ontology',
	    'Sequence_Ontology',
	    'quality',
	    );
              
    }
    else { 
	@namespaces = split /\%09/, $namespaces; #split on tab?
    }
    my @roots = ();
    foreach my $ns (@namespaces) {
        my $root = $schema->resultset('Cv::Cvterm')->find( { name=> $ns });
	print STDERR "ROOT $root ".$root->name()."\n";
	push @roots, $root;
    }
    
    my @response_list = ();

    foreach my $r (@roots) { 
	my $hashref = $self->flatten_node($r, undef);
	push @response_list, $hashref;
    }
    $c->{stash}->{rest}= \@response_list;
}


sub match_GET { 
    my ($self, $c) = @_;
    $self->match_POST($c);
}

sub match_POST {
    my $self = shift;
    my $c    = shift;
    my $db_name = $c->request->param("db_name");
    my $term_name = $c->request->param("term_name");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $query = "SELECT distinct cvterm.cvterm_id as cvterm_id  , cv.name as cv_name , cvterm.name as cvterm_name , db.name || ':' || dbxref.accession as accession
                FROM db
               JOIN dbxref USING (db_id ) JOIN cvterm USING (dbxref_id)
               JOIN cv USING (cv_id ) JOIN cvtermsynonym USING (cvterm_id )
               WHERE db.name = ? AND (cvterm.name ilike ? OR cvtermsynonym.synonym ilike ? OR cvterm.definition ilike ?)
GROUP BY cvterm.cvterm_id,cv.name, cvterm.name, dbxref.accession, db.name ";
    my $sth= $schema->storage->dbh->prepare($query);
    $sth->execute($db_name, "\%$term_name\%", "\%$term_name\%", "\%$term_name\%");
    my @response_list;
    while  (my $hashref = $sth->fetchrow_hashref ) {
        push @response_list, $hashref;
    }
    $c->{stash}->{rest} = \@response_list;
}



=head2 nodes2list
 DEPRECATED. REPLACED by FLATTEN_NODE()
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


### used for cvterm resultset
sub flatten_node { 
    my $self = shift;
    my $node_row = shift;
    my $rel_row = shift;
    
    my $has_children = 0;
    if ($node_row->children()->first()) { 
	$has_children = 1;
    }
    
    my $rel_name = "";
    if ($rel_row) { 
	$rel_name = $rel_row->name();
    }

    my $dbxref = $node_row->dbxref();

    my $hashref = 
    { accession    => $dbxref->db->name().":".$dbxref->accession,
      cvterm_name  => $node_row->name(),
      cvterm_id    => $node_row->cvterm_id(),
      has_children => $has_children,
      relationship => $rel_name,
    };
}


#sub end :ActionClass('Serialize') {}


1;
