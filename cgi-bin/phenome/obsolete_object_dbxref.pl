use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Phenome::LocusDbxref;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;
use JSON;

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();
my $json = JSON->new();
my %error=();


if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {
    
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    my ($object_dbxref_id, $type, $action) = $doc->get_encoded_arguments("object_dbxref_id", "type", "action");
    my  $link;
    
    eval {
	if ($type eq 'locus') {
	    my $locus_dbxref=CXGN::Phenome::LocusDbxref->new($dbh, $object_dbxref_id);
	    if ($action eq 'unobsolete' ) {
		$locus_dbxref->unobsolete();
	    }else { $locus_dbxref->obsolete(); }
	    my $locus_id = $locus_dbxref->get_locus_id();
	    $link = "http://solgenomics.net/phenome/locus_display.pl?locus_id=$locus_id";
	}elsif ($type eq 'individual') {
	    my $individual_dbxref=CXGN::Phenome::Individual::IndividualDbxref->new($dbh, $object_dbxref_id);
	    if ($action eq 'unobsolete' ) { $individual_dbxref->unobsolete(); }
	    else { $individual_dbxref->obsolete(); }
	    
	    my $individual_id = $individual_dbxref->get_individual_id();
	    $link = "http://solgenomics.net/phenome/individual.pl?individual_id=$individual_id";
	}
    };
    if ($@) { 
	warn "$action ontology term association failed!  $@"; 
	$error{error} =  "$action annotation for $type failed!  $@"; 
    }
    else  { 
	$error{response} =  "$action annotation for $type worked!"; 
	
	my $subject="[Ontology-$type association $action] ";
	my $person= CXGN::People::Person->new($dbh, $login_person_id);
	my $user=$person->get_first_name()." ".$person->get_last_name();
	my $user_link = qq |http://solgenomics.net/solpeople/personal-info.pl?sp_person_id=$login_person_id|;
	
   	my $fdbk_body="$user ($user_link) just $action ontology-$type association from phenome. $type - dbxref\n
         id=$object_dbxref_id  \n $link"; 
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
    }
    
} else {
    $error{error} =  "User type $login_user_type does not have permissions to obsolete ! ";
}

my $jobj = $json->encode(\%error);
print  $jobj;
