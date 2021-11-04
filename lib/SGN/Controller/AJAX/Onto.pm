=head1 NAME

SGN::Controller::AJAX::Onto - a REST controller class to provide the
backend for the SGN ontology browser

=head1 DESCRIPTION

Essentially provides four services: roots, children, parents, and
cache, that the SGN ontology browser relies on. Output is JSON, as a
list of hashes, that has the following keys: accession, has_children,
cvterm_name, cvterm_id, and for some functions, parent.

The ontologies that should be displayed must be configured in the configuration file (sgn.conf or sgn_local.conf for SGN). Insert a line of the following format into the conf file:

C<onto_root_namespaces  GO (Gene Ontology), PO (Plant Ontology), SO (Sequence Ontology), PATO (Phenotype and Trait Ontology), SP (Solanaceae Ontology)>

where onto_root_namespaces is the conf key, "GO" the two letter code of the ontology (as it appears in the db database table), and in parenthesis is the human readable name of the ontology.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 PUBLIC ACTIONS

=cut

package SGN::Controller::AJAX::Onto;

use Moose;
use SGN::Model::Cvterm;
use CXGN::Chado::Cvterm;
use CXGN::Onto;
use Data::Dumper;
use JSON;

use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

=head2 compose_trait

Creates a new term in the designated composed trait cv and links it to component terms through cvterm_relationship

=cut

sub compose_trait: Path('/ajax/onto/store_composed_term') Args(0) {

  my $self = shift;
  my $c = shift;

  #my @ids = $c->req->param("ids[]");
  #print STDERR "Ids array for composing in AJAX Onto = @ids\n";

  my $new_trait_names = decode_json $c->req->param("new_trait_names");
  #print STDERR Dumper $new_trait_names;
  my $new_terms;
  eval {
      my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
      $new_terms = $onto->store_composed_term($new_trait_names);
  };
  if ($@) {
      $c->stash->{rest} = { error => "An error occurred saving the new trait details: $@" };
  }
  else {
      my $message = '';
      my @names;
      foreach (@$new_terms){
          $message .= 'Saved new trait <a href="/cvterm/'.$_->[0].'/view">'.$_->[1].'</a><br>';
          push @names, $_->[1];
      }
      $c->stash->{rest} = { success => $message,
                            names => \@names };
  }

}

=head2 store_ontology_identifier

Creates a ontology identifier by adding an entry in the DB, cv, and cvterm tables.

=cut

sub store_ontology_identifier: Path('/ajax/onto/store_ontology_identifier') Args(0) {
    my $self = shift;
    my $c = shift;
    #print STDERR Dumper $c->req->params();

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to create ontology!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to create ontology!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to add ontology." };
        $c->detach();
    }

    my $ontology_name = $c->req->param("ontology_name");
    my $ontology_description = $c->req->param("ontology_description");
    my $ontology_identifier = $c->req->param("ontology_identifier");
    my $ontology_type = $c->req->param("ontology_type");

    my %finish;
    if ($c->config->{allow_observation_variable_submission_interface}) {
        my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
        my $return = $onto->store_ontology_identifier(
            $ontology_name,
            $ontology_description,
            $ontology_identifier,
            $ontology_type
        );
        if ($return->{error}) {
            $finish{error} = $return->{error};
        } elsif ($return->{success}) {
            $finish{success} = 'Saved new ontology <a href="/cvterm/'.$return->{new_term}->[0].'/view">'.$return->{new_term}->[1].'</a><br>';
        } else {
            $finish{error} = 'Something went wrong!';
        }
    } else {
        $finish{error} = 'On this database it is not allowed for users to add their own ontology! Please contact us!';
    }
    $c->stash->{rest} = \%finish;
}

=head2 store_trait_method_scale_observation_variable

Creates a new term in the designated observation variable cv and links it to component trait, method, and scale terms through cvterm_relationship. will create trait, method, and scale terms in their own ontologies if they need to be.

=cut

