use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Contact;
use CXGN::Feed;

use CXGN::Phenome::LocusDbxref;
use CXGN::Phenome::Locus::LocusDbxrefEvidence;
use CXGN::Phenome::Individual::IndividualDbxref;
use CXGN::Phenome::Individual::IndividualDbxrefEvidence;

use JSON;


my $dbh = CXGN::DB::Connection->new();

my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    
    my %error = ();
    my $json = JSON->new();
    
    
    my ($type, $object_id, $dbxref_id,  $relationship_id, $evidence_code_id, $evidence_description_id, $evidence_with_id, $reference_id ) = $doc->get_encoded_arguments("type", "object_id", "dbxref_id", "relationship_id", "evidence_code_id", "evidence_description_id", "evidence_with_id", "reference_id");
    
    if (!$evidence_with_id) {$evidence_with_id = undef};
    if (!$evidence_description_id) {$evidence_description_id = undef};
    if (!$reference_id) {$reference_id = CXGN::Chado::Publication::get_curator_ref($dbh)};
   
    my $link;
    eval {
	#print STDERR "trying to store a new $type _dbxref ! \n\n";
	my ($object_dbxref, $object_dbxref_id, $object_dbxref_evidence);
	my @evidences;
	if ($type eq 'locus') {
	    $object_dbxref_id= CXGN::Phenome::LocusDbxref::locus_dbxref_exists($dbh,$object_id, $dbxref_id);
	    $object_dbxref=CXGN::Phenome::LocusDbxref->new($dbh, $object_dbxref_id);
	    $object_dbxref->set_locus_id($object_id);
	    
	    $object_dbxref_evidence= CXGN::Phenome::Locus::LocusDbxrefEvidence->new($dbh); ##
	    $link= "http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$object_id";
	
	}elsif ($type eq 'individual') {
	    $object_dbxref_id= CXGN::Phenome::Individual::IndividualDbxref::individual_dbxref_exists($dbh,$object_id, $dbxref_id);
	    $object_dbxref=CXGN::Phenome::Individual::IndividualDbxref->new($dbh, $object_dbxref_id);
	    $object_dbxref->set_individual_id($object_id);
	    $object_dbxref_evidence= CXGN::Phenome::Individual::IndividualDbxrefEvidence->new($dbh);
	

	    $link= "http://www.sgn.cornell.edu/phenome/individual.pl?individual_id=$object_id";
	}
	
	$object_dbxref->set_dbxref_id($dbxref_id);
	$object_dbxref->set_sp_person_id($login_person_id);
	
	#this store should insert a new locus_dbxref if !$locus_dbxref_id
	#update obsolete to 'f' if $locus_dbxref_id and obsolete ='t'
	#do nothing if $locus_dbxref_id and obsolete = 'f'
	my $obsolete = $object_dbxref->get_obsolete();
	
	#print STDERR "associate_ontology.pl is about to store a new $type _dbxref...\n";
	
	#if the dbxref exists this should just return the database id to be used for storing a  dbxref_evidence
	$object_dbxref_id=$object_dbxref->store(); 
	if ($type eq 'locus') { $object_dbxref_evidence->set_object_dbxref_id($object_dbxref_id); }
	elsif ($type eq 'individual') { $object_dbxref_evidence->set_individual_dbxref_id($object_dbxref_id); }
	
	$object_dbxref_evidence->set_relationship_type_id($relationship_id);
	$object_dbxref_evidence->set_evidence_code_id($evidence_code_id);
	$object_dbxref_evidence->set_evidence_description_id($evidence_description_id);
	$object_dbxref_evidence->set_evidence_with($evidence_with_id);
	$object_dbxref_evidence->set_reference_id($reference_id);
	$object_dbxref_evidence->set_sp_person_id($login_person_id);
	
	#$object_dbxref_evidence->set_updated_by($login_person_id); # evidences are now handled directly. 
	#see update_ontology_evidence.pl
	
	#if the evidence code already exists for this annotation, do not  store 
	#if   ($object_dbxref_evidence->evidence_exists()  ) {
 	    #return here some javascript error code...
 	#    $error{"error"} = "associate_ontology_term.pl failed. Evidence code already exists in db...(relationship_id = $relationship_id, evidence_code_id = $evidence_code_id, $type _dbxref_id = $object_dbxref_id \n";
 	
	#LocusDbxrefEvidence->store() should unobsolete if the evidence exists with obsolete= 't'
	my $object_dbxref_evidence_id= $object_dbxref_evidence->store() ; 
	
    };
    if ($@) { 
	$error{"error"} =  'Failed associating ontology term! An email message has been sent to the SGN development team. We are working on fixing this problem.';
	CXGN::Contact::send_email('associate_ontology_term.pl died',"$@ \n params: relationship_id=$relationship_id\n evidence_code_id= $evidence_code_id\n evidence_description_id =$evidence_description_id\nevidence_with_id=$evidence_with_id \n reference_id=$reference_id\n sp_person_id=$login_person_id\n type=$type\n object_id= $object_id\n  dbxref_id=$dbxref_id", 'sgn-bugs@sgn.cornell.edu');
	warn "associating ontology term failed!  $@"; 
    }
    else  { 
	
	my $subject="[New ontology term loaded] $type $object_id";
	my $person= CXGN::People::Person->new($dbh, $login_person_id);
	my $user=$person->get_first_name()." ".$person->get_last_name();
	my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id|;
	
   	my $fdbk_body="$user ($user_link has submitted a new ontology term for $type $object_id  \n 
        $link";  
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
    my $jobj = $json->encode(\%error);
    print  $jobj;
    
    
}
    
    

