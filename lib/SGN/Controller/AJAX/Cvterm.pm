
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
    $c->{stash}->{rest} = \@response_list;
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
    $c->{stash}->{rest} = $hashref;
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
    $c->{stash}->{rest} = $hashref;
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
    $c->{stash}->{rest} = $hashref;
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
    $c->{stash}->{rest} = $hashref;
}

sub recursive_stocks : Local : ActionClass('REST') { }

sub recursive_stocks_GET :Args(0) {
    my ($self, $c) = @_;
    my $cvterm_id = $c->request->param("cvterm_id");
    my $q = <<'';
SELECT DISTINCT
        stock_id
      , stock.name
      , stock.description
FROM cvtermpath
JOIN cvterm on (cvtermpath.object_id = cvterm.cvterm_id OR cvtermpath.subject_id = cvterm.cvterm_id )
JOIN stock_cvterm on (stock_cvterm.cvterm_id = cvterm.cvterm_id)
JOIN stock USING (stock_id)
WHERE cvtermpath.object_id = ?
  AND stock.is_obsolete = ?
  AND pathdistance > 0
  AND 0 = ( SELECT COUNT(*)
            FROM stock_cvtermprop p
            WHERE type_id IN ( SELECT cvterm_id FROM cvterm WHERE name = 'obsolete' )
              AND p.stock_cvterm_id = stock_cvterm.stock_cvterm_id
              AND value = '1'
          )
ORDER BY stock.name

    my $sth = $c->dbc->dbh->prepare($q);
    my $rows = $c->stash->{rest}{count} = 0 + $sth->execute($cvterm_id, 'false');
    if( $rows > 500 ) {
        $c->stash->{rest}{html} = commify_number($rows)." annotated stocks found, too many to display.";
    } else {
        my @stock_data;
        while ( my ($stock_id , $stock_name, $description) = $sth->fetchrow_array ) {
            my $stock_link = qq|<a href="/stock/$stock_id/view">$stock_name</a> |;
            push @stock_data, [
                $stock_link,
                $description,
                ];
        }
        $c->stash->{rest}{html} =
            @stock_data
                ? columnar_table_html(
                    headings  =>  [ "Stock name", "Description" ],
                    data      => \@stock_data,
                    )
                : undef;
    }
}

sub recursive_loci : Local : ActionClass('REST') { }

sub recursive_loci_GET :Args(0) {
    my ($self, $c) = @_;
    my $cvterm_id = $c->request->param("cvterm_id");
    my $q = "SELECT DISTINCT locus_id, locus_name, locus_symbol, common_name  FROM cvtermpath
             JOIN cvterm ON (cvtermpath.object_id = cvterm.cvterm_id OR cvtermpath.subject_id = cvterm.cvterm_id)
             JOIN phenome.locus_dbxref USING (dbxref_id )
             JOIN phenome.locus USING (locus_id)
             JOIN sgn.common_name USING (common_name_id)
             WHERE (cvtermpath.object_id = ?) AND locus_dbxref.obsolete = 'f' AND locus.obsolete = 'f' AND pathdistance > 0";

    my $sth = $c->dbc->dbh->prepare($q);
    $c->stash->{rest}{count} = 0+$sth->execute($cvterm_id); #< execute can return 0E0, i.e. zero but true.
    my @data;
    while ( my ($locus_id, $locus_name, $locus_symbol, $common_name) = $sth->fetchrow_array ) {
        my $link = qq|<a href="/phenome/locus_display.pl?locus_id=$locus_id">$locus_symbol</a> |;
        push @data,
        [
         (
          $common_name,
          $link,
          $locus_name,
         )
        ];
    }
    $c->stash->{rest}{html} = @data ?
        columnar_table_html(
            headings     =>  [ "Organism", "Symbol", "Name" ],
            data         => \@data,
        )  : '<span class="ghosted">none</span>' ;
}


sub phenotyped_stocks : Local : ActionClass('REST') { }

sub phenotyped_stocks_GET :Args(0) {
    my ($self, $c) = @_;
    my $cvterm_id = $c->request->param("cvterm_id");
    my $q = "SELECT DISTINCT object_id, type.name, stock.name, stock.description
             FROM public.stock_relationship
             JOIN stock ON stock_id = object_id

             JOIN cvterm as type ON cvterm_id = stock.type_id
             JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = stock_relationship.subject_id)
             JOIN nd_experiment_phenotype USING (nd_experiment_id)
             JOIN phenotype USING (phenotype_id)
             JOIN cvterm on cvterm.cvterm_id = observable_id
             WHERE observable_id = ? AND type.name ilike ?";

    my $sth = $c->dbc->dbh->prepare($q);
    $c->stash->{rest}{count} = 0 + $sth->execute($cvterm_id , '%population%');
    my @data;
    while ( my ($stock_id, $type, $stock_name, $description) = $sth->fetchrow_array ) {
        my $link = qq|<a href="/stock/$stock_id/view">$stock_name</a> |;
        push @data,
        [
         (
          $link,
          $description,
         )
        ];
    }
    $c->stash->{rest}{html} = @data ?
        columnar_table_html(
            headings     =>  [ "Stock name", "Description" ],
            data         => \@data,
        )  : undef ;
}


1;
