
=head1 NAME

SGN::Controller::AJAX::Cvterm - a REST controller class to provide the
backend for objects linked with cvterms

=head1 DESCRIPTION

Browse the cvterm database for selecting cvterms (ontology terms, and their evidece codes) to be linked with other objects

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::Cvterm;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Page::FormattingHelpers qw/ columnar_table_html commify_number /;
use CXGN::Chado::Cvterm;
use Data::Dumper;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


=head2 autocomplete

Public Path: /ajax/cvterm/autocomplete

Autocomplete a cvterm name.  Takes a single GET param,
C<term>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(0) {
    my ( $self, $c ) = @_;

    #my $term = $c->req->param('term_name');
    my $db_name = $c->request->param('db_name');
    # trim and regularize whitespace
    #$term =~ s/(^\s+|\s+)$//g;
    #$term =~ s/\s+/ /g;
    my $term_name = $c->request->param("term");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $query = "SELECT distinct cvterm.cvterm_id as cvterm_id  , cv.name as cv_name , cvterm.name as cvterm_name , db.name || ':' || dbxref.accession as accession
                FROM db
               JOIN dbxref USING (db_id ) JOIN cvterm USING (dbxref_id)
               JOIN cv USING (cv_id )
               LEFT JOIN cvtermsynonym USING (cvterm_id )
               WHERE db.name = ? AND (cvterm.name ilike ? OR cvtermsynonym.synonym ilike ? OR cvterm.definition ilike ?) AND cvterm.is_obsolete = 0 AND is_relationshiptype = 0
GROUP BY cvterm.cvterm_id,cv.name, cvterm.name, dbxref.accession, db.name
ORDER BY cv.name, cvterm.name limit 30";
    my $sth= $schema->storage->dbh->prepare($query);
    $sth->execute($db_name, "\%$term_name\%", "\%$term_name\%", "\%$term_name\%");
    my @response_list;
    while (my ($cvterm_id, $cv_name, $cvterm_name, $accession) = $sth->fetchrow_array() ) {
        push @response_list, $cv_name . "--" . $accession . "--" . $cvterm_name ;
    }
    $c->stash->{rest} = \@response_list;
}

sub autocompleteslim : Local : ActionClass('REST') { }

sub autocompleteslim_GET :Args(0) {
    my ( $self, $c ) = @_;

    #my $term = $c->req->param('term_name');
    my $db_name = $c->request->param('db_name');
    $db_name = '%'.$db_name.'%';
    # trim and regularize whitespace
    #$term =~ s/(^\s+|\s+)$//g;
    #$term =~ s/\s+/ /g;
    my $term_name = $c->request->param("term");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $query = "SELECT distinct cvterm.cvterm_id as cvterm_id  , cv.name as cv_name , cvterm.name as cvterm_name , db.name || ':' || dbxref.accession as accession
                FROM db
               JOIN dbxref USING (db_id ) JOIN cvterm USING (dbxref_id)
               JOIN cv USING (cv_id )
               LEFT JOIN cvtermsynonym USING (cvterm_id )
               WHERE db.name ilike ? AND (cvterm.name ilike ? OR cvtermsynonym.synonym ilike ? OR cvterm.definition ilike ?) AND cvterm.is_obsolete = 0 AND is_relationshiptype = 0
GROUP BY cvterm.cvterm_id,cv.name, cvterm.name, dbxref.accession, db.name
ORDER BY cv.name, cvterm.name limit 30";
    my $sth= $schema->storage->dbh->prepare($query);
    $sth->execute($db_name, "\%$term_name\%", "\%$term_name\%", "\%$term_name\%");
    my @response_list;
    while (my ($cvterm_id, $cv_name, $cvterm_name, $accession) = $sth->fetchrow_array() ) {
        push @response_list, $cvterm_name . "|" . $accession ;
    }
    $c->stash->{rest} = \@response_list;
}

sub relationships : Local : ActionClass('REST') { }

