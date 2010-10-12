use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use JSON;
use Try::Tiny;

my $json = JSON->new();
my %response=();

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();
my ($term_name, $db_name) = $doc->get_encoded_arguments("term_name", "db_name");

my $dbh = CXGN::DB::Connection->new();
my %terms;

try {
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
    
    my ($dbxref_id, $cv_name,$cvterm_name, $accession, $synonym) = $ontology_query->fetchrow_array();
    
    while($cvterm_name){
	$terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"}  =  $cvterm_name;
	($dbxref_id, $cv_name,$cvterm_name, $accession, $synonym) = $ontology_query->fetchrow_array();    
    }
    
    $synonym_query->execute($db_name);
    while (my ($dbxref_id, $cv_name, $cvterm_name, $accession, $synonym) = $synonym_query->fetchrow_array()) {
	if ($terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} ) {
	    $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} .= " ($synonym)";
	}else {
	    $terms{$cv_name}{"$dbxref_id*$cv_name--$db_name:$accession--"} = $cvterm_name . " ($synonym)";
	}
    }
} catch { $response{error} = "Fetching ontology terms failed! \n" . $! } ;

#sort the hash of hashes by keys(cv_name)  and then by values (term names)
my $print_string=""; 

foreach my $cv_name(sort (keys %terms ) ) {
    foreach my $key(sort { $terms{$cv_name}{$a} cmp $terms{$cv_name}{$b} } keys %{$terms{$cv_name}} ) {
	$print_string .= $key . $terms{$cv_name}{$key};
	$print_string .= "|";
    }
} 
#print $print_string;	

$response{response} = $print_string;

print $json->encode(\%response);
