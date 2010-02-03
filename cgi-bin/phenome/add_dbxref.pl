use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Contact;

use CXGN::Chado::Dbxref;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LocusRanking;
use CXGN::Feed;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {
    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($type,$object_id,$dbxref_id,$validate)= $doc->get_encoded_arguments("type","object_id","dbxref_id","validate");
    
    my $dbxref= CXGN::Chado::Dbxref->new($dbh, $dbxref_id);
    my $pub_id=$dbxref->get_publication()->get_pub_id();
    my $link;
    eval {
	my ($object, $object_dbxref, $object_dbxref_id);
	if ($type eq 'locus') {
	    $link= "http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$object_id";
	    
	    $object=CXGN::Phenome::Locus->new($dbh, $object_id);
	    my $pub_rank= CXGN::Phenome::Locus::LocusRanking->new($dbh, $object_id, $pub_id);
	    $pub_rank->set_validate($validate);
	    $pub_rank->store_validate(); #store locus_pub_ranking_validate
	    my $locus_dbxref_id =$object->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	    if ($validate eq 'yes') { $object->add_locus_dbxref($dbxref,$locus_dbxref_id,$login_person_id); } 
	    elsif ($validate eq 'no') { $object->get_locus_dbxref($dbxref)->obsolete(); } 

	    
	}elsif ($type eq 'individual') {
	    $object_dbxref_id= CXGN::Phenome::Individual::IndividualDbxref::individual_dbxref_exists($dbh,$object_id, $dbxref_id);
	    $object_dbxref=CXGN::Phenome::Individual::IndividualDbxref->new($dbh, $object_dbxref_id);
	    $object_dbxref->set_individual_id($object_id);
	    $link= "http://www.sgn.cornell.edu/phenome/individual.pl?individual_id=$object_id";
	}
	
	#this store should insert a new locus_dbxref if !$locus_dbxref_id
	#update obsolete to 'f' if $locus_dbxref_id and obsolete ='t'
	#do nothing if $locus_dbxref_id and obsolete = 'f'
	#my $obsolete = $object_dbxref->get_obsolete();
	#if ($obsolete eq 'f' && $object_dbxref_id) {  
	#    print STDERR "********associate_ontology_term.pl exiting ***** $obsolete, $object_dbxref_id, $type\n\n";
	#    exit();
        #}
	
    };
    if ($@) { warn "***********dbxref association failed! \n $@ \n "; }
    else  { 
	
	my $subject="[New locus_dbxref term loaded] $type $object_id";
	my $person= CXGN::People::Person->new($dbh, $login_person_id);
	my $user=$person->get_first_name()." ".$person->get_last_name();
	my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id|;
	
   	my $fdbk_body="$user ($user_link has submitted a new dbxref (id=$dbxref_id) for $type $object_id  \n 
        $link";  
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
}
    
    