sub store_trait_method_scale_observation_variable: Path('/ajax/onto/store_trait_method_scale_observation_variable') Args(0) {
    my $self = shift;
    my $c = shift;
    #print STDERR Dumper $c->req->params();

    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to create observation variables!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to create observation variables!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to add observation variables." };
        $c->detach();
    }

    my $selected_observation_variable_db_id = $c->req->param("selected_observation_variable_db_id");
    my $new_observation_variable_name = $c->req->param("new_observation_variable_name");
    my $new_observation_variable_definition = $c->req->param("new_observation_variable_definition");
    my $selected_trait_db_id = $c->req->param("selected_trait_db_id");
    my $selected_trait_cvterm_id = $c->req->param("selected_trait_cvterm_id");
    my $new_trait_name = $c->req->param("new_trait_name");
    my $new_trait_definition = $c->req->param("new_trait_definition");
    my $selected_method_db_id = $c->req->param("selected_method_db_id");
    my $selected_method_cvterm_id = $c->req->param("selected_method_cvterm_id");
    my $new_method_name = $c->req->param("new_method_name");
    my $new_method_definition = $c->req->param("new_method_definition");
    my $selected_scale_db_id = $c->req->param("selected_scale_db_id");
    my $selected_scale_cvterm_id = $c->req->param("selected_scale_cvterm_id");
    my $new_scale_name = $c->req->param("new_scale_name");
    my $new_scale_definition = $c->req->param("new_scale_definition");
    my $new_scale_format = $c->req->param("new_scale_format");
    my $new_scale_minumum = $c->req->param("new_scale_minimum");
    my $new_scale_maximum = $c->req->param("new_scale_maximum");
    my $new_scale_default = $c->req->param("new_scale_default");
    my $new_scale_categories = $c->req->param("new_scale_categories");

    my %finish;
    if ($c->config->{allow_observation_variable_submission_interface}) {
        my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
        my $return = $onto->store_observation_variable_trait_method_scale(
            $selected_observation_variable_db_id,
            $new_observation_variable_name,
            $new_observation_variable_definition,
            $selected_trait_db_id,
            $selected_trait_cvterm_id,
            $new_trait_name,
            $new_trait_definition,
            $selected_method_db_id,
            $selected_method_cvterm_id,
            $new_method_name,
            $new_method_definition,
            $selected_scale_db_id,
            $selected_scale_cvterm_id,
            $new_scale_name,
            $new_scale_definition,
            $new_scale_format,
            $new_scale_minumum,
            $new_scale_maximum,
            $new_scale_default,
            $new_scale_categories
        );
        if ($return->{error}) {
            $finish{error} = $return->{error};
        } elsif ($return->{success}) {
            $finish{success} = 'Saved new observation variable <a href="/cvterm/'.$return->{new_term}->[0].'/view">'.$return->{new_term}->[1].'</a><br>';
        } else {
            $finish{error} = 'Something went wrong!';
        }
    } else {
        $finish{error} = 'On this database it is not allowed for users to add their own observation variables! Please contact us!';
    }
    $c->stash->{rest} = \%finish;
}

=head2 get_trait_from_exact_components

searches for and returns (if found) a composed trait that contains the exact components supplied

=cut

sub get_trait_from_exact_components: Path('/ajax/onto/get_trait_from_exact_components') Args(0) {

  my $self = shift;
  my $c = shift;
  my @component_ids = $c->req->param("ids[]");
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

  my $trait_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@component_ids);
  if (!$trait_id) {
    $c->stash->{rest} = { error => "No exact matches found."};
  }
  else {
    $c->stash->{rest} = { trait_id => $trait_id };
  }
}

=head2 get_trait_from_component_categories

searches for and returns traits that contain one of the ids from each id category supplied

=cut

sub get_traits_from_component_categories: Path('/ajax/onto/get_traits_from_component_categories') Args(0) {

  my $self = shift;
  my $c = shift;
  my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
  my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
  my $composable_cvterm_format = $c->config->{composable_cvterm_format};
  my @object_ids = $c->req->param("object_ids[]");
  my @attribute_ids = $c->req->param("attribute_ids[]");
  my @method_ids = $c->req->param("method_ids[]");
  my @unit_ids = $c->req->param("unit_ids[]");
  my @trait_ids = $c->req->param("trait_ids[]");
  my @tod_ids = $c->req->param("tod_ids[]");
  my @toy_ids = $c->req->param("toy_ids[]");
  my @gen_ids = $c->req->param("gen_ids[]");
  my @evt_ids = $c->req->param("evt_ids[]");

  print STDERR "Obj ids are @object_ids\n Attr ids are @attribute_ids\n Method ids are @method_ids\n unit ids are @unit_ids\n trait ids are @trait_ids\n tod ids are @tod_ids\n toy ids are @toy_ids\n gen ids are @gen_ids\n evt ids are @evt_ids\n";
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

  my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
      object => \@object_ids,
      attribute => \@attribute_ids,
      method => \@method_ids,
      unit => \@unit_ids,
      trait => \@trait_ids,
      tod => \@tod_ids,
      toy => \@toy_ids,
      gen => \@gen_ids,
      evt => \@evt_ids,
  });

  if (!$traits) {
    $c->stash->{rest} = { error => "No matches found."};
  }
  else {
    $c->stash->{rest} = {
      existing_traits => $traits->{existing_traits},
      new_traits => $traits->{new_traits}
    };
  }
}


