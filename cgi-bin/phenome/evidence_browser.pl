use strict;
use warnings;

use CXGN::Scrap::AjaxPage;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($type, $evidence_code_id, $locus_id, $individual_id) = $doc->get_encoded_arguments("type", "evidence_code_id", "locus_id", "individual_id");

my $dbh = CXGN::DB::Connection->new();

if ($type eq 'relationship') {

    my $relationship_query = $dbh->prepare("SELECT distinct(cvterm.dbxref_id), cvterm.name 
                                       FROM public.cvterm 
                                       JOIN public.cv USING (cv_id) 
                                      JOIN public.cvterm_relationship ON (cvterm.cvterm_id= cvterm_relationship.subject_id)
                                       WHERE cv.name ='relationship' AND
                                       cvterm.is_obsolete = 0 
                                       ORDER BY cvterm.name;
                                      ");
    $relationship_query->execute();
    
    my ($dbxref_id, $cvterm_name) = $relationship_query->fetchrow_array();
    my $available_relationships;
    
    while($cvterm_name){
	$available_relationships .= "$dbxref_id*$cvterm_name|";
	($dbxref_id, $cvterm_name) = $relationship_query->fetchrow_array();    
    }
    
    
    print "$available_relationships";



}elsif ($type eq 'evidence_code') {

 my $evidence_code_query = $dbh->prepare("SELECT distinct(cvterm.dbxref_id), cvterm.name 
                                       FROM public.cvterm_relationship
                                       
                                      JOIN public.cvterm ON (cvterm.cvterm_id= cvterm_relationship.subject_id)
                                       WHERE
                                       object_id= (select cvterm_id from cvterm where name = 'evidence_code') AND
                                       cvterm.is_obsolete = 0 
                                       ORDER BY cvterm.name;
                                      ");
    $evidence_code_query->execute();
    
    my ($dbxref_id, $cvterm_name) = $evidence_code_query->fetchrow_array();
    my $available_evidence_codes;
    
    while($cvterm_name){
	$available_evidence_codes.= "$dbxref_id*$cvterm_name|";
	($dbxref_id, $cvterm_name) = $evidence_code_query->fetchrow_array();    
    }
    
    
    print "$available_evidence_codes";


}elsif ($type eq 'evidence_description') {

 my $evidence_description_query = $dbh->prepare("SELECT dbxref_id, cvterm.name FROM cvterm 
                                                JOIN cvterm_relationship ON cvterm_id=subject_id 
                                                WHERE object_id= (select cvterm_id FROM public.cvterm WHERE dbxref_id= ?) 
                                                AND cvterm.is_obsolete = 0" 
                                                );
    $evidence_description_query->execute($evidence_code_id);
    
    my ($dbxref_id, $cvterm_name) = $evidence_description_query->fetchrow_array();
    my $available_evidence_descriptions;
    
    while($cvterm_name){
	$available_evidence_descriptions.= "$dbxref_id*$cvterm_name|";
	($dbxref_id, $cvterm_name) = $evidence_description_query->fetchrow_array();    
    }
    
    
    print "$available_evidence_descriptions";

}elsif ($type eq 'evidence_with') {
    my $evidence_with_query;
    if ($locus_id) {
	$evidence_with_query = $dbh->prepare("SELECT dbxref.dbxref_id, accession,name, description 
                                          FROM public.dbxref 
                                          JOIN feature USING (dbxref_id) 
                                          JOIN phenome.locus_dbxref USING (dbxref_id)
                                          WHERE locus_id= ? 
                                          AND phenome.locus_dbxref.obsolete = 'f'" 
					     );
	$evidence_with_query->execute($locus_id);
    }elsif ($individual_id) {
	$evidence_with_query = $dbh->prepare("SELECT dbxref.dbxref_id, accession,name, description 
                                          FROM public.dbxref 
                                          JOIN feature USING (dbxref_id) 
                                          JOIN phenome.individual_dbxref USING (dbxref_id)
                                          WHERE individual_id= ? 
                                          AND phenome.individual_dbxref.obsolete = 'f'" 
					     );
	$evidence_with_query->execute($individual_id);
    }
    my ($dbxref_id, $accession, $name, $description) = $evidence_with_query->fetchrow_array();
    my $available_evidence_with;
    
    while($accession){
	$available_evidence_with.= "$dbxref_id*$name: $description|";
	($dbxref_id, $accession, $name, $description) = $evidence_with_query->fetchrow_array();
    }
    
    
    print "$available_evidence_with";

}elsif ($type eq 'reference') {

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
    }elsif ($individual_id) {
	$reference_query= $dbh->prepare("SELECT dbxref.dbxref_id, accession,title 
                                          FROM public.dbxref 
                                          JOIN public.pub_dbxref USING (dbxref_id)
                                          JOIN public.pub USING (pub_id)
                                          JOIN phenome.individual_dbxref USING (dbxref_id)
                                          WHERE individual_id= ? 
                                          AND phenome.individual_dbxref.obsolete = 'f'" 
					);
	$reference_query->execute($individual_id);
    }
    my ($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
    my $available_reference;
    
    while($accession){
	$available_reference.= "$dbxref_id*$accession: $title|";
	($dbxref_id, $accession, $title) = $reference_query->fetchrow_array();
    }
    
    
    print "$available_reference";
    
}
