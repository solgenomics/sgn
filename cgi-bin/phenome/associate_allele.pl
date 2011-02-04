use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Phenome::Individual;
use CXGN::People::Person;
use CXGN::Feed;
use JSON;

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my $dbh = CXGN::DB::Connection->new();
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {


    
    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($individual_id, $allele_id, $sp_person_id) = $doc->get_encoded_arguments("individual_id", "allele_id", "sp_person_id");
    
    my %error = ();
    my $json = JSON->new();
   
    eval {
	my $individual=CXGN::Phenome::Individual->new($dbh, $individual_id);
	$individual->set_updated_by($sp_person_id);
	$individual->associate_allele($allele_id, $sp_person_id);
	$error{"response"} = "Associated allele $allele_id with indvidual $individual_id!";
    };
    if ($@) { 
	$error{"error"} = "Associate allele failed! " . $@;
	CXGN::Contact::send_email('associate_allele.pl died',$error{"error"}, 'sgn-bugs@sgn.cornell.edu');
	
    } else  { 
	
	my $subject="[New individual associated] allele $allele_id";
	my $person= CXGN::People::Person->new($dbh, $login_person_id);
	my $user=$person->get_first_name()." ".$person->get_last_name();
	my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
	
   	my $fdbk_body="$user ($user_link has associated individual $individual_id with allele $allele_id  \n
         http://www.sgn.cornell.edu/phenome/individual.pl?individual_id=$individual_id"; 
 
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
    
    my $jobj = $json->objToJson(\%error);
    
    #print "Content-Type: text/plain\n\n"; # no need for this ! We already have the http header! 
    print  $jobj;
    
}
