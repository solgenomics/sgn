
use strict;
use warnings;

# a new version of the ontology browser by Lukas.

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Chado::Ontology;
use CXGN::Chado::Cvterm;
use JSON;


my $json = JSON->new();
my %res=();

my $s   = CXGN::Scrap::AjaxPage->new();
my $dbh = CXGN::DB::Connection->new();

my ( $node, $action, $db_name, $term_name ) =
  $s->get_encoded_arguments( "node", "action", "db_name", "term_name" );

my $cvterm = CXGN::Chado::Cvterm->new_with_accession( $dbh, $node );

my $empty_cvterm   = CXGN::Chado::Cvterm->new($dbh);
my @response_nodes = ();
my $error          = "";
if ( $action eq "children" ) {
    @response_nodes = $cvterm->get_children();
}
elsif ( $action eq "parents" ) {
    @response_nodes = $cvterm->get_recursive_parents();
}
elsif ( $action eq "roots" ) {
    my @namespaces = ( 'GO', 'PO', 'SP', 'SO', 'PATO' );
    my @roots = ();
    foreach (@namespaces) {
        push @roots, CXGN::Chado::Cvterm::get_roots( $dbh, $_ );
    }
    foreach (@roots) { push @response_nodes, [ $_, $empty_cvterm ] }
    
    
} elsif ( $action eq "match" ) {
    my $synonym_query = $dbh->prepare(
	"SELECT  distinct(cvterm.dbxref_id), cv.name, cvterm.name, dbxref.accession, synonym
                                   FROM public.cvterm 
                                   JOIN public.cv USING (cv_id)
                                   LEFT JOIN public.cvtermsynonym USING (cvterm_id)
                                   JOIN public.dbxref USING (dbxref_id)
                                   JOIN public.db USING (db_id)
                                   WHERE cvterm.is_obsolete= 0 AND
                                   db.name=? AND
                                   cvtermsynonym.synonym ilike '%$term_name%'
                                  "
	);
    
    my $ontology_query = $dbh->prepare(
	"SELECT  distinct(cvterm.dbxref_id), cv.name, cvterm.name, dbxref.accession,
                                   count(synonym)
                                   FROM public.cvterm 
                                   JOIN public.cv USING (cv_id)
                                   LEFT JOIN public.cvtermsynonym USING (cvterm_id)
                                   JOIN public.dbxref USING (dbxref_id)
                                   JOIN public.db USING (db_id)
                                   WHERE cvterm.is_obsolete= 0 AND
                                   db.name=? AND
                                    (cvterm.name ilike '%$term_name%'
                                    OR cvterm.definition ilike '%$term_name%'
                                    )
                                    GROUP BY cvterm.dbxref_id, cvterm.name, dbxref.accession, cv.name
                                    ORDER BY cv.name, cvterm.name
                                   "
	);
    $ontology_query->execute($db_name);
    my %terms;
    my ( $dbxref_id, $cv_name, $cvterm_name, $accession, $synonym ) =
	$ontology_query->fetchrow_array();
    
    while ($cvterm_name) {
        $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} =
	    $cvterm_name;
        ( $dbxref_id, $cv_name, $cvterm_name, $accession, $synonym ) =
	    $ontology_query->fetchrow_array();
    }
    
    $synonym_query->execute($db_name);
    my @synonym_terms;
    while ( my ( $dbxref_id, $cv_name, $cvterm_name, $accession, $synonym ) =
	    $synonym_query->fetchrow_array() )
    {
        if ( $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} ) {
            $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} .=
		" ($synonym)";
        }
        else {
            $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} =
		$cvterm_name . " ($synonym)";
        }
    }
    
    #sort the hash of hashes by keys(cv_name)  and then by values (term names)
    my $print_string;
    
    foreach my $cv_name ( sort ( keys %terms ) ) {
        foreach my $key (
            sort { $terms{$cv_name}{$a} cmp $terms{$cv_name}{$b} }
            keys %{ $terms{$cv_name} }
	    )
        {
            $print_string .= $key . $terms{$cv_name}{$key};
            $print_string .= "|";
        }
    }
    $res{response} = $print_string;

} else { $res{error} = "ERROR. The action parameter is required."; }


my @response_list = ();

if (@response_nodes) {
    foreach my $n (@response_nodes) {
	my $has_children = 0;
	if ( $n->[0]->count_children() > 0 ) { $has_children = 1; }
	push @response_list,
	( $n->[0]->get_full_accession() ) . "\*"
	    . (   $n->[0]->get_cvterm_name() . "\*"
		  . ( $n->[0]->get_cvterm_id() )
		  . "\*$has_children" . "\*"
		  . $n->[1]->get_cvterm_name() );
    }
    $res{response} = join "#", @response_list;
}


$s->send_http_header();
print $json->encode(\%res);