sub relationships_GET :Args(0) {
    my ($self, $c) = @_;
    my $relationship_query = $c->dbc->dbh->prepare("SELECT distinct(cvterm.cvterm_id), cvterm.name
                                       FROM public.cvterm
                                       JOIN public.cv USING (cv_id)
                                      JOIN public.cvterm_relationship ON (cvterm.cvterm_id= cvterm_relationship.subject_id)
                                       WHERE cv.name ='relationship' AND
                                       cvterm.is_obsolete = 0
                                       ORDER BY cvterm.name;
                                      ");
    $relationship_query->execute();
    my $hashref={};
    while  ( my ($cvterm_id, $cvterm_name) = $relationship_query->fetchrow_array() ) {
        $hashref->{$cvterm_name} = $cvterm_id;
    }
    $c->stash->{rest} = $hashref;
}

sub locus_relationships : Local : ActionClass('REST') { }

sub locus_relationships_GET :Args(0) {
    my ($self, $c) = @_;
    my $query = $c->dbc->dbh->prepare(
        "SELECT distinct(cvterm.cvterm_id), cvterm.name
        FROM public.cvterm
        JOIN public.cv USING (cv_id)
        WHERE cv.name ='Locus Relationship' AND
        cvterm.is_obsolete = 0
        ORDER BY cvterm.name;
    ");
    $query->execute();
    my $hashref={};
    while  ( my ($cvterm_id, $cvterm_name) = $query->fetchrow_array() ) {
        $hashref->{$cvterm_name} = $cvterm_id;
    }
    $c->stash->{rest} = $hashref;
}

=head2

Public Path: /ajax/cvterm/evidence

get a list of available evidence codes from cvterms
responds with a JSON array .

=cut

sub evidence : Local : ActionClass('REST') { }

sub evidence_GET :Args(0) {
    my ($self, $c) = @_;
    my $query = $c->dbc->dbh->prepare(
        "SELECT distinct(cvterm.cvterm_id), cvterm.name
         FROM public.cvterm_relationship
         JOIN public.cvterm ON (cvterm.cvterm_id= cvterm_relationship.subject_id)
         WHERE object_id= (select cvterm_id FROM cvterm where name = 'evidence_code')
         AND cvterm.is_obsolete = 0
         ORDER BY cvterm.name" );
    $query->execute();
    my $hashref={};
    while  ( my ($cvterm_id, $cvterm_name) = $query->fetchrow_array() ) {
        $hashref->{$cvterm_name} = $cvterm_id;
    }
    $c->stash->{rest} = $hashref;
}


sub evidence_description : Local : ActionClass('REST') { }

sub evidence_description_GET :Args(0) {
    my ($self, $c) = @_;
    my $evidence_code_id = $c->request->param("evidence_code_id");
    my $query = $c->dbc->dbh->prepare("SELECT cvterm_id, cvterm.name FROM cvterm
                                                JOIN cvterm_relationship ON cvterm_id=subject_id
                                                WHERE object_id= (select cvterm_id FROM public.cvterm WHERE cvterm_id= ?)
                                                AND cvterm.is_obsolete = 0"
        );
    $query->execute($evidence_code_id);
    my $hashref={};
    while  ( my ($cvterm_id, $cvterm_name) = $query->fetchrow_array() ) {
        $hashref->{$cvterm_name} = $cvterm_id;
    }
    $c->stash->{rest} = $hashref;
}

sub get_synonyms : Path('/ajax/cvterm/get_synonyms') Args(0) {

  my $self = shift;
  my $c = shift;
  my @trait_ids = $c->req->param('trait_ids[]');
  print STDERR "Trait ids = @trait_ids\n";
  my $dbh = $c->dbc->dbh();
  my $synonyms = {};

  foreach my $trait_id (@trait_ids) {
    my $cvterm = CXGN::Chado::Cvterm->new( $dbh, $trait_id );
    my $found_cvterm_id = $cvterm->get_cvterm_id;
    $synonyms->{$trait_id} = $cvterm->get_uppercase_synonym() || "None";
  }

  $c->stash->{rest} = { synonyms => $synonyms };

}

sub get_annotated_stocks :Chained('/cvterm/get_cvterm') :PathPart('datatables/annotated_stocks') Args(0) {
    my ($self, $c) = @_;
    my $cvterm = $c->stash->{cvterm};
    my $cvterm_id = $cvterm->cvterm_id;
    my $q = <<'';
SELECT DISTINCT
    type.name,
    stock_id,
    stock.uniquename,
    stock.description
FROM cvtermpath
JOIN cvterm on (cvtermpath.object_id = cvterm.cvterm_id OR cvtermpath.subject_id = cvterm.cvterm_id )
JOIN stock_cvterm on (stock_cvterm.cvterm_id = cvterm.cvterm_id)
JOIN stock USING (stock_id)
JOIN cvterm as type on type.cvterm_id = stock.type_id
WHERE cvtermpath.object_id = ?
  AND stock.is_obsolete = ?
  AND pathdistance > 0
  AND 0 = ( SELECT COUNT(*)
            FROM stock_cvtermprop p
            WHERE type_id IN ( SELECT cvterm_id FROM cvterm WHERE name = 'obsolete' )
              AND p.stock_cvterm_id = stock_cvterm.stock_cvterm_id
              AND value = '1'
          )
ORDER BY stock.uniquename

    my $sth = $c->dbc->dbh->prepare($q);
    my $rows = $c->stash->{rest}{count} = 0 + $sth->execute($cvterm_id, 'false');

    my @stock_data;
        while ( my ($type, $stock_id , $stock_name, $description) = $sth->fetchrow_array ) {
            my $stock_link = qq|<a href="/stock/$stock_id/view">$stock_name</a> |;
            push @stock_data, [
                $type,
		$stock_link,
                $description,
                ];
        }
    $c->stash->{rest} = { data => \@stock_data, };
}



sub get_annotated_loci :Chained('/cvterm/get_cvterm') :PathPart('datatables/annotated_loci') Args(0) {
    my ($self, $c) = @_;
    my $cvterm = $c->stash->{cvterm};
    my $cvterm_id = $cvterm->cvterm_id;

    my $q = "SELECT DISTINCT locus_id, locus_name, locus_symbol, common_name  FROM cvtermpath
             JOIN cvterm ON (cvtermpath.object_id = cvterm.cvterm_id OR cvtermpath.subject_id = cvterm.cvterm_id)
             JOIN phenome.locus_dbxref USING (dbxref_id )
             JOIN phenome.locus USING (locus_id)
             JOIN sgn.common_name USING (common_name_id)
             WHERE (cvtermpath.object_id = ?) AND locus_dbxref.obsolete = 'f' AND locus.obsolete = 'f' AND pathdistance > 0";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($cvterm_id);
    my @data;
    while ( my ($locus_id, $locus_name, $locus_symbol, $common_name) = $sth->fetchrow_array ) {
        my $link = qq|<a href="/locus/$locus_id/view">$locus_symbol</a> |;
        push @data,
        [
         (
          $common_name,
          $link,
          $locus_name,
         )
        ];
    }
    $c->stash->{rest} = { data => \@data, };
}



sub get_phenotyped_stocks :Chained('/cvterm/get_cvterm') :PathPart('datatables/phenotyped_stocks') Args(0) {
    my ($self, $c) = @_;
    my $cvterm =  $c->stash->{cvterm};
    my $cvterm_id  = $cvterm->cvterm_id;

    my $q = "SELECT DISTINCT acc.stock_id,  pathdistance, acc.uniquename, acc.description, type.name
             FROM cvtermpath
             JOIN cvterm ON (cvtermpath.object_id = cvterm.cvterm_id
                         OR cvtermpath.subject_id = cvterm.cvterm_id )
             JOIN phenotype on cvterm.cvterm_id = phenotype.observable_id
             JOIN nd_experiment_phenotype USING (phenotype_id)
             JOIN nd_experiment_stock USING (nd_experiment_id)
             JOIN stock as plot USING (stock_id)
             JOIN stock_relationship on(plot.stock_id=stock_relationship.subject_id) join stock as acc on(stock_relationship.object_id=acc.stock_id)
             JOIN cvterm as type on type.cvterm_id = acc.type_id      
             WHERE cvtermpath.object_id = ? ORDER BY acc.stock_id " ;


    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($cvterm_id) ;
    #$c->stash->{rest}{count} = 0 + $sth->execute($cvterm_id);
    my @data;
    while ( my ($stock_id, $pathdistance, $stock_name, $description, $type) = $sth->fetchrow_array ) {
        my $link = qq|<a href="/stock/$stock_id/view">$stock_name</a> |;
        push @data, [
	    $type,
	    $link,
	    $description,
        ];
    }
    $c->stash->{rest} = { data => \@data, };
}

sub get_direct_trials :Chained('/cvterm/get_cvterm') :PathPart('datatables/direct_trials') Args(0) {
    my ($self, $c) = @_;
    my $cvterm = $c->stash->{cvterm};
    my $cvterm_id = $cvterm->cvterm_id;
    my $q = "SELECT DISTINCT project_id, project.name, project.description
             FROM public.project
              JOIN nd_experiment_project USING (project_id)
              JOIN nd_experiment_stock USING (nd_experiment_id)
              JOIN nd_experiment_phenotype USING (nd_experiment_id)
              JOIN phenotype USING (phenotype_id)
              JOIN cvterm on cvterm.cvterm_id = phenotype.observable_id
             WHERE observable_id = ?
    ";

    my $sth = $c->dbc->dbh->prepare($q);
    my $count = 0 + $sth->execute($cvterm_id );
    my @data;
    while ( my ($project_id, $project_name, $description) = $sth->fetchrow_array ) {
        my $link = qq|<a href="/breeders/trial/$project_id">$project_name</a> |;
        push @data,
        [
	 $link,
	 $description,
          ];
    }
    $c->stash->{rest} = { data => \@data, count => $count };
}

sub get_cvtermprops : Path('/cvterm/prop/get') : ActionClass('REST') { }

sub get_cvtermprops_GET {
    my ($self, $c) = @_;

    my $cvterm_id = $c->req->param("cvterm_id");
    my $type_id = $c->req->param("type_id");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $prop_rs = $schema->resultset("Cv::Cvtermprop")->search(
	{
	    'me.cvterm_id' => $cvterm_id,
	    #type_id => $type_id,
	}, { join => 'type', order_by => 'cvtermprop_id' } );

    my @propinfo = ();
    while (my $prop = $prop_rs->next()) {
	push @propinfo, {cvtermprop_id => $prop->cvtermprop_id, cvterm_id => $prop->cvterm_id, type_id => $prop->type_id(), type_name => $prop->type->name(), value => $prop->value() };
    }

    $c->stash->{rest} = \@propinfo;


}

sub add_cvtermprop : Path('/cvterm/prop/add') : ActionClass('REST') { }

sub add_cvtermprop_POST {
    my ( $self, $c ) = @_;
    my $response;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    if (!$c->user()) {
	$c->stash->{rest} = { error => "Log in required for adding stock properties." }; return;
    }

    #if (  any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {

    if ($c->stash->{access}->grant( $c->stash->{user_id}, "write", "ontologies")) { 
        my $req = $c->req;
        my $cvterm_id = $c->req->param('cvterm_id');
        my $prop  = $c->req->param('prop');
        my $cv_name = $c->req->param('cv_name') || 'trait_property'; 
	$prop =~ s/^\s+|\s+$//g; #trim whitespace from both ends
        my $prop_type = $c->req->param('prop_type');

	my $cvterm = $schema->resultset("Cv::Cvterm")->find( { cvterm_id => $cvterm_id } );

    if ($cvterm && defined($prop) && $prop_type) {

        try {
            $cvterm->create_cvtermprops( { $prop_type => $prop }, { cv_name => $cv_name , autocreate => 1 } );
	    
            my $dbh = $c->dbc->dbh();
	    $c->stash->{rest} = { message => "cvterm_id $cvterm_id and type_id $prop_type have been associated with value $prop. " };
	
	} catch {
            $c->stash->{rest} = { error => "Failed: $_" }
        };
    } else {
	$c->stash->{rest} = { error => "Cannot associate prop $prop_type: $prop with cvterm $cvterm_id " };
	}
    } else {
	$c->stash->{rest} = { error => 'You do not have the privileges to modify ontologies' };
    }
}

sub delete_cvtermprop : Path('/cvterm/prop/delete') : ActionClass('REST') { }

sub delete_cvtermprop_GET {
    my $self = shift;
    my $c = shift;
    my $cvtermprop_id = $c->req->param("cvtermprop_id");

    #if (! any { $_ eq 'curator' || $_ eq 'submitter' || $_ eq 'sequencer' } $c->user->roles() ) {
    if ($c->stash->{access}->denied( $c->stash->{user_id}, "write", "ontologies")) { 
	$c->stash->{rest} = { error => 'Log in and privileges required for deletion of stock properties.' };
	$c->detach();
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $cvtermprop = $schema->resultset("Cv::Cvtermprop")->find( { cvtermprop_id => $cvtermprop_id });
    if (! $cvtermprop) {
	$c->stash->{rest} = { error => 'The specified prop does not exist' };
	return;
    }
    eval {
	$cvtermprop->delete();
    };
    if ($@) {
	$c->stash->{rest} = { error => "An error occurred during deletion: $@" };
	    return;
    }
    $c->stash->{rest} = { message => "The cvterm prop was removed from the database." };
}

####
1;##
####
