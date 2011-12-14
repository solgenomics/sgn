use strict;
use warnings;

use CXGN::Scrap::AjaxPage;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($type, $evidence_code_id, $locus_id, $individual_id) = $doc->get_encoded_arguments("type", "evidence_code_id", "locus_id", "individual_id");

my $dbh = CXGN::DB::Connection->new();

if ($type eq 'reference') {

    my $reference_query;
    if ($locus_id) {
	$reference_query= $dbh->prepare("SELECT dbxref.dbxref_id, accession,title 
                                          FROM public.dbxref 
                                          JOIN public.pub_dbxref USING (dbxref_id)
                                          JOIN public.pub USING (pub_id)
                                          JOIN phenome.locus_dbxref USING (dbxref_id)
                                          WHERE locus_id= ? 
                                          AND phenome.locus_dbxref.obsolete = 'f'" 
					);
	$reference_query->execute($locus_id);
    }
    my ($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
    my $available_reference;
    while($accession){
	$available_reference.= "$dbxref_id*$accession: $title|";
	($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
    }
    print "$available_reference";
}