=head2 children

Public Path: /<ns>/children

L<Catalyst::Action::REST> action.

Provides a list of child terms, each child term being a hashref (or
equivalent) with keys accession, cvterm_name, cvterm_id, has_children,
and relationship.

=cut

sub children : Local : ActionClass('REST') { }

sub children_GET {
    my ( $self, $c ) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my ($db_name, $accession) = split ":", $c->request->param('node');

    my $db = $schema->resultset('General::Db')->search({ name => uc($db_name) })->first();
    my $dbxref = $db->find_related('dbxrefs', { accession => $accession });

    my $cvterm = $dbxref->cvterm;

    my $cvrel_rs = $cvterm->children(); # returns a result set

    my @response_list = ();
    while (my $cvrel_row = $cvrel_rs->next()) {
        my $relationship_node = $cvrel_row->type();
        my $child_node = $cvrel_row->subject();

        #only report back children of the same cv namespace
      #  if ($child_node->cv_id() != $cvterm->cv_id()) {
      #      next();
      #  }

        my $responsehash = $self->flatten_node($child_node, $relationship_node);
        push @response_list, $responsehash;
    }
    @response_list = sort { lc $a->{cvterm_name} cmp lc $b->{cvterm_name} } @response_list;
    $c->stash->{rest} = \@response_list;
}


=head2 parents

Public Path: /<ns>/parents

L<Catalyst::Action::REST> action.

Returns a list of hashes with parents information in json, a list of
hashrefs with the keys: accession, relationship, has_children, cvterm_id
and cvterm_name.

=cut

sub parents  : Local : ActionClass('REST') { }

