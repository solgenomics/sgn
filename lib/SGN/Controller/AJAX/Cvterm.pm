
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


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
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
    my $db_name = $c->req->param('db_name');
    # trim and regularize whitespace
    #$term =~ s/(^\s+|\s+)$//g;
    #$term =~ s/\s+/ /g;
    #my $db_name = 'PO';
    my $term_name = $c->request->param("term");

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
    #while  (my $hashref = $sth->fetchrow_hashref ) {
    #    push @response_list, $hashref;
    #}
    while (my ($cvterm_id, $cv_name, $cvterm_name, $accession) = $sth->fetchrow_array() ) {
        push @response_list, $cv_name . "--" . $accession . " " . $cvterm_name ;
    }
    $c->{stash}->{rest} = \@response_list;
}




1;
