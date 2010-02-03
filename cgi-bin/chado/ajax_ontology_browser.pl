
use strict;

# a new version of the ontology browser by Lukas.

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Chado::Ontology;
use CXGN::Chado::Cvterm;


my $s = CXGN::Scrap::AjaxPage->new();
my $dbh = CXGN::DB::Connection->new();

my ($node, $action, $db_name, $term_name) = $s->get_encoded_arguments("node", "action", "db_name", "term_name");

#my ($namespace, $id) = split/\:/, $parent;


#my $cv = CXGN::Chado::Ontology->new_with_name($dbh, $namespace);
my $cvterm = CXGN::Chado::Cvterm->new_with_accession($dbh, $node);

my $empty_cvterm=CXGN::Chado::Cvterm->new($dbh);
my @response_nodes = ();
my $error = "";
if ($action eq "children") { 
    @response_nodes = $cvterm->get_children();
}
elsif ($action eq "parents") { 
    @response_nodes = $cvterm->get_ancestors();
}
elsif ($action eq "roots") { 
    my @namespaces=('GO', 'PO', 'SP', 'SO', 'PATO');
    my @roots=();
    foreach (@namespaces) { push @roots, CXGN::Chado::Cvterm::get_roots($dbh, $_); }
    foreach (@roots) { push @response_nodes, [$_, $empty_cvterm]  };
    
}
elsif ($action eq "match") { 
    print STDERR "Getting nodes matching string $node...\n";
    
    my $synonym_query= $dbh->prepare("SELECT  distinct(cvterm.dbxref_id), cv.name, cvterm.name, dbxref.accession, synonym
                                    FROM public.cvterm 
                                   JOIN public.cv USING (cv_id)
                                   LEFT JOIN public.cvtermsynonym USING (cvterm_id)
                                   JOIN public.dbxref USING (dbxref_id)
                                   JOIN public.db USING (db_id)
                                    WHERE cvterm.is_obsolete= 0 AND
                                    db.name=? AND
                                    cvtermsynonym.synonym ilike '%$term_name%'
                                  ");
    
    my $ontology_query = $dbh->prepare("SELECT  distinct(cvterm.dbxref_id), cv.name, cvterm.name, dbxref.accession,
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
                                   ");
    $ontology_query->execute($db_name);
    my %terms;
    my ($dbxref_id, $cv_name,$cvterm_name, $accession, $synonym) = $ontology_query->fetchrow_array();
    
    while($cvterm_name){
	$terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"}  =  $cvterm_name;
	($dbxref_id, $cv_name,$cvterm_name, $accession, $synonym) = $ontology_query->fetchrow_array();    
    }
    
    $synonym_query->execute($db_name);
    my @synonym_terms;
    while (my ($dbxref_id, $cv_name, $cvterm_name, $accession, $synonym) = $synonym_query->fetchrow_array()) {
	if ($terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} ) {
	    $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} .= " ($synonym)";
	}else {
	    $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} = $cvterm_name . " ($synonym)";
	}
    }
    
#sort the hash of hashes by keys(cv_name)  and then by values (term names)
    my $print_string; 
    
    foreach my $cv_name(sort (keys %terms ) ) {
	foreach my $key(sort { $terms{$cv_name}{$a} cmp $terms{$cv_name}{$b} } keys %{$terms{$cv_name}} ) {
	    $print_string .= $key . $terms{$cv_name}{$key};
	    $print_string .= "|";
	}
    } 
    print "Content-Type: text/html\n\n";
    print $print_string;
    exit();
    
}else {  $error = "ERROR. The action parameter is required.";}

#foreach (@response_nodes) {
#print STDERR $_->[0]->get_cvterm_name() ;}#. "---" . $_->[1]->get_cvterm_name() . "!!\n"; }

my $response = "";
my @response_list =();
if ($error) { 
    $response = $error;
}
else { 
#print "CV ID: ".$cv->get_cv_id()."\n";
    foreach my $n (@response_nodes) { 
	my $has_children = 0;
	if ($n->[0]->count_children() > 0) { $has_children = 1; }
	push @response_list, ($n->[0]->get_full_accession())."\%".($n->[0]->get_cvterm_name()."\%".($n->[0]->get_cvterm_id())."\%$has_children" . "\%" . $n->[1]->get_cvterm_name());
    }
}

$response = join "#",  @response_list;


print STDERR "AJAX ONTOLOGY BROWSER RETURNS: $response\n";
#print $s->header();
print "Content-Type: text/html\n\n";
print $response;
#print $s->footer();