sub parents_GET  {
    my ($self, $c) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my ($db_name, $accession) = split ":", $c->request->param('node');
    my $dbxref;
    my %response;
    my $db = $schema->resultset('General::Db')->search(
	{ 'upper(me.name)'   => uc($db_name), 
	  'cvterm.name'      => {'!=', undef },
	  'dbxrefs.accession' => $accession
	},
	{join   =>  { 'dbxrefs'  => 'cvterm' }
	}
	);
    my $db_id;
    if (!$db || !$accession) {
	#not sure we need here to send an error key, since cache is usually called after parents (? )
	$response{error} = "Did not pass a legal ontology term ID! ( $db_name : $accession)";
	$c->stash->{rest} = \%response;
	return;
    } elsif ( $db->count > 1 ) {
	$response{error} = "Found more than one db row for  db.name $db_name : check your database";
	$c->stash->{rest} = \%response;
	return;
    }
    $db_id=$db->next->db_id;
    my $sql = 'IS NOT NULL ';
    my $dbxref_rs = $schema->resultset('General::Dbxref')->search(
	{ 'me.accession' => $accession,
	  'db_id'       => $db_id,
	  'cvterm.cvterm_id' => \$sql 
  
	},
	{ join =>  'cvterm'    },
	);

    if ($dbxref_rs->count >1 ) {
	while (my $d = $dbxref_rs->next() ) { print STDERR "DBXREF = " . $d->dbxref_id . " CVTERM = " . $d->cvterm->cvterm_id . "NAME = " . $d->cvterm->name . " \n\n" ; }  
	$response{error} = "Found more than one dbxref row for  accession  $accession : check your database";
	$c->stash->{rest} = \%response;
	return;
    } else {
	$dbxref = $dbxref_rs->next();
    }
    #print STDERR "***Onto.pm:   My db_name  = $db_name , accession = $accession, db = " . $db_name . "db id = " . $db_id . " cvterm = " . $dbxref->cvterm->cvterm_id . "\n\n";
    if (!$dbxref) {
        $response{error} = "Could not find term $db_name : $accession in the database! Check your input and try again";
        $c->stash->{rest} = \%response;
        return;
    }
    my $cvterm = $dbxref->cvterm;

    my @response_list = ();
    if ($cvterm) {
        my $parents_rs = $cvterm->recursive_parents(); # returns a result set
        while (my $parent = $parents_rs->next()) {
            #only report back children of the same cv namespace
            if ($parent->cv_id() != $cvterm->cv_id()) {
                next();
            }
            my $responsehash = $self->flatten_node($parent, undef);
            push @response_list, $responsehash;
        }
    } else {
        $response{error} = "Could not find term $db_name : $accession in the database! Check your input and try again. THIS MAY BE AN INTERNAL DATABASE PROBLEM! Please contact sgn-feedback\@sgn.cornell.edu for help.";
        $c->stash->{rest} = \%response;
        return;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 menu

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub menu  : Local : ActionClass('REST') { }

sub menu_GET  {
    my $self = shift;
    my $c = shift;

    my $menudata = $c->config->{onto_root_namespaces};

    print STDERR "MENUDATA: $menudata\n";
    my @menuitems = split ",", $menudata;

    my $menu = '<select name="cv_select">';

    foreach my $mi (@menuitems) {
	print STDERR "MENU ITEM: $mi\n";
	if ($mi =~ /\s*(\w+)?\s*(.*)$/) {
	    my $value = $1;
	    my $name = $2;

	    $menu .= qq { <option value="$value">$value $name</option>\n };
	}
    }

    $menu .= "</select>\n";
    $c->stash->{rest} = [ $menu ];

}




=head2 roots

Public Path: /<ns>/roots

L<Catalyst::Action::REST> action.

Provides the default roots for drawing the ontology browser

Query/Body Params:

  nodes: optional, a string with namespace definitions, separated by white
         space (for example, "PO SP SO"). If not provided, will This overrides the standard
         namespaces provided when called without arguments.

=cut

sub roots    : Local : ActionClass('REST') { }

sub roots_GET {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $namespace = $c->request->param('nodes');
    my @namespaces = ();
    my @response_nodes = ();
    #my $empty_cvterm   = CXGN::Chado::Cvterm->new($c->dbc()->dbh());
    if (!$namespace) { # should namespaces be db names ? (SO, GO,PO, SP, PATO)
        @namespaces = (
            'GO',
            'PO',
            'SP',
            'SO',
            'PATO',
	    'CO',
            );
    }
    else {
        @namespaces = split /\s+/, $namespace; #split on whitespace
    }
    my @roots = ();
    my $is_rel = 0;
    foreach my $ns (@namespaces) {
        $is_rel = 1 if $ns eq 'OBO_REL';
        my $q = "SELECT cvterm.cvterm_id FROM cvterm
                 JOIN dbxref USING(dbxref_id) JOIN db USING(db_id)
                 LEFT JOIN cvterm_relationship ON (cvterm.cvterm_id=cvterm_relationship.subject_id)
                 WHERE cvterm_relationship.subject_id IS NULL AND is_obsolete= ? AND is_relationshiptype = ? AND db.name= ? ";
        my $sth = $schema->storage->dbh->prepare($q);
        $sth->execute(0,$is_rel,$ns);
        while (my ($cvterm_id) = $sth->fetchrow_array() ) {
            my $root = $schema->resultset("Cv::Cvterm")->find( { cvterm_id => $cvterm_id } );
            push @roots, $root;
        }
    }
    my @response_list = ();

    foreach my $r (@roots) {
        my $hashref = $self->flatten_node($r, undef);
        push @response_list, $hashref;
    }
    $c->stash->{rest}= \@response_list;
}


=head2 match

Public Path: /<ns>/match

L<Catalyst::Action::REST> action.

Query/Body Params:

  db_name
  term_name

=cut

sub match    : Local : ActionClass('REST') { }

sub match_GET {
    my $self = shift;
    my $c    = shift;
    my $db_name = $c->request->param("db_name");
    my $term_name = $c->request->param("term_name");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $query = "SELECT distinct cvterm.cvterm_id as cvterm_id  , cv.name as cv_name , cvterm.name as cvterm_name , db.name || ':' || dbxref.accession as accession
                FROM db
               JOIN dbxref USING (db_id ) JOIN cvterm USING (dbxref_id)
               JOIN cv USING (cv_id )
               LEFT JOIN cvtermsynonym USING (cvterm_id )
               WHERE db.name = ? AND (cvterm.name ilike ? OR cvtermsynonym.synonym ilike ? OR cvterm.definition ilike ?) AND cvterm.is_obsolete = 0
GROUP BY cvterm.cvterm_id,cv.name, cvterm.name, dbxref.accession, db.name ";
    my $sth= $schema->storage->dbh->prepare($query);
    $sth->execute($db_name, "\%$term_name\%", "\%$term_name\%", "\%$term_name\%");
    my @response_list;
    while  (my $hashref = $sth->fetchrow_hashref ) {
        push @response_list, $hashref;
    }
    $c->stash->{rest} = \@response_list;
}

=head2 cache

Public Path: /<ns>/cache

L<Catalyst::Action::REST> action.

Provides a list of parents and their direct children in a denormalized
list. The parameter node is used to determine all the children that
need to be cached for the parentage view to render fast (without
having to call the children ajax function).

=cut

sub cache    : Local : ActionClass('REST') { }

sub cache_GET {
    my $self =shift;
    my $c = shift;

    $self->{duplicates} = {};
    $self->{cache_list} = [];

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my %response;
    my ($db_name, $accession) = split ":", $c->request->param('node');
    if (!$db_name || !$accession) {
        $response{error} = "Looks like you passed an illegal ontology term ID ! ($db_name : $accession) Please try again.";
        $c->stash->{rest} = \%response;
        return;
    }
    
###############
    my $db = $schema->resultset('General::Db')->search(
	{ 'upper(me.name)'   => uc($db_name),
	  'cvterm.name'      => {'!=', undef },
	  'dbxrefs.accession' => $accession
	},
	{join   =>  { 'dbxrefs'  => 'cvterm' }
	}
	);
    my ($db_id, $dbxref);
    $db_id=$db->next->db_id;
    my $sql = 'IS NOT NULL ';
    my $dbxref_rs = $schema->resultset('General::Dbxref')->search(
	{ 'me.accession' => $accession,
	  'db_id'       => $db_id,
	  'cvterm.cvterm_id' => \$sql

	},
	{ join =>  'cvterm'    },
	);

    if ($dbxref_rs->count >1 ) {
	while (my $d = $dbxref_rs->next() ) { print STDERR "DBXREF = " . $d->dbxref_id . " CVTERM = " . $d->cvterm->cvterm_id . "NAME = " . $d->cvterm->name . " \n\n" ; }
	$response{error} = "Found more than one dbxref row for  accession  $accession : check your database";
	$c->stash->{rest} = \%response;
	return;
    } else {
	$dbxref = $dbxref_rs->next();
    }
    if (!$dbxref) {
	$response{error} = "Did not find ontology term $db_name : $accession in the database. Please try again. If you think this term should exist please contact sgn-feedback\@sgn.cornell.edu";
	$c->stash->{rest} = \%response;
	return;
    }
    ######################
    my $cvterm = $dbxref->cvterm;
    if (!$cvterm) {
        $response{error} = "Did not find ontology term $db_name : $accession in the database. This may be an internal database issue. Please contact sgn-feedback\@sgn.cornell.edu and we will fix this error ASAP";
        $c->stash->{rest} = \%response;
        return;
    }
    my $parents_rs = $cvterm->recursive_parents(); # returns a result set
    if (!$parents_rs->next) {
        $response{error} = "did not find recursive parents for cvterm " . $cvterm->name;
        $c->stash->{rest} = \%response;
        return;
    }

#    $self->add_cache_list(undef, $cvterm, $cvterm->type());
    while (my $p = $parents_rs->next()) {
        my $children_rs = $p->children();
        while (my $rel_rs = $children_rs->next()) { # returns a list of cvterm rows
            my $child = $rel_rs->subject();
            $self->add_cache_list($p, $child, $rel_rs->type());
        }
    }
    $c->stash->{rest} = $self->{cache_list};
}


=head1 PRIVATE ACTIONS

=head2 add_cache_list

Private action.

Adds an entry to the cache list.

Argsuments: 3 cvterm row objects: Parent, child, relationship

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

1;
